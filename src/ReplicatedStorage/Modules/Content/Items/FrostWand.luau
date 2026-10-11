-- Ability tool: FREEZE. The server fires a ray along your aim; the first player it hits is frozen solid (cannot move, jump,
-- attack, steal or emote) for Duration seconds (hard cap 3 s). A frozen player is immune to freezing for 6 s afterwards.
-- It only works near a hamster that is being claimed, carried or stolen, like every other weapon.
return {
	Id = "frost_wand",
	DisplayName = "Frost Wand",
	Description = "Freeze a thief in place for 2 seconds. Long cooldown, and they can't be frozen again right away.",
	Category = "Weapon",
	Icon = "wand",
	Rarity = "Rare",
	Currency = "Coins",
	Price = 90000,
	MinRebirth = 1,
	Equip = {
		Kind = "Tool",
		Weapon = { Type = "Freeze", Range = 45, Cooldown = 20, Duration = 2, Look = { Style = "wand", Color = "9AD8FF", Accent = "E8F7FF" } },
	},
}
