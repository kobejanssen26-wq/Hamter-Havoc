--[[
	Hats, crowns, helmets and headwear. All attach to the Head.
	Head top is y = 3.4 at z = -0.7; hats sit around (0, 3.3, -0.65).
]]

local Toolkit = require(script.Parent.Toolkit)

local T = Toolkit
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local V3 = Vector3.new
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal

local Hats = {} :: { [string]: (Toolkit.Ctx, any) -> () }

local HZ = -0.65
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 210, 80)
local BLACK = Color3.fromRGB(34, 30, 38)
local RED = Color3.fromRGB(230, 70, 70)
local STEEL = Color3.fromRGB(190, 196, 210)

local function head(extra: { [string]: any }?): any
	local options: any = { Attach = "Head" }
	if extra then
		for key, value in extra do
			options[key] = value
		end
	end
	return options
end

-- stacked rods forming a cone-like silhouette. layers: {diameter, height, color, material?}
local function cone(ctx: Toolkit.Ctx, name: string, baseY: number, z: number, layers: { { any } }): number
	local y = baseY
	for index, layer in layers do
		T.rod(ctx, name .. index, layer[1], layer[2], CF(0, y + layer[2] / 2, z), layer[3], head({ Material = layer[4] }))
		y += layer[2] * 0.88
	end
	return y
end

local function pompom(ctx: Toolkit.Ctx, position: Vector3, size: number, color: Color3?)
	T.blob(ctx, "Pompom", V3(size, size, size), CF(position), color or WHITE, head())
end

---------------------------------------------------------------------------

Hats.party = function(ctx, spec)
	local a = ctx.Accent
	local top = cone(ctx, "Party", 3.2, HZ, { { 1.8, 0.5, a }, { 1.45, 0.5, WHITE }, { 1.1, 0.5, a }, { 0.75, 0.5, WHITE }, { 0.4, 0.45, a } })
	pompom(ctx, V3(0, top + 0.1, HZ), 0.5, GOLD)
end

Hats.tophat = function(ctx, spec)
	T.plate(ctx, "Brim", 2.7, 0.15, CF(0, 3.35, HZ), BLACK, head())
	T.rod(ctx, "Crown", 1.75, 1.6, CF(0, 4.2, HZ), BLACK, head())
	T.rod(ctx, "Band", 1.8, 0.3, CF(0, 3.65, HZ), spec.hatColor or RED, head())
end

Hats.chef = function(ctx, spec)
	T.rod(ctx, "Band", 1.8, 0.7, CF(0, 3.55, HZ), WHITE, head())
	T.blob(ctx, "Puff", V3(2.5, 1.7, 2.5), CF(0, 4.5, HZ), WHITE, head())
	T.blob(ctx, "PuffSide", V3(1.2, 1.2, 1.2), CF(0.9, 4.3, HZ + 0.5), WHITE, head({ Minor = true }))
end

Hats.crown = function(ctx, spec)
	local color = spec.hatColor or GOLD
	T.rod(ctx, "Band", 1.95, 0.55, CF(0, 3.6, HZ), color, head({ Material = METAL }))
	for index = 0, 4 do
		local angle = (index / 5) * math.pi * 2
		T.blob(ctx, "Spike", V3(0.4, 0.9, 0.4), CF(math.cos(angle) * 0.85, 4.15, HZ + math.sin(angle) * 0.85), color, head({ Material = METAL }))
		T.blob(ctx, "Jewel", V3(0.22, 0.22, 0.22), CF(math.cos(angle) * 0.85, 4.65, HZ + math.sin(angle) * 0.85), if index % 2 == 0 then RED else Color3.fromRGB(80, 160, 255), head({ Material = NEON, Minor = true }))
	end
end

Hats.royal = function(ctx, spec)
	local velvet = spec.hatColor or Color3.fromRGB(150, 40, 70)
	T.blob(ctx, "Velvet", V3(2.1, 1.3, 2.0), CF(0, 3.85, HZ), velvet, head())
	T.rod(ctx, "Trim", 2.2, 0.45, CF(0, 3.5, HZ), Color3.fromRGB(250, 245, 240), head())
	for _, angle in { 0, 90 } do
		T.rod(ctx, "Arch", 0.22, 2.1, CF(0, 4.25, HZ) * ANG(rad(angle), 0, rad(90 - angle)), GOLD, head({ Material = METAL }))
	end
	T.blob(ctx, "Orb", V3(0.5, 0.5, 0.5), CF(0, 4.85, HZ), GOLD, head({ Material = METAL }))
	T.gem(ctx, "BigJewel", V3(0.34, 0.34, 0.2), CF(0, 3.55, HZ - 1.1), Color3.fromRGB(110, 220, 255), head())
end

Hats.halo = function(ctx, spec)
	T.plate(ctx, "Halo", 2.2, 0.12, CF(0, 4.4, HZ) * ANG(rad(6), 0, 0), spec.hatColor or GOLD, head({ Material = NEON }))
	T.plate(ctx, "HaloCore", 1.7, 0.14, CF(0, 4.4, HZ) * ANG(rad(6), 0, 0), Color3.fromRGB(255, 252, 220), head({ Material = NEON, Transparency = 0.3 }))
end

