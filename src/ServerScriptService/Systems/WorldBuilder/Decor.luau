--[[
	Reusable scenery pieces: trees, bushes, flowers, rocks, benches, lamps, signs, fences ...
	Every function creates a Model under `parent` and returns it.
	Coordinates: ground top is Y = 0 (so `pos` is the point on the ground).
]]

local Build = require(script.Parent.Build)
local Palette = require(script.Parent.Palette)

local Decor = {}

local PLASTIC = Enum.Material.SmoothPlastic
local WOOD = Enum.Material.Wood
local GRASS = Enum.Material.Grass

local function at(pos: Vector3, yaw: number?): CFrame
	return CFrame.new(pos) * CFrame.Angles(0, yaw or 0, 0)
end

---------------------------------------------------------------------------
-- Plants
---------------------------------------------------------------------------

function Decor.tree(parent: Instance, pos: Vector3, kind: string, scale: number, rng: Random): Model
	local model = Build.model(parent, "Tree_" .. kind)
	local yaw = rng:NextNumber() * math.pi * 2

	if kind == "pine" then
		local trunkHeight = 5 * scale
		Build.pillar(model, "Trunk", 1.5 * scale, trunkHeight, at(pos + Vector3.new(0, trunkHeight / 2, 0)), Palette.WoodDark, WOOD)
		local layers = { { 8.5, 3.6, 5.4 }, { 6.8, 3.4, 8.2 }, { 4.8, 3.2, 10.8 } }
		for index, layer in layers do
			Build.blob(
				model,
				"Needles" .. index,
				Vector3.new(layer[1], layer[2], layer[1]) * scale,
				at(pos + Vector3.new(0, layer[3] * scale, 0), yaw),
				if index % 2 == 0 then Palette.Pine else Palette.LeafDark,
				GRASS,
				{ CanCollide = false }
			)
		end
	else
		local trunkHeight = 5.5 * scale
		Build.pillar(model, "Trunk", 1.6 * scale, trunkHeight, at(pos + Vector3.new(0, trunkHeight / 2, 0)), Palette.Wood, WOOD)
		local canopyColor = if kind == "cherry" then Palette.Cherry else Palette.Leaf
		local canopyDark = if kind == "cherry" then Color3.fromRGB(246, 144, 178) else Palette.LeafDark
		local top = trunkHeight + 2 * scale
		local blobs = {
			{ Vector3.new(0, top, 0), 8.5, canopyColor },
			{ Vector3.new(2.8, top - 0.8, 1.2), 5.6, canopyDark },
			{ Vector3.new(-2.6, top - 0.6, -1.6), 5.8, canopyColor },
			{ Vector3.new(0.4, top + 2.2, -0.4), 5.4, canopyDark },
		}
		for index, info in blobs do
			local size = info[2] * scale
			Build.blob(model, "Canopy" .. index, Vector3.new(size, size * 0.9, size), at(pos + info[1] * scale), info[3], GRASS, { CanCollide = false })
		end
	end

	-- Only the trunk blocks the player.
	local trunk = model:FindFirstChild("Trunk") :: Part?
	if trunk then
		trunk.CanCollide = true
	end
	return model
end

function Decor.bush(parent: Instance, pos: Vector3, scale: number, rng: Random, berries: boolean?): Model
	local model = Build.model(parent, "Bush")
	local color = if rng:NextNumber() > 0.5 then Palette.Leaf else Palette.LeafDark
	for index = 1, 3 do
		local size = (2.4 + rng:NextNumber() * 1.2) * scale
		local offset = Vector3.new((index - 2) * 1.5 * scale, size * 0.35, (rng:NextNumber() - 0.5) * 1.2 * scale)
		Build.blob(model, "Leaves" .. index, Vector3.new(size, size * 0.85, size), at(pos + offset), color, GRASS, { CanCollide = false })
	end
	if berries then
		for _ = 1, 5 do
			local offset = Vector3.new((rng:NextNumber() - 0.5) * 3.4 * scale, (0.8 + rng:NextNumber() * 1.2) * scale, (rng:NextNumber() - 0.5) * 2.4 * scale)
			Build.deco(model, "Berry", Vector3.one * 0.5, at(pos + offset), Palette.FlowerColors[1 + rng:NextInteger(0, 1)], PLASTIC, { Shape = Enum.PartType.Ball })
		end
	end
	return model
end

