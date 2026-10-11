--[[
	ItemRegistry: every item the player can own besides hamsters - weapons, equipment, consumables. One file per item in
	Modules/Content/Items (see _Template.luau). Shop, backpack, hotbar, tools, combat and the economy all read THIS
	registry, so adding a valid file makes the item appear everywhere it belongs:

	  Category Weapon      a real Tool (built by the server), sold in the Shop > Weapons, equipped from the hotbar
	  Category Equipment   a passive item, sold in Shop > Equipment, its Stats apply while you own it
	  Category Consumable  counted item (boosts, pouch), bought in Shop > Boosts, used from the hotbar

	Ownership: weapons/equipment live in profile.Gear[id] = true, consumables in profile.Items[id] = count.
	Definitions that fail validation are skipped and listed in ItemRegistry.Issues (ContentCheck prints them).
]]

local ContentRegistry = require(script.Parent.ContentRegistry)
local ContentValidator = require(script.Parent.ContentValidator)
local RarityConfig = require(script.Parent.RarityConfig)

local ItemRegistry = {}

ItemRegistry.List = {} :: { any }
ItemRegistry.ById = {} :: { [string]: any }
ItemRegistry.Issues = {} :: { ContentValidator.Issue }

-- Which shop category sells an item of this category.
ItemRegistry.ShopCategory = { Weapon = "Weapons", Equipment = "Equipment", Consumable = "Boosts" }

local assets = game:GetService("ReplicatedStorage"):FindFirstChild("Assets")

do
	local loaded, problems = ContentRegistry.load("Items")
	for _, message in problems do
		table.insert(ItemRegistry.Issues, { Level = "error", Kind = "Item", Id = "?", Message = message })
	end
	local context = {
		Rarities = RarityConfig.ById,
		ExistingIds = ItemRegistry.ById,
		ModelExists = function(name: string): boolean
			local folder = assets and assets:FindFirstChild("Tools")
			return folder ~= nil and folder:FindFirstChild(name) ~= nil
		end,
	}
	for _, entry in loaded do
		local found = ContentValidator.validateItem(entry.Def, context)
		local fatal = false
		for _, problem in found do
			table.insert(ItemRegistry.Issues, problem)
			fatal = fatal or problem.Level == "error"
		end
		if not fatal then
			table.insert(ItemRegistry.List, entry.Def)
			ItemRegistry.ById[entry.Def.Id] = entry.Def
		end
	end
	-- shop order: by the rebirth that unlocks it, then price (so the unlock ladder reads top to bottom)
	table.sort(ItemRegistry.List, function(a, b)
		local ar, br = a.MinRebirth or 0, b.MinRebirth or 0
		if ar ~= br then
			return ar < br
		end
		local ap, bp = a.Price or 0, b.Price or 0
		if ap ~= bp then
			return ap < bp
		end
		return a.Id < b.Id
	end)
end

function ItemRegistry.get(id: any): any?
	return if type(id) == "string" then ItemRegistry.ById[id] else nil
end

-- Can this item sit on the hotbar? (weapons and consumables; passive equipment does not need a slot)
function ItemRegistry.hotbarCapable(def: any): boolean
	return def.Equip.Kind == "Tool" or def.Equip.Kind == "Consume"
end

function ItemRegistry.isConsumable(def: any): boolean
	return def.Equip.Kind == "Consume"
end

-- How many of the item the profile owns (gear: 0 or 1, consumables: the stored count).
function ItemRegistry.owned(data: any, id: string): number
	local def = ItemRegistry.ById[id]
	if not def then
		return 0
	end
	if def.Equip.Kind == "Consume" then
		return (data.Items and data.Items[id]) or 0
	end
	return if data.Gear and data.Gear[id] then 1 else 0
end

-- Sum of one passive stat over every owned Equipment item.
function ItemRegistry.gearBonus(data: any, stat: string): number
	local total = 0
	if data.Gear then
		for id, owned in data.Gear do
			local def = if owned then ItemRegistry.ById[id] else nil
			if def and def.Equip.Kind == "Passive" then
				total += def.Equip.Stats[stat] or 0
			end
		end
	end
	return total
end

return ItemRegistry
