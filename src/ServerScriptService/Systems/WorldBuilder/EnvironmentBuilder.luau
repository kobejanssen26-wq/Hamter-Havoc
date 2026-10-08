--[[
	The land around the hamster road: ground, promenades, gate driveways, street lamps, the forest
	ring, and a backdrop of hills, a lake, mountains, clouds and birds.

	  playable    |x| < GroundHalfX, |z| < GroundHalfZ (invisible walls at the edge)
	  forest      the outer strip of the playable area and just beyond it
	  backdrop    hills (~350-500 studs), a lake in the west, rocky mountains (650-1200 studs),
	              clouds high above. Backdrop parts never collide and cast no shadows.

	Deliberately calm: big pieces instead of many small props. Mirror-symmetric around the road.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Build)
local Decor = require(script.Parent.Decor)
local Palette = require(script.Parent.Palette)

local PathConfig = require(ReplicatedStorage.Modules.PathConfig)
local WorldLayout = require(ReplicatedStorage.Modules.WorldLayout)

local EnvironmentBuilder = {}

local PAVING = Enum.Material.Cobblestone

local GROUND_HALF_X = WorldLayout.GroundHalfX
local GROUND_HALF_Z = WorldLayout.GroundHalfZ
local LOT_BACK = WorldLayout.GateDistance + WorldLayout.LotDepth -- |z| of the back of the lots
local OUTER_X = WorldLayout.HouseColumns[#WorldLayout.HouseColumns] + WorldLayout.LotHalfWidth -- x of the last lot edge

-- True for points that belong to the playable core (road, promenades, lots, burrow, exit).
local function isCore(x: number, z: number): boolean
	if math.abs(z) < 34 then
		return math.abs(x) < PathConfig.Length / 2 + 26
	end
	return math.abs(x) < OUTER_X + 6 and math.abs(z) < LOT_BACK + 6
end

local function buildGround(folder: Folder, rng: Random)
	Build.part(folder, "Ground", Vector3.new(GROUND_HALF_X * 2, 4, GROUND_HALF_Z * 2), CFrame.new(0, -2, 0), Palette.Grass, Enum.Material.Grass)
	-- a few large, soft colour patches so the lawn isn't flat (big and few, not confetti)
	local patches = Build.folder(folder, "GrassPatches")
	for _ = 1, 14 do
		local x = (rng:NextNumber() * 2 - 1) * (GROUND_HALF_X - 30)
		local z = (rng:NextNumber() * 2 - 1) * (GROUND_HALF_Z - 30)
		local radius = 22 + rng:NextNumber() * 26
		local color = if rng:NextNumber() > 0.5 then Palette.GrassLight else Palette.GrassDark
		Build.pillar(patches, "Patch", radius * 2, 0.04, CFrame.new(x, 0.01, z), color, Enum.Material.Grass, { CanCollide = false, CastShadow = false, Transparency = 0.35 })
	end
end

local function buildWalkways(folder: Folder)
	local walks = Build.folder(folder, "Promenades")
	local length = (OUTER_X + 12) * 2
	for _, sign in { 1, -1 } do
		local z = sign * WorldLayout.PromenadeZ
		Build.part(walks, "Promenade", Vector3.new(length, 0.2, WorldLayout.PromenadeHalfWidth * 2), CFrame.new(0, 0.1, z), Palette.Pavement, PAVING, { CanCollide = false })
		for _, edge in { -1, 1 } do
			Build.deco(walks, "PromenadeEdge", Vector3.new(length, 0.26, 0.6), CFrame.new(0, 0.12, z + edge * (WorldLayout.PromenadeHalfWidth - 0.3)), Palette.PavementDark, PAVING)
		end
		-- driveway from the promenade to every gate
		local inner = WorldLayout.PromenadeZ + WorldLayout.PromenadeHalfWidth
		local depth = WorldLayout.GateDistance - inner + 1
		for _, x in WorldLayout.HouseColumns do
			Build.part(walks, "GatePath", Vector3.new(12, 0.18, depth), CFrame.new(x, 0.09, sign * (inner + depth / 2 - 0.5)), Palette.PavementDark, PAVING, { CanCollide = false })
		end
	end
end

-- Street lamps and trees on the grass strips between the plots; lamps at the plaza corners.
local function buildStreetscape(folder: Folder, rng: Random)
	local props = Build.folder(folder, "Props")
	local columns = WorldLayout.HouseColumns
	local gaps = {}
	for index = 1, #columns - 1 do
		local a, b = columns[index], columns[index + 1]
		if math.abs(a + b) > 1 then
			table.insert(gaps, (a + b) / 2) -- between two plots on the same side of the plaza
		end
	end
	table.insert(gaps, columns[1] - WorldLayout.LotHalfWidth - 10)
	table.insert(gaps, columns[#columns] + WorldLayout.LotHalfWidth + 10)

	local lampZ = WorldLayout.PromenadeZ + WorldLayout.PromenadeHalfWidth + 2.5
	for _, sign in { 1, -1 } do
		local facing = if sign > 0 then 0 else math.pi
		for _, x in gaps do
			Decor.streetLamp(props, CFrame.new(x, 0, sign * lampZ) * CFrame.Angles(0, facing, 0), 12)
			Decor.largeTree(props, Vector3.new(x, 0, sign * (WorldLayout.GateDistance + 22)), 0.95 + rng:NextNumber() * 0.15, rng)
		end
		for _, x in { -WorldLayout.PlazaHalfWidth - 4, WorldLayout.PlazaHalfWidth + 4 } do
			Decor.streetLamp(props, CFrame.new(x, 0, sign * lampZ) * CFrame.Angles(0, facing, 0), 12)
		end
	end
end

-- Forest: big trees in groves on the outer strip of the map, denser just beyond the edge.
local function buildForest(folder: Folder, rng: Random)
	local forest = Build.folder(folder, "Forest")
	local step = 16
	for x = -GROUND_HALF_X - 60, GROUND_HALF_X + 60, step do
		for z = -GROUND_HALF_Z - 60, GROUND_HALF_Z + 60, step do
			local px = x + (rng:NextNumber() - 0.5) * 10
			local pz = z + (rng:NextNumber() - 0.5) * 10
			if not isCore(px, pz) then
				local outside = math.abs(px) > GROUND_HALF_X or math.abs(pz) > GROUND_HALF_Z
				local density = if outside then 0.8 else 0.5
				-- groves with natural clearings
				local clearing = math.noise(px / 70, pz / 70, 3.1) > 0.25
				if not clearing and rng:NextNumber() < density then
					local pos = Vector3.new(px, 0, pz)
					local roll = rng:NextNumber()
					if roll < 0.45 then
						Decor.tree(forest, pos, "pine", 1.5 + rng:NextNumber() * 0.9, rng)
					elseif roll < 0.8 then
						Decor.largeTree(forest, pos, 0.8 + rng:NextNumber() * 0.35, rng, if rng:NextNumber() < 0.5 then Palette.Leaf else Palette.LeafDark)
					elseif roll < 0.88 then
						Decor.largeTree(forest, pos, 0.75, rng, Palette.Cherry)
					else
						Decor.rock(forest, pos, 1.4 + rng:NextNumber(), rng)
					end
				end
			end
		end
	end
end

local function buildBackdrop(folder: Folder, rng: Random)
	local backdrop = Build.folder(folder, "Backdrop")

	-- outer ground so the world never ends in the void
	Build.part(backdrop, "OuterGround", Vector3.new(3400, 4, 3400), CFrame.new(0, -2.15, 0), Palette.GrassDark, Enum.Material.Grass, { CanCollide = false, CastShadow = false })

	-- rolling hills just beyond the forest
	local hills = Build.folder(backdrop, "Hills")
	for index = 1, 26 do
		local angle = (index / 26) * math.pi * 2 + rng:NextNumber() * 0.15
		local radiusX = GROUND_HALF_X + 140 + rng:NextNumber() * 120
		local radiusZ = GROUND_HALF_Z + 150 + rng:NextNumber() * 110
		local pos = Vector3.new(math.cos(angle) * radiusX, -8, math.sin(angle) * radiusZ)
		local size = Vector3.new(180 + rng:NextNumber() * 140, 50 + rng:NextNumber() * 40, 140 + rng:NextNumber() * 100)
		local color = if index % 3 == 0 then Palette.GrassLight elseif index % 3 == 1 then Palette.Grass else Palette.GrassDark
		Decor.hill(hills, pos, size, color)
		if rng:NextNumber() < 0.6 then
			for _ = 1, 3 do
				local offset = Vector3.new((rng:NextNumber() - 0.5) * size.X * 0.5, 0, (rng:NextNumber() - 0.5) * size.Z * 0.4)
				Decor.tree(hills, pos + offset + Vector3.new(0, size.Y * 0.38, 0), "pine", 2.2 + rng:NextNumber(), rng)
			end
		end
	end

	-- a lake behind the hamster burrow (west) with a sandy, stony shore
	local lake = Build.model(backdrop, "Lake")
	local lakeCenter = Vector3.new(-GROUND_HALF_X - 230, 0, 0)
	Build.pillar(lake, "Shore", 300, 0.6, CFrame.new(lakeCenter + Vector3.new(0, 0.1, 0)), Color3.fromRGB(214, 200, 168), Enum.Material.Sand, { CanCollide = false, CastShadow = false })
	local water = Build.pillar(lake, "Water", 280, 0.6, CFrame.new(lakeCenter + Vector3.new(0, 0.3, 0)), Color3.fromRGB(96, 170, 214), Enum.Material.Glass, { CanCollide = false, CastShadow = false, Transparency = 0.15, Reflectance = 0.25 })
	water:SetAttribute("Ripple", true)
	for _ = 1, 10 do
		local angle = rng:NextNumber() * math.pi * 2
		Decor.rock(lake, lakeCenter + Vector3.new(math.cos(angle) * 142, 0, math.sin(angle) * 142), 2 + rng:NextNumber() * 1.5, rng)
	end

	-- mountains: a near ring (greener, crisper) and a far ring (bluer, faded into the haze)
	local mountains = Build.folder(backdrop, "Mountains")
	local function ring(count: number, radiusX: number, radiusZ: number, width: number, height: number, tint: number, snowChance: number)
		for index = 1, count do
			local angle = (index / count) * math.pi * 2 + rng:NextNumber() * 0.2
			local pos = Vector3.new(math.cos(angle) * radiusX * (0.9 + rng:NextNumber() * 0.2), -10, math.sin(angle) * radiusZ * (0.9 + rng:NextNumber() * 0.2))
			local w = width * (0.75 + rng:NextNumber() * 0.5)
			local h = height * (0.7 + rng:NextNumber() * 0.6)
			Decor.mountain(mountains, pos, w, h, rng, tint, rng:NextNumber() < snowChance)
		end
	end
	ring(16, 760, 640, 300, 210, 0.25, 0.4)
	ring(22, 1150, 1000, 420, 330, 0.6, 0.9)

	-- clouds drift slowly overhead
	local clouds = Build.folder(backdrop, "Clouds")
	for _ = 1, 18 do
		local pos = Vector3.new((rng:NextNumber() - 0.5) * 1600, 220 + rng:NextNumber() * 90, (rng:NextNumber() - 0.5) * 1400)
		Decor.cloud(clouds, pos, 0.9 + rng:NextNumber() * 0.9, rng)
	end

	-- a few birds circling over the forest and the plaza
	local birds = Build.folder(backdrop, "Birds")
	for index = 1, 5 do
		local center = Vector3.new((index - 3) * 110, 70 + rng:NextNumber() * 30, (if index % 2 == 0 then 1 else -1) * (90 + rng:NextNumber() * 60))
		Decor.bird(birds, center, 30 + rng:NextNumber() * 25, rng)
	end
end

local function buildBoundary(folder: Folder)
	local boundary = Build.folder(folder, "Boundary")
	local wallProps = { Transparency = 1, CanQuery = false, CastShadow = false }
	Build.part(boundary, "North", Vector3.new(GROUND_HALF_X * 2, 80, 2), CFrame.new(0, 40, GROUND_HALF_Z), Palette.Cream, Enum.Material.SmoothPlastic, wallProps)
	Build.part(boundary, "South", Vector3.new(GROUND_HALF_X * 2, 80, 2), CFrame.new(0, 40, -GROUND_HALF_Z), Palette.Cream, Enum.Material.SmoothPlastic, wallProps)
	Build.part(boundary, "East", Vector3.new(2, 80, GROUND_HALF_Z * 2), CFrame.new(GROUND_HALF_X, 40, 0), Palette.Cream, Enum.Material.SmoothPlastic, wallProps)
	Build.part(boundary, "West", Vector3.new(2, 80, GROUND_HALF_Z * 2), CFrame.new(-GROUND_HALF_X, 40, 0), Palette.Cream, Enum.Material.SmoothPlastic, wallProps)
end

function EnvironmentBuilder.build(parent: Instance, rng: Random): Folder
	local folder = Build.folder(parent, "Environment")
	buildGround(folder, rng)
	buildWalkways(folder)
	buildStreetscape(folder, rng)
	buildForest(folder, rng)
	buildBackdrop(folder, rng)
	buildBoundary(folder)
	return folder
end

return EnvironmentBuilder
