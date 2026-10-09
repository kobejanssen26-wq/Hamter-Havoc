--[[
	ItemSystem: using hotbar consumables. The client only sends the slot id; the server checks that the player
	really owns one (profile.Items), applies the effect and removes it. Slot definitions live in HotbarConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local EconomyMath = require(Modules.EconomyMath)
local Format = require(Modules.Format)
local HotbarConfig = require(Modules.HotbarConfig)

local DataSystem = require(script.Parent.DataSystem)
local EconomySystem = require(script.Parent.EconomySystem)
local ReplicationSystem = require(script.Parent.ReplicationSystem)

local ItemSystem = {}

local USE_COOLDOWN = 0.4
local lastUse: { [Player]: number } = {}

function ItemSystem.count(data: any, itemId: string): number
	return data.Items[itemId] or 0
end

-- Returns (ok, message)
function ItemSystem.use(player: Player, slotId: any): (boolean, string)
	local data = DataSystem.get(player)
	local slot = if type(slotId) == "string" then HotbarConfig.ById[slotId] else nil
	if not data or not slot then
		return false, "Unknown item"
	end
	if slot.Kind ~= "Consumable" then
		return false, slot.Name .. " is used with its own key"
	end
	local clock = os.clock()
	if (lastUse[player] or 0) + USE_COOLDOWN > clock then
		return false, "Too fast"
	end
	lastUse[player] = clock

	if ItemSystem.count(data, slot.Id) <= 0 then
		return false, string.format("You don't own %s - buy it in the shop", slot.Name)
	end

	local message
	if slot.Effect == "Boost" then
		EconomySystem.addBoost(player, slot.BoostId :: string, slot.Seconds :: number)
		message = slot.Name .. " activated!"
	elseif slot.Effect == "Pouch" then
		local amount = math.max(1000, EconomyMath.incomePerSecond(data, os.time()) * 60 * (slot.Minutes :: number))
		EconomySystem.addCoins(player, amount, false)
		message = "+" .. Format.coins(amount) .. " cash"
	else
		return false, "Unsupported item"
	end

	local left = data.Items[slot.Id] - 1
	data.Items[slot.Id] = if left > 0 then left else nil
	ReplicationSystem.mark(player, "Items")
	return true, message
end

function ItemSystem.forget(player: Player)
	lastUse[player] = nil
end

return ItemSystem
