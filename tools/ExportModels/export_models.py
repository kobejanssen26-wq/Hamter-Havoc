#!/usr/bin/env python3
"""
Exports every asset in ModelLibrary/ to a genuine Roblox model file (.rbxm).

  python3 tools/ExportModels/export_models.py                 # build everything, report what changed, write NEW files only
  python3 tools/ExportModels/export_models.py --update        # also overwrite files whose content changed (prints a diff summary)
  python3 tools/ExportModels/export_models.py --only Hamster_Default
  python3 tools/ExportModels/export_models.py --check         # exit 1 if any export is out of date (use in CI / before commit)

How it works (see tools/ExportModels/README.md):
  1. harness/gen.py wraps the game's real scripts + the library's build-model.lua files for a mock Roblox runtime
  2. `luau` runs exporter/export_scene.lua, which builds each asset with the game's own builder code and prints it as JSON
  3. this script turns that JSON into a Rojo project, lets `rojo build` create an .rbxmx (Rojo knows every property type and enum value),
     patches in what Rojo's project format cannot express (duplicate sibling names, Part0/Part1/PrimaryPart references),
     and lets Rojo write the final binary .rbxm
  4. the .rbxm is read back and verified (instance count, names, references, scripts)
  5. ModelLibrary/README.md (the catalog) is regenerated from the files that really exist
"""
import argparse, hashlib, json, os, re, shutil, subprocess, sys, tempfile
import xml.etree.ElementTree as ET

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
LIB = os.path.join(ROOT, "ModelLibrary")
HARNESS = os.path.join(HERE, "harness")


def find_tool(name, env):
    candidates = [os.environ.get(env), shutil.which(name), os.path.expanduser("~/.rokit/bin/" + name), os.path.expanduser("~/.aftman/bin/" + name)]
    for path in candidates:
        if path and os.path.exists(path):
            return path
    sys.exit(f"error: `{name}` not found. Install it (rokit add {'rojo-rbx/rojo' if name == 'rojo' else 'luau-lang/luau'}) or set ${env}.")


def run(cmd, **kw):
    result = subprocess.run(cmd, capture_output=True, text=True, **kw)
    if result.returncode != 0:
        sys.exit(f"command failed: {' '.join(cmd)}\n{result.stdout}\n{result.stderr}")
    return result


# ------------------------------------------------------------------------------------------------ scene run
def run_scene(luau, scene="export_scene.lua", folder="exporter"):
    run([sys.executable, os.path.join(HARNESS, "gen.py"), os.path.join(HERE, "exporter", "context.lua"), os.path.join(HERE, folder, scene)])
    result = subprocess.run([luau, "run.lua"], cwd=HARNESS, capture_output=True, text=True)
    metas, exports, warns, fails = {}, {}, [], {}
    done = None
    for line in result.stdout.splitlines():
        if line.startswith("META|"):
            _, name, body = line.split("|", 2)
            metas[name] = json.loads(body)
        elif line.startswith("EXPORT|"):
            _, name, body = line.split("|", 2)
            exports[name] = json.loads(body)
        elif line.startswith("INFO|"):
            print("info:", line[5:].replace("|", ": ", 1))
        elif line.startswith("WARN|"):
            warns.append(line[5:])
        elif line.startswith("FAIL|"):
            _, name, why = line.split("|", 2)
            fails[name] = why
        elif line.startswith("DONE|"):
            done = line
    if done is None:
        sys.exit("exporter did not finish:\n" + result.stdout[-2000:] + result.stderr[-2000:])
    return metas, exports, warns, fails


def run_scene_tests(luau):
    run([sys.executable, os.path.join(HARNESS, "gen.py"), os.path.join(HERE, "exporter", "context.lua"), os.path.join(HERE, "tests", "library_tests.lua")])
    result = subprocess.run([luau, "run.lua"], cwd=HARNESS, capture_output=True, text=True)
    print(result.stdout.strip())
    if result.stderr.strip():
        print(result.stderr.strip())
    sys.exit(0 if "FAIL 0" in result.stdout and result.returncode == 0 else 1)


# ------------------------------------------------------------------------------------------------ json -> rbxm
def to_project(name, export):
    order = []  # DFS list of nodes

    def project_node(node, is_root=False):
        index = len(order)
        order.append(node)
        out = {"$className": node["class"]}
        if node["props"] or node["tags"]:
            props = dict(node["props"])
            if node["tags"]:
                props["Tags"] = node["tags"]
            out["$properties"] = props
        if node["attrs"]:
            out["$attributes"] = node["attrs"]
        for child in node["children"]:
            child_index = len(order)
            out[f"{child_index:05d}~~{child['name']}"] = project_node(child)
        return out

    tree = project_node(export["tree"], True)
    return {"name": name, "tree": tree}, order


