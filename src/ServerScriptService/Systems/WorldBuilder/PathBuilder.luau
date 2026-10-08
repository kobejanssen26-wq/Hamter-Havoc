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
	Build.blob(hill, "Hill", Vector3.new(26, 15, 30), base * CFrame.new(0, 2.5, 13), Palette.Grass, Enum.Material.Grass, { CanCollide = true })
	Build.blob(hill, "HillTop", Vector3.new(16, 8, 18), base * CFrame.new(0, 8.5, 13), Palette.GrassLight, Enum.Material.Grass, { CanCollide = false })
	Build.blob(hill, "HillSide", Vector3.new(12, 7, 14), base * CFrame.new(-9, 2.6, 6), Palette.GrassDark, Enum.Material.Grass, { CanCollide = false })

	-- the burrow opening
	Build.blob(parent, "BurrowHole", Vector3.new(10, 7.5, 5), base * CFrame.new(0, 2.7, 1.2), Color3.fromRGB(34, 22, 26), Enum.Material.SmoothPlastic, { CanCollide = false })
	for _, side in { -1, 1 } do
		Build.pillar(parent, "BurrowPost", 1.1, 8.4, base * CFrame.new(side * 5.6, 4.2, -0.6), Palette.WoodDark, Enum.Material.Wood)
	end
	Build.part(parent, "BurrowBeam", Vector3.new(12.6, 1, 1.2), base * CFrame.new(0, 8.6, -0.6), Palette.WoodDark, Enum.Material.Wood)

	local sign = Build.part(parent, "BurrowSign", Vector3.new(11, 2.8, 0.5), base * CFrame.new(0, 11.2, -0.6), Palette.WoodLight, Enum.Material.Wood, { CanCollide = false })
	Build.surfaceText(sign, Enum.NormalId.Front, "🐹 HAMSTER BURROW", { TextColor = Palette.Ink, PixelsPerStud = 50 })
	Build.deco(parent, "SignPostL", Vector3.new(0.4, 2.4, 0.4), base * CFrame.new(-4.4, 9.8, -0.6), Palette.WoodDark, Enum.Material.Wood)
	Build.deco(parent, "SignPostR", Vector3.new(0.4, 2.4, 0.4), base * CFrame.new(4.4, 9.8, -0.6), Palette.WoodDark, Enum.Material.Wood)

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

	Decor.flowers(parent, (base * CFrame.new(-10, 0, -3)).Position, 3, 12, rng)
	Decor.flowers(parent, (base * CFrame.new(10, 0, -3)).Position, 3, 12, rng)
	Decor.mushrooms(parent, (base * CFrame.new(-8, 0, 3)).Position, rng)
	Decor.lamp(parent, (base * CFrame.new(7.5, 0, -7)).Position, 7)
	Decor.lamp(parent, (base * CFrame.new(-7.5, 0, -7)).Position, 7)
end

local function buildExit(parent: Instance, rng: Random)
	local finish = PathConfig.ExitPoint
	local _, tangent = PathConfig.pointAt(PathConfig.Length)
	local base = CFrame.lookAt(finish, finish + tangent)

	-- stone tunnel the hamsters run into
	Build.blob(parent, "ExitHill", Vector3.new(26, 15, 26), base * CFrame.new(0, 2.5, -13), Palette.Grass, Enum.Material.Grass, { CanCollide = true })
	Build.blob(parent, "ExitHole", Vector3.new(10, 7.5, 5), base * CFrame.new(0, 2.7, -1.2), Color3.fromRGB(28, 22, 34), Enum.Material.SmoothPlastic, { CanCollide = false })
	for _, side in { -1, 1 } do
		Build.part(parent, "ExitPillar", Vector3.new(1.8, 8.6, 1.8), base * CFrame.new(side * 5.6, 4.3, 0.4), Palette.Stone, Enum.Material.Slate)
	end
	Build.part(parent, "ExitArch", Vector3.new(13, 1.6, 2), base * CFrame.new(0, 9, 0.4), Palette.StoneDark, Enum.Material.Slate)
	local sign = Build.part(parent, "ExitSign", Vector3.new(8, 2.4, 0.5), base * CFrame.new(0, 11.2, 0.4), Palette.WoodLight, Enum.Material.Wood, { CanCollide = false })
	Build.surfaceText(sign, Enum.NormalId.Back, "EXIT →", { TextColor = Palette.Ink, PixelsPerStud = 50 })
	Build.surfaceText(sign, Enum.NormalId.Front, "EXIT", { TextColor = Palette.Ink, PixelsPerStud = 50 })
	Decor.flowers(parent, (base * CFrame.new(-9, 0, 4)).Position, 3, 10, rng)
	Decor.flowers(parent, (base * CFrame.new(9, 0, 4)).Position, 3, 10, rng)
	Decor.lamp(parent, (base * CFrame.new(7.5, 0, 6)).Position, 7)
	Decor.lamp(parent, (base * CFrame.new(-7.5, 0, 6)).Position, 7)
end

function PathBuilder.build(parent: Instance, rng: Random): Folder
	local folder = Build.folder(parent, "HamsterPath")
	local width = PathConfig.Width
	local samples = PathConfig.sample(5)

	for index = 1, #samples - 1 do
		local a = samples[index].Position
		local b = samples[index + 1].Position
		local mid = (a + b) / 2
		local length = (b - a).Magnitude + 0.4
		local cframe = CFrame.lookAt(Vector3.new(mid.X, 0.14, mid.Z), Vector3.new(b.X, 0.14, b.Z))
		Build.part(folder, "Road", Vector3.new(width, 0.28, length), cframe, Palette.Road, Enum.Material.SmoothPlastic, { CastShadow = false })
		for _, side in { -1, 1 } do
			Build.part(folder, "Curb", Vector3.new(0.8, 0.5, length), cframe * CFrame.new(side * (width / 2 + 0.4), 0.11, 0), Palette.RoadEdge, Enum.Material.Cobblestone, { CastShadow = false })
		end
	end

	-- paw prints along the road show the direction of travel
	for index = 3, #samples - 2, 3 do
		local sample = samples[index]
		local side = if (index // 3) % 2 == 0 then -1 else 1
		local position = sample.Position + Vector3.new(0, PathConfig.RoadHeight, 0) + sample.Tangent:Cross(Vector3.yAxis) * (side * 1.8)
		Decor.pawPrint(folder, CFrame.lookAt(position, position + sample.Tangent), Color3.fromRGB(214, 160, 100))
	end

	buildBurrow(folder, rng)
	buildExit(folder, rng)
	return folder
end

return PathBuilder
