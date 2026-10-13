--[[
	Default player profile. Anything missing from a loaded profile is filled in from here
	(so adding a field later never breaks old saves). Must stay JSON-serialisable.
]]

local GameConfig = require(script.Parent.GameConfig)
local SettingsConfig = require(script.Parent.SettingsConfig)

return {
	Version = 1,

	-- currencies
	Coins = GameConfig.get("Economy", "StartingCash"), -- GameConfig.luau > Economy
	Gems = GameConfig.get("Economy", "StartingDiamonds"),
	Tokens = 0,
	Rebirths = 0,

	-- collection
	Inventory = {}, -- [speciesId] = count owned
	Index = {}, -- [speciesId] = true once ever collected (survives rebirth)
	Equipped = {}, -- array of speciesIds shown in the house (earning coins)
	IndexRewards = {}, -- [rarityId] = true once the completion reward was claimed

	-- progression
	Upgrades = {}, -- [upgradeId] = level
	Boosts = {}, -- [boostId] = unix time it expires
	Items = {}, -- [itemId] = count of consumable items (hotbar); server authoritative
	Gear = {}, -- [itemId] = true for owned weapons / equipment (ItemRegistry); server authoritative
	Hotbar = {}, -- ["2".."8"] = itemId on that hotbar slot (slot 1 is always the built-in Slap)
	Tutorial = { Step = 1, Done = false, Skipped = false },
	Passes = {}, -- [passKey] = true (re-verified on join)
	Cosmetics = { Owned = {}, Roof = "default" },

	Stats = {
		HamstersCollected = 0,
		CoinsEarned = 0,
		GemsEarned = 0,
		UpgradesBought = 0,
		Sold = 0,
		Found = {}, -- [rarityId] = how many found
		Claimed = 0, -- balls paid for
		Secured = 0, -- balls that reached a house
		Steals = 0, -- balls stolen from other players
		Stolen = 0, -- stolen balls that were secured (counts for the thief)
		Recovered = 0, -- own balls taken back
		Slaps = 0,
		TheftsStopped = 0, -- thefts of MY hamsters that I stopped by hitting the thief
		TheftsFailed = 0, -- thefts I attempted that failed
		TimesRobbed = 0, -- my hamsters that were stolen for good
	},

	Quests = { Claimed = {} },
	Achievements = { Claimed = {} },
	Daily = { Streak = 0, LastDay = 0 },
	Wheel = { NextFreeAt = 0 }, -- Lucky Wheel: unix time the next free spin is ready
	Codes = {}, -- [CODE] = true
	Receipts = {}, -- processed developer product receipt ids

	Settings = SettingsConfig.Defaults,

	FirstJoin = 0,
	LastLogin = 0,
	Sessions = 0,
}