Hats.horns = function(ctx, spec)
	local color = spec.hatColor or Color3.fromRGB(220, 50, 60)
	T.both(function(side)
		T.blob(ctx, "Horn", V3(0.45, 1.2, 0.45), CF(side * 0.85, 3.8, -0.7) * ANG(0, 0, rad(-side * 25)), color, head())
		T.blob(ctx, "HornTip", V3(0.25, 0.6, 0.25), CF(side * 1.15, 4.35, -0.7) * ANG(0, 0, rad(-side * 40)), color, head())
	end)
end

Hats.beanie = function(ctx, spec)
	local color = spec.hatColor or ctx.Accent
	T.blob(ctx, "Beanie", V3(2.7, 1.5, 2.4), CF(0, 3.55, HZ), color, head())
	T.rod(ctx, "Cuff", 2.7, 0.45, CF(0, 3.3, HZ), T.shade(color, 0.8), head())
	pompom(ctx, V3(0, 4.45, HZ), 0.6, WHITE)
end

Hats.cowboy = function(ctx, spec)
	local brown = Color3.fromRGB(150, 100, 60)
	T.plate(ctx, "Brim", 3.6, 0.14, CF(0, 3.4, HZ), brown, head())
	T.both(function(side)
		T.blob(ctx, "BrimCurl", V3(0.9, 0.35, 2), CF(side * 1.5, 3.55, HZ), brown, head())
	end)
	T.rod(ctx, "Crown", 1.7, 1, CF(0, 3.9, HZ), brown, head())
	T.rod(ctx, "Band", 1.75, 0.25, CF(0, 3.55, HZ), Color3.fromRGB(80, 50, 30), head())
	T.blob(ctx, "Pinch", V3(1.2, 0.35, 1.3), CF(0, 4.4, HZ), T.shade(brown, 1.1), head())
end

Hats.wizard = function(ctx, spec)
	local color = spec.hatColor or Color3.fromRGB(110, 70, 190)
	T.plate(ctx, "Brim", 3.1, 0.14, CF(0, 3.4, HZ), color, head())
	local top = cone(ctx, "Cone", 3.4, HZ, { { 2, 0.9, color }, { 1.55, 0.9, color }, { 1.1, 0.9, color }, { 0.7, 0.8, color } })
	T.rod(ctx, "Band", 2.05, 0.28, CF(0, 3.62, HZ), GOLD, head())
	T.star(ctx, "Star", 0.55, CF(0, 3.9, HZ - 1.05), Color3.fromRGB(255, 240, 130), head())
	T.blob(ctx, "Tip", V3(0.4, 0.5, 0.4), CF(0.1, top + 0.1, HZ), color, head())
end

Hats.pirate = function(ctx, spec)
	T.blob(ctx, "Hat", V3(3.5, 1.1, 2.2), CF(0, 3.75, HZ), BLACK, head())
	T.blob(ctx, "Brim", V3(3.9, 0.4, 2.4), CF(0, 3.4, HZ), BLACK, head())
	T.blob(ctx, "Skull", V3(0.6, 0.55, 0.2), CF(0, 3.8, HZ - 1.05), WHITE, head())
	T.block(ctx, "Bone", V3(1, 0.14, 0.12), CF(0, 3.55, HZ - 1.08), WHITE, head())
	T.blob(ctx, "Feather", V3(0.3, 1.1, 0.5), CF(1.4, 4.2, HZ) * ANG(0, 0, rad(-30)), RED, head())
end

Hats.knight = function(ctx, spec)
	T.blob(ctx, "Helm", V3(2.9, 2.0, 2.5), CF(0, 3.2, HZ), STEEL, head({ Material = METAL }))
	T.block(ctx, "Visor", V3(2, 0.3, 0.3), CF(0, 2.75, HZ - 1.2), Color3.fromRGB(60, 60, 75), head())
	T.block(ctx, "Crest", V3(0.3, 0.6, 2.2), CF(0, 4.35, HZ), STEEL, head({ Material = METAL }))
	T.blob(ctx, "Plume", V3(0.55, 1.4, 1.4), CF(0, 4.8, HZ + 0.3), spec.hatColor or RED, head())
end

Hats.flowers = function(ctx, spec)
	for index = 1, 8 do
		local angle = (index / 8) * math.pi * 2
		local color = ({ Color3.fromRGB(255, 130, 170), Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 220, 100), Color3.fromRGB(190, 150, 255) })[(index - 1) % 4 + 1]
		T.blob(ctx, "Flower", V3(0.55, 0.45, 0.55), CF(math.cos(angle) * 1.05, 3.3 + math.abs(math.sin(angle)) * 0.02, HZ + math.sin(angle) * 0.95), color, head())
		T.blob(ctx, "Leaf", V3(0.35, 0.18, 0.5), CF(math.cos(angle + 0.2) * 1.05, 3.25, HZ + math.sin(angle + 0.2) * 0.95), Color3.fromRGB(110, 190, 100), head({ Minor = true }))
	end
end

Hats.leaf = function(ctx, spec)
	local green = Color3.fromRGB(100, 190, 100)
	T.blob(ctx, "Leaf", V3(2.6, 0.22, 1.8), CF(0, 3.6, HZ) * ANG(rad(-8), 0, rad(8)), green, head())
	T.block(ctx, "Vein", V3(2.2, 0.06, 0.1), CF(0, 3.72, HZ) * ANG(rad(-8), 0, rad(8)), Color3.fromRGB(70, 150, 80), head())
	T.rod(ctx, "Stem", 0.14, 0.7, CF(0.9, 3.35, HZ + 0.3) * ANG(0, 0, rad(60)), Color3.fromRGB(80, 150, 80), head())
