--[[
	Variants for the parts that make each hamster look different: eyes, mouths, ears, tails and fur patterns.
	Each variant is a function(ctx, spec). Species pick variants by id in HamsterDatabase.
]]

local Toolkit = require(script.Parent.Toolkit)

local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local V3 = Vector3.new

local Faces = {}

local BLACK = Color3.fromRGB(28, 22, 30)
local WHITE = Color3.new(1, 1, 1)

local EYE_Y = 2.5
local EYE_X = 0.62
local EYE_Z = -1.66

---------------------------------------------------------------------------
-- eyes
---------------------------------------------------------------------------

local function eyePos(side: number, dx: number?, dy: number?, dz: number?): CFrame
	return CF(side * EYE_X + (dx or 0) * side, EYE_Y + (dy or 0), EYE_Z + (dz or 0))
end

Faces.Eyes = {} :: { [string]: (Toolkit.Ctx, any) -> () }

Faces.Eyes.dot = function(ctx, spec)
	Toolkit.both(function(side)
		Toolkit.blob(ctx, "Eye", V3(0.36, 0.46, 0.3), eyePos(side), BLACK, { Attach = "Head" })
		Toolkit.blob(ctx, "EyeShine", V3(0.12, 0.12, 0.08), eyePos(side, -0.06, 0.1, -0.13), WHITE, { Attach = "Head", Minor = true })
	end)
end

Faces.Eyes.big = function(ctx, spec)
	Toolkit.both(function(side)
		Toolkit.blob(ctx, "Eye", V3(0.62, 0.78, 0.32), eyePos(side), BLACK, { Attach = "Head" })
		Toolkit.blob(ctx, "Iris", V3(0.42, 0.52, 0.2), eyePos(side, 0, -0.04, -0.1), Toolkit.shade(spec.eyeColor or Color3.fromRGB(110, 70, 50), 1), { Attach = "Head", Minor = true })
		Toolkit.blob(ctx, "EyeShine", V3(0.24, 0.24, 0.1), eyePos(side, -0.1, 0.18, -0.16), WHITE, { Attach = "Head" })
		Toolkit.blob(ctx, "EyeShine2", V3(0.11, 0.11, 0.08), eyePos(side, 0.1, -0.12, -0.16), WHITE, { Attach = "Head", Minor = true })
	end)
end

Faces.Eyes.sparkle = function(ctx, spec)
	local iris = spec.eyeColor or Color3.fromRGB(120, 190, 255)
	Toolkit.both(function(side)
		Toolkit.blob(ctx, "Eye", V3(0.68, 0.84, 0.32), eyePos(side), BLACK, { Attach = "Head" })
		Toolkit.blob(ctx, "Iris", V3(0.5, 0.64, 0.2), eyePos(side, 0, -0.04, -0.1), iris, { Attach = "Head", Material = Enum.Material.Neon })
		Toolkit.blob(ctx, "EyeShine", V3(0.26, 0.26, 0.1), eyePos(side, -0.12, 0.2, -0.18), WHITE, { Attach = "Head" })
		Toolkit.blob(ctx, "EyeShine2", V3(0.14, 0.14, 0.08), eyePos(side, 0.12, -0.15, -0.18), WHITE, { Attach = "Head" })
		Toolkit.blob(ctx, "EyeShine3", V3(0.09, 0.09, 0.08), eyePos(side, 0.08, 0.22, -0.18), WHITE, { Attach = "Head", Minor = true })
	end)
end

Faces.Eyes.sleepy = function(ctx, spec)
	Toolkit.both(function(side)
		Toolkit.block(ctx, "EyeLine", V3(0.6, 0.1, 0.2), eyePos(side, 0, -0.04) * ANG(0, 0, rad(side * -10)), BLACK, { Attach = "Head" })
		Toolkit.block(ctx, "Lash", V3(0.14, 0.12, 0.16), eyePos(side, 0.3, -0.1) * ANG(0, 0, rad(side * 30)), BLACK, { Attach = "Head", Minor = true })
	end)
end

