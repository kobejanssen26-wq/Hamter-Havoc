--[[
	RebirthSystem. Rebirth n costs 10^(n+3) coins. It resets coins, coin-upgrades, your inventory and
	display, and keeps: the Hamster Index, gems, rebirth tokens + token upgrades, quests, achievements.
	In return: a permanent multiplier, gems, tokens, and new rarities / house slots.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local Format = require(Modules.Format)
local RebirthConfig = require(Modules.RebirthConfig)
local UpgradeConfig = require(Modules.UpgradeConfig)

local Remotes = require(ReplicatedStorage.Remotes)

local AnnounceSystem = require(script.Parent.AnnounceSystem)
local DataSystem = require(script.Parent.DataSystem)
local EconomySystem = require(script.Parent.EconomySystem)
local Events = require(script.Parent.Events)
local Notifier = require(script.Parent.Notifier)
local ReplicationSystem = require(script.Parent.ReplicationSystem)

local RebirthSystem = {}

-- Returns (ok, message)
function RebirthSystem.perform(player: Player): (boolean, string)
	local data = DataSystem.get(player)
	if not data then
		return false, "No data"
	end
	local nextRebirth = data.Rebirths + 1
	if nextRebirth > RebirthConfig.MaxRebirths then
		return false, "You reached the maximum rebirth!"
	end
	local cost = RebirthConfig.cost(nextRebirth)
	if data.Coins < cost then
		return false, "You need " .. Format.coins(cost) .. " coins to rebirth"
	end

	-- reset
	data.Rebirths = nextRebirth
	EconomySystem.setCoins(player, RebirthConfig.startingCoins(nextRebirth))
	data.Inventory = {}
	data.Equipped = {}
	for id, definition in UpgradeConfig.Definitions do
		if definition.ResetOnRebirth then
			data.Upgrades[id] = nil
		end
	end

	-- rewards
	local gems = EconomySystem.addGems(player, RebirthConfig.gemReward(nextRebirth), true)
	local tokens = RebirthConfig.tokenReward(nextRebirth)
	EconomySystem.addTokens(player, tokens)

	EconomySystem.updateAttributes(player)
	ReplicationSystem.mark(player, "Rebirths", "Inventory", "Equipped", "Upgrades", "Stats")
	Events.EquippedChanged:Fire(player)
	Events.Rebirthed:Fire(player, nextRebirth)
	AnnounceSystem.rebirth(player, nextRebirth)
	Remotes.event("Fx"):FireClient(player, "Rebirth", nextRebirth)
	Notifier.send(player, string.format("REBIRTH %d! +%s gems, +%d tokens", nextRebirth, Format.short(gems), tokens), "reward")
	return true, "Rebirth complete"
end

return RebirthSystem
