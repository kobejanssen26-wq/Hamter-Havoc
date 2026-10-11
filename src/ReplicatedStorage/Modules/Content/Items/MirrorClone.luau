-- Ability tool: DECOY. Sends a see-through cyan look-alike running ahead of you for Duration seconds. It is only a model:
-- it copies no data, items or currency, can't steal or be stolen from, and any hit pops it. One decoy per player.
return {
	Id = "mirror_clone",
	DisplayName = "Mirror Clone",
	Description = "Send a see-through copy of yourself running off for 8 seconds to throw thieves off. Any hit pops it.",
	Category = "Weapon",
	Icon = "mirror",
	Rarity = "Mythic",
	Currency = "Gems",
	Price = 900,
	MinRebirth = 5,
	Equip = {
		Kind = "Tool",
		Weapon = { Type = "Decoy", Cooldown = 50, Duration = 8, Look = { Style = "mirror", Color = "CDEFFF", Accent = "FFD35A" } },
	},
}
