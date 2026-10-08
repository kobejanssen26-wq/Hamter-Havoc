--[[
	Glasses, neck/body gear (scarves, capes, armor), back gear and held items.
]]

local Toolkit = require(script.Parent.Toolkit)

local T = Toolkit
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local V3 = Vector3.new
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal

local Gear = {} :: { [string]: (Toolkit.Ctx, any) -> () }

local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 210, 80)
local BLACK = Color3.fromRGB(34, 30, 38)
local RED = Color3.fromRGB(230, 70, 70)
local STEEL = Color3.fromRGB(190, 196, 210)
local WOODC = Color3.fromRGB(150, 105, 65)

local function opt(attach: string, extra: { [string]: any }?): any
	local options: any = { Attach = attach }
	if extra then
		for key, value in extra do
			options[key] = value
		end
	end
	return options
end

---------------------------------------------------------------------------
-- glasses (Head)
---------------------------------------------------------------------------

local EYE_X, EYE_Y, GLASS_Z = 0.62, 2.5, -1.92

local function lenses(ctx: Toolkit.Ctx, diameter: number, lens: Color3, rim: Color3, transparency: number?, material: Enum.Material?)
	T.both(function(side)
		T.disc(ctx, "Rim", diameter + 0.2, 0.1, CF(side * EYE_X, EYE_Y, GLASS_Z + 0.04), rim, opt("Head", { Material = METAL }))
		T.disc(ctx, "Lens", diameter, 0.1, CF(side * EYE_X, EYE_Y, GLASS_Z - 0.02), lens, opt("Head", { Transparency = transparency, Material = material }))
	end)
	T.block(ctx, "Bridge", V3(0.35, 0.1, 0.1), CF(0, EYE_Y + 0.05, GLASS_Z), rim, opt("Head"))
	T.both(function(side)
		T.block(ctx, "Temple", V3(0.1, 0.1, 0.9), CF(side * 1.28, EYE_Y + 0.02, GLASS_Z + 0.4), rim, opt("Head", { Minor = true }))
	end)
end

Gear.glasses_round = function(ctx, spec)
	lenses(ctx, 0.82, Color3.fromRGB(200, 235, 255), Color3.fromRGB(70, 55, 45), 0.45, Enum.Material.Glass)
end
Gear.nerd_glasses = function(ctx, spec)
	lenses(ctx, 0.9, Color3.fromRGB(220, 240, 255), BLACK, 0.5, Enum.Material.Glass)
end
Gear.sunglasses = function(ctx, spec)
	lenses(ctx, 0.88, Color3.fromRGB(25, 25, 35), BLACK, 0.05, nil)
end
Gear.heart_glasses = function(ctx, spec)
	lenses(ctx, 0.82, Color3.fromRGB(255, 110, 160), Color3.fromRGB(255, 190, 215), 0.2, NEON)
end
Gear.star_glasses = function(ctx, spec)
	T.both(function(side)
		T.star(ctx, "StarLens", 1.1, CF(side * EYE_X, EYE_Y, GLASS_Z), Color3.fromRGB(255, 225, 90), opt("Head"))
	end)
	T.block(ctx, "Bridge", V3(0.3, 0.1, 0.1), CF(0, EYE_Y, GLASS_Z), GOLD, opt("Head"))
end
Gear.visor = function(ctx, spec)
	T.block(ctx, "Visor", V3(2.5, 0.65, 0.2), CF(0, EYE_Y, GLASS_Z), ctx.Accent, opt("Head", { Material = NEON, Transparency = 0.1 }))
	T.block(ctx, "VisorFrame", V3(2.65, 0.8, 0.12), CF(0, EYE_Y, GLASS_Z + 0.1), BLACK, opt("Head"))
end
Gear.goggles = function(ctx, spec)
	local band = spec.hatColor or Color3.fromRGB(120, 85, 50)
	T.rod(ctx, "Strap", 2.75, 0.4, CF(0, 3.05, -0.7), band, opt("Head"))
	T.both(function(side)
		T.disc(ctx, "GogRim", 0.95, 0.25, CF(side * 0.62, 3.1, -1.95), Color3.fromRGB(150, 150, 165), opt("Head", { Material = METAL }))
		T.disc(ctx, "GogLens", 0.72, 0.28, CF(side * 0.62, 3.1, -2.03), Color3.fromRGB(120, 230, 255), opt("Head", { Material = NEON, Transparency = 0.2 }))
	end)
