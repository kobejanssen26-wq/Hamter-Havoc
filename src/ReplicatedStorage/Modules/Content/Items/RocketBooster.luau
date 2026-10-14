-- PREMIUM GADGET (Game Pass "Rocket Booster", see GamepassConfig): a hand-held rocket. Click and it throws you up and forward.
-- A short, strong boost (not flight). Cooldown, stun and death are handled by the server (MobilitySystem).
return {
	Id = "rocket_booster",
	DisplayName = "Rocket Booster",
	Description = "Light the fuse and launch yourself over fences and rivals. Recharges in a few seconds.",
	Category = "Gadget",
	Icon = "rocket",
	Rarity = "Legendary",
	Equip = {
		Kind = "Tool",
		Weapon = {
			Type = "Rocket", Cooldown = 9, Boost = 72, Forward = 46,
			Look = { Style = "rocket", Color = "FF4A58", Accent = "FFE066", Swing = "Raise" },
		},
	},
}
