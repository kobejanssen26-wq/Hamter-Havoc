#!/usr/bin/env bash
# Rebuilds the /Models asset library from the game code (needs lune, rojo, python3 with pillow, numpy, trimesh).
#   tools/build_models.sh            (from the project root)
set -euo pipefail
cd "$(dirname "$0")/.."
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# generated folders are replaced; hand-written README files stay
rm -rf Models/Hamsters Models/Buildings Models/HamsterWheel Models/Environment Models/Trees Models/Plants \
	Models/Furniture Models/Decorations Models/Props Models/Animals Models/Effects Models/UI \
	Models/manifest.json Models/ASSET_INDEX.md
mkdir -p Models

lune run tools/lune/export_models.luau . Models "$WORK/parts"
python3 tools/export_glb.py "$WORK/parts" Models
lune run tools/lune/export_icon_data.luau . "$WORK/icons.json"
python3 tools/export_icons.py "$WORK/icons.json" Models/UI/Icons 256
python3 tools/build_asset_index.py "$WORK/parts" Models