end
Gear.glasses_3d = function(ctx, spec)
	T.both(function(side)
		T.block(ctx, "Lens3D", V3(0.85, 0.7, 0.1), CF(side * EYE_X, EYE_Y, GLASS_Z), if side < 0 then Color3.fromRGB(255, 70, 70) else Color3.fromRGB(70, 160, 255), opt("Head", { Transparency = 0.3 }))
	end)
	T.block(ctx, "Frame", V3(2.1, 0.12, 0.12), CF(0, EYE_Y + 0.3, GLASS_Z + 0.05), WHITE, opt("Head"))
end
Gear.monocle = function(ctx, spec)
	T.disc(ctx, "MonRim", 0.95, 0.1, CF(EYE_X, EYE_Y, GLASS_Z), GOLD, opt("Head", { Material = METAL }))
	T.disc(ctx, "MonLens", 0.78, 0.1, CF(EYE_X, EYE_Y, GLASS_Z - 0.03), Color3.fromRGB(215, 240, 255), opt("Head", { Material = Enum.Material.Glass, Transparency = 0.45 }))
	T.rod(ctx, "Chain", 0.06, 1.4, CF(EYE_X + 0.55, EYE_Y - 0.7, GLASS_Z + 0.1) * ANG(0, 0, rad(-20)), GOLD, opt("Head"))
end
Gear.eyepatch = function(ctx, spec)
	T.disc(ctx, "Patch", 0.95, 0.12, CF(-EYE_X, EYE_Y, GLASS_Z), BLACK, opt("Head"))
	T.block(ctx, "PatchStrap", V3(2.7, 0.1, 0.1), CF(0, EYE_Y + 0.35, -1.0) * ANG(0, 0, rad(12)), BLACK, opt("Head", { Minor = true }))
end

---------------------------------------------------------------------------
-- neck and body (Body unless stated)
---------------------------------------------------------------------------

Gear.scarf = function(ctx, spec)
	local color = spec.hatColor or RED
	T.blob(ctx, "Scarf", V3(2.8, 0.85, 2.6), CF(0, 1.7, -0.5), color, opt("Body"))
	T.block(ctx, "ScarfTail", V3(0.65, 1.5, 0.22), CF(0.85, 1.0, -1.45) * ANG(0, 0, rad(8)), color, opt("Body"))
	T.block(ctx, "ScarfStripe", V3(0.67, 0.18, 0.24), CF(0.85, 0.7, -1.46) * ANG(0, 0, rad(8)), WHITE, opt("Body", { Minor = true }))
	T.block(ctx, "ScarfStripe", V3(0.67, 0.18, 0.24), CF(0.82, 1.2, -1.46) * ANG(0, 0, rad(8)), WHITE, opt("Body", { Minor = true }))
end
Gear.bowtie = function(ctx, spec)
	local color = spec.hatColor or Color3.fromRGB(230, 70, 110)
	T.both(function(side)
		T.blob(ctx, "BowWing", V3(0.75, 0.6, 0.3), CF(side * 0.5, 1.45, -1.55) * ANG(0, 0, rad(side * 12)), color, opt("Body"))
	end)
	T.blob(ctx, "BowKnot", V3(0.32, 0.32, 0.32), CF(0, 1.45, -1.58), T.shade(color, 0.8), opt("Body"))
end
Gear.tie = function(ctx, spec)
	local color = spec.hatColor or Color3.fromRGB(60, 90, 200)
	T.blob(ctx, "Knot", V3(0.4, 0.35, 0.3), CF(0, 1.55, -1.6), color, opt("Body"))
	T.block(ctx, "Tie", V3(0.4, 1.1, 0.14), CF(0, 0.85, -1.68), color, opt("Body"))
end
Gear.bellcollar = function(ctx, spec)
	T.blob(ctx, "Collar", V3(2.5, 0.4, 2.3), CF(0, 1.65, -0.5), spec.hatColor or RED, opt("Body"))
	T.blob(ctx, "Bell", V3(0.55, 0.55, 0.55), CF(0, 1.35, -1.45), GOLD, opt("Body", { Material = METAL }))
end
Gear.medal = function(ctx, spec)
	T.block(ctx, "Ribbon", V3(0.45, 0.9, 0.1), CF(0, 1.55, -1.6), Color3.fromRGB(80, 130, 230), opt("Body"))
	T.disc(ctx, "Medal", 0.7, 0.12, CF(0, 0.95, -1.68), GOLD, opt("Body", { Material = METAL }))
	T.star(ctx, "MedalStar", 0.4, CF(0, 0.95, -1.76), WHITE, opt("Body", { Minor = true }))
