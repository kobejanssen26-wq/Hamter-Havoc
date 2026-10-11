-- Melee weapon. Stats are enforced by the SERVER (CombatSystem): range, arc, cooldown, knockback, stun, chance that a hit carrier drops the hamster.
return {
	Id = "foam_bat",
	DisplayName = "Squeak Bat",
	Description = "Your first weapon. A quick swing that knocks thieves off balance and makes them drop the hamster.",
	Category = "Weapon",
	Icon = "bat",
	Rarity = "Basic",
	Currency = "Coins",
	Price = 8000,
	MinRebirth = 0,
	Equip = {
		Kind = "Tool",
		Weapon = { Type = "Melee", Range = 9, Arc = 0.1, Cooldown = 0.8, Knockback = 44, Stun = 1.0, DropChance = 0.85, Look = { Style = "bat", Color = "E8B070", Accent = "FF6B6B" } },
	},
}