end

Hats.bow = function(ctx, spec)
	local color = spec.hatColor or Color3.fromRGB(255, 120, 170)
	T.blob(ctx, "BowL", V3(0.9, 0.7, 0.35), CF(0.55, 3.45, -1.0) * ANG(0, 0, rad(15)), color, head())
	T.blob(ctx, "BowR", V3(0.9, 0.7, 0.35), CF(1.4, 3.35, -1.0) * ANG(0, 0, rad(-15)), color, head())
	T.blob(ctx, "Knot", V3(0.4, 0.4, 0.4), CF(0.95, 3.4, -1.0), T.shade(color, 0.85), head())
end

Hats.alien = function(ctx, spec)
	T.both(function(side)
		T.rod(ctx, "Antenna", 0.12, 1.5, CF(side * 0.6, 4.1, -0.8) * ANG(0, 0, rad(-side * 15)), Color3.fromRGB(110, 190, 110), head())
		T.blob(ctx, "Bulb", V3(0.5, 0.5, 0.5), CF(side * 0.85, 4.9, -0.8), spec.hatColor or Color3.fromRGB(150, 255, 150), head({ Material = NEON }))
	end)
end

Hats.mushroom = function(ctx, spec)
	local cap = spec.hatColor or Color3.fromRGB(235, 80, 80)
	T.blob(ctx, "Cap", V3(3.3, 1.7, 3.1), CF(0, 3.75, HZ), cap, head())
	for index, offset in { V3(-0.8, 4.4, -0.2), V3(0.7, 4.5, 0.3), V3(0, 4.25, -1.2), V3(1.2, 4.0, -0.9), V3(-1.2, 4.0, -0.8) } do
		T.blob(ctx, "Dot", V3(0.5, 0.2, 0.5), CF(offset), WHITE, head({ Minor = index > 3 }))
	end
end

Hats.cheese = function(ctx, spec)
	local cheese = Color3.fromRGB(255, 205, 70)
	T.block(ctx, "Wedge", V3(1.9, 1.3, 1.8), CF(0, 3.95, HZ) * ANG(0, rad(10), rad(4)), cheese, head())
	T.blob(ctx, "Hole", V3(0.5, 0.5, 0.2), CF(0.3, 4.1, HZ - 0.95), Color3.fromRGB(220, 160, 40), head())
	T.blob(ctx, "Hole", V3(0.35, 0.35, 0.2), CF(-0.5, 3.8, HZ - 0.95), Color3.fromRGB(220, 160, 40), head({ Minor = true }))
end

Hats.strawberry = function(ctx, spec)
	T.blob(ctx, "Berry", V3(2.3, 2, 2.3), CF(0, 3.8, HZ), Color3.fromRGB(235, 55, 75), head())
	for index = 0, 5 do
		local angle = (index / 6) * math.pi * 2
		T.blob(ctx, "Leaf", V3(0.6, 0.18, 0.9), CF(math.cos(angle) * 0.55, 4.8, HZ + math.sin(angle) * 0.55) * ANG(0, -angle, 0), Color3.fromRGB(90, 190, 90), head())
		T.blob(ctx, "Seed", V3(0.14, 0.2, 0.14), CF(math.cos(angle) * 1.0, 3.7 + (index % 2) * 0.5, HZ + math.sin(angle) * 1.0), Color3.fromRGB(255, 230, 130), head({ Minor = true }))
	end
end

Hats.bread = function(ctx, spec)
	T.blob(ctx, "Loaf", V3(2.8, 1.7, 2.1), CF(0, 3.95, HZ), Color3.fromRGB(215, 160, 95), head())
	for index = -1, 1 do
		T.block(ctx, "Slash", V3(0.15, 0.1, 0.9), CF(index * 0.6, 4.75, HZ) * ANG(0, rad(30), 0), Color3.fromRGB(245, 215, 160), head())
	end
end

Hats.acorn = function(ctx, spec)
	T.blob(ctx, "Cap", V3(2.6, 1.4, 2.5), CF(0, 3.65, HZ), Color3.fromRGB(150, 100, 60), head())
	T.rod(ctx, "Stem", 0.3, 0.6, CF(0, 4.4, HZ), Color3.fromRGB(110, 70, 40), head())
	T.rod(ctx, "Rim", 2.7, 0.2, CF(0, 3.28, HZ), Color3.fromRGB(120, 80, 50), head())
end

Hats.santa = function(ctx, spec)
	cone(ctx, "Santa", 3.25, HZ, { { 2.4, 0.7, RED }, { 1.9, 0.7, RED }, { 1.4, 0.7, RED }, { 0.9, 0.6, RED } })
	T.rod(ctx, "Trim", 2.55, 0.4, CF(0, 3.3, HZ), WHITE, head())
	pompom(ctx, V3(0.7, 4.5, HZ + 0.4), 0.55, WHITE)
end