end
Gear.pendant = function(ctx, spec)
	T.rod(ctx, "Chain", 0.08, 1.2, CF(0, 1.5, -1.45) * ANG(rad(-10), 0, 0), GOLD, opt("Body", { Material = METAL }))
	T.gem(ctx, "Gem", V3(0.45, 0.55, 0.3), CF(0, 0.95, -1.7), ctx.Accent, opt("Body"))
end
Gear.lei = function(ctx, spec)
	for index = 0, 8 do
		local angle = math.rad(-80 + index * 20)
		local color = ({ Color3.fromRGB(255, 120, 160), Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 255, 255) })[index % 3 + 1]
		T.blob(ctx, "LeiFlower", V3(0.55, 0.45, 0.45), CF(math.sin(angle) * 1.15, 1.6 - math.cos(angle) * 0.3, -1.1 - math.cos(angle) * 0.35), color, opt("Body"))
	end
end
Gear.ruff = function(ctx, spec)
	T.blob(ctx, "Ruff", V3(3.0, 0.9, 2.7), CF(0, 1.7, -0.5), WHITE, opt("Body"))
	for index = 0, 7 do
		local angle = (index / 8) * math.pi * 2
		T.blob(ctx, "RuffBall", V3(0.6, 0.6, 0.6), CF(math.cos(angle) * 1.3, 1.7, -0.5 + math.sin(angle) * 1.2), WHITE, opt("Body", { Minor = index % 2 == 1 }))
	end
end
Gear.apron = function(ctx, spec)
	T.block(ctx, "Apron", V3(1.7, 1.6, 0.14), CF(0, 1.0, -1.45), WHITE, opt("Body"))
	T.block(ctx, "ApronPocket", V3(0.9, 0.5, 0.1), CF(0, 0.75, -1.55), Color3.fromRGB(240, 235, 225), opt("Body"))
	T.block(ctx, "ApronStrap", V3(1.2, 0.12, 0.12), CF(0, 1.75, -1.1), WHITE, opt("Body", { Minor = true }))
end
Gear.cape = function(ctx, spec)
	local color = spec.hatColor or RED
	T.block(ctx, "Cape", V3(2.7, 2.7, 0.22), CF(0, 1.35, 1.8) * ANG(rad(-8), 0, 0), color, opt("Body"))
	T.blob(ctx, "CapeCollar", V3(2.8, 0.7, 2.4), CF(0, 1.75, -0.2), T.shade(color, 0.85), opt("Body"))
	T.blob(ctx, "Clasp", V3(0.35, 0.35, 0.35), CF(0, 1.55, -1.35), GOLD, opt("Body", { Material = METAL }))
end
Gear.cape_royal = function(ctx, spec)
	local color = spec.hatColor or Color3.fromRGB(140, 30, 70)
	T.block(ctx, "Cape", V3(2.9, 2.9, 0.24), CF(0, 1.3, 1.85) * ANG(rad(-8), 0, 0), color, opt("Body"))
	T.block(ctx, "Ermine", V3(3.1, 0.5, 0.28), CF(0, 2.7, 1.8) * ANG(rad(-8), 0, 0), WHITE, opt("Body"))
	for index = 0, 4 do
		T.blob(ctx, "ErmineDot", V3(0.16, 0.16, 0.1), CF(-1 + index * 0.5, 2.7 + (index % 2) * 0.05, 1.68), BLACK, opt("Body", { Minor = true }))
	end
	T.blob(ctx, "Clasp", V3(0.4, 0.4, 0.4), CF(0, 1.6, -1.3), GOLD, opt("Body", { Material = METAL }))
end
Gear.armor = function(ctx, spec)
	local metal = spec.hatColor or STEEL
	T.blob(ctx, "Chestplate", V3(2.6, 1.6, 1.4), CF(0, 1.3, -0.8), metal, opt("Body", { Material = METAL, Reflectance = 0.15 }))
	T.block(ctx, "Belt", V3(2.6, 0.3, 1.2), CF(0, 0.8, -0.8), Color3.fromRGB(110, 75, 45), opt("Body"))
	T.blob(ctx, "Emblem", V3(0.5, 0.5, 0.2), CF(0, 1.4, -1.5), GOLD, opt("Body", { Material = METAL }))
