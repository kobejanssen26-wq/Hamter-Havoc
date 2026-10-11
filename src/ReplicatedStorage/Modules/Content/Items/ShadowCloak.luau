-- Ability tool: INVISIBILITY. Turns you almost invisible for Duration seconds. Counterplay: a faint sparkle trail stays visible,
-- and the cloak ends when you attack, get hit or frozen, pick up a hamster or die. Long cooldown.
return {
	Id = "shadow_cloak",
	DisplayName = "Shadow Cloak",
	Description = "Slip away unseen for 6 seconds. A faint sparkle trail gives you away, and any hit or grab ends it.",
	Category = "Weapon",
	Icon = "cloak",
	Rarity = "Legendary",
	Currency = "Gems",
	Price = 400,
	MinRebirth = 3,
	Equip = {
		Kind = "Tool",
		Weapon = { Type = "Cloak", Cooldown = 45, Duration = 6, Look = { Style = "cloak", Color = "3B2F66", Accent = "B070FF" } },
	},
}
