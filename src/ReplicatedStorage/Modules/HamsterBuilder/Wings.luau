--[[
	Wings (animated WingLJ / WingRJ joints), special tails (TailJ) and magical orbiting effects.
	Wing styles share one generator but produce clearly different silhouettes.
]]

local Toolkit = require(script.Parent.Toolkit)

local T = Toolkit
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local V3 = Vector3.new
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal

local Wings = {} :: { [string]: (Toolkit.Ctx, any) -> () }

local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 210, 80)

---------------------------------------------------------------------------
-- wings
---------------------------------------------------------------------------

type WingStyle = {
	Kind: string, -- feather | membrane | fairy | butterfly | stars | mecha | crystal | bands
	Main: Color3,
	Tip: Color3?,
	Edge: Color3?,
	Span: number?,
	Height: number?,
	Count: number?,
	Material: Enum.Material?,
	Transparency: number?,
	Emitter: string?,
	Sweep: number?,
}

local function buildWings(ctx: Toolkit.Ctx, style: WingStyle)
	local span = style.Span or 2.6
	local height = style.Height or 2.4
	local count = style.Count or 5
	local tip = style.Tip or style.Main
	local edge = style.Edge or tip

	T.both(function(side)
		local name = if side < 0 then "WingL" else "WingR"
		local pivot = V3(side * 0.7, 2.1, 1.25)
		-- wing frame: x grows outward, the wing is swept back by `Sweep` degrees
		local frame = CF(pivot) * ANG(0, side * rad(-(style.Sweep or 24)), 0)
		local function at(dx: number, dy: number, dz: number?): CFrame
			return frame * CF(side * dx, dy, dz or 0)
		end

		local mainOptions: any = { NoWeld = true, Mesh = Enum.MeshType.Sphere, Material = style.Material, Transparency = style.Transparency }
		local main
		if style.Kind == "mecha" then
			mainOptions.Mesh = nil
			main = T.make(ctx, name, V3(span * 0.9, height * 0.35, 0.18), at(span * 0.45, height * 0.3), style.Main, mainOptions)
		elseif style.Kind == "crystal" then
			mainOptions.Mesh = nil
			main = T.make(ctx, name, V3(0.5, height * 0.9, 0.3), at(0.5, height * 0.4) * ANG(0, 0, rad(side * -10)), style.Main, mainOptions)
		else
			main = T.make(ctx, name, V3(span, height * (if style.Kind == "bands" then 0.5 else 0.8), 0.14), at(span * 0.5, height * 0.25), style.Main, mainOptions)
		end
		assert(main)
		ctx.Parts[name] = main
		T.joint(ctx, name .. "J", ctx.Parts.Body, main, pivot)

		local function piece(kind: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material?, transparency: number?, minor: boolean?): Part?
			local options: any = { Attach = name, Material = material or style.Material, Transparency = transparency, Minor = minor }
			if kind == "blob" then
				return T.blob(ctx, name .. "Part", size, cframe, color, options)
			end
			return T.block(ctx, name .. "Part", size, cframe, color, options)
		end

		if style.Kind == "feather" then
			for index = 1, count do
				local t = index / count
				piece("blob", V3(0.55, height * (0.95 - t * 0.45), 0.12), at(span * (0.15 + t * 0.85), height * 0.05 - t * 0.35) * ANG(0, 0, rad(side * (-8 - t * 45))), if index % 2 == 0 then tip else style.Main, style.Material, style.Transparency)
			end
		elseif style.Kind == "membrane" then
			for index = 1, 3 do
				local t = index / 3
				T.rod(ctx, name .. "Bone", 0.13, height * 1.05, ctx.Parts[name].CFrame * CF(side * (-span * 0.4 + t * span * 0.85), 0.05, -0.1) * ANG(0, 0, rad(side * (6 - t * 12))), edge, { Attach = name, Material = METAL })
			end
			piece("blob", V3(0.25, 0.7, 0.2), at(0.2, height * 0.62), edge, METAL, nil, false)
			piece("blob", V3(span * 0.9, height * 0.4, 0.1), at(span * 0.5, -height * 0.2), tip, style.Material, style.Transparency)
		elseif style.Kind == "fairy" then
			piece("blob", V3(span * 0.7, height * 0.6, 0.1), at(span * 0.35, -height * 0.25) * ANG(0, 0, rad(side * -25)), tip, NEON, 0.5)
			piece("blob", V3(span * 0.45, height * 0.35, 0.08), at(span * 0.6, height * 0.45), edge, NEON, 0.6, true)
		elseif style.Kind == "butterfly" then
			piece("blob", V3(span * 0.7, height * 0.65, 0.12), at(span * 0.4, -height * 0.32) * ANG(0, 0, rad(side * -20)), tip, nil, nil)
			for index, offset in { V3(0.9, 0.65, 0), V3(1.6, 0.2, 0), V3(1.2, -0.55, 0) } do
				piece("blob", V3(0.45, 0.45, 0.16), at(offset.X, offset.Y), WHITE, nil, nil, index > 2)
			end
			piece("blob", V3(0.35, 0.35, 0.16), at(1.0, -0.9), edge, NEON, nil, true)
		elseif style.Kind == "stars" then
			for index = 1, 7 do
				local dx = 0.4 + (index * 0.83) % (span * 0.85)
				local dy = ((index * 1.37) % height) - height * 0.1
				piece("blob", V3(0.2, 0.2, 0.18), at(dx, dy), WHITE, NEON, nil, index > 4)
			end
			piece("blob", V3(span * 1.05, height * 0.9, 0.1), at(span * 0.5, height * 0.25), edge, NEON, 0.65)
		elseif style.Kind == "mecha" then
			for index = 1, count do
				local t = index / count
				piece("block", V3(0.45, height * (0.95 - t * 0.5), 0.14), at(span * (0.2 + t * 0.8), -t * 0.3) * ANG(0, 0, rad(side * (-6 - t * 40))), if index % 2 == 0 then tip else style.Main, METAL, nil)
				piece("block", V3(0.1, height * (0.8 - t * 0.5), 0.18), at(span * (0.2 + t * 0.8), -t * 0.3) * ANG(0, 0, rad(side * (-6 - t * 40))), edge, NEON, nil, true)
			end
		elseif style.Kind == "crystal" then
			for index = 1, count do
				local t = index / count
				T.crystal(ctx, name .. "Shard", 0.4, height * (1 - t * 0.5), ctx.Parts[name].CFrame * CF(side * t * span * 0.9, -t * 0.4, 0) * ANG(0, 0, rad(side * (-10 - t * 45))), if index % 2 == 0 then tip else style.Main, { Attach = name })
			end
		elseif style.Kind == "bands" then
			local colors = { style.Main, tip, edge, T.shade(tip, 1.1) }
			for index, color in colors do
				piece("blob", V3(span * (1 - index * 0.12), height * 0.38, 0.1), at(span * 0.5, height * 0.28 - index * 0.38) * ANG(0, 0, rad(side * -index * 6)), color, NEON, 0.35 + index * 0.08)
			end
		end

		if style.Emitter then
			T.emitter(ctx, style.Emitter, edge, name)
		end
	end)
