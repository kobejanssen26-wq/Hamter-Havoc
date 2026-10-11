-- Consumable: bought in the Shop (Boosts), kept in your backpack, used from the hotbar. Effects are applied by ItemSystem on the server.
return {
	Id = "item_speed",
	DisplayName = "Speed Tonic",
	Description = "+6 walk speed for 10 minutes.",
	Category = "Consumable",
	Icon = "bolt",
	Equip = { Kind = "Consume", Effect = "Boost", BoostId = "Speed2x", Seconds = 600 },
}
