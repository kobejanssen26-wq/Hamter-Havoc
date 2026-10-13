#!/bin/bash
# Bakes the HUD ScreenGuis (MainUI, HotbarUI) into src/StarterGui/*.model.json - the Studio-editable HUD templates.
#   LUAU=/path/to/luau tools/SimTests/bake_hud.sh          write the templates
#   LUAU=... tools/SimTests/bake_hud.sh --check            exit 1 when the committed templates are out of date
# The templates are generated from the client code in the mock Roblox environment (so they are exactly what the code builds
# on a desktop at 1280x720). Edit the HUD in Studio afterwards; the code adopts your changes (docs/STUDIO_GUIDE.md).
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
LUAU="${LUAU:-luau}"
BUILD="$HERE/.build"
OUT="$HERE/../../src/StarterGui"
mkdir -p "$BUILD" "$OUT"
cp "$HERE/mock.lua" "$HERE/classes.lua" "$BUILD/"
cp "$HERE/scn_bake_hud.lua" "$BUILD/scn_bake_hud.lua"
(cd "$BUILD" && python3 "$HERE/gen.py" scn_bake_hud.lua >/dev/null && timeout 600 "$LUAU" run.lua 2>&1 | grep '^BAKE|' > "$BUILD/hud_bake.txt" || true)
python3 - "$OUT" "${1:-}" "$BUILD/hud_bake.txt" <<'PY'
import sys, json, os
out, mode, rawfile = sys.argv[1], sys.argv[2], sys.argv[3]
raw = open(rawfile).read()
changed = False
count = 0
for line in raw.splitlines():
    _, name, body = line.split("|", 2)
    doc = json.loads(body)
    doc.pop("Name", None)  # the file name is the instance name (a top-level Name is ignored by Rojo)
    text = json.dumps(doc, indent=1, ensure_ascii=False) + "\n"
    path = os.path.join(out, name + ".model.json")
    old = open(path).read() if os.path.exists(path) else None
    count += 1
    if old != text:
        changed = True
        if mode == "--check":
            print("OUT OF DATE:", path)
        else:
            open(path, "w").write(text)
            print("wrote", path, len(text), "bytes")
if count == 0:
    print("bake produced nothing"); sys.exit(2)
if mode == "--check" and changed:
    sys.exit(1)
print("ok" if mode == "--check" else "done")
PY
