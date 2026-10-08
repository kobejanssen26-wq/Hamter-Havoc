--[[
	Quests. Each quest is a one-time goal measured by a stat; reward is claimed manually in the Quest UI.
	Stats: HamstersCollected, CoinsEarned, UpgradesBought, Sold, Rebirths, Unique (index size), Found:<RarityId>.
	Reward: { Coins, Gems, Tokens, Boost = { Id, Seconds }, Hamster = speciesId }
]]

local QuestConfig = {}

QuestConfig.Quests = {
	{ Id = "collect10", Title = "First Steps", Desc = "Collect 10 hamsters", Stat = "HamstersCollected", Target = 10, Reward = { Coins = 150 } },
	{ Id = "unique10", Title = "Fresh Collector", Desc = "Collect 10 different hamsters", Stat = "Unique", Target = 10, Reward = { Gems = 60 } },
	{ Id = "upgrade5", Title = "Upgrader", Desc = "Buy 5 upgrades", Stat = "UpgradesBought", Target = 5, Reward = { Coins = 1500 } },
	{ Id = "earn10k", Title = "Pocket Money", Desc = "Earn 10,000 coins", Stat = "CoinsEarned", Target = 10000, Reward = { Boost = { Id = "Coins2x", Seconds = 600 } } },
	{ Id = "findRare", Title = "Something Special", Desc = "Find a Rare hamster", Stat = "Found:Rare", Target = 1, Reward = { Gems = 40 } },
	{ Id = "collect100", Title = "Hamster Fan", Desc = "Collect 100 hamsters", Stat = "HamstersCollected", Target = 100, Reward = { Gems = 80 } },
	{ Id = "unique25", Title = "Growing Index", Desc = "Collect 25 different hamsters", Stat = "Unique", Target = 25, Reward = { Boost = { Id = "Luck2x", Seconds = 600 }, Gems = 60 } },
	{ Id = "findEpic", Title = "Epic Moment", Desc = "Find an Epic hamster", Stat = "Found:Epic", Target = 1, Reward = { Gems = 80 } },
	{ Id = "rebirth1", Title = "Born Again", Desc = "Rebirth once", Stat = "Rebirths", Target = 1, Reward = { Gems = 200, Tokens = 1 } },
	{ Id = "findLegendary", Title = "WAIT, A LEGENDARY?!", Desc = "Find a Legendary hamster", Stat = "Found:Legendary", Target = 1, Reward = { Gems = 250 } },
	{ Id = "earn1m", Title = "Seven Figures", Desc = "Earn 1,000,000 coins", Stat = "CoinsEarned", Target = 1000000, Reward = { Gems = 300 } },
	{ Id = "collect500", Title = "Hamster Hoarder", Desc = "Collect 500 hamsters", Stat = "HamstersCollected", Target = 500, Reward = { Gems = 150, Boost = { Id = "Luck2x", Seconds = 900 } } },
	{ Id = "unique50", Title = "Serious Collector", Desc = "Collect 50 different hamsters", Stat = "Unique", Target = 50, Reward = { Gems = 250, Tokens = 1 } },
	{ Id = "sell10", Title = "Tidy House", Desc = "Sell 10 duplicate hamsters", Stat = "Sold", Target = 10, Reward = { Coins = 2500 } },
	{ Id = "rebirth3", Title = "Triple Rebirth", Desc = "Reach 3 rebirths", Stat = "Rebirths", Target = 3, Reward = { Gems = 500, Tokens = 2 } },
	{ Id = "findMythic", Title = "Myth Hunter", Desc = "Find a Mythic hamster", Stat = "Found:Mythic", Target = 1, Reward = { Gems = 500 } },
}

QuestConfig.ById = {} :: { [string]: any }
for _, quest in QuestConfig.Quests do
	QuestConfig.ById[quest.Id] = quest
end

-- `data` = player profile (server) or the client's copy of it.
function QuestConfig.getStat(data: any, stat: string): number
	if stat == "Unique" then
		local count = 0
		for _ in data.Index do
			count += 1
		end
		return count
	elseif stat == "Rebirths" then
		return data.Rebirths or 0
	elseif string.sub(stat, 1, 6) == "Found:" then
		return (data.Stats.Found or {})[string.sub(stat, 7)] or 0
	end
	return data.Stats[stat] or 0
end

function QuestConfig.isComplete(data: any, quest: any): boolean
	return QuestConfig.getStat(data, quest.Stat) >= quest.Target
end

return QuestConfig