def patch_rbxmx(path, order, refs, root_name):
    tree = ET.parse(path)
    root = tree.getroot()
    items = []

    def collect(item):
        items.append(item)
        for child in item.findall("Item"):
            collect(child)

    for top in root.findall("Item"):
        collect(top)
    if len(items) != len(order):
        raise RuntimeError(f"Rojo produced {len(items)} instances, expected {len(order)}")
    for item, node in zip(items, order):
        props = item.find("Properties")
        name_el = props.find("string[@name='Name']")
        clean = re.sub(r"^\d{5}~~", "", name_el.text or "")
        name_el.text = clean
        if clean != node["name"] and item is not items[0]:
            raise RuntimeError(f"name mismatch: {clean!r} vs {node['name']!r}")
    items[0].find("Properties").find("string[@name='Name']").text = root_name
    for ref in refs:
        owner = items[ref["owner"]]
        target = items[ref["target"]]
        ref_el = ET.SubElement(owner.find("Properties"), "Ref", {"name": ref["prop"]})
        ref_el.text = target.get("referent")
    tree.write(path, encoding="utf-8", xml_declaration=False)


def build_rbxm(rojo, name, export, workdir):
    project, order = to_project(export["tree"]["name"], export)
    pdir = os.path.join(workdir, name)
    os.makedirs(pdir, exist_ok=True)
    pfile = os.path.join(pdir, "build.project.json")
    json.dump(project, open(pfile, "w"))
    xml_path = os.path.join(pdir, name + ".rbxmx")
    run([rojo, "build", pfile, "-o", xml_path])
    patch_rbxmx(xml_path, order, export["refs"], export["tree"]["name"])
    # a second project that points at the patched XML: Rojo converts it to the binary format
    json.dump({"name": name, "tree": {"$path": os.path.basename(xml_path)}}, open(os.path.join(pdir, "convert.project.json"), "w"))
    out = os.path.join(pdir, name + ".rbxm")
    run([rojo, "build", os.path.join(pdir, "convert.project.json"), "-o", out])
    return out, order


def verify_rbxm(rojo, path, name, order, refs, workdir):
    """Reads the binary file back (Rojo -> XML) and checks it against what was exported."""
    data = open(path, "rb").read()
    if not data.startswith(b"<roblox!\x89\xff\r\n\x1a\n"):
        raise RuntimeError("not a binary Roblox model (bad header)")
    pdir = os.path.join(workdir, name + "_verify")
    os.makedirs(pdir, exist_ok=True)
    shutil.copy(path, os.path.join(pdir, name + ".rbxm"))
    json.dump({"name": name, "tree": {"$path": name + ".rbxm"}}, open(os.path.join(pdir, "p.project.json"), "w"))
    back = os.path.join(pdir, "back.rbxmx")
    run([rojo, "build", os.path.join(pdir, "p.project.json"), "-o", back])
    root = ET.parse(back).getroot()
    items = []

    def collect(item):
        items.append(item)
        for child in item.findall("Item"):
            collect(child)

    for top in root.findall("Item"):
        collect(top)
    if len(items) != len(order):
        raise RuntimeError(f"read back {len(items)} instances, expected {len(order)}")
    for item, node in zip(items, order):
        if item.get("class") != node["class"]:
            raise RuntimeError(f"class mismatch {item.get('class')} vs {node['class']}")
        got = item.find("Properties").find("string[@name='Name']").text
        if item is not items[0] and got != node["name"]:
            raise RuntimeError(f"name mismatch {got!r} vs {node['name']!r}")
    # script sources survive byte for byte
    for item, node in zip(items, order):
        if item.get("class") in ("Script", "LocalScript", "ModuleScript"):
            got = next((el for el in item.find("Properties") if el.get("name") == "Source"), None)
            if got is None or (got.text or "") != node["props"].get("Source", ""):
                raise RuntimeError(f"script source of {node['name']} changed during export")
    found = 0
    for ref in refs:
        owner = items[ref["owner"]]
        props = owner.find("Properties")
        # Roblox stores WeldConstraint.Part0/Part1 under the name Part0Internal/Part1Internal
        el = props.find(f"Ref[@name='{ref['prop']}']")
        if el is None:
            el = props.find(f"Ref[@name='{ref['prop']}Internal']")
        if el is None or el.text != items[ref["target"]].get("referent"):
            raise RuntimeError(f"reference {ref['prop']} on {order[ref['owner']]['name']} did not survive")
        found += 1
    return {"instances": len(items), "refs": found, "scripts": sum(1 for i in items if i.get("class") in ("Script", "LocalScript", "ModuleScript"))}


# ------------------------------------------------------------------------------------------------ catalog
def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()[:12]


