--[[
	Character props: the pieces that make a collectible hamster read as a specific JOKE or personality at a glance
	(a stack of cash, a sweater vest and a side parting, a stack of delivery boxes, a mini rocket, a pie ...). They are
	original designs and carry no logos or brand marks. Same conventions as Gear/Hats: hamster space, faces -Z.
	Used by Content/Hamsters files through Look.Acc, e.g.  Acc = { "sweater_vest", "side_part", "glasses_round" }.
]]

local Toolkit = require(script.Parent.Toolkit)

local T = Toolkit
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local V3 = Vector3.new
local METAL = Enum.Material.Metal
local NEON = Enum.Material.Neon

local Characters = {} :: { [string]: (Toolkit.Ctx, any) -> () }

local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 210, 80)
local CARDBOARD = Color3.fromRGB(196, 150, 96)

local function opt(attach: string, extra: { [string]: any }?): any
	local options: any = { Attach = attach }
	if extra then
		for key, value in extra do
			options[key] = value
		end
	end
	return options
end

-- A stack of banknotes held in the right paw, with a gold coin on top.
Characters.cash_stack = function(ctx, spec)
	local green = Color3.fromRGB(88, 190, 112)
	for index = 0, 2 do
		T.block(ctx, "Notes", V3(1.3, 0.28, 0.8), CF(0.6, 0.95 + index * 0.3, -1.6) * ANG(0, rad(-20 + index * 6), 0), T.shade(green, 1 - index * 0.05), opt("Body"))
	end
	T.block(ctx, "Band", V3(0.28, 1.0, 0.86), CF(0.6, 1.25, -1.6) * ANG(0, rad(-14), 0), WHITE, opt("Body", { Minor = true }))
	T.disc(ctx, "Coin", 0.55, 0.12, CF(0.6, 1.95, -1.55) * ANG(rad(70), 0, 0), GOLD, opt("Body", { Material = METAL }))
end

-- Knitted sweater vest over the belly with a collar and tie-less V neck.
Characters.sweater_vest = function(ctx, spec)
	local color = spec.hatColor or Color3.fromRGB(86, 120, 176)
	T.blob(ctx, "Vest", V3(2.85, 1.75, 2.75), CF(0, 1.1, 0.3), color, opt("Body", { Material = Enum.Material.Fabric }))
	T.block(ctx, "Shirt", V3(0.9, 0.8, 0.12), CF(0, 1.55, -1.58), WHITE, opt("Body"))
	T.block(ctx, "VNeckL", V3(0.5, 0.12, 0.12), CF(-0.28, 1.28, -1.62) * ANG(0, 0, rad(-50)), T.shade(color, 0.75), opt("Body", { Minor = true }))
	T.block(ctx, "VNeckR", V3(0.5, 0.12, 0.12), CF(0.28, 1.28, -1.62) * ANG(0, 0, rad(50)), T.shade(color, 0.75), opt("Body", { Minor = true }))
	for index = -1, 1 do
		T.block(ctx, "Knit", V3(0.08, 1.2, 0.08), CF(index * 0.7, 0.85, -1.55), T.shade(color, 0.85), opt("Body", { Minor = true }))
	end
end

-- Neatly combed hair with a side parting.
Characters.side_part = function(ctx, spec)
	local color = spec.HairColor or Color3.fromRGB(150, 120, 90)
	T.blob(ctx, "Hair", V3(2.3, 0.75, 2.0), CF(0, 3.33, -0.7), color, opt("Head"))
	T.block(ctx, "Parting", V3(0.07, 0.25, 1.3), CF(-0.5, 3.62, -0.7), T.shade(color, 0.6), opt("Head", { Minor = true }))
	T.blob(ctx, "Sweep", V3(1.2, 0.5, 1.5), CF(0.45, 3.5, -0.8) * ANG(0, 0, rad(-12)), T.shade(color, 1.12), opt("Head", { Minor = true }))
end

-- A tower of cardboard delivery boxes strapped to the back.
Characters.box_stack = function(ctx, spec)
	local sizes = { V3(2.0, 1.1, 1.3), V3(1.6, 0.95, 1.2), V3(1.2, 0.8, 1.0) }
	local y = 1.5
	for index, size in sizes do
		local lift = size.Y / 2
		T.block(ctx, "Box", size, CF(0, y + lift, 1.85) * ANG(0, rad((index - 2) * 7), 0), T.shade(CARDBOARD, 1 + (index - 2) * 0.06), opt("Body"))
		T.block(ctx, "Tape", V3(size.X * 0.2, size.Y + 0.04, size.Z + 0.04), CF(0, y + lift, 1.85) * ANG(0, rad((index - 2) * 7), 0), Color3.fromRGB(235, 220, 170), opt("Body", { Minor = true }))
		y += size.Y
	end
end

-- A little toy rocket held up in the paw.
Characters.mini_rocket = function(ctx, spec)
	local base = CF(0.65, 1.7, -1.5) * ANG(0, 0, rad(-12))
	T.rod(ctx, "Hull", 0.7, 1.8, base, Color3.fromRGB(240, 242, 248), opt("Body", { Material = METAL }))
	T.blob(ctx, "Nose", V3(0.7, 0.9, 0.7), base * CF(0, 1.2, 0), Color3.fromRGB(230, 70, 70), opt("Body"))
	T.disc(ctx, "Window", 0.32, 0.1, base * CF(0, 0.25, -0.34), Color3.fromRGB(120, 200, 255), opt("Body", { Material = NEON }))
	for index = 0, 2 do
		T.block(ctx, "Fin", V3(0.1, 0.55, 0.45), base * CF(0, -0.8, 0) * ANG(0, rad(index * 120), 0) * CF(0, 0, 0.4), Color3.fromRGB(230, 70, 70), opt("Body", { Minor = index == 2 }))
	end
	T.blob(ctx, "Flame", V3(0.45, 0.9, 0.45), base * CF(0, -1.45, 0), Color3.fromRGB(255, 170, 60), opt("Body", { Material = NEON }))