function Decor.flowers(parent: Instance, pos: Vector3, radius: number, count: number, rng: Random): Model
	local model = Build.model(parent, "Flowers")
	for _ = 1, count do
		local angle = rng:NextNumber() * math.pi * 2
		local distance = math.sqrt(rng:NextNumber()) * radius
		local base = pos + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local height = 0.9 + rng:NextNumber() * 0.7
		Build.deco(model, "Stem", Vector3.new(0.12, height, 0.12), CFrame.new(base + Vector3.new(0, height / 2, 0)), Palette.LeafDark, GRASS)
		local color = Palette.FlowerColors[rng:NextInteger(1, #Palette.FlowerColors)]
		Build.deco(model, "Bloom", Vector3.new(0.65, 0.35, 0.65), CFrame.new(base + Vector3.new(0, height + 0.1, 0)), color, PLASTIC, { Shape = Enum.PartType.Ball })
		Build.deco(model, "Center", Vector3.new(0.25, 0.25, 0.25), CFrame.new(base + Vector3.new(0, height + 0.28, 0)), Palette.Gold, PLASTIC, { Shape = Enum.PartType.Ball })
	end
	return model
end

function Decor.sunflower(parent: Instance, pos: Vector3, scale: number): Model
	local model = Build.model(parent, "Sunflower")
	local height = 5 * scale
	Build.pillar(model, "Stem", 0.35 * scale, height, at(pos + Vector3.new(0, height / 2, 0)), Palette.LeafDark, GRASS, { CanCollide = false })
	Build.pillar(model, "Petals", 3 * scale, 0.35, at(pos + Vector3.new(0, height, 0)) * CFrame.Angles(0, 0, math.rad(80)), Palette.Gold, PLASTIC, { CanCollide = false })
	Build.pillar(model, "Seeds", 1.6 * scale, 0.5, at(pos + Vector3.new(0, height, 0)) * CFrame.Angles(0, 0, math.rad(80)) * CFrame.new(0, 0.1, 0), Palette.WoodDark, PLASTIC, { CanCollide = false })
	Build.animate(model, "Sway", { Amplitude = 3, Speed = 1.2 })
	return model
end

function Decor.rock(parent: Instance, pos: Vector3, scale: number, rng: Random): Model
	local model = Build.model(parent, "Rock")
	for index = 1, 2 do
		local size = (2 + rng:NextNumber() * 2.4) * scale / index
		Build.blob(
			model,
			"Stone" .. index,
			Vector3.new(size * 1.2, size * 0.8, size),
			at(pos + Vector3.new((index - 1) * 1.8 * scale, size * 0.25, (index - 1) * 0.8 * scale), rng:NextNumber() * math.pi),
			if index == 1 then Palette.Stone else Palette.StoneDark,
			Enum.Material.Slate
		)
	end
	return model
end

function Decor.mushrooms(parent: Instance, pos: Vector3, rng: Random): Model
	local model = Build.model(parent, "Mushrooms")
	for index = 1, 3 do
		local offset = Vector3.new((index - 2) * 1.1, 0, (rng:NextNumber() - 0.5) * 1.2)
		local height = 0.7 + rng:NextNumber() * 0.5
		Build.pillar(model, "Stalk", 0.4, height, at(pos + offset + Vector3.new(0, height / 2, 0)), Palette.Cream, PLASTIC, { CanCollide = false })
		Build.blob(model, "Cap", Vector3.new(1.3, 0.8, 1.3), at(pos + offset + Vector3.new(0, height + 0.15, 0)), Color3.fromRGB(235, 90, 90), PLASTIC, { CanCollide = false })
		Build.deco(model, "Dot", Vector3.new(0.25, 0.15, 0.25), at(pos + offset + Vector3.new(0.2, height + 0.5, 0.1)), Color3.new(1, 1, 1), PLASTIC)
	end
	return model
end

function Decor.stump(parent: Instance, pos: Vector3, scale: number): Model
	local model = Build.model(parent, "Stump")
	Build.pillar(model, "Stump", 2.2 * scale, 1.2 * scale, at(pos + Vector3.new(0, 0.6 * scale, 0)), Palette.Wood, WOOD)
	Build.pillar(model, "Rings", 1.7 * scale, 0.1, at(pos + Vector3.new(0, 1.2 * scale + 0.02, 0)), Palette.WoodLight, WOOD, { CanCollide = false })
	return model
end

---------------------------------------------------------------------------
-- Street furniture
---------------------------------------------------------------------------

function Decor.bench(parent: Instance, cframe: CFrame): Model
	local model = Build.model(parent, "Bench")
	Build.part(model, "Seat", Vector3.new(5, 0.4, 1.8), cframe * CFrame.new(0, 1.5, 0), Palette.WoodLight, WOOD)
	Build.part(model, "Back", Vector3.new(5, 1.4, 0.3), cframe * CFrame.new(0, 2.5, 0.8) * CFrame.Angles(math.rad(-10), 0, 0), Palette.WoodLight, WOOD)
	for _, x in { -2.1, 2.1 } do
		Build.part(model, "Leg", Vector3.new(0.4, 1.4, 1.6), cframe * CFrame.new(x, 0.7, 0), Palette.WoodDark, WOOD)
	end
	return model
end

function Decor.lamp(parent: Instance, pos: Vector3, tall: number?): Model
	local model = Build.model(parent, "Lamp")
	local height = tall or 8
	Build.pillar(model, "Base", 1.4, 0.8, at(pos + Vector3.new(0, 0.4, 0)), Palette.StoneDark, Enum.Material.Metal)
	Build.pillar(model, "Pole", 0.4, height, at(pos + Vector3.new(0, height / 2, 0)), Palette.Ink, Enum.Material.Metal)
	local bulb = Build.blob(model, "Bulb", Vector3.new(1.8, 2.1, 1.8), at(pos + Vector3.new(0, height + 0.8, 0)), Color3.fromRGB(255, 226, 150), Enum.Material.Neon, { CanCollide = false })
	Build.pillar(model, "Cap", 2.2, 0.3, at(pos + Vector3.new(0, height + 2, 0)), Palette.Ink, Enum.Material.Metal, { CanCollide = false })
	Build.light(bulb, Color3.fromRGB(255, 214, 140), 0.9, 22)
	return model
end

function Decor.signpost(parent: Instance, cframe: CFrame, text: string, color: Color3?): Model
	local model = Build.model(parent, "Signpost")
	Build.part(model, "PostL", Vector3.new(0.5, 5, 0.5), cframe * CFrame.new(-2.3, 2.5, 0), Palette.WoodDark, WOOD)
	Build.part(model, "PostR", Vector3.new(0.5, 5, 0.5), cframe * CFrame.new(2.3, 2.5, 0), Palette.WoodDark, WOOD)
	local board = Build.part(model, "Board", Vector3.new(6.4, 2.6, 0.5), cframe * CFrame.new(0, 4.4, 0), color or Palette.WoodLight, WOOD)
	Build.part(model, "Roof", Vector3.new(7, 0.4, 1.2), cframe * CFrame.new(0, 5.9, 0), Palette.WoodDark, WOOD, { CanCollide = false })
	Build.surfaceText(board, Enum.NormalId.Front, text, { TextColor = Palette.Ink, PixelsPerStud = 50 })
	return model
end

function Decor.barrel(parent: Instance, pos: Vector3): Model
	local model = Build.model(parent, "Barrel")
	Build.pillar(model, "Barrel", 2.2, 2.6, at(pos + Vector3.new(0, 1.3, 0)), Palette.Wood, WOOD)
	for _, y in { 0.5, 2.1 } do
		Build.pillar(model, "Band", 2.3, 0.2, at(pos + Vector3.new(0, y, 0)), Palette.Ink, Enum.Material.Metal, { CanCollide = false })
	end
	return model
end

function Decor.crate(parent: Instance, pos: Vector3, yaw: number?): Model
	local model = Build.model(parent, "Crate")
	Build.part(model, "Crate", Vector3.new(2.4, 2.4, 2.4), at(pos + Vector3.new(0, 1.2, 0), yaw), Palette.WoodLight, WOOD)
	Build.deco(model, "Strap", Vector3.new(2.5, 0.3, 2.5), at(pos + Vector3.new(0, 1.2, 0), yaw), Palette.WoodDark, WOOD)
	return model
end

---------------------------------------------------------------------------
-- Boundaries
---------------------------------------------------------------------------

-- Straight picket fence from `a` to `b` (ground points). Optional invisible wall behind it.
function Decor.fenceRun(parent: Instance, a: Vector3, b: Vector3, options: { Color: Color3?, Wall: boolean? }?): Model
	local opts = options or {}
	local model = Build.model(parent, "Fence")
	local delta = b - a
	local length = delta.Magnitude
	if length < 0.5 then
		return model
	end
	local direction = delta.Unit
	local color = opts.Color or Palette.Cream

	local centerPoint = (a + b) / 2
	local runCFrame = CFrame.lookAt(centerPoint, b)
	Build.part(model, "RailTop", Vector3.new(0.3, 0.35, length), runCFrame * CFrame.new(0, 2.7, 0), color, WOOD, { CanCollide = false })
	Build.part(model, "RailLow", Vector3.new(0.3, 0.35, length), runCFrame * CFrame.new(0, 1.2, 0), color, WOOD, { CanCollide = false })

	local count = math.max(2, math.floor(length / 1.9))
	for index = 0, count do
		local point = a + direction * (length * index / count)
		local tall = if index % 4 == 0 then 3.8 else 3.2
		Build.deco(model, "Picket", Vector3.new(0.7, tall, 0.35), CFrame.lookAt(point + Vector3.new(0, tall / 2, 0), point + Vector3.new(0, tall / 2, 0) + direction), color, WOOD)
	end

	if opts.Wall ~= false then
		-- Invisible barrier so nobody hops over the fence.
		Build.part(model, "Barrier", Vector3.new(0.6, 16, length), runCFrame * CFrame.new(0, 8, 0), color, PLASTIC, { Transparency = 1, CanQuery = false, CastShadow = false })
	end
	return model
end

function Decor.hedgeRun(parent: Instance, a: Vector3, b: Vector3, rng: Random): Model
	local model = Build.model(parent, "Hedge")
	local delta = b - a
	local length = delta.Magnitude
	local direction = delta.Unit
	local count = math.max(1, math.floor(length / 3))
	for index = 0, count - 1 do
		local point = a + direction * (length * (index + 0.5) / count)
		local width = length / count + 0.6
		Build.blob(
			model,
			"Hedge",
			Vector3.new(2.6, 4.2 + rng:NextNumber() * 0.6, width),
			CFrame.lookAt(point + Vector3.new(0, 2, 0), point + Vector3.new(0, 2, 0) + direction),
			if index % 2 == 0 then Palette.Leaf else Palette.LeafDark,
			GRASS
		)
	end
	local centerPoint = (a + b) / 2
	Build.part(model, "Barrier", Vector3.new(2.6, 16, length), CFrame.lookAt(centerPoint + Vector3.new(0, 8, 0), b + Vector3.new(0, 8, 0)), Palette.Leaf, PLASTIC, { Transparency = 1, CanQuery = false })
	return model
end

---------------------------------------------------------------------------
-- Animated / themed decorations (animated on the client through tags)
---------------------------------------------------------------------------

function Decor.windmill(parent: Instance, pos: Vector3, yaw: number): Model
	local model = Build.model(parent, "Windmill")
	local base = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
	Build.pillar(model, "Tower", 5, 11, base * CFrame.new(0, 5.5, 0), Palette.Cream, PLASTIC)
	Build.pillar(model, "Roof", 6.4, 1.2, base * CFrame.new(0, 11.4, 0), Palette.RoofColors[1], PLASTIC)
	Build.blob(model, "Dome", Vector3.new(5.6, 3, 5.6), base * CFrame.new(0, 12.2, 0), Palette.RoofColors[1], PLASTIC)
	Build.part(model, "Door", Vector3.new(1.6, 2.6, 0.3), base * CFrame.new(0, 1.3, -2.45), Palette.WoodDark, WOOD, { CanCollide = false })

	local hub = Build.pillar(model, "Hub", 1.2, 1.2, base * CFrame.new(0, 8.5, -3.1) * CFrame.Angles(0, math.rad(90), 0), Palette.WoodDark, WOOD, { CanCollide = false })
	-- Blades are one rotating model: the client spins it around the pivot's Z axis (see DecorAnimator).
	local blades = Build.model(model, "Blades")
	local pivot = Build.deco(blades, "Pivot", Vector3.one * 0.4, base * CFrame.new(0, 8.5, -3.2), Palette.WoodDark, WOOD, { Transparency = 1 })
	hub.Parent = model
	for index = 0, 3 do
		local blade = Build.part(blades, "Blade", Vector3.new(1.6, 7, 0.3), base * CFrame.new(0, 8.5, -3.2) * CFrame.Angles(0, 0, math.rad(index * 90)) * CFrame.new(0, 4, 0), Palette.Cream, PLASTIC, { CanCollide = false })
		Build.deco(blades, "Sail", Vector3.new(1.2, 5, 0.2), blade.CFrame * CFrame.new(0, 0.2, -0.1), Palette.Pink, PLASTIC)
	end
	blades.PrimaryPart = pivot
	blades:SetAttribute("HomeCFrame", pivot.CFrame)
	Build.animate(blades, "SpinModel", { Speed = 0.8 })
	return model
end

function Decor.balloon(parent: Instance, pos: Vector3, color: Color3): Model
	local model = Build.model(parent, "Balloon")
	Build.pillar(model, "String", 0.08, 5, at(pos + Vector3.new(0, 2.5, 0)), Palette.Ink, PLASTIC, { CanCollide = false })
	Build.blob(model, "Balloon", Vector3.new(2.6, 3.2, 2.6), at(pos + Vector3.new(0, 6.4, 0)), color, PLASTIC, { CanCollide = false })
	Build.deco(model, "Shine", Vector3.new(0.5, 0.9, 0.3), at(pos + Vector3.new(-0.6, 7.2, -0.8)), Color3.new(1, 1, 1), PLASTIC, { Transparency = 0.4 })
	Build.animate(model, "Bob", { Amplitude = 0.5, Speed = 1.4 })
	return model
end

function Decor.flag(parent: Instance, pos: Vector3, color: Color3): Model
	local model = Build.model(parent, "Flag")
	Build.pillar(model, "Pole", 0.3, 9, at(pos + Vector3.new(0, 4.5, 0)), Palette.Ink, Enum.Material.Metal)
	local cloth = Build.part(model, "Cloth", Vector3.new(3.4, 2.2, 0.15), at(pos + Vector3.new(1.8, 8, 0)), color, PLASTIC, { CanCollide = false })
	Build.animate(cloth, "Sway", { Amplitude = 6, Speed = 2.4, Axis = "Y" })
	return model
end

function Decor.pond(parent: Instance, pos: Vector3, radius: number, rng: Random): Model
	local model = Build.model(parent, "Pond")
	Build.pillar(model, "Bank", radius * 2 + 2.4, 0.5, at(pos + Vector3.new(0, 0.1, 0)), Palette.Stone, Enum.Material.Slate, { CanCollide = false })
	local water = Build.pillar(model, "Water", radius * 2, 0.5, at(pos + Vector3.new(0, 0.25, 0)), Palette.Water, Enum.Material.Glass, { CanCollide = false, Transparency = 0.25, Reflectance = 0.2 })
	for _ = 1, 5 do
		local angle = rng:NextNumber() * math.pi * 2
		local distance = rng:NextNumber() * (radius - 1.4)
		Build.pillar(model, "LilyPad", 1.5, 0.1, at(pos + Vector3.new(math.cos(angle) * distance, 0.55, math.sin(angle) * distance)), Palette.Leaf, GRASS, { CanCollide = false })
	end
	water:SetAttribute("Ripple", true)
	return model
end

function Decor.fireflies(parent: Instance, pos: Vector3, radius: number): Part
	-- Ambient particles; the client enables/disables them based on the Particles setting.
	local emitterPart = Build.deco(parent, "Fireflies", Vector3.new(radius * 2, 3, radius * 2), CFrame.new(pos + Vector3.new(0, 3, 0)), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1, CanQuery = false })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150))
	emitter.LightEmission = 1
	emitter.Rate = 2
	emitter.Lifetime = NumberRange.new(3, 5)
	emitter.Speed = NumberRange.new(0.3, 1)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.2), NumberSequenceKeypoint.new(1, 1) })
	emitter.Parent = emitterPart
	emitterPart:AddTag("AmbientParticles")
	return emitterPart
end

function Decor.pawPrint(parent: Instance, cframe: CFrame, color: Color3)
	local print = Build.model(parent, "PawPrint")
	Build.pillar(print, "Pad", 1.4, 0.06, cframe * CFrame.new(0, 0.04, 0.35), color, PLASTIC, { CanCollide = false, CastShadow = false })
	for index = -1, 1 do
		local x = index * 0.78
		local z = -0.7 - (1 - math.abs(index)) * 0.35
		Build.pillar(print, "Toe", 0.55, 0.06, cframe * CFrame.new(x, 0.04, z), color, PLASTIC, { CanCollide = false, CastShadow = false })
	end
end

return Decor
