#!/bin/bash
# Runs one simulation scenario against the REAL game scripts (server + client) inside a mock Roblox environment.
#   tools/SimTests/run.sh scn_theft.lua          (needs the `luau` binary: set LUAU=/path/to/luau, or have it on PATH)
#   tools/SimTests/run.sh --all                  runs every scenario and prints one PASS/FAIL line each
# The mock is NOT Roblox: it checks game LOGIC (state machines, security rules, data, UI structure and geometry),
# not how things look or feel. See README.md in this folder.
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
LUAU="${LUAU:-luau}"
BUILD="$HERE/.build"
mkdir -p "$BUILD"
cp "$HERE/mock.lua" "$HERE/classes.lua" "$BUILD/"

run_one() {
	local scenario="$1"
	cp "$HERE/$scenario" "$BUILD/$scenario"
	(cd "$BUILD" && python3 "$HERE/gen.py" "$scenario" >/dev/null && timeout 900 "$LUAU" run.lua 2>&1)
}

with_temp_content() {
	# scn_content.lua checks good AND deliberately broken content files: write them, run, always remove them
	local C="$HERE/../../src/ReplicatedStorage/Modules/Content"
	trap 'rm -f "$C"/Hamsters/Test*.luau "$C"/Animations/Test*.luau' EXIT
	cat > "$C/Hamsters/TestNibbler.luau" <<'L'
return { Id = "test_nibbler", DisplayName = "Testy Nibbler", Rarity = "Rare", Price = 12345, IncomePerSecond = 77, Look = { Fur = "A0B0C0", Ears = "pointy" } }
L
	echo 'return { Id = "brownie", DisplayName = "Dup Brownie", Rarity = "Basic" }' > "$C/Hamsters/TestDup.luau"
	echo 'return { Id = "test_badrarity", DisplayName = "Bad", Rarity = "Nope" }' > "$C/Hamsters/TestBadRarity.luau"
	echo 'return { Id = "test_fakeicon", DisplayName = "Fake Icon", Rarity = "Rare", Icon = "rbxassetid://REPLACE_WITH_VALID_ASSET_ID" }' > "$C/Hamsters/TestFakeIcon.luau"
	echo 'return { Id = "test_nomodel", DisplayName = "No Model", Rarity = "Basic", ModelName = "NoSuchModel" }' > "$C/Hamsters/TestNoModel.luau"
	echo 'return { Name = "Test_Anim", AssetId = "", Rig = "R15", Use = "Emote" }' > "$C/Animations/TestAnim.luau"
	echo 'return { Name = "Test_BadAnim", AssetId = "rbxassetid://PLACEHOLDER", Rig = "R15", Use = "Emote" }' > "$C/Animations/TestBadAnim.luau"
	run_one scn_content.lua
}

if [ "$1" = "--all" ]; then
	for s in scn_loop scn_ui scn_theft scn_lb scn_content scn_econ scn_wheels scn_game; do
		if [ "$s" = "scn_content" ]; then out="$( (with_temp_content) )"; else out="$(run_one $s.lua)"; fi
		echo "== $s: $(echo "$out" | grep -E 'PASS [0-9]+|TOTAL ERRORS|fails:' | tail -1)"
		echo "$out" | grep -E "\[FAIL\]" || true
	done
elif [ "$1" = "scn_content.lua" ]; then
	with_temp_content
else
	run_one "$1"
fi
