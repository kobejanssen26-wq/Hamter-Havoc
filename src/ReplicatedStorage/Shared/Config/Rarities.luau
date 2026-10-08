--[[
	Rarity configuration. Nothing else in the project hard-codes rarity names or values.

	Per rarity:
	  Name, DisplayColor, SpawnWeight, PriceMultiplier, IncomeMultiplier,
	  VisualEffect, IsLimited, MaximumSupply
	  SpawnsNaturally = false -> never rolled by the route spawner (Divine / Admin for now).

	VisualEffect:
	  BallTransparency, FurColor, AccentColor (defaults to DisplayColor),
	  LightBrightness / LightRange, Particles, BeaconHeight, Crown
]]

local Rarities = {}

Rarities.Order = {
	"Common",
	"Uncommon",
	"Rare",
	"Epic",
	"Legendary",
	"Mythic",
	"Divine",
	"Secret",
	"Admin",
}

Rarities.Definitions = {
	Common = {
		Name = "Common",
		DisplayColor = Color3.fromRGB(215, 215, 220),
		SpawnWeight = 600,
		PriceMultiplier = 1,
		IncomeMultiplier = 1,
		VisualEffect = {
			BallTransparency = 0.6,
			FurColor = Color3.fromRGB(214, 178, 130),
			LightBrightness = 0,
			Particles = false,
			BeaconHeight = 0,
			Crown = false,
		},
		IsLimited = false,
		SpawnsNaturally = true,
	},
	Uncommon = {
		Name = "Uncommon",
		DisplayColor = Color3.fromRGB(70, 210, 90),
		SpawnWeight = 250,
		PriceMultiplier = 8,
		IncomeMultiplier = 5,
		VisualEffect = {
			BallTransparency = 0.55,
			FurColor = Color3.fromRGB(235, 215, 170),
			LightBrightness = 0.8,
			Particles = false,
			BeaconHeight = 0,
			Crown = false,
		},
		IsLimited = false,
		SpawnsNaturally = true,
	},
	Rare = {
		Name = "Rare",
		DisplayColor = Color3.fromRGB(55, 130, 255),
		SpawnWeight = 100,
		PriceMultiplier = 40,
		IncomeMultiplier = 20,
		VisualEffect = {
			BallTransparency = 0.5,
			FurColor = Color3.fromRGB(200, 215, 240),
			LightBrightness = 1.2,
			Particles = false,
			BeaconHeight = 12,
			Crown = false,
		},
		IsLimited = false,
		SpawnsNaturally = true,
	},
	Epic = {
		Name = "Epic",
		DisplayColor = Color3.fromRGB(170, 70, 255),
		SpawnWeight = 40,
		PriceMultiplier = 200,
		IncomeMultiplier = 100,
		VisualEffect = {
			BallTransparency = 0.45,
			FurColor = Color3.fromRGB(225, 200, 245),
			LightBrightness = 1.6,
			Particles = true,
			BeaconHeight = 20,
			Crown = false,
		},
		IsLimited = false,
		SpawnsNaturally = true,
	},
	Legendary = {
		Name = "Legendary",
		DisplayColor = Color3.fromRGB(255, 200, 40),
		SpawnWeight = 8,
		PriceMultiplier = 1000,
		IncomeMultiplier = 500,
		VisualEffect = {
			BallTransparency = 0.4,
			FurColor = Color3.fromRGB(255, 225, 130),
			LightBrightness = 2.2,
			Particles = true,
			BeaconHeight = 30,
			Crown = false,
		},
		IsLimited = false,
		SpawnsNaturally = true,
	},
	Mythic = {
		Name = "Mythic",
		DisplayColor = Color3.fromRGB(255, 50, 50),
		SpawnWeight = 1.5,
		PriceMultiplier = 6000,
		IncomeMultiplier = 3000,
		VisualEffect = {
			BallTransparency = 0.35,
			FurColor = Color3.fromRGB(255, 160, 150),
			LightBrightness = 2.8,
			Particles = true,
			BeaconHeight = 42,
			Crown = false,
		},
		IsLimited = false,
		SpawnsNaturally = true,
	},
	Divine = {
		Name = "Divine",
		DisplayColor = Color3.fromRGB(60, 230, 255),
		SpawnWeight = 0.3, -- reserved for later; not spawned in the prototype
		PriceMultiplier = 40000,
		IncomeMultiplier = 20000,
		VisualEffect = {
			BallTransparency = 0.3,
			FurColor = Color3.fromRGB(210, 250, 255),
			LightBrightness = 3.2,
			Particles = true,
			BeaconHeight = 55,
			Crown = false,
		},
		IsLimited = false,
		SpawnsNaturally = false,
	},
	Secret = {
		Name = "Secret",
		DisplayColor = Color3.fromRGB(18, 0, 30),
		SpawnWeight = 0.2,
		PriceMultiplier = 400000,
		IncomeMultiplier = 200000,
		VisualEffect = {
			BallTransparency = 0.3,
			FurColor = Color3.fromRGB(40, 20, 60),
			AccentColor = Color3.fromRGB(180, 40, 255),
			LightBrightness = 4,
			LightRange = 22,
			Particles = true,
			BeaconHeight = 70,
			Crown = false,
		},
		IsLimited = false,
		SpawnsNaturally = true,
	},
	Admin = {
		Name = "Admin",
		DisplayColor = Color3.fromRGB(12, 12, 12),
		SpawnWeight = 0,
		PriceMultiplier = 4000000,
		IncomeMultiplier = 2000000,
		VisualEffect = {
			BallTransparency = 0.25,
			FurColor = Color3.fromRGB(20, 20, 20),
			AccentColor = Color3.fromRGB(255, 205, 60),
			LightBrightness = 5,
			LightRange = 26,
			Particles = true,
			BeaconHeight = 90,
			Crown = true,
		},
		IsLimited = true,
		MaximumSupply = 3,
		SpawnsNaturally = false,
	},
}

function Rarities.getAccentColor(rarityName: string): Color3
	local definition = Rarities.Definitions[rarityName]
	return definition.VisualEffect.AccentColor or definition.DisplayColor
end

return Rarities
