--[[
	Rebirth: the big prestige step. It is hard to reach (money + a real collection + a hamster of the right rarity)
	and every single rebirth gives permanent power:

	  every rebirth   +1 hamster slot, +30% permanent income, +5% luck, gems and tokens
	  milestones      new floors (R3 / R6 / R10 / R15), advanced upgrades (R5 / R10), keepsake hamsters,
	                  better security, new rarities, tower trim (silver / gold / diamond)

	RESET: coins, your owned hamsters (except your best "keepsakes"), coin upgrades.
	KEEP:  Hamster Index + milestones, rebirth count and everything it unlocked, floors, token upgrades,
	       gems, tokens, quests, achievements, cosmetics, gamepasses.
	Numbers were tuned with the progression simulation (see tests): first rebirth after roughly an hour.
]]

local FloorConfig = require(script.Parent.FloorConfig)
local HamsterDatabase = require(script.Parent.HamsterDatabase)
local RarityConfig = require(script.Parent.RarityConfig)
local SecurityConfig = require(script.Parent.SecurityConfig)

local RebirthConfig = {}

RebirthConfig.MaxRebirths = 25
RebirthConfig.GemReward = 500
RebirthConfig.BaseSlots = 3
RebirthConfig.IncomeStep = 0.30 -- +30% permanent income per rebirth (the Rebirth Boost token upgrade makes this bigger)
RebirthConfig.LuckStep = 0.05
RebirthConfig.CostBase = 700000 -- first rebirth: $700,000
RebirthConfig.CostGrowth = 4.6
RebirthConfig.AdvancedUpgradeRebirths = { 5, 10 } -- each of these adds a tier of upgrade levels

-- The rarity (by name) you must own at least one hamster of, per rebirth number.
local REQUIRED_RARITY = { "Shiny", "Rare", "Rare", "Epic", "Ultra", "Legendary", "Legendary", "Mythic", "Mythic", "Divine", "Divine", "Cosmic", "Cosmic", "Celestial", "Celestial", "Secret", "Secret", "Ancient", "Ancient", "Unknown" }

-- Specific hamsters (stable species ids) that a rebirth demands instead of a generic rarity.
RebirthConfig.RequiredSpecies = { [1] = "silver" }

export type Requirement = { Kind: string, Label: string, Need: number, Rarity: string?, SpeciesId: string? }

-- Coins needed to perform rebirth number `n` (n = current rebirths + 1).
function RebirthConfig.cost(n: number): number
	return RebirthConfig.CostBase * RebirthConfig.CostGrowth ^ (n - 1)
end

function RebirthConfig.requiredHamsters(n: number): number
	return RebirthConfig.BaseSlots + n
end

