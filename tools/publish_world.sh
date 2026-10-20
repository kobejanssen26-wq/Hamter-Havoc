#!/bin/bash
# Re-bakes the editor preview of the world + HUD and rebuilds HamsterPlaza.rbxl (the file you open in Roblox Studio).
# Run it before EVERY push so the .rbxl on GitHub always matches the code:
#   LUAU=/path/to/luau ROJO=/path/to/rojo tools/publish_world.sh
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE/.."
"$HERE/SimTests/bake_world.sh" | grep -E "^wrote|bake produced" || true
"$HERE/SimTests/bake_hud.sh" | grep -E "^wrote" || true
(cd "$ROOT" && "${ROJO:-rojo}" build default.project.json -o HamsterPlaza.rbxl)
