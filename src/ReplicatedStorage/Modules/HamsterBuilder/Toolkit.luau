--[[
	Primitive toolkit for procedurally modelling hamsters out of rounded parts.

	Hamster-local space: origin = on the ground under the hamster, +Y up, the hamster FACES -Z.
	Reference anchors (scale 1):
	  body centre (0, 1.3, 0.3)   head centre (0, 2.3, -0.7)   head top y = 3.4   face front z = -1.85
	  back (z = +1.6, y ~ 2.2)    paws on the ground (y = 0..0.7)
	All coordinates passed to these helpers are in that space (the model is built at the origin and
	moved afterwards).
]]

local Toolkit = {}

local CF = CFrame.new
local ANG = CFrame.Angles

export type Ctx = {
	Model: Model,
	Root: Part,
	Parts: { [string]: Part },
	Joints: { [string]: Motor6D },
	Fur: Color3,
	Belly: Color3,
	Color2: Color3,
	Accent: Color3,
	LowDetail: boolean,
	Rarity: string,
}

Toolkit.Anchors = {
	HeadTop = Vector3.new(0, 3.35, -0.6),
	FaceFront = Vector3.new(0, 2.3, -1.85),
	BackTop = Vector3.new(0, 2.3, 0.7),
	BackCenter = Vector3.new(0, 1.9, 1.5),
	Chest = Vector3.new(0, 1.2, -1.1),
	Neck = Vector3.new(0, 1.7, -0.5),
}

function Toolkit.shade(color: Color3, factor: number): Color3
	return Color3.new(math.clamp(color.R * factor, 0, 1), math.clamp(color.G * factor, 0, 1), math.clamp(color.B * factor, 0, 1))
end

function Toolkit.mix(a: Color3, b: Color3, alpha: number): Color3
	return a:Lerp(b, alpha)
end

export type Options = {
	Material: Enum.Material?,
	Transparency: number?,
	Reflectance: number?,
	Shape: Enum.PartType?,
	Mesh: Enum.MeshType?,
	Attach: string?,
	NoWeld: boolean?,
	Minor: boolean?,
	Cast: boolean?,
}

-- Core part factory. Returns nil for `Minor` parts when the hamster is built in low detail.
function Toolkit.make(ctx: Ctx, name: string, size: Vector3, cframe: CFrame, color: Color3, opts: Options?): Part?
	local options = opts or {}
	if options.Minor and ctx.LowDetail then
		return nil
	end
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = options.Material or Enum.Material.SmoothPlastic
	part.Anchored = false
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.CastShadow = options.Cast == true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if options.Transparency then
		part.Transparency = options.Transparency
	end
	if options.Reflectance then
		part.Reflectance = options.Reflectance
	end
	if options.Shape then
		part.Shape = options.Shape
	end
	if options.Mesh then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = options.Mesh
		mesh.Parent = part
	end
	part.Parent = ctx.Model
	if not options.NoWeld then
		local attach = ctx.Parts[options.Attach or "Body"]
		if attach then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = attach
			weld.Part1 = part
			weld.Parent = part
		end
	end
	return part
end

local function merge(options: Options?, extra: Options): Options
	local result: any = {}
	if options then
		for key, value in options :: any do
			result[key] = value
		end
	end
	for key, value in extra :: any do
		if result[key] == nil then
			result[key] = value
		end
	end
	return result
end

-- Rounded ellipsoid.
function Toolkit.blob(ctx: Ctx, name: string, size: Vector3, cframe: CFrame, color: Color3, opts: Options?): Part?
	return Toolkit.make(ctx, name, size, cframe, color, merge(opts, { Mesh = Enum.MeshType.Sphere }))
end

function Toolkit.block(ctx: Ctx, name: string, size: Vector3, cframe: CFrame, color: Color3, opts: Options?): Part?
	return Toolkit.make(ctx, name, size, cframe, color, opts)
end

-- Cylinder standing along Y (a "rod"). `center` is its middle.
function Toolkit.rod(ctx: Ctx, name: string, diameter: number, length: number, center: CFrame, color: Color3, opts: Options?): Part?
	return Toolkit.make(ctx, name, Vector3.new(length, diameter, diameter), center * ANG(0, 0, math.rad(90)), color, merge(opts, { Shape = Enum.PartType.Cylinder }))
end

-- Flat disc facing forward (-Z). `center` is its middle.
function Toolkit.disc(ctx: Ctx, name: string, diameter: number, thickness: number, center: CFrame, color: Color3, opts: Options?): Part?
	return Toolkit.make(ctx, name, Vector3.new(thickness, diameter, diameter), center * ANG(0, math.rad(90), 0), color, merge(opts, { Shape = Enum.PartType.Cylinder }))
end

-- Flat horizontal ring-ish disc (halo / brim). Lies in the XZ plane.
function Toolkit.plate(ctx: Ctx, name: string, diameter: number, thickness: number, center: CFrame, color: Color3, opts: Options?): Part?
	return Toolkit.rod(ctx, name, diameter, thickness, center, color, opts)
end