Faces.Eyes.happy = function(ctx, spec)
	Toolkit.both(function(side)
		Toolkit.block(ctx, "EyeArcA", V3(0.34, 0.1, 0.2), eyePos(side, 0.16, 0.04) * ANG(0, 0, rad(side * -38)), BLACK, { Attach = "Head" })
		Toolkit.block(ctx, "EyeArcB", V3(0.34, 0.1, 0.2), eyePos(side, -0.16, 0.04) * ANG(0, 0, rad(side * 38)), BLACK, { Attach = "Head" })
	end)
end

Faces.Eyes.wink = function(ctx, spec)
	Faces.Eyes.big(ctx, spec)
	-- replace the right eye by a wink arc
	for _, part in ctx.Model:GetChildren() do
		if part:IsA("BasePart") and part.CFrame.Position.X > 0.3 and (part.Name == "Eye" or part.Name == "Iris" or part.Name == "EyeShine" or part.Name == "EyeShine2") then
			part:Destroy()
		end
	end
	Toolkit.block(ctx, "WinkA", V3(0.34, 0.1, 0.2), eyePos(1, 0.16, 0.04) * ANG(0, 0, rad(-38)), BLACK, { Attach = "Head" })
	Toolkit.block(ctx, "WinkB", V3(0.34, 0.1, 0.2), eyePos(1, -0.16, 0.04) * ANG(0, 0, rad(38)), BLACK, { Attach = "Head" })
end

Faces.Eyes.angry = function(ctx, spec)
	Faces.Eyes.dot(ctx, spec)
	Toolkit.both(function(side)
		Toolkit.block(ctx, "Brow", V3(0.62, 0.14, 0.2), eyePos(side, 0, 0.42) * ANG(0, 0, rad(side * 22)), BLACK, { Attach = "Head" })
	end)
end

Faces.Eyes.tear = function(ctx, spec)
	Faces.Eyes.big(ctx, spec)
	Toolkit.blob(ctx, "Tear", V3(0.16, 0.26, 0.12), eyePos(-1, 0, -0.55, -0.1), Color3.fromRGB(140, 200, 255), { Attach = "Head", Transparency = 0.2, Minor = true })
end

Faces.Eyes.star = function(ctx, spec)
	Toolkit.both(function(side)
		Toolkit.blob(ctx, "EyeBack", V3(0.62, 0.7, 0.2), eyePos(side), BLACK, { Attach = "Head" })
		Toolkit.star(ctx, "EyeStar", 0.62, eyePos(side, 0, 0, -0.14), Color3.fromRGB(255, 230, 110), { Attach = "Head" })
	end)
end

Faces.Eyes.heart = function(ctx, spec)
	Toolkit.both(function(side)
		local color = Color3.fromRGB(255, 90, 140)
		Toolkit.blob(ctx, "HeartL", V3(0.3, 0.3, 0.2), eyePos(side, -0.1, 0.1), color, { Attach = "Head", Material = Enum.Material.Neon })
		Toolkit.blob(ctx, "HeartR", V3(0.3, 0.3, 0.2), eyePos(side, 0.1, 0.1), color, { Attach = "Head", Material = Enum.Material.Neon })
		Toolkit.block(ctx, "HeartTip", V3(0.3, 0.3, 0.2), eyePos(side, 0, -0.04) * ANG(0, 0, rad(45)), color, { Attach = "Head", Material = Enum.Material.Neon })
	end)
end

Faces.Eyes.glow = function(ctx, spec)
	local color = spec.eyeColor or ctx.Accent
	Toolkit.both(function(side)
		Toolkit.blob(ctx, "Eye", V3(0.5, 0.62, 0.3), eyePos(side), color, { Attach = "Head", Material = Enum.Material.Neon })
		Toolkit.blob(ctx, "Pupil", V3(0.16, 0.4, 0.16), eyePos(side, 0, 0, -0.1), BLACK, { Attach = "Head" })
	end)
end

