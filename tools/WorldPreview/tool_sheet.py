#!/usr/bin/env python3
"""
Contact sheet of every weapon / gadget model, built by the REAL ToolBuilder (so what you see is what the player holds).
    LUAU=/path/to/luau python3 tools/WorldPreview/tool_sheet.py [out.png]
Needs the simulation tools (tools/SimTests) and Playwright's Chromium (see render.js).
"""
import json, os, subprocess, sys
from PIL import Image, ImageDraw
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", ".."))
OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/tool_sheet.png"
TMP = "/tmp/toolsheet"
os.makedirs(TMP, exist_ok=True)
run = subprocess.run([os.path.join(ROOT, "tools", "SimTests", "run.sh"), "scn_toolshow.lua"], capture_output=True, text=True, cwd=ROOT)
line = next((l for l in run.stdout.splitlines() if l.startswith("BAKE|ToolShowcase|")), None)
if not line:
    sys.exit("no ToolShowcase output:\n" + run.stdout[-800:] + run.stderr[-800:])
data = line.split("|", 2)[2]
json_path = os.path.join(TMP, "ToolShowcase.json")
open(json_path, "w").write(data)
names = [c["Name"] for c in json.loads(data)["Children"]]
tiles = []
for index, name in enumerate(names, 1):
    x = index * 14
    png = os.path.join(TMP, f"{name}.png")
    subprocess.run(["node", os.path.join(HERE, "render.js"), "--files", json_path, "--eye", f"{x+5},9.5,-8", "--target", f"{x},6,-0.5", "--fov", "42", "--size", "420x330", "--sky", "0.82,0.88,0.96", "--out", png], check=True, capture_output=True)
    tiles.append((name, Image.open(png)))
cols = 4
rows = (len(tiles) + cols - 1) // cols
sheet = Image.new("RGB", (cols * 420, rows * 330), (255, 255, 255))
draw = ImageDraw.Draw(sheet)
for i, (name, img) in enumerate(tiles):
    sheet.paste(img, ((i % cols) * 420, (i // cols) * 330))
    draw.text(((i % cols) * 420 + 8, (i // cols) * 330 + 6), name, fill=(40, 40, 60))
sheet.save(OUT)
print("wrote", OUT, len(tiles), "tools")