-- Faceted neon diamond (gems, crystals).
function Toolkit.gem(ctx: Ctx, name: string, size: Vector3, center: CFrame, color: Color3, opts: Options?): Part?
	return Toolkit.make(ctx, name, size, center * ANG(math.rad(45), math.rad(45), 0), color, merge(opts, { Material = Enum.Material.Neon }))
end

-- A tall crystal: elongated diamond.
function Toolkit.crystal(ctx: Ctx, name: string, width: number, height: number, center: CFrame, color: Color3, opts: Options?): Part?
	return Toolkit.make(ctx, name, Vector3.new(width, height, width), center * ANG(0, math.rad(45), 0), color, merge(opts, { Material = Enum.Material.Neon, Transparency = 0.15 }))
end

-- 4-point star made from crossed thin blocks (faces forward).
function Toolkit.star(ctx: Ctx, name: string, size: number, center: CFrame, color: Color3, opts: Options?)
	Toolkit.make(ctx, name, Vector3.new(size, size * 0.3, size * 0.2), center, color, merge(opts, { Material = Enum.Material.Neon }))
	Toolkit.make(ctx, name, Vector3.new(size * 0.3, size, size * 0.2), center, color, merge(opts, { Material = Enum.Material.Neon }))
	Toolkit.make(ctx, name, Vector3.new(size * 0.7, size * 0.22, size * 0.2), center * ANG(0, 0, math.rad(45)), color, merge(opts, { Material = Enum.Material.Neon, Minor = true }))
	Toolkit.make(ctx, name, Vector3.new(size * 0.7, size * 0.22, size * 0.2), center * ANG(0, 0, math.rad(-45)), color, merge(opts, { Material = Enum.Material.Neon, Minor = true }))
end

-- Motor6D with the pivot given in hamster space. Animated by the client (Transform).
function Toolkit.joint(ctx: Ctx, name: string, part0: Part, part1: Part, pivot: Vector3)
	local motor = Instance.new("Motor6D")
	motor.Name = name
	motor.Part0 = part0
	motor.Part1 = part1
	local pivotCFrame = CF(pivot)
	motor.C0 = part0.CFrame:ToObjectSpace(pivotCFrame)
	motor.C1 = part1.CFrame:ToObjectSpace(pivotCFrame)
	motor.Parent = part1
	ctx.Joints[name] = motor
	return motor
end

-- Registers an articulated part (body, head, ears, paws ...): creates it, joins it, remembers it.
function Toolkit.limb(ctx: Ctx, name: string, parent: string, pivot: Vector3, size: Vector3, cframe: CFrame, color: Color3, mesh: Enum.MeshType?, opts: Options?): Part
	local part = Toolkit.make(ctx, name, size, cframe, color, merge(opts, { NoWeld = true, Mesh = mesh }))
	assert(part, "limb parts can never be minor")
	ctx.Parts[name] = part
	Toolkit.joint(ctx, name .. "J", ctx.Parts[parent], part, pivot)
	return part
end

-- Runs fn(side) for the left (-1) and right (+1) side.
function Toolkit.both(fn: (number) -> ())
	fn(-1)
	fn(1)
end

local TEXTURES = {
	sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
}

-- Particle emitter on a part. Disabled by default for display models (the client toggles `AmbientParticles`).
function Toolkit.emitter(ctx: Ctx, kind: string, color: Color3, parentName: string?): ParticleEmitter?
	local parent = ctx.Parts[parentName or "Body"]
	if not parent then
		return nil
	end
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Fx_" .. kind
	emitter.Texture = if kind == "flame" or kind == "embers" then TEXTURES.fire elseif kind == "smoke" or kind == "snow" then TEXTURES.smoke else TEXTURES.sparkle
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = if kind == "smoke" then 0 else 0.7
	emitter.Rate = 6
	emitter.Lifetime = NumberRange.new(1, 1.8)
	emitter.Speed = NumberRange.new(1, 2.5)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Rotation = NumberRange.new(0, 360)

	if kind == "flame" or kind == "embers" then
		emitter.Acceleration = Vector3.new(0, 4, 0)
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.SpreadAngle = Vector2.new(25, 25)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	elseif kind == "snow" then
		emitter.LightEmission = 0.2
		emitter.Acceleration = Vector3.new(0, -2, 0)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0.25) })
	elseif kind == "bubbles" then
		emitter.Acceleration = Vector3.new(0, 1.5, 0)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.7) })
	elseif kind == "hearts" or kind == "stars" then
		emitter.Acceleration = Vector3.new(0, 1.2, 0)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.1) })
	elseif kind == "glitch" then
		emitter.Speed = NumberRange.new(2, 5)
		emitter.Rate = 10
		emitter.Lifetime = NumberRange.new(0.3, 0.7)
	end

	emitter.Enabled = true
	emitter.Parent = parent
	parent:AddTag("BuilderFx")
	return emitter
end

function Toolkit.glow(ctx: Ctx, color: Color3, brightness: number, range: number)
	local body = ctx.Parts.Body
	if not body then
		return
	end
	local light = Instance.new("PointLight")
	light.Name = "BuilderGlow"
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = body
end

return Toolkit