end
Gear.pauldrons = function(ctx, spec)
	T.both(function(side)
		T.blob(ctx, "Pauldron", V3(1.1, 0.9, 1.2), CF(side * 1.45, 2.1, -0.1), spec.hatColor or STEEL, opt("Body", { Material = METAL }))
		T.blob(ctx, "PauldronSpike", V3(0.3, 0.6, 0.3), CF(side * 1.6, 2.6, -0.1) * ANG(0, 0, rad(-side * 25)), GOLD, opt("Body", { Material = METAL, Minor = true }))
	end)
end
Gear.spiked_collar = function(ctx, spec)
	T.blob(ctx, "Collar", V3(2.5, 0.4, 2.3), CF(0, 1.65, -0.5), BLACK, opt("Body"))
	for index = 0, 6 do
		local angle = math.rad(-70 + index * 23)
		T.blob(ctx, "Spike", V3(0.2, 0.35, 0.2), CF(math.sin(angle) * 1.2, 1.7, -0.5 - math.cos(angle) * 1.1), STEEL, opt("Body", { Material = METAL }))
	end
end
Gear.tutu = function(ctx, spec)
	for index = 0, 9 do
		local angle = (index / 10) * math.pi * 2
		T.blob(ctx, "Tutu", V3(0.9, 0.2, 0.9), CF(math.cos(angle) * 1.2, 0.85, 0.2 + math.sin(angle) * 1.2), spec.hatColor or Color3.fromRGB(255, 170, 210), opt("Body"))
	end
end
Gear.fish_scales = function(ctx, spec)
	for row = 0, 2 do
		for col = -1, 1 do
			T.blob(ctx, "Scale", V3(0.8, 0.5, 0.2), CF(col * 0.8 + (row % 2) * 0.4, 0.75 + row * 0.45, -1.35), ctx.Accent, opt("Body", { Material = Enum.Material.Glass, Minor = row == 2 }))
		end
	end
end

---------------------------------------------------------------------------
-- back gear (Body)
---------------------------------------------------------------------------

Gear.backpack = function(ctx, spec)
	local color = spec.hatColor or ctx.Accent
	T.blob(ctx, "Pack", V3(1.9, 1.9, 0.9), CF(0, 1.8, 1.75), color, opt("Body"))
	T.blob(ctx, "PackFlap", V3(1.7, 0.8, 0.95), CF(0, 2.35, 1.8), T.shade(color, 0.8), opt("Body"))
	T.block(ctx, "PackBuckle", V3(0.3, 0.3, 0.1), CF(0, 2.0, 2.25), GOLD, opt("Body", { Material = METAL }))
	T.both(function(side)
		T.block(ctx, "Strap", V3(0.25, 1.4, 0.12), CF(side * 0.75, 1.7, 1.2) * ANG(rad(-12), 0, 0), T.shade(color, 0.7), opt("Body", { Minor = true }))
	end)
end
Gear.shell = function(ctx, spec)
	local green = spec.hatColor or Color3.fromRGB(95, 160, 90)
	T.blob(ctx, "Shell", V3(2.9, 1.9, 2.4), CF(0, 2.2, 0.9), green, opt("Body"))
	for index, offset in { V3(0, 3.0, 0.9), V3(-0.8, 2.7, 0.5), V3(0.8, 2.7, 0.5), V3(-0.7, 2.6, 1.4), V3(0.7, 2.6, 1.4) } do
		T.blob(ctx, "ShellPlate", V3(0.8, 0.25, 0.8), CF(offset), T.shade(green, 0.72), opt("Body", { Minor = index > 3 }))
	end
end
Gear.jetpack = function(ctx, spec)
	T.both(function(side)
		T.rod(ctx, "Tank", 0.9, 2, CF(side * 0.65, 1.9, 1.95), STEEL, opt("Body", { Material = METAL }))
		T.rod(ctx, "Nozzle", 0.6, 0.4, CF(side * 0.65, 0.8, 1.95), Color3.fromRGB(90, 90, 105), opt("Body", { Material = METAL }))
		T.blob(ctx, "Flame", V3(0.5, 1.1, 0.5), CF(side * 0.65, 0.2, 1.95), Color3.fromRGB(255, 160, 60), opt("Body", { Material = NEON }))
	end)
	T.block(ctx, "Strap", V3(1.5, 0.2, 0.15), CF(0, 2.4, 1.85), BLACK, opt("Body", { Minor = true }))