function RebirthConfig.requiredRarity(n: number): string
	return REQUIRED_RARITY[math.min(n, #REQUIRED_RARITY)]
end

-- Permanent income step per rebirth, boosted by the Rebirth Boost token upgrade (`boostLevel`).
function RebirthConfig.incomeStep(boostLevel: number): number
	return RebirthConfig.IncomeStep * (1 + 0.1 * boostLevel)
end

-- Permanent income multiplier shown on the rebirth screen.
function RebirthConfig.multiplier(rebirths: number, boostLevel: number): number
	return 1 + rebirths * RebirthConfig.incomeStep(boostLevel)
end

function RebirthConfig.luckMultiplier(rebirths: number): number
	return 1 + rebirths * RebirthConfig.LuckStep
end

function RebirthConfig.tokenReward(n: number): number
	return 1 + math.floor((n - 1) / 3)
end

function RebirthConfig.gemReward(n: number): number
	return RebirthConfig.GemReward
end

function RebirthConfig.startingCoins(rebirths: number): number
	return 250 * (1 + rebirths)
end

-- Hamster slots earned through rebirths (+1 every rebirth).
function RebirthConfig.bonusSlots(rebirths: number): number
	return rebirths
end

-- How many of your best hamsters survive a rebirth.
function RebirthConfig.keepsakes(rebirths: number): number
	if rebirths <= 0 then
		return 0
	end
	return math.min(1 + rebirths // 3, 6)
end

-- Extra upgrade levels unlocked by rebirths (advanced upgrade tiers).
function RebirthConfig.upgradeTier(rebirths: number): number
	local tier = 0
	for _, needed in RebirthConfig.AdvancedUpgradeRebirths do
		if rebirths >= needed then
			tier += 1
		end
	end
	return tier
end

-- Tower trim colour name by rebirth.
function RebirthConfig.trim(rebirths: number): string
	if rebirths >= 20 then
		return "Diamond"
	elseif rebirths >= 10 then
		return "Gold"
	elseif rebirths >= 5 then
		return "Silver"
	end
	return "Wood"
end

-- The three requirements of rebirth `n`, in the order the UI shows them.
function RebirthConfig.requirements(n: number): { Requirement }
	local rarityId = RebirthConfig.requiredRarity(n)
	local speciesId = RebirthConfig.RequiredSpecies[n]
	local third = { Kind = "Rarity", Label = rarityId .. " hamster", Need = 1, Rarity = rarityId }
	if speciesId then
		local species = HamsterDatabase.ById[speciesId]
		third = { Kind = "Species", Label = (if species then species.Name else speciesId) .. " hamster", Need = 1, SpeciesId = speciesId }
	end
	return {
		{ Kind = "Coins", Label = "Cash", Need = RebirthConfig.cost(n) },
		{ Kind = "Hamsters", Label = "Hamsters in your collection", Need = RebirthConfig.requiredHamsters(n) },
		third,
	}
end

-- How far a profile is from rebirth `n`. Returns allMet and one entry per requirement with Have / Met.
function RebirthConfig.check(data: any, n: number): (boolean, { { Kind: string, Label: string, Need: number, Have: number, Met: boolean, Rarity: string?, SpeciesId: string? } })
	local needRank = RarityConfig.rank(RebirthConfig.requiredRarity(n))
	local owned, ofRarity = 0, 0
	for speciesId, count in data.Inventory do
		if count > 0 then
			owned += count
			local species = HamsterDatabase.ById[speciesId]
			if species and RarityConfig.rank(species.Rarity) >= needRank then
				ofRarity += count
			end
		end
	end
	local allMet = true
	local list = {}
	for _, requirement in RebirthConfig.requirements(n) do
		local have = if requirement.Kind == "Coins" then data.Coins
			elseif requirement.Kind == "Hamsters" then owned
			elseif requirement.Kind == "Species" then (data.Inventory[requirement.SpeciesId] or 0)
			else ofRarity
		local met = have >= requirement.Need
		allMet = allMet and met
		table.insert(list, { Kind = requirement.Kind, Label = requirement.Label, Need = requirement.Need, Have = have, Met = met, Rarity = requirement.Rarity, SpeciesId = requirement.SpeciesId })
	end
	return allMet, list
end

export type Reward = { Icon: string, Text: string }

-- Everything rebirth number `n` gives (for the UI and the announcement).
function RebirthConfig.rewards(n: number, boostLevel: number?): { Reward }
	local boost = boostLevel or 0
	local list: { Reward } = {}
	table.insert(list, { Icon = "slot", Text = string.format("+1 hamster slot (%d total)", RebirthConfig.BaseSlots + RebirthConfig.bonusSlots(n)) })
	table.insert(list, { Icon = "income", Text = string.format("+%d%% permanent income (x%.2f total)", math.floor(RebirthConfig.incomeStep(boost) * 100 + 0.5), RebirthConfig.multiplier(n, boost)) })
	table.insert(list, { Icon = "luck", Text = string.format("+%d%% permanent luck", math.floor(RebirthConfig.LuckStep * 100 + 0.5)) })
	local floor = FloorConfig.unlockedAt(n)
	if floor then
		table.insert(list, { Icon = "floor", Text = string.format("NEW FLOOR %d: %s", floor.Index, floor.Name) })
	end
	local tierBefore, tierAfter = RebirthConfig.upgradeTier(n - 1), RebirthConfig.upgradeTier(n)
	if tierAfter > tierBefore then
		table.insert(list, { Icon = "upgrade", Text = string.format("Advanced upgrades, tier %d (more levels)", tierAfter) })
	end
	if RebirthConfig.keepsakes(n) > RebirthConfig.keepsakes(n - 1) then
		table.insert(list, { Icon = "keep", Text = string.format("Keep your %d best hamster%s through rebirth", RebirthConfig.keepsakes(n), if RebirthConfig.keepsakes(n) > 1 then "s" else "") })
	end
	for _, tier in SecurityConfig.Tiers do
		if tier.MinRebirth == n and n > 0 then
			table.insert(list, { Icon = "security", Text = string.format("Better gate: %s (%ds)", tier.Name, tier.Duration) })
		end
	end
	for _, id in RarityConfig.Order do
		local definition = RarityConfig.ById[id]
		if definition.MinRebirth == n then
			table.insert(list, { Icon = "hamster", Text = if definition.Hidden then "A mysterious new rarity starts appearing" else string.format("%s hamsters start appearing", definition.Name) })
		end
	end
	if RebirthConfig.trim(n) ~= RebirthConfig.trim(n - 1) then
		table.insert(list, { Icon = "trim", Text = string.format("%s trim on your tower", RebirthConfig.trim(n)) })
	end
	table.insert(list, { Icon = "gems", Text = string.format("+%d gems, +%d rebirth token%s", RebirthConfig.gemReward(n), RebirthConfig.tokenReward(n), if RebirthConfig.tokenReward(n) > 1 then "s" else "") })
	return list
end

-- What a rebirth resets and what it keeps (shown before you confirm).
RebirthConfig.ResetList = {
	"Coins",
	"Your owned hamsters (except your best keepsakes)",
	"Coin upgrades (training, range, multiplier, luck, speed, storage)",
}
RebirthConfig.KeepList = {
	"Hamster Index, discoveries and collection bonuses",
	"Rebirth level, income multiplier, luck, floors and tower trim",
	"Token upgrades, gems and tokens",
	"Quests, achievements, daily streak, codes",
	"Cosmetics and gamepasses",
}

return RebirthConfig
