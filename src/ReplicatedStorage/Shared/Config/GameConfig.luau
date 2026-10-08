--[[
	Central balancing / layout configuration.
	Everything tweakable for the prototype lives here (or in Rarities / Rebirth / Mutations).
]]

local GameConfig = {}

GameConfig.Economy = {
	StartingCash = 1000,
	BaseIncomePerSecond = 5, -- Common hamster income; rarity IncomeMultiplier scales it.
	BasePrice = 250, -- Common hamster price; rarity PriceMultiplier scales it.
	IncomeTickSeconds = 1,
}

GameConfig.Map = {
	GroundSize = 900,
	GroundY = 0.2, -- Y of the top of the ground.
	RouteThickness = 0.6,
	PlazaRadius = 55,
}

-- The route is an arc around the map centre. Hamster balls roll from the start
-- (distance 0) to the end (distance = Radius * sweep) and then disappear.
GameConfig.Route = {
	Center = Vector3.new(0, 0, 0),
	Radius = 250,
	StartAngleDegrees = -90,
	SweepDegrees = 330,
	Width = 22,
	PlateSegments = 96,
	BallSpeed = 22, -- studs / second
	BallDiameter = 7,
	SpawnIntervalSeconds = 5,
	MaxBalls = 40,
}

GameConfig.Bases = {
	Count = 8,
	RingRadius = 140,
	Size = Vector3.new(70, 1, 70),
	SlotSpacing = 16,
	SlotZ = 17, -- local Z of the wheel row (back of the base)
	SpawnZ = -12, -- local Z of the spawn pad
	CollectorX = 25,
}

GameConfig.Wheel = {
	Radius = 5,
	Thickness = 3,
	SpinSpeed = 2.5, -- radians / second (visual only, animated on the client)
	PlatformSize = 13,
}

GameConfig.Purchase = {
	MaxDistance = 35, -- server-side distance check between buyer and ball
}

-- Security is level based so upgrades can be added later (more lasers, more damage, ...).
GameConfig.Security = {
	DefaultLevel = 1,
	Levels = {
		[1] = {
			Name = "Basic Lasers",
			LaserDamage = 15,
			DamageCooldownSeconds = 1.5,
			LaserHeights = { 1.5, 3.5 },
			Color = Color3.fromRGB(255, 40, 40),
		},
	},
}

GameConfig.Stealing = {
	MaxDistance = 20, -- thief <-> hamster
	CarryTimeoutSeconds = 60, -- hamster returns to the owner after this
	HitMaxDistance = 25,
	OnlyOwnerCanHit = false, -- prototype: anyone can test-hit a thief
	CarryOffset = Vector3.new(0, 4.5, 0),
	CheckIntervalSeconds = 0.2,
}

-- Prototype testing helpers. Leave nil for normal play.
GameConfig.Debug = {
	ForceRarity = nil, -- e.g. "Legendary" makes every ball that rarity
	SpawnIntervalOverride = nil, -- e.g. 2
}

return GameConfig
