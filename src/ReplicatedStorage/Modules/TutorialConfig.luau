--[[
	First-time player tutorial (7 steps). Edit this file to change the text or the order. Steps are tiny and skippable;
	completion is saved (profile.Tutorial) so it never shows twice, and profiles that existed before it was added are
	marked done on load. Players can replay it from Settings.

	Kind "Ack"       the player presses the button (nothing to verify)
	Kind "Stat"      the server watches the real profile: advances itself when Stats[Stat] >= Target
	Kind "Equipped"  advances itself when at least one hamster is placed on the working bench
	Target           what the guide points at, found by TAG in the world (never by coordinates):
	                   "Base" "Bench" "Gate" "Upgrade" "Altar" "Leaderboard"   (objects marked with Build.target in the builders)
	                   "Hamsters"                                              (the nearest hamster ball on the road)
	Objects inside a house are only offered to that house's owner, so everybody is guided to THEIR OWN base.
]]

local TutorialConfig = {}

TutorialConfig.Steps = {
	{ Id = "base", Kind = "Ack", Title = "Your base", Text = "This is your base. Hamsters you win are brought here and work for you. Nobody else owns it.", Target = "Base", Button = "Next" },
	{ Id = "hamster", Kind = "Stat", Stat = "Claimed", Target = 1, Title = "Get your first hamster", Text = "Walk up to a hamster ball on the road and hold E to buy it with cash. Check its price first.", Pointer = "Hamsters" },
	{ Id = "bench", Kind = "Equipped", Title = "Your working bench", Text = "Your hamster rolls home and runs on a wheel of your bench, earning money every second. Open Backpack > Hamsters to choose who works.", Target = "Bench" },
	{ Id = "gate", Kind = "Ack", Title = "Lock your base", Text = "Other players can steal from an open base. Your gate protects it for a while: press E at the security panel to switch it back on.", Target = "Gate", Button = "Next" },
	{ Id = "upgrade", Kind = "Ack", Title = "Upgrade", Text = "Spend your cash here: more income, more luck, faster walking. Upgrades are the quickest way to grow.", Target = "Upgrade", Button = "Next" },
	{ Id = "altar", Kind = "Ack", Title = "Rebirth altar", Text = "When you have the cash and the required hamsters, rebirth here for permanent income and new gear. You keep all your hamsters.", Target = "Altar", Button = "Next" },
	{ Id = "leaderboard", Kind = "Ack", Title = "Leaderboard", Text = "Compete with everyone: most hamsters, most steals, most money. Good luck!", Target = "Leaderboard", Button = "Finish" },
}

TutorialConfig.DoneStep = 99

return TutorialConfig
