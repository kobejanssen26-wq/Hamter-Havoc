-- Heavy rebirth weapon. Huge arc and reach, the strongest shove, but a very slow recovery: miss and you are open.
return {
	Id = "party_hammer",
	DisplayName = "Party Hammer",
	Description = "A wide, slow smash with the strongest knockback. Miss and you are wide open.",
	Category = "Weapon",
	Icon = "hammer",
	Rarity = "Legendary",
	Currency = "Coins",
	Price = 600000,
	MinRebirth = 4,
	Equip = {
		Kind = "Tool",
		Weapon = {
			Type = "Melee", Range = 12, Arc = -0.2, Cooldown = 2.2, WindUp = 0.3, Active = 0.28,
			Knockback = 60, Lift = 28, Stun = 1.4, DropChance = 1,
			Animation = "Weapon_PartyHammer",
			Look = { Style = "hammer", Color = "FF5AC8", Accent = "FFE250", Swing = "Overhead" },
		},
	},
}
