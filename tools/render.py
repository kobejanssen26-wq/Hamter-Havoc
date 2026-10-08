#!/usr/bin/env python3
"""Tiny flat-shaded preview renderer for part dumps (JSON from tools/lune/*.luau).

Painter's algorithm, per-face Lambert shading, distance fog. Good enough to judge layout,
proportions and colours without Roblox Studio. Also used by the asset exporter for meshes.

usage: render.py parts.json out.png --eye x,y,z --at x,y,z [--fov 60] [--size 1600x900] [--ortho top:halfwidth]
"""
import argparse, json, math
import numpy as np
from PIL import Image, ImageDraw

SEG = 16
NEAR = 0.5

def clip_near(pts):
    """Sutherland-Hodgman clip of a camera-space polygon against z = NEAR."""
    out = []
    n = len(pts)
    for i in range(n):
        a, b = pts[i], pts[(i + 1) % n]
        ina, inb = a[2] >= NEAR, b[2] >= NEAR
        if ina:
            out.append(a)
        if ina != inb:
            t = (NEAR - a[2]) / (b[2] - a[2])
            out.append(a + (b - a) * t)
    return np.array(out)

def box_mesh():
    v = np.array([[x, y, z] for x in (-.5, .5) for y in (-.5, .5) for z in (-.5, .5)])
    faces = [(0,1,3,2),(4,6,7,5),(0,4,5,1),(2,3,7,6),(0,2,6,4),(1,5,7,3)]
    return v, faces

def wedge_mesh():
    # Roblox wedge: slope rises toward -Z; full height at back (-Z), zero at front (+Z)
    v = np.array([[-.5,-.5,-.5],[.5,-.5,-.5],[.5,-.5,.5],[-.5,-.5,.5],[-.5,.5,-.5],[.5,.5,-.5]])
    faces = [(0,3,2,1),(0,1,5,4),(3,4,5,2),(0,4,3),(1,2,5)]
    return v, faces

def cornerwedge_mesh():
    v = np.array([[-.5,-.5,-.5],[.5,-.5,-.5],[.5,-.5,.5],[-.5,-.5,.5],[.5,.5,-.5]])
    faces = [(0,3,2,1),(0,1,4),(1,2,4),(2,3,4),(3,0,4)]
    return v, faces

def cyl_mesh(n=SEG):
    # axis along X
    v = []
    for x in (-.5, .5):
        for i in range(n):
            a = 2*math.pi*i/n
            v.append([x, .5*math.cos(a), .5*math.sin(a)])
    faces = [tuple(range(n-1, -1, -1)), tuple(range(n, 2*n))]
    for i in range(n):
        j = (i+1) % n
        faces.append((i, j, n+j, n+i))
    return np.array(v), faces

def sphere_mesh(lat=8, lon=SEG):
    v = []
    for i in range(lat+1):
        t = math.pi*i/lat
        for j in range(lon):
            p = 2*math.pi*j/lon
            v.append([.5*math.sin(t)*math.cos(p), .5*math.cos(t), .5*math.sin(t)*math.sin(p)])
    faces = []
    for i in range(lat):
        for j in range(lon):
            a = i*lon+j; b = i*lon+(j+1)%lon
            c = (i+1)*lon+(j+1)%lon; d = (i+1)*lon+j
            faces.append((a, b, c, d))
    return np.array(v), faces

MESHES = {"box": box_mesh(), "wedge": wedge_mesh(), "cornerwedge": cornerwedge_mesh(),
          "cylinder": cyl_mesh(), "sphere": sphere_mesh(), "ball": sphere_mesh()}

TILE = 24.0

def subdivide(world, faces):
    """Yield faces as world-space vertex lists; big quads are split into tiles so depth sorting works."""
    for face in faces:
        pts = world[list(face)]
        if len(face) == 4:
            a, b, c, d = pts
            nu = max(1, int(math.ceil(max(np.linalg.norm(b - a), np.linalg.norm(c - d)) / TILE)))
            nv = max(1, int(math.ceil(max(np.linalg.norm(d - a), np.linalg.norm(c - b)) / TILE)))
            if nu * nv > 1:
                for i in range(nu):
                    for j in range(nv):
                        def P(u, v):
                            return (a * (1 - u) + b * u) * (1 - v) + (d * (1 - u) + c * u) * v
                        u0, u1, v0, v1 = i / nu, (i + 1) / nu, j / nv, (j + 1) / nv
                        yield [P(u0, v0), P(u1, v0), P(u1, v1), P(u0, v1)]
                continue
        yield list(pts)

