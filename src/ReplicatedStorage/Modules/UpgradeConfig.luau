--[[
	Upgrades. Coin upgrades reset on rebirth; token upgrades are permanent.
	Each upgrade also appears as a pedestal inside the player's house (see HouseBuilder).
]]

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
		Id = "HamsterTraining", Name = "Hamster Training", Icon = "🏃", Currency = "Coins",
		Description = "Your hamsters run faster in their wheels: more coins every second.",
		MaxLevel = 20, ResetOnRebirth = true,
		BaseCost = 120, Growth = 1.55, PerLevel = 0.08, Format = "+%d%% income",
		Percent = true,
	},
	CollectionRange = {
		Id = "CollectionRange", Name = "Collection Range", Icon = "🧲", Currency = "Coins",
		Description = "Reach hamsters from further away - essential for the fast ones.",
		MaxLevel = 10, ResetOnRebirth = true,
		BaseCost = 150, Growth = 2, PerLevel = 2.5, Format = "+%.1f studs",
	},
	CoinMultiplier = {
		Id = "CoinMultiplier", Name = "Coin Multiplier", Icon = "🪙", Currency = "Coins",
		Description = "Every coin you earn is worth more.",
		MaxLevel = 15, ResetOnRebirth = true,
		BaseCost = 400, Growth = 2.2, PerLevel = 0.15, Format = "+%d%% coins",
		Percent = true,
	},
	SpawnLuck = {
		Id = "SpawnLuck", Name = "Spawn Luck", Icon = "🍀", Currency = "Coins",
		Description = "Rarer hamsters show up more often. Strong, but capped.",
		MaxLevel = 5, ResetOnRebirth = true,
		Costs = { 2500, 40000, 800000, 15000000, 400000000 },
		Multipliers = { 1.25, 1.5, 2, 3, 5 }, Format = "Luck x%.2f",
	},
	WalkSpeed = {
		Id = "WalkSpeed", Name = "Walk Speed", Icon = "👟", Currency = "Coins",
		Description = "Run faster to chase down speedy hamsters.",
		MaxLevel = 8, ResetOnRebirth = true,
		BaseCost = 60, Growth = 1.9, PerLevel = 1.5, Format = "+%.1f speed",
	},
	ExtraStorage = {
		Id = "ExtraStorage", Name = "Extra Storage", Icon = "🏠", Currency = "Coins",
		Description = "Display more hamsters in your house (each one earns coins).",
		MaxLevel = 9, ResetOnRebirth = true,
		BaseCost = 300, Growth = 3.2, PerLevel = 1, Format = "+%d slot",
	},
	RebirthBoost = {
		Id = "RebirthBoost", Name = "Rebirth Boost", Icon = "🔥", Currency = "Tokens",
		Description = "Makes every Rebirth multiplier step stronger. Permanent.",
		MaxLevel = 10, ResetOnRebirth = false,
		BaseCost = 1, Growth = 1, Linear = true, PerLevel = 0.10, Format = "+%d%% rebirth bonus",
		Percent = true,
	},
	GemBoost = {
		Id = "GemBoost", Name = "Gem Boost", Icon = "💎", Currency = "Tokens",
		Description = "More gems from quests, index rewards and rebirths. Permanent.",
		MaxLevel = 10, ResetOnRebirth = false,
		BaseCost = 1, Growth = 1, Linear = true, PerLevel = 0.10, Format = "+%d%% gems",
		Percent = true,
	},
}

-- Cost of the NEXT level (nil if maxed). `level` = current level.
function UpgradeConfig.cost(id: string, level: number): number?
	local definition = UpgradeConfig.Definitions[id]
	if not definition or level >= definition.MaxLevel then
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