end
Gear.dino_spikes = function(ctx, spec)
	for index = 0, 4 do
		local z = -0.2 + index * 0.45
		T.blob(ctx, "Spike", V3(0.45, 0.9 - math.abs(index - 2) * 0.12, 0.45), CF(0, 2.5 - math.abs(index - 2) * 0.12, z + 0.2), spec.hatColor or Color3.fromRGB(240, 160, 70), opt("Body"))
	end
end
Gear.quiver = function(ctx, spec)
	T.rod(ctx, "Quiver", 0.7, 1.8, CF(0.6, 2.0, 1.9) * ANG(0, 0, rad(-18)), Color3.fromRGB(130, 90, 55), opt("Body"))
	for index = 0, 2 do
		T.rod(ctx, "Arrow", 0.08, 0.9, CF(0.4 + index * 0.18, 3.1, 1.9) * ANG(0, 0, rad(-18)), WOODC, opt("Body"))
		T.blob(ctx, "Fletch", V3(0.2, 0.3, 0.1), CF(0.35 + index * 0.18, 3.5, 1.9), RED, opt("Body", { Minor = true }))
	end
end
Gear.sack = function(ctx, spec)
	T.blob(ctx, "Sack", V3(2.0, 2.0, 1.7), CF(0, 1.9, 1.9), Color3.fromRGB(205, 175, 125), opt("Body"))
	T.blob(ctx, "SackKnot", V3(0.7, 0.6, 0.7), CF(0, 3.0, 1.9), Color3.fromRGB(180, 150, 100), opt("Body"))
	T.blob(ctx, "SeedSpill", V3(0.35, 0.25, 0.35), CF(0.4, 3.4, 1.9), Color3.fromRGB(255, 230, 130), opt("Body", { Minor = true }))
end
Gear.ghost_sheet = function(ctx, spec)
	T.blob(ctx, "Sheet", V3(3.4, 3.8, 3.2), CF(0, 2.3, 0.3), WHITE, opt("Body", { Transparency = 0.1 }))
	T.both(function(side)
		T.blob(ctx, "SheetEye", V3(0.45, 0.65, 0.2), CF(side * 0.6, 2.7, -1.2), BLACK, opt("Body"))
	end)
end

---------------------------------------------------------------------------
-- held items (front paws)
---------------------------------------------------------------------------

local function held(x: number, y: number, z: number): CFrame
	return CF(x, y, z)
end

Gear.held_cookie = function(ctx, spec)
	T.disc(ctx, "Cookie", 1.3, 0.28, held(0.45, 1.15, -1.55), Color3.fromRGB(215, 160, 95), opt("Body"))
	for _, offset in { V3(0.1, 0.25, 0), V3(-0.25, -0.15, 0), V3(0.3, -0.25, 0), V3(-0.1, 0.35, 0) } do
		T.blob(ctx, "Chip", V3(0.22, 0.22, 0.1), held(0.45 + offset.X, 1.15 + offset.Y, -1.74), Color3.fromRGB(80, 50, 35), opt("Body", { Minor = true }))
	end
end
Gear.held_cheese = function(ctx, spec)
	T.block(ctx, "Cheese", V3(1.3, 0.9, 1.0), held(0.5, 1.0, -1.6) * ANG(0, rad(-20), rad(8)), Color3.fromRGB(255, 205, 70), opt("Body"))
	T.blob(ctx, "Hole", V3(0.3, 0.3, 0.1), held(0.35, 1.05, -2.12), Color3.fromRGB(220, 160, 40), opt("Body", { Minor = true }))
end
Gear.held_bread = function(ctx, spec)
	T.blob(ctx, "Loaf", V3(1.5, 0.9, 1.0), held(0.5, 1.05, -1.6) * ANG(0, rad(-25), 0), Color3.fromRGB(215, 160, 95), opt("Body"))
	T.block(ctx, "Slash", V3(0.1, 0.06, 0.6), held(0.5, 1.5, -1.6) * ANG(0, rad(-25), 0), Color3.fromRGB(245, 215, 160), opt("Body", { Minor = true }))
