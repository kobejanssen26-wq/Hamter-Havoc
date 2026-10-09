--[[
	Upgrades. Coin upgrades reset on rebirth; token upgrades are permanent.
	Each upgrade also appears as a pedestal inside the player's house (see HouseBuilder).
	ADVANCED TIERS: rebirths 5 and 10 (RebirthConfig.AdvancedUpgradeRebirths) each add `TierLevels` more levels
	to the upgrades that have them, so the same upgrades keep mattering in the late game.
	Costs were tuned with the progression simulation: they stay a meaningful share of income from minute 5 to hour 10.
]]

local RebirthConfig = require(script.Parent.RebirthConfig)

local UpgradeConfig = {}

UpgradeConfig.Order = {
	"HamsterTraining",
	"CollectionRange",
	"CoinMultiplier",
	"SpawnLuck",
	"WalkSpeed",
	"ExtraStorage",
	"RebirthBoost",
	"GemBoost",
}

UpgradeConfig.Definitions = {
	HamsterTraining = {
		Id = "HamsterTraining", Name = "Hamster Training", Icon = "bolt", Currency = "Coins",
		Description = "Your hamsters run faster in their wheels: more cash every second.",
		MaxLevel = 20, ResetOnRebirth = true, TierLevels = 5,
		BaseCost = 500, Growth = 1.9, PerLevel = 0.08, Format = "+%d%% income",
		Percent = true,
	},
	CollectionRange = {
		Id = "CollectionRange", Name = "Collection Range", Icon = "magnet", Currency = "Coins",
		Description = "Reach hamsters from further away - essential for the fast ones.",
		MaxLevel = 10, ResetOnRebirth = true,
		BaseCost = 300, Growth = 2, PerLevel = 2.5, Format = "+%.1f studs",
	},
	CoinMultiplier = {
		Id = "CoinMultiplier", Name = "Coin Multiplier", Icon = "coin", Currency = "Coins",
		Description = "Every coin you earn is worth more.",
		MaxLevel = 15, ResetOnRebirth = true, TierLevels = 5,
		BaseCost = 2000, Growth = 2.5, PerLevel = 0.15, Format = "+%d%% cash",
		Percent = true,
	},
	SpawnLuck = {
		Id = "SpawnLuck", Name = "Spawn Luck", Icon = "clover", Currency = "Coins",
		Description = "Rarer hamsters show up more often. Strong, but capped.",
		MaxLevel = 5, ResetOnRebirth = true, TierLevels = 1,
		Costs = { 25000, 500000, 12000000, 300000000, 8000000000, 200000000000, 5000000000000 },
		Multipliers = { 1.25, 1.5, 2, 3, 5, 7, 10 }, Format = "Luck x%.2f",
	},
	WalkSpeed = {
		Id = "WalkSpeed", Name = "Walk Speed", Icon = "shoe", Currency = "Coins",
		Description = "Run faster to chase down speedy hamsters.",
		MaxLevel = 8, ResetOnRebirth = true,
		BaseCost = 100, Growth = 2, PerLevel = 1.5, Format = "+%.1f speed",
	},
	ExtraStorage = {
		Id = "ExtraStorage", Name = "Extra Storage", Icon = "home", Currency = "Coins",
		Description = "More hamster slots (each one earns cash). Limited by the wheel stations of your floors.",
		MaxLevel = 9, ResetOnRebirth = true,
		BaseCost = 1000, Growth = 4.5, PerLevel = 1, Format = "+%d slot",
	},
	RebirthBoost = {
		Id = "RebirthBoost", Name = "Rebirth Boost", Icon = "flame", Currency = "Tokens",
		Description = "Makes every Rebirth multiplier step stronger. Permanent.",
		MaxLevel = 10, ResetOnRebirth = false,
		BaseCost = 1, Growth = 1, Linear = true, PerLevel = 0.10, Format = "+%d%% rebirth bonus",
		Percent = true,
	},
	GemBoost = {
		Id = "GemBoost", Name = "Diamond Boost", Icon = "gem", Currency = "Tokens",
		Description = "More diamonds from quests, index rewards and rebirths. Permanent.",
		MaxLevel = 10, ResetOnRebirth = false,
		BaseCost = 1, Growth = 1, Linear = true, PerLevel = 0.10, Format = "+%d%% diamonds",
		Percent = true,
	},
}

-- Highest level you can buy right now (advanced tiers come with rebirths).
function UpgradeConfig.maxLevel(id: string, rebirths: number?): number
	local definition = UpgradeConfig.Definitions[id]
	if not definition then
		return 0
	end
	return definition.MaxLevel + (definition.TierLevels or 0) * RebirthConfig.upgradeTier(rebirths or 0)
end

-- Cost of the NEXT level (nil if maxed). `level` = current level.
function UpgradeConfig.cost(id: string, level: number, rebirths: number?): number?
	local definition = UpgradeConfig.Definitions[id]
	if not definition or level >= UpgradeConfig.maxLevel(id, rebirths) then
		return nil
	end
	if definition.Costs then
		return definition.Costs[level + 1]
	end
	if definition.Linear then
		return definition.BaseCost + level
	end
	return math.floor(definition.BaseCost * definition.Growth ^ level)
end

-- Numeric total effect at a level (percent upgrades return a fraction, e.g. 0.16).
function UpgradeConfig.effect(id: string, level: number): number
	local definition = UpgradeConfig.Definitions[id]
	if not definition or level <= 0 then
		return if definition and definition.Multipliers then 1 else 0
	end
	if definition.Multipliers then
		return definition.Multipliers[math.min(level, #definition.Multipliers)]
	end
	return definition.PerLevel * level
end

function UpgradeConfig.effectText(id: string, level: number): string
	local definition = UpgradeConfig.Definitions[id]
	local effect = UpgradeConfig.effect(id, level)
	if definition.Multipliers then
		return string.format(definition.Format, effect)
	end
	if definition.Percent then
		return string.format(definition.Format, math.floor(effect * 100 + 0.5))
	end
	if string.find(definition.Format, "%%d") then
		return string.format(definition.Format, math.floor(effect))
	end
	return string.format(definition.Format, effect)
end

return UpgradeConfig