end

-- Football jersey with a bold number.
Characters.jersey = function(ctx, spec)
	local color = spec.hatColor or Color3.fromRGB(220, 60, 60)
	T.blob(ctx, "Jersey", V3(2.85, 1.8, 2.75), CF(0, 1.15, 0.3), color, opt("Body", { Material = Enum.Material.Fabric }))
	T.block(ctx, "Collar", V3(1.1, 0.16, 0.14), CF(0, 1.95, -1.4), WHITE, opt("Body"))
	T.block(ctx, "Stripe", V3(2.4, 0.18, 0.1), CF(0, 0.7, -1.55), WHITE, opt("Body", { Minor = true }))
	T.block(ctx, "SevenBar", V3(0.7, 0.14, 0.08), CF(0, 1.5, -1.68), WHITE, opt("Body"))
	T.block(ctx, "SevenStem", V3(0.14, 0.8, 0.08), CF(0.1, 1.15, -1.68) * ANG(0, 0, rad(-14)), WHITE, opt("Body"))
end

-- A whole pie held in both paws.
Characters.held_pie = function(ctx, spec)
	T.disc(ctx, "Tin", 1.5, 0.3, CF(0.1, 1.05, -1.65) * ANG(rad(-20), 0, 0), Color3.fromRGB(190, 196, 210), opt("Body", { Material = METAL }))
	T.disc(ctx, "Crust", 1.35, 0.4, CF(0.1, 1.08, -1.72) * ANG(rad(-20), 0, 0), Color3.fromRGB(225, 170, 100), opt("Body"))
	T.blob(ctx, "Cream", V3(0.9, 0.45, 0.5), CF(0.1, 1.3, -1.9), WHITE, opt("Body"))
	T.blob(ctx, "Cherry", V3(0.28, 0.28, 0.28), CF(0.1, 1.55, -1.92), Color3.fromRGB(220, 50, 70), opt("Body", { Minor = true }))
end

-- Swept-up, tall ginger quiff.
Characters.quiff = function(ctx, spec)
	local color = spec.HairColor or Color3.fromRGB(214, 120, 62)
	T.blob(ctx, "QuiffBase", V3(2.2, 0.7, 1.9), CF(0, 3.3, -0.7), color, opt("Head"))
	T.blob(ctx, "Quiff", V3(1.5, 1.2, 1.6), CF(0, 3.85, -1.1) * ANG(rad(-22), 0, 0), T.shade(color, 1.08), opt("Head"))
	T.blob(ctx, "QuiffTip", V3(0.9, 0.7, 0.9), CF(0, 4.15, -1.55) * ANG(rad(-35), 0, 0), T.shade(color, 1.15), opt("Head", { Minor = true }))
end

-- Long coat with a belt and popped collar.
Characters.trench_coat = function(ctx, spec)
	local color = spec.hatColor or Color3.fromRGB(190, 160, 110)
	T.blob(ctx, "Coat", V3(2.95, 1.9, 2.85), CF(0, 1.05, 0.3), color, opt("Body", { Material = Enum.Material.Fabric }))
	T.blob(ctx, "CoatTail", V3(2.6, 0.8, 2.5), CF(0, 0.55, 0.45), T.shade(color, 0.92), opt("Body", { Material = Enum.Material.Fabric }))
	T.block(ctx, "Belt", V3(2.7, 0.2, 2.5), CF(0, 1.05, 0.3), T.shade(color, 0.6), opt("Body", { Minor = true }))
	T.both(function(side)
		T.block(ctx, "Collar", V3(0.6, 0.7, 0.25), CF(side * 0.55, 1.85, -1.3) * ANG(0, rad(side * -20), rad(side * 18)), T.shade(color, 1.1), opt("Body"))
	end)
end

-- Handheld microphone.
Characters.held_microphone = function(ctx, spec)
	T.rod(ctx, "Handle", 0.3, 1.2, CF(0.6, 1.35, -1.55) * ANG(rad(-25), 0, rad(-10)), Color3.fromRGB(70, 74, 90), opt("Body", { Material = METAL }))
	T.blob(ctx, "Head", V3(0.62, 0.62, 0.62), CF(0.72, 2.0, -1.75), Color3.fromRGB(190, 196, 210), opt("Body", { Material = METAL }))
	T.block(ctx, "Grille", V3(0.64, 0.1, 0.64), CF(0.72, 1.98, -1.75), Color3.fromRGB(60, 62, 76), opt("Body", { Minor = true }))
end

-- Boom microphone that curls from the headphones to the mouth.
Characters.headset_mic = function(ctx, spec)
	T.rod(ctx, "Boom", 0.1, 1.5, CF(-1.25, 2.1, -1.5) * ANG(0, rad(50), rad(70)), Color3.fromRGB(40, 40, 50), opt("Head"))
	T.blob(ctx, "MicTip", V3(0.3, 0.3, 0.3), CF(-0.55, 2.0, -1.9), Color3.fromRGB(40, 40, 50), opt("Head"))
end

-- A glossy highlight on a shiny bald head.
Characters.bald_shine = function(ctx, spec)
	T.blob(ctx, "Shine", V3(0.7, 0.3, 0.5), CF(-0.5, 3.3, -1.0) * ANG(0, rad(20), rad(15)), WHITE, opt("Head", { Transparency = 0.35, Minor = true }))
end

return Characters
