--[[
	Ground, promenades, the paths from every gate to the road, a few lamps, the forest border and the
	invisible world boundary. Deliberately calm: no signs, barrels or random props.
	Everything is mirror-symmetric around the road (z = 0) and the plaza (x = 0).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Build)
local Decor = require(script.Parent.Decor)
local Palette = require(script.Parent.Palette)

local WorldLayout = require(ReplicatedStorage.Modules.WorldLayout)

local EnvironmentBuilder = {}

local COSMETIC = Enum.Material.Cobblestone

local GROUND_HALF_X = WorldLayout.GroundHalfX
local GROUND_HALF_Z = WorldLayout.GroundHalfZ
local LOT_BACK = WorldLayout.GateDistance + WorldLayout.LotDepth -- |z| of the back hedges

-- True for points that belong to the playable core (road, promenades, lots, plaza annexes).
local function isCore(x: number, z: number): boolean
	if math.abs(z) < 26 and math.abs(x) > 148 then
		return true -- burrow and exit tunnel
	end
	return math.abs(x) < 160 and math.abs(z) < LOT_BACK + 8
end

function EnvironmentBuilder.build(parent: Instance, rng: Random): Folder
	local folder = Build.folder(parent, "Environment")

	-- ground + soft grass patches so the lawn isn't one flat colour
	Build.part(folder, "Ground", Vector3.new(GROUND_HALF_X * 2, 4, GROUND_HALF_Z * 2), CFrame.new(0, -2, 0), Palette.Grass, Enum.Material.Grass)
	local patches = Build.folder(folder, "GrassPatches")
	for _ = 1, 40 do
		local x = (rng:NextNumber() * 2 - 1) * (GROUND_HALF_X - 8)
		local z = (rng:NextNumber() * 2 - 1) * (GROUND_HALF_Z - 8)
		local radius = 6 + rng:NextNumber() * 12
		local color = if rng:NextNumber() > 0.5 then Palette.GrassLight else Palette.GrassDark
		Build.pillar(patches, "Patch", radius * 2, 0.04, CFrame.new(x, 0.01, z), color, Enum.Material.Grass, { CanCollide = false, CastShadow = false })
	end

	-- promenades (the wide walkways in front of the houses; hamsters roll home along them too)
	local walks = Build.folder(folder, "Promenades")
	local promenadeLength = 320
	for _, sign in { 1, -1 } do
		local z = sign * WorldLayout.PromenadeZ
		Build.part(walks, "Promenade", Vector3.new(promenadeLength, 0.2, WorldLayout.PromenadeHalfWidth * 2), CFrame.new(0, 0.1, z), Palette.Pavement, COSMETIC, { CanCollide = false })
		for _, edge in { -1, 1 } do
			Build.deco(walks, "PromenadeEdge", Vector3.new(promenadeLength, 0.24, 0.5), CFrame.new(0, 0.11, z + edge * (WorldLayout.PromenadeHalfWidth - 0.25)), Palette.PavementDark, COSMETIC)
		end
		-- a paved path from every gate straight to the road
		for _, x in WorldLayout.HouseColumns do
			Build.part(walks, "GatePath", Vector3.new(7, 0.16, WorldLayout.GateDistance - WorldLayout.RoadHalfWidth), CFrame.new(x, 0.09, sign * (WorldLayout.GateDistance + WorldLayout.RoadHalfWidth) / 2), Palette.PavementDark, COSMETIC, { CanCollide = false })
		end
	end

	-- street furniture: a few lamps and benches between the road and the promenade
	local props = Build.folder(folder, "Props")
	for _, sign in { 1, -1 } do
		for _, x in { -130, -76, 76, 130 } do
			Decor.lamp(props, Vector3.new(x, 0, sign * 10.2), 7)
		end
		for _, x in { -34, 34 } do
			local facing = if sign > 0 then math.pi else 0
			Decor.bench(props, CFrame.new(x, 0, sign * 10.6) * CFrame.Angles(0, facing, 0))
		end
	end

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
				elseif roll < 0.7 then
					Decor.bush(forest, pos, 0.9 + rng:NextNumber() * 0.5, rng, rng:NextNumber() > 0.6)
				elseif roll < 0.8 then
					Decor.rock(forest, pos, 0.8 + rng:NextNumber() * 1.2, rng)
				elseif roll < 0.86 then
					Decor.stump(forest, pos, 0.9 + rng:NextNumber() * 0.5)
				end
			end
		end
	end

	-- scenery beyond the invisible walls: a darker lawn with a sparse ring of pines, so the world has no visible edge
	local outer = Build.folder(folder, "Beyond")
	Build.part(outer, "OuterGround", Vector3.new(GROUND_HALF_X * 2 + 300, 4, GROUND_HALF_Z * 2 + 300), CFrame.new(0, -2.1, 0), Palette.GrassDark, Enum.Material.Grass, { CanCollide = false })
	for x = -GROUND_HALF_X - 150, GROUND_HALF_X + 150, 34 do
		for z = -GROUND_HALF_Z - 150, GROUND_HALF_Z + 150, 34 do
			if math.abs(x) > GROUND_HALF_X + 6 or math.abs(z) > GROUND_HALF_Z + 6 then
				local pos = Vector3.new(x + (rng:NextNumber() - 0.5) * 14, 0, z + (rng:NextNumber() - 0.5) * 14)
				if rng:NextNumber() < 0.75 then
					Decor.tree(outer, pos, "pine", 1.3 + rng:NextNumber() * 1.0, rng)
				end
			end
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