Hats.nightcap = function(ctx, spec)
	local color = spec.hatColor or Color3.fromRGB(130, 150, 230)
	T.blob(ctx, "Cap", V3(2.6, 1.4, 2.4), CF(0, 3.5, HZ), color, head())
	T.blob(ctx, "Droop", V3(0.9, 0.9, 1.8), CF(0.2, 3.9, HZ + 1.6), color, head())
	T.blob(ctx, "Droop2", V3(0.6, 0.6, 1.2), CF(0.3, 3.5, HZ + 2.5), color, head())
	pompom(ctx, V3(0.35, 3.1, HZ + 3.1), 0.5, WHITE)
	T.star(ctx, "Star", 0.4, CF(-0.5, 3.9, HZ - 1.1), Color3.fromRGB(255, 240, 130), head())
end

Hats.tiara = function(ctx, spec)
	T.rod(ctx, "Band", 2.0, 0.22, CF(0, 3.5, HZ), STEEL, head({ Material = METAL }))
	for index = -2, 2 do
		local height = 0.5 + (2 - math.abs(index)) * 0.18
		T.gem(ctx, "Gem", V3(0.3, height, 0.3), CF(index * 0.4, 3.75 + height / 2, HZ - 0.85 + math.abs(index) * 0.12), if index == 0 then Color3.fromRGB(255, 120, 190) else Color3.fromRGB(150, 220, 255), head())
	end
end

Hats.viking = function(ctx, spec)
	T.blob(ctx, "Helm", V3(2.9, 2.0, 2.6), CF(0, 3.2, HZ), Color3.fromRGB(150, 150, 165), head({ Material = METAL }))
	T.rod(ctx, "Band", 2.95, 0.3, CF(0, 3.0, HZ), Color3.fromRGB(120, 85, 50), head())
	T.both(function(side)
		T.blob(ctx, "HornBase", V3(0.6, 0.6, 0.6), CF(side * 1.5, 3.4, HZ), Color3.fromRGB(245, 235, 215), head())
		T.blob(ctx, "HornMid", V3(0.5, 0.9, 0.5), CF(side * 1.9, 3.9, HZ) * ANG(0, 0, rad(-side * 30)), Color3.fromRGB(245, 235, 215), head())
		T.blob(ctx, "HornTip", V3(0.3, 0.7, 0.3), CF(side * 2.3, 4.5, HZ) * ANG(0, 0, rad(-side * 55)), Color3.fromRGB(245, 235, 215), head())
	end)
end

Hats.astro = function(ctx, spec)
	T.blob(ctx, "Bubble", V3(3.5, 3.3, 3.2), CF(0, 2.5, -0.7), Color3.fromRGB(200, 235, 255), head({ Transparency = 0.65, Material = Enum.Material.Glass }))
	T.rod(ctx, "Collar", 3.2, 0.5, CF(0, 1.5, -0.4), WHITE, head())
	T.rod(ctx, "Antenna", 0.12, 0.8, CF(1.2, 4.2, -0.7), STEEL, head())
	T.blob(ctx, "Light", V3(0.3, 0.3, 0.3), CF(1.2, 4.7, -0.7), RED, head({ Material = NEON }))
end

Hats.sunhat = function(ctx, spec)
	local straw = Color3.fromRGB(240, 210, 130)
	T.plate(ctx, "Brim", 4, 0.12, CF(0, 3.35, HZ), straw, head())
	T.rod(ctx, "Crown", 1.9, 0.8, CF(0, 3.75, HZ), straw, head())
	T.rod(ctx, "Ribbon", 1.95, 0.25, CF(0, 3.55, HZ), spec.hatColor or Color3.fromRGB(255, 120, 150), head())
	T.blob(ctx, "Flower", V3(0.5, 0.4, 0.5), CF(1, 3.7, HZ - 0.7), WHITE, head({ Minor = true }))
end

Hats.crystal_crown = function(ctx, spec)
	local color = ctx.Accent
	T.rod(ctx, "Band", 1.95, 0.4, CF(0, 3.55, HZ), STEEL, head({ Material = METAL }))
	for index = 0, 6 do
		local angle = (index / 7) * math.pi * 2
		local height = 0.9 + (index % 3) * 0.35
		T.crystal(ctx, "Crystal", 0.38, height, CF(math.cos(angle) * 0.85, 3.7 + height / 2, HZ + math.sin(angle) * 0.85) * ANG(rad(math.sin(angle) * 10), 0, rad(-math.cos(angle) * 10)), color, head())
	end
end

Hats.pizza = function(ctx, spec)
	T.blob(ctx, "Slice", V3(2.4, 0.45, 2.4), CF(0, 3.55, HZ), Color3.fromRGB(250, 200, 90), head())
	T.blob(ctx, "Crust", V3(2.5, 0.55, 0.5), CF(0, 3.55, HZ - 1.15), Color3.fromRGB(215, 150, 80), head())
	for _, offset in { V3(-0.5, 3.8, -0.4), V3(0.5, 3.8, -0.9), V3(0.1, 3.8, 0.1) } do
		T.blob(ctx, "Pepperoni", V3(0.55, 0.15, 0.55), CF(offset), Color3.fromRGB(200, 60, 60), head())
	end
end

Hats.cloud = function(ctx, spec)
	for index, offset in { V3(0, 4.1, HZ), V3(-0.9, 3.9, HZ + 0.2), V3(0.9, 3.9, HZ - 0.1), V3(0.2, 4.6, HZ + 0.2) } do
		T.blob(ctx, "Puff", V3(1.7 - index * 0.1, 1.2, 1.5), CF(offset), WHITE, head({ Transparency = 0.05 }))
	end
end

