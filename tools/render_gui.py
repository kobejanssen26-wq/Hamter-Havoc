#!/usr/bin/env python3
"""Render a dumped Roblox GUI tree (tools/lune/guidump.luau) to a PNG: UI screenshots without Studio.

Supports what Hamster Plaza's UI uses: Frames/labels/buttons, UDim2 positions and sizes, AnchorPoint,
UICorner, UIStroke, UIGradient, UIScale, UIPadding, UIListLayout, UIGridLayout, AutomaticSize (text),
RichText colours, rotation, clipping (ScrollingFrame / ClipsDescendants). 3D ViewportFrames and avatar
images are drawn as placeholders. Fonts: Fredoka One for FredokaOne, Montserrat for Gotham.

usage: render_gui.py dump.json out.png [--size 1280x720] [--fonts dir] [--backdrop image.png]
"""
import argparse, json, math, os, re
from PIL import Image, ImageDraw, ImageFont, ImageFilter

SS = 2  # supersampling for smooth corners
FONT_DIR = "/tmp/claude-0/fonts"
_font_cache = {}


def font_for(name, size):
    name = name or "GothamBold"
    if name in ("FredokaOne",):
        path = "fredoka.ttf"
    elif name in ("GothamMedium", "Gotham"):
        path = "mont500.ttf"
    else:
        path = "mont700.ttf"
    key = (path, int(size))
    if key not in _font_cache:
        full = os.path.join(FONT_DIR, path)
        try:
            _font_cache[key] = ImageFont.truetype(full, max(4, int(size)))
        except OSError:
            _font_cache[key] = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", max(4, int(size)))
    return _font_cache[key]


def rgb(c, alpha=1.0):
    return (int(c[0] * 255), int(c[1] * 255), int(c[2] * 255), int(max(0, min(1, alpha)) * 255))


TAG = re.compile(r"<(/?)(font|b|i|u)([^>]*)>")


def rich_segments(text, base_color, rich):
    """Split RichText into (text, color, bold) runs per line."""
    text = text.replace("&lt;", "<").replace("&gt;", ">").replace("&amp;", "&")
    if not rich:
        return [[(line, base_color, False)] for line in text.split("\n")]
    lines = [[]]
    color_stack = [base_color]
    bold = 0
    pos = 0
    for m in TAG.finditer(text):
        chunk = text[pos:m.start()]
        pos = m.end()
        for i, part in enumerate(chunk.split("\n")):
            if i > 0:
                lines.append([])
            if part:
                lines[-1].append((part, color_stack[-1], bold > 0))
        closing, tag, attrs = m.group(1), m.group(2), m.group(3)
        if tag == "font":
            if closing:
                if len(color_stack) > 1:
                    color_stack.pop()
            else:
                cm = re.search(r'color="#?([0-9a-fA-F]{6})"', attrs)
                if cm:
                    h = cm.group(1)
                    color_stack.append((int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255))
                else:
                    color_stack.append(color_stack[-1])
        elif tag == "b":
            bold += -1 if closing else 1
    chunk = text[pos:]
    for i, part in enumerate(chunk.split("\n")):
        if i > 0:
            lines.append([])
        if part:
            lines[-1].append((part, color_stack[-1], bold > 0))
    return lines


def text_width(segments, font):
    return sum(font.getlength(t) for t, _, _ in segments)


def wrap_lines(lines, font, width):
    out = []
    for segs in lines:
        current, cur_w = [], 0
        for text, color, bold in segs:
            words = re.split(r"(\s+)", text)
            for word in words:
                w = font.getlength(word)
                if cur_w + w > width and cur_w > 0 and word.strip():
                    out.append(current)
                    current, cur_w = [], 0
                    word = word.lstrip()
                    w = font.getlength(word)
                current.append((word, color, bold))
                cur_w += w
        out.append(current)
    return out