end

Wings.wings_angel = function(ctx, spec)
	buildWings(ctx, { Kind = "feather", Main = Color3.fromRGB(252, 250, 255), Tip = Color3.fromRGB(235, 240, 255), Count = 6, Span = 2.8, Height = 2.6 })
end
Wings.wings_seraph = function(ctx, spec)
	buildWings(ctx, { Kind = "feather", Main = WHITE, Tip = Color3.fromRGB(255, 240, 190), Count = 8, Span = 3.6, Height = 3.4, Material = NEON, Transparency = 0.1 })
end
Wings.wings_bat = function(ctx, spec)
	buildWings(ctx, { Kind = "membrane", Main = Color3.fromRGB(90, 30, 70), Tip = Color3.fromRGB(150, 40, 80), Edge = Color3.fromRGB(60, 25, 55), Span = 3.2, Height = 2.4, Sweep = 32 })
end
Wings.wings_dragon = function(ctx, spec)
	buildWings(ctx, { Kind = "membrane", Main = Color3.fromRGB(70, 150, 80), Tip = Color3.fromRGB(110, 190, 90), Edge = Color3.fromRGB(190, 80, 60), Span = 3.6, Height = 2.8, Sweep = 28 })
end
Wings.wings_fairy = function(ctx, spec)
	buildWings(ctx, { Kind = "fairy", Main = Color3.fromRGB(190, 240, 255), Tip = Color3.fromRGB(255, 190, 240), Edge = Color3.fromRGB(190, 255, 220), Span = 2.4, Height = 2.6, Transparency = 0.45, Material = NEON, Emitter = "sparkle" })
