-- Knockback weapon. The glove springs out of its coil: big shove, narrow, slow.
return {
	Id = "spring_glove",
	DisplayName = "Spring Boxing Glove",
	Description = "Punches out on a spring and launches thieves backwards. Narrow and slow.",
	Category = "Weapon",
	Icon = "spring",
	Rarity = "Rare",
	Currency = "Coins",
	Price = 40000,
	MinRebirth = 1,
	Equip = {
		Kind = "Tool",
		Weapon = {
			Type = "Melee", Range = 12, Arc = 0.45, Cooldown = 1.7, WindUp = 0.22, Active = 0.16,
			Knockback = 60, Lift = 24, Stun = 0.6, DropChance = 0.6,
			Animation = "Weapon_SpringGlove",
			Look = { Style = "spring", Color = "EB343E", Accent = "BEC6D6", Swing = "Punch" },
		},
	},
}