def part_geometry(p, seg_scale=1):
    v, faces = MESHES.get(p["s"], MESHES["box"])
    cf = p["cf"]; pos = np.array(cf[:3]); R = np.array(cf[3:]).reshape(3, 3)
    sz = np.array(p["sz"])
    if p["s"] == "ball":
        d = min(sz); sz = np.array([d, d, d])
    if p["s"] == "cylinder":
        d = min(sz[1], sz[2]); sz = np.array([sz[0], d, d])
    world = (v * sz) @ R.T + pos
    return world, faces

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("out")
    ap.add_argument("--eye", default="0,200,-300"); ap.add_argument("--at", default="0,0,0")
    ap.add_argument("--fov", type=float, default=55); ap.add_argument("--size", default="1600x900")
    ap.add_argument("--sky", default="168,212,255"); ap.add_argument("--fog", type=float, default=0)
    ap.add_argument("--fogcolor", default="214,226,240")
    a = ap.parse_args()
    W, H = map(int, a.size.split("x"))
    eye = np.array(list(map(float, a.eye.split(",")))); at = np.array(list(map(float, a.at.split(","))))
    fwd = at - eye; fwd /= np.linalg.norm(fwd)
    right = np.cross(fwd, [0, 1, 0]); right /= np.linalg.norm(right)
    up = np.cross(right, fwd)
    f = (H/2) / math.tan(math.radians(a.fov/2))
    light = np.array([-0.45, 0.8, -0.35]); light /= np.linalg.norm(light)
    fogc = np.array(list(map(float, a.fogcolor.split(","))))
    parts = json.load(open(a.src))
    polys = []
    for p in parts:
        world, faces = part_geometry(p)
        rel = world - eye
        cam = np.stack([rel @ right, rel @ up, rel @ fwd], axis=1)
        base = np.array(p["c"]) * 255
        alpha = 1 - p.get("t", 0)
        neon = p.get("m") == "Neon"
        for face in subdivide(world, faces):
            idx = list(range(len(face)))
            wpts = np.array(face)
            rel2 = wpts - eye
            pts = np.stack([rel2 @ right, rel2 @ up, rel2 @ fwd], axis=1)
            if (pts[:, 2] < NEAR).any():
                if (pts[:, 2] < NEAR).all():
                    continue
                pts = clip_near(pts)
                if len(pts) < 3:
                    continue
            n = np.cross(wpts[1] - wpts[0], wpts[2] - wpts[0])
            nl = np.linalg.norm(n)
            if nl < 1e-9:
                if len(idx) > 3:
                    n = np.cross(wpts[2] - wpts[0], wpts[3] - wpts[0]); nl = np.linalg.norm(n)
                if nl < 1e-9:
                    continue
            n /= nl
            center = wpts.mean(axis=0)
            if np.dot(n, eye - center) <= 0:
                continue
            shade = 1.0 if neon else 0.55 + 0.5 * max(0, np.dot(n, light))
            col = np.clip(base * shade, 0, 255)
            depth = pts[:, 2].mean()
            if a.fog > 0:
                k = 1 - math.exp(-depth / a.fog)
                col = col * (1 - k) + fogc * k
            proj = [(W/2 + q[0]*f/q[2], H/2 - q[1]*f/q[2]) for q in pts]
            polys.append((depth, proj, tuple(int(c) for c in col), alpha))
    polys.sort(key=lambda t: -t[0])
    img = Image.new("RGB", (W, H), tuple(map(int, a.sky.split(","))))
    # sky gradient
    sky = np.array(list(map(int, a.sky.split(","))), dtype=float)
    draw = ImageDraw.Draw(img)
    for y in range(H):
        k = y / H
        c = sky * (1 - k*0.35) + fogc * (k*0.35)
        draw.line([(0, y), (W, y)], fill=tuple(int(x) for x in c))
    for depth, proj, col, alpha in polys:
        if alpha < 0.2:
            continue
        if alpha < 0.95:
            # cheap translucency: tint toward the sky colour instead of true blending
            col = tuple(int(c * alpha + s * (1 - alpha)) for c, s in zip(col, (200, 225, 240)))
        draw.polygon(proj, fill=col)
    img.save(a.out)
    print("rendered", len(polys), "polygons ->", a.out)

def _poly_layer(W, H, proj, col, alpha):
    layer = Image.new("RGBA", (W, H))
    ImageDraw.Draw(layer).polygon(proj, fill=col + (int(alpha*255),))
    return layer

if __name__ == "__main__":
    main()
