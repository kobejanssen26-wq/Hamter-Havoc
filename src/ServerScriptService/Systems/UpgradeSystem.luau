--[[
	UpgradeSystem: buys upgrade levels. Cost, currency and max level come from UpgradeConfig;
	nothing the client sends except the upgrade id is trusted.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local FloorConfig = require(Modules.FloorConfig)
local Format = require(Modules.Format)
local UpgradeConfig = require(Modules.UpgradeConfig)

local DataSystem = require(script.Parent.DataSystem)
local EconomySystem = require(script.Parent.EconomySystem)
local Events = require(script.Parent.Events)
local ReplicationSystem = require(script.Parent.ReplicationSystem)

local UpgradeSystem = {}

-- Returns (ok, message, newLevel)
function UpgradeSystem.buy(player: Player, upgradeId: any): (boolean, string, number?)
	local data = DataSystem.get(player)
	local definition = if type(upgradeId) == "string" then UpgradeConfig.Definitions[upgradeId] else nil
	if not data or not definition then
		return false, "Unknown upgrade"
	end

	if not UpgradeConfig.available(definition.Id, FloorConfig.unlocked(data.Rebirths)) then
		return false, string.format("%s unlocks with Floor %d", definition.Name, definition.RequiresFloor or 1)
	end

	local level = data.Upgrades[definition.Id] or 0
	local cost = UpgradeConfig.cost(definition.Id, level, data.Rebirths)
	if not cost then
		return false, definition.Name .. " is already maxed"
	end

	local paid
	if definition.Currency == "Tokens" then
		paid = EconomySystem.trySpendTokens(player, cost)
	else
		paid = EconomySystem.trySpendCoins(player, cost)
	end
	if not paid then
		return false, string.format("Not enough %s (need %s)", string.lower(definition.Currency), Format.short(cost))
	end

	data.Upgrades[definition.Id] = level + 1
	data.Stats.UpgradesBought += 1
	ReplicationSystem.mark(player, "Upgrades", "Stats")
	Events.UpgradeChanged:Fire(player, definition.Id)
	return true, definition.Name .. " upgraded!", level + 1
end

return UpgradeSystem
