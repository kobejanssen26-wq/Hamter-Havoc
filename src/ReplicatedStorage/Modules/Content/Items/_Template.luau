--[[
	ITEM TEMPLATE - copy it, rename the file, edit it. This template is ignored by the game. Full guide: docs/CONTENT_GUIDE.md
	An item with Currency + Price appears in the Shop automatically (Weapon -> Weapons, Equipment -> Equipment) and, once bought,
	in the Backpack and (weapons / consumables) on the hotbar. Nothing else needs to change.

	Category   "Weapon" | "Equipment" | "Consumable"
	Equip      { Kind = "Tool",    Weapon = { Type = "Melee" | "Ranged", Range, Arc, Cooldown, Knockback, Stun, DropChance, Look = { Style, Color, Accent } } }
	           { Kind = "Passive", Stats = { CollectRange = 4, WalkSpeed = 2 } }          (always active while owned)
	           { Kind = "Consume", Effect = "Boost", BoostId = "Coins2x", Seconds = 900 } or { Effect = "Pouch", Minutes = 10 }
	ModelName  optional: a Tool you made in Studio, saved as src/ReplicatedStorage/Assets/Tools/<ModelName>.rbxm (must contain a part named Handle)
]]
return {
	Enabled = false,

	Id = "my_item",
	DisplayName = "My Item",
	Description = "What it does.",
	Category = "Weapon",
	Icon = "star", -- a drawn icon (UI/Icons.luau) or "rbxassetid://<uploaded image>"
	Rarity = "Rare", -- optional: tints the card (a rarity id)
	Currency = "Coins", -- "Coins" (cash) or "Gems" (diamonds); leave out Currency + Price for items that are not sold
	Price = 10000,
	Equip = { Kind = "Tool", Weapon = { Type = "Melee", Range = 9, Arc = 0.1, Cooldown = 1, Knockback = 40, Stun = 1, DropChance = 0.8, Look = { Style = "bat", Color = "E8B070", Accent = "FF6B6B" } } },
}