Faces.Eyes.cat = function(ctx, spec)
	local color = spec.eyeColor or Color3.fromRGB(255, 220, 90)
	Toolkit.both(function(side)
		Toolkit.blob(ctx, "Eye", V3(0.56, 0.7, 0.3), eyePos(side), color, { Attach = "Head" })
		Toolkit.blob(ctx, "Slit", V3(0.12, 0.56, 0.12), eyePos(side, 0, 0, -0.1), BLACK, { Attach = "Head" })
		Toolkit.blob(ctx, "EyeShine", V3(0.14, 0.14, 0.08), eyePos(side, -0.12, 0.16, -0.14), WHITE, { Attach = "Head", Minor = true })
	end)
end

Faces.Eyes.void = function(ctx, spec)
	Toolkit.both(function(side)
		Toolkit.blob(ctx, "Eye", V3(0.62, 0.34, 0.3), eyePos(side) * ANG(0, 0, rad(side * -14)), WHITE, { Attach = "Head", Material = Enum.Material.Neon })
	end)
end

Faces.Eyes.crystal = function(ctx, spec)
	local color = spec.eyeColor or ctx.Accent
	Toolkit.both(function(side)
		Toolkit.gem(ctx, "Eye", V3(0.36, 0.36, 0.2), eyePos(side), color, { Attach = "Head" })
	end)
end

---------------------------------------------------------------------------
-- mouths (nose is always built)
---------------------------------------------------------------------------

Faces.Mouths = {} :: { [string]: (Toolkit.Ctx, any) -> () }

Faces.Mouths.smile = function(ctx, spec)
	Toolkit.both(function(side)
		Toolkit.block(ctx, "Smile", V3(0.26, 0.07, 0.12), CF(side * 0.13, 1.94, -1.82) * ANG(0, 0, rad(side * -25)), BLACK, { Attach = "Head" })
	end)
end

Faces.Mouths.open = function(ctx, spec)
	Toolkit.blob(ctx, "Mouth", V3(0.5, 0.42, 0.2), CF(0, 1.9, -1.8), Color3.fromRGB(110, 40, 60), { Attach = "Head" })
	Toolkit.blob(ctx, "Tongue", V3(0.3, 0.2, 0.12), CF(0, 1.8, -1.86), Color3.fromRGB(255, 130, 150), { Attach = "Head", Minor = true })
end

Faces.Mouths.cat = function(ctx, spec)
	Toolkit.both(function(side)
		Toolkit.block(ctx, "CatMouth", V3(0.26, 0.07, 0.12), CF(side * 0.14, 1.93, -1.82) * ANG(0, 0, rad(side * -35)), BLACK, { Attach = "Head" })
	end)
	Toolkit.block(ctx, "CatLip", V3(0.07, 0.2, 0.12), CF(0, 2.02, -1.84), BLACK, { Attach = "Head", Minor = true })
end

Faces.Mouths.fang = function(ctx, spec)
	Faces.Mouths.smile(ctx, spec)
	Toolkit.both(function(side)
		Toolkit.block(ctx, "Fang", V3(0.1, 0.22, 0.1), CF(side * 0.24, 1.82, -1.84), WHITE, { Attach = "Head" })
	end)
end

Faces.Mouths.grin = function(ctx, spec)
	Toolkit.block(ctx, "Grin", V3(0.9, 0.2, 0.14), CF(0, 1.9, -1.8), Color3.fromRGB(110, 40, 60), { Attach = "Head" })
	Toolkit.block(ctx, "Teeth", V3(0.8, 0.09, 0.1), CF(0, 1.98, -1.86), WHITE, { Attach = "Head" })
end

Faces.Mouths.tongue = function(ctx, spec)
	Faces.Mouths.smile(ctx, spec)
	Toolkit.blob(ctx, "Tongue", V3(0.26, 0.3, 0.1), CF(0.12, 1.78, -1.82), Color3.fromRGB(255, 120, 150), { Attach = "Head" })
end

Faces.Mouths.oh = function(ctx, spec)
	Toolkit.blob(ctx, "Mouth", V3(0.26, 0.3, 0.14), CF(0, 1.86, -1.8), Color3.fromRGB(90, 30, 50), { Attach = "Head" })
