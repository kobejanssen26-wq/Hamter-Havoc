--[[
	ItemView: client-side helpers shared by the hotbar, backpack and shop to describe an item (ItemRegistry) and to read
	what the player owns / holds. Display only: ownership and prices are decided by the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Format = require(Modules:WaitForChild("Format"))
local HotbarConfig = require(Modules:WaitForChild("HotbarConfig"))
local ItemRegistry = require(Modules:WaitForChild("ItemRegistry"))
local RarityConfig = require(Modules:WaitForChild("RarityConfig"))

local DataController = require(script.Parent.Parent.Controllers.DataController)
local Theme = require(script.Parent.Theme)

local ItemView = {}

local C = Theme.Colors

function ItemView.rarityColor(def: any): Color3
	local rarity = def.Rarity and RarityConfig.ById[def.Rarity]
	if rarity then
		return if rarity.Hidden then rarity.Accent else rarity.Color
	end
	return C.Line
end

-- How many the player owns (gear 0/1, consumables count) according to the replicated profile.
function ItemView.count(def: any): number
	local data = DataController.Data
	if def.Equip.Kind == "Consume" then
		return (data.Items and data.Items[def.Id]) or 0
	end
	return if data.Gear and data.Gear[def.Id] then 1 else 0
end

-- The item on hotbar slot 2..N, or nil for an empty slot (slot 1 is the built-in paws).
function ItemView.hotbarItem(slot: number): any?
	local hotbar = DataController.Data.Hotbar
	local id = hotbar and hotbar[tostring(slot)]
	local def = ItemRegistry.get(id)
	if def and ItemView.count(def) > 0 then
		return def
	end
	return nil
end

-- The slot an owned item sits on, or nil.
function ItemView.slotOf(def: any): number?
	for slot = 2, HotbarConfig.SlotCount do
		local item = ItemView.hotbarItem(slot)
		if item and item.Id == def.Id then
			return slot
		end
	end
	return nil
end

-- The id of the weapon Tool the character holds, if any.
function ItemView.heldId(): string?
	local character = Players.LocalPlayer.Character
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") then
				local id = child:GetAttribute("ItemId")
				if ItemRegistry.get(id) then
					return id
				end
			end
		end
	end
	return nil
end

local EFFECT_TEXT = { Coins2x = "Double cash", Luck2x = "Double luck", Speed2x = "Double speed", AutoCollect = "Auto collect" }

-- Short readable facts about an item for the detail panels. { { Label, Value } }
function ItemView.stats(def: any): { { string } }
	local equip = def.Equip
	local lines = {}
	if equip.Kind == "Tool" then
		local w = equip.Weapon
		table.insert(lines, { "Type", if w.Type == "Ranged" then "Ranged" else "Melee" })
		table.insert(lines, { "Range", string.format("%d studs", w.Range) })
		table.insert(lines, { "Cooldown", string.format("%.1fs", w.Cooldown) })
		table.insert(lines, { "Knockback", tostring(math.floor(w.Knockback)) })
		table.insert(lines, { "Stun", string.format("%.1fs", w.Stun) })
		table.insert(lines, { "Drop chance", string.format("%d%%", math.floor(w.DropChance * 100 + 0.5)) })
	elseif equip.Kind == "Passive" then
		if equip.Stats.CollectRange then
			table.insert(lines, { "Collect range", string.format("+%s studs", tostring(equip.Stats.CollectRange)) })
		end
		if equip.Stats.WalkSpeed then
			table.insert(lines, { "Walk speed", string.format("+%s", tostring(equip.Stats.WalkSpeed)) })
		end
		table.insert(lines, { "Works", "while you own it" })
	else
		if equip.Effect == "Boost" then
			table.insert(lines, { "Effect", EFFECT_TEXT[equip.BoostId] or equip.BoostId })
			table.insert(lines, { "Lasts", if equip.Seconds >= 120 then string.format("%d min", math.floor(equip.Seconds / 60 + 0.5)) else string.format("%d s", equip.Seconds) })
		else
			table.insert(lines, { "Effect", string.format("%d min of income", equip.Minutes) })
		end
		table.insert(lines, { "Use", "from the hotbar" })
	end
	return lines
end

function ItemView.priceText(def: any): string
	if not def.Price then
		return "Not for sale"
	end
	return string.format("%s %s", Format.short(def.Price), if def.Currency == "Gems" then "diamonds" else "cash")
end

return ItemView
