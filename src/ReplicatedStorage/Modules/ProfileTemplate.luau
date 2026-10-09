--[[
	Default player profile. Anything missing from a loaded profile is filled in from here
	(so adding a field later never breaks old saves). Must stay JSON-serialisable.
]]

local SettingsConfig = require(script.Parent.SettingsConfig)

return {
	Version = 1,

	-- currencies
	Coins = 250, -- enough for the first Basic hamster (100) and a spare
	Gems = 25,
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
	},

	Quests = { Claimed = {} },
	Achievements = { Claimed = {} },
	Daily = { Streak = 0, LastDay = 0 },
	Codes = {}, -- [CODE] = true
	Receipts = {}, -- processed developer product receipt ids

	Settings = SettingsConfig.Defaults,

	FirstJoin = 0,
	LastLogin = 0,
	Sessions = 0,
}
