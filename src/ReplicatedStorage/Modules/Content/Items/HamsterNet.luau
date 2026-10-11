-- Equipment: a passive item. While you own it, its Stats apply (server and client use the same EconomyMath).
-- Supported stats: CollectRange, WalkSpeed (see EconomyMath.gearBonus).
return {
	Id = "hamster_net",
	DisplayName = "Hamster Net",
	Description = "+4 studs of collection range for claiming hamsters.",
	Category = "Equipment",
	Icon = "net",
	Rarity = "Cute",
	Currency = "Coins",
	Price = 15000,
	Equip = { Kind = "Passive", Stats = { CollectRange = 4 } },
}