end
Wings.wings_butterfly = function(ctx, spec)
	buildWings(ctx, { Kind = "butterfly", Main = spec.hatColor or Color3.fromRGB(255, 150, 60), Tip = Color3.fromRGB(255, 200, 80), Edge = Color3.fromRGB(80, 40, 30), Span = 2.9, Height = 2.7 })
end
Wings.wings_cosmic = function(ctx, spec)
	buildWings(ctx, { Kind = "stars", Main = Color3.fromRGB(30, 30, 90), Tip = Color3.fromRGB(90, 70, 200), Edge = Color3.fromRGB(110, 140, 255), Span = 3.2, Height = 3, Transparency = 0.25, Emitter = "stars" })
end
Wings.wings_golden = function(ctx, spec)
	buildWings(ctx, { Kind = "feather", Main = GOLD, Tip = Color3.fromRGB(255, 240, 160), Count = 6, Span = 3, Height = 2.7, Material = METAL })
end
Wings.wings_mecha = function(ctx, spec)
	buildWings(ctx, { Kind = "mecha", Main = Color3.fromRGB(150, 160, 180), Tip = Color3.fromRGB(100, 110, 130), Edge = ctx.Accent, Count = 5, Span = 3.2, Height = 2.6 })
end
Wings.wings_bee = function(ctx, spec)
	buildWings(ctx, { Kind = "fairy", Main = Color3.fromRGB(230, 245, 255), Tip = Color3.fromRGB(220, 235, 255), Edge = WHITE, Span = 1.7, Height = 1.5, Transparency = 0.55, Sweep = 18 })
end
Wings.wings_ice = function(ctx, spec)
	buildWings(ctx, { Kind = "crystal", Main = Color3.fromRGB(170, 230, 255), Tip = Color3.fromRGB(220, 250, 255), Count = 5, Span = 3, Height = 2.6 })
end
Wings.wings_flame = function(ctx, spec)
	buildWings(ctx, { Kind = "feather", Main = Color3.fromRGB(255, 120, 40), Tip = Color3.fromRGB(255, 210, 80), Count = 6, Span = 3, Height = 2.8, Material = NEON, Emitter = "flame" })
end
Wings.wings_aurora = function(ctx, spec)
	buildWings(ctx, { Kind = "bands", Main = Color3.fromRGB(90, 255, 170), Tip = Color3.fromRGB(110, 190, 255), Edge = Color3.fromRGB(200, 120, 255), Span = 3.4, Height = 3.2, Emitter = "sparkle" })
end
Wings.wings_void = function(ctx, spec)
	buildWings(ctx, { Kind = "stars", Main = Color3.fromRGB(25, 8, 40), Tip = Color3.fromRGB(60, 20, 90), Edge = Color3.fromRGB(190, 80, 255), Span = 3.4, Height = 3.2, Transparency = 0.2, Emitter = "glitch" })
end
Wings.wings_leaf = function(ctx, spec)
	buildWings(ctx, { Kind = "fairy", Main = Color3.fromRGB(130, 210, 110), Tip = Color3.fromRGB(180, 235, 130), Edge = Color3.fromRGB(100, 170, 90), Span = 2.2, Height = 2.2, Transparency = 0.15, Material = Enum.Material.Grass })
end

---------------------------------------------------------------------------
-- special tails (replace the default nub: use tail = "none" in the species)
---------------------------------------------------------------------------

local function tailBase(ctx: Toolkit.Ctx, size: Vector3, offset: Vector3, color: Color3, material: Enum.Material?): Part
	local part = T.make(ctx, "Tail", size, CF(offset), color, { NoWeld = true, Mesh = Enum.MeshType.Sphere, Material = material })
	assert(part)
	ctx.Parts.Tail = part
	T.joint(ctx, "TailJ", ctx.Parts.Body, part, V3(0, 1.0, 1.45))
	return part
end

local function onTail(extra: { [string]: any }?): any
	local options: any = { Attach = "Tail" }
	if extra then
		for key, value in extra do
			options[key] = value
		end
	end
	return options
end

Wings.tail_fluffy = function(ctx, spec)
	tailBase(ctx, V3(1.5, 1.7, 1.5), V3(0, 1.5, 2.0), spec.tailColor or ctx.Fur)
	T.blob(ctx, "TailTip", V3(0.9, 0.9, 0.9), CF(0, 2.2, 2.2), spec.tailTip or ctx.Belly, onTail())
