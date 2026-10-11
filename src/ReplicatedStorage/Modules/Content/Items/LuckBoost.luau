-- Consumable: bought in the Shop (Boosts), kept in your backpack, used from the hotbar. Effects are applied by ItemSystem on the server.
return {
	Id = "item_luck",
	DisplayName = "2x Luck",
	Description = "Rarer hamsters appear more often for 10 minutes.",
	Category = "Consumable",
	Icon = "clover",
	Equip = { Kind = "Consume", Effect = "Boost", BoostId = "Luck2x", Seconds = 600 },
}