end
Gear.held_donut = function(ctx, spec)
	T.disc(ctx, "Donut", 1.3, 0.45, held(0.45, 1.15, -1.55), Color3.fromRGB(225, 165, 100), opt("Body"))
	T.disc(ctx, "Icing", 1.2, 0.2, held(0.45, 1.15, -1.7), Color3.fromRGB(255, 140, 190), opt("Body"))
	T.disc(ctx, "Hole", 0.35, 0.5, held(0.45, 1.15, -1.72), Color3.fromRGB(60, 40, 40), opt("Body", { Minor = true }))
	for index = 0, 4 do
		local angle = index * 1.3
		T.block(ctx, "Sprinkle", V3(0.2, 0.06, 0.06), held(0.45 + math.cos(angle) * 0.38, 1.15 + math.sin(angle) * 0.38, -1.82) * ANG(0, 0, angle), WHITE, opt("Body", { Minor = true }))
	end
end
Gear.held_strawberry = function(ctx, spec)
	T.blob(ctx, "Berry", V3(0.95, 1.1, 0.95), held(0.5, 1.05, -1.55), Color3.fromRGB(235, 55, 75), opt("Body"))
	T.blob(ctx, "Leaf", V3(0.7, 0.14, 0.7), held(0.5, 1.65, -1.55), Color3.fromRGB(90, 190, 90), opt("Body"))
end
Gear.held_seed = function(ctx, spec)
	T.blob(ctx, "Seed", V3(0.5, 1.1, 0.35), held(0.5, 1.05, -1.6) * ANG(0, 0, rad(-25)), Color3.fromRGB(70, 70, 80), opt("Body"))
	T.blob(ctx, "SeedStripe", V3(0.14, 1.0, 0.3), held(0.5, 1.05, -1.62) * ANG(0, 0, rad(-25)), WHITE, opt("Body", { Minor = true }))
end
Gear.held_carrot = function(ctx, spec)
	T.rod(ctx, "Carrot", 0.5, 1.5, held(0.55, 1.2, -1.55) * ANG(rad(-20), 0, rad(-18)), Color3.fromRGB(255, 150, 50), opt("Body"))
	T.blob(ctx, "Greens", V3(0.5, 0.6, 0.5), held(0.8, 2.0, -1.65), Color3.fromRGB(100, 190, 90), opt("Body"))
end
Gear.held_icecream = function(ctx, spec)
	T.rod(ctx, "Cone", 0.7, 1.2, held(0.5, 0.8, -1.55) * ANG(0, 0, rad(180)), Color3.fromRGB(225, 180, 110), opt("Body"))
	T.blob(ctx, "Scoop", V3(1.0, 0.95, 1.0), held(0.5, 1.6, -1.55), spec.hatColor or Color3.fromRGB(255, 170, 200), opt("Body"))
	T.blob(ctx, "Cherry", V3(0.3, 0.3, 0.3), held(0.5, 2.15, -1.55), RED, opt("Body"))
end
Gear.held_sword = function(ctx, spec)
	T.block(ctx, "Blade", V3(0.22, 2.6, 0.1), held(0.95, 2.3, -1.6) * ANG(0, 0, rad(-12)), Color3.fromRGB(215, 225, 240), opt("Body", { Material = METAL, Reflectance = 0.25 }))
	T.block(ctx, "Guard", V3(0.9, 0.18, 0.2), held(0.88, 1.0, -1.6) * ANG(0, 0, rad(-12)), GOLD, opt("Body", { Material = METAL }))
	T.rod(ctx, "Hilt", 0.2, 0.55, held(0.84, 0.78, -1.6) * ANG(0, 0, rad(-12)), Color3.fromRGB(110, 70, 45), opt("Body"))
end
Gear.held_staff = function(ctx, spec)
	T.rod(ctx, "Staff", 0.25, 4.0, held(1.0, 2.0, -1.5), Color3.fromRGB(125, 85, 55), opt("Body"))
	T.blob(ctx, "Orb", V3(0.8, 0.8, 0.8), held(1.0, 4.2, -1.5), ctx.Accent, opt("Body", { Material = NEON }))
	T.rod(ctx, "Claw", 0.9, 0.12, held(1.0, 3.8, -1.5), GOLD, opt("Body", { Material = METAL }))
end
Gear.held_wand = function(ctx, spec)
	T.rod(ctx, "Wand", 0.14, 1.9, held(0.95, 1.7, -1.65) * ANG(0, 0, rad(-25)), Color3.fromRGB(240, 235, 245), opt("Body"))
	T.star(ctx, "WandStar", 0.9, held(1.45, 2.7, -1.65), Color3.fromRGB(255, 230, 110), opt("Body"))
