-- Control weapon. Short reach, very fast, small knockback but a long stun - it holds a thief in place for a friend to finish.
-- (Hit immunity after a stun stops it from stun-locking anybody.)
return {
	Id = "shock_baton",
	DisplayName = "Shock Baton",
	Description = "Short reach, rapid taps, long stun. Keeps a thief in place.",
	Category = "Weapon",
	Icon = "baton",
	Rarity = "Epic",
	Currency = "Coins",
	Price = 160000,
	MinRebirth = 2,
	Equip = {
		Kind = "Tool",
		Weapon = {
			Type = "Melee", Range = 7, Arc = 0.25, Cooldown = 0.55, WindUp = 0.08, Active = 0.14,
			Knockback = 16, Lift = 6, Stun = 1.3, DropChance = 0.8,
			Animation = "Weapon_ShockBaton",
			Look = { Style = "baton", Color = "46DCFF", Accent = "AAB2C4", Swing = "Thrust" },
		},
	},
}
