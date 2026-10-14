-- PREMIUM GADGET (Game Pass "Sky Glider", see GamepassConfig): a hang glider. Jump, then click: your wing opens and you glide for a few
-- seconds, falling slowly and flying forward; click again to fold it and land. It recharges after the glide.
-- Only the server decides if a glide may start (MobilitySystem): you must own it, be in the air, not stunned, and not recharging.
return {
	Id = "sky_glider",
	DisplayName = "Sky Glider",
	Description = "Jump, click, and soar. A bright hang glider that carries you across the plaza.",
	Category = "Gadget",
	Icon = "glider",
	Rarity = "Epic",
	-- no Price / Currency: it is not sold for cash, it comes with the Game Pass
	Equip = {
		Kind = "Tool",
		Weapon = {
			Type = "Glider", Cooldown = 5, Duration = 6, Speed = 30, FallSpeed = 9,
			Look = { Style = "glider", Color = "FF5CA8", Accent = "FFD65C", Swing = "Raise" },
		},
	},
}
