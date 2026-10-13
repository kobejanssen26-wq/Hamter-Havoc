-- TRAP. A puddle of goo: whoever steps in it walks at about a third of their speed for a few seconds (no stun).
return {
	Id = "glue_trap",
	DisplayName = "Glue Puddle",
	Description = "A sticky puddle. Anyone who steps in it walks at a crawl for 4 seconds.",
	Category = "Weapon",
	Icon = "glue",
	Rarity = "Rare",
	Currency = "Coins",
	Price = 30000,
	MinRebirth = 1,
	Equip = {
		Kind = "Tool",
		Weapon = {
			Type = "Trap", TrapKind = "Glue", Cooldown = 7, Duration = 45, MaxActive = 3, ArmSeconds = 1.0,
			Slow = 0.35, SlowSeconds = 4.5,
			Look = { Style = "gluetrap", Color = "78FF5A", Accent = "FF54AA" },
		},
	},
}
