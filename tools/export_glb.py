#!/usr/bin/env python3
"""Turn the part dumps written by tools/lune/export_models.luau into .glb files (glTF 2.0, binary).

One mesh per material (colour + transparency + neon), Y up, 1 unit = 1 stud. Boxes, wedges and
cylinders are flat shaded; spheres are smooth. Open the result in Blender, Windows 3D Viewer,
https://gltf-viewer.donmccurdy.com or import it back into Roblox (Import 3D).

usage: export_glb.py <workDir> <ModelsDir>
  reads  <workDir>/<Category__Sub__Name>.json
  writes <ModelsDir>/<Category>/<Sub>/<Name>/<Name>.glb
"""
import glob, json, os, sys

import numpy as np
import trimesh

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from render import part_geometry  # noqa: E402  (same geometry as the preview renderer)

SMOOTH = {"sphere", "ball"}


def triangles(face):
    return [(face[0], face[i], face[i + 1]) for i in range(1, len(face) - 1)]


def part_mesh(p):
    world, faces = part_geometry(p)
    if p["s"] in SMOOTH:
        tris = [t for f in faces for t in triangles(f)]
        mesh = trimesh.Trimesh(vertices=world, faces=np.array(tris), process=False)
        mesh.remove_degenerate_faces() if hasattr(mesh, "remove_degenerate_faces") else None
        return mesh
    # flat: every face gets its own vertices
    verts, tris = [], []
    for f in faces:
        base = len(verts)
        verts.extend(world[list(f)])
        tris.extend((base, base + i, base + i + 1) for i in range(1, len(f) - 1))
    return trimesh.Trimesh(vertices=np.array(verts), faces=np.array(tris), process=False)


def material_key(p):
    c = tuple(round(v, 3) for v in p["c"])
    return (c, round(p.get("t", 0), 2), p.get("m") == "Neon", p.get("m") in ("Glass", "ForceField"))


def build_scene(parts, name):
    groups = {}
    for p in parts:
        groups.setdefault(material_key(p), []).append(part_mesh(p))
    scene = trimesh.Scene()
    for index, (key, meshes) in enumerate(sorted(groups.items(), key=lambda kv: str(kv[0]))):
        (r, g, b), t, neon, glass = key
        mesh = trimesh.util.concatenate(meshes) if len(meshes) > 1 else meshes[0]
        alpha = max(0.0, min(1.0, 1 - t))
        material = trimesh.visual.material.PBRMaterial(
            name=f"{name}_mat{index}",
            baseColorFactor=[r, g, b, alpha],
            metallicFactor=0.0,
            roughnessFactor=0.15 if glass else 0.8,
            emissiveFactor=[r, g, b] if neon else [0, 0, 0],
            alphaMode="BLEND" if alpha < 0.999 else "OPAQUE",
            doubleSided=alpha < 0.999,
        )
        mesh.visual = trimesh.visual.TextureVisuals(material=material)
        scene.add_geometry(mesh, node_name=f"{name}_{index}", geom_name=f"{name}_{index}")
    return scene


def main():
    work, models = sys.argv[1], sys.argv[2]
    count = 0
    for path in sorted(glob.glob(os.path.join(work, "*.json"))):
        rel = os.path.basename(path)[:-5].split("__")
        name = rel[-1]
        parts = json.load(open(path))
        out_dir = os.path.join(models, *rel)
        os.makedirs(out_dir, exist_ok=True)
        build_scene(parts, name).export(os.path.join(out_dir, name + ".glb"))
        count += 1
    print("glb files:", count)


if __name__ == "__main__":
    main()
