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
		if w.Type == "Freeze" then
			table.insert(lines, { "Ability", "Freeze a player" })
			table.insert(lines, { "Frozen for", string.format("%.1f s", w.Duration) })
			table.insert(lines, { "Range", string.format("%d studs", w.Range) })
			table.insert(lines, { "Cooldown", string.format("%d s", w.Cooldown) })
		elseif w.Type == "Cloak" then
			table.insert(lines, { "Ability", "Near invisibility" })
			table.insert(lines, { "Lasts", string.format("%d s", w.Duration) })
			table.insert(lines, { "Cooldown", string.format("%d s", w.Cooldown) })
			table.insert(lines, { "Counter", "Sparkle trail, ends on hit" })
		elseif w.Type == "Decoy" then
			table.insert(lines, { "Ability", "See-through decoy" })
			table.insert(lines, { "Lasts", string.format("%d s", w.Duration) })
			table.insert(lines, { "Cooldown", string.format("%d s", w.Cooldown) })
			table.insert(lines, { "Counter", "Cyan outline, pops on hit" })
		elseif w.Type == "Trap" then
			table.insert(lines, { "Ability", ({ Spike = "Spikes: stun + drops a carried hamster", Glue = "Glue: slows to " .. math.floor((w.Slow or 0.4) * 100) .. "% speed", Banana = "Banana: slips and flings" })[w.TrapKind] or "Trap" })
			table.insert(lines, { "Max set", string.format("%d at a time, %d s each", w.MaxActive, w.Duration) })
			table.insert(lines, { "Cooldown", string.format("%d s", w.Cooldown) })
			table.insert(lines, { "Limit", "Not while carrying a hamster; not in safe zones" })
		elseif w.Type == "Glider" then
			table.insert(lines, { "Ability", "Glide through the air" })
			table.insert(lines, { "Glide time", string.format("%d s (click again to land)", w.Duration) })
			table.insert(lines, { "Speed", string.format("%d studs/s, falls only %d studs/s", w.Speed, w.FallSpeed) })
			table.insert(lines, { "Recharge", string.format("%d s after the glide", w.Cooldown) })
			table.insert(lines, { "Needs", "You must be in the air to start" })
		elseif w.Type == "Rocket" then
			table.insert(lines, { "Ability", "Rocket boost" })
			table.insert(lines, { "Launch", string.format("%d up, %d forward", w.Boost, w.Forward) })
			table.insert(lines, { "Cooldown", string.format("%d s", w.Cooldown) })
			table.insert(lines, { "Not while", "stunned, frozen or in a safe-zone-free fall" })
		elseif w.Type == "Guard" then
			table.insert(lines, { "Ability", "Shield: blocks knockback and stun" })
			table.insert(lines, { "Lasts", string.format("%d s", w.Duration) })
			table.insert(lines, { "Cooldown", string.format("%d s", w.Cooldown) })
			table.insert(lines, { "Limit", "Not while carrying a hamster" })
		else
			table.insert(lines, { "Type", if w.Type == "Ranged" then "Ranged" else "Melee" })
			table.insert(lines, { "Range", string.format("%d studs", w.Range) })
			table.insert(lines, { "Cooldown", string.format("%.1fs", w.Cooldown) })
			table.insert(lines, { "Knockback", tostring(math.floor(w.Knockback)) })
			table.insert(lines, { "Stun", string.format("%.1fs", w.Stun) })
			table.insert(lines, { "Drop chance", string.format("%d%%", math.floor(w.DropChance * 100 + 0.5)) })
		end
		if def.MinRebirth and def.MinRebirth > 0 then
			table.insert(lines, { "Unlocks at", string.format("Rebirth %d", def.MinRebirth) })
		end
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