end
Gear.held_shield = function(ctx, spec)
	T.disc(ctx, "Shield", 1.9, 0.22, held(-0.95, 1.3, -1.6), spec.hatColor or Color3.fromRGB(70, 110, 200), opt("Body", { Material = METAL }))
	T.disc(ctx, "ShieldRim", 2.05, 0.18, held(-0.95, 1.3, -1.55), GOLD, opt("Body", { Material = METAL }))
	T.star(ctx, "ShieldStar", 0.9, held(-0.95, 1.3, -1.75), WHITE, opt("Body"))
end
Gear.held_lollipop = function(ctx, spec)
	T.rod(ctx, "Stick", 0.12, 1.6, held(0.55, 1.2, -1.55), WHITE, opt("Body"))
	T.disc(ctx, "Candy", 1.1, 0.25, held(0.55, 2.1, -1.55), Color3.fromRGB(255, 120, 170), opt("Body"))
	T.disc(ctx, "CandySwirl", 0.6, 0.28, held(0.55, 2.1, -1.57), WHITE, opt("Body", { Minor = true }))
end
Gear.held_bamboo = function(ctx, spec)
	for index = 0, 2 do
		T.rod(ctx, "Bamboo", 0.35, 1.2, held(0.8 + index * 0.1, 1.0 + index * 1.05, -1.5), Color3.fromRGB(120, 190, 100), opt("Body"))
		T.rod(ctx, "Node", 0.42, 0.1, held(0.8 + index * 0.1, 1.55 + index * 1.05, -1.5), Color3.fromRGB(90, 150, 80), opt("Body", { Minor = true }))
	end
end
Gear.held_flower = function(ctx, spec)
	T.rod(ctx, "Stem", 0.1, 1.8, held(0.55, 1.5, -1.55), Color3.fromRGB(90, 170, 90), opt("Body"))
	for index = 0, 4 do
		local angle = (index / 5) * math.pi * 2
		T.blob(ctx, "Petal", V3(0.45, 0.45, 0.2), held(0.55 + math.cos(angle) * 0.38, 2.5 + math.sin(angle) * 0.38, -1.55), spec.hatColor or Color3.fromRGB(255, 140, 190), opt("Body"))
	end
	T.blob(ctx, "Center", V3(0.38, 0.38, 0.25), held(0.55, 2.5, -1.58), Color3.fromRGB(255, 215, 70), opt("Body"))
end
Gear.held_bottle = function(ctx, spec)
	T.rod(ctx, "Bottle", 0.8, 1.3, held(0.5, 1.1, -1.55), Color3.fromRGB(245, 250, 255), opt("Body", { Transparency = 0.15 }))
	T.rod(ctx, "Neck", 0.4, 0.45, held(0.5, 1.95, -1.55), Color3.fromRGB(245, 250, 255), opt("Body"))
	T.rod(ctx, "Cap", 0.5, 0.18, held(0.5, 2.25, -1.55), spec.hatColor or Color3.fromRGB(255, 130, 170), opt("Body"))
end
Gear.held_gem = function(ctx, spec)
	T.gem(ctx, "HeldGem", V3(0.8, 1, 0.8), held(0.5, 1.5, -1.65), ctx.Accent, opt("Body"))
	T.blob(ctx, "Glow", V3(1.1, 1.1, 1.1), held(0.5, 1.5, -1.65), ctx.Accent, opt("Body", { Material = NEON, Transparency = 0.7 }))
end
Gear.held_scythe = function(ctx, spec)
	T.rod(ctx, "Pole", 0.22, 5, held(1.1, 2.3, -1.5), Color3.fromRGB(70, 55, 70), opt("Body"))
	T.blob(ctx, "Blade", V3(2.0, 0.28, 0.14), held(0.2, 4.9, -1.5) * ANG(0, 0, rad(18)), Color3.fromRGB(210, 220, 235), opt("Body", { Material = METAL }))
end
Gear.held_trident = function(ctx, spec)
	T.rod(ctx, "Shaft", 0.2, 4.2, held(1.0, 2.1, -1.5), GOLD, opt("Body", { Material = METAL }))
	for index = -1, 1 do
		T.rod(ctx, "Prong", 0.14, 1.0, held(1.0 + index * 0.4, 4.7, -1.5), GOLD, opt("Body", { Material = METAL }))
	end
	T.block(ctx, "Cross", V3(1.0, 0.14, 0.14), held(1.0, 4.2, -1.5), GOLD, opt("Body", { Material = METAL }))
