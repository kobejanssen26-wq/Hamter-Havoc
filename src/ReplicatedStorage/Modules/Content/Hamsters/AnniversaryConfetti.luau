return {
	Id = "anniversary_confetti",
	DisplayName = "Anniversary Confetti",
	Rarity = "Rare",
	Description = "LIMITED EDITION - a party hamster that only rolls by during the anniversary event.",
	SpawnWeight = 0.6, -- rarer than its neighbours of the same rarity
	Look = { Fur = "FFD1E8", Belly = "FFFFFF", Ears = "fluffy", Eyes = "sparkle", Mouth = "open", Acc = { "tiara", "held_balloon", "ground_glow" }, Accent = "FF6FD8" },
	Effects = { { "sparkle", "FFD0F8" }, { "stars", "FFE066" } },
	Limited = { EndsAt = 1798761600 }, -- 1 Jan 2027 00:00 UTC; after that it stops rolling (owners keep it)
}