end

Faces.Mouths.flat = function(ctx, spec)
	Toolkit.block(ctx, "Mouth", V3(0.34, 0.07, 0.12), CF(0, 1.9, -1.82), BLACK, { Attach = "Head" })
end

Faces.Mouths.none = function() end

---------------------------------------------------------------------------
-- ears (articulated: EarLJ / EarRJ on the head)
---------------------------------------------------------------------------

Faces.Ears = {} :: { [string]: (Toolkit.Ctx, any) -> () }

local function simpleEar(width: number, height: number, tilt: number, x: number, y: number, z: number, innerScale: number?)
	return function(ctx: Toolkit.Ctx, spec: any)
		local color = spec.earColor or ctx.Fur
		local inner = spec.earInner or Color3.fromRGB(255, 176, 190)
		Toolkit.both(function(side)
			local name = if side < 0 then "EarL" else "EarR"
			local cframe = CF(side * x, y, z) * ANG(0, 0, rad(-side * tilt))
			local ear = Toolkit.make(ctx, name, V3(width, height, 0.38), cframe, color, { NoWeld = true, Mesh = Enum.MeshType.Sphere })
			assert(ear)
			ctx.Parts[name] = ear
			Toolkit.joint(ctx, name .. "J", ctx.Parts.Head, ear, V3(side * x, y - height * 0.4, z))
			local scale = innerScale or 0.6
			Toolkit.blob(ctx, name .. "Inner", V3(width * scale, height * scale, 0.3), cframe * CF(0, -height * 0.04, -0.1), inner, { Attach = name, Minor = true })
		end)
	end
end

Faces.Ears.round = simpleEar(0.95, 0.95, 12, 0.95, 3.2, -0.55)
Faces.Ears.bear = simpleEar(1.15, 1.1, 8, 1.0, 3.25, -0.5, 0.55)
Faces.Ears.tiny = simpleEar(0.6, 0.6, 10, 1.0, 3.1, -0.5)
Faces.Ears.big = simpleEar(1.5, 1.6, 15, 1.1, 3.35, -0.5)
Faces.Ears.cat = simpleEar(0.95, 1.55, 20, 0.95, 3.5, -0.5, 0.55)
Faces.Ears.bunny = simpleEar(0.8, 2.7, 10, 0.55, 4.5, -0.5, 0.65)
Faces.Ears.floppy = simpleEar(0.9, 1.9, -62, 1.5, 2.9, -0.55, 0.55)
Faces.Ears.elf = simpleEar(1.9, 0.6, -28, 1.7, 3.0, -0.5, 0.55)
Faces.Ears.fluffy = simpleEar(1.3, 1.3, 10, 1.0, 3.25, -0.5, 0.7)

Faces.Ears.none = function() end

---------------------------------------------------------------------------
-- tails (articulated TailJ)
---------------------------------------------------------------------------

Faces.Tails = {} :: { [string]: (Toolkit.Ctx, any) -> () }

local function tail(size: Vector3, offset: Vector3)
	return function(ctx: Toolkit.Ctx, spec: any)
		local color = spec.tailColor or ctx.Fur
		local part = Toolkit.make(ctx, "Tail", size, CF(offset), color, { NoWeld = true, Mesh = Enum.MeshType.Sphere })
		assert(part)
		Toolkit.joint(ctx, "TailJ", ctx.Parts.Body, part, V3(0, 1.0, 1.45))
		ctx.Parts.Tail = part
	end
end

Faces.Tails.nub = tail(V3(0.6, 0.6, 0.6), V3(0, 1.0, 1.75))
Faces.Tails.fluffy = tail(V3(1.4, 1.6, 1.4), V3(0, 1.5, 1.95))
Faces.Tails.long = tail(V3(0.3, 0.3, 1.7), V3(0, 0.9, 2.3))
Faces.Tails.curl = tail(V3(0.7, 1.6, 0.7), V3(0, 1.9, 2.0))
Faces.Tails.none = function() end

---------------------------------------------------------------------------
-- fur patterns (use spec.color2)
---------------------------------------------------------------------------