end
Gear.held_hammer = function(ctx, spec)
	T.rod(ctx, "Handle", 0.25, 2.4, held(0.9, 1.6, -1.5), Color3.fromRGB(125, 85, 55), opt("Body"))
	T.block(ctx, "Head", V3(1.5, 0.9, 0.9), held(0.9, 3.1, -1.5), STEEL, opt("Body", { Material = METAL }))
end
Gear.held_book = function(ctx, spec)
	T.block(ctx, "Book", V3(1.3, 1.6, 0.35), held(0.4, 1.2, -1.6) * ANG(rad(-12), rad(-10), 0), spec.hatColor or Color3.fromRGB(110, 60, 160), opt("Body"))
	T.block(ctx, "Pages", V3(1.2, 1.5, 0.3), held(0.42, 1.2, -1.55) * ANG(rad(-12), rad(-10), 0), Color3.fromRGB(250, 245, 230), opt("Body"))
end
Gear.held_lantern = function(ctx, spec)
	T.block(ctx, "LanternBody", V3(0.8, 1.1, 0.8), held(0.5, 1.0, -1.55), Color3.fromRGB(70, 60, 70), opt("Body", { Material = METAL }))
	T.blob(ctx, "LanternFlame", V3(0.5, 0.7, 0.5), held(0.5, 1.0, -1.55), Color3.fromRGB(255, 210, 110), opt("Body", { Material = NEON }))
	T.rod(ctx, "Handle", 0.08, 0.6, held(0.5, 1.8, -1.55), Color3.fromRGB(70, 60, 70), opt("Body"))
end
Gear.held_torch = function(ctx, spec)
	T.rod(ctx, "Torch", 0.28, 1.8, held(0.55, 1.3, -1.55), Color3.fromRGB(125, 85, 55), opt("Body"))
	T.blob(ctx, "Fire", V3(0.7, 1.0, 0.7), held(0.55, 2.4, -1.55), Color3.fromRGB(255, 140, 50), opt("Body", { Material = NEON }))
	T.emitter(ctx, "flame", Color3.fromRGB(255, 170, 70), "Body")
end
Gear.held_brush = function(ctx, spec)
	T.rod(ctx, "Brush", 0.14, 1.8, held(0.65, 1.6, -1.55) * ANG(0, 0, rad(-20)), Color3.fromRGB(130, 90, 60), opt("Body"))
	T.blob(ctx, "Bristles", V3(0.35, 0.6, 0.35), held(1.0, 2.6, -1.55) * ANG(0, 0, rad(-20)), spec.hatColor or Color3.fromRGB(255, 90, 120), opt("Body"))
end
Gear.held_pizza = function(ctx, spec)
	T.block(ctx, "Slice", V3(1.3, 0.2, 1.3), held(0.5, 1.2, -1.6) * ANG(rad(-35), rad(20), 0), Color3.fromRGB(250, 200, 90), opt("Body"))
	T.blob(ctx, "Pepperoni", V3(0.35, 0.1, 0.35), held(0.5, 1.4, -1.8), Color3.fromRGB(200, 60, 60), opt("Body", { Minor = true }))
end
Gear.held_cupcake = function(ctx, spec)
	T.rod(ctx, "Cup", 0.9, 0.7, held(0.5, 0.95, -1.55), Color3.fromRGB(255, 170, 120), opt("Body"))
	T.blob(ctx, "Frosting", V3(1.0, 0.8, 1.0), held(0.5, 1.5, -1.55), Color3.fromRGB(255, 190, 220), opt("Body"))
	T.blob(ctx, "Cherry", V3(0.3, 0.3, 0.3), held(0.5, 2.0, -1.55), RED, opt("Body"))
end
Gear.held_balloon = function(ctx, spec)
	T.rod(ctx, "String", 0.04, 3, held(0.6, 2.4, -1.5), Color3.fromRGB(80, 80, 90), opt("Body"))
	T.blob(ctx, "Balloon", V3(1.5, 1.8, 1.5), held(0.6, 4.4, -1.5), spec.hatColor or Color3.fromRGB(255, 100, 140), opt("Body"))
end
Gear.held_orb = function(ctx, spec)
	T.blob(ctx, "Orb", V3(1.1, 1.1, 1.1), held(0.4, 1.5, -1.7), ctx.Accent, opt("Body", { Material = NEON, Transparency = 0.2 }))
	T.blob(ctx, "OrbCore", V3(0.5, 0.5, 0.5), held(0.4, 1.5, -1.7), WHITE, opt("Body", { Material = NEON }))
end

return Gear
