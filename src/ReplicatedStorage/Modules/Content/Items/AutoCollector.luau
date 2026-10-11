-- Consumable: bought in the Shop (Boosts), kept in your backpack, used from the hotbar. Effects are applied by ItemSystem on the server.
return {
	Id = "item_auto",
	DisplayName = "Auto Collector",
	Description = "Grabs affordable hamsters in range for 10 minutes.",
	Category = "Consumable",
	Icon = "bot",
	Equip = { Kind = "Consume", Effect = "Boost", BoostId = "AutoCollect", Seconds = 600 },
}
