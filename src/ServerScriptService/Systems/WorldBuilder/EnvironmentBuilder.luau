--[[
	Ground, promenades, the paths from every gate to the road, a few lamps, and the scenery around the playable
	area: forest, rocks, cliffs, hills, lakes, a ring of mountains and drifting clouds. Deliberately calm: no signs,
	barrels or random props. The playable core is mirror-symmetric around the road (z = 0) and the plaza (x = 0).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Build)
local Decor = require(script.Parent.Decor)
local Palette = require(script.Parent.Palette)

local WorldLayout = require(ReplicatedStorage.Modules.WorldLayout)

local EnvironmentBuilder = {}

local COSMETIC = Enum.Material.Cobblestone
local GRASS = Enum.Material.Grass
local ROCK = Enum.Material.Slate

local GROUND_HALF_X = WorldLayout.GroundHalfX
local GROUND_HALF_Z = WorldLayout.GroundHalfZ
local LOT_BACK = WorldLayout.GateDistance + WorldLayout.LotDepth -- |z| of the back hedges
local LOT_OUTER_X = WorldLayout.HouseColumns[#WorldLayout.HouseColumns] + WorldLayout.LotHalfWidth

local ROCK_COLORS = { Color3.fromRGB(132, 128, 142), Color3.fromRGB(150, 144, 156), Color3.fromRGB(118, 116, 132) }
local FAR_TINT = Color3.fromRGB(150, 160, 196) -- far mountains fade towards the haze colour

-- True for points that belong to the playable core (road, promenades, lots, plaza annexes, burrow and exit).
local function isCore(x: number, z: number): boolean
	if math.abs(z) < 40 and math.abs(x) > LOT_OUTER_X - 20 then
		return true -- burrow and exit tunnel
	end
	return math.abs(x) < LOT_OUTER_X + 8 and math.abs(z) < LOT_BACK + 8
end

local function lerpColor(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, t)
end

---------------------------------------------------------------------------
-- backdrop: mountains, hills, lakes, cliffs, clouds
---------------------------------------------------------------------------

-- A mountain made of stacked, narrowing rock slabs plus a snow cap. `fade` (0..1) tints distant ones towards the haze.
local function mountain(parent: Instance, base: Vector3, width: number, height: number, fade: number, rng: Random)
	local model = Build.model(parent, "Mountain")
	local rock = lerpColor(ROCK_COLORS[rng:NextInteger(1, #ROCK_COLORS)], FAR_TINT, fade)
	local layers = 5
	local yaw = rng:NextNumber() * math.pi
	for layer = 1, layers do
		local t = (layer - 1) / layers
		local layerWidth = width * (1 - t * 0.8) * (0.9 + rng:NextNumber() * 0.2)
		local layerHeight = height / layers * 1.35
		local offset = Vector3.new((rng:NextNumber() - 0.5) * width * 0.08, 0, (rng:NextNumber() - 0.5) * width * 0.08)
		local color = if layer > layers - 1 then Color3.fromRGB(246, 248, 255) else lerpColor(rock, Color3.fromRGB(96, 150, 96), math.max(0, 0.45 - t * 1.1) * (1 - fade))
		Build.blob(
			model,
			"Slice" .. layer,
			Vector3.new(layerWidth, layerHeight, layerWidth * 0.9),
			CFrame.new(base + offset + Vector3.new(0, height * t + layerHeight * 0.3, 0)) * CFrame.Angles(0, yaw + layer * 0.3, 0),
			color,
			if layer > layers - 1 then Enum.Material.Snow else ROCK,
			{ CanCollide = false, CastShadow = false }
		)
	end
	return model
end

local function hill(parent: Instance, pos: Vector3, radius: number, height: number, rng: Random, withTrees: boolean)
	local model = Build.model(parent, "Hill")
	Build.blob(model, "Hill", Vector3.new(radius * 2, height * 2, radius * 1.7), CFrame.new(pos.X, pos.Y, pos.Z) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0), if rng:NextNumber() > 0.5 then Palette.Grass else Palette.GrassLight, GRASS, { CanCollide = false, CastShadow = false })
	if withTrees then
		for _ = 1, math.floor(radius / 9) do
			local angle = rng:NextNumber() * math.pi * 2
			local distance = rng:NextNumber() * radius * 0.55
			local tx, tz = pos.X + math.cos(angle) * distance, pos.Z + math.sin(angle) * distance
			local topY = pos.Y + height * math.sqrt(math.max(0, 1 - (distance / radius) ^ 2)) - 1.5
			Decor.tree(model, Vector3.new(tx, topY, tz), if rng:NextNumber() > 0.4 then "pine" else "round", 1.4 + rng:NextNumber() * 0.8, rng)
		end
	end
	return model
end

local function lake(parent: Instance, center: Vector3, radius: number)
	local model = Build.model(parent, "Lake")
	Build.pillar(model, "Shore", radius * 2 + 16, 0.4, CFrame.new(center.X, -0.05, center.Z), Color3.fromRGB(214, 200, 164), Enum.Material.Sand, { CanCollide = false })
	local water = Build.pillar(model, "Water", radius * 2, 0.6, CFrame.new(center.X, 0.05, center.Z), Palette.Water, Enum.Material.Glass, { CanCollide = false, Transparency = 0.3, Reflectance = 0.25, CastShadow = false })
	water:SetAttribute("Ripple", true)
	Build.pillar(model, "Deep", radius * 1.3, 0.62, CFrame.new(center.X, 0.07, center.Z), Color3.fromRGB(86, 160, 214), Enum.Material.Glass, { CanCollide = false, Transparency = 0.45, CastShadow = false })
	return model
end

local function cliffWall(parent: Instance, center: Vector3, length: number, alongX: boolean, height: number, rng: Random)
	local model = Build.model(parent, "Cliff")
	local count = math.floor(length / 20)
	for index = 1, count do
		local offset = -length / 2 + (index - 0.5) * (length / count)
		local w = 22 + rng:NextNumber() * 12
		local h = height * (0.55 + rng:NextNumber() * 0.7)
		local pos = center + (if alongX then Vector3.new(offset, h / 2 - 3, 0) else Vector3.new(0, h / 2 - 3, offset)) + Vector3.new((rng:NextNumber() - 0.5) * 6, 0, (rng:NextNumber() - 0.5) * 6)
		local color = ROCK_COLORS[rng:NextInteger(1, #ROCK_COLORS)]
		Build.part(model, "Rock", Vector3.new(w, h, w * 0.8), CFrame.new(pos) * CFrame.Angles(math.rad((rng:NextNumber() - 0.5) * 8), rng:NextNumber() * math.pi, math.rad((rng:NextNumber() - 0.5) * 8)), color, ROCK, { CanCollide = false })
		if rng:NextNumber() > 0.5 then
			Build.part(model, "Moss", Vector3.new(w * 0.9, 1.4, w * 0.7), CFrame.new(pos + Vector3.new(0, h / 2, 0)), Palette.GrassDark, GRASS, { CanCollide = false })
		end
	end
	return model
end

local function cloud(parent: Instance, position: Vector3, scale: number, speed: number, rng: Random)
	local model = Build.model(parent, "Cloud")
	local puffs = rng:NextInteger(4, 6)
	for puff = 1, puffs do
		local size = (14 + rng:NextNumber() * 12) * scale
		Build.blob(model, "Puff", Vector3.new(size * 1.5, size * 0.7, size), CFrame.new(position + Vector3.new((puff - puffs / 2) * 11 * scale, rng:NextNumber() * 4 * scale, (rng:NextNumber() - 0.5) * 10 * scale)), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, { CanCollide = false, CanQuery = false, CastShadow = false, Transparency = 0.12 })
	end
	model:SetAttribute("Speed", speed)
	model:AddTag("Cloud")
	return model
end

local function buildBackdrop(folder: Folder, rng: Random)
	local backdrop = Build.folder(folder, "Backdrop")
	local lakes = {
		{ Vector3.new(-GROUND_HALF_X - 70, 0, -GROUND_HALF_Z - 110), 78 },
		{ Vector3.new(GROUND_HALF_X + 90, 0, GROUND_HALF_Z + 120), 64 },
		{ Vector3.new(GROUND_HALF_X + 120, 0, -GROUND_HALF_Z - 40), 46 },
	}

	-- mountain ring: three rows, the far ones are bigger and hazier
	local rows = { { 360, 90, 0.2 }, { 470, 150, 0.45 }, { 600, 230, 0.7 } }
	for _, row in rows do
		local radiusX, height, fade = row[1] + GROUND_HALF_X - 250, row[2], row[3]
		local radiusZ = row[1] + GROUND_HALF_Z - 175
		local count = 16 + math.floor(row[1] / 60)
		for index = 1, count do
			local angle = (index / count) * math.pi * 2 + rng:NextNumber() * 0.15
			local pos = Vector3.new(math.cos(angle) * radiusX, -2, math.sin(angle) * radiusZ)
			local size = height * (1.5 + rng:NextNumber() * 0.9)
			local blocked = false
			for _, entry in lakes do
				blocked = blocked or (pos - entry[1]).Magnitude < entry[2] + size * 0.45
			end
			if blocked then
				continue
			end
			mountain(backdrop, pos, size, height * (0.7 + rng:NextNumber() * 0.6), fade, rng)
		end
	end

	-- rolling hills just outside the playable ground
	for _ = 1, 26 do
		local angle = rng:NextNumber() * math.pi * 2
		local distance = 1.12 + rng:NextNumber() * 0.5
		local pos = Vector3.new(math.cos(angle) * (GROUND_HALF_X + 40) * distance, -4, math.sin(angle) * (GROUND_HALF_Z + 40) * distance)
		local radius = 40 + rng:NextNumber() * 50
		local blocked = false
		for _, entry in lakes do
			blocked = blocked or (pos - entry[1]).Magnitude < entry[2] + radius
		end
		if not blocked then
			hill(backdrop, pos, radius, 12 + rng:NextNumber() * 20, rng, true)
		end
	end

	-- lakes
	for _, entry in lakes do
		lake(backdrop, entry[1], entry[2])
	end

	-- cliffs hugging the north / south edges of the playable ground
	cliffWall(backdrop, Vector3.new(0, 0, GROUND_HALF_Z + 22), GROUND_HALF_X * 1.6, true, 46, rng)
	cliffWall(backdrop, Vector3.new(0, 0, -GROUND_HALF_Z - 22), GROUND_HALF_X * 1.6, true, 46, rng)
	cliffWall(backdrop, Vector3.new(GROUND_HALF_X + 22, 0, 0), GROUND_HALF_Z * 1.4, false, 36, rng)
	cliffWall(backdrop, Vector3.new(-GROUND_HALF_X - 22, 0, 0), GROUND_HALF_Z * 1.4, false, 36, rng)

	-- clouds (drift on the client, see NatureController)
	local clouds = Build.folder(backdrop, "Clouds")
	for _ = 1, 16 do
		local x = (rng:NextNumber() * 2 - 1) * 650
		local z = (rng:NextNumber() * 2 - 1) * 450
		cloud(clouds, Vector3.new(x, 150 + rng:NextNumber() * 90, z), 1 + rng:NextNumber() * 1.4, 1.5 + rng:NextNumber() * 2.5, rng)
	end
end

---------------------------------------------------------------------------
-- playable ground
---------------------------------------------------------------------------

function EnvironmentBuilder.build(parent: Instance, rng: Random): Folder
	local folder = Build.folder(parent, "Environment")

	-- ground + soft grass patches so the lawn isn't one flat colour
	Build.part(folder, "Ground", Vector3.new(GROUND_HALF_X * 2, 4, GROUND_HALF_Z * 2), CFrame.new(0, -2, 0), Palette.Grass, GRASS)
	local patches = Build.folder(folder, "GrassPatches")
	for _ = 1, 60 do
		local x = (rng:NextNumber() * 2 - 1) * (GROUND_HALF_X - 8)
		local z = (rng:NextNumber() * 2 - 1) * (GROUND_HALF_Z - 8)
		local radius = 8 + rng:NextNumber() * 16
		local color = if rng:NextNumber() > 0.5 then Palette.GrassLight else Palette.GrassDark
		Build.pillar(patches, "Patch", radius * 2, 0.04, CFrame.new(x, 0.01, z), color, GRASS, { CanCollide = false, CastShadow = false })
	end

	-- promenades (the wide walkways in front of the houses; hamsters roll home along them too)
	local walks = Build.folder(folder, "Promenades")
	local promenadeLength = LOT_OUTER_X * 2 + 20
	for _, sign in { 1, -1 } do
		local z = sign * WorldLayout.PromenadeZ
		Build.part(walks, "Promenade", Vector3.new(promenadeLength, 0.2, WorldLayout.PromenadeHalfWidth * 2), CFrame.new(0, 0.1, z), Palette.Pavement, COSMETIC, { CanCollide = false })
		for _, edge in { -1, 1 } do
			Build.deco(walks, "PromenadeEdge", Vector3.new(promenadeLength, 0.24, 0.6), CFrame.new(0, 0.11, z + edge * (WorldLayout.PromenadeHalfWidth - 0.3)), Palette.PavementDark, COSMETIC)
		end
		-- a paved path from every gate straight to the road
		for _, x in WorldLayout.HouseColumns do
			Build.part(walks, "GatePath", Vector3.new(11, 0.16, WorldLayout.GateDistance - WorldLayout.RoadHalfWidth), CFrame.new(x, 0.09, sign * (WorldLayout.GateDistance + WorldLayout.RoadHalfWidth) / 2), Palette.PavementDark, COSMETIC, { CanCollide = false })
		end
	end

	-- street furniture: a few lamps and benches between the road and the promenade
	local props = Build.folder(folder, "Props")
	for _, sign in { 1, -1 } do
		for _, x in { -190, -128, -64, 64, 128, 190 } do
			Decor.lamp(props, Vector3.new(x, 0, sign * 17), 7)
		end
		for _, x in { -44, 44 } do
			local facing = if sign > 0 then math.pi else 0
			Decor.bench(props, CFrame.new(x, 0, sign * 17.5) * CFrame.Angles(0, facing, 0))
		end
	end

	-- forest in the ring between the lots and the edge of the ground
	local forest = Build.folder(folder, "Forest")
	local step = 13
	for x = -GROUND_HALF_X + 6, GROUND_HALF_X - 6, step do
		for z = -GROUND_HALF_Z + 6, GROUND_HALF_Z - 6, step do
			local px = x + (rng:NextNumber() - 0.5) * 8
			local pz = z + (rng:NextNumber() - 0.5) * 8
			if not isCore(px, pz) then
				local roll = rng:NextNumber()
				local pos = Vector3.new(px, 0, pz)
				if roll < 0.55 then
					local kinds = { "round", "pine", "pine", "cherry", "round" }
					Decor.tree(forest, pos, kinds[rng:NextInteger(1, #kinds)], 1 + rng:NextNumber() * 0.9, rng)
				elseif roll < 0.7 then
					Decor.bush(forest, pos, 0.9 + rng:NextNumber() * 0.5, rng, rng:NextNumber() > 0.6)
				elseif roll < 0.8 then
					Decor.rock(forest, pos, 1 + rng:NextNumber() * 2, rng)
				end
			end
		end
	end

	-- scenery beyond the invisible walls: a darker lawn so the world has no visible edge
	local outer = Build.folder(folder, "Beyond")
	Build.part(outer, "OuterGround", Vector3.new(GROUND_HALF_X * 2 + 1400, 4, GROUND_HALF_Z * 2 + 1100), CFrame.new(0, -2.15, 0), Palette.GrassDark, GRASS, { CanCollide = false })
	for x = -GROUND_HALF_X - 140, GROUND_HALF_X + 140, 30 do
		for z = -GROUND_HALF_Z - 140, GROUND_HALF_Z + 140, 30 do
			if math.abs(x) > GROUND_HALF_X + 8 or math.abs(z) > GROUND_HALF_Z + 8 then
				local pos = Vector3.new(x + (rng:NextNumber() - 0.5) * 14, 0, z + (rng:NextNumber() - 0.5) * 14)
				if rng:NextNumber() < 0.7 then
					Decor.tree(outer, pos, if rng:NextNumber() > 0.3 then "pine" else "round", 1.4 + rng:NextNumber() * 1.1, rng)
				end
			end
		end
	end

	buildBackdrop(folder, rng)

	-- invisible boundary so nobody wanders off the map
	local boundary = Build.folder(folder, "Boundary")
	local wallProps = { Transparency = 1, CanQuery = false, CastShadow = false }
	Build.part(boundary, "North", Vector3.new(GROUND_HALF_X * 2, 80, 2), CFrame.new(0, 40, GROUND_HALF_Z), Palette.Cream, Enum.Material.SmoothPlastic, wallProps)
	Build.part(boundary, "South", Vector3.new(GROUND_HALF_X * 2, 80, 2), CFrame.new(0, 40, -GROUND_HALF_Z), Palette.Cream, Enum.Material.SmoothPlastic, wallProps)
	Build.part(boundary, "East", Vector3.new(2, 80, GROUND_HALF_Z * 2), CFrame.new(GROUND_HALF_X, 40, 0), Palette.Cream, Enum.Material.SmoothPlastic, wallProps)
	Build.part(boundary, "West", Vector3.new(2, 80, GROUND_HALF_Z * 2), CFrame.new(-GROUND_HALF_X, 40, 0), Palette.Cream, Enum.Material.SmoothPlastic, wallProps)
	return folder
end

return EnvironmentBuilder
