--[[
	HAMSTER TEMPLATE - copy this file, rename it (e.g. SilverHamster.luau) and edit it. Delete `Enabled = false`.
	This template itself is ignored by the game. Full guide: docs/CONTENT_GUIDE.md

	Everything except the first four fields is optional. What you leave out falls back to the rarity formula
	(Price / IncomePerSecond) or to the procedural hamster (Look).
]]
return {
	Enabled = false, -- remove this line (or set it to true) to activate the hamster

	Id = "my_new_hamster", -- stable internal id: lowercase letters, digits, underscores. NEVER change it after release (saves use it)
	DisplayName = "My New Hamster", -- what players see
	Rarity = "Rare", -- one of: Basic Cute Shiny Rare Epic Ultra Legendary Mythic Divine Cosmic Celestial Secret Ancient Unknown

	-- Economy (optional - without these the rarity formula decides)
	-- Price = 25000, -- cash to claim it when it rolls by
	-- IncomePerSecond = 350, -- cash per second while it runs on a wheel (before multipliers)
	-- SpawnWeight = 1, -- relative chance among the hamsters of the same rarity
	-- Spawnable = false, -- true/omitted: rolls down the road; false: only from rewards/codes (like exclusives)

	-- Collection text (shown in the Hamster Index) and limited editions
	-- Description = "Short collectible blurb, max 140 characters.",
	-- Limited = { EndsAt = 1798761600 }, -- unix time (UTC). After it the hamster stops rolling; owners keep theirs. Optional StartsAt too.

	-- Look. Either use your own model ...
	-- ModelName = "MyNewHamster", -- a Model inside ReplicatedStorage/Assets/HamsterModels (see the guide for the rig rules)
	-- Icon = "rbxassetid://<your uploaded image id>", -- thumbnail for menus (optional; a snapshot of the model is used otherwise)
	-- ... or tweak the procedural hamster:
	-- Look = { Fur = "C8935A", Belly = "F3DDB5", Ears = "round", Eyes = "dot", Size = 1 },

	-- Extras (optional)
	-- Animation = { Idle = "My_Hamster_Idle", Walk = "My_Hamster_Walk" }, -- names from Content/Animations (custom rigs only)
	-- Sound = { Spawn = "Coin" }, -- names from AudioConfig.Sfx
	-- Effects = { { "sparkle", "FFD35A" } }, -- particle effects, same kinds as the built-in hamsters
	-- Unlock = { MinRebirth = 2 }, -- only appears in the world from this many rebirths (on top of the rarity's own unlock)
}