Hats.bee = function(ctx, spec)
	T.both(function(side)
		T.rod(ctx, "Antenna", 0.1, 1.3, CF(side * 0.6, 4, -0.8) * ANG(0, 0, rad(-side * 20)), BLACK, head())
		T.blob(ctx, "Bulb", V3(0.4, 0.4, 0.4), CF(side * 0.85, 4.7, -0.8), Color3.fromRGB(255, 215, 60), head())
	end)
end

Hats.propeller = function(ctx, spec)
	local color = spec.hatColor or Color3.fromRGB(80, 150, 255)
	T.blob(ctx, "Cap", V3(2.6, 1.3, 2.4), CF(0, 3.5, HZ), color, head())
	T.rod(ctx, "Peg", 0.2, 0.5, CF(0, 4.25, HZ), STEEL, head())
	T.blob(ctx, "BladeA", V3(2.4, 0.1, 0.5), CF(0, 4.55, HZ), Color3.fromRGB(255, 80, 80), head())
	T.blob(ctx, "BladeB", V3(0.5, 0.1, 2.4), CF(0, 4.55, HZ), Color3.fromRGB(255, 220, 70), head())
end

Hats.samurai = function(ctx, spec)
	T.blob(ctx, "Kabuto", V3(2.9, 1.8, 2.5), CF(0, 3.3, HZ), Color3.fromRGB(70, 70, 90), head({ Material = METAL }))
	T.both(function(side)
		T.blob(ctx, "Flap", V3(0.4, 1.2, 1.8), CF(side * 1.5, 2.8, HZ), Color3.fromRGB(150, 40, 50), head())
		T.blob(ctx, "Horn", V3(0.35, 1.6, 0.25), CF(side * 0.6, 4.4, HZ - 0.9) * ANG(0, 0, rad(-side * 25)), GOLD, head({ Material = METAL }))
	end)
	T.blob(ctx, "Crest", V3(0.5, 0.5, 0.2), CF(0, 3.8, HZ - 1.2), GOLD, head({ Material = METAL }))
end

Hats.pharaoh = function(ctx, spec)
	local blue = Color3.fromRGB(60, 110, 200)
	T.blob(ctx, "Nemes", V3(2.8, 1.8, 2.6), CF(0, 3.3, HZ), GOLD, head({ Material = METAL }))
	T.both(function(side)
		for index = 0, 3 do
			T.block(ctx, "Drape", V3(0.55, 0.4, 1.0), CF(side * 1.35, 2.9 - index * 0.5, HZ + 0.2), if index % 2 == 0 then blue else GOLD, head())
		end
	end)
	T.blob(ctx, "Cobra", V3(0.4, 0.7, 0.4), CF(0, 3.75, HZ - 1.25), Color3.fromRGB(80, 200, 120), head({ Material = NEON }))
end

Hats.jester = function(ctx, spec)
	local a = spec.hatColor or Color3.fromRGB(230, 70, 120)
	local b = Color3.fromRGB(80, 120, 230)
	T.rod(ctx, "Band", 2.1, 0.4, CF(0, 3.4, HZ), GOLD, head())
	T.both(function(side)
		T.blob(ctx, "Horn", V3(0.9, 1.4, 0.9), CF(side * 0.9, 3.95, HZ) * ANG(0, 0, rad(-side * 30)), if side < 0 then a else b, head())
		T.blob(ctx, "HornTip", V3(0.6, 0.9, 0.6), CF(side * 1.5, 4.55, HZ) * ANG(0, 0, rad(-side * 55)), if side < 0 then a else b, head())
		T.blob(ctx, "Bell", V3(0.4, 0.4, 0.4), CF(side * 1.95, 4.75, HZ), GOLD, head({ Material = METAL }))
	end)
end

Hats.flame_crown = function(ctx, spec)
	T.rod(ctx, "Band", 1.9, 0.4, CF(0, 3.55, HZ), Color3.fromRGB(90, 30, 30), head({ Material = METAL }))
	for index = 0, 5 do
		local angle = (index / 6) * math.pi * 2
		local height = 0.9 + (index % 2) * 0.5
		T.blob(ctx, "Flame", V3(0.5, height, 0.5), CF(math.cos(angle) * 0.85, 3.8 + height / 2, HZ + math.sin(angle) * 0.85), if index % 2 == 0 then Color3.fromRGB(255, 120, 40) else Color3.fromRGB(255, 200, 70), head({ Material = NEON }))
	end
	T.emitter(ctx, "flame", Color3.fromRGB(255, 150, 60), "Head")
end

Hats.star_crown = function(ctx, spec)
	T.rod(ctx, "Band", 1.95, 0.35, CF(0, 3.55, HZ), GOLD, head({ Material = METAL }))
	for index = 0, 4 do
		local angle = (index / 5) * math.pi * 2
		T.star(ctx, "Star", 0.7, CF(math.cos(angle) * 0.85, 4.15, HZ + math.sin(angle) * 0.85) * ANG(0, -angle + math.pi / 2, 0), Color3.fromRGB(255, 240, 130), head())
	end
end

Hats.laurel = function(ctx, spec)
	for index = 0, 9 do
		local angle = math.rad(130 + index * 28)
		T.blob(ctx, "Leaf", V3(0.5, 0.2, 0.8), CF(math.cos(angle) * 1.15, 3.2, HZ + math.sin(angle) * 1.1) * ANG(0, -angle, 0), if index % 2 == 0 then Color3.fromRGB(120, 190, 90) else GOLD, head({ Material = if index % 2 == 0 then nil else METAL }))
	end
