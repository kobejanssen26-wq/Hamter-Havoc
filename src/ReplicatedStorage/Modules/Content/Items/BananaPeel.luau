-- TRAP. Set it on the ground; whoever steps on it slips and is flung forward. Cheap, early, funny. Not while carrying a hamster.
return {
	Id = "banana_peel",
	DisplayName = "Banana Peel",
	Description = "Set it on the ground. The next player to step on it slips and slides away.",
	Category = "Weapon",
	Icon = "banana",
	Rarity = "Basic",
	Currency = "Coins",
	Price = 3500,
	MinRebirth = 0,
	Equip = {
		Kind = "Tool",
		Weapon = {
			Type = "Trap", TrapKind = "Banana", Cooldown = 5, Duration = 40, MaxActive = 3, ArmSeconds = 0.8,
			Stun = 0.9, Knockback = 40, Lift = 12, DropChance = 0.5,
			Look = { Style = "banana", Color = "FFE23C", Accent = "966228" },
		},
	},
}
