#!/bin/bash
# Re-bakes the editor preview of the world (world/*.model.json) from the real builders. Deterministic: unchanged builders = unchanged files.
#   LUAU=/path/to/luau tools/SimTests/bake_world.sh
# Then rebuild the place:  rojo build -o HamsterPlaza.rbxl
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
LUAU="${LUAU:-luau}"
BUILD="$HERE/.build"
OUT="$HERE/../../world"
mkdir -p "$BUILD"
cp "$HERE/mock.lua" "$HERE/classes.lua" "$BUILD/"
cp "$HERE/scn_bake.lua" "$BUILD/scn_bake.lua"
(cd "$BUILD" && python3 "$HERE/gen.py" scn_bake.lua >/dev/null && timeout 900 "$LUAU" run.lua 2>&1 | grep '^BAKE|' > "$BUILD/world_bake.txt" || true)
python3 - "$OUT" "$BUILD/world_bake.txt" <<'PY'
import sys, os
out, rawfile = sys.argv[1], sys.argv[2]
count = 0
for line in open(rawfile):
    line = line.rstrip("\n")
    _, name, body = line.split("|", 2)
    path = os.path.join(out, name + ".model.json")
    old = open(path).read() if os.path.exists(path) else None
    count += 1
    if old != body:
        open(path, "w").write(body)
        print("wrote", path, len(body), "bytes")
    else:
        print("unchanged", path)
if count == 0:
    print("bake produced nothing"); sys.exit(2)
PY
