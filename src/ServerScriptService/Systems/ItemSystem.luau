--[[
	ItemSystem: using consumables (boosts, cash pouch). The client only sends the item id; the server checks that the
	player really owns one (profile.Items), applies the effect and removes it. Definitions live in Content/Items.
	Weapons and equipment are not "used": see GearSystem.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local EconomyMath = require(Modules.EconomyMath)
local Format = require(Modules.Format)
local ItemRegistry = require(Modules.ItemRegistry)

local DataSystem = require(script.Parent.DataSystem)
local EconomySystem = require(script.Parent.EconomySystem)
local GearSystem = require(script.Parent.GearSystem)
local ReplicationSystem = require(script.Parent.ReplicationSystem)

local ItemSystem = {}

local USE_COOLDOWN = 0.4
local lastUse: { [Player]: number } = {}

function ItemSystem.count(data: any, itemId: string): number
	return data.Items[itemId] or 0
end

-- Returns (ok, message)
function ItemSystem.use(player: Player, itemId: any): (boolean, string)
	local data = DataSystem.get(player)
	local item = ItemRegistry.get(itemId)
	if not data or not item then
		return false, "Unknown item"
	end
	if item.Equip.Kind ~= "Consume" then
		return false, item.DisplayName .. " is equipped, not used up"
	end
	local clock = os.clock()
	if (lastUse[player] or 0) + USE_COOLDOWN > clock then
		return false, "Too fast"
	end
	lastUse[player] = clock

	if ItemSystem.count(data, item.Id) <= 0 then
		return false, string.format("You don't own %s - buy it in the shop", item.DisplayName)
	end

	local effect = item.Equip
	local message
	if effect.Effect == "Boost" then
		EconomySystem.addBoost(player, effect.BoostId :: string, effect.Seconds :: number)
		message = item.DisplayName .. " activated!"
	elseif effect.Effect == "Pouch" then
		local amount = math.max(1000, EconomyMath.incomePerSecond(data, os.time()) * 60 * (effect.Minutes :: number))
		EconomySystem.addCoins(player, amount, false)
		message = "+" .. Format.coins(amount) .. " cash"
	else
		return false, "Unsupported item"
	end

	local left = data.Items[item.Id] - 1
	data.Items[item.Id] = if left > 0 then left else nil
	ReplicationSystem.mark(player, "Items")
	if left <= 0 then
		GearSystem.afterUse(player)
	end
	return true, message
end

function ItemSystem.forget(player: Player)
	lastUse[player] = nil
end

return ItemSystem
