-- Heavy hitter. Longest reach of the early weapons and big knockback, but slow to swing again.
-- Stats are enforced by the SERVER (CombatSystem). Hit window = WindUp .. WindUp+Active; Cooldown counts from the start of the swing.
return {
	Id = "foam_bat",
	DisplayName = "Squeak Bat",
	Description = "Long reach, heavy shove. Slow to swing again - make the first hit count.",
	Category = "Weapon",
	Icon = "bat",
	Rarity = "Basic",
	Currency = "Coins",
	Price = 8000,
	MinRebirth = 0,
	Equip = {
		Kind = "Tool",
		Weapon = {
			Type = "Melee", Range = 11, Arc = 0.1, Cooldown = 1.2, WindUp = 0.16, Active = 0.22,
			Knockback = 54, Lift = 18, Stun = 1.0, DropChance = 0.9,
			Animation = "Weapon_SqueakBat",
			Look = { Style = "bat", Color = "E8B070", Accent = "FF6B6B", Swing = "Overhead" },
		},
	},
}
