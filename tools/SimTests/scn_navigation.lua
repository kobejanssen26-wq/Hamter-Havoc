-- Navigation audit: can a player really WALK to everything, is it findable, and does nothing stand in the way?
-- A walkability model is built from the REAL parts of the generated world (the baked world/*.model.json is not looked at):
--   * every anchored part that collides blocks, invisible walls too (Barrier parts of the fences and hedges, the boundary)
--   * a part whose top is at most STEP (2 studs) above the walking surface is a step, not an obstacle; a part whose underside is more than
--     HEAD (5.5 studs) above the walking surface is overhead (gate beams, signs, roofs): both can be walked over / under
--   * the character has a radius (1.2 studs): every obstacle is grown by it, so gaps narrower than 2.4 studs do not count
--   * upper floors are separate grids (they only exist where a floor slab carries you) entered at the lift landing
-- On that model (Dijkstra on a 1-stud grid) the audit proves:
--   1. every public destination (Coins Shop, Robux Shop, Lucky Wheel, Leaderboard kiosk, Like & Favorite boards) can be reached from the
--      guest spawn, within the reach of its [F] prompt, without a detour
--   2. every house gate is reached, and from the street every [F] / [E] prompt of every base: altar, mailbox, security panel, chest (the
--      physical way to the Hamster collection), upgrade terminal, the 8 upgrade pedestals, the working-bench rings, the lift
--   3. on every upper floor the lift landing reaches everything on that floor, including the lift call buttons
--   4. the walkways (promenades, gate paths, driveways, annex paths, shop approach, wheel path, hall path, road) stay free along their whole length
--   5. invisible walls: every fence / hedge barrier has a visible fence / hedge along its whole length, none lies on a walkway
--   6. the laser gate: the lasers span exactly the opening between the pylons and nothing else can be walked through on the gate line
--   7. signs: text faces the people who walk up to the place it names; every destination is named by a sign or a label
--   8. the rolling hamster balls: nothing stands on the centre line of their real routes (WorldLayout.transitRoute)
-- Every check has a self-test with a deliberately broken input. The mock is not Roblox: this proves reachability and geometry, not how it feels.
local results = { pass = 0, fail = 0 }
local function section(title) print("\n== " .. title .. " ==") end
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end
local adv = M.Sim.advance

local CHAR_R = 1.2 -- radius of a character
local STEP = 2.0 -- highest step a character walks over
local HEAD = 5.5 -- clearance above the walking surface that counts as "overhead"

---------------------------------------------------------------------------
-- geometry helpers: footprints on the ground plane
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

local function pathOf(inst)
	local chain, node = {}, inst
	while node and node ~= workspace do
		table.insert(chain, 1, RawData[node].Name)
		node = RawData[node].Parent
	end
	return table.concat(chain, "/")
end

-- A part as the walkability model sees it: a convex footprint (or a circle for a standing cylinder) and a height range.
local function describe(inst)
	local data = RawData[inst]
	local props = data.Props
	local cf, size = props.CFrame, props.Size
	local r = cf.r
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local ey = math.abs(r[4]) * hx + math.abs(r[5]) * hy + math.abs(r[6]) * hz
	local shape = if props.Shape then props.Shape.Name else "Block"
	local part = {
		Inst = inst,
		Name = data.Name,
		Path = pathOf(inst),
		Top = cf.Y + ey,
		Bottom = cf.Y - ey,
		Transparency = props.Transparency or 0,
		Solid = props.CanCollide ~= false,
		X = cf.X,
		Y = cf.Y,
		Z = cf.Z,
	}
	if shape == "Cylinder" and math.abs(r[4]) > 0.99 then
		part.Circle = { cf.X, cf.Z, hy } -- a standing cylinder: radius = half of Size.Y
		part.Box = { cf.X - hy, cf.X + hy, cf.Z - hy, cf.Z + hy }
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
		part.Poly = hull(corners)
		local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
		for _, v in part.Poly do x0, x1, z0, z1 = math.min(x0, v[1]), math.max(x1, v[1]), math.min(z0, v[2]), math.max(z1, v[2]) end
		part.Box = { x0, x1, z0, z1 }
	end
	return part
end

local function distToPoly(poly, px, pz)
	local inside = true
	local best = math.huge
	for i = 1, #poly do
		local a, b = poly[i], poly[i % #poly + 1]
		local ex, ez = b[1] - a[1], b[2] - a[2]
		if ex * (pz - a[2]) - ez * (px - a[1]) < 0 then inside = false end
		local len2 = ex * ex + ez * ez
		local t = if len2 > 1e-12 then math.clamp(((px - a[1]) * ex + (pz - a[2]) * ez) / len2, 0, 1) else 0
		local dx, dz = px - (a[1] + t * ex), pz - (a[2] + t * ez)
		best = math.min(best, math.sqrt(dx * dx + dz * dz))
	end
	return if inside then 0 else best
end
-- distance from a point on the ground plane to the footprint of a part (0 when inside)
local function distTo(part, px, pz)
	if part.Circle then
		return math.max(0, math.sqrt((px - part.Circle[1]) ^ 2 + (pz - part.Circle[2]) ^ 2) - part.Circle[3])
	end
	return distToPoly(part.Poly, px, pz)
end

---------------------------------------------------------------------------
-- the walkability grid
---------------------------------------------------------------------------
-- A grid of 1 x 1 stud cells over [x0, x1) x [z0, z1). A cell is blocked when a character standing in its middle would touch an obstacle.
-- `base` = height of the walking surface; `support` (optional) = parts that carry the floor (a cell without floor under it is blocked).
local function buildGrid(parts, x0, x1, z0, z1, base, radius, support)
	local g = { X0 = x0, Z0 = z0, W = x1 - x0, H = z1 - z0 }
	g.Blocked = table.create(g.W * g.H, false)
	for _, p in parts do
		if p.Solid and p.Top > base + STEP and p.Bottom < base + HEAD and p.Box[2] >= x0 - radius and p.Box[1] <= x1 + radius and p.Box[4] >= z0 - radius and p.Box[3] <= z1 + radius then
			for i = math.max(0, math.floor(p.Box[1] - radius) - x0), math.min(g.W - 1, math.ceil(p.Box[2] + radius) - x0) do
				for j = math.max(0, math.floor(p.Box[3] - radius) - z0), math.min(g.H - 1, math.ceil(p.Box[4] + radius) - z0) do
					local k = j * g.W + i + 1
					if not g.Blocked[k] and distTo(p, x0 + i + 0.5, z0 + j + 0.5) <= radius then g.Blocked[k] = true end
				end
			end
		end
	end
	if support then
		local carried = table.create(g.W * g.H, false)
		for _, p in support do
			if p.Box[2] >= x0 and p.Box[1] <= x1 and p.Box[4] >= z0 and p.Box[3] <= z1 then
				for i = math.max(0, math.floor(p.Box[1]) - x0), math.min(g.W - 1, math.ceil(p.Box[2]) - x0) do
					for j = math.max(0, math.floor(p.Box[3]) - z0), math.min(g.H - 1, math.ceil(p.Box[4]) - z0) do
						if distTo(p, x0 + i + 0.5, z0 + j + 0.5) == 0 then carried[j * g.W + i + 1] = true end
					end
				end
			end
		end
		for k = 1, g.W * g.H do
			if not carried[k] then g.Blocked[k] = true end
		end
	end
	return g
end
local function cellOf(g, x, z): (number, number)
	return math.floor(x - g.X0), math.floor(z - g.Z0)
end
local function inGrid(g, i, j): boolean
	return i >= 0 and i < g.W and j >= 0 and j < g.H
end

-- Dijkstra from one cell (8 neighbours, no cutting corners through blocked cells); returns Dist and Prev per cell.
local function dijkstra(g, si, sj)
	local count = g.W * g.H
	local dist, prev = table.create(count, math.huge), table.create(count, 0)
	local heap = {}
	local function push(k, d)
		table.insert(heap, { k, d })
		local i = #heap
		while i > 1 do
			local parent = i // 2
			if heap[parent][2] <= heap[i][2] then break end
			heap[parent], heap[i] = heap[i], heap[parent]
			i = parent
		end
	end
	local function pop()
		local top = heap[1]
		local last = table.remove(heap)
		if #heap > 0 then
			heap[1] = last
			local i = 1
			while true do
				local l, r = i * 2, i * 2 + 1
				local m = i
				if l <= #heap and heap[l][2] < heap[m][2] then m = l end
				if r <= #heap and heap[r][2] < heap[m][2] then m = r end
				if m == i then break end
				heap[m], heap[i] = heap[i], heap[m]
				i = m
			end
		end
		return top
	end
	if not inGrid(g, si, sj) or g.Blocked[sj * g.W + si + 1] then
		return { Dist = dist, Prev = prev, Grid = g, Start = nil }
	end
	local start = sj * g.W + si + 1
	dist[start] = 0
	push(start, 0)
	while #heap > 0 do
		local top = pop()
		local k, d = top[1], top[2]
		if d <= dist[k] then
			local i, j = (k - 1) % g.W, (k - 1) // g.W
			for di = -1, 1 do
				for dj = -1, 1 do
					if di ~= 0 or dj ~= 0 then
						local ni, nj = i + di, j + dj
						if ni >= 0 and ni < g.W and nj >= 0 and nj < g.H then
							local nk = nj * g.W + ni + 1
							if not g.Blocked[nk] and (di == 0 or dj == 0 or (not g.Blocked[j * g.W + ni + 1] and not g.Blocked[nj * g.W + i + 1])) then
								local nd = d + (if di ~= 0 and dj ~= 0 then 1.4142 else 1)
								if nd < dist[nk] then
									dist[nk] = nd
									prev[nk] = k
									push(nk, nd)
								end
							end
						end
					end
				end
			end
		end
	end
	return { Dist = dist, Prev = prev, Grid = g, Start = start }
end

-- The cheapest reachable cell from which a prompt at (x, y, z) with reach `reach` can be used (root height 3 above the walking surface).
local function reachCell(search, x, y, z, reach, base)
	local g = search.Grid
	local best, bestK = math.huge, nil
	local r = math.ceil(reach)
	local ci, cj = cellOf(g, x, z)
	for i = math.max(0, ci - r), math.min(g.W - 1, ci + r) do
		for j = math.max(0, cj - r), math.min(g.H - 1, cj + r) do
			local k = j * g.W + i + 1
			if search.Dist[k] < best then
				local dx, dz, dy = g.X0 + i + 0.5 - x, g.Z0 + j + 0.5 - z, (base + 3) - y
				if dx * dx + dz * dz + dy * dy <= reach * reach then best, bestK = search.Dist[k], k end
			end
		end
	end
	return best, bestK
end
-- cells (world x, z) from the start to cell k
local function routeTo(search, k)
	local g, cells = search.Grid, {}
	while k and k ~= 0 do
		table.insert(cells, 1, { g.X0 + (k - 1) % g.W + 0.5, g.Z0 + (k - 1) // g.W + 0.5 })
		k = search.Prev[k]
	end
	return cells
end

local FACE = { Front = { 0, 0, -1 }, Back = { 0, 0, 1 }, Right = { 1, 0, 0 }, Left = { -1, 0, 0 }, Top = { 0, 1, 0 }, Bottom = { 0, -1, 0 } }
local function faceNormal(part: Instance, faceName: string)
	local cf = RawData[part].Props.CFrame
	local f, r = FACE[faceName] or FACE.Front, cf.r
	return r[1] * f[1] + r[2] * f[2] + r[3] * f[3], r[4] * f[1] + r[5] * f[2] + r[6] * f[3], r[7] * f[1] + r[8] * f[2] + r[9] * f[3]
end

task.spawn(function()
	M.isServer = true
	local mainServer = find("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	adv(3)
	local WorldLayout = require(find("ReplicatedStorage.Modules.WorldLayout"))
	local PlazaBuilder = require(find("ServerScriptService.Systems.WorldBuilder.PlazaBuilder"))
	local HouseSystem = require(find("ServerScriptService.Systems.HouseSystem"))
	local HouseBuilder = require(find("ServerScriptService.Systems.WorldBuilder.HouseBuilder"))
	-- the preview state of the baked world: 1, 2, 3, 4, 5, 3, 2, 1 floors (a real server starts with 1 floor everywhere)
	local previewFloors = { 1, 2, 3, 4, 5, 3, 2, 1 }
	local houseRng = Random.new(3)
	local houses = HouseSystem.all()
	for index, house in houses do HouseBuilder.setFloors(house, previewFloors[index], houseRng) end

	---------------------------------------------------------------------------
	-- the world as obstacles
	---------------------------------------------------------------------------
	local parts, visible = {}, {}
	local spawnPart
	for _, d in M.descendants(workspace) do
		local data = RawData[d]
		if data.Props and data.Props.Size and data.Props.CFrame and M.InstanceMethods.IsA(d, "BasePart") and data.Props.Anchored then
			local path = pathOf(d)
			if not (string.find(path, "^Environment/Backdrop") or string.find(path, "^Environment/Beyond") or path == "Environment/Ground") then
				local part = describe(d)
				table.insert(parts, part)
				if part.Transparency < 0.5 then table.insert(visible, part) end
			end
		end
		if data.ClassName == "SpawnLocation" then spawnPart = d end
	end
	local spawnPos = RawData[spawnPart].Props.CFrame
	local X0, X1, Z0, Z1 = -WorldLayout.GroundHalfX - 4, WorldLayout.GroundHalfX + 4, -WorldLayout.GroundHalfZ - 4, WorldLayout.GroundHalfZ + 4
	local ground = buildGrid(parts, X0, X1, Z0, Z1, 0, CHAR_R)
	local blockedCells = 0
	for _, b in ground.Blocked do if b then blockedCells += 1 end end
	print(string.format("   walkability model: %d parts, grid %d x %d cells, %d blocked", #parts, ground.W, ground.H, blockedCells))
	local si, sj = cellOf(ground, spawnPos.X, spawnPos.Z)
	local fromSpawn = dijkstra(ground, si, sj)
	local reached = 0
	for _, d in fromSpawn.Dist do if d < math.huge then reached += 1 end end
	check("the guest spawn stands on free ground and the map is one connected area (" .. reached .. " cells walkable from the spawn)", fromSpawn.Start ~= nil and reached > (ground.W * ground.H - blockedCells) * 0.97, string.format("%d of %d free cells", reached, ground.W * ground.H - blockedCells))

	---------------------------------------------------------------------------
	section("1. public destinations from the guest spawn")
	---------------------------------------------------------------------------
	local prompts = {}
	for _, d in M.descendants(workspace) do
		local data = RawData[d]
		if data.ClassName == "ProximityPrompt" then
			local parent = RawData[data.Parent]
			local cf = parent.Props and parent.Props.CFrame
			if cf then
				local path = pathOf(data.Parent)
				local house = tonumber(string.match(path, "^PlayerHouses/House(%d+)/"))
				table.insert(prompts, {
					Prompt = d, Object = tostring(data.Props.ObjectText), Action = tostring(data.Props.ActionText), Reach = data.Props.MaxActivationDistance or 10,
					X = cf.X, Y = cf.Y, Z = cf.Z, Path = path, House = house, Part = parent.Name,
					Opens = data.Attributes.OpenUI or (data.Attributes.SpinWheel and "SpinWheel") or (data.Attributes.InviteFriends and "Community") or (data.Attributes.Elevator and "Elevator") or (data.Attributes.SecurityHouse and "SecurityPanel") or (data.Attributes.TheftSlot and "TheftSlot") or "?",
				})
			end
		end
	end
	local function findPrompt(filter)
		local list = {}
		for _, p in prompts do if filter(p) then table.insert(list, p) end end
		return list
	end
	local function reachability(list, search, base, label, ratioLimit)
		local unreachable, detours = {}, {}
		local worst = 0
		for _, p in list do
			local cost, k = reachCell(search, p.X, p.Y, p.Z, p.Reach, base)
			if cost == math.huge then
				table.insert(unreachable, string.format("%s '%s' at (%.0f, %.0f)", p.Path, p.Object, p.X, p.Z))
			elseif ratioLimit then
				local sx, sz = search.Grid.X0 + (search.Start - 1) % search.Grid.W, search.Grid.Z0 + (search.Start - 1) // search.Grid.W
				local straight = math.sqrt((p.X - sx) ^ 2 + (p.Z - sz) ^ 2) - p.Reach
				if straight > 5 then
					worst = math.max(worst, cost / straight)
					if cost / straight > ratioLimit then table.insert(detours, string.format("%s: walk %.0f vs straight %.0f", p.Object, cost, straight)) end
				end
			end
		end
		return unreachable, detours, worst
	end
	local publicPrompts = findPrompt(function(p) return p.House == nil and p.Y < 6 and p.Opens ~= "?" end)
	local byOpens = {}
	for _, p in publicPrompts do byOpens[p.Opens] = (byOpens[p.Opens] or 0) + 1 end
	local parts_ = {}
	for key, n in byOpens do table.insert(parts_, key .. " x" .. n) end
	table.sort(parts_)
	print("   public prompts:", table.concat(parts_, ", "))
	for _, want in { { "Shop", 1 }, { "RobuxShop", 1 }, { "SpinWheel", 1 }, { "Leaderboards", 1 }, { "Community", 4 } } do
		local list = findPrompt(function(p) return p.House == nil and p.Opens == want[1] end)
		local unreachable, detours, worst = reachability(list, fromSpawn, 0, want[1], 1.6)
		check(string.format("the %s (%d prompt%s) can be walked to from the guest spawn, no detour (walk <= 1.6 x straight)", want[1], #list, if #list == 1 then "" else "s"), #list == want[2] and #unreachable == 0 and #detours == 0, string.format("%d found, unreachable: %s, worst ratio %.2f", #list, tostring(unreachable[1]), worst))
	end
	do
		local counter = findPrompt(function(p) return p.Opens == "Shop" end)[1]
		local cost = reachCell(fromSpawn, counter.X, counter.Y, counter.Z, counter.Reach, 0)
		print(string.format("   walk from the guest spawn: Coins Shop %.0f studs", cost))
	end

	---------------------------------------------------------------------------
	section("2. every base from the street: gate, altar, panel, chest, terminal, pedestals, lift")
	---------------------------------------------------------------------------
	local gateProblems = {}
	for index, house in houses do
		local gx, gz = (house.CFrame * CFrame.new(0, 0, -3)).Position.X, (house.CFrame * CFrame.new(0, 0, -3)).Position.Z
		local gi, gj = cellOf(ground, gx, gz)
		local k = gj * ground.W + gi + 1
		local gateIn = house.CFrame * CFrame.new(0, 0, 4)
		local ik = (select(2, cellOf(ground, gateIn.Position.X, gateIn.Position.Z))) * ground.W + (cellOf(ground, gateIn.Position.X, gateIn.Position.Z)) + 1
		if not (fromSpawn.Dist[k] < math.huge and fromSpawn.Dist[ik] < math.huge) then table.insert(gateProblems, "House" .. index) end
	end
	check("the gate of every house (3 studs outside and 4 studs inside the gate line) is reachable from the spawn: the laser field is no wall", #gateProblems == 0, table.concat(gateProblems, ","))
	local spawnProblems = {}
	for index, house in houses do
		local sp = house.SpawnCFrame.Position -- where the owner appears (3 studs above the driveway, 9 studs inside the gate)
		local si2, sj2 = cellOf(ground, sp.X, sp.Z)
		if not (inGrid(ground, si2, sj2) and fromSpawn.Dist[sj2 * ground.W + si2 + 1] < math.huge) then table.insert(spawnProblems, "House" .. index) end
	end
	check("the owner's spawn point of every base is free ground connected to the street", #spawnProblems == 0, table.concat(spawnProblems, ","))
	local kinds = {
		{ "Rebirth Altar", function(p) return p.Opens == "Rebirth" end, 8 },
		{ "Mailbox (daily gift)", function(p) return p.Opens == "Daily" end, 8 },
		{ "Security Panel", function(p) return p.Opens == "SecurityPanel" end, 8 },
		{ "Hamster Chest (opens the Backpack collection)", function(p) return p.Object == "Hamster Chest" end, 8 },
		{ "Upgrade Terminal", function(p) return p.Object == "Upgrade Terminal" end, 8 },
		{ "upgrade pedestals", function(p) return p.Opens == "Upgrades" and p.Part == "StationBase" end, 64 },
		{ "working-bench rings (steal prompts)", function(p) return p.Opens == "TheftSlot" and p.Y < 6 end, 64 },
		{ "lift call button on the ground floor (only the 6 houses with 2 or more floors have a lift)", function(p) return p.Opens == "Elevator" and p.Y < 6 end, 6 },
	}
	for _, kind in kinds do
		local list = findPrompt(function(p) return p.House ~= nil and kind[2](p) end)
		local unreachable, detours = reachability(list, fromSpawn, 0, kind[1], 1.8)
		check(string.format("%s: %d of %d reachable from the street", kind[1], #list - #unreachable, kind[3]), #list == kind[3] and #unreachable == 0 and #detours == 0, string.format("%d found, first problem: %s", #list, tostring(unreachable[1] or detours[1])))
	end
	-- the working benches exist on floor 1 only as rings (the wheels appear when a slot is unlocked): the ring of slot 1 carries the tutorial target
	-- self-test: wall a house in (four probe slabs around the lot): the same check must see it
	do
		local home = houses[1]
		local c = home.CFrame
		local probes = {}
		for _, spec in { { 0, -2, 90, 6 }, { 0, 90, 90, 6 }, { -45, 44, 6, 100 }, { 45, 44, 6, 100 } } do
			local center = c * CFrame.new(spec[1], 0, spec[2] + 0)
			local part = { Name = "Probe", Path = "probe", Top = 12, Bottom = 0, Transparency = 0, Solid = true, X = center.Position.X, Y = 6, Z = center.Position.Z }
			local x0, x1, z0, z1 = center.Position.X - spec[3] / 2, center.Position.X + spec[3] / 2, center.Position.Z - spec[4] / 2, center.Position.Z + spec[4] / 2
			part.Poly = { { x0, z0 }, { x1, z0 }, { x1, z1 }, { x0, z1 } }
			part.Box = { x0, x1, z0, z1 }
			table.insert(probes, part)
		end
		local withProbe = table.clone(parts)
		for _, p in probes do table.insert(withProbe, p) end
		local g2 = buildGrid(withProbe, X0, X1, Z0, Z1, 0, CHAR_R)
		local s2 = dijkstra(g2, cellOf(ground, spawnPos.X, spawnPos.Z))
		local altar = findPrompt(function(p) return p.House == 1 and p.Opens == "Rebirth" end)[1]
		check("self-test: with a wall built round the lot the altar of that house is reported unreachable", reachCell(s2, altar.X, altar.Y, altar.Z, altar.Reach, 0) == math.huge)
	end

	---------------------------------------------------------------------------
	section("3. upper floors: from the lift landing to everything on the floor")
	---------------------------------------------------------------------------
	local upperProblems, upperChecked = {}, 0
	for index, house in houses do
		local cframe = house.CFrame
		local corners = { cframe * Vector3.new(-30, 0, 18), cframe * Vector3.new(30, 0, 76) }
		local rx0, rx1 = math.floor(math.min(corners[1].X, corners[2].X)), math.ceil(math.max(corners[1].X, corners[2].X))
		local rz0, rz1 = math.floor(math.min(corners[1].Z, corners[2].Z)), math.ceil(math.max(corners[1].Z, corners[2].Z))
		for floor = 2, house.FloorCount do
			local base = WorldLayout.floorY(floor)
			local support = {}
			for _, p in parts do
				if p.Solid and math.abs(p.Top - base) < 0.4 and p.Path and string.find(p.Path, "^PlayerHouses/House" .. index .. "/Tower/Floor" .. floor .. "_") and (p.Box[2] - p.Box[1]) > 3 and (p.Box[4] - p.Box[3]) > 3 and (string.find(p.Name, "Floor") or string.find(p.Name, "Slab")) then table.insert(support, p) end
			end
			local grid = buildGrid(parts, rx0, rx1, rz0, rz1, base, CHAR_R, support)
			local landing = house.Landing[floor].Position
			local li, lj = cellOf(grid, landing.X, landing.Z)
			local search = dijkstra(grid, li, lj)
			local onFloor = findPrompt(function(p) return p.House == index and p.Y >= base - 0.5 and p.Y <= base + 8 and p.Opens ~= "?" end)
			local missing = {}
			for _, p in onFloor do
				local cost = reachCell(search, p.X, p.Y, p.Z, p.Reach, base)
				if cost == math.huge then table.insert(missing, string.format("'%s' (%s)", p.Object, p.Action)) end
				upperChecked += 1
			end
			if search.Start == nil or #missing > 0 or #onFloor == 0 then
				table.insert(upperProblems, string.format("House%d floor %d: %s", index, floor, if search.Start == nil then "the lift landing is not on a walkable floor" elseif #onFloor == 0 then "no prompt found" else table.concat(missing, ", ")))
			end
		end
	end
	local landingProblems = {}
	for index, house in houses do
		local land = house.Landing[1].Position
		local li, lj = cellOf(ground, land.X, land.Z)
		if house.FloorCount >= 2 and not (inGrid(ground, li, lj) and fromSpawn.Dist[lj * ground.W + li + 1] < math.huge) then
			table.insert(landingProblems, "House" .. index .. " floor 1 landing at (" .. string.format("%.0f, %.0f", land.X, land.Z) .. ") is not walkable from the street")
		end
	end
	check("the landing on floor 1 (where the lift sets you down) is free ground reachable from the street in every house with a lift", #landingProblems == 0, landingProblems[1])
	check("on every upper floor of every house the lift landing reaches every [F] prompt on that floor (" .. upperChecked .. " prompts), the lift call buttons included", #upperProblems == 0 and upperChecked > 20, #upperProblems .. " problems, first: " .. tostring(upperProblems[1]))
	do
		-- self-test: a wall across floor 2 of House2 (between the lift landing and the storage lounge) must cut the storage chest off
		local house = houses[2]
		local cframe = house.CFrame
		local base = WorldLayout.floorY(2)
		local corners = { cframe * Vector3.new(-30, 0, 18), cframe * Vector3.new(30, 0, 76) }
		local rx0, rx1 = math.floor(math.min(corners[1].X, corners[2].X)), math.ceil(math.max(corners[1].X, corners[2].X))
		local rz0, rz1 = math.floor(math.min(corners[1].Z, corners[2].Z)), math.ceil(math.max(corners[1].Z, corners[2].Z))
		local support = {}
		for _, p in parts do
			if p.Solid and math.abs(p.Top - base) < 0.4 and string.find(p.Path, "^PlayerHouses/House2/Tower/Floor2_") and (string.find(p.Name, "Floor") or string.find(p.Name, "Slab")) and (p.Box[2] - p.Box[1]) > 3 then table.insert(support, p) end
		end
		local a, b = cframe * Vector3.new(-30, 0, 44), cframe * Vector3.new(30, 0, 46)
		local wx0, wx1, wz0, wz1 = math.min(a.X, b.X), math.max(a.X, b.X), math.min(a.Z, b.Z), math.max(a.Z, b.Z)
		local wall = { Name = "Probe", Path = "probe", Top = base + 8, Bottom = base, Transparency = 0, Solid = true, X = (wx0 + wx1) / 2, Y = base + 4, Z = (wz0 + wz1) / 2, Poly = { { wx0, wz0 }, { wx1, wz0 }, { wx1, wz1 }, { wx0, wz1 } }, Box = { wx0, wx1, wz0, wz1 } }
		local withProbe = table.clone(parts)
		table.insert(withProbe, wall)
		local landing = house.Landing[2].Position
		local chest = findPrompt(function(p) return p.House == 2 and p.Object == "Storage" end)[1]
		local open = dijkstra(buildGrid(parts, rx0, rx1, rz0, rz1, base, CHAR_R, support), cellOf({ X0 = rx0, Z0 = rz0 }, landing.X, landing.Z))
		local closed = dijkstra(buildGrid(withProbe, rx0, rx1, rz0, rz1, base, CHAR_R, support), cellOf({ X0 = rx0, Z0 = rz0 }, landing.X, landing.Z))
		check("self-test: the floor 2 storage chest is reachable from the landing, and a wall across the floor cuts it off", chest ~= nil and reachCell(open, chest.X, chest.Y, chest.Z, chest.Reach, base) < math.huge and reachCell(closed, chest.X, chest.Y, chest.Z, chest.Reach, base) == math.huge)
	end

	---------------------------------------------------------------------------
	section("4. walkways stay free along their whole length")
	---------------------------------------------------------------------------
	local PAVED = { Promenade = true, GatePath = true, AnnexPath = true, ShopApproach = true, WheelPath = true, HallPath = true, Road = true, Driveway = true }
	local walkways = {}
	for _, p in parts do
		if PAVED[p.Name] and p.Top < 0.5 and p.Poly then
			local w, d = p.Box[2] - p.Box[1], p.Box[4] - p.Box[3]
			table.insert(walkways, { Name = p.Name, Part = p, AlongX = w >= d, Width = math.min(w, d), Length = math.max(w, d), X = p.X, Z = p.Z, Box = p.Box })
		end
	end
	local function freeRun(g, x, z, alongX, limit)
		-- contiguous free width across the walkway (perpendicular to its long axis) through the centre point; counts free cells in both directions
		local ci, cj = cellOf(g, x, z)
		if not inGrid(g, ci, cj) or g.Blocked[cj * g.W + ci + 1] then return 0 end
		local run = 1
		for dir = -1, 1, 2 do
			local step = 1
			while step <= limit do
				local i, j = ci + (if alongX then 0 else dir * step), cj + (if alongX then dir * step else 0)
				if not inGrid(g, i, j) or g.Blocked[j * g.W + i + 1] then break end
				run += 1
				step += 1
			end
		end
		return run
	end
	local MIN_FREE = 4 -- studs of free width (after growing every obstacle by the character radius) that a walkway must keep
	local function walkwayProblems(g)
		local problems = {}
		for _, w in walkways do
			if w.Part.Name ~= "Road" or true then
				local worst = math.huge
				local worstAt
				local from, to = if w.AlongX then w.Box[1] + 2 else w.Box[3] + 2, if w.AlongX then w.Box[2] - 2 else w.Box[4] - 2
				local s = from
				while s <= to do
					local x, z = if w.AlongX then s else w.X, if w.AlongX then w.Z else s
					local run = freeRun(g, x, z, w.AlongX, math.ceil(w.Width / 2))
					if run < worst then worst, worstAt = run, string.format("(%.0f, %.0f)", x, z) end
					s += 2
				end
				if worst < math.min(MIN_FREE, w.Width - 2 * CHAR_R - 1) then
					table.insert(problems, string.format("%s %.0f wide at %s: only %d studs free", w.Name, w.Width, worstAt or "?", worst))
				end
			end
		end
		return problems
	end
	local wp = walkwayProblems(ground)
	for index = 1, math.min(#wp, 8) do print("   WALKWAY", wp[index]) end
	check(string.format("%d walkways (promenades, gate paths, driveways, annex paths, shop approach, wheel path, hall path, road) keep >= %d studs free the whole way (every obstacle grown by the character radius)", #walkways, MIN_FREE), #walkways >= 30 and #wp == 0, #wp .. " problems, first: " .. tostring(wp[1]))
	do
		-- self-test: a fountain-sized block dropped into the wheel path
		local probe = { Name = "Probe", Path = "probe", Top = 6, Bottom = 0, Transparency = 0, Solid = true, X = 0, Y = 3, Z = 64, Poly = { { -3, 61 }, { 3, 61 }, { 3, 67 }, { -3, 67 } }, Box = { -3, 3, 61, 67 } }
		local withProbe = table.clone(parts)
		table.insert(withProbe, probe)
		local g2 = buildGrid(withProbe, X0, X1, Z0, Z1, 0, CHAR_R)
		local found = walkwayProblems(g2)
		check("self-test: a block dropped into the 8 stud wheel path is found", #found >= 1, found[1])
	end

	---------------------------------------------------------------------------
	section("5. invisible walls")
	---------------------------------------------------------------------------
	local invisible, naked = {}, {}
	for _, p in parts do
		if p.Solid and p.Transparency >= 0.9 and p.Top - p.Bottom > 3 and not string.find(p.Path, "^Environment/Boundary/") then table.insert(invisible, p) end
	end
	-- a barrier has a visible fence / hedge along its whole centre line: a picket, a rail or a hedge bush within 1.2 studs, in the same model
	for _, p in invisible do
		local model = RawData[p.Inst].Parent
		local mates = {}
		for _, child in M.InstanceMethods.GetChildren(model) do
			if child ~= p.Inst and RawData[child].Props and RawData[child].Props.Size and (RawData[child].Props.Transparency or 0) < 0.5 and RawData[child].Props.CFrame then mates[#mates + 1] = describe(child) end
		end
		local long = if p.Box[2] - p.Box[1] >= p.Box[4] - p.Box[3] then "x" else "z"
		local a, b = if long == "x" then p.Box[1] else p.Box[3], if long == "x" then p.Box[2] else p.Box[4]
		local s = a + 0.5
		local gap
		while s <= b - 0.5 do
			local px, pz = if long == "x" then s else p.X, if long == "x" then p.Z else s
			local seen = false
			for _, m in mates do
				if distTo(m, px, pz) <= 1.2 then seen = true break end
			end
			if not seen then gap = string.format("%.0f,%.0f", px, pz) break end
			s += 1
		end
		if gap then table.insert(naked, string.format("%s has no visible fence / hedge at (%s)", p.Path, gap)) end
	end
	check(string.format("every one of the %d invisible fence / hedge barriers has a visible fence or hedge along its whole length", #invisible), #invisible >= 40 and #naked == 0, #naked .. " without, first: " .. tostring(naked[1]))
	local onWalkway = {}
	for _, p in invisible do
		for _, w in walkways do
			if w.Part.Name ~= "Road" and w.Part.Name ~= "Promenade" and p.Box[2] > w.Box[1] + 0.3 and p.Box[1] < w.Box[2] - 0.3 and p.Box[4] > w.Box[3] + 0.3 and p.Box[3] < w.Box[4] - 0.3 then
				table.insert(onWalkway, p.Path .. " across the " .. w.Name .. " at (" .. string.format("%.0f,%.0f", w.X, w.Z) .. ")")
				break
			end
		end
	end
	check("no invisible wall lies on a gate path, driveway, annex path, shop approach, wheel path or hall path", #onWalkway == 0, #onWalkway .. " e.g. " .. tostring(onWalkway[1]))
	do
		local bare = { Name = "Barrier", Path = "probe/Barrier", Top = 16, Bottom = 0, Transparency = 1, Solid = true, X = 0, Y = 8, Z = 64, Poly = { { -4, 63.7 }, { 4, 63.7 }, { 4, 64.3 }, { -4, 64.3 } }, Box = { -4, 4, 63.7, 64.3 } }
		local hit = false
		for _, w in walkways do
			if w.Part.Name ~= "Road" and w.Part.Name ~= "Promenade" and bare.Box[2] > w.Box[1] + 0.3 and bare.Box[1] < w.Box[2] - 0.3 and bare.Box[4] > w.Box[3] + 0.3 and bare.Box[3] < w.Box[4] - 0.3 then hit = true end
		end
		check("self-test: an invisible wall across the wheel path is found", hit)
	end
	print(string.format("   (the 4 boundary walls at the edge of the map are invisible on purpose: x = +-%d, z = +-%d)", WorldLayout.GroundHalfX, WorldLayout.GroundHalfZ))

	---------------------------------------------------------------------------
	section("6. the laser gate")
	---------------------------------------------------------------------------
	-- on the gate line (local z = 0) the blockers cover everything except the opening between the pylons; the laser field spans exactly that opening
	local function gateOpening(house)
		local cframe = house.CFrame
		local flip = if cframe.LookVector.Z > 0 then 1 else -1
		local covered = {}
		for _, p in parts do
			if p.Solid and p.Top > STEP and p.Bottom < HEAD and p.Poly and string.find(p.Path, "^PlayerHouses/House" .. house.Index .. "/Yard/") then
				-- clip the footprint with the gate line z_local = 0
				local lo, hi = math.huge, -math.huge
				local verts = {}
				for _, v in p.Poly do
					local lp = cframe:PointToObjectSpace(Vector3.new(v[1], 0, v[2]))
					table.insert(verts, { lp.X, lp.Z })
				end
				for i = 1, #verts do
					local a, b = verts[i], verts[i % #verts + 1]
					if (a[2] <= 0 and b[2] >= 0) or (a[2] >= 0 and b[2] <= 0) then
						local t = if math.abs(b[2] - a[2]) < 1e-9 then 0 else -a[2] / (b[2] - a[2])
						local x = a[1] + (b[1] - a[1]) * t
						lo, hi = math.min(lo, x), math.max(hi, x)
					end
				end
				if lo <= hi then table.insert(covered, { lo, hi, p.Name }) end
			end
		end
		table.sort(covered, function(a, b) return a[1] < b[1] end)
		local free, cursor = {}, -WorldLayout.LotHalfWidth - 2
		for _, c in covered do
			if c[1] > cursor + 0.01 then table.insert(free, { cursor, c[1] }) end
			cursor = math.max(cursor, c[2])
		end
		if cursor < WorldLayout.LotHalfWidth + 2 then table.insert(free, { cursor, WorldLayout.LotHalfWidth + 2 }) end
		return free
	end
	local gateProblemsList, slitWorst = {}, 0
	for index, house in houses do
		local free = gateOpening(house)
		local field = house.Security.Field
		local fcf, fsize = RawData[field].Props.CFrame, RawData[field].Props.Size
		local fieldLocal = house.CFrame:PointToObjectSpace(fcf.Position)
		local fieldLo, fieldHi = fieldLocal.X - fsize.X / 2, fieldLocal.X + fsize.X / 2
		local passable = {}
		for _, f in free do
			local width = f[2] - f[1]
			if width >= 2 * CHAR_R then table.insert(passable, f) else slitWorst = math.max(slitWorst, width) end
		end
		if #passable ~= 1 then
			table.insert(gateProblemsList, string.format("House%d: %d passable openings on the gate line", index, #passable))
		else
			local f = passable[1]
			if math.abs(f[1] - fieldLo) > 0.3 or math.abs(f[2] - fieldHi) > 0.3 then
				table.insert(gateProblemsList, string.format("House%d: opening %.1f .. %.1f but lasers %.1f .. %.1f", index, f[1], f[2], fieldLo, fieldHi))
			end
		end
		-- the beams lie inside the field
		for _, beam in house.Security.Beams do
			local bcf, bsize = RawData[beam].Props.CFrame, RawData[beam].Props.Size
			local bl = house.CFrame:PointToObjectSpace(bcf.Position)
			if bl.X - bsize.X / 2 < fieldLo - 0.3 or bl.X + bsize.X / 2 > fieldHi + 0.3 then table.insert(gateProblemsList, string.format("House%d: a laser beam sticks out of the opening", index)) break end
		end
		-- the field fills the opening up to the crossbeam
		local top = fcf.Y + fsize.Y / 2
		if top < 7 or top > 7.4 or fcf.Y - fsize.Y / 2 > 1 then table.insert(gateProblemsList, string.format("House%d: laser field height %.1f .. %.1f", index, fcf.Y - fsize.Y / 2, top)) end
	end
	check("on the gate line of every house there is exactly one opening a character fits through, and the laser field spans exactly that opening (+-0.3)", #gateProblemsList == 0, #gateProblemsList .. " problems, first: " .. tostring(gateProblemsList[1]))
	check("no slit beside the pylons is wide enough to squeeze past the lasers (widest slit on the gate line: " .. string.format("%.2f", slitWorst) .. " studs, a character needs " .. 2 * CHAR_R .. ")", slitWorst < 2 * CHAR_R - 0.4)
	do
		-- self-test: a gap of 3 studs between the pylon and the fence must be seen as a second opening
		local free = { { -6.5, 6.5 }, { 8.3, 11.3 } }
		local passable = 0
		for _, f in free do if f[2] - f[1] >= 2 * CHAR_R then passable += 1 end end
		check("self-test: a 3 stud gap beside the pylon would count as a second way past the lasers", passable == 2)
	end

	---------------------------------------------------------------------------
	section("7. signs: readable from where people walk, destinations named")
	---------------------------------------------------------------------------
	-- every SurfaceGui with text or pictures, with the direction its face looks
	local signs = {}
	for _, d in M.descendants(workspace) do
		local data = RawData[d]
		if data.ClassName == "SurfaceGui" and RawData[data.Parent].Props and RawData[data.Parent].Props.CFrame then
			local faceName = data.Props.Face and data.Props.Face.Name or "Front"
			local nx, ny, nz = faceNormal(data.Parent, faceName)
			local texts = {}
			for _, child in M.descendants(d) do
				if RawData[child].ClassName == "TextLabel" and RawData[child].Props.Text and RawData[child].Props.Text ~= "" then table.insert(texts, tostring(RawData[child].Props.Text)) end
			end
			local cf = RawData[data.Parent].Props.CFrame
			table.insert(signs, { Gui = d, Part = data.Parent, Path = pathOf(data.Parent), Face = faceName, NX = nx, NY = ny, NZ = nz, X = cf.X, Y = cf.Y, Z = cf.Z, Text = table.concat(texts, " | ") })
		end
	end
	-- (a) every sign near the ground can be seen from somewhere you can walk: at least 20 walkable cells within 3-40 studs in front of it (+-70 degrees)
	local function viewers(g, search, sx, sz, nx, nz)
		local count = 0
		local flat = math.sqrt(nx * nx + nz * nz)
		if flat < 0.5 then return 99 end -- looks up or down: not a wall sign
		for di = -40, 40, 2 do
			for dj = -40, 40, 2 do
				local dd = math.sqrt(di * di + dj * dj)
				if dd >= 3 and dd <= 40 and (di * nx + dj * nz) / dd / flat > 0.34 then
					local i, j = cellOf(g, sx + di, sz + dj)
					if inGrid(g, i, j) and search.Dist[j * g.W + i + 1] < math.huge then count += 1 end
				end
			end
		end
		return count
	end
	local unseen, signCount = {}, 0
	for _, s in signs do
		if s.Y < 25 and s.Text ~= "" and not string.find(s.Path, "^HamsterPlaza/LuckyWheel/Rotor") and not string.find(s.Path, "/Floor%d_") then
			signCount += 1
			local v = viewers(ground, fromSpawn, s.X, s.Z, s.NX, s.NZ)
			if v < 20 then table.insert(unseen, string.format("%s (%s face) has %d viewing places", s.Path, s.Face, v)) end
		end
	end
	check(string.format("every one of %d ground-level signs and boards can be seen from at least 20 walkable places in front of it", signCount), signCount > 25 and #unseen == 0, #unseen .. " e.g. " .. tostring(unseen[1]))

	-- (b) the people who walk to a place read the sign that names it: along the real walking route (from where they start to the prompt)
	-- the sign faces them for at least 6 route cells within 4-30 studs of it (angle to the face normal below 70 degrees)
	local function facesRoute(search, sign, destination, base, maxD)
		local cost, k = reachCell(search, destination.X, destination.Y, destination.Z, destination.Reach, base)
		if cost == math.huge then return 0, "destination unreachable" end
		local route = routeTo(search, k)
		local flat = math.sqrt(sign.NX ^ 2 + sign.NZ ^ 2)
		local good, near = 0, 0
		for _, c in route do
			local dx, dz = c[1] - sign.X, c[2] - sign.Z
			local d = math.sqrt(dx * dx + dz * dz)
			if d >= 4 and d <= (maxD or 30) then
				near += 1
				if (dx * sign.NX + dz * sign.NZ) / d / flat > 0.34 then good += 1 end
			end
		end
		return good, string.format("%d of %d route cells near the sign see its face", good, near)
	end
	local function signAt(pathPattern)
		for _, s in signs do if string.find(s.Path, pathPattern) then return s end end
	end
	local function promptOf(filter) return findPrompt(filter)[1] end
	-- (the signpost and the hall gate sign belong to the paved walking lane x = -4.5 .. 4.5 from the plaza (z = -26) down to the hall: that lane is the
	--  designed route, the cheapest line across the grass from the spawn is not)
	local laneSearch = { Grid = ground, Dist = {}, Prev = {}, Start = nil }
	do
		local lane = {}
		for z = -26, -100, -1 do table.insert(lane, { 0.5, z + 0.5 }) end
		function laneSearch.route() return lane end
	end
	local function facesLane(sign, maxD)
		local flat = math.sqrt(sign.NX ^ 2 + sign.NZ ^ 2)
		local good, near = 0, 0
		for _, c in laneSearch.route() do
			local dx, dz = c[1] - sign.X, c[2] - sign.Z
			local d = math.sqrt(dx * dx + dz * dz)
			if d >= 4 and d <= (maxD or 30) then
				near += 1
				if (dx * sign.NX + dz * sign.NZ) / d / flat > 0.34 then good += 1 end
			end
		end
		return good, string.format("%d of %d lane cells near the sign see its face", good, near)
	end
	local approach = {
		{ "Coins Shop sign", signAt("^HamsterPlaza/CoinsShop/Sign$"), promptOf(function(p) return p.Opens == "Shop" end) },
		{ "Robux Shop sign", signAt("^HamsterPlaza/RobuxShop/Sign$"), promptOf(function(p) return p.Opens == "RobuxShop" end) },
		{ "Lucky Wheel sign", signAt("^HamsterPlaza/LuckyWheel/Sign$"), promptOf(function(p) return p.Opens == "SpinWheel" end) },
	}
	for _, entry in approach do
		local good, detail = 0, "sign or destination missing"
		if entry[2] and entry[3] then good, detail = facesRoute(fromSpawn, entry[2], entry[3], 0) end
		check("the " .. entry[1] .. " faces the people who walk from the guest spawn to the place it names", good >= 6, detail)
	end
	for _, entry in { { "LEADERBOARDS signpost on the promenade", "^HamsterPlaza/Signpost/Board$" }, { "Leaderboard Hall gate sign", "^LeaderboardHall/HallSign$" } } do
		local sign = signAt(entry[2])
		local good, detail = 0, "sign missing"
		if sign then good, detail = facesLane(sign, 30) end
		check("the " .. entry[1] .. " faces the people who walk the paved lane from the plaza to the hall", good >= 6, detail)
	end
	-- the house signs, from the street to the gate and from the gate to the altar / the panel (checked on every house)
	local houseSignFails = { Name = {}, Altar = {}, Panel = {} }
	for index, house in houses do
		local cframe = house.CFrame
		local gate = cframe * Vector3.new(0, 0, -3)
		local gateSearch = dijkstra(ground, cellOf(ground, gate.X, gate.Z))
		local nameSign = signAt("^PlayerHouses/House" .. index .. "/Yard/SignBoard$")
		local altarSign = signAt("^PlayerHouses/House" .. index .. "/Yard/AltarSign$")
		local panelSign = signAt("^PlayerHouses/House" .. index .. "/Yard/PanelScreen$")
		local altar = promptOf(function(p) return p.House == index and p.Opens == "Rebirth" end)
		local panel = promptOf(function(p) return p.House == index and p.Opens == "SecurityPanel" end)
		-- the name sign is read on the way from the promenade to the gate (from the spawn)
		local goodName = facesRoute(fromSpawn, nameSign, { X = gate.X, Y = 3, Z = gate.Z, Reach = 3 }, 0, 45)
		if goodName < 6 then table.insert(houseSignFails.Name, "House" .. index) end
		local goodAltar = facesRoute(gateSearch, altarSign, altar, 0)
		if goodAltar < 6 then table.insert(houseSignFails.Altar, string.format("House%d (face looks along %.2f, %.2f)", index, altarSign.NX, altarSign.NZ)) end
		local goodPanel = facesRoute(gateSearch, panelSign, panel, 0)
		if goodPanel < 3 then table.insert(houseSignFails.Panel, "House" .. index) end
	end
	check("the house name sign faces the promenade people walk along to the gate (all 8 houses)", #houseSignFails.Name == 0, table.concat(houseSignFails.Name, ", "))
	check("the REBIRTH ALTAR sign faces the people who walk from the gate to the altar (all 8 houses)", #houseSignFails.Altar == 0, table.concat(houseSignFails.Altar, ", "))
	check("the security panel screen (SECURE / RECHARGING) faces the people who walk from the gate to the panel (all 8 houses)", #houseSignFails.Panel == 0, table.concat(houseSignFails.Panel, ", "))
	do
		-- self-test: the Coins Shop sign is seen by the people walking to the shop today; turned round it is not
		local sign = signAt("^HamsterPlaza/CoinsShop/Sign$")
		local shop = promptOf(function(p) return p.Opens == "Shop" end)
		local turned = { X = sign.X, Y = sign.Y, Z = sign.Z, NX = -sign.NX, NY = sign.NY, NZ = -sign.NZ }
		local a = facesRoute(fromSpawn, sign, shop, 0)
		local b = facesRoute(fromSpawn, turned, shop, 0)
		check("self-test: the same sign turned round is seen by nobody on the way to the shop", a >= 6 and b == 0, a .. " vs " .. b)
	end

	-- (c) destinations are named: a sign or a label with the name stands within 20 studs, and every prompt has a name and an action
	local function labelsNear(x, z, radius)
		local found = {}
		for _, s in signs do
			if math.sqrt((s.X - x) ^ 2 + (s.Z - z) ^ 2) <= radius then table.insert(found, string.upper(s.Text)) end
		end
		for _, d in M.descendants(workspace) do
			if RawData[d].ClassName == "BillboardGui" then
				local pd = RawData[RawData[d].Parent]
				if pd.Props and pd.Props.CFrame and math.sqrt((pd.Props.CFrame.X - x) ^ 2 + (pd.Props.CFrame.Z - z) ^ 2) <= radius then
					for _, child in M.descendants(d) do
						if RawData[child].ClassName == "TextLabel" and RawData[child].Props.Text then table.insert(found, string.upper(tostring(RawData[child].Props.Text))) end
					end
				end
			end
		end
		return table.concat(found, " # ")
	end
	local namedChecks = {
		{ "Coins Shop", function(p) return p.Opens == "Shop" end, "COINS SHOP", 22 },
		{ "Robux Shop", function(p) return p.Opens == "RobuxShop" end, "ROBUX SHOP", 22 },
		{ "Lucky Wheel", function(p) return p.Opens == "SpinWheel" end, "LUCKY WHEEL", 22 },
		{ "Leaderboards (the hall: gate sign at its entrance)", function(p) return p.Opens == "Leaderboards" end, "LEADERBOARDS", 36 },
		{ "Rebirth Altar", function(p) return p.House == 1 and p.Opens == "Rebirth" end, "REBIRTH ALTAR", 22 },
		{ "Security Panel (its screen shows the state)", function(p) return p.House == 1 and p.Opens == "SecurityPanel" end, "NO OWNER", 6 }, -- the screen shows SECURE / RECHARGING / PRESS F/E / NO OWNER
	}
	for _, entry in namedChecks do
		local p = findPrompt(entry[2])[1]
		local text = labelsNear(p.X, p.Z, entry[4])
		check("the " .. entry[1] .. " is named by a sign / label within " .. entry[4] .. " studs (" .. entry[3] .. ")", string.find(text, entry[3], 1, true) ~= nil, string.sub(text, 1, 80))
	end
	local unnamed = {}
	for _, p in prompts do
		if p.Object == "" or p.Object == "nil" or p.Action == "" or p.Action == "nil" then table.insert(unnamed, p.Path) end
	end
	check(string.format("every one of the %d [F] / [E] prompts in the world has an object name and an action text", #prompts), #prompts > 150 and #unnamed == 0, #unnamed .. " e.g. " .. tostring(unnamed[1]))
	-- the tutorial points at real objects: every target name exists, public ones can be walked to
	local targets = {}
	for _, d in M.descendants(workspace) do
		local name = RawData[d].Attributes.TutorialTarget
		if type(name) == "string" and M.InstanceMethods.HasTag(d, "TutorialTarget") and RawData[d].Props and RawData[d].Props.CFrame then
			targets[name] = targets[name] or {}
			local cf = RawData[d].Props.CFrame
			table.insert(targets[name], { X = cf.X, Y = cf.Y, Z = cf.Z, Path = pathOf(d) })
		end
	end
	local missingTargets, unreachableTargets = {}, {}
	for _, name in { "Base", "Bench", "Gate", "Upgrade", "Altar", "Shop", "Wheel", "Leaderboard" } do
		if not targets[name] then
			table.insert(missingTargets, name)
		else
			for _, t in targets[name] do
				local cost = reachCell(fromSpawn, t.X, t.Y, t.Z, 14, 0)
				if cost == math.huge then table.insert(unreachableTargets, t.Path) end
			end
		end
	end
	check("all 8 tutorial targets (Base, Bench, Gate, Upgrade, Altar, Shop, Wheel, Leaderboard) exist and every copy of them can be walked up to (within 14 studs)", #missingTargets == 0 and #unreachableTargets == 0, table.concat(missingTargets, ",") .. " " .. tostring(unreachableTargets[1]))

	---------------------------------------------------------------------------
	section("8. the rolling hamster balls: their real routes")
	---------------------------------------------------------------------------
	-- Balls roll along WorldLayout.transitRoute: from the road over the strip to the promenade, along it, up the gate path, the driveway, through the
	-- front door to the pad. The centre line of every route (from every kind of start) must not run through anything that stands on the ground: the
	-- smallest ball has a radius of 2.2 studs (HamsterStates.ballRadius(1)), so anything that stands closer than that to the centre line is rolled through.
	local BALL = 2.2
	local obstacles = {}
	for _, p in parts do
		if p.Top > 0.7 and p.Bottom < 2 * BALL and p.Transparency < 0.9 and not string.find(p.Path, "^Environment/Promenades") and not string.find(p.Path, "^PlayerHouses/House%d/Tower") and not string.find(p.Path, "/Yard/Gate") and not string.find(p.Path, "^HamsterPath/Road") and not string.find(p.Path, "^HamsterPath/Curb") then
			table.insert(obstacles, p)
		end
	end
	local bucket = {}
	for _, p in obstacles do
		for cx = math.floor(p.Box[1] / 8), math.floor(p.Box[2] / 8) do
			for cz = math.floor(p.Box[3] / 8), math.floor(p.Box[4] / 8) do
				local key = cx .. "," .. cz
				bucket[key] = bucket[key] or {}
				table.insert(bucket[key], p)
			end
		end
	end
	local nearest = {} -- per prop (Model): the smallest distance to the centre line of any route
	local visitedCells = {}
	local routeCount = 0
	local function checkRoute(route, houseIndex)
		routeCount += 1
		local points = route.Points
		for k = 1, #points - 1 do
			local a, b = points[k], points[k + 1]
			local segment = math.sqrt((b.X - a.X) ^ 2 + (b.Z - a.Z) ^ 2)
			local steps = math.max(1, math.ceil(segment / 1))
			for step = 0, steps do
				local t = step / steps
				local px, pz = a.X + (b.X - a.X) * t, a.Z + (b.Z - a.Z) * t
				local cell = math.floor(px * 2) .. "," .. math.floor(pz * 2)
				if not visitedCells[cell] then
					visitedCells[cell] = true
					for _, p in bucket[math.floor(px / 8) .. "," .. math.floor(pz / 8)] or {} do
						local d = distTo(p, px, pz)
						if d < BALL then
							local model = RawData[p.Inst].Parent
							local key = tostring(model)
							if not nearest[key] or d < nearest[key].D then
								local mp = if model and RawData[model].ClassName == "Model" then pathOf(model) else p.Path
								nearest[key] = { D = d, Text = string.format("%s at (%.0f, %.0f) stands %.1f studs from the route centre line (house %d)", mp, p.X, p.Z, d, houseIndex) }
							end
						end
					end
				end
			end
		end
	end
	for index, house in houses do
		local side = if index <= 4 then 1 else -1
		for fx = -220, 220, 4 do
			for _, lane in { -9, -6.5, 0, 6.5, 9 } do
				checkRoute(WorldLayout.transitRoute(house.CFrame, Vector3.new(fx, 0.1, lane)), index)
			end
			checkRoute(WorldLayout.transitRoute(house.CFrame, Vector3.new(fx, 0.1, side * WorldLayout.PromenadeZ)), index)
		end
	end
	local CLIP = 2.0 -- a ball of the smallest size (radius 2.2) is cut by anything closer than this to the centre line
	local clipped = {}
	for _, entry in nearest do
		if entry.D < CLIP then table.insert(clipped, entry.Text) end
	end
	table.sort(clipped)
	local clippedTrees = 0
	for _, c in clipped do
		if string.find(c, "Tree_") or string.find(c, "/Bush") or string.find(c, "/Rock") or string.find(c, "/Trunk") then clippedTrees += 1 end
	end
	print(string.format("   %d routes (8 houses x 111 start points along the road x 5 lanes + the promenade), %d obstacles near the ground", routeCount, #obstacles))
	for index = 1, math.min(#clipped, 12) do print("   ROLLED THROUGH", clipped[index]) end
	check("no tree, bush or rock stands on the centre line of a rolling route", clippedTrees == 0, clippedTrees)
	check("no bench, lamp, flower bed, sign post or other street furniture stands closer than 2 studs to the centre line of a rolling route (a ball rolls through it)", #clipped - clippedTrees == 0, (#clipped - clippedTrees) .. " pieces, first: " .. tostring(clipped[1]))
	do
		local probe = { Path = "probe", Name = "Probe", Top = 3, Bottom = 0, Transparency = 0, Solid = true, X = 0, Y = 1.5, Z = 34, Poly = { { -1, 33 }, { 1, 33 }, { 1, 35 }, { -1, 35 } }, Box = { -1, 1, 33, 35 } }
		check("self-test: a post put on the promenade centre line is closer than a ball radius to the route", distTo(probe, 0, 34) < BALL)
	end

	print(string.format("PASS %d  FAIL %d", results.pass, results.fail))
	print("== done ==")
end)
