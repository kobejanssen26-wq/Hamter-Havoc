--[[
	GearSystem: ownership, hotbar layout and equipping of weapons / equipment / consumables (ItemRegistry).
	Everything here is server authoritative; the client only asks.

	  profile.Gear[id] = true        owned weapon / equipment
	  profile.Items[id] = count      owned consumables
	  profile.Hotbar["2".."8"] = id  which owned hotbar item sits on which slot (slot 1 is the built-in Slap)

	Weapons are real Tools: they live in the player's Backpack (given again after every respawn) and are equipped with
	Humanoid:EquipTool - the same thing Roblox's own hotbar would do. Nothing can be equipped that is not owned.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local HotbarConfig = require(Modules.HotbarConfig)
local ItemRegistry = require(Modules.ItemRegistry)

local DataSystem = require(script.Parent.DataSystem)
local Events = require(script.Parent.Events)
local PlayerState = require(script.Parent.PlayerState)
local ReplicationSystem = require(script.Parent.ReplicationSystem)
local ToolBuilder = require(script.Parent.ToolBuilder)

local GearSystem = {}

GearSystem.MaxStack = 99

local lastEquip: { [Player]: number } = {}

local function slotKey(slot: number): string
	return tostring(slot)
end

---------------------------------------------------------------------------
-- hotbar layout
---------------------------------------------------------------------------

-- Slot (2..N) an item sits on, or nil.
function GearSystem.slotOf(data: any, itemId: string): number?
	for key, id in data.Hotbar do
		if id == itemId then
			return tonumber(key)
		end
	end
	return nil
end

-- Removes entries for items that are unknown or no longer owned (migration + after the last consumable is used).
function GearSystem.clean(data: any)
	for key, id in table.clone(data.Hotbar) do
		local def = ItemRegistry.ById[id]
		local slot = tonumber(key)
		if not def or not slot or not HotbarConfig.validSlot(slot) or not ItemRegistry.hotbarCapable(def) or ItemRegistry.owned(data, id) <= 0 then
			data.Hotbar[key] = nil
		end
	end
end

-- Puts every owned hotbar item that has no slot yet into the first free slot.
function GearSystem.fill(data: any)
	GearSystem.clean(data)
	for _, def in ItemRegistry.List do
		if ItemRegistry.hotbarCapable(def) and ItemRegistry.owned(data, def.Id) > 0 and not GearSystem.slotOf(data, def.Id) then
			for slot = 2, HotbarConfig.SlotCount do
				if data.Hotbar[slotKey(slot)] == nil then
					data.Hotbar[slotKey(slot)] = def.Id
					break
				end
			end
		end
	end
end

-- Moves an owned item to a slot (swaps with whatever is there). Returns (ok, message).
function GearSystem.moveSlot(player: Player, itemId: any, slot: any): (boolean, string)
	local data = DataSystem.get(player)
	local def = ItemRegistry.get(itemId)
	if not data or not def or not ItemRegistry.hotbarCapable(def) or ItemRegistry.owned(data, def.Id) <= 0 then
		return false, "You don't own that item"
	end
	if not HotbarConfig.validSlot(slot) then
		return false, "Invalid slot"
	end
	local from = GearSystem.slotOf(data, def.Id)
	local occupant = data.Hotbar[slotKey(slot)]
	data.Hotbar[slotKey(slot)] = def.Id
	if from and from ~= slot then
		data.Hotbar[slotKey(from)] = occupant
	end
	GearSystem.clean(data)
	ReplicationSystem.mark(player, "Hotbar")
	return true, "Moved"
end

---------------------------------------------------------------------------
-- ownership
---------------------------------------------------------------------------

-- Gives the player one of an item (gear: owned for good, consumable: +1). Returns (ok, message).
-- The caller has already validated and charged; this only grants.
function GearSystem.grant(player: Player, itemId: string): (boolean, string)
	local data = DataSystem.get(player)
	local def = ItemRegistry.get(itemId)
	if not data or not def then
		return false, "Unknown item"
	end
	if def.Equip.Kind == "Consume" then
		if (data.Items[itemId] or 0) >= GearSystem.MaxStack then
			return false, string.format("You can hold at most %d of these", GearSystem.MaxStack)
		end
		data.Items[itemId] = (data.Items[itemId] or 0) + 1
		ReplicationSystem.mark(player, "Items")
	else
		if data.Gear[itemId] then
			return false, "You already own this"
		end
		data.Gear[itemId] = true
		ReplicationSystem.mark(player, "Gear")
	end
	GearSystem.fill(data)
	ReplicationSystem.mark(player, "Hotbar")
	if def.Equip.Kind == "Tool" then
		GearSystem.giveTools(player)
	end
	if def.Equip.Kind == "Passive" then
		require(script.Parent.EconomySystem).updateAttributes(player)
		require(script.Parent.PlayerState).apply(player)
	end
	DataSystem.markDirty(player)
	return true, "Added"
end

-- Called after the last consumable of an item was used.
function GearSystem.afterUse(player: Player)
	local data = DataSystem.get(player)
	if data then
		GearSystem.clean(data)
		ReplicationSystem.mark(player, "Hotbar")
	end
end

-- Discards consumables (never weapons / equipment: those were paid for and are kept). Returns (ok, message).
function GearSystem.discard(player: Player, itemId: any, amount: any): (boolean, string)
	local data = DataSystem.get(player)
	local def = ItemRegistry.get(itemId)
	if not data or not def or def.Equip.Kind ~= "Consume" then
		return false, "Only consumables can be discarded"
	end
	if type(amount) ~= "number" or amount ~= amount or amount < 1 then
		return false, "Invalid amount"
	end
	amount = math.min(math.floor(amount), data.Items[itemId] or 0)
	if amount < 1 then
		return false, "You don't have any"
	end
	local left = data.Items[itemId] - amount
	data.Items[itemId] = if left > 0 then left else nil
	ReplicationSystem.mark(player, "Items")
	GearSystem.afterUse(player)
	DataSystem.markDirty(player)
	return true, string.format("Discarded %d", amount)
end

---------------------------------------------------------------------------
-- tools
---------------------------------------------------------------------------

local function ownedToolIds(data: any): { string }
	local ids = {}
	for _, def in ItemRegistry.List do
		if def.Equip.Kind == "Tool" and data.Gear[def.Id] then
			table.insert(ids, def.Id)
		end
	end
	return ids
end

local function findTool(container: Instance?, itemId: string): Tool?
	if not container then
		return nil
	end
	for _, child in container:GetChildren() do
		if child:IsA("Tool") and child:GetAttribute("ItemId") == itemId then
			return child
		end
	end
	return nil
end

-- Makes the Backpack contain exactly the owned weapon tools (no duplicates, nothing unowned).
function GearSystem.giveTools(player: Player)
	local data = DataSystem.get(player)
	if not data then
		return
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	local owned = {}
	for _, id in ownedToolIds(data) do
		owned[id] = true
	end
	-- remove tools that are not owned (or duplicates) from the backpack and the character
	for _, container in { backpack :: Instance, player.Character } do
		if container then
			local seen = {}
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("ItemId") then
					local id = child:GetAttribute("ItemId")
					if not owned[id] or seen[id] then
						child:Destroy()
					end
					seen[id] = true
				end
			end
		end
	end
	for id in owned do
		if not findTool(backpack, id) and not findTool(player.Character, id) then
			local tool = ToolBuilder.build(ItemRegistry.ById[id])
			tool.Parent = backpack
		end
	end
end

-- The weapon the player currently holds: (definition, tool) or nil. Only owned weapons count.
function GearSystem.equippedWeapon(player: Player): (any?, Tool?)
	local data = DataSystem.get(player)
	local character = player.Character
	if not data or not character then
		return nil, nil
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then
			local def = ItemRegistry.get(child:GetAttribute("ItemId"))
			if def and def.Equip.Kind == "Tool" and data.Gear[def.Id] then
				return def, child
			end
		end
	end
	return nil, nil
end

-- Equip (toggle off when it is already held). Returns (ok, message).
function GearSystem.equip(player: Player, itemId: any): (boolean, string)
	local data = DataSystem.get(player)
	local def = ItemRegistry.get(itemId)
	if not data or not def or def.Equip.Kind ~= "Tool" or not data.Gear[def.Id] then
		return false, "You don't own that weapon"
	end
	local humanoid = PlayerState.character(player)
	if not humanoid then
		return false, "You can't equip right now"
	end
	if PlayerState.isStunned(player) then
		return false, "You can't equip while stunned"
	end
	local clock = os.clock()
	if (lastEquip[player] or 0) + 0.15 > clock then
		return false, "Too fast"
	end
	lastEquip[player] = clock
	local held = GearSystem.equippedWeapon(player)
	if held and held.Id == def.Id then
		humanoid:UnequipTools()
		return true, "Unequipped"
	end
	GearSystem.giveTools(player)
	local tool = findTool(player:FindFirstChildOfClass("Backpack"), def.Id) or findTool(player.Character, def.Id)
	if not tool then
		return false, "Weapon unavailable"
	end
	humanoid:EquipTool(tool)
	return true, "Equipped"
end

function GearSystem.unequip(player: Player): (boolean, string)
	local humanoid = PlayerState.character(player)
	if not humanoid then
		return false, "Nothing to unequip"
	end
	humanoid:UnequipTools()
	return true, "Unequipped"
end

---------------------------------------------------------------------------
-- lifecycle
---------------------------------------------------------------------------

function GearSystem.start()
	Events.ProfileLoaded:Connect(function(player)
		local data = DataSystem.get(player)
		if data then
			GearSystem.fill(data) -- migrates old saves: consumables you already own get hotbar slots
			ReplicationSystem.mark(player, "Hotbar")
			GearSystem.giveTools(player)
		end
	end)
	local function onCharacter(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(GearSystem.giveTools, player) -- tools do not survive a respawn: hand them out again
		end)
	end
	for _, player in Players:GetPlayers() do
		onCharacter(player)
	end
	Players.PlayerAdded:Connect(onCharacter)
end

function GearSystem.forget(player: Player)
	lastEquip[player] = nil
end

return GearSystem