end

Hats.golden_helm = function(ctx, spec)
	T.blob(ctx, "Helm", V3(2.9, 2.1, 2.5), CF(0, 3.2, HZ), GOLD, head({ Material = METAL, Reflectance = 0.2 }))
	T.block(ctx, "Visor", V3(2, 0.3, 0.3), CF(0, 2.75, HZ - 1.2), Color3.fromRGB(80, 60, 30), head())
	T.both(function(side)
		T.blob(ctx, "Wing", V3(0.25, 0.9, 1.5), CF(side * 1.55, 3.6, HZ) * ANG(0, 0, rad(-side * 35)), WHITE, head())
	end)
	T.blob(ctx, "Jewel", V3(0.4, 0.4, 0.3), CF(0, 3.95, HZ - 1.2), Color3.fromRGB(255, 80, 120), head({ Material = NEON }))
end

Hats.void_crown = function(ctx, spec)
	local purple = Color3.fromRGB(70, 20, 120)
	T.rod(ctx, "Band", 1.95, 0.4, CF(0, 3.55, HZ), Color3.fromRGB(25, 10, 40), head({ Material = METAL }))
	for index = 0, 4 do
		local angle = (index / 5) * math.pi * 2
		local height = 1 + (index % 2) * 0.6
		T.crystal(ctx, "Shard", 0.34, height, CF(math.cos(angle) * 0.85, 3.8 + height / 2, HZ + math.sin(angle) * 0.85) * ANG(rad(math.sin(angle) * 14), 0, rad(-math.cos(angle) * 14)), purple, head())
	end
	T.gem(ctx, "FloatShard", V3(0.4, 0.4, 0.4), CF(0, 5.1, HZ), Color3.fromRGB(190, 90, 255), head())
end

Hats.galaxy_crown = function(ctx, spec)
	T.rod(ctx, "Band", 1.9, 0.3, CF(0, 3.5, HZ), Color3.fromRGB(30, 30, 90), head({ Material = METAL }))
	for index = 0, 4 do
		local angle = (index / 5) * math.pi * 2
		T.blob(ctx, "Orb", V3(0.5, 0.5, 0.5), CF(math.cos(angle) * 1.25, 4.1 + (index % 2) * 0.3, HZ + math.sin(angle) * 1.25), Color3.fromHSV(0.6 + index * 0.06, 0.7, 1), head({ Material = NEON }))
	end
	T.star(ctx, "Star", 0.8, CF(0, 4.7, HZ), Color3.new(1, 1, 1), head())
end

Hats.headphones = function(ctx, spec)
	local color = spec.hatColor or ctx.Accent
	T.rod(ctx, "Arc", 0.28, 3.1, CF(0, 3.45, HZ) * ANG(0, 0, 0), color, head())
	T.both(function(side)
		T.rod(ctx, "Cup", 1.0, 0.55, CF(side * 1.5, 2.6, HZ), T.shade(color, 0.75), head({ Material = METAL }))
		T.blob(ctx, "Pad", V3(0.35, 0.85, 0.85), CF(side * 1.3, 2.6, HZ), Color3.fromRGB(60, 60, 70), head())
		T.rod(ctx, "Band", 0.28, 1.0, CF(side * 1.5, 3.1, HZ), color, head())
	end)
end

Hats.beret = function(ctx, spec)
	T.blob(ctx, "Beret", V3(2.9, 0.9, 2.5), CF(0.15, 3.5, HZ) * ANG(0, 0, rad(-8)), spec.hatColor or Color3.fromRGB(210, 60, 80), head())
	T.rod(ctx, "Stem", 0.2, 0.4, CF(0.2, 4.05, HZ), Color3.fromRGB(150, 40, 60), head())
end

Hats.detective = function(ctx, spec)
	local tan = Color3.fromRGB(190, 160, 110)
	T.blob(ctx, "Cap", V3(2.7, 1.3, 2.4), CF(0, 3.55, HZ), tan, head())
	T.blob(ctx, "VisorFront", V3(1.6, 0.2, 0.9), CF(0, 3.3, HZ - 1.2), Color3.fromRGB(130, 100, 70), head())
	T.blob(ctx, "VisorBack", V3(1.6, 0.2, 0.9), CF(0, 3.3, HZ + 1.2), Color3.fromRGB(130, 100, 70), head())
	T.block(ctx, "Check", V3(0.3, 0.3, 0.3), CF(0.6, 4.1, HZ), Color3.fromRGB(120, 90, 60), head())
	T.block(ctx, "Check", V3(0.3, 0.3, 0.3), CF(-0.5, 4.0, HZ - 0.5), Color3.fromRGB(120, 90, 60), head({ Minor = true }))
end

Hats.ninja_band = function(ctx, spec)
	local color = spec.hatColor or Color3.fromRGB(60, 60, 100)
	T.rod(ctx, "Band", 2.6, 0.55, CF(0, 3.0, HZ), color, head())
	T.block(ctx, "Plate", V3(1.2, 0.5, 0.2), CF(0, 3.0, HZ - 1.2), STEEL, head({ Material = METAL }))
	T.block(ctx, "TailA", V3(0.35, 0.2, 1.4), CF(0.3, 3.0, HZ + 1.6) * ANG(0, rad(-12), 0), color, head())
	T.block(ctx, "TailB", V3(0.35, 0.2, 1.1), CF(-0.2, 2.7, HZ + 1.5) * ANG(0, rad(14), 0), color, head())