end
Wings.tail_squirrel = function(ctx, spec)
	tailBase(ctx, V3(1.2, 2.2, 1.2), V3(0, 1.9, 2.0), spec.tailColor or ctx.Fur)
	T.blob(ctx, "TailCurl", V3(1.4, 1.4, 1.4), CF(0, 3.2, 1.6), spec.tailColor or ctx.Fur, onTail())
	T.blob(ctx, "TailStripe", V3(1.45, 0.3, 1.45), CF(0, 3.2, 1.6), spec.tailTip or ctx.Color2, onTail({ Minor = true }))
end
Wings.tail_fish = function(ctx, spec)
	local color = spec.tailColor or Color3.fromRGB(90, 190, 220)
	tailBase(ctx, V3(0.9, 1.0, 1.8), V3(0, 1.1, 2.2), color)
	T.blob(ctx, "FinTop", V3(0.2, 1.6, 1.2), CF(0, 1.5, 3.3) * ANG(rad(-25), 0, 0), T.shade(color, 1.2), onTail())
	T.blob(ctx, "FinBottom", V3(0.2, 1.6, 1.2), CF(0, 0.6, 3.3) * ANG(rad(25), 0, 0), T.shade(color, 1.2), onTail())
end
Wings.tail_lightning = function(ctx, spec)
	local yellow = Color3.fromRGB(255, 230, 80)
	tailBase(ctx, V3(0.5, 0.5, 0.5), V3(0, 1.0, 1.7), yellow, NEON)
	T.block(ctx, "Bolt1", V3(0.35, 1.0, 0.25), CF(0, 1.5, 2.0) * ANG(0, 0, rad(25)), yellow, onTail({ Material = NEON }))
	T.block(ctx, "Bolt2", V3(0.35, 1.0, 0.25), CF(0.3, 2.3, 2.1) * ANG(0, 0, rad(-25)), yellow, onTail({ Material = NEON }))
	T.block(ctx, "Bolt3", V3(0.45, 1.2, 0.25), CF(0.1, 3.2, 2.2) * ANG(0, 0, rad(25)), yellow, onTail({ Material = NEON }))
end
Wings.tail_flame = function(ctx, spec)
	tailBase(ctx, V3(0.9, 1.2, 0.9), V3(0, 1.4, 1.9), Color3.fromRGB(255, 130, 50), NEON)
	T.blob(ctx, "FlameTip", V3(0.7, 1.4, 0.7), CF(0, 2.5, 2.0), Color3.fromRGB(255, 210, 90), onTail({ Material = NEON }))
	T.emitter(ctx, "flame", Color3.fromRGB(255, 160, 60), "Tail")
end
Wings.tail_star = function(ctx, spec)
	tailBase(ctx, V3(0.4, 0.4, 0.4), V3(0, 1.0, 1.7), ctx.Fur)
	T.star(ctx, "StarTail", 1.4, CF(0, 1.7, 2.2) * ANG(0, math.rad(90), 0), Color3.fromRGB(255, 230, 110), onTail())
end
Wings.tail_nine = function(ctx, spec)
	local color = spec.tailColor or ctx.Fur
	tailBase(ctx, V3(1.1, 1.8, 1.1), V3(0, 1.6, 2.0), color)
	for index = 1, 8 do
		local angle = rad(-70 + (index - 1) * 20)
		T.blob(ctx, "FoxTail", V3(0.9, 1.9, 0.9), CF(math.sin(angle) * 1.9, 1.7 + math.cos(angle) * 0.9, 2.1 + math.abs(angle) * 0.2) * ANG(0, 0, -angle), color, onTail({ Minor = index % 2 == 0 }))
		T.blob(ctx, "FoxTip", V3(0.6, 0.7, 0.6), CF(math.sin(angle) * 2.4, 2.4 + math.cos(angle) * 1.4, 2.1 + math.abs(angle) * 0.2), spec.tailTip or ctx.Accent, onTail({ Minor = index % 2 == 0, Material = NEON }))
	end
end
Wings.tail_dragon = function(ctx, spec)
	local color = spec.tailColor or Color3.fromRGB(80, 160, 90)
	tailBase(ctx, V3(0.9, 0.9, 1.6), V3(0, 1.0, 2.1), color)
	T.blob(ctx, "TailMid", V3(0.7, 0.7, 1.4), CF(0, 1.1, 3.2), color, onTail())
	T.blob(ctx, "TailEnd", V3(0.5, 0.5, 1.1), CF(0, 1.3, 4.1), color, onTail())
	T.blob(ctx, "Spade", V3(0.3, 1.0, 0.9), CF(0, 1.5, 4.8), Color3.fromRGB(220, 90, 70), onTail())
	for index = 0, 2 do
		T.blob(ctx, "Ridge", V3(0.25, 0.5, 0.4), CF(0, 1.55 + index * 0.05, 2.0 + index * 1.0), Color3.fromRGB(220, 90, 70), onTail({ Minor = true }))
	end
