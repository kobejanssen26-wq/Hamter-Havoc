--[[
	Ground, promenades, lamps, the forest border and the invisible world boundary.
	The playable core is compact: houses at z = +-76, promenades at z = +-50, plaza in the middle.
]]

local Build = require(script.Parent.Build)
local Decor = require(script.Parent.Decor)
local Palette = require(script.Parent.Palette)

local EnvironmentBuilder = {}

local COSMETIC = Enum.Material.Cobblestone

local GROUND_HALF_X = 178
local GROUND_HALF_Z = 132

-- True for points that belong to the dense core (houses, plaza, promenades) or the road corridors.
local function isCore(x: number, z: number): boolean
	if math.abs(x) < 116 and math.abs(z) < 104 then
		return true
	end
	-- keep the road ends and burrow/exit areas free
	if math.abs(z + 16) < 18 and math.abs(x) > 110 then
		return true
	end
	return false
end

function EnvironmentBuilder.build(parent: Instance, rng: Random): Folder
	local folder = Build.folder(parent, "Environment")

	-- ground + soft grass patches so the lawn isn't one flat colour
	Build.part(folder, "Ground", Vector3.new(GROUND_HALF_X * 2, 4, GROUND_HALF_Z * 2), CFrame.new(0, -2, 0), Palette.Grass, Enum.Material.Grass)
	local patches = Build.folder(folder, "GrassPatches")
	for _ = 1, 70 do
		local x = (rng:NextNumber() * 2 - 1) * (GROUND_HALF_X - 8)
		local z = (rng:NextNumber() * 2 - 1) * (GROUND_HALF_Z - 8)
		local radius = 6 + rng:NextNumber() * 12
		local color = if rng:NextNumber() > 0.5 then Palette.GrassLight else Palette.GrassDark
		Build.pillar(patches, "Patch", radius * 2, 0.04, CFrame.new(x, 0.01, z), color, Enum.Material.Grass, { CanCollide = false, CastShadow = false })
	end

	-- promenades in front of the houses
	local walks = Build.folder(folder, "Promenades")
	for _, sign in { 1, -1 } do
		Build.part(walks, "Promenade", Vector3.new(232, 0.2, 6), CFrame.new(0, 0.1, sign * 50), Palette.Pavement, COSMETIC, { CanCollide = false })
		for _, edge in { -3.2, 3.2 } do
			Build.deco(walks, "PromenadeEdge", Vector3.new(232, 0.24, 0.4), CFrame.new(0, 0.11, sign * 50 + edge), Palette.PavementDark, COSMETIC)
		end
		for _, x in { -88, -44, 0, 44, 88 } do
			Build.part(walks, "GateTile", Vector3.new(4.4, 0.2, 2.4), CFrame.new(x, 0.1, sign * 53.8), Palette.Pavement, COSMETIC, { CanCollide = false })
		end
	end
	-- connectors to the plaza
	Build.part(walks, "ConnectorNorth", Vector3.new(6, 0.2, 14), CFrame.new(0, 0.1, 40.5), Palette.Pavement, COSMETIC, { CanCollide = false })
	for _, x in { -9.5, 9.5 } do
		Build.part(walks, "ConnectorSouth", Vector3.new(5, 0.2, 16), CFrame.new(x, 0.1, -39.5), Palette.Pavement, COSMETIC, { CanCollide = false })
	end
	-- garden paths to windmill and pond
	Build.part(walks, "GardenPathWest", Vector3.new(4, 0.2, 14), CFrame.new(-60, 0.1, 43) * CFrame.Angles(0, math.rad(-10), 0), Palette.Pavement, COSMETIC, { CanCollide = false })
	Build.part(walks, "GardenPathEast", Vector3.new(4, 0.2, 14), CFrame.new(60, 0.1, 43) * CFrame.Angles(0, math.rad(10), 0), Palette.Pavement, COSMETIC, { CanCollide = false })

	-- street furniture along both promenades
	local props = Build.folder(folder, "Props")
	for _, sign in { 1, -1 } do
		for _, x in { -100, -72, -44, -16, 16, 44, 72, 100 } do
			Decor.lamp(props, Vector3.new(x, 0, sign * 46.2), 7)
		end
		for _, x in { -66, -22, 22, 66 } do
			local facing = if sign > 0 then math.pi else 0
			Decor.bench(props, CFrame.new(x, 0, sign * 46.4) * CFrame.Angles(0, facing, 0))
		end
		for _, x in { -110, -58, 58, 110 } do
			Decor.bush(props, Vector3.new(x, 0, sign * 47), 1.1, rng, true)
		end
	end
	Decor.signpost(props, CFrame.new(-22, 0, 47.5) * CFrame.Angles(0, math.pi, 0), "Houses ↑ Plaza ↓", Palette.Cream)
	Decor.signpost(props, CFrame.new(22, 0, -47.5), "Houses ↓ Plaza ↑", Palette.Cream)
	Decor.barrel(props, Vector3.new(-108, 0, 47))
	Decor.crate(props, Vector3.new(-106, 0, 46), 0.4)
	Decor.barrel(props, Vector3.new(108, 0, -47))

	-- forest border
	local forest = Build.folder(folder, "Forest")
	local step = 12
	for x = -GROUND_HALF_X + 6, GROUND_HALF_X - 6, step do
		for z = -GROUND_HALF_Z + 6, GROUND_HALF_Z - 6, step do
			local px = x + (rng:NextNumber() - 0.5) * 7
			local pz = z + (rng:NextNumber() - 0.5) * 7
			if not isCore(px, pz) then
				local roll = rng:NextNumber()
				local pos = Vector3.new(px, 0, pz)
				if roll < 0.5 then
					local kinds = { "round", "pine", "pine", "cherry", "round" }
					Decor.tree(forest, pos, kinds[rng:NextInteger(1, #kinds)], 0.9 + rng:NextNumber() * 0.7, rng)
				elseif roll < 0.68 then
					Decor.bush(forest, pos, 0.9 + rng:NextNumber() * 0.5, rng, rng:NextNumber() > 0.6)
				elseif roll < 0.78 then
					Decor.rock(forest, pos, 0.8 + rng:NextNumber() * 1.2, rng)
				elseif roll < 0.9 then
					Decor.flowers(forest, pos, 3.5, 10, rng)
				elseif roll < 0.95 then
					Decor.mushrooms(forest, pos, rng)
				else
					Decor.stump(forest, pos, 0.9 + rng:NextNumber() * 0.5)
				end
			end
		end
	end
	-- a few tree clumps inside the core corners (between promenades and the world edge)
	for _, corner in { Vector3.new(-120, 0, 70), Vector3.new(120, 0, 70), Vector3.new(-120, 0, -70), Vector3.new(120, 0, -70) } do
		for _ = 1, 3 do
			local offset = Vector3.new((rng:NextNumber() - 0.5) * 16, 0, (rng:NextNumber() - 0.5) * 30)
			Decor.tree(forest, corner + offset, "round", 1.2, rng)
		end
	end

	-- invisible boundary so nobody wanders off the map
	local boundary = Build.folder(folder, "Boundary")
	local wallProps = { Transparency = 1, CanQuery = false, CastShadow = false }
	Build.part(boundary, "North", Vector3.new(GROUND_HALF_X * 2, 60, 2), CFrame.new(0, 30, GROUND_HALF_Z), Palette.Cream, Enum.Material.SmoothPlastic, wallProps)
	Build.part(boundary, "South", Vector3.new(GROUND_HALF_X * 2, 60, 2), CFrame.new(0, 30, -GROUND_HALF_Z), Palette.Cream, Enum.Material.SmoothPlastic, wallProps)
	Build.part(boundary, "East", Vector3.new(2, 60, GROUND_HALF_Z * 2), CFrame.new(GROUND_HALF_X, 30, 0), Palette.Cream, Enum.Material.SmoothPlastic, wallProps)
	Build.part(boundary, "West", Vector3.new(2, 60, GROUND_HALF_Z * 2), CFrame.new(-GROUND_HALF_X, 30, 0), Palette.Cream, Enum.Material.SmoothPlastic, wallProps)
	return folder
end

return EnvironmentBuilder