end

Hats.bandana = function(ctx, spec)
	local color = spec.hatColor or RED
	T.blob(ctx, "Cloth", V3(2.7, 1.2, 2.45), CF(0, 3.4, HZ), color, head())
	T.blob(ctx, "Knot", V3(0.5, 0.5, 0.5), CF(0, 3.2, HZ + 1.3), T.shade(color, 0.8), head())
	T.block(ctx, "Dot", V3(0.2, 0.2, 0.1), CF(0.5, 3.8, HZ - 0.95), WHITE, head({ Minor = true }))
	T.block(ctx, "Dot", V3(0.2, 0.2, 0.1), CF(-0.5, 3.7, HZ - 1.0), WHITE, head({ Minor = true }))
end

Hats.witch = function(ctx, spec)
	local color = BLACK
	T.plate(ctx, "Brim", 3.2, 0.14, CF(0, 3.4, HZ), color, head())
	local top = cone(ctx, "Cone", 3.4, HZ, { { 2, 0.9, color }, { 1.5, 0.9, color }, { 1.05, 0.9, color }, { 0.6, 0.8, color } })
	T.rod(ctx, "Band", 2.05, 0.3, CF(0, 3.65, HZ), Color3.fromRGB(150, 70, 210), head())
	T.block(ctx, "Buckle", V3(0.5, 0.4, 0.15), CF(0, 3.65, HZ - 1.03), GOLD, head({ Material = METAL }))
	T.blob(ctx, "Bend", V3(0.5, 0.7, 0.5), CF(0.25, top + 0.2, HZ) * ANG(0, 0, rad(-25)), color, head())
end

Hats.sprout = function(ctx, spec)
	T.rod(ctx, "Stem", 0.14, 0.9, CF(0, 3.8, HZ), Color3.fromRGB(90, 170, 90), head())
	T.both(function(side)
		T.blob(ctx, "SproutLeaf", V3(0.9, 0.12, 0.5), CF(side * 0.42, 4.3, HZ) * ANG(0, 0, rad(side * 25)), Color3.fromRGB(120, 210, 110), head())
	end)
end

Hats.hardhat = function(ctx, spec)
	T.blob(ctx, "Dome", V3(2.7, 1.5, 2.4), CF(0, 3.5, HZ), Color3.fromRGB(255, 205, 40), head())
	T.plate(ctx, "Brim", 2.9, 0.12, CF(0, 3.2, HZ), Color3.fromRGB(240, 190, 30), head())
	T.block(ctx, "Ridge", V3(0.3, 0.2, 2.2), CF(0, 4.25, HZ), Color3.fromRGB(240, 190, 30), head())
	T.blob(ctx, "Lamp", V3(0.5, 0.4, 0.3), CF(0, 3.7, HZ - 1.1), Color3.fromRGB(255, 250, 200), head({ Material = NEON }))
end

Hats.sailor = function(ctx, spec)
	T.rod(ctx, "Band", 2.6, 0.5, CF(0, 3.3, HZ), Color3.fromRGB(40, 60, 120), head())
	T.blob(ctx, "Top", V3(2.7, 0.6, 2.5), CF(0, 3.65, HZ), WHITE, head())
	T.block(ctx, "Ribbon", V3(0.3, 0.2, 1.5), CF(0.4, 3.2, HZ + 1.4), Color3.fromRGB(40, 60, 120), head({ Minor = true }))
end

Hats.antlers = function(ctx, spec)
	local brown = Color3.fromRGB(150, 105, 65)
	T.both(function(side)
		T.rod(ctx, "Beam", 0.28, 1.8, CF(side * 0.85, 4.1, HZ) * ANG(0, 0, rad(-side * 18)), brown, head())
		T.rod(ctx, "Tine", 0.22, 0.9, CF(side * 1.4, 4.45, HZ) * ANG(0, 0, rad(-side * 60)), brown, head())
		T.rod(ctx, "Tine", 0.22, 0.7, CF(side * 1.15, 3.95, HZ - 0.3) * ANG(rad(40), 0, rad(-side * 45)), brown, head({ Minor = true }))
	end)
end

Hats.moon_circlet = function(ctx, spec)
	T.rod(ctx, "Band", 1.95, 0.22, CF(0, 3.5, HZ), STEEL, head({ Material = METAL }))
	T.blob(ctx, "Moon", V3(0.9, 0.9, 0.2), CF(0, 4.1, HZ - 0.95), Color3.fromRGB(250, 250, 255), head({ Material = NEON }))
	T.blob(ctx, "MoonCut", V3(0.75, 0.75, 0.22), CF(0.2, 4.15, HZ - 1.0), ctx.Accent, head())
end

Hats.sun_crown = function(ctx, spec)
	T.rod(ctx, "Band", 1.9, 0.35, CF(0, 3.55, HZ), GOLD, head({ Material = METAL }))
	for index = 0, 8 do
		local angle = (index / 9) * math.pi * 2
		T.blob(ctx, "Ray", V3(0.3, 1.1, 0.3), CF(math.cos(angle) * 0.9, 4.2, HZ + math.sin(angle) * 0.9) * ANG(rad(math.sin(angle) * 22), 0, rad(-math.cos(angle) * 22)), Color3.fromRGB(255, 235, 140), head({ Material = NEON }))
	end
	T.blob(ctx, "Sun", V3(0.7, 0.7, 0.4), CF(0, 3.7, HZ - 1.05), Color3.fromRGB(255, 200, 60), head({ Material = NEON }))
