--[[
	First-time player tutorial (9 steps). Edit this file to change the text or the order. Steps are tiny and skippable;
	completion is saved (profile.Tutorial) so it never shows twice, and profiles that existed before it was added are
	marked done on load. Players can replay it from Settings.

	Kind "Ack"       the player presses the button (nothing to verify)
	Kind "Stat"      the server watches the real profile: advances itself when Stats[Stat] >= Need
	Kind "Equipped"  advances itself when at least one hamster is placed on the working bench
	Target / Pointer what the guide points at, found by TAG in the world (never by coordinates):
	                   "Base" "Bench" "Gate" "Upgrade" "Altar" "Wheel" "Leaderboard"   (objects marked with Build.target in the builders)
	                   "Hamsters"                                              (the nearest hamster ball on the road)
	Objects inside a house are only offered to that house's owner, so everybody is guided to THEIR OWN base.
]]

local TutorialConfig = {}

TutorialConfig.Steps = {
	{ Id = "base", Kind = "Ack", Title = "Your base", Text = "This is your base. Hamsters you win are brought here and work for you. Nobody else owns it.", Target = "Base", Button = "Next" },
	{ Id = "hamster", Kind = "Stat", Stat = "Claimed", Need = 1, Title = "Get your first hamster", Text = "Walk up to a hamster ball on the road (the arrow points at the nearest one). Its price floats above it: pick one you can afford, stand next to it and press E to buy it.", Pointer = "Hamsters" },
	{ Id = "bench", Kind = "Equipped", Title = "Your working bench", Text = "Your hamster rolls home and runs on a wheel of your bench, earning money every second. Open Backpack > Hamsters to choose who works.", Target = "Bench" },
	{ Id = "income", Kind = "Stat", Stat = "CoinsEarned", Need = 10, Title = "Earn income", Target = "Bench", Text = "Watch your cash at the top of the screen: every hamster on your bench adds to it every second, even while you walk around. This step continues by itself when you have earned some." },
	{ Id = "gate", Kind = "Ack", Title = "Lock your base", Text = "Other players can steal from an open base. Your gate protects it for a while: press E at the security panel to switch it back on.", Target = "Gate", Button = "Next" },
	{ Id = "upgrade", Kind = "Ack", Title = "Upgrade", Text = "Spend your cash here: more income, more luck, faster walking. Upgrades are the quickest way to grow.", Target = "Upgrade", Button = "Next" },
	{ Id = "altar", Kind = "Ack", Title = "Rebirth altar", Text = "When you have the cash and the required hamsters, rebirth here for permanent income and new gear. You keep all your hamsters.", Target = "Altar", Button = "Next" },
	{ Id = "wheel", Kind = "Ack", Title = "Lucky Wheel", Text = "This wheel in the plaza gives a free spin every couple of hours: cash, diamonds, boosts and even hamsters. Press F next to it to spin. A green sign tells you when your spin is ready.", Target = "Wheel", Button = "Next" },
	{ Id = "leaderboard", Kind = "Ack", Title = "Leaderboard", Text = "Compete with everyone: most hamsters, most steals, most money. Good luck!", Target = "Leaderboard", Button = "Finish" },
}

TutorialConfig.DoneStep = 99

return TutorialConfig
