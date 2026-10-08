--[[
	Collection rewards. Everything is derived from the Hamster Index (data.Index), so it can never go
	out of sync and needs no claiming:

	  Milestones  "find N hamsters of one rarity" -> a permanent % bonus to Coins or Luck
	  Titles      complete a whole rarity -> "<Rarity> Collector"; complete the Index -> "Hamster Master"
	  Final       the whole Index: +50% coins forever, the title and a one-time gem / token reward (claimed in the Index)

	The old per-rarity gem reward (RarityConfig.IndexReward) still exists and is claimed in the Index too.
]]

local HamsterDatabase = require(script.Parent.HamsterDatabase)
local RarityConfig = require(script.Parent.RarityConfig)

local IndexRewardConfig = {}

export type Milestone = { Id: string, Rarity: string, Count: number, Stat: string, Percent: number }

local function m(rarity: string, count: number, stat: string, percent: number): Milestone
	return { Id = string.lower(rarity) .. count, Rarity = rarity, Count = count, Stat = stat, Percent = percent }
end

IndexRewardConfig.Milestones = {
	m("Basic", 10, "Coins", 0.05),
	m("Cute", 10, "Luck", 0.05),
	m("Shiny", 10, "Coins", 0.05),
	m("Rare", 8, "Luck", 0.05),
	m("Epic", 10, "Coins", 0.08),
	m("Ultra", 8, "Luck", 0.08),
	m("Legendary", 5, "Coins", 0.10),
	m("Legendary", 10, "Luck", 0.05),
	m("Mythic", 6, "Coins", 0.10),
	m("Divine", 6, "Luck", 0.10),
	m("Cosmic", 6, "Coins", 0.12),
	m("Celestial", 5, "Luck", 0.12),
	m("Secret", 5, "Coins", 0.15),
	m("Ancient", 5, "Luck", 0.15),
	m("Unknown", 3, "Coins", 0.20),
} :: { Milestone }

IndexRewardConfig.FinalReward = { Gems = 25000, Tokens = 25, CoinPercent = 0.5, Title = "Hamster Master" }
IndexRewardConfig.FinalKey = "__ALL" -- key in data.IndexRewards once the final reward was claimed

-- How many hamsters of a rarity were ever found (exclusives count too).
function IndexRewardConfig.found(data: any, rarityId: string): number
	local count = 0
	for _, species in HamsterDatabase.ByRarity[rarityId] or {} do
		if data.Index[species.Id] then
			count += 1
		end
	end
	return count
end

function IndexRewardConfig.isDone(data: any, milestone: Milestone): boolean
	return IndexRewardConfig.found(data, milestone.Rarity) >= milestone.Count
end

-- Complete = every hamster that can spawn in this rarity has been found.
function IndexRewardConfig.rarityComplete(data: any, rarityId: string): boolean
	local pool = HamsterDatabase.Spawnable[rarityId]
	if not pool or #pool == 0 then
		return false
	end
	for _, species in pool do
		if not data.Index[species.Id] then
			return false
		end
	end
	return true
end

function IndexRewardConfig.finalComplete(data: any): boolean
	for _, rarityId in RarityConfig.Order do
		if #HamsterDatabase.Spawnable[rarityId] > 0 and not IndexRewardConfig.rarityComplete(data, rarityId) then
			return false
		end
	end
	return true
end

-- Total permanent bonus (0.15 = +15%) for "Coins" or "Luck".
function IndexRewardConfig.bonus(data: any, stat: string): number
	local total = 0
	for _, milestone in IndexRewardConfig.Milestones do
		if milestone.Stat == stat and IndexRewardConfig.isDone(data, milestone) then
			total += milestone.Percent
		end
	end
	if stat == "Coins" and IndexRewardConfig.finalComplete(data) then
		total += IndexRewardConfig.FinalReward.CoinPercent
	end
	return total
end

-- The best title earned so far (nil if none).
function IndexRewardConfig.title(data: any): string?
	if IndexRewardConfig.finalComplete(data) then
		return IndexRewardConfig.FinalReward.Title
	end
	local best: string? = nil
	for _, rarityId in RarityConfig.Order do
		if IndexRewardConfig.rarityComplete(data, rarityId) then
			best = RarityConfig.ById[rarityId].Name .. " Collector"
		end
	end
	return best
end

return IndexRewardConfig