end

Hats.ice_crown = function(ctx, spec)
	local ice = Color3.fromRGB(170, 230, 255)
	T.rod(ctx, "Band", 1.95, 0.35, CF(0, 3.55, HZ), Color3.fromRGB(210, 240, 255), head({ Material = Enum.Material.Glass }))
	for index = 0, 5 do
		local angle = (index / 6) * math.pi * 2
		local height = 1 + (index % 2) * 0.5
		T.crystal(ctx, "Icicle", 0.36, height, CF(math.cos(angle) * 0.85, 3.8 + height / 2, HZ + math.sin(angle) * 0.85), ice, head())
	end
end

Hats.rune_circlet = function(ctx, spec)
	T.rod(ctx, "Band", 1.95, 0.4, CF(0, 3.5, HZ), Color3.fromRGB(150, 110, 70), head({ Material = Enum.Material.Slate }))
	for index = 0, 4 do
		local angle = math.rad(-60 + index * 30)
		T.block(ctx, "Rune", V3(0.25, 0.4, 0.1), CF(math.sin(angle) * 1.0, 3.5, HZ - math.cos(angle) * 1.0) * ANG(0, angle, 0), ctx.Accent, head({ Material = NEON }))
	end
end

Hats.stone_crown = function(ctx, spec)
	local stone = Color3.fromRGB(140, 130, 120)
	for index = 0, 5 do
		local angle = (index / 6) * math.pi * 2
		T.block(ctx, "Slab", V3(0.6, 0.9 + (index % 3) * 0.3, 0.45), CF(math.cos(angle) * 0.95, 3.8, HZ + math.sin(angle) * 0.95) * ANG(0, -angle, 0), stone, head({ Material = Enum.Material.Slate }))
	end
	T.rod(ctx, "Base", 2.1, 0.4, CF(0, 3.45, HZ), T.shade(stone, 0.8), head({ Material = Enum.Material.Slate }))
end

Hats.top_gem = function(ctx, spec)
	T.rod(ctx, "Base", 1.0, 0.25, CF(0, 3.45, HZ), GOLD, head({ Material = METAL }))
	T.gem(ctx, "Gem", V3(0.9, 1.1, 0.9), CF(0, 4.1, HZ), spec.hatColor or ctx.Accent, head())
end

Hats.hood = function(ctx, spec)
	local color = spec.hatColor or ctx.Accent
	T.blob(ctx, "Hood", V3(3.0, 2.5, 2.7), CF(0, 3.0, HZ + 0.15), color, head())
	T.blob(ctx, "HoodBack", V3(2.4, 1.7, 1.7), CF(0, 2.5, HZ + 1.5), color, head())
	T.rod(ctx, "Trim", 3, 0.3, CF(0, 2.2, HZ - 0.3), T.shade(color, 1.2), head({ Minor = true }))
end

Hats.crown_of_thorns = function(ctx, spec)
	for index = 0, 9 do
		local angle = (index / 10) * math.pi * 2
		T.block(ctx, "Thorn", V3(0.18, 0.7, 0.18), CF(math.cos(angle) * 1.0, 3.6, HZ + math.sin(angle) * 0.95) * ANG(rad(math.sin(angle) * 25), 0, rad(-math.cos(angle) * 25)), Color3.fromRGB(60, 40, 30), head())
	end
	T.rod(ctx, "Vine", 2.0, 0.2, CF(0, 3.35, HZ), Color3.fromRGB(70, 90, 60), head())
end

Hats.unicorn_horn = function(ctx, spec)
	local cream = Color3.fromRGB(255, 245, 225)
	local top = cone(ctx, "Horn", 3.3, -0.9, { { 0.75, 0.6, cream }, { 0.6, 0.6, Color3.fromRGB(255, 190, 230) }, { 0.45, 0.6, cream }, { 0.3, 0.6, Color3.fromRGB(190, 220, 255) }, { 0.16, 0.5, cream } })
	T.blob(ctx, "HornGlow", V3(0.3, 0.3, 0.3), CF(0, top + 0.1, -0.9), Color3.fromRGB(255, 255, 255), head({ Material = NEON }))
	T.both(function(side)
		T.blob(ctx, "HornEar", V3(0.5, 0.6, 0.2), CF(side * 0.35, 3.45, -0.9), Color3.fromRGB(255, 190, 220), head({ Minor = true }))
	end)
end

Hats.cat_hood = function(ctx, spec)
	local color = spec.hatColor or ctx.Accent
	T.blob(ctx, "Hood", V3(2.9, 1.4, 2.5), CF(0, 3.5, HZ), color, head())
	T.both(function(side)
		T.blob(ctx, "CatEar", V3(0.8, 1.1, 0.35), CF(side * 0.95, 4.2, HZ) * ANG(0, 0, rad(-side * 15)), color, head())
		T.blob(ctx, "CatEarIn", V3(0.45, 0.7, 0.2), CF(side * 0.95, 4.15, HZ - 0.1) * ANG(0, 0, rad(-side * 15)), Color3.fromRGB(255, 170, 190), head({ Minor = true }))
	end)
end

return Hats
