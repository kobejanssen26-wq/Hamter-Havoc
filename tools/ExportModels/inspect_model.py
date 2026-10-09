#!/usr/bin/env python3
"""Prints the hierarchy of a .rbxm / .rbxmx file: classes, names, key properties, references, attributes, scripts.
    python3 tools/ExportModels/inspect_model.py ModelLibrary/Hamsters/Hamster_Default.rbxm [--depth 3] [--props]
Uses Rojo only as a format converter (binary -> XML), so what you see is what is in the file."""
import argparse, base64, os, shutil, struct, subprocess, sys, tempfile, json
import xml.etree.ElementTree as ET

def rojo_path():
    for p in (os.environ.get("ROJO"), shutil.which("rojo"), os.path.expanduser("~/.rokit/bin/rojo")):
        if p and os.path.exists(p):
            return p
    sys.exit("rojo not found (set $ROJO)")

def load(path):
    if path.endswith(".rbxmx"):
        return ET.parse(path).getroot()
    with tempfile.TemporaryDirectory() as d:
        name = os.path.basename(path)
        shutil.copy(path, os.path.join(d, name))
        json.dump({"name": os.path.splitext(name)[0], "tree": {"$path": name}}, open(os.path.join(d, "p.project.json"), "w"))
        out = os.path.join(d, "o.rbxmx")
        subprocess.run([rojo_path(), "build", os.path.join(d, "p.project.json"), "-o", out], check=True, capture_output=True)
        return ET.parse(out).getroot()

def attributes(b64):
    data = base64.b64decode(b64)
    count = struct.unpack_from("<I", data, 0)[0]
    pos, out = 4, {}
    for _ in range(count):
        n = struct.unpack_from("<I", data, pos)[0]; pos += 4
        key = data[pos:pos + n].decode(); pos += n
        kind = data[pos]; pos += 1
        if kind == 2:
            n = struct.unpack_from("<I", data, pos)[0]; pos += 4
            out[key] = data[pos:pos + n].decode(); pos += n
        elif kind == 3:
            out[key] = bool(data[pos]); pos += 1
        elif kind == 6:
            out[key] = struct.unpack_from("<d", data, pos)[0]; pos += 8
        elif kind == 0x11:
            out[key] = struct.unpack_from("<fff", data, pos); pos += 12
        elif kind == 0x0F:
            out[key] = struct.unpack_from("<fff", data, pos); pos += 12
        else:
            out[key] = f"<type {kind}>"; break
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("file"); ap.add_argument("--depth", type=int, default=2); ap.add_argument("--props", action="store_true")
    a = ap.parse_args()
    root = load(a.file)
    names = {}
    def collect(item):
        names[item.get("referent")] = item.find("Properties").find("string[@name='Name']").text
        for c in item.findall("Item"): collect(c)
    for top in root.findall("Item"): collect(top)
    counts = {}
    def show(item, depth):
        props = item.find("Properties")
        cls = item.get("class"); counts[cls] = counts.get(cls, 0) + 1
        if depth <= a.depth:
            extra = []
            for el in props:
                n = el.get("name")
                if el.tag == "Ref":
                    if el.text and el.text != "null": extra.append(f"{n}->{names.get(el.text, '?')}")
                elif n == "AttributesSerialize" and el.text: extra.append("attributes=" + json.dumps(attributes(el.text)))
                elif n == "Size": extra.append("Size=(%s,%s,%s)" % tuple(round(float(el.find(k).text), 2) for k in "XYZ"))
                elif n == "RunContext": extra.append("RunContext=" + {"0": "Legacy", "1": "Server", "2": "Client"}.get(el.text, el.text))
                elif n == "Tags" and el.text: extra.append("tags=" + repr(base64.b64decode(el.text).decode().split("\0")))
                elif a.props and n not in ("Name", "AttributesSerialize", "Tags", "Source"): extra.append(f"{n}={el.text.strip() if el.text and el.text.strip() else el.tag}")
            src = next((e for e in props if e.get("name") == "Source"), None)
            if src is not None: extra.append(f"Source={len((src.text or '').splitlines())} lines")
            print("  " * depth + f"{cls} {names[item.get('referent')]!r} " + " ".join(extra))
        for c in item.findall("Item"): show(c, depth + 1)
    for top in root.findall("Item"): show(top, 0)
    print("\ntotal:", sum(counts.values()), "instances;", ", ".join(f"{k} x{v}" for k, v in sorted(counts.items(), key=lambda kv: -kv[1])))

main()
