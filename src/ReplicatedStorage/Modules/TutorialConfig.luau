--[[
	First-time player tutorial. Steps are tiny and skippable; completion is saved (profile.Tutorial) so it never
	shows twice, and profiles that existed before the tutorial was added are marked done on load.

	Kind "Ack"    the player presses the button (nothing to verify)
	Kind "Stat"   the server watches the real profile: advances itself when Stats[Stat] >= Target
	Target        what the guide arrow points to: "Plot", "Hamsters", "Shop" or nil
]]

local TutorialConfig = {}

TutorialConfig.Steps = {
	{ Id = "welcome", Kind = "Ack", Title = "Welcome to Hamster Plaza!", Text = "Hamsters roll down the street in balls. Buy them, bring them home and they earn cash for you.", Button = "Let's go" },
	{ Id = "plot", Kind = "Ack", Title = "This is your plot", Text = "You were given your own base automatically. Hamsters you secure live here and produce cash.", Target = "Plot", Button = "Got it" },
	{ Id = "discover", Kind = "Ack", Title = "Spot the hamsters", Text = "Each hamster shows its name, rarity, price and income per second. Pick something you can afford.", Target = "Hamsters", Button = "Next" },
	{ Id = "buy", Kind = "Stat", Stat = "Claimed", Target = 1, Title = "Buy your first hamster", Text = "Walk up to a hamster ball and hold E to pay for it.", Pointer = "Hamsters" },
	{ Id = "earn", Kind = "Stat", Stat = "Secured", Target = 1, Title = "Bring it home", Text = "Your hamster rolls to your base on its own. Guard it - other players can steal it! Slap thieves with Q.", Pointer = "Plot" },
	{ Id = "progress", Kind = "Ack", Title = "Keep growing", Text = "Earn cash, buy upgrades at your terminal, collect new species, and rebirth for permanent power. Daily Quests and the Shop are in the corner buttons.", Button = "Start playing" },
}

TutorialConfig.DoneStep = 99

return TutorialConfig
