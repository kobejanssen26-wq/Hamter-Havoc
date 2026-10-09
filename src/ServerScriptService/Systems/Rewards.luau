--[[
	One function that hands out any reward table:
	{ Coins, Gems, Tokens, Boost = { Id, Seconds }, Hamster = speciesId }
	Used by quests, achievements, dailies, codes, index completion and rebirths.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local Format = require(Modules.Format)
local HamsterDatabase = require(Modules.HamsterDatabase)
local ShopConfig = require(Modules.ShopConfig)

local CollectionSystem = require(script.Parent.CollectionSystem)
local EconomySystem = require(script.Parent.EconomySystem)
local Notifier = require(script.Parent.Notifier)

local Rewards = {}

-- Returns readable lines ("+500 coins", ...). Coins are fixed (no multiplier); gems use the gem multiplier.
function Rewards.grant(player: Player, reward: any): { string }
	local lines = {}
	if reward.Coins then
		EconomySystem.addCoins(player, reward.Coins, false)
		table.insert(lines, "+" .. Format.short(reward.Coins) .. " cash")
	end
	if reward.Gems then
		local gained = EconomySystem.addGems(player, reward.Gems, true)
		table.insert(lines, "+" .. Format.short(gained) .. " diamonds")
	end
	if reward.Tokens then
		EconomySystem.addTokens(player, reward.Tokens)
		table.insert(lines, "+" .. reward.Tokens .. " rebirth tokens")
	end
	if reward.Boost then
		EconomySystem.addBoost(player, reward.Boost.Id, reward.Boost.Seconds)
		local info = ShopConfig.Boosts[reward.Boost.Id]
		table.insert(lines, string.format("%s (%d min)", if info then info.Name else reward.Boost.Id, math.floor(reward.Boost.Seconds / 60)))
	end
	if reward.Hamster then
		local species = HamsterDatabase.ById[reward.Hamster]
		if species then
			CollectionSystem.grant(player, reward.Hamster, "Reward")
			table.insert(lines, species.Name .. " hamster!")
		end
	end
	return lines
end

function Rewards.describe(lines: { string }): string
	return table.concat(lines, ", ")
end

function Rewards.grantAndNotify(player: Player, title: string, reward: any): string
	local text = Rewards.describe(Rewards.grant(player, reward))
	Notifier.send(player, title .. ": " .. text, "reward")
	return text
end

return Rewards