end
Wings.tail_peacock = function(ctx, spec)
	tailBase(ctx, V3(0.5, 0.5, 0.5), V3(0, 1.0, 1.7), ctx.Fur)
	for index = 1, 7 do
		local angle = rad(-60 + (index - 1) * 20)
		T.blob(ctx, "Plume", V3(0.55, 2.4, 0.15), CF(math.sin(angle) * 1.6, 2.8 + math.cos(angle) * 0.3, 2.3) * ANG(0, 0, -angle), Color3.fromHSV(0.4 + index * 0.03, 0.7, 0.9), onTail())
		T.blob(ctx, "PlumeEye", V3(0.3, 0.3, 0.18), CF(math.sin(angle) * 1.9, 3.5 + math.cos(angle) * 0.5, 2.25), Color3.fromRGB(255, 220, 90), onTail({ Material = NEON, Minor = index % 2 == 0 }))
	end
end
Wings.tail_crystal = function(ctx, spec)
	tailBase(ctx, V3(0.5, 0.5, 0.5), V3(0, 1.0, 1.7), ctx.Fur)
	for index = 0, 3 do
		T.crystal(ctx, "TailShard", 0.5, 1.6 - index * 0.2, CF((index - 1.5) * 0.45, 1.8 + math.abs(index - 1.5) * -0.2, 2.1) * ANG(0, 0, rad((index - 1.5) * 18)), ctx.Accent, onTail())
	end
end

---------------------------------------------------------------------------
-- magical effects made of geometry
---------------------------------------------------------------------------

Wings.orbit_orbs = function(ctx, spec)
	for index = 0, 2 do
		local angle = (index / 3) * math.pi * 2 + 0.4
		T.blob(ctx, "Orb", V3(0.55, 0.55, 0.55), CF(math.cos(angle) * 2.3, 2.6 + (index % 2) * 0.5, math.sin(angle) * 2.3), ctx.Accent, { Attach = "Body", Material = NEON })
	end
end
Wings.orbit_stars = function(ctx, spec)
	for index = 0, 3 do
		local angle = (index / 4) * math.pi * 2
		T.star(ctx, "OrbitStar", 0.7, CF(math.cos(angle) * 2.4, 2.8 + (index % 2) * 0.4, math.sin(angle) * 2.4) * ANG(0, -angle + math.pi / 2, 0), Color3.fromRGB(255, 240, 150), { Attach = "Body" })
	end
end
Wings.orbit_shards = function(ctx, spec)
	for index = 0, 4 do
		local angle = (index / 5) * math.pi * 2
		T.gem(ctx, "Shard", V3(0.35, 0.6, 0.35), CF(math.cos(angle) * 2.5, 2.2 + (index % 3) * 0.5, math.sin(angle) * 2.5), ctx.Accent, { Attach = "Body" })
	end
end
Wings.orbit_ring = function(ctx, spec)
	T.plate(ctx, "OrbitRing", 5.0, 0.08, CF(0, 2.0, 0.3) * ANG(rad(12), 0, rad(8)), ctx.Accent, { Attach = "Body", Material = NEON, Transparency = 0.35 })
	T.plate(ctx, "OrbitRing2", 4.2, 0.06, CF(0, 2.0, 0.3) * ANG(rad(-20), 0, rad(-10)), WHITE, { Attach = "Body", Material = NEON, Transparency = 0.5, Minor = true })
end
Wings.ground_glow = function(ctx, spec)
	T.plate(ctx, "GroundGlow", 4.6, 0.06, CF(0, 0.04, 0.2), ctx.Accent, { Attach = "Body", Material = NEON, Transparency = 0.45 })
end
Wings.floating_runes = function(ctx, spec)
	for index = 0, 3 do
		local angle = (index / 4) * math.pi * 2 + 0.5
		T.block(ctx, "Rune", V3(0.5, 0.7, 0.1), CF(math.cos(angle) * 2.5, 2.4 + (index % 2) * 0.6, math.sin(angle) * 2.5) * ANG(0, -angle + math.pi / 2, 0), ctx.Accent, { Attach = "Body", Material = NEON })
	end
end
return Wings
