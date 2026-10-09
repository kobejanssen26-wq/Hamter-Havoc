--[[
	Lays out the hamster road from PathConfig plus the spawn burrow (west) and the exit tunnel (east).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Build)
local Decor = require(script.Parent.Decor)
local Palette = require(script.Parent.Palette)

local PathConfig = require(ReplicatedStorage.Modules.PathConfig)

local PathBuilder = {}

local function buildBurrow(parent: Instance, rng: Random)
	local start = PathConfig.SpawnPoint
	local _, tangent = PathConfig.pointAt(0)
	local base = CFrame.lookAt(start, start + tangent) -- -Z is the road direction

	-- grassy hill behind the road start
	local hill = Build.model(parent, "BurrowHill")
	Build.blob(hill, "Hill", Vector3.new(52, 20, 36), base * CFrame.new(0, 3.5, 15), Palette.Grass, Enum.Material.Grass, { CanCollide = true })
	Build.blob(hill, "HillTop", Vector3.new(34, 11, 22), base * CFrame.new(0, 11, 15), Palette.GrassLight, Enum.Material.Grass, { CanCollide = false })
	Build.blob(hill, "HillSide", Vector3.new(20, 9, 20), base * CFrame.new(-24, 3, 8), Palette.GrassDark, Enum.Material.Grass, { CanCollide = false })

	-- the burrow opening
	Build.blob(parent, "BurrowHole", Vector3.new(22, 9, 5), base * CFrame.new(0, 3, 1.2), Color3.fromRGB(34, 22, 26), Enum.Material.SmoothPlastic, { CanCollide = false })
	for _, side in { -1, 1 } do
		Build.pillar(parent, "BurrowPost", 1.3, 9.4, base * CFrame.new(side * 12.4, 4.7, -0.6), Palette.WoodDark, Enum.Material.Wood)
	end
	Build.part(parent, "BurrowBeam", Vector3.new(26.6, 1.1, 1.4), base * CFrame.new(0, 9.5, -0.6), Palette.WoodDark, Enum.Material.Wood)

	local sign = Build.part(parent, "BurrowSign", Vector3.new(14, 3, 0.5), base * CFrame.new(0, 12.2, -0.6), Palette.WoodLight, Enum.Material.Wood, { CanCollide = false })
	Build.surfaceText(sign, Enum.NormalId.Front, "HAMSTER BURROW", { TextColor = Palette.Ink, PixelsPerStud = 50 })
	Build.deco(parent, "SignPostL", Vector3.new(0.4, 2.4, 0.4), base * CFrame.new(-5.4, 10.8, -0.6), Palette.WoodDark, Enum.Material.Wood)
	Build.deco(parent, "SignPostR", Vector3.new(0.4, 2.4, 0.4), base * CFrame.new(5.4, 10.8, -0.6), Palette.WoodDark, Enum.Material.Wood)

	-- warm glow + sparkles from the hole: this is where hamsters appear
	local glow = Build.deco(parent, "BurrowGlow", Vector3.new(6, 4, 2), base * CFrame.new(0, 2.2, -0.2), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { Transparency = 1, CanQuery = false })
	Build.light(glow, Color3.fromRGB(255, 200, 120), 1.2, 18)
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 226, 150))
	sparkle.LightEmission = 1
	sparkle.Rate = 5
	sparkle.Lifetime = NumberRange.new(1.2, 2)
	sparkle.Speed = NumberRange.new(2, 4)
	sparkle.SpreadAngle = Vector2.new(35, 35)
	sparkle.EmissionDirection = Enum.NormalId.Front
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Parent = glow
	glow:AddTag("AmbientParticles")

	Decor.flowers(parent, (base * CFrame.new(-19, 0, -4)).Position, 3, 12, rng)
	Decor.flowers(parent, (base * CFrame.new(19, 0, -4)).Position, 3, 12, rng)
	Decor.lamp(parent, (base * CFrame.new(16, 0, -8)).Position, 7)
end

local function buildExit(parent: Instance, rng: Random)
	local finish = PathConfig.ExitPoint
	local _, tangent = PathConfig.pointAt(PathConfig.Length)
	local base = CFrame.lookAt(finish, finish + tangent)

	-- stone tunnel the hamsters run into
	Build.blob(parent, "ExitHill", Vector3.new(52, 20, 30), base * CFrame.new(0, 3.5, -15), Palette.Grass, Enum.Material.Grass, { CanCollide = true })
	Build.blob(parent, "ExitHole", Vector3.new(22, 9, 5), base * CFrame.new(0, 3, -1.2), Color3.fromRGB(28, 22, 34), Enum.Material.SmoothPlastic, { CanCollide = false })
	for _, side in { -1, 1 } do
		Build.part(parent, "ExitPillar", Vector3.new(2.2, 9.6, 2.2), base * CFrame.new(side * 12.4, 4.8, 0.4), Palette.Stone, Enum.Material.Slate)
	end
	Build.part(parent, "ExitArch", Vector3.new(27.4, 1.8, 2.4), base * CFrame.new(0, 10, 0.4), Palette.StoneDark, Enum.Material.Slate)
	Decor.lamp(parent, (base * CFrame.new(16, 0, 8)).Position, 7)
end

-- Painted arrow (chevron) pointing east, i.e. in the direction the hamsters roll.
local function chevron(parent: Instance, center: Vector3)
	for _, side in { -1, 1 } do
		Build.deco(
			parent,
			"Arrow",
			Vector3.new(2.6, 0.05, 0.5),
			CFrame.new(center + Vector3.new(-0.8, 0.31, side * 0.7)) * CFrame.Angles(0, side * math.rad(34), 0),
			Palette.Cream,
			Enum.Material.SmoothPlastic,
			{ Transparency = 0.15 }
		)
	end
end

function PathBuilder.build(parent: Instance, rng: Random): Folder
	local folder = Build.folder(parent, "HamsterPath")
	local width = PathConfig.Width
	local length = PathConfig.Length
	local height = PathConfig.RoadHeight

	-- the road: one straight slab, curbs on both sides
	Build.part(folder, "Road", Vector3.new(length, height, width), CFrame.new(0, height / 2, 0), Palette.Road, Enum.Material.SmoothPlastic, { CastShadow = false })
	for _, side in { -1, 1 } do
		Build.part(folder, "Curb", Vector3.new(length, 0.5, 0.8), CFrame.new(0, height / 2 + 0.11, side * (width / 2 + 0.4)), Palette.RoadEdge, Enum.Material.Cobblestone, { CastShadow = false })
	end
	-- lane divider (dashes) and direction arrows
	for x = -200, 200, 20 do
		Build.deco(folder, "LaneDash", Vector3.new(6, 0.04, 0.3), CFrame.new(x, height + 0.02, 0), Palette.Cream, Enum.Material.SmoothPlastic, { Transparency = 0.3 })
	end
	for _, x in { -170, -130, -90, 90, 130, 170 } do
		for _, lane in PathConfig.LaneOffsets do
			chevron(folder, Vector3.new(x, 0, lane))
		end
	end

	buildBurrow(folder, rng)
	buildExit(folder, rng)
	return folder
end

return PathBuilder
