-- FIRST WEAPON (no rebirth needed). A huge cartoon glove: fast and light. Role: chase thieves and keep hitting - low
-- knockback, short stun, quick recovery. Clearly better than bare paws (reach, speed, drop chance) for a fair price.
return {
	Id = "slap_glove",
	DisplayName = "Mega Slap Glove",
	Description = "Your first weapon. Fast, wide slaps - hits twice as often as bare paws.",
	Category = "Weapon",
	Icon = "glove",
	Rarity = "Basic",
	Currency = "Coins",
	Price = 1500,
	MinRebirth = 0,
	Equip = {
		Kind = "Tool",
		Weapon = {
			Type = "Melee", Range = 9, Arc = 0.05, Cooldown = 0.7, WindUp = 0.1, Active = 0.18,
			Knockback = 34, Lift = 12, Stun = 0.7, DropChance = 0.75,
			Animation = "Weapon_SlapGlove", -- optional published animation (Content/Animations); built-in swing is used until it has an AssetId
			Look = { Style = "glove", Color = "FFD65C", Accent = "FF4A78", Swing = "Side" },
		},
	},
}