def count_instances(rojo, path):
    with tempfile.TemporaryDirectory() as d:
        name = os.path.basename(path)
        shutil.copy(path, os.path.join(d, name))
        json.dump({"name": os.path.splitext(name)[0], "tree": {"$path": name}}, open(os.path.join(d, "p.project.json"), "w"))
        out = os.path.join(d, "o.rbxmx")
        run([rojo, "build", os.path.join(d, "p.project.json"), "-o", out])
        return len(list(ET.parse(out).getroot().iter("Item")))


def write_catalog(entries, rojo):
    generated = {os.path.normpath(os.path.join(c["category"], c["file"])) for c in entries}
    # models saved by hand from Roblox Studio (see tools/ExportModels/plugin) are listed too, flagged as manual
    for dirpath, dirs, names in os.walk(LIB):
        dirs[:] = sorted(d for d in dirs if not d.startswith("_"))
        for n in sorted(names):
            rel = os.path.normpath(os.path.relpath(os.path.join(dirpath, n), LIB))
            if n.endswith((".rbxm", ".rbxmx")) and rel not in generated and os.sep in rel:
                category = rel.split(os.sep)[0]
                entries.append({"name": n, "title": os.path.splitext(n)[0].replace("_", " ") + " (saved from Studio)", "category": category, "file": rel[len(category) + 1:].replace(os.sep, "/"), "instances": count_instances(rojo, os.path.join(dirpath, n)), "dependencies": "See the asset's README", "reusable": "Yes"})
    header = open(os.path.join(HERE, "catalog_header.md")).read()
    rows = ["| Asset | Category | File | Instances | Dependencies | Reusable |", "|---|---|---|---|---|---|"]
    for e in sorted(entries, key=lambda x: (x["category"], x["name"])):
        rel = f"{e['category']}/{e['file']}"
        rows.append(f"| {e['title']} | {e['category']} | [`{e['file']}`]({rel}) | {e['instances']} | {e['dependencies']} | {e['reusable']} |")
    open(os.path.join(LIB, "README.md"), "w").write(header.rstrip() + "\n\n" + "\n".join(rows) + "\n\nSee each asset's own README (folder next to the file) for hierarchy, pivot, attributes and required scripts.\n")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--only", help="export one asset by name")
    parser.add_argument("--update", action="store_true", help="overwrite existing exports whose content changed")
    parser.add_argument("--test", action="store_true", help="run the behaviour tests (wheel spin direction/axis/pivot, hamster animation) against the library assets")
    parser.add_argument("--check", action="store_true", help="do not write; fail if exports are missing or out of date")
    args = parser.parse_args()
    rojo, luau = find_tool("rojo", "ROJO"), find_tool("luau", "LUAU")
    if args.test:
        run_scene_tests(luau)
        return

    metas, exports, warns, fails = run_scene(luau)
    problems = 0
    for name, why in fails.items():
        print(f"FAILED   {name}: {why}")
        problems += 1
    for w in warns:
        print("warning:", w)

    catalog = []
    with tempfile.TemporaryDirectory() as workdir:
        for name in sorted(exports):
            if args.only and name != args.only:
                continue
            meta = metas[name]
            config_dir = os.path.join(ROOT, meta["dir"])
            target = os.path.join(LIB, meta["category"], meta["file"])
            path, order = build_rbxm(rojo, name, exports[name], workdir)
            report = verify_rbxm(rojo, path, name, order, exports[name]["refs"], workdir)
            new_bytes = open(path, "rb").read()
            status = "new"
            if os.path.exists(target):
                same = open(target, "rb").read() == new_bytes
                status = "unchanged" if same else "CHANGED"
            if args.check:
                if status != "unchanged":
                    print(f"OUT OF DATE {name} ({status})")
                    problems += 1
                else:
                    print(f"ok       {name}")
            elif status == "CHANGED" and not args.update:
                print(f"CHANGED  {name}: the current game code produces a different model than {os.path.relpath(target, ROOT)}.")
                print("         Not overwritten. Re-run with --update to replace it (git keeps the old version).")
            else:
                if status != "unchanged":
                    os.makedirs(os.path.dirname(target), exist_ok=True)
                    shutil.copy(path, target)
                print(f"{'wrote' if status != 'unchanged' else 'unchanged':10}{name}  -> {os.path.relpath(target, ROOT)}  ({report['instances']} instances, {report['refs']} references, {report['scripts']} scripts, {len(new_bytes)} bytes)")
            catalog.append({"name": name, "title": meta.get("title", name), "category": meta["category"], "file": meta["file"], "instances": report["instances"], "dependencies": meta.get("dependencies", ""), "reusable": meta.get("reusable", "Yes")})
    if not args.check and not args.only and os.path.isdir(LIB):
        write_catalog([c for c in catalog if os.path.exists(os.path.join(LIB, c["category"], c["file"]))], rojo)
    sys.exit(1 if problems else 0)


if __name__ == "__main__":
    main()