Faces.Patterns = {} :: { [string]: (Toolkit.Ctx, any) -> () }

Faces.Patterns.none = function() end

Faces.Patterns.spots = function(ctx, spec)
	local c = ctx.Color2
	Toolkit.blob(ctx, "Spot", V3(0.9, 0.35, 0.8), CF(-0.75, 2.3, 0.3), c, { Attach = "Body" })
	Toolkit.blob(ctx, "Spot", V3(0.7, 0.3, 0.7), CF(0.6, 2.35, 0.95), c, { Attach = "Body" })
	Toolkit.blob(ctx, "Spot", V3(0.6, 0.3, 0.6), CF(0.2, 2.25, -0.15), c, { Attach = "Body", Minor = true })
	Toolkit.blob(ctx, "Spot", V3(0.6, 0.25, 0.6), CF(0.7, 3.2, -0.7), c, { Attach = "Head" })
end

Faces.Patterns.stripes = function(ctx, spec)
	local c = ctx.Color2
	for index = 0, 2 do
		Toolkit.blob(ctx, "Stripe", V3(2.3 - index * 0.2, 0.26, 0.38), CF(0, 2.28 - index * 0.04, -0.15 + index * 0.65), c, { Attach = "Body" })
	end
	Toolkit.blob(ctx, "Stripe", V3(0.38, 0.26, 1.1), CF(0, 3.34, -0.7), c, { Attach = "Head" })
end

Faces.Patterns.mask = function(ctx, spec)
	local c = ctx.Color2
	Toolkit.both(function(side)
		Toolkit.blob(ctx, "Patch", V3(1, 0.95, 0.25), CF(side * EYE_X, EYE_Y - 0.05, -1.58) * ANG(0, 0, rad(side * -20)), c, { Attach = "Head" })
	end)
end

Faces.Patterns.saddle = function(ctx, spec)
	Toolkit.blob(ctx, "Saddle", V3(2.1, 0.7, 2), CF(0, 2.15, 0.7), ctx.Color2, { Attach = "Body" })
end

Faces.Patterns.cap = function(ctx, spec)
	Toolkit.blob(ctx, "FurCap", V3(2.45, 1.2, 2.1), CF(0, 3.0, -0.6), ctx.Color2, { Attach = "Head" })
end

Faces.Patterns.blaze = function(ctx, spec)
	Toolkit.blob(ctx, "Blaze", V3(0.45, 1.3, 0.2), CF(0, 2.95, -1.55), ctx.Color2, { Attach = "Head" })
end

Faces.Patterns.socks = function(ctx, spec)
	-- handled when the paws are created (see HamsterBuilder)
end

Faces.Patterns.panda = function(ctx, spec)
	Faces.Patterns.mask(ctx, spec)
	Toolkit.blob(ctx, "PandaBelt", V3(2.75, 0.8, 2.3), CF(0, 1.9, -0.1), ctx.Color2, { Attach = "Body" })
end

Faces.Patterns.tiger = function(ctx, spec)
	local c = ctx.Color2
	for index = 0, 3 do
		Toolkit.blob(ctx, "TigerStripe", V3(0.3, 1.1, 2.7 - index * 0.3), CF(-1.3, 1.5 + index * 0.1, 0.2 + index * 0.1), c, { Attach = "Body", Minor = index > 1 })
		Toolkit.blob(ctx, "TigerStripe", V3(0.3, 1.1, 2.7 - index * 0.3), CF(1.3, 1.5 + index * 0.1, 0.2 + index * 0.1), c, { Attach = "Body", Minor = index > 1 })
	end
end

Faces.Patterns.freckles = function(ctx, spec)
	for index = 1, 5 do
		local side = if index % 2 == 0 then 1 else -1
		Toolkit.blob(ctx, "Freckle", V3(0.12, 0.12, 0.08), CF(side * (0.7 + index * 0.06), 2.12 + (index % 3) * 0.06, -1.68), ctx.Color2, { Attach = "Head", Minor = true })
	end
end

return Faces
