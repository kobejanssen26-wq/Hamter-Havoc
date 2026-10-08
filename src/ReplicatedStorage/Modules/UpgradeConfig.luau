--[[
	Upgrades. Coin upgrades reset on rebirth; token upgrades are permanent.
	Each upgrade also appears as a pedestal inside the player's apartment (see HouseBuilder):
	normal upgrades on the ground floor, advanced ones (RequiresFloor) in the Research Lab.
	Icon is the id of a UI icon (see UI/Icons), never an emoji.
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
	"TurboWheels",
	"LuckyCharms",
}

UpgradeConfig.Definitions = {
	HamsterTraining = {
		Id = "HamsterTraining", Name = "Hamster Training", Icon = "Wheel", Currency = "Coins",
		Description = "Your hamsters run faster in their wheels: more coins every second.",
		MaxLevel = 20, ResetOnRebirth = true,
		BaseCost = 120, Growth = 1.55, PerLevel = 0.08, Format = "+%d%% income",
		Percent = true,
	},
	CollectionRange = {
		Id = "CollectionRange", Name = "Collection Range", Icon = "Magnet", Currency = "Coins",
		Description = "Reach hamsters from further away - essential for the fast ones.",
		MaxLevel = 10, ResetOnRebirth = true,
		BaseCost = 150, Growth = 2, PerLevel = 2.5, Format = "+%.1f studs",
	},
	CoinMultiplier = {
		Id = "CoinMultiplier", Name = "Coin Multiplier", Icon = "Coin", Currency = "Coins",
		Description = "Every coin you earn is worth more.",
		MaxLevel = 15, ResetOnRebirth = true,
		BaseCost = 400, Growth = 2.2, PerLevel = 0.15, Format = "+%d%% coins",
		Percent = true,
	},
	SpawnLuck = {
		Id = "SpawnLuck", Name = "Spawn Luck", Icon = "Luck", Currency = "Coins",
		Description = "Rarer hamsters show up more often. Strong, but capped.",
		MaxLevel = 5, ResetOnRebirth = true,
		Costs = { 2500, 40000, 800000, 15000000, 400000000 },
		Multipliers = { 1.25, 1.5, 2, 3, 5 }, Format = "Luck x%.2f",
	},
	WalkSpeed = {
		Id = "WalkSpeed", Name = "Walk Speed", Icon = "Speed", Currency = "Coins",
		Description = "Run faster to chase down speedy hamsters.",
		MaxLevel = 8, ResetOnRebirth = true,
		BaseCost = 60, Growth = 1.9, PerLevel = 1.5, Format = "+%.1f speed",
	},
	ExtraStorage = {
		Id = "ExtraStorage", Name = "Extra Storage", Icon = "Storage", Currency = "Coins",
		Description = "One more hamster slot per level (until your floors are full).",
		MaxLevel = 3, ResetOnRebirth = true,
		Costs = { 2500, 60000, 1500000 }, PerLevel = 1, Format = "+%d slot",
	},
	RebirthBoost = {
		Id = "RebirthBoost", Name = "Rebirth Boost", Icon = "Rebirth", Currency = "Tokens",
		Description = "Makes every Rebirth multiplier step stronger. Permanent.",
		MaxLevel = 10, ResetOnRebirth = false,
		BaseCost = 1, Growth = 1, Linear = true, PerLevel = 0.10, Format = "+%d%% rebirth bonus",
		Percent = true,
	},
	GemBoost = {
		Id = "GemBoost", Name = "Gem Boost", Icon = "Gem", Currency = "Tokens",
		Description = "More gems from quests, index rewards and rebirths. Permanent.",
		MaxLevel = 10, ResetOnRebirth = false,
		BaseCost = 1, Growth = 1, Linear = true, PerLevel = 0.10, Format = "+%d%% gems",
		Percent = true,
	},
	TurboWheels = {
		Id = "TurboWheels", Name = "Turbo Wheels", Icon = "Turbo", Currency = "Coins",
		Description = "Advanced: lab-tuned wheels make every hamster earn more.",
		MaxLevel = 10, ResetOnRebirth = true, RequiresFloor = 3,
		BaseCost = 50000000, Growth = 2.4, PerLevel = 0.12, Format = "+%d%% income",
		Percent = true,
	},
	LuckyCharms = {
		Id = "LuckyCharms", Name = "Lucky Charms", Icon = "Clover", Currency = "Tokens",
		Description = "Advanced: permanent luck charms from the Research Lab.",
		MaxLevel = 5, ResetOnRebirth = false, RequiresFloor = 3,
		BaseCost = 3, Growth = 1, Linear = true, PerLevel = 0.06, Format = "+%d%% luck",
		Percent = true,
	},
}

-- Is the upgrade available to this player (advanced upgrades need their floor)?
function UpgradeConfig.available(id: string, floors: number): boolean
	local definition = UpgradeConfig.Definitions[id]
	return definition ~= nil and floors >= (definition.RequiresFloor or 1)
end

-- Coin upgrades get more expensive with every rebirth (x RebirthCostScale per rebirth) so they stay a
-- real decision after each reset instead of being bought out instantly. Token upgrades never scale.
UpgradeConfig.RebirthCostScale = 3

-- Cost of the NEXT level (nil if maxed). `level` = current level, `rebirths` = the player's rebirths.
function UpgradeConfig.cost(id: string, level: number, rebirths: number?): number?
	local definition = UpgradeConfig.Definitions[id]
	if not definition or level >= definition.MaxLevel then
		return nil
	end
	local cost
	if definition.Costs then
		cost = definition.Costs[level + 1]
	elseif definition.Linear then
		cost = definition.BaseCost + level
	else
		cost = math.floor(definition.BaseCost * definition.Growth ^ level)
	end
	if definition.Currency == "Coins" and rebirths and rebirths > 0 then
		cost = math.floor(cost * UpgradeConfig.RebirthCostScale ^ rebirths)
	end
	return cost
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
