#!/usr/bin/env python3
"""
Release check: fast static checks of the whole project (no Roblox needed). Run before every publish:

    python3 tools/ReleaseCheck/release_check.py            # prints problems; exit code 1 if any ERROR
    python3 tools/ReleaseCheck/release_check.py --strict   # warnings also fail

It does NOT replace testing in Studio. It finds the mistakes a machine can find:
  - icon names that do not exist (a missing icon shows a grey dot)
  - duplicate ids in the content folders (hamsters, items, emotes, animations)
  - content files without the fields the game needs
  - a Discord webhook (or any private-looking secret) committed to the repository
  - client code that calls HttpService, or secrets / admin config placed where players can read them
  - remote handlers that do not check the player
  - game passes / products that are not configured (warning: they are simply hidden in the shop until you add ids)
  - placeholder text left in the game
"""
import os, re, sys, glob

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
SRC = os.path.join(ROOT, "src")
errors, warnings = [], []

def read(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        return f.read()

def rel(path):
    return os.path.relpath(path, ROOT)

def luau_files(*parts):
    return glob.glob(os.path.join(SRC, *parts, "**", "*.luau"), recursive=True)

# ---------------------------------------------------------------------------
# 1. icons
icons_src = read(os.path.join(SRC, "StarterPlayer", "StarterPlayerScripts", "UI", "Icons.luau"))
drawn = set(re.findall(r"^draw\.([a-z_0-9]+) = function", icons_src, re.M))
alias_block = re.search(r"local alias[^=]*= \{(.*?)\n\}", icons_src, re.S)
aliases = set(re.findall(r"^\s*([a-z_0-9]+) = \"", alias_block.group(1), re.M)) if alias_block else set()
known = drawn | aliases
icon_uses = {}
for path in luau_files():
    text = read(path)
    for match in re.finditer(r"\bIcon = \"([A-Za-z0-9_]+)\"", text):
        icon_uses.setdefault(match.group(1), set()).add(rel(path))
    for match in re.finditer(r"UIKit\.(?:icon|iconText)\([^)]*?\"([a-z_]+)\"", text):
        pass
for name, files in sorted(icon_uses.items()):
    if name not in known and not name.startswith("rbxassetid"):
        errors.append(f"icon '{name}' does not exist in Icons.luau (used in {', '.join(sorted(files)[:3])})")

# 2. duplicate ids + required fields in content folders
def content(folder, id_key):
    seen = {}
    for path in sorted(glob.glob(os.path.join(SRC, "ReplicatedStorage", "Modules", "Content", folder, "*.luau"))):
        if os.path.basename(path).startswith("_"):
            continue
        text = read(path)
        match = re.search(rf"\b{id_key} = \"([^\"]+)\"", text)
        if not match:
            errors.append(f"{rel(path)}: no {id_key} found")
            continue
        value = match.group(1)
        if value in seen:
            errors.append(f"{rel(path)}: duplicate {id_key} '{value}' (also in {rel(seen[value])})")
        seen[value] = path
        if folder in ("Hamsters", "Items") and "DisplayName" not in text:
            errors.append(f"{rel(path)}: no DisplayName")
        if folder == "Hamsters" and "Rarity" not in text:
            errors.append(f"{rel(path)}: no Rarity")
        if folder == "Items":
            if 'Kind = "Consume"' not in text and 'Category = "Gadget"' not in text and ("Price" not in text or "Currency" not in text):
                errors.append(f"{rel(path)}: needs Price and Currency")
            price = re.search(r"\bPrice = (\d+)", text)
            if price and int(price.group(1)) <= 0:
                errors.append(f"{rel(path)}: Price must be above 0")
            cooldown = re.search(r"\bCooldown = ([\d.]+)", text)
            if cooldown and float(cooldown.group(1)) <= 0:
                errors.append(f"{rel(path)}: Cooldown must be above 0")
    return seen
content("Hamsters", "Id"); content("Items", "Id"); content("Emotes", "Id"); content("Animations", "Name")

# 3. secrets
SECRET_PATTERNS = [
    (r"discord(?:app)?\.com/api/webhooks/\d+/[\w-]+", "a Discord webhook URL"),
    (r"rbxassetid://REPLACE", "an unreplaced asset placeholder"),
    (r"-----BEGIN [A-Z ]*PRIVATE KEY-----", "a private key"),
    (r"(?i)api[_-]?key\s*=\s*\"[A-Za-z0-9_\-]{16,}\"", "an API key"),
]
scan_dirs = [SRC, os.path.join(ROOT, "tools"), os.path.join(ROOT, "docs"), os.path.join(ROOT, "world")]
for base in scan_dirs:
    for dirpath, _, names in os.walk(base):
        if ".build" in dirpath:
            continue
        for name in names:
            if not name.endswith((".luau", ".lua", ".md", ".json", ".py", ".sh")):
                continue
            path = os.path.join(dirpath, name)
            if name == "release_check.py" or name == "scn_discord.lua":
                continue  # (this script and the Discord test use a fake URL on purpose)
            if os.path.getsize(path) > 8_000_000:
                continue
            text = read(path)
            for pattern, label in SECRET_PATTERNS:
                if "REPLACE" in pattern and not path.startswith(SRC):
                    continue  # (docs and tests talk about the placeholder on purpose)
                if re.search(pattern, text):
                    errors.append(f"{rel(path)}: contains {label}")

discord_cfg = read(os.path.join(SRC, "ServerScriptService", "Config", "DiscordConfig.luau"))
if re.search(r'WebhookUrl = "[^"]+"', discord_cfg):
    errors.append("DiscordConfig.WebhookUrl is not empty: keep the URL in the ServerStorage StringValue, never in the repository")

# 4. client code must not touch HTTP, server-only configs must stay on the server
for path in luau_files("StarterPlayer") + luau_files("ReplicatedStorage") + luau_files("StarterGui"):
    text = read(path)
    if "HttpService" in text and "GenerateGUID" not in text and "JSON" not in text:
        errors.append(f"{rel(path)}: client-readable code uses HttpService")
    if re.search(r"Config\.(AdminConfig|DiscordConfig)|require\([^)]*(AdminConfig|DiscordConfig)", text):
        errors.append(f"{rel(path)}: client-readable code requires a server-only config")
for path in luau_files("ReplicatedStorage"):
    if re.search(r"discord.*webhook|webhook.*url", read(path), re.I):
        errors.append(f"{rel(path)}: mentions a webhook in a client-readable folder")

# 5. request router: every action must take the player and be wrapped
router = read(os.path.join(SRC, "ServerScriptService", "Systems", "RequestRouter.luau"))
for name, args in re.findall(r"^actions\.([A-Za-z]+) = function\(([^)]*)\)", router, re.M):
    if args.strip() and not args.strip().startswith("player"):  # (an action without arguments reads public data only)
        errors.append(f"RequestRouter action {name} does not receive the player")
if "pcall" not in router:
    warnings.append("RequestRouter has no pcall around actions")

# 6. shop configuration: unconfigured passes / products are hidden, tell the owner
gp = read(os.path.join(SRC, "ReplicatedStorage", "Modules", "GamepassConfig.luau"))
unconfigured = re.findall(r"PassId = 0", gp)
if unconfigured:
    warnings.append(f"{len(unconfigured)} Game Pass(es) have PassId = 0: they are NOT shown as purchasable until you paste real ids (GamepassConfig)")
shop = read(os.path.join(SRC, "ReplicatedStorage", "Modules", "ShopConfig.luau"))
if re.search(r"ProductId = 0", shop):
    warnings.append(f"{len(re.findall('ProductId = 0', shop))} developer product(s) have ProductId = 0: hidden in the Robux shop until you paste real ids (ShopConfig)")

# 7. placeholders left in the game
for path in luau_files():
    if "Content/" in path.replace("\\", "/") and os.path.basename(path).startswith("_"):
        continue
    for number, line in enumerate(read(path).splitlines(), 1):
        if re.search(r"\b(TODO|FIXME|XXX)\b|lorem ipsum|PLACEHOLDER_", line, re.I) and "PLACEHOLDER" not in line.upper().replace("PLACEHOLDERTEXT", ""):
            warnings.append(f"{rel(path)}:{number}: leftover marker: {line.strip()[:80]}")

# 8. discord / admin defaults for a release build
admin = read(os.path.join(SRC, "ServerScriptService", "Config", "AdminConfig.luau"))
if "CreatorIsOwner = true" in admin:
    warnings.append("AdminConfig.CreatorIsOwner = true: the experience creator is Owner as well (fine if intended)")
if re.search(r"OwnerUserIds = \{\s*(0,?\s*)?\}", admin):
    errors.append("AdminConfig.OwnerUserIds has no real UserId")
if "DiscordConfig.Enabled = false" in discord_cfg:
    warnings.append("Discord logging is switched off (DiscordConfig.Enabled = false). Fine until you set up the webhook (docs/MAINTENANCE.md, chapter Discord)")

# 9. animation catalog + community settings
import subprocess
doc_check = subprocess.run([sys.executable, os.path.join(ROOT, "tools", "ReleaseCheck", "gen_animation_docs.py"), "--check"], capture_output=True, text=True)
if doc_check.returncode != 0:
    errors.append("docs/ANIMATIONS.md is out of date: run python3 tools/ReleaseCheck/gen_animation_docs.py")
catalog = read(os.path.join(SRC, "ReplicatedStorage", "Modules", "ActionCatalog.luau"))
animation_names = {m for p in glob.glob(os.path.join(SRC, "ReplicatedStorage", "Modules", "Content", "Animations", "*.luau")) if not os.path.basename(p).startswith("_") for m in re.findall(r"\bName = \"([^\"]+)\"", read(p))}
for name in re.findall(r"\bAnimation = \"([A-Za-z0-9_]+)\"", catalog):
    if name not in animation_names:
        errors.append(f"ActionCatalog refers to the animation '{name}' that does not exist in Content/Animations")
if re.search(r"rbxassetid://\d+", catalog):
    errors.append("ActionCatalog contains an asset id: ids belong in Content/Animations files only")
overrides = read(os.path.join(SRC, "ReplicatedStorage", "Modules", "IconOverrides.luau"))
for key, value in re.findall(r"^\s+([a-z_0-9]+) = \"([^\"]*)\",", overrides.split("IconOverrides.Images = {", 1)[1].split("}", 1)[0] if "IconOverrides.Images = {" in overrides else "", re.M):
    if not re.fullmatch(r"rbxassetid://\d+", value):
        errors.append(f"IconOverrides: '{key}' = '{value}' is not written like rbxassetid://<digits> (it would be ignored)")
    if key not in known:
        errors.append(f"IconOverrides: there is no icon called '{key}' (see Icons.luau)")
social = read(os.path.join(SRC, "ReplicatedStorage", "Modules", "SocialConfig.luau"))
if re.search(r"SocialConfig\.GroupId = 0\b", social):
    warnings.append("SocialConfig.GroupId = 0: the Community window hides the group row until you fill in your group (docs/MAINTENANCE.md)")

# ---------------------------------------------------------------------------
print(f"release check: {len(errors)} error(s), {len(warnings)} warning(s)")
for line in errors:
    print("  ERROR  " + line)
for line in warnings:
    print("  warn   " + line)
if errors or ("--strict" in sys.argv and warnings):
    sys.exit(1)
