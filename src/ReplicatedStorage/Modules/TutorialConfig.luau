--[[
	First-time player tutorial (11 steps). Edit this file to change the text or the order. Steps are small and skippable;
	completion is saved (profile.Tutorial) so it never shows twice, and profiles that existed before it was added are
	marked done on load. Players can replay it from Settings.

	Kind "Ack"       the player presses the button (nothing to verify)
	Kind "Stat"      the server watches the real profile: advances itself when Stats[Stat] >= Need
	Kind "Equipped"  advances itself when at least one hamster is placed on the working bench

	What a step points at (all found by TAG / NAME at the moment it is shown, never by coordinates):
	  Target / Pointer   an object in the world: "Base" "Bench" "Gate" "Upgrade" "Altar" "Shop" "Wheel" "Leaderboard"
	                     (objects marked with Build.target in the builders; "Hamsters" = the nearest hamster ball YOU CAN AFFORD)
	  UiTarget           a button on the screen: a rail button by its id ("Backpack", "Shop", "RobuxShop", "Quests", "Wheel",
	                     "Playtime", "Leaderboards", "Settings") or the HUD piece "IncomePill". It gets a gold outline and an arrow.
	  Dynamic            the text is completed with live numbers (TutorialUI.Dynamic): "hamster" (the real ball and price),
	                     "gate" (laser duration and cooldown), "upgrade" (the cheapest upgrade and its cost), "altar" (rebirth
	                     requirements with what you have, what resets and what you keep). `Text` is the fallback.
	Objects inside a house are only offered to that house's owner, so everybody is guided to THEIR OWN base.
]]

local TutorialConfig = {}

TutorialConfig.Steps = {
	{ Id = "base", Kind = "Ack", Title = "Your base", Text = "This is your base. Hamsters you buy roll here and work for you. Nobody else can use it.", Target = "Base", Button = "Next" },
	{ Id = "hamster", Kind = "Stat", Stat = "Claimed", Need = 1, Title = "Get your first hamster", Dynamic = "hamster", Text = "Walk up to a hamster ball on the road (the arrow points at one you can afford). Stand next to it and press E to buy it.", Pointer = "Hamsters" },
	{ Id = "bench", Kind = "Equipped", Title = "Put it to work", Text = "Your hamster rolls home. Open the Backpack (right side, or press I), tab Hamsters, and press Work +: it then runs in a wheel on your bench.", Target = "Bench", UiTarget = "Backpack" },
	{ Id = "income", Kind = "Stat", Stat = "CoinsEarned", Need = 10, Title = "Earn income", Target = "Bench", UiTarget = "IncomePill", Text = "This shows your income per second ($/s). Every hamster on your bench adds to it, even while you walk around. This step continues by itself when you earned some." },
	{ Id = "gate", Kind = "Ack", Title = "Lock your base", Dynamic = "gate", Text = "Other players can steal from an open base. At your security panel press E to switch your lasers on: they protect your base for a while.", Target = "Gate", Button = "Next" },
	{ Id = "upgrade", Kind = "Ack", Title = "Upgrade", Dynamic = "upgrade", Text = "Press F at the Upgrade Terminal to spend cash on more income, luck and speed. Upgrades are the quickest way to grow.", Target = "Upgrade", Button = "Next" },
	{ Id = "collection", Kind = "Ack", Title = "Your hamster collection", UiTarget = "Backpack", Text = "Open the Backpack (right side, or press I): tab Hamsters is your collection, the Hamster Index button shows every hamster in the game and which ones you found.", Button = "Next" },
	{ Id = "altar", Kind = "Ack", Title = "Rebirth altar", Dynamic = "altar", Text = "At this altar you rebirth once you have the cash and the required hamsters: permanent income and new gear.", Target = "Altar", Button = "Next" },
	{ Id = "shop", Kind = "Ack", Title = "Coins Shop", UiTarget = "Shop", Text = "Buy weapons, equipment and boosts with your coins here (or with the Shop button on the right). The Robux Shop next to it sells diamond packs and game passes.", Target = "Shop", Button = "Next" },
	{ Id = "wheel", Kind = "Ack", Title = "Lucky Wheel", Text = "Behind the shops: one free spin every few hours, with cash, diamonds, boosts and even hamsters. Press F next to it. The sign shows when your spin is ready.", Target = "Wheel", Button = "Next" },
	{ Id = "leaderboard", Kind = "Ack", Title = "Leaderboard", Text = "Compete with everyone: most hamsters, most steals, most money. Good luck!", Target = "Leaderboard", Button = "Finish" },
}

TutorialConfig.DoneStep = 99

return TutorialConfig
