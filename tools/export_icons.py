#!/usr/bin/env python3
"""Render IconShapes (exported as JSON by tools/lune/export_icon_data.luau) to PNG files.

usage: export_icons.py icons.json out_dir [size=256]
The PNGs match the in-game vector icons (UI/Icons) and can be uploaded to Roblox as decals.
"""
import json, math, os, sys
from PIL import Image, ImageDraw, ImageFont

SS = 4  # supersampling

def hexc(h, alpha=255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), alpha)

def rounded_mask(w, h, radius):
    m = Image.new("L", (max(1, w), max(1, h)), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, w - 1, h - 1], radius=radius, fill=255)
    return m

def find_font(size):
    for path in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/dejavu/DejaVuSans-Bold.ttf"]:
        if os.path.exists(path):
            return ImageFont.truetype(path, size)
    return ImageFont.load_default()

def draw_shape(canvas, shape, scale):
    w = max(1, int(round(shape["w"] * scale)))
    h = max(1, int(round(shape["h"] * scale)))
    rad = shape.get("rad", 0) * min(w, h) * 2 if shape.get("rad", 0) < 0.5 else min(w, h) / 2
    sw = shape.get("sw", 0) * scale
    pad = int(sw) + 2
    layer = Image.new("RGBA", (w + 2 * pad, h + 2 * pad), (0, 0, 0, 0))
    alpha = int(round(255 * (1 - shape.get("t", 0))))
    if "c" in shape and alpha > 0:
        top = hexc(shape["c"])
        bottom = hexc(shape.get("g", shape["c"]))
        grad = Image.new("RGBA", (w, h))
        gd = ImageDraw.Draw(grad)
        for y in range(h):
            k = y / max(1, h - 1)
            gd.line([(0, y), (w, y)], fill=tuple(int(top[i] * (1 - k) + bottom[i] * k) for i in range(3)) + (alpha,))
        mask = rounded_mask(w, h, rad)
        layer.paste(grad, (pad, pad), mask)
    if sw > 0 and "s" in shape:
        ImageDraw.Draw(layer).rounded_rectangle([pad - sw / 2, pad - sw / 2, pad + w - 1 + sw / 2, pad + h - 1 + sw / 2], radius=rad + sw / 2, outline=hexc(shape["s"]), width=max(1, int(round(sw))))
    if "txt" in shape:
        font = find_font(int(h * 0.9))
        d = ImageDraw.Draw(layer)
        bbox = d.textbbox((0, 0), shape["txt"], font=font)
        tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
        d.text((pad + (w - tw) / 2 - bbox[0], pad + (h - th) / 2 - bbox[1]), shape["txt"], font=font, fill=hexc(shape.get("tc", "FFFFFF")))
    r = shape.get("r", 0)
    if r:
        layer = layer.rotate(-r, resample=Image.BICUBIC, expand=True)
    cx, cy = shape["x"] * scale, shape["y"] * scale
    canvas.alpha_composite(layer, (int(round(cx - layer.width / 2)), int(round(cy - layer.height / 2))))

def render(shapes, size):
    big = size * SS
    canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    for shape in shapes:
        draw_shape(canvas, shape, big / 100)
    return canvas.resize((size, size), Image.LANCZOS)

def main():
    data = json.load(open(sys.argv[1]))
    out = sys.argv[2]
    size = int(sys.argv[3]) if len(sys.argv) > 3 else 256
    os.makedirs(out, exist_ok=True)
    for name, shapes in sorted(data["Icons"].items()):
        render(shapes, size).save(os.path.join(out, name + ".png"))
    # contact sheet for a quick look
    names = sorted(data["Icons"])
    cols = 8
    cell = 96
    rows = math.ceil(len(names) / cols)
    sheet = Image.new("RGBA", (cols * cell, rows * (cell + 18)), (255, 248, 238, 255))
    d = ImageDraw.Draw(sheet)
    for i, name in enumerate(names):
        img = render(data["Icons"][name], 80)
        x, y = (i % cols) * cell, (i // cols) * (cell + 18)
        sheet.alpha_composite(img, (x + 8, y + 4))
        d.text((x + 6, y + 84), name, fill=(60, 44, 46, 255))
    sheet.save(os.path.join(out, "_contact_sheet.png"))
    print("exported", len(names), "icons to", out)

if __name__ == "__main__":
    main()
