-- Plaza path audit: nothing that belongs to the plaza - the Like & Favorite boards, lamps, benches, flower beds, signposts, trees, rocks - may
-- stand ON a paved surface (plaza paving, annex paths, shop approach, wheel path, hamster road + curbs, promenades, gate paths), and the
-- walking lanes (plaza -> shops -> Lucky Wheel, plaza -> Leaderboard Hall, the promenades, the road) stay free of solid parts.
-- Footprints are the real rotated rectangles / discs of the parts (CFrame + Size), not centre points. A board keeps >= 2 studs from every paved
-- edge, every other prop >= 1 stud; only lamps and flower beds (which are meant to line the edge of a path) may touch it, their middle must be
-- off the pavement. Runs on the REAL builders (the baked world/*.model.json is not looked at).
local results = { pass = 0, fail = 0 }
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end
local adv = M.Sim.advance

local BOARD_CLEARANCE = 2 -- studs between a Like & Favorite board and the nearest paved edge
local PROP_CLEARANCE = 1 -- studs between any other plaza prop and the nearest paved edge
local LANE_HALF_WIDTH = 4.5 -- the free walking lanes are 9 wide (the annex paths are 10, the wheel path 8)
local TOUCHES_GROUND = 1.0 -- a part whose underside is lower than this stands on the ground
local SPAWN_CLEARANCE = 1 -- studs between a board and the guest spawn pad
local EDGE_DRESSING = { Lamp = true, Flowers = true } -- may overlap the edge of a path (the lamp base, the flower mound), but not stand in it

-- Things that stand on pavement ON PURPOSE, by the group they belong to (everything else must keep its clearance).
local ON_PAVEMENT_BY_DESIGN = {
	PlazaArch = "the arch stands on the plaza paving, the road runs under it",
	LuckyWheel = "the round platform is where the wheel path ends",
	CoinsShop = "the steps and barrels stand on the shop approach in front of the door",
	RobuxShop = "the steps and barrels stand on the shop approach in front of the door",
	LeaderboardHall = "the hall is a paved square: its boards, kiosk, benches and lamps stand on it",
	["HamsterPath/BurrowHill"] = "the road runs into the burrow hill",
}
local PAVED_NAMES = {
	PavingOuter = true, PavingRing = true, PavingInner = true, AnnexPath = true, ShopApproach = true, WheelPath = true,
	Promenade = true, PromenadeEdge = true, GatePath = true, Road = true, Curb = true, HallPaving = true, HallRing = true, HallPath = true,
}
local EXPECTED_PAVED = { "PavingOuter", "AnnexPath", "ShopApproach", "WheelPath", "Promenade", "PromenadeEdge", "GatePath", "Road", "Curb", "HallPaving", "HallPath" }

---------------------------------------------------------------------------
-- convex polygons on the ground plane: { { x, z }, ... } counter-clockwise
---------------------------------------------------------------------------
local function hull(points)
	table.sort(points, function(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end)
	local function cross(o, a, b) return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1]) end
	local lower, upper = {}, {}
	for _, p in points do
		while #lower >= 2 and cross(lower[#lower - 1], lower[#lower], p) <= 0 do table.remove(lower) end
		table.insert(lower, p)
	end
	for index = #points, 1, -1 do
		local p = points[index]
		while #upper >= 2 and cross(upper[#upper - 1], upper[#upper], p) <= 0 do table.remove(upper) end
		table.insert(upper, p)
	end
	table.remove(lower)
	table.remove(upper)
	for _, p in upper do table.insert(lower, p) end
	return lower
end

-- ellipse with the semi-axis vectors (ax, az) and (bx, bz) around (cx, cz)
local function ellipse(cx, cz, ax, az, bx, bz)
	local steps = if math.max(math.abs(ax) + math.abs(bx), math.abs(az) + math.abs(bz)) > 10 then 96 else 32
	local points = {}
	for index = 0, steps - 1 do
		local t = index / steps * math.pi * 2
		table.insert(points, { cx + math.cos(t) * ax + math.sin(t) * bx, cz + math.cos(t) * az + math.sin(t) * bz })
	end
	return points
end

local function pointSegment(px, pz, a, b)
	local dx, dz = b[1] - a[1], b[2] - a[2]
	local length2 = dx * dx + dz * dz
	local t = if length2 > 1e-12 then math.clamp(((px - a[1]) * dx + (pz - a[2]) * dz) / length2, 0, 1) else 0
	local ex, ez = px - (a[1] + t * dx), pz - (a[2] + t * dz)
	return math.sqrt(ex * ex + ez * ez)
end

-- Signed clearance of two convex polygons: the gap between them (> 0), or minus the distance one has to move to clear the other when they overlap.
local function clearance(a, b)
	local depth = math.huge
	local separated = false
	for _, poly in { a, b } do
		for i = 1, #poly do
			local p, q = poly[i], poly[i % #poly + 1]
			local nx, nz = q[2] - p[2], p[1] - q[1]
			local length = math.sqrt(nx * nx + nz * nz)
			if length > 1e-9 then
				nx, nz = nx / length, nz / length
				local aMin, aMax, bMin, bMax = math.huge, -math.huge, math.huge, -math.huge
				for _, v in a do
					local d = v[1] * nx + v[2] * nz
					aMin, aMax = math.min(aMin, d), math.max(aMax, d)
				end
				for _, v in b do
					local d = v[1] * nx + v[2] * nz
					bMin, bMax = math.min(bMin, d), math.max(bMax, d)
				end
				local overlap = math.min(aMax - bMin, bMax - aMin) -- how far one has to move along this axis to clear the other
				if overlap <= 0 then
					separated = true
				end
				depth = math.min(depth, overlap)
			end
		end
	end
	if not separated then
		return -depth
	end
	-- disjoint convex polygons: the closest points are a vertex of one and an edge of the other
	local gap = math.huge
	for _, pair in { { a, b }, { b, a } } do
		for _, v in pair[1] do
			for i = 1, #pair[2] do
				gap = math.min(gap, pointSegment(v[1], v[2], pair[2][i], pair[2][i % #pair[2] + 1]))
			end
		end
	end
	return gap
end

local function bounds(poly)
	local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
	for _, v in poly do
		x0, x1, z0, z1 = math.min(x0, v[1]), math.max(x1, v[1]), math.min(z0, v[2]), math.max(z1, v[2])
	end
	return { x0, x1, z0, z1 }
end
local function boxGap(a, b) -- gap between two bounding boxes (0 when they touch or overlap)
	local gx = math.max(a[1] - b[2], b[1] - a[2], 0)
	local gz = math.max(a[3] - b[4], b[3] - a[4], 0)
	return math.sqrt(gx * gx + gz * gz)
end
local function rectangle(x0, x1, z0, z1)
	return { { x0, z0 }, { x1, z0 }, { x1, z1 }, { x0, z1 } }
end

---------------------------------------------------------------------------
-- parts
---------------------------------------------------------------------------
local PAVED_COLORS = {}
local function colorKey(color)
	return string.format("%.3f,%.3f,%.3f", color.R, color.G, color.B)
end

-- Footprint on the ground plane of an anchored part: a disc for a standing cylinder, an ellipse for an upright blob / ball, else the hull
-- of the 8 corners of the (possibly tilted) box.
local function describe(inst)
	local data = RawData[inst]
	local props = data.Props
	local cf, size = props.CFrame, props.Size
	local r = cf.r
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local ey = math.abs(r[4]) * hx + math.abs(r[5]) * hy + math.abs(r[6]) * hz
	local shape = if props.Shape then props.Shape.Name else "Block"
	local sphere = shape == "Ball"
	for _, child in data.Children do
		local mesh = RawData[child]
		if mesh.ClassName == "SpecialMesh" and mesh.Props.MeshType and mesh.Props.MeshType.Name == "Sphere" then
			sphere = true
		end
	end
	local poly
	if shape == "Cylinder" and math.abs(r[4]) > 0.99 then
		poly = ellipse(cf.X, cf.Z, hy, 0, 0, hz)
	elseif sphere and math.abs(r[5]) > 0.99 then
		poly = ellipse(cf.X, cf.Z, r[1] * hx, r[7] * hx, r[3] * hz, r[9] * hz)
	else
		local corners = {}
		for _, sx in { -1, 1 } do
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					local lx, ly, lz = sx * hx, sy * hy, sz * hz
					table.insert(corners, { cf.X + r[1] * lx + r[2] * ly + r[3] * lz, cf.Z + r[7] * lx + r[8] * ly + r[9] * lz })
				end
			end
		end
		poly = hull(corners)
	end
	return {
		Name = data.Name,
		Poly = poly,
		Box = bounds(poly),
		Top = cf.Y + ey,
		Bottom = cf.Y - ey,
		Height = 2 * ey,
		Solid = props.CanCollide ~= false,
		Transparency = props.Transparency or 0,
		Color = props.Color,
		X = cf.X,
		Z = cf.Z,
	}
end

-- All anchored parts of the world, sorted into paved surfaces and plaza props (a prop is whatever hangs in a Model under HamsterPlaza,
-- LeaderboardHall, HamsterPath or Environment/Props: Group is the plaza child it belongs to, Key the Model the part sits in).
local function scan()
	local pavement, propParts, parts = {}, {}, {}
	for _, d in M.descendants(workspace) do
		local data = RawData[d]
		if data.Props and data.Props.Size and data.Props.CFrame and M.InstanceMethods.IsA(d, "BasePart") and data.Props.Anchored then
			local chain = {}
			local node = d
			while node and node ~= workspace do
				table.insert(chain, 1, RawData[node].Name)
				node = RawData[node].Parent
			end
			local top, second = chain[1], chain[2]
			local part = describe(d)
			part.Path = table.concat(chain, "/")
			table.insert(parts, part)
			local plazaFolder = top == "HamsterPlaza" or top == "HamsterPath" or top == "LeaderboardHall"
			local loose = #chain == 2 and plazaFolder
			local walkway = top == "Environment" and second == "Promenades"
			if (loose or walkway) and part.Top <= 0.55 and part.Height <= 0.6 and part.Transparency < 0.9 and (PAVED_NAMES[part.Name] or PAVED_COLORS[colorKey(part.Color)]) then
				table.insert(pavement, part)
			elseif (#chain >= 3 and plazaFolder) or (#chain >= 4 and top == "Environment" and second == "Props") then
				part.Group = if top == "HamsterPlaza" then second elseif top == "Environment" then "Environment/Props" elseif top == "LeaderboardHall" then top else top .. "/" .. second
				part.Key = RawData[d].Parent
				part.Prop = table.concat(chain, "/", 1, #chain - 1)
				part.Kind = chain[#chain - 1]
				table.insert(propParts, part)
			end
		end
	end
	return pavement, propParts, parts
end

local function isBoard(part)
	return string.sub(part.Group, 1, 14) == "FavoritesBoard"
end
local function isPad(part)
	return string.sub(part.Name, 1, 10) == "PromptPad_"
end

task.spawn(function()
	M.isServer = true
	local mainServer = find("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	adv(3)
	local WorldLayout = require(find("ReplicatedStorage.Modules.WorldLayout"))
	local Palette = require(find("ServerScriptService.Systems.WorldBuilder.Palette"))
	local LuckyWheelBuilder = require(find("ServerScriptService.Systems.WorldBuilder.LuckyWheelBuilder"))
	for _, color in { Palette.Pavement, Palette.PavementDark, Palette.Road, Palette.RoadEdge } do
		PAVED_COLORS[colorKey(color)] = true
	end

	---------------------------------------------------------------------------
	-- 1. the paved surfaces are found (a detector that scans nothing proves nothing)
	---------------------------------------------------------------------------
	local pavement, propParts, allParts = scan()
	local pavedByName = {}
	for _, p in pavement do pavedByName[p.Name] = (pavedByName[p.Name] or 0) + 1 end
	local missing = {}
	for _, name in EXPECTED_PAVED do
		if not pavedByName[name] then table.insert(missing, name) end
	end
	check("the audit finds the paved surfaces (plaza paving, annex paths, shop approach, wheel path, promenades, gate paths, road, hall paving)", #missing == 0 and #pavement > 20, string.format("%d paved parts, missing: %s", #pavement, table.concat(missing, ",")))

	---------------------------------------------------------------------------
	-- 2. no prop stands on pavement: boards, lamps, benches, flower beds, signs, trees, rocks ... keep their clearance
	---------------------------------------------------------------------------
	-- One entry per prop (Model): its worst ground-contact part. The two prompt pads of a board only have to stay off the pavement itself.
	local function touchesGround(part)
		return part.Bottom <= TOUCHES_GROUND and part.Height > 0.05 and (part.Transparency < 0.95 or part.Solid)
	end
	local function offenders(pavementParts, parts)
		local worst = {}
		local anchors = {} -- a lamp / flower bed is judged by its widest part on the ground (lamp base, flower mound)
		for _, part in parts do
			local area = (part.Box[2] - part.Box[1]) * (part.Box[4] - part.Box[3])
			if touchesGround(part) and (not anchors[part.Key] or area > anchors[part.Key].Area) then
				part.Area = area
				anchors[part.Key] = part
			end
		end
		for _, part in parts do
			local judged = (touchesGround(part) and (not EDGE_DRESSING[part.Kind] or anchors[part.Key] == part)) or isPad(part)
			if judged and not ON_PAVEMENT_BY_DESIGN[part.Group] then
				local need = if isPad(part) then 0 elseif isBoard(part) then BOARD_CLEARANCE else PROP_CLEARANCE
				local poly, box = part.Poly, part.Box
				if EDGE_DRESSING[part.Kind] then
					need = 0 -- only the middle of the lamp / flower bed has to be off the pavement
					poly = rectangle(part.X - 0.01, part.X + 0.01, part.Z - 0.01, part.Z + 0.01)
					box = bounds(poly)
				end
				for _, paved in pavementParts do
					if boxGap(box, paved.Box) < need + 0.01 then
						local gap = clearance(poly, paved.Poly)
						local current = worst[part.Key]
						if gap < need - 0.01 and (not current or gap - need < current.Gap - current.Need) then
							worst[part.Key] = { Prop = part.Prop, Group = part.Group, Part = part.Name, Paved = paved.Name, Gap = gap, Need = need, X = part.X, Z = part.Z }
						end
					end
				end
			end
		end
		local list = {}
		for _, entry in worst do table.insert(list, entry) end
		table.sort(list, function(a, b)
			if a.Gap - a.Need ~= b.Gap - b.Need then return a.Gap - a.Need < b.Gap - b.Need end
			return a.Prop < b.Prop
		end)
		return list
	end
	local found = offenders(pavement, propParts)
	local boardOffenders, otherOffenders = {}, {}
	for _, entry in found do
		local where = string.format("%s [%s] at (%.1f, %.1f)", entry.Prop, entry.Part, entry.X, entry.Z)
		if entry.Gap < 0 then
			print(string.format("   ON PATH  %s: stands on the %s (to get clear it has to move %.1f studs, needs %.1f)", where, entry.Paved, -entry.Gap + entry.Need, entry.Need))
		else
			print(string.format("   ON PATH  %s: only %.2f studs from the %s, needs %.1f", where, entry.Gap, entry.Paved, entry.Need))
		end
		table.insert(if string.sub(entry.Group, 1, 14) == "FavoritesBoard" then boardOffenders else otherOffenders, string.format("%s (%.0f,%.0f)", entry.Prop, entry.X, entry.Z))
	end
	check("no Like & Favorite board stands on or within " .. BOARD_CLEARANCE .. " studs of a paved path / road / promenade", #boardOffenders == 0, table.concat(boardOffenders, ", "))
	check("no lamp, bench, flower bed, signpost, tree, rock or other prop stands on or within " .. PROP_CLEARANCE .. " stud of pavement (shops, arch, wheel platform, hall and burrow excepted)", #otherOffenders == 0, table.concat(otherOffenders, ", "))
	for group, reason in ON_PAVEMENT_BY_DESIGN do
		print("   (on pavement by design: " .. group .. " - " .. reason .. ")")
	end

	---------------------------------------------------------------------------
	-- 3. the walking lanes stay free of solid parts (thin floors under 0.5 studs and everything above head height do not count)
	---------------------------------------------------------------------------
	local wheelStart = LuckyWheelBuilder.CENTER.Z - 6.5 -- the wheel path ends at the platform
	local promenadeNear = WorldLayout.PromenadeZ - WorldLayout.PromenadeHalfWidth
	local promenadeFar = WorldLayout.PromenadeZ + WorldLayout.PromenadeHalfWidth
	local promenadeX = WorldLayout.HouseColumns[#WorldLayout.HouseColumns] + WorldLayout.LotHalfWidth + 10
	local lanes = {
		{ "north annex -> between the shops -> Lucky Wheel", -LANE_HALF_WIDTH, LANE_HALF_WIDTH, promenadeNear, wheelStart },
		{ "plaza -> Leaderboard Hall", -LANE_HALF_WIDTH, LANE_HALF_WIDTH, -100, -promenadeNear },
		{ "north promenade", -promenadeX, promenadeX, promenadeNear, promenadeFar },
		{ "south promenade", -promenadeX, promenadeX, -promenadeFar, -promenadeNear },
		{ "hamster road", -215, 215, -WorldLayout.RoadHalfWidth, WorldLayout.RoadHalfWidth },
	}
	local function laneBlockers(parts, lane)
		local rectPoly = rectangle(lane[2], lane[3], lane[4], lane[5])
		local laneBox = bounds(rectPoly)
		local blockers = {}
		for _, part in parts do
			if part.Solid and part.Top > 0.5 and part.Bottom < 6.5 and boxGap(part.Box, laneBox) < 0.01 and clearance(part.Poly, rectPoly) < -0.01 then
				table.insert(blockers, string.format("%s at (%.1f, %.1f), %.1f high", part.Path, part.X, part.Z, part.Height))
			end
		end
		table.sort(blockers)
		return blockers
	end
	local blockedBefore = 0
	for _, lane in lanes do
		local blockers = laneBlockers(allParts, lane)
		blockedBefore += #blockers
		for index = 1, math.min(#blockers, 8) do print("   BLOCKS", lane[1] .. ":", blockers[index]) end
		check("the walking lane '" .. lane[1] .. "' is free of solid parts", #blockers == 0, #blockers)
	end

	---------------------------------------------------------------------------
	-- 4. the Like & Favorite boards: clear of the guest spawn, readable from both sides
	---------------------------------------------------------------------------
	local plazaFolder = workspace.HamsterPlaza
	local spawnPart = workspace.SpawnLocations:FindFirstChild("PlazaSpawn")
	check("the guest spawn pad exists on the plaza, beside the road", spawnPart ~= nil and math.abs(RawData[spawnPart].Props.CFrame.Z) > WorldLayout.RoadHalfWidth + 1)
	local spawnPoly = describe(spawnPart).Poly
	local boards = 0
	for _, model in plazaFolder:GetChildren() do
		local boardName = RawData[model].Name
		if string.sub(boardName, 1, 14) == "FavoritesBoard" then
			boards += 1
			local solid, pads = {}, {}
			for _, part in propParts do
				if part.Group == boardName then
					table.insert(if isPad(part) then pads else solid, part)
				end
			end
			check(boardName .. " is built from solid parts and two prompt pads", #solid >= 5 and #pads == 2, #solid .. " solid, " .. #pads .. " pads")
			local nearest = math.huge
			for _, part in solid do
				nearest = math.min(nearest, clearance(part.Poly, spawnPoly))
			end
			check(boardName .. " does not stand on or against the guest spawn pad (>= " .. SPAWN_CLEARANCE .. " stud)", nearest >= SPAWN_CLEARANCE, string.format("%.2f", nearest))
			-- readable: a prompt pad is the spot a player stands on in front of / behind the board; no solid prop of another model stands in it
			local blocked = {}
			for _, pad in pads do
				for _, part in propParts do
					if part.Group ~= boardName and part.Solid and part.Top > 0.5 and part.Bottom < 6.5 and boxGap(part.Box, pad.Box) < 0.01 and clearance(part.Poly, pad.Poly) < -0.01 then
						table.insert(blocked, part.Path)
					end
				end
			end
			check(boardName .. ": the spots in front of and behind it (prompt pads) are free of solid props", #blocked == 0, table.concat(blocked, ", "))
		end
	end
	check("the plaza has a Like & Favorite board", boards >= 1, boards)

	-- advisory: a solid prop inside the guest spawn pad (cosmetic: a guest can land on it)
	local seen = {}
	for _, part in propParts do
		if part.Solid and part.Bottom <= TOUCHES_GROUND and part.Height > 0.05 and not seen[part.Key] and clearance(part.Poly, spawnPoly) < -0.2 then
			seen[part.Key] = true
			print(string.format("   NOTE inside the guest spawn pad: %s at (%.1f, %.1f)", part.Prop, part.X, part.Z))
		end
	end

	---------------------------------------------------------------------------
	-- 5. self-tests: the audit must see the defects it is meant to see
	---------------------------------------------------------------------------
	local function withProbe(modelName, parts, run)
		local model = M.newInstance("Model", true)
		RawData[model].Name = modelName
		M.setParent(model, plazaFolder)
		for _, spec in parts do
			local probe = M.newInstance("Part", true)
			RawData[probe].Name = spec.Name
			RawData[probe].Props.Anchored = true
			RawData[probe].Props.CanCollide = true
			RawData[probe].Props.Size = spec.Size
			RawData[probe].Props.CFrame = spec.CFrame
			M.setParent(probe, model)
		end
		local probePavement, probeProps, probeAll = scan()
		local result = run(probePavement, probeProps, probeAll)
		M.InstanceMethods.Destroy(model)
		return result
	end
	local function seesOffender(modelName, parts)
		return withProbe(modelName, parts, function(probePavement, probeProps)
			for _, entry in offenders(probePavement, probeProps) do
				if string.find(entry.Prop, modelName, 1, true) then return true end
			end
			return false
		end)
	end
	local function newLaneBlockers(modelName, parts)
		return withProbe(modelName, parts, function(_, _, probeAll)
			local count = 0
			for _, lane in lanes do count += #laneBlockers(probeAll, lane) end
			return count - blockedBefore
		end)
	end
	local baseSize = Vector3.new(8.8, 0.3, 2.2)
	local function boardProbe(x, z, yaw)
		return { { Name = "Base", Size = baseSize, CFrame = CFrame.new(x, 0.15, z) * CFrame.Angles(0, yaw, 0) } }
	end
	check("self-test: a board dropped in the middle of the promenade is found", seesOffender("FavoritesBoardProbe", boardProbe(-24, -32, math.pi)))
	check("self-test: a board whose base is 1 stud from the promenade edge is too close (it needs 2)", seesOffender("FavoritesBoardProbe", boardProbe(-48, -25 + 1 + 1.1, 0)))
	check("self-test: a board whose base is 3 studs from the promenade edge is fine", not seesOffender("FavoritesBoardProbe", boardProbe(-48, -25 + 3 + 1.1, 0)))
	check("self-test: a lamp base standing on the hamster road is found", seesOffender("LampProbe", { { Name = "Base", Size = Vector3.new(1.4, 0.8, 1.4), CFrame = CFrame.new(60, 0.4, 3) } }))
	check("self-test: a signpost standing on the promenade is found", seesOffender("SignProbe", { { Name = "Post", Size = Vector3.new(0.5, 5, 0.5), CFrame = CFrame.new(40, 2.5, 34) } }))
	check("self-test: a block dropped into the walkway between the shops is found by the lane check", newLaneBlockers("BlockProbe", { { Name = "Block", Size = Vector3.new(6, 4, 6), CFrame = CFrame.new(0, 2, 60) } }) >= 1)
	check("self-test: a block dropped on the road is found by the lane check", newLaneBlockers("BlockProbe", { { Name = "Block", Size = Vector3.new(3, 4, 3), CFrame = CFrame.new(100, 2, 0) } }) >= 1)

	print(string.format("PASS %d  FAIL %d", results.pass, results.fail))
	print("== done ==")
end)
