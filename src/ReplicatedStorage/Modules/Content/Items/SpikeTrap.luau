-- TRAP. The classic: a plate of spikes. Whoever steps on it is stunned and drops a carried hamster. If it catches the
-- thief of YOUR hamster, the theft fails. Three at a time, they disappear after 60 s. Not while carrying a hamster.
return {
	Id = "spike_trap",
	DisplayName = "Spike Trap",
	Description = "Set a plate of spikes. The next thief to step on it is stunned and drops the hamster.",
	Category = "Weapon",
	Icon = "spike",
	Rarity = "Epic",
	Currency = "Coins",
	Price = 75000,
	MinRebirth = 2,
	Equip = {
		Kind = "Tool",
		Weapon = {
			Type = "Trap", TrapKind = "Spike", Cooldown = 9, Duration = 60, MaxActive = 3, ArmSeconds = 1.2,
			Stun = 1.5, Lift = 16, DropChance = 1,
			Look = { Style = "spiketrap", Color = "969EB0", Accent = "FF4858" },
		},
	},
}
