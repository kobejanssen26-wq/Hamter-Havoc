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
	C="$(cd "$HERE/../../src/ReplicatedStorage/Modules/Content" && pwd)"
	# (C is deliberately NOT local: the EXIT trap runs after the function returned. A local C used to leave the
	#  Test*.luau files behind in the real Content folders.)
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

# scn_hud.lua runs twice (no templates / with the baked templates + simulated Studio edits) and the built HUDs are compared
run_hud() {
	local OUTDIR="$BUILD"
	for mode in plain template; do
		python3 - "$HERE" "$BUILD" "$mode" <<'PY'
import sys, json
here, build, mode = sys.argv[1:4]
texts = {}
for name in ("MainUI", "HotbarUI"):
    texts[name] = open(f"{here}/../../src/StarterGui/{name}.model.json").read()
prelude = f'local MODE = "{mode}"\nlocal HUD_JSON = {{\n'
for name, text in texts.items():
    prelude += f'\t{name} = [==[{text}]==],\n'
prelude += "}\nlocal find_game = find\n"
open(f"{build}/scn_hud_{mode}.lua", "w").write(prelude + open(f"{here}/scn_hud.lua").read())
PY
		(cd "$BUILD" && python3 "$HERE/gen.py" "scn_hud_$mode.lua" >/dev/null && timeout 900 "$LUAU" run.lua 2>&1) > "$BUILD/hud_$mode.out" || true
	done
	grep -E "^\s+\[(PASS|FAIL)\]|PASS [0-9]+" "$BUILD/hud_template.out"
	grep '^SIG|' "$BUILD/hud_plain.out" | sort > "$BUILD/hud_plain.sig"
	grep '^SIG|' "$BUILD/hud_template.out" | sort > "$BUILD/hud_template.sig"
	if [ -s "$BUILD/hud_plain.sig" ] && diff -q "$BUILD/hud_plain.sig" "$BUILD/hud_template.sig" >/dev/null; then
		echo "  [PASS] the HUD built from the templates has exactly the same instances as the HUD built from code ($(wc -l < "$BUILD/hud_plain.sig") distinct paths)"
	else
		echo "  [FAIL] the template HUD differs from the code-built HUD"; diff "$BUILD/hud_plain.sig" "$BUILD/hud_template.sig" | head -20
	fi
}

if [ "$1" = "scn_hud.lua" ]; then
	run_hud
	exit 0
fi

if [ "$1" = "--all" ]; then
	hud_out="$(run_hud)"
	echo "== scn_hud: $(echo "$hud_out" | grep -cE '\[PASS\]') passed, $(echo "$hud_out" | grep -c '\[FAIL\]') failed"
	echo "$hud_out" | grep "\[FAIL\]" || true
	if "$HERE/bake_hud.sh" --check >/dev/null 2>&1; then echo "== hud templates: up to date"; else echo "== hud templates: OUT OF DATE (run tools/SimTests/bake_hud.sh)"; fi
	for s in scn_loop scn_ui scn_gear scn_combat scn_admin scn_rebirth scn_world scn_audit scn_tutorial scn_theft scn_lb scn_content scn_econ scn_wheels scn_game; do
		if [ "$s" = "scn_content" ]; then out="$( (with_temp_content) )"; else out="$(run_one $s.lua)"; fi
		echo "== $s: $(echo "$out" | grep -E 'PASS [0-9]+|TOTAL ERRORS|fails:' | tail -1)"
		echo "$out" | grep -E "\[FAIL\]" || true
	done
elif [ "$1" = "scn_content.lua" ]; then
	with_temp_content
else
	run_one "$1"
fi
