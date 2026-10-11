-- Consumable: bought in the Shop (Boosts), kept in your backpack, used from the hotbar. Effects are applied by ItemSystem on the server.
return {
	Id = "item_coins",
	DisplayName = "2x Cash",
	Description = "Doubles all cash you earn for 15 minutes.",
	Category = "Consumable",
	Icon = "coin",
	Equip = { Kind = "Consume", Effect = "Boost", BoostId = "Coins2x", Seconds = 900 },
}
