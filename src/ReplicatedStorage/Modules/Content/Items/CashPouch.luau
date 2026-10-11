-- Consumable: bought in the Shop (Boosts), kept in your backpack, used from the hotbar. Effects are applied by ItemSystem on the server.
return {
	Id = "item_pouch",
	DisplayName = "Cash Pouch",
	Description = "10 minutes of your current income, instantly.",
	Category = "Consumable",
	Icon = "pouch",
	Equip = { Kind = "Consume", Effect = "Pouch", Minutes = 10 },
}
