--[[
	HamsterBuilder - turns a species definition (HamsterDatabase) into a rigged Model.

	Every hamster shares a cute rounded base but gets its own ears, eyes, mouth, fur pattern, tail,
	accessories, wings, effects and size, so no two species are recolours of each other.

	Rig:  Root (anchored, invisible) -> BodyJ -> HeadJ -> EarLJ/EarRJ ; BodyJ -> PawFLJ/FRJ/BLJ/BRJ, TailJ, WingLJ/WingRJ
	All joints are Motor6Ds animated on the client through `Transform` (see HamsterAnimator).

	Usage:  local model = HamsterBuilder.build(species, { Scale = 0.5, LowDetail = true })
]]

local Toolkit = require(script.Toolkit)
local Faces = require(script.Faces)
local Hats = require(script.Hats)
local Gear = require(script.Gear)
local Wings = require(script.Wings)

local T = Toolkit
local CF = CFrame.new
local ANG = CFrame.Angles
local rad = math.rad
local V3 = Vector3.new

local HamsterBuilder = {}

local Accessories: { [string]: (Toolkit.Ctx, any) -> () } = {}
for _, library in { Hats, Gear, Wings } do
	for id, builder in library :: any do
		Accessories[id] = builder
	end
end

HamsterBuilder.Registry = {
	Eyes = Faces.Eyes,
	Mouths = Faces.Mouths,
	Ears = Faces.Ears,
	Tails = Faces.Tails,
	Patterns = Faces.Patterns,
	Accessories = Accessories,
}

export type BuildOptions = {
	Scale: number?,
	LowDetail: boolean?,
	Particles: boolean?,
}

local NOSE = Color3.fromRGB(255, 130, 150)
local PINK = Color3.fromRGB(255, 160, 175)
local WHITE = Color3.new(1, 1, 1)

-- Names that are missing from the registries (for tests / content validation).
function HamsterBuilder.validate(species: any): { string }
	local problems = {}
	local function check(kind: string, registry: { [string]: any }, id: string?)
		if id and registry[id] == nil then
			table.insert(problems, string.format("%s: unknown %s '%s'", species.Id, kind, id))
		end
	end
	check("eyes", Faces.Eyes, species.Eyes)
	check("mouth", Faces.Mouths, species.Mouth)
	check("ears", Faces.Ears, species.Ears)
	check("tail", Faces.Tails, species.Tail)
	check("pattern", Faces.Patterns, species.Pattern)
	for _, id in species.Acc or {} do
		check("accessory", Accessories, id)
	end
	return problems
end

-- A string that is identical for two species only if their look is identical.
function HamsterBuilder.signature(species: any): string
	local accessories = table.clone(species.Acc or {})
	table.sort(accessories)
	local fx = {}
	for _, entry in species.Fx or {} do
		table.insert(fx, entry[1])
	end
	return table.concat({
		species.Ears or "round",
		species.Eyes or "dot",
		species.Mouth or "smile",
		species.Pattern or "none",
		species.Tail or "nub",
		table.concat(accessories, "+"),
		table.concat(fx, "+"),
		string.format("%.2f", species.Size or 1),
	}, "|")
end

