-- Defensive gadget. Raise it and shoves cannot move or stun you for a few seconds. Not while carrying a hamster
-- (otherwise it would make thefts unstoppable), and it does not stop the theft rules or the hamster drop.
return {
	Id = "bubble_shield",
	DisplayName = "Bubble Shield",
	Description = "Blocks knockback and stun for 3 seconds. Can't be used while carrying a hamster.",
	Category = "Weapon",
	Icon = "shield",
	Rarity = "Rare",
	Currency = "Coins",
	Price = 120000,
	MinRebirth = 2,
	Equip = {
		Kind = "Tool",
		Weapon = {
			Type = "Guard", Cooldown = 22, Duration = 3,
			Animation = "Weapon_BubbleShield",
			Look = { Style = "shield", Color = "4CA8FF", Accent = "FFE250", Swing = "Raise" },
		},
	},
}
