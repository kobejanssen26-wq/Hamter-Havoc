--[[
	Ground, promenades, the paths from every gate to the road, a few lamps, and the scenery around the playable
	area: forest, rocks, cliffs, hills, lakes, layered angular mountain ranges (MountainBuilder) and drifting clouds.
	The result is baked into the place file and then edited in Roblox Studio (attribute StudioOwned, see EnvironmentConfig). Deliberately calm: no signs,
	barrels or random props. The playable core is mirror-symmetric around the road (z = 0) and the plaza (x = 0).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Build)
local Decor = require(script.Parent.Decor)
local MountainBuilder = require(script.Parent.MountainBuilder)
local Palette = require(script.Parent.Palette)

local WorldLayout = require(ReplicatedStorage.Modules.WorldLayout)

local EnvironmentBuilder = {}

local COSMETIC = Enum.Material.Cobblestone
local GRASS = Enum.Material.Grass

local GROUND_HALF_X = WorldLayout.GroundHalfX
local GROUND_HALF_Z = WorldLayout.GroundHalfZ
local LOT_BACK = WorldLayout.GateDistance + WorldLayout.LotDepth -- |z| of the back hedges
local LOT_OUTER_X = WorldLayout.HouseColumns[#WorldLayout.HouseColumns] + WorldLayout.LotHalfWidth

-- Keeps scenery from overlapping: every tree / bush / rock claims a circle on the ground and a candidate that would overlap
-- an earlier one (crown into a neighbour's trunk, rock under a crown) is skipped.
local function newFootprints()
	local cells: { [string]: { { number } } } = {}
	local CELL = 24
	local self = {}
	function self.tryPlace(x: number, z: number, radius: number): boolean
		local cx, cz = math.floor(x / CELL), math.floor(z / CELL)
		for dx = -1, 1 do
			for dz = -1, 1 do
				local list = cells[(cx + dx) .. "," .. (cz + dz)]
				if list then
					for _, other in list do
						local gap = math.sqrt((other[1] - x) ^ 2 + (other[2] - z) ^ 2)
						if gap < other[3] + radius then
							return false
						end
					end
				end
			end
		end
		local key = cx .. "," .. cz
		cells[key] = cells[key] or {}
		table.insert(cells[key], { x, z, radius })
		return true
	end
	return self
end

-- Lawn patches are flat discs (top 0.06) that lie only on bare lawn. The things that stand on the lawn are at heights a patch would fight with
-- (a lot's lawn tops at 0.07, the promenades and paths at 0.10 .. 0.16), so a patch keeps PATCH_GAP away from the lots, the promenades and the plaza strip
-- between the two inner lots (plaza, annexes, shops, wheel, hall), and from every patch of the other shade (two shades in one plane fight as well).
local PATCH_GAP = 0.5
local MIN_PATCH_RADIUS = 4

-- the rectangles { x0, x1, z0, z1 } a patch has to stay away from
local function lawnReserved(): { { number } }
	local columns = WorldLayout.HouseColumns
	local reserved = { { columns[2] + WorldLayout.LotHalfWidth, columns[3] - WorldLayout.LotHalfWidth, -GROUND_HALF_Z, GROUND_HALF_Z } } -- the plaza strip
	for _, sign in { 1, -1 } do
		local nearZ = WorldLayout.PromenadeZ - WorldLayout.PromenadeHalfWidth
		local farZ = WorldLayout.PromenadeZ + WorldLayout.PromenadeHalfWidth
		table.insert(reserved, { -LOT_OUTER_X - 10, LOT_OUTER_X + 10, math.min(sign * nearZ, sign * farZ), math.max(sign * nearZ, sign * farZ) }) -- promenade
		for _, column in columns do
			table.insert(reserved, { column - WorldLayout.LotHalfWidth, column + WorldLayout.LotHalfWidth, math.min(sign * WorldLayout.GateDistance, sign * LOT_BACK), math.max(sign * WorldLayout.GateDistance, sign * LOT_BACK) }) -- lot
		end
	end
	return reserved
end

-- True for points that belong to the playable core (road, promenades, lots, plaza annexes, burrow and exit).
local function isCore(x: number, z: number): boolean
	if math.abs(z) < 40 and math.abs(x) > LOT_OUTER_X - 20 then
		return true -- burrow and exit tunnel
	end
	return math.abs(x) < LOT_OUTER_X + 8 and math.abs(z) < LOT_BACK + 8
end

---------------------------------------------------------------------------
-- backdrop: mountains, hills, lakes, cliffs, clouds
---------------------------------------------------------------------------

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

-- A low rocky ridge hugging an edge of the playable ground: overlapping faceted rock hills (the same triangle mountains as
-- the big ranges, just small and wide) instead of the old rows of upright boxes.
local function cliffWall(parent: Instance, center: Vector3, length: number, alongX: boolean, height: number, rng: Random)
	local model = Build.model(parent, "Cliff")
	local spacing = 52
	local count = math.max(2, math.floor(length / spacing))
	for index = 1, count do
		local offset = -length / 2 + (index - 0.5) * (length / count) + (rng:NextNumber() - 0.5) * 14
		local position = center + (if alongX then Vector3.new(offset, 0, 0) else Vector3.new(0, 0, offset))
		MountainBuilder.massif(model, {
			Position = Vector3.new(position.X, 0, position.Z),
			Width = 70 + rng:NextNumber() * 44,
			Height = height * (0.35 + rng:NextNumber() * 0.85),
			Fade = 0.04,
			Detail = 2,
			Peaks = { 2, 3 },
		}, rng)
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

	-- angular mountain ranges around the outer edges (see MountainBuilder / EnvironmentConfig)
	MountainBuilder.build(backdrop, rng, GROUND_HALF_X, GROUND_HALF_Z, lakes)

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
			hill(backdrop, pos, radius, 8 + rng:NextNumber() * 12, rng, true)
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

-- Ground transitions: the lawn does not stop at a hard line. Outside the walls grass breaks up into dirt, then scree and
-- boulders towards the foot of the mountains; inside, flower beds soften the edge of the forest. All flat, non-colliding
-- patches (a few hundred cheap parts) plus boulders.
local function buildTransitions(folder: Folder, rng: Random, footprints: any)
	local transitions = Build.folder(folder, "Transitions")
	local DIRT = Color3.fromRGB(158, 126, 92)
	local SCREE = Color3.fromRGB(132, 126, 134)
	local function patch(x: number, z: number, radius: number, color: Color3, material: Enum.Material)
		Build.pillar(transitions, "Patch", radius * 2, 0.06, CFrame.new(x, 0.03 + rng:NextNumber() * 0.04, z), color, material, { CanCollide = false, CanQuery = false, CastShadow = false })
	end
	for _ = 1, 150 do
		-- a point in a band 4-70 studs outside the ground, anywhere around it
		local onEnds = rng:NextNumber() < 0.45
		local depth = 4 + rng:NextNumber() * 66
		local along = (rng:NextNumber() * 2 - 1)
		local x, z
		if onEnds then
			x = (GROUND_HALF_X + depth) * (if rng:NextNumber() > 0.5 then 1 else -1)
			z = along * (GROUND_HALF_Z + 40)
		else
			z = (GROUND_HALF_Z + depth) * (if rng:NextNumber() > 0.5 then 1 else -1)
			x = along * (GROUND_HALF_X + 40)
		end
		local t = depth / 70 -- 0 = next to the lawn, 1 = foot of the mountains
		local material = if t < 0.45 then Enum.Material.Ground else Enum.Material.Slate
		patch(x, z, 5 + rng:NextNumber() * 12, if t < 0.45 then DIRT else SCREE, material)
		if rng:NextNumber() < 0.28 + t * 0.4 then
			local rx, rz = x + (rng:NextNumber() - 0.5) * 10, z + (rng:NextNumber() - 0.5) * 10
			local scale = 1.2 + rng:NextNumber() * 2.2 * (0.5 + t)
			if footprints.tryPlace(rx, rz, 1.6 * scale + 0.6) then
				Decor.rock(transitions, Vector3.new(rx, 0, rz), scale, rng)
			end
		end
	end
	-- flower beds just inside the forest edge, away from lots and paths
	for _ = 1, 40 do
		local x = (rng:NextNumber() * 2 - 1) * (GROUND_HALF_X - 14)
		local z = (if rng:NextNumber() > 0.5 then 1 else -1) * (LOT_BACK + 14 + rng:NextNumber() * (GROUND_HALF_Z - LOT_BACK - 26))
		if not isCore(x, z) then
			Decor.flowers(transitions, Vector3.new(x, 0, z), 2 + rng:NextNumber() * 2, 8, rng)
		end
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
	local reserved = lawnReserved()
	local placed: { { X: number, Z: number, Radius: number, Light: boolean } } = {}
	for _ = 1, 60 do
		-- (the random numbers are drawn for every candidate, placed or not, so the forest and the rest of the world do not move)
		local x = (rng:NextNumber() * 2 - 1) * (GROUND_HALF_X - 8)
		local z = (rng:NextNumber() * 2 - 1) * (GROUND_HALF_Z - 8)
		local radius = 8 + rng:NextNumber() * 16
		local light = rng:NextNumber() > 0.5
		for _, rect in reserved do
			local dx, dz = math.max(rect[1] - x, 0, x - rect[2]), math.max(rect[3] - z, 0, z - rect[4])
			radius = math.min(radius, math.sqrt(dx * dx + dz * dz) - PATCH_GAP)
		end
		for _, other in placed do
			if other.Light ~= light then
				radius = math.min(radius, math.sqrt((other.X - x) ^ 2 + (other.Z - z) ^ 2) - other.Radius - PATCH_GAP)
			end
		end
		if radius >= MIN_PATCH_RADIUS then
			table.insert(placed, { X = x, Z = z, Radius = radius, Light = light })
			Build.pillar(patches, "Patch", radius * 2, 0.06, CFrame.new(x, 0.03, z), if light then Palette.GrassLight else Palette.GrassDark, GRASS, { CanCollide = false, CastShadow = false })
		end
	end

	-- promenades (the wide walkways in front of the houses; hamsters roll home along them too). They lie at the height of the plaza paving (0.1); the kerb
	-- strips are 0.06 higher and 0.05 inside the sides and ends of the promenade, so no two faces of a different colour share a plane.
	local walks = Build.folder(folder, "Promenades")
	local promenadeLength = LOT_OUTER_X * 2 + 20
	local halfWidth = WorldLayout.PromenadeHalfWidth
	for _, sign in { 1, -1 } do
		local z = sign * WorldLayout.PromenadeZ
		Build.part(walks, "Promenade", Vector3.new(promenadeLength, 0.1, halfWidth * 2), CFrame.new(0, 0.05, z), Palette.Pavement, COSMETIC, { CanCollide = false })
		for _, edge in { -1, 1 } do
			Build.deco(walks, "PromenadeEdge", Vector3.new(promenadeLength - 0.2, 0.16, 0.6), CFrame.new(0, 0.08, z + edge * (halfWidth - 0.35)), Palette.PavementDark, COSMETIC)
		end
		-- a paved path from every gate straight to the road: in two pieces, the road side and the gate side of the promenade (it would only lie hidden under it)
		for _, x in WorldLayout.HouseColumns do
			for _, span in { { WorldLayout.RoadHalfWidth, WorldLayout.PromenadeZ - halfWidth }, { WorldLayout.PromenadeZ + halfWidth, WorldLayout.GateDistance } } do
				Build.part(walks, "GatePath", Vector3.new(11, 0.12, span[2] - span[1]), CFrame.new(x, 0.06, sign * (span[1] + span[2]) / 2), Palette.PavementDark, COSMETIC, { CanCollide = false })
			end
		end
	end

	-- street furniture: a few lamps and benches between the road and the promenade
	local props = Build.folder(folder, "Props")
	for _, sign in { 1, -1 } do
		for _, x in { -190, -128, -72, 72, 128, 190 } do -- (not +-64: that is the middle of the gate path)
			Decor.lamp(props, Vector3.new(x, 0, sign * 17), 7)
		end
		for _, x in { -44, 44 } do
			local facing = if sign > 0 then math.pi else 0
			Decor.bench(props, CFrame.new(x, 0, sign * 17.5) * CFrame.Angles(0, facing, 0))
		end
	end

	-- forest in the ring between the lots and the edge of the ground
	local forest = Build.folder(folder, "Forest")
	local footprints = newFootprints()
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
					local scale = 1 + rng:NextNumber() * 0.9
					local kind = kinds[rng:NextInteger(1, #kinds)]
					if footprints.tryPlace(px, pz, 4.4 * scale + 0.6) then
						Decor.tree(forest, pos, kind, scale, rng)
					end
				elseif roll < 0.7 then
					local scale = 0.9 + rng:NextNumber() * 0.5
					local berries = rng:NextNumber() > 0.6
					if footprints.tryPlace(px, pz, 3 * scale) then
						Decor.bush(forest, pos, scale, rng, berries)
					end
				elseif roll < 0.8 then
					local scale = 1 + rng:NextNumber() * 2
					if footprints.tryPlace(px, pz, 1.6 * scale + 0.6) then
						Decor.rock(forest, pos, scale, rng)
					end
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
					local kind = if rng:NextNumber() > 0.3 then "pine" else "round"
					local scale = 1.4 + rng:NextNumber() * 1.1
					if footprints.tryPlace(pos.X, pos.Z, 4.4 * scale + 0.6) then
						Decor.tree(outer, pos, kind, scale, rng)
					end
				end
			end
		end
	end

	buildBackdrop(folder, rng)
	buildTransitions(folder, rng, footprints)

	-- invisible boundary so nobody wanders off the map
	local boundary = Build.folder(folder, "Boundary")
	local wallProps = { Transparency = 1, CanQuery = false, CastShadow = false }
	Build.part(boundary, "North", Vector3.new(GROUND_HALF_X * 2, 80, 2), CFrame.new(0, 40, GROUND_HALF_Z), Palette.Cream, Enum.Material.SmoothPlastic, wallProps)
	Build.part(boundary, "South", Vector3.new(GROUND_HALF_X * 2, 80, 2), CFrame.new(0, 40, -GROUND_HALF_Z), Palette.Cream, Enum.Material.SmoothPlastic, wallProps)
	Build.part(boundary, "East", Vector3.new(2, 80, GROUND_HALF_Z * 2), CFrame.new(GROUND_HALF_X, 40, 0), Palette.Cream, Enum.Material.SmoothPlastic, wallProps)
	Build.part(boundary, "West", Vector3.new(2, 80, GROUND_HALF_Z * 2), CFrame.new(-GROUND_HALF_X, 40, 0), Palette.Cream, Enum.Material.SmoothPlastic, wallProps)
	-- From now on the scenery belongs to Roblox Studio: WorldBuilder keeps it as it is (set the attribute to false to
	-- let the code rebuild it from EnvironmentConfig on the next Play).
	folder:SetAttribute("StudioOwned", true)
	return folder
end

-- A scenery folder that was built into the place (StudioOwned): give back the runtime tags that a saved place can't
-- keep (the client sways trees and drifts clouds based on them).
function EnvironmentBuilder.adopt(folder: Instance)
	for _, descendant in folder:GetDescendants() do
		if descendant:IsA("Model") then
			if descendant.Name == "Cloud" then
				descendant:AddTag("Cloud")
			elseif string.sub(descendant.Name, 1, 5) == "Tree_" then
				descendant:AddTag("TreeSway")
			end
		end
	end
end

return EnvironmentBuilder