-- Stable per-species body proportions in a narrow range (so they stay hamster-like), from the species id.
function HamsterBuilder.proportions(id: string): { Width: number, Height: number, Length: number, Head: number }
	local hash = 5381
	for index = 1, #id do
		hash = (hash * 33 + string.byte(id, index)) % 2147483647
	end
	local function unit(shift: number): number
		return ((hash // shift) % 1000) / 999 * 2 - 1 -- -1 .. 1
	end
	return {
		Width = 1 + unit(1) * 0.1,
		Height = 1 + unit(7) * 0.08,
		Length = 1 + unit(31) * 0.1,
		Head = 1 + unit(127) * 0.07,
	}
end

function HamsterBuilder.build(species: any, options: BuildOptions?): Model
	local opts = options or {}
	-- a hamster with its own Studio model (Content/Hamsters ModelName) uses it; a missing/invalid model falls back below
	if species.ModelName then
		local modelsModule = script.Parent:FindFirstChild("HamsterModels")
		if modelsModule then
			local custom = (require(modelsModule) :: any).instantiate(species, opts.Scale or 1)
			if custom then
				return custom
			end
		end
	end
	local fur: Color3 = species.Fur
	local belly: Color3 = species.Belly or T.mix(fur, WHITE, 0.55)

	local model = Instance.new("Model")
	model.Name = species.Name

	local root = Instance.new("Part")
	root.Name = "Root"
	root.Size = V3(1, 0.2, 1)
	root.CFrame = CF(0, 0.1, 0)
	root.Transparency = 1
	root.Anchored = true
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Parent = model
	model.PrimaryPart = root

	local ctx: Toolkit.Ctx = {
		Model = model,
		Root = root,
		Parts = { Root = root },
		Joints = {},
		Fur = fur,
		Belly = belly,
		Color2 = species.Color2 or T.shade(fur, 0.7),
		Accent = species.Accent or Color3.fromRGB(255, 190, 80),
		LowDetail = opts.LowDetail == true,
		Rarity = species.Rarity or "Basic",
	}
	local spec: any = species

	-- core body ---------------------------------------------------------
	-- every species gets its own stable proportions (plumper, longer, bigger head ...), so hamsters are not just recolours.
	-- Derived from the id, so a species always looks the same; `species.Build = { Width, Height, Length, Head }` overrides it.
	local build = species.Build or HamsterBuilder.proportions(species.Id or species.Name or "")
	T.limb(ctx, "Body", "Root", V3(0, 0.5, 0.3), V3(2.7 * build.Width, 2.2 * build.Height, 2.6 * build.Length), CF(0, 1.3, 0.3), fur, Enum.MeshType.Sphere, { Cast = true })
	T.limb(ctx, "Head", "Body", V3(0, 1.8, -0.4), V3(2.6 * build.Head, 2.2 * build.Head, 2.3 * build.Head), CF(0, 2.3, -0.7), fur, Enum.MeshType.Sphere, { Cast = true })

	local pawColor = species.PawColor or (if species.Pattern == "socks" then ctx.Color2 else T.mix(fur, PINK, 0.25))
	local paws = {
		{ "PawFL", V3(-0.85, 0.4, -0.9), V3(0.75, 0.6, 0.85) },
		{ "PawFR", V3(0.85, 0.4, -0.9), V3(0.75, 0.6, 0.85) },
		{ "PawBL", V3(-1.0, 0.4, 0.95), V3(0.85, 0.6, 1.1) },
		{ "PawBR", V3(1.0, 0.4, 0.95), V3(0.85, 0.6, 1.1) },
	}
	for _, paw in paws do
		T.limb(ctx, paw[1], "Body", V3(paw[2].X, 0.7, paw[2].Z), paw[3], CF(paw[2]), pawColor, Enum.MeshType.Sphere)
	end

	T.blob(ctx, "Belly", V3(1.7, 1.5, 0.6), CF(0, 1.15, -0.95), belly, { Attach = "Body" })
	T.both(function(side)
		T.blob(ctx, "Cheek", V3(1.0, 1.0, 0.9), CF(side * 1.05, 1.95, -1.0), fur, { Attach = "Head" })
	end)
	T.blob(ctx, "Muzzle", V3(1.15, 0.85, 0.6), CF(0, 2.0, -1.55), belly, { Attach = "Head" })
	T.blob(ctx, "Nose", V3(0.3, 0.24, 0.2), CF(0, 2.2, -1.86), species.NoseColor or NOSE, { Attach = "Head" })
	if not species.NoBlush then
		T.both(function(side)
			T.blob(ctx, "Blush", V3(0.5, 0.32, 0.15), CF(side * 0.98, 2.1, -1.7), Color3.fromRGB(255, 130, 160), { Attach = "Head", Transparency = 0.45, Minor = true })
		end)
	end
	T.both(function(side)
		for index = -1, 1 do
			T.block(ctx, "Whisker", V3(0.8, 0.03, 0.03), CF(side * 1.55, 2.05 + index * 0.1, -1.55) * ANG(0, rad(-side * 12), rad(side * index * 8)), Color3.fromRGB(240, 235, 230), { Attach = "Head", Minor = true })
		end
	end)

	-- small realistic details (skipped in low detail): front teeth and a few fur tufts
	T.both(function(side)
		T.block(ctx, "Incisor", V3(0.16, 0.2, 0.08), CF(side * 0.1, 1.68, -1.8), Color3.fromRGB(252, 248, 236), { Attach = "Head", Minor = true })
	end)
	for index, offset in { V3(-0.28, 3.4, -0.55), V3(0.05, 3.48, -0.7), V3(0.3, 3.38, -0.5) } do
		T.blob(ctx, "FurTuft", V3(0.34, 0.5, 0.3), CF(offset) * ANG(rad(-14), 0, rad((index - 2) * 22)), T.mix(fur, WHITE, 0.2), { Attach = "Head", Minor = true })
	end

	-- variants ----------------------------------------------------------
	local patternBuilder = Faces.Patterns[species.Pattern or "none"]
	if patternBuilder then
		patternBuilder(ctx, spec)
	end
	local earBuilder = Faces.Ears[species.Ears or "round"]
	if earBuilder then
		earBuilder(ctx, spec)
	end
	local tailBuilder = Faces.Tails[species.Tail or "nub"]
	if tailBuilder then
		tailBuilder(ctx, spec)
	end
	local eyeBuilder = Faces.Eyes[species.Eyes or "dot"]
	if eyeBuilder then
		eyeBuilder(ctx, spec)
	end
	local mouthBuilder = Faces.Mouths[species.Mouth or "smile"]
	if mouthBuilder then
		mouthBuilder(ctx, spec)
	end

	for _, id in species.Acc or {} do
		local builder = Accessories[id]
		if builder then
			builder(ctx, spec)
		else
			warn(string.format("HamsterBuilder: unknown accessory '%s' on %s", id, species.Name))
		end
	end

	-- particles + light --------------------------------------------------
	for _, entry in species.Fx or {} do
		local emitter = T.emitter(ctx, entry[1], entry[2] or ctx.Accent, "Body")
		if emitter and opts.Particles == false then
			emitter.Enabled = false
		end
	end
	if species.Glow then
		T.glow(ctx, species.Glow[1], species.Glow[2], species.Glow[3])
	end

	-- size ---------------------------------------------------------------
	local scale = (species.Size or 1) * (opts.Scale or 1)
	if math.abs(scale - 1) > 0.001 then
		model:ScaleTo(scale)
	end

	model:SetAttribute("SpeciesId", species.Id)
	model:SetAttribute("Rarity", species.Rarity)
	model:SetAttribute("Height", 3.4 * scale)
	return model
end

-- Camera that frames a built model nicely (used for index icons). Model must be at the origin.
function HamsterBuilder.frameCamera(model: Model, fieldOfView: number?): (CFrame, number)
	local fov = fieldOfView or 30
	local boxCFrame, size = model:GetBoundingBox()
	local center = boxCFrame.Position
	local radius = math.max(size.X, size.Y * 1.1, size.Z * 0.8) * 0.5
	local distance = radius / math.tan(math.rad(fov / 2)) * 1.15
	local direction = Vector3.new(0.35, 0.22, -1).Unit
	return CFrame.lookAt(center + direction * distance, center), fov
end

return HamsterBuilder