class Renderer:
    def __init__(self, W, H, backdrop=None):
        self.W, self.H = W, H
        if backdrop:
            self.img = Image.open(backdrop).convert("RGBA").resize((W * SS, H * SS))
        else:
            self.img = Image.new("RGBA", (W * SS, H * SS), (122, 170, 104, 255))
            d = ImageDraw.Draw(self.img)
            for y in range(H * SS):
                k = y / (H * SS)
                if k < 0.45:
                    c = (int(150 + 60 * k), int(200 + 20 * k), 255, 255)
                else:
                    c = (int(118 - 30 * (k - 0.45)), int(176 - 40 * (k - 0.45)), int(98 - 20 * (k - 0.45)), 255)
                d.line([(0, y), (W * SS, y)], fill=c)

    # ---------------------------------------------------------------- helpers
    @staticmethod
    def mods(node):
        m = {}
        for child in node.get("k", []):
            c = child["c"]
            if c in ("UICorner", "UIStroke", "UIGradient", "UIScale", "UIListLayout", "UIGridLayout", "UIPadding"):
                m.setdefault(c, child)
        return m

    @staticmethod
    def gui_children(node):
        kids = [c for c in node.get("k", []) if c["c"] not in ("UICorner", "UIStroke", "UIGradient", "UIScale", "UIListLayout", "UIGridLayout", "UIPadding")]
        return sorted(kids, key=lambda c: c.get("z") or 0)  # Sibling ZIndexBehavior: draw order by ZIndex

    def natural_size(self, node, k, parent_w, parent_h):
        size = node.get("size") or [0, 0, 0, 0]
        w = size[0] * parent_w + size[1] * k
        h = size[2] * parent_h + size[3] * k
        auto = node.get("auto") or "None"
        mods = self.mods(node)
        s = mods.get("UIScale", {}).get("s", 1) or 1
        if auto != "None":
            nw, nh = w, h
            if node.get("text") is not None:
                font = font_for(node.get("font"), (node.get("ts") or 14) * k)
                lines = rich_segments(node.get("text") or "", (0, 0, 0), node.get("rich"))
                tw = max((text_width(l, font) for l in lines), default=0)
                nw = max(w, tw + 2 * k)
            kids = [c for c in self.gui_children(node) if c.get("vis", True) is not False]
            pad = mods.get("UIPadding")
            pl = (pad["l"][1] + pad["r"][1]) * k if pad else 0
            lst = mods.get("UIListLayout")
            if kids and lst and lst.get("dir") == "Horizontal":
                gap = lst["pad"][1] * k
                total = 0
                for kid in kids:
                    kw, kh = self.natural_size(kid, k, w, h)
                    total += kw
                nw = max(nw, total + gap * (len(kids) - 1) + pl)
            elif kids:
                for kid in kids:
                    kw, kh = self.natural_size(kid, k, w, h)
                    kx = (kid.get("pos") or [0, 0, 0, 0])[1] * k
                    nw = max(nw, kx + kw + pl)
            if "X" in auto or auto == "XY":
                w = nw
            if "Y" in auto or auto == "XY":
                h = nh
        return w * s, h * s

    # ---------------------------------------------------------------- drawing
    def draw_box(self, node, rect, clip):
        x, y, w, h = rect
        if w < 0.5 or h < 0.5:
            return
        mods = self.mods(node)
        S = SS
        lw, lh = int(math.ceil(w * S)) + 4, int(math.ceil(h * S)) + 4
        layer = Image.new("RGBA", (lw, lh), (0, 0, 0, 0))
        corner = mods.get("UICorner")
        radius = 0
        if corner:
            radius = (corner["r"][0] * min(w, h) * 2 if corner["r"][0] > 0 else corner["r"][1]) * S
            radius = min(radius, min(w, h) * S / 2)
        box = [2, 2, 2 + w * S - 1, 2 + h * S - 1]
        bgt = node.get("bgt", 0) if node.get("bgt") is not None else 0
        bg = node.get("bg")
        if bg and bgt < 0.999:
            grad = mods.get("UIGradient")
            if grad and grad.get("on", True) is not False and grad.get("from"):
                fill = Image.new("RGBA", (lw, lh))
                gd = ImageDraw.Draw(fill)
                rot = (grad.get("rot") or 0) % 360
                for i in range(lh if rot in (90, 270) else lw):
                    t = i / max(1, (lh if rot in (90, 270) else lw) - 1)
                    if rot == 270 or rot == 180:
                        t = 1 - t
                    c = [bg[j] * (grad["from"][j] * (1 - t) + grad["to"][j] * t) for j in range(3)]
                    col = rgb(c, 1 - bgt)
                    if rot in (90, 270):
                        gd.line([(0, i), (lw, i)], fill=col)
                    else:
                        gd.line([(i, 0), (i, lh)], fill=col)
                mask = Image.new("L", (lw, lh), 0)
                ImageDraw.Draw(mask).rounded_rectangle(box, radius=radius, fill=255)
                layer.paste(fill, (0, 0), mask)
            else:
                ImageDraw.Draw(layer).rounded_rectangle(box, radius=radius, fill=rgb(bg, 1 - bgt))
        stroke = mods.get("UIStroke")
        is_text = node.get("text") is not None
        if stroke and stroke.get("on", True) is not False and (stroke.get("mode") != "Contextual" or not is_text):
            th = (stroke.get("th") or 1) * S * self.k_for(node)
            col = rgb(stroke.get("col") or (0, 0, 0), 1 - (stroke.get("t") or 0))
            pad = th
            big = Image.new("RGBA", (lw + int(2 * pad) + 2, lh + int(2 * pad) + 2), (0, 0, 0, 0))
            ImageDraw.Draw(big).rounded_rectangle([pad - th / 2 + 2, pad - th / 2 + 2, pad + w * S + th / 2, pad + h * S + th / 2], radius=radius + th / 2, outline=col, width=max(1, int(round(th))))
            big.alpha_composite(layer, (int(pad), int(pad)))
            layer = big
            offset = pad
        else:
            offset = 0
        if is_text and node.get("text"):
            self.draw_text(node, layer, (2 + offset, 2 + offset, w * S, h * S), stroke)
        if node["c"] == "ViewportFrame":
            d = ImageDraw.Draw(layer)
            r = min(w, h) * S * 0.32
            cx, cy = 2 + offset + w * S / 2, 2 + offset + h * S / 2
            d.ellipse([cx - r, cy - r * 0.9, cx + r, cy + r * 0.9], fill=(232, 170, 110, 255), outline=(150, 96, 60, 255), width=3)
            d.ellipse([cx - r * 0.8, cy - r * 1.05, cx - r * 0.35, cy - r * 0.6], fill=(214, 140, 80, 255))
            d.ellipse([cx + r * 0.35, cy - r * 1.05, cx + r * 0.8, cy - r * 0.6], fill=(214, 140, 80, 255))
        if node["c"] in ("ImageLabel", "ImageButton") and node.get("image"):
            d = ImageDraw.Draw(layer)
            d.rounded_rectangle([2 + offset, 2 + offset, 2 + offset + w * S, 2 + offset + h * S], radius=radius, fill=(190, 176, 200, 255))
        rot = node.get("rot") or 0
        if rot:
            layer = layer.rotate(-rot, resample=Image.BICUBIC, expand=True)
        cx, cy = (x + w / 2) * S, (y + h / 2) * S
        px, py = int(round(cx - layer.width / 2)), int(round(cy - layer.height / 2))
        self.composite(layer, px, py, clip)

    def k_for(self, node):
        return node.get("_k", 1)

    def draw_text(self, node, layer, box, stroke):
        bx, by, bw, bh = box
        k = self.k_for(node)
        size = (node.get("ts") or 14) * k * SS
        base = node.get("tc") or (0, 0, 0)
        if node.get("placeholder"):
            base = (0.6, 0.55, 0.55)
        lines = rich_segments(node["text"], base, node.get("rich"))
        font = font_for(node.get("font"), size)
        if node.get("scaled"):
            size = bh * 0.82
            font = font_for(node.get("font"), size)
            longest = max((text_width(l, font) for l in lines), default=1)
            if longest > bw * 0.98 and longest > 0:
                size *= bw * 0.98 / longest
                font = font_for(node.get("font"), size)
            size = min(size, bh / max(1, len(lines)) * 0.92)
            font = font_for(node.get("font"), size)
        if node.get("wrap"):
            lines = wrap_lines(lines, font, bw)
        line_h = size * 1.18
        total_h = line_h * len(lines)
        ty = node.get("ty") or "Center"
        y0 = by + (0 if ty == "Top" else (bh - total_h if ty == "Bottom" else (bh - total_h) / 2))
        d = ImageDraw.Draw(layer)
        alpha = 1 - (node.get("tt") or 0)
        outline = None
        if stroke and stroke.get("on", True) is not False and stroke.get("mode") == "Contextual":
            outline = (rgb(stroke.get("col") or (0, 0, 0), (1 - (stroke.get("t") or 0)) * alpha), max(1, int((stroke.get("th") or 1) * k * SS)))
        for i, segs in enumerate(lines):
            lw = text_width(segs, font)
            tx = node.get("tx") or "Center"
            x0 = bx + (0 if tx == "Left" else (bw - lw if tx == "Right" else (bw - lw) / 2))
            yy = y0 + i * line_h + (line_h - size) / 2 - size * 0.08
            for text, color, bold in segs:
                f = font_for("GothamBlack" if bold and node.get("font") != "FredokaOne" else node.get("font"), size)
                kwargs = {}
                if outline:
                    kwargs = {"stroke_width": outline[1], "stroke_fill": outline[0]}
                d.text((x0, yy), text, font=f, fill=rgb(color, alpha), **kwargs)
                x0 += f.getlength(text)

    def composite(self, layer, px, py, clip):
        if clip:
            cx0, cy0, cx1, cy1 = [int(v * SS) for v in clip]
            lx0, ly0 = max(px, cx0), max(py, cy0)
            lx1, ly1 = min(px + layer.width, cx1), min(py + layer.height, cy1)
            if lx1 <= lx0 or ly1 <= ly0:
                return
            layer = layer.crop((lx0 - px, ly0 - py, lx1 - px, ly1 - py))
            px, py = lx0, ly0
        if px >= self.img.width or py >= self.img.height:
            return
        if px < 0 or py < 0:
            layer = layer.crop((max(0, -px), max(0, -py), layer.width, layer.height))
            px, py = max(0, px), max(0, py)
        self.img.alpha_composite(layer, (px, py))

    # ---------------------------------------------------------------- layout
    def render_node(self, node, rect, k, clip):
        if node.get("vis", True) is False:
            return
        node["_k"] = k
        x, y, w, h = rect
        self.draw_box(node, rect, clip)
        mods = self.mods(node)
        child_clip = clip
        if node.get("clip") or node["c"] == "ScrollingFrame":
            box = (x, y, x + w, y + h)
            child_clip = box if not clip else (max(box[0], clip[0]), max(box[1], clip[1]), min(box[2], clip[2]), min(box[3], clip[3]))
        self.layout_children(node, rect, k, child_clip)

    def layout_children(self, node, rect, k, clip):
        x, y, w, h = rect
        mods = self.mods(node)
        pad = mods.get("UIPadding")
        if pad:
            pl = pad["l"][0] * w + pad["l"][1] * k
            pr = pad["r"][0] * w + pad["r"][1] * k
            pt = pad["t"][0] * h + pad["t"][1] * k
            pb = pad["b"][0] * h + pad["b"][1] * k
            x, y, w, h = x + pl, y + pt, w - pl - pr, h - pt - pb
        kids = [c for c in self.gui_children(node) if c.get("vis", True) is not False]
        lst = mods.get("UIListLayout")
        grid = mods.get("UIGridLayout")
        if grid:
            cell = grid["cell"]
            cw, ch = cell[0] * w + cell[1] * k, cell[2] * h + cell[3] * k
            gp = grid["cpad"]
            gx, gy = gp[0] * w + gp[1] * k, gp[2] * h + gp[3] * k
            per_row = grid.get("max") or 0
            fit = max(1, int((w + gx) // (cw + gx)))
            per_row = min(per_row, fit) if per_row else fit
            kids.sort(key=lambda c: c.get("lo") or 0)
            rows_w = per_row * cw + (per_row - 1) * gx
            x0 = x + ((w - rows_w) / 2 if grid.get("ha") == "Center" else 0)
            for i, kid in enumerate(kids):
                r, c = divmod(i, per_row)
                self.place(kid, (x0 + c * (cw + gx), y + r * (ch + gy), cw, ch), k, clip, fixed=True)
            return
        if lst:
            kids.sort(key=lambda c: c.get("lo") or 0)
            horizontal = lst.get("dir") == "Horizontal"
            gap = lst["pad"][0] * (w if horizontal else h) + lst["pad"][1] * k
            sizes = [self.natural_size(kid, k, w, h) for kid in kids]
            total = sum(s[0] if horizontal else s[1] for s in sizes) + gap * max(0, len(kids) - 1)
            ha, va = lst.get("ha") or "Left", lst.get("va") or "Top"
            if horizontal and lst.get("wraps"):
                cx, cy, row_h = x, y, 0
                for kid, (kw, kh) in zip(kids, sizes):
                    if cx > x and cx + kw > x + w + 0.5:
                        cx, cy, row_h = x, cy + row_h + gap, 0
                    self.place(kid, (cx, cy, kw, kh), k, clip, fixed=True)
                    cx += kw + gap
                    row_h = max(row_h, kh)
                return
            if horizontal:
                cx = x + (0 if ha == "Left" else ((w - total) / 2 if ha == "Center" else w - total))
                for kid, (kw, kh) in zip(kids, sizes):
                    ky = y + (0 if va == "Top" else ((h - kh) / 2 if va == "Center" else h - kh))
                    self.place(kid, (cx, ky, kw, kh), k, clip, fixed=True)
                    cx += kw + gap
            else:
                cy = y + (0 if va == "Top" else ((h - total) / 2 if va == "Center" else h - total))
                for kid, (kw, kh) in zip(kids, sizes):
                    kx = x + (0 if ha == "Left" else ((w - kw) / 2 if ha == "Center" else w - kw))
                    self.place(kid, (kx, cy, kw, kh), k, clip, fixed=True)
                    cy += kh + gap
            return
        for kid in kids:
            kw, kh = self.natural_size(kid, k, w, h)
            pos = kid.get("pos") or [0, 0, 0, 0]
            anchor = kid.get("anchor") or [0, 0]
            kx = x + pos[0] * w + pos[1] * k - anchor[0] * kw
            ky = y + pos[2] * h + pos[3] * k - anchor[1] * kh
            self.place(kid, (kx, ky, kw, kh), k, clip, fixed=False)

    def place(self, kid, rect, k, clip, fixed):
        s = self.mods(kid).get("UIScale", {}).get("s", 1) or 1
        self.render_node(kid, rect, k * s, clip)

    def render(self, guis):
        for gui in guis:
            if gui.get("on") is False:
                continue
            gui["_k"] = 1
            self.layout_children(gui, (0, 0, self.W, self.H), 1, None)
        return self.img.resize((self.W, self.H), Image.LANCZOS)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--size", default="1280x720")
    ap.add_argument("--fonts", default="/tmp/claude-0/fonts")
    ap.add_argument("--backdrop")
    a = ap.parse_args()
    globals()["FONT_DIR"] = a.fonts
    W, H = map(int, a.size.split("x"))
    guis = json.load(open(a.src))
    Renderer(W, H, a.backdrop).render(guis).convert("RGB").save(a.out)
    print("rendered", a.out)


if __name__ == "__main__":
    main()
