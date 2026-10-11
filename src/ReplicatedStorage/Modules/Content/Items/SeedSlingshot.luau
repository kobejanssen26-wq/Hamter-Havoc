-- Ranged weapon: the server fires a ray from the player along the aim direction (the client only sends the direction).
return {
	Id = "seed_slingshot",
	DisplayName = "Seed Slingshot",
	Description = "Hit thieves from across the street. Needs a clear line of sight and reloads slowly.",
	Category = "Weapon",
	Icon = "slingshot",
	Rarity = "Epic",
	Currency = "Coins",
	Price = 150000,
	MinRebirth = 2,
	Equip = {
		Kind = "Tool",
		Weapon = { Type = "Ranged", Range = 55, Arc = 0.9, Cooldown = 1.8, Knockback = 30, Stun = 0.8, DropChance = 0.7, Look = { Style = "slingshot", Color = "8A5A3A", Accent = "F2C14E" } },
	},
}
