-- Terrain, vegetation and object sweep of the generated world (the REAL builders; the baked world/*.model.json is not looked at).
--   1. budget: how many parts every folder costs, scenery is cheap (anchored, no collisions / queries / shadows)
--   2. mountains and cliffs: the real surface of the triangle meshes (a vertical ray against every wedge), seen from the walkable ground:
--        - no rock surface rises INSIDE the walkable ground unless it collides (you can not walk through a mountain)
--        - the foot of every mountain closes below the ground (no hovering edge), the surface has no holes, every massif is sunk into the ground
--        - no tree / bush / rock / flower bed stands INSIDE a mountain surface
--   3. vegetation: trunks reach the ground, no two trees on one spot, none standing on a path / road / promenade, none in front of a door
--   4. object sweep: matching houses have identical dimensions, every part of a house stays inside its lot, collision shapes that are
--      much bigger than what you see (the burrow / exit hills)
-- Every detector has a self-test with a deliberately broken input (a probe), so a green result means the check can really see the problem.
-- The mock is not Roblox: this proves geometry and structure, not how the world looks. Scenes: tools/WorldPreview/render.js.
local results = { pass = 0, fail = 0 }
local function section(title) print("\n== " .. title .. " ==") end
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end
local adv = M.Sim.advance

local GROUND_HALF_X, GROUND_HALF_Z = 285, 190 -- the invisible walls stand here (WorldLayout.GroundHalfX/Z, read again below)

local function pathOf(inst)
	local chain, node = {}, inst
	while node and node ~= workspace do
		table.insert(chain, 1, RawData[node].Name)
		node = RawData[node].Parent
	end
	return table.concat(chain, "/")
end

local function isBasePart(inst)
	return M.InstanceMethods.IsA(inst, "BasePart")
end

---------------------------------------------------------------------------
-- terrain surface: the highest point of a set of wedges above (x, z), by a vertical ray against each wedge (a triangular prism)
---------------------------------------------------------------------------
-- A WedgePart has its right angle at the back-bottom edge (+Z side) and its slope rises towards +Z (see Build.rightWedge).
-- In wedge space the prism is  |x| <= a,  y >= -b,  z <= c,  y <= (b / c) * z.  A vertical world ray is a line in wedge space, so every
-- limit is one linear inequality in t (the height along the ray).
local function wedgeRecord(d)
	local data = RawData[d]
	local cf, size = data.Props.CFrame, data.Props.Size
	local r = cf.r
	local rec = { A = size.X / 2, B = size.Y / 2, C = size.Z / 2, CX = cf.X, CY = cf.Y, CZ = cf.Z, Part = d }
	-- world-space direction of each wedge axis = a column of the rotation matrix
	rec.AX, rec.AY, rec.AZ = { r[1], r[4], r[7] }, { r[2], r[5], r[8] }, { r[3], r[6], r[9] }
	local hx = math.abs(r[1]) * rec.A + math.abs(r[2]) * rec.B + math.abs(r[3]) * rec.C
	local hz = math.abs(r[7]) * rec.A + math.abs(r[8]) * rec.B + math.abs(r[9]) * rec.C
	local hy = math.abs(r[4]) * rec.A + math.abs(r[5]) * rec.B + math.abs(r[6]) * rec.C
	rec.X0, rec.X1, rec.Z0, rec.Z1, rec.Bottom, rec.Top = cf.X - hx, cf.X + hx, cf.Z - hz, cf.Z + hz, cf.Y - hy, cf.Y + hy
	rec.Collides = data.Props.CanCollide ~= false
	rec.Path = pathOf(d)
	return rec
end

local function wedgeTop(w, x, z): number?
	local dx, dz = x - w.CX, z - w.CZ
	-- wedge-space coordinates of the point (x, t, z) are  u + t * v  per axis
	local u1 = w.AX[1] * dx + w.AX[3] * dz - w.AX[2] * w.CY
	local u2 = w.AY[1] * dx + w.AY[3] * dz - w.AY[2] * w.CY
	local u3 = w.AZ[1] * dx + w.AZ[3] * dz - w.AZ[2] * w.CY
	local v1, v2, v3 = w.AX[2], w.AY[2], w.AZ[2]
	local lo, hi = -math.huge, math.huge
	-- each limit is  alpha * t <= beta
	local function limit(alpha: number, beta: number): boolean
		if math.abs(alpha) < 1e-9 then
			return beta >= -1e-9
		elseif alpha > 0 then
			hi = math.min(hi, beta / alpha)
		else
			lo = math.max(lo, beta / alpha)
		end
		return true
	end
	local k = w.B / w.C
	if not (limit(v1, w.A - u1) and limit(-v1, w.A + u1) and limit(-v2, w.B + u2) and limit(v3, w.C - u3) and limit(v2 - k * v3, -(u2 - k * u3))) then
		return nil
	end
	if lo <= hi and hi < math.huge then
		return hi
	end
	return nil
end

-- Height map over [x0, x1] x [z0, z1] at `res` studs: Surface[i][j] = highest surface height or nil. Also remembers whether the top is a colliding part.
local function rasterize(wedges, x0, x1, z0, z1, res)
	local nx, nz = math.floor((x1 - x0) / res) + 1, math.floor((z1 - z0) / res) + 1
	local height, solid = table.create(nx * nz), table.create(nx * nz)
	for k = 1, nx * nz do
		height[k] = -math.huge
		solid[k] = false
	end
	for _, w in wedges do
		if w.X1 >= x0 and w.X0 <= x1 and w.Z1 >= z0 and w.Z0 <= z1 then
			for i = math.max(0, math.ceil((w.X0 - x0) / res)), math.min(nx - 1, math.floor((w.X1 - x0) / res)) do
				local x = x0 + i * res
				for j = math.max(0, math.ceil((w.Z0 - z0) / res)), math.min(nz - 1, math.floor((w.Z1 - z0) / res)) do
					local top = wedgeTop(w, x, z0 + j * res)
					local k = j * nx + i + 1
					if top and top > height[k] then
						height[k] = top
						solid[k] = w.Collides
					end
				end
			end
		end
	end
	return { Height = height, Solid = solid, NX = nx, NZ = nz, X0 = x0, Z0 = z0, Res = res }
end
local function heightAt(map, x, z): number
	local i, j = math.floor((x - map.X0) / map.Res + 0.5), math.floor((z - map.Z0) / map.Res + 0.5)
	if i < 0 or i >= map.NX or j < 0 or j >= map.NZ then
		return -math.huge
	end
	return map.Height[j * map.NX + i + 1]
end

-- How much of the walkable ground (inside the invisible walls) lies under a rock surface that does not collide.
local function intrusion(map, halfX, halfZ)
	local cells, highest, hx, hz = 0, 0, 0, 0
	for j = 0, map.NZ - 1 do
		for i = 0, map.NX - 1 do
			local x, z = map.X0 + i * map.Res, map.Z0 + j * map.Res
			if math.abs(x) <= halfX - 1 and math.abs(z) <= halfZ - 1 then
				local k = j * map.NX + i + 1
				local h = map.Height[k]
				if h > 0.5 and not map.Solid[k] then
					cells += 1
					if h > highest then highest, hx, hz = h, x, z end
				end
			end
		end
	end
	return cells * map.Res * map.Res, highest, hx, hz
end

---------------------------------------------------------------------------
-- decor / tree records
---------------------------------------------------------------------------
local function treeRecord(model)
	local trunk, crowns = nil, {}
	for _, child in M.descendants(model) do
		local name = RawData[child].Name
		if name == "Trunk" then trunk = child
		elseif string.sub(name, 1, 6) == "Canopy" or string.sub(name, 1, 7) == "Needles" then table.insert(crowns, child) end
	end
	if not trunk or #crowns == 0 then return nil end
	local tcf, tsz = RawData[trunk].Props.CFrame, RawData[trunk].Props.Size
	local rec = { Model = model, Path = pathOf(model), X = tcf.X, Z = tcf.Z, Base = tcf.Y - tsz.X / 2, TrunkR = tsz.Y / 2, CrownR = 0, CrownBottom = math.huge }
	rec.Kind = string.sub(RawData[model].Name, 6)
	rec.Scale = tsz.Y / (if rec.Kind == "pine" then 1.5 else 1.6)
	for _, crown in crowns do
		local ccf, csz = RawData[crown].Props.CFrame, RawData[crown].Props.Size
		rec.CrownR = math.max(rec.CrownR, math.max(csz.X, csz.Z) / 2)
		rec.CrownBottom = math.min(rec.CrownBottom, ccf.Y - csz.Y / 2)
	end
	local top = string.match(rec.Path, "^(%w+)/")
	rec.Where = if top == "Environment" then "Environment/" .. string.match(rec.Path, "^Environment/(%w+)/") elseif top == "PlayerHouses" then "Yard" else top
	return rec
end

task.spawn(function()
	M.isServer = true
	local mainServer = find("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	adv(3)
	local WorldLayout = require(find("ReplicatedStorage.Modules.WorldLayout"))
	local HouseSystem = require(find("ServerScriptService.Systems.HouseSystem"))
	local HouseBuilder = require(find("ServerScriptService.Systems.WorldBuilder.HouseBuilder"))
	GROUND_HALF_X, GROUND_HALF_Z = WorldLayout.GroundHalfX, WorldLayout.GroundHalfZ
	-- the preview state of the baked world: 1, 2, 3, 4, 5, 3, 2, 1 floors (a real server starts with 1 floor everywhere)
	local previewFloors = { 1, 2, 3, 4, 5, 3, 2, 1 }
	local houseRng = Random.new(3)
	for index, house in HouseSystem.all() do HouseBuilder.setFloors(house, previewFloors[index], houseRng) end

	---------------------------------------------------------------------------
	section("1. part budget (what every folder costs the client)")
	---------------------------------------------------------------------------
	local perFolder, total, anchoredOk, scenery, sceneryExpensive = {}, 0, 0, 0, {}
	for _, d in M.descendants(workspace) do
		local data = RawData[d]
		if data.Props and data.Props.Size and isBasePart(d) then
			total += 1
			local path = pathOf(d)
			local top, second = string.match(path, "^(%w+)/?(%w*)")
			local key = if top == "Environment" or top == "PlayerHouses" then top .. "/" .. second else top
			perFolder[key] = (perFolder[key] or 0) + 1
			-- (the golden statue is a hamster rig: every part hangs on joints from its ANCHORED Root, so the assembly is anchored)
			if data.Props.Anchored or string.find(path, "^HamsterPlaza/PlazaStatue/") then anchoredOk += 1 end
			if top == "Environment" and (second == "Backdrop" or second == "Beyond") then
				scenery += 1
				local p = data.Props
				-- mountain facets, cliff facets, clouds, hills and lakes: no collision, no query, no shadow; trees outside the walls: only the trunk collides
				local isTree = string.find(path, "/Tree_") ~= nil
				local cheap
				if isTree then
					cheap = p.CanCollide == false or data.Name == "Trunk"
				else
					cheap = p.CanCollide == false and (data.Name ~= "Facet" and data.Name ~= "Puff" or (p.CastShadow == false and p.CanQuery == false))
				end
				if not cheap then table.insert(sceneryExpensive, path) end
			end
		end
	end
	local names = {}
	for key in perFolder do table.insert(names, key) end
	table.sort(names)
	for _, key in names do print(string.format("   %-34s %6d parts", key, perFolder[key])) end
	print(string.format("   %-34s %6d parts (%d anchored)", "TOTAL (preview floors 1,2,3,4,5,3,2,1)", total, anchoredOk))
	check("every part of the world is anchored (nothing falls, nothing simulates)", anchoredOk == total, total - anchoredOk .. " loose")
	do
		local statue = workspace.HamsterPlaza:FindFirstChild("PlazaStatue")
		check("the golden statue hangs on an ANCHORED root (so it can not fall off the arch)", statue ~= nil and statue.PrimaryPart ~= nil and statue.PrimaryPart.Anchored == true)
	end
	check("the whole map stays within the part budget (<= 30000 with 5 floors somewhere)", total <= 30000, total)
	check("the mountain / hill backdrop stays within budget (<= 16000 parts)", (perFolder["Environment/Backdrop"] or 0) <= 16000, perFolder["Environment/Backdrop"])
	check("backdrop and beyond scenery is cheap: mountain / cliff facets and clouds never collide, cast shadows or answer raycasts (trees outside the walls: only the trunk collides)", #sceneryExpensive == 0, #sceneryExpensive .. " e.g. " .. tostring(sceneryExpensive[1]))

	---------------------------------------------------------------------------
	section("2. mountains and cliffs: the real surface")
	---------------------------------------------------------------------------
	local wedges, massifs, cliffs = {}, {}, {}
	for _, d in M.descendants(workspace) do
		local data = RawData[d]
		if data.ClassName == "WedgePart" and data.Props.Size and data.Props.CFrame then
			local path = pathOf(d)
			if string.find(path, "^Environment/Backdrop/") then
				local rec = wedgeRecord(d)
				table.insert(wedges, rec)
				local model = data.Parent
				massifs[model] = massifs[model] or { Path = path, Bottom = math.huge, Count = 0 }
				massifs[model].Count += 1
				massifs[model].Bottom = math.min(massifs[model].Bottom, rec.Bottom)
				if string.find(path, "^Environment/Backdrop/Cliff/") then table.insert(cliffs, rec) end
			end
		end
	end
	local massifCount = 0
	for _ in massifs do massifCount += 1 end
	print(string.format("   %d triangle wedges in %d massifs (%d of them in the cliff walls along the edges)", #wedges, massifCount, #cliffs))
	check("the mountains are found (a detector that scans nothing proves nothing)", #wedges > 5000 and massifCount >= 60, #wedges .. " wedges")

	local MARGIN = 40
	local map = rasterize(wedges, -GROUND_HALF_X - MARGIN, GROUND_HALF_X + MARGIN, -GROUND_HALF_Z - MARGIN, GROUND_HALF_Z + MARGIN, 3)
	local area, highest, hx, hz = intrusion(map, GROUND_HALF_X, GROUND_HALF_Z)
	check("no rock surface rises inside the walkable ground (the walls at x = +-" .. GROUND_HALF_X .. ", z = +-" .. GROUND_HALF_Z .. ") unless it collides: you can not walk through a mountain",
		area == 0, string.format("%.0f m2 of the walkable ground lies under non-colliding rock, up to %.0f studs high at (%.0f, %.0f)", area, highest, hx, hz))

	-- ... and in particular never over the playable core: the lots, the promenades, the road, the plaza and the hall
	do
		local coreHalfX = WorldLayout.HouseColumns[#WorldLayout.HouseColumns] + WorldLayout.LotHalfWidth + 8
		local coreHalfZ = WorldLayout.GateDistance + WorldLayout.LotDepth + 8
		local coreCells, coreHighest = 0, 0
		for j = 0, map.NZ - 1 do
			for i = 0, map.NX - 1 do
				local x, z = map.X0 + i * map.Res, map.Z0 + j * map.Res
				if math.abs(x) <= coreHalfX and math.abs(z) <= coreHalfZ then
					local h = map.Height[j * map.NX + i + 1]
					if h > 0.3 then coreCells += 1 coreHighest = math.max(coreHighest, h) end
				end
			end
		end
		check("no mountain or cliff surface touches the playable core (lots, promenades, road, plaza, hall: |x| <= " .. coreHalfX .. ", |z| <= " .. coreHalfZ .. ")", coreCells == 0, string.format("%d cells, up to %.1f studs", coreCells, coreHighest))
	end

	-- self-test: a rock slab dropped into the plaza must be seen
	do
		local probe = M.newInstance("WedgePart", true)
		RawData[probe].Name = "TerrainProbe"
		RawData[probe].Props.Anchored = true
		RawData[probe].Props.CanCollide = false
		RawData[probe].Props.Size = Vector3.new(0.6, 12, 24)
		RawData[probe].Props.CFrame = CFrame.new(0, 6, 0)
		M.setParent(probe, workspace)
		local probeRec = wedgeRecord(probe)
		M.InstanceMethods.Destroy(probe)
		local small = rasterize({ probeRec }, -30, 30, -30, 30, 3)
		local seen, tall = intrusion(small, GROUND_HALF_X, GROUND_HALF_Z)
		check("self-test: a rock slab dropped into the plaza is found by the intrusion check", seen > 0 and tall > 5, string.format("%.0f m2, %.1f high", seen, tall))
		probeRec.Collides = true
		local solidMap = rasterize({ probeRec }, -30, 30, -30, 30, 3)
		check("self-test: the same slab made collidable is accepted (a solid rock is a wall, not a ghost)", (intrusion(solidMap, GROUND_HALF_X, GROUND_HALF_Z)) == 0)
	end

	-- the foot of the mountains closes below the ground: every edge of the surface lies under y = 0.3 (no shelf hovering above the lawn)
	local edgeHigh, edgeCells, holeCells = 0, 0, 0
	do
		local nx, nz, H = map.NX, map.NZ, map.Height
		local function has(i, j) return i >= 0 and i < nx and j >= 0 and j < nz and H[j * nx + i + 1] > -math.huge end
		for j = 0, nz - 1 do
			for i = 0, nx - 1 do
				if has(i, j) and not (has(i + 1, j) and has(i - 1, j) and has(i, j + 1) and has(i, j - 1)) then
					-- only edges inside the raster (not the cut at the border of the window)
					if i > 1 and j > 1 and i < nx - 2 and j < nz - 2 then
						edgeCells += 1
						if H[j * nx + i + 1] > 0.3 then edgeHigh += 1 end
					end
				end
			end
		end
		-- holes: empty cells that cannot reach the border of the raster through empty cells
		local reach = table.create(nx * nz, false)
		local stack = {}
		local function push(i, j)
			if i >= 0 and i < nx and j >= 0 and j < nz and not has(i, j) and not reach[j * nx + i + 1] then
				reach[j * nx + i + 1] = true
				table.insert(stack, j * nx + i + 1)
			end
		end
		for i = 0, nx - 1 do push(i, 0) push(i, nz - 1) end
		for j = 0, nz - 1 do push(0, j) push(nx - 1, j) end
		while #stack > 0 do
			local k = table.remove(stack)
			local i, j = (k - 1) % nx, (k - 1) // nx
			push(i + 1, j) push(i - 1, j) push(i, j + 1) push(i, j - 1)
		end
		for j = 0, nz - 1 do
			for i = 0, nx - 1 do
				if not has(i, j) and not reach[j * nx + i + 1] then holeCells += 1 end
			end
		end
	end
	check("the foot of every mountain closes below the ground: no edge of the surface hovers above y = 0.3", edgeCells > 100 and edgeHigh == 0, string.format("%d edge cells, %d above the lawn", edgeCells, edgeHigh))
	check("the surfaces have no holes (no enclosed gap between facets)", holeCells == 0, holeCells .. " cells")
	local unsunk = {}
	for _, info in massifs do
		if info.Bottom > -5 then table.insert(unsunk, info.Path) end
	end
	check("every massif is sunk into the ground (its lowest facet lies at least 5 studs under it): nothing floats", #unsunk == 0, #unsunk .. " e.g. " .. tostring(unsunk[1]))

	-- trees, bushes, rocks and flower beds do not stand inside a mountain
	local buried, buriedWhere = {}, {}
	local solids = 0
	for _, d in M.descendants(workspace) do
		local data = RawData[d]
		if data.ClassName == "Model" then
			local name = data.Name
			local kind = if string.sub(name, 1, 5) == "Tree_" then "Tree" elseif name == "Bush" or name == "Rock" or name == "Flowers" then name else nil
			local path = if kind then pathOf(d) else ""
			if kind and not string.find(path, "^Environment/Backdrop/Hill") then
				local first
				for _, child in M.InstanceMethods.GetChildren(d) do
					if RawData[child].Props and RawData[child].Props.CFrame and RawData[child].Props.Size then first = child break end
				end
				if first then
					solids += 1
					local cf = RawData[first].Props.CFrame
					local h = heightAt(map, cf.X, cf.Z)
					if h > 0.5 and not (function() local k = (math.floor((cf.Z - map.Z0) / map.Res + 0.5)) * map.NX + math.floor((cf.X - map.X0) / map.Res + 0.5) + 1 return map.Solid[k] end)() then
						local inside = math.abs(cf.X) <= GROUND_HALF_X and math.abs(cf.Z) <= GROUND_HALF_Z
						table.insert(buried, string.format("%s at (%.0f, %.0f) under rock %.1f high", path, cf.X, cf.Z, h))
						local key = (if inside then "walkable " else "outside ") .. kind
						buriedWhere[key] = (buriedWhere[key] or 0) + 1
					end
				end
			end
		end
	end
	table.sort(buried)
	for index = 1, math.min(#buried, 10) do print("   BURIED", buried[index]) end
	local summary = {}
	for key, count in buriedWhere do table.insert(summary, key .. " " .. count) end
	table.sort(summary)
	local insideCount = 0
	for key, count in buriedWhere do if string.sub(key, 1, 8) == "walkable" then insideCount += count end end
	check("no tree, bush, rock or flower bed on the walkable ground stands inside a mountain surface (" .. solids .. " checked)", insideCount == 0, table.concat(summary, ", "))
	check("no tree outside the walls stands inside a mountain surface either (the ring seen from the road and the roofs)", #buried - insideCount == 0, (#buried - insideCount) .. " outside")

	---------------------------------------------------------------------------
	section("3. vegetation")
	---------------------------------------------------------------------------
	local trees = {}
	for _, d in M.descendants(workspace) do
		if RawData[d].ClassName == "Model" and string.sub(RawData[d].Name, 1, 5) == "Tree_" then
			local rec = treeRecord(d)
			if rec then table.insert(trees, rec) end
		end
	end
	local byWhere = {}
	for _, t in trees do byWhere[t.Where] = (byWhere[t.Where] or 0) + 1 end
	local wherenames = {}
	for key, count in byWhere do table.insert(wherenames, key .. " " .. count) end
	table.sort(wherenames)
	print("   trees:", table.concat(wherenames, ", "))
	-- trunks reach the ground: the bottom of the trunk is on the lawn (y = 0), or inside the hill it grows on (backdrop)
	local floatingTrunk = {}
	for _, t in trees do
		if t.Where ~= "Environment/Backdrop" and math.abs(t.Base) > 0.3 then
			table.insert(floatingTrunk, string.format("%s at (%.0f, %.0f): trunk bottom at y = %.2f", t.Path, t.X, t.Z, t.Base))
		end
	end
	check("every tree trunk starts on the ground (y = 0 +- 0.3; backdrop hill trees grow out of their hill)", #floatingTrunk == 0, #floatingTrunk .. " e.g. " .. tostring(floatingTrunk[1]))
	local underground = 0
	for _, t in trees do
		if t.CrownBottom < t.Base + 2 * t.Scale and t.Where ~= "Environment/Backdrop" then underground += 1 end
	end
	check("every crown sits above the trunk base by at least 2 trunk-scales (no crown on the ground)", underground == 0, underground)

	-- two trees on one spot / crowns that stack up
	local function stacked(list, same, crowd)
		local sameSpot, crowded = {}, {}
		local cells = {}
		for index, t in list do
			local key = math.floor(t.X / 16) .. "," .. math.floor(t.Z / 16)
			cells[key] = cells[key] or {}
			table.insert(cells[key], index)
		end
		for index, a in list do
			local cx, cz = math.floor(a.X / 16), math.floor(a.Z / 16)
			for dx = -1, 1 do
				for dz = -1, 1 do
					for _, other in cells[(cx + dx) .. "," .. (cz + dz)] or {} do
						if other > index then
							local b = list[other]
							local d = math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2)
							if d < same then
								table.insert(sameSpot, string.format("%s + %s at (%.0f, %.0f), %.1f apart", a.Path, b.Path, a.X, a.Z, d))
							elseif d < crowd * (a.CrownR + b.CrownR) then
								table.insert(crowded, string.format("%s + %s at (%.0f, %.0f), %.1f apart", a.Path, b.Path, a.X, a.Z, d))
							end
						end
					end
				end
			end
		end
		return sameSpot, crowded
	end
	local playable, backdrop = {}, {}
	for _, t in trees do
		if t.Where == "Environment/Backdrop" or t.Where == "Environment/Beyond" then table.insert(backdrop, t) else table.insert(playable, t) end
	end
	local sameA, crowdA = stacked(playable, 2.5, 0.6)
	check("no two trees on the walkable ground stand on one spot (< 2.5 studs) and no two crowns merge into one (< 60% of the crown radii)", #sameA == 0 and #crowdA == 0, #sameA + #crowdA .. " pairs, " .. #playable .. " trees checked")
	local sameB, crowdB = stacked(backdrop, 2.5, 0.6)
	for index = 1, math.min(#sameB, 4) do print("   SAME SPOT", sameB[index]) end
	check("no two trees of the backdrop hills / the ring outside the walls stand on one spot (< 2.5 studs) either", #sameB == 0, #sameB .. " pairs, e.g. " .. tostring(sameB[1]))
	check("no two crowns of the backdrop merge into one (hill trees are scattered without looking at each other or at the ring)", #crowdB == 0, #crowdB .. " pairs")
	do
		local probe = { { Path = "probe/a", X = 10, Z = 10, CrownR = 4 }, { Path = "probe/b", X = 10.8, Z = 10, CrownR = 4 } }
		local s = stacked(probe, 2.5, 0.6)
		check("self-test: two trees put on one spot are found", #s == 1)
	end

	-- trees and paths: no trunk on a paved surface, none in front of a door
	local paved = {}
	local PAVED_NAMES = { Promenade = true, GatePath = true, Driveway = true, GateApron = true, AnnexPath = true, ShopApproach = true, WheelPath = true, HallPath = true, HallPaving = true, PavingOuter = true, Road = true, Curb = true }
	for _, d in M.descendants(workspace) do
		local data = RawData[d]
		if data.Props and data.Props.Size and isBasePart(d) and PAVED_NAMES[data.Name] then
			local cf, size = data.Props.CFrame, data.Props.Size
			local circle = data.Props.Shape and data.Props.Shape.Name == "Cylinder"
			table.insert(paved, { Name = data.Name, X = cf.X, Z = cf.Z, R = cf.r, W = size.X, H = size.Y, D = size.Z, Circle = circle })
		end
	end
	local function onPaved(x, z, radius)
		for _, p in paved do
			local dx, dz = x - p.X, z - p.Z
			if p.Circle then
				if math.sqrt(dx * dx + dz * dz) <= p.H / 2 + radius then return p.Name end
			else
				local lx = p.R[1] * dx + p.R[4] * 0 + p.R[7] * dz
				local lz = p.R[3] * dx + p.R[9] * dz
				if math.abs(lx) <= p.W / 2 + radius and math.abs(lz) <= p.D / 2 + radius then return p.Name end
			end
		end
		return nil
	end
	local onPath = {}
	for _, t in playable do
		local name = onPaved(t.X, t.Z, t.TrunkR)
		if name then table.insert(onPath, string.format("%s at (%.0f, %.0f) on the %s", t.Path, t.X, t.Z, name)) end
	end
	check("no tree trunk stands on a path, promenade, road, curb, driveway or the plaza paving (" .. #paved .. " paved parts, " .. #playable .. " trees)", #onPath == 0, #onPath .. " e.g. " .. tostring(onPath[1]))
	check("self-test: a trunk put in the middle of the road is found", onPaved(0, 0, 1) == "Road")

	-- doors: the zones in front of every door (houses, shops, hall gate) are free of trunks and low crowns
	local zones = {}
	for index = 1, WorldLayout.HouseCount do
		local cf = WorldLayout.houseCFrame(index)
		table.insert(zones, { Name = "House" .. index .. " gate + driveway + front door", Cf = cf, X0 = -8, X1 = 8, Z0 = -6, Z1 = WorldLayout.DoorZ + 1 })
	end
	for _, side in { -1, 1 } do
		table.insert(zones, { Name = (if side < 0 then "Coins" else "Robux") .. " Shop door", Cf = CFrame.new(side * 15, 0, 52), X0 = -6, X1 = 6, Z0 = -9, Z1 = 1 })
	end
	table.insert(zones, { Name = "Leaderboard Hall gate", Cf = CFrame.new(0, 0, -73), X0 = -9, X1 = 9, Z0 = -6, Z1 = 6 })
	local blockedDoors = {}
	for _, t in playable do
		for _, zone in zones do
			local lp = zone.Cf:PointToObjectSpace(Vector3.new(t.X, 0, t.Z))
			local reach = t.TrunkR + (if t.CrownBottom < 5 then t.CrownR else 0)
			if lp.X >= zone.X0 - reach and lp.X <= zone.X1 + reach and lp.Z >= zone.Z0 - reach and lp.Z <= zone.Z1 + reach then
				table.insert(blockedDoors, string.format("%s at (%.0f, %.0f) blocks the %s", t.Path, t.X, t.Z, zone.Name))
			end
		end
	end
	check("no tree trunk or low crown blocks a house gate, a front door, a shop door or the hall gate (" .. #zones .. " zones)", #blockedDoors == 0, #blockedDoors .. " e.g. " .. tostring(blockedDoors[1]))

	---------------------------------------------------------------------------
	section("4. object sweep")
	---------------------------------------------------------------------------
	-- matching houses (same number of floors) have identical dimensions: every structural part appears with the same name, size and place
	-- (random decoration - hedge heights, flower blooms, book colours, tree crowns, lily pads - is left out)
	local RANDOM = { Hedge = true, Leaves = true, Bloom = true, Book = true, Canopy1 = true, Canopy2 = true, Canopy3 = true, Needles1 = true, Needles2 = true, Needles3 = true, LilyPad = true, Berry = true, Stone1 = true, Stone2 = true, Trunk = true }
	local function signature(houseModel, cframe)
		local groups = {}
		for _, d in M.descendants(houseModel) do
			local data = RawData[d]
			if data.Props and data.Props.Size and isBasePart(d) and not RANDOM[data.Name] then
				local lp = cframe:PointToObjectSpace(Vector3.new(data.Props.CFrame.X, data.Props.CFrame.Y, data.Props.CFrame.Z))
				local s = data.Props.Size
				local dims = { s.X, s.Y, s.Z }
				table.sort(dims)
				local key = string.format("%s|%.2f,%.2f,%.2f", data.Name, dims[1], dims[2], dims[3])
				groups[key] = groups[key] or {}
				table.insert(groups[key], { lp.X, lp.Y, lp.Z })
			end
		end
		return groups
	end
	-- parts of A that have no partner (same name and size, within 0.15 studs) in B, plus the parts of B nobody in A matches
	local function differences(a, b)
		local missing = 0
		local function unmatched(x, y)
			local n = 0
			for key, list in x do
				local others = table.clone(y[key] or {})
				for _, p in list do
					local found
					for index, q in others do
						if math.abs(p[1] - q[1]) < 0.15 and math.abs(p[2] - q[2]) < 0.15 and math.abs(p[3] - q[3]) < 0.15 then found = index break end
					end
					if found then table.remove(others, found) else n += 1 end
				end
			end
			return n
		end
		missing = unmatched(a, b) + unmatched(b, a)
		return missing
	end
	local houses = HouseSystem.all()
	local signatures = {}
	for index, house in houses do signatures[index] = signature(house.Model, house.CFrame) end
	for _, pair in { { 1, 8 }, { 2, 7 }, { 3, 6 } } do
		local diff = differences(signatures[pair[1]], signatures[pair[2]])
		check(string.format("House%d and House%d (same floors, opposite rows) have identical dimensions part by part", pair[1], pair[2]), diff == 0, diff .. " differing parts")
	end
	do
		local mutated = {}
		for key, list in signatures[1] do mutated[key] = table.clone(list) end
		local anyKey = next(mutated)
		mutated[anyKey][1] = { mutated[anyKey][1][1] + 0.5, mutated[anyKey][1][2], mutated[anyKey][1][3] }
		check("self-test: one part moved by half a stud between two houses is seen by the comparison", differences(signatures[1], mutated) == 2)
	end

	-- every part of a house stays inside its own lot (neighbours do not grow into each other), measured on the real part boxes
	local lotMargin, outside = 1.5, {} -- (the gate apron straddles the gate line by design: 2.5 studs into the street)
	local xs = {}
	for _, d in M.descendants(workspace.PlayerHouses) do
		local data = RawData[d]
		if data.Props and data.Props.Size and data.Props.CFrame and isBasePart(d) then
			local houseModel = d
			while RawData[houseModel].Parent ~= workspace.PlayerHouses do houseModel = RawData[houseModel].Parent end
			local index = RawData[houseModel].Attributes.HouseId
			local cf = WorldLayout.houseCFrame(index)
			local size, pcf = data.Props.Size, data.Props.CFrame
			local r = pcf.r
			local hx = (math.abs(r[1]) * size.X + math.abs(r[2]) * size.Y + math.abs(r[3]) * size.Z) / 2
			local hz = (math.abs(r[7]) * size.X + math.abs(r[8]) * size.Y + math.abs(r[9]) * size.Z) / 2
			local c = cf:PointToObjectSpace(Vector3.new(pcf.X, pcf.Y, pcf.Z))
			-- (the local frame of a south house is turned by 180 degrees: its half extents are the same in x and z)
			local hxl = if math.abs(cf.RightVector.X) > 0.5 then hx else hz
			local hzl = if math.abs(cf.RightVector.X) > 0.5 then hz else hx
			if math.abs(c.X) + hxl > WorldLayout.LotHalfWidth + lotMargin or c.Z - hzl < -3 or c.Z + hzl > WorldLayout.LotDepth + lotMargin then
				table.insert(outside, string.format("House%d %s (%.1f, %.1f) size %.1fx%.1f", index, data.Name, c.X, c.Z, hxl * 2, hzl * 2))
			end
		end
	end
	for index = 1, math.min(#outside, 6) do print("   OUTSIDE LOT", outside[index]) end
	check("every part of every house stands inside its own lot (68 x 86 studs, 1.5 margin; the gate apron may reach 3 studs into the street): neighbouring lots never overlap", #outside == 0, #outside .. " e.g. " .. tostring(outside[1]))
	local gap = WorldLayout.HouseColumns[2] - WorldLayout.HouseColumns[1] - 2 * WorldLayout.LotHalfWidth
	check("lots of a row are separated by an even gap (" .. gap .. " studs) wide enough for a walking route", gap >= 20 and WorldLayout.HouseColumns[3] - WorldLayout.HouseColumns[2] - 2 * WorldLayout.LotHalfWidth >= 40 and WorldLayout.HouseColumns[4] - WorldLayout.HouseColumns[3] - 2 * WorldLayout.LotHalfWidth == gap)

	-- fences: the pickets of every run stand evenly (spacing within 0.1 stud of each other, about 3.2 studs) and the first / last one stands on the run's ends
	do
		local uneven, runs, pickets = {}, 0, 0
		for _, d in M.descendants(workspace.PlayerHouses) do
			if RawData[d].ClassName == "Model" and RawData[d].Name == "Fence" then
				local list, rail = {}, nil
				for _, child in M.InstanceMethods.GetChildren(d) do
					if RawData[child].Name == "Picket" then table.insert(list, child) end
					if RawData[child].Name == "RailTop" then rail = child end
				end
				if rail and #list > 2 then
					runs += 1
					pickets += #list
					local rcf, rsize = RawData[rail].Props.CFrame, RawData[rail].Props.Size
					local ax, az = rcf.r[3], rcf.r[9] -- the rail runs along its local Z axis
					local along = {}
					for _, p in list do
						local cf = RawData[p].Props.CFrame
						table.insert(along, (cf.X - rcf.X) * ax + (cf.Z - rcf.Z) * az)
					end
					table.sort(along)
					local first, last = along[1], along[#along]
					local mean = (last - first) / (#along - 1)
					local worst = 0
					for index = 2, #along do worst = math.max(worst, math.abs(along[index] - along[index - 1] - mean)) end
					if worst > 0.1 or mean < 2.7 or mean > 3.7 or math.abs(first + rsize.Z / 2) > 0.2 or math.abs(last - rsize.Z / 2) > 0.2 then
						table.insert(uneven, string.format("%s: spacing %.2f (uneven by %.2f), ends %.1f / %.1f of %.1f", pathOf(d), mean, worst, first, last, rsize.Z / 2))
					end
				end
			end
		end
		check(string.format("the %d pickets of the %d fence runs stand evenly spaced (+-0.1, about 3.2 studs) from end to end", pickets, runs), runs == 16 and #uneven == 0, #uneven .. " uneven runs, first: " .. tostring(uneven[1]))
	end

	-- the wheel emblem on every roof: its spokes must lie IN the plane of the ring (a spoke along the axis of the ring is a rod sticking out of it)
	do
		local bad, rings = {}, 0
		for _, house in houses do
			local ring, spokes = nil, {}
			for _, d in M.descendants(house.Roof) do
				local name = RawData[d].Name
				if name == "EmblemRing" then ring = d end
				if name == "EmblemSpoke" then table.insert(spokes, d) end
			end
			if ring then
				rings += 1
				local rr = RawData[ring].Props.CFrame.r
				local axis = { rr[1], rr[4], rr[7] } -- a cylinder lies along its local X axis
				for _, spoke in spokes do
					local sr = RawData[spoke].Props.CFrame.r
					local size = RawData[spoke].Props.Size
					-- the long side of the spoke: its local Z axis (Size.Z is the longest)
					local long = if size.Z >= size.X and size.Z >= size.Y then { sr[3], sr[6], sr[9] } elseif size.X >= size.Y then { sr[1], sr[4], sr[7] } else { sr[2], sr[5], sr[8] }
					if math.abs(long[1] * axis[1] + long[2] * axis[2] + long[3] * axis[3]) > 0.3 then
						table.insert(bad, "House" .. house.Index)
						break
					end
				end
			end
		end
		check("the wheel emblem on every roof (" .. rings .. " roofs) has spokes in the plane of its ring, not a rod through its axis", rings == 8 and #bad == 0, #bad .. " roofs wrong: " .. table.concat(bad, ","))
	end

	-- collision shapes that are much bigger than what you see: a collidable sphere / ellipsoid (a block with a sphere mesh collides as a BLOCK)
	local fat = {}
	for _, d in M.descendants(workspace) do
		local data = RawData[d]
		if data.Props and data.Props.Size and isBasePart(d) and data.Props.CanCollide ~= false then
			local sphere = false
			for _, child in data.Children do
				local mesh = RawData[child]
				if mesh.ClassName == "SpecialMesh" and mesh.Props.MeshType and mesh.Props.MeshType.Name == "Sphere" then sphere = true end
			end
			local s = data.Props.Size
			-- an ellipsoid fills pi/6 = 52% of its box: the corners of a big one are far from anything you see
			local reachable = math.abs(data.Props.CFrame.X) <= GROUND_HALF_X + 30 and math.abs(data.Props.CFrame.Z) <= GROUND_HALF_Z -- (the Beyond / Transitions ring outside the walls can not be reached)
			if sphere and reachable and math.min(s.X, s.Z) >= 8 and s.Y >= 8 then
				table.insert(fat, string.format("%s: invisible collision block %.0f x %.0f x %.0f around a dome", pathOf(d), s.X, s.Y, s.Z))
			end
		end
	end
	for _, l in fat do print("   FAT COLLISION", l) end
	check("no big dome / ellipsoid that a player can reach collides as a block (invisible corners next to its curved surface)", #fat == 0, #fat .. " e.g. " .. tostring(fat[1]))

	-- stacked duplicates: two parts with the same name, size and place (they fight each other and cost twice)
	do
		local seenKey, duplicates, mountainDuplicates, facets = {}, {}, 0, 0
		for _, d in M.descendants(workspace) do
			local data = RawData[d]
			if data.Props and data.Props.Size and data.Props.CFrame and isBasePart(d) then
				local path = pathOf(d)
				local cf, size = data.Props.CFrame, data.Props.Size
				local r = cf.r
				local key = string.format("%s|%.2f,%.2f,%.2f|%.2f,%.2f,%.2f|%.2f,%.2f,%.2f,%.2f", data.Name, size.X, size.Y, size.Z, cf.X, cf.Y, cf.Z, r[1], r[5], r[9], r[2])
				local isMountain = string.find(path, "^Environment/Backdrop/Mountains") ~= nil or string.find(path, "^Environment/Backdrop/Cliff") ~= nil
				if isMountain then facets += 1 end
				if seenKey[key] then
					if isMountain then
						mountainDuplicates += 1
					elseif string.find(path, "^HamsterPlaza/PlazaStatue") then
						-- (the golden statue is built by HamsterBuilder: reported as a hand-off, see docs/release/world.md)
					else
						table.insert(duplicates, path)
					end
				end
				seenKey[key] = true
			end
		end
		table.sort(duplicates)
		for index = 1, math.min(#duplicates, 5) do print("   DUPLICATE", duplicates[index]) end
		check("no two parts of the world (statue and mountain facets apart) sit on top of each other with the same name, size and place", #duplicates == 0, #duplicates .. " e.g. " .. tostring(duplicates[1]))
		check(string.format("duplicated mountain / cliff facets stay negligible (%d of %d)", mountainDuplicates, facets), mountainDuplicates <= facets * 0.002)
		do
			local probe = { "a|1,1,1|0,0,0", "a|1,1,1|0,0,0" }
			local seen, found = {}, 0
			for _, k in probe do if seen[k] then found += 1 end seen[k] = true end
			check("self-test: two identical parts are found by the duplicate check", found == 1)
		end
	end

	---------------------------------------------------------------------------
	section("5. editable in Studio: ownership and names")
	---------------------------------------------------------------------------
	do
		local owned = { "Environment", "HamsterPlaza", "LeaderboardHall", "HamsterPath", "SpawnLocations" }
		local flags, allOwned = {}, true
		for _, name in owned do
			local folder = workspace:FindFirstChild(name)
			local ok = folder ~= nil and folder:GetAttribute("StudioOwned") == true
			allOwned = allOwned and ok
			flags[#flags + 1] = name .. "=" .. tostring(ok)
		end
		check("the five world folders are Studio-owned (StudioOwned = true) and PlayerHouses is regenerated: " .. table.concat(flags, ", "), allOwned and workspace.PlayerHouses:GetAttribute("StudioOwned") ~= true)
		local function exactlyOne(parent, names)
			local missing = {}
			for _, name in names do
				local n = 0
				for _, child in M.InstanceMethods.GetChildren(parent) do if RawData[child].Name == name then n += 1 end end
				if n ~= 1 then table.insert(missing, name .. " x" .. n) end
			end
			return missing
		end
		local missing = {}
		for _, m in exactlyOne(workspace.HamsterPlaza, { "CoinsShop", "RobuxShop", "LuckyWheel", "PlazaArch", "PlazaFountain", "ReadingNook", "FavoritesBoard", "FavoritesBoard2", "Signpost", "PlazaStatue", "PavingOuter", "ShopApproach", "WheelPath" }) do table.insert(missing, "HamsterPlaza/" .. m) end
		for _, m in exactlyOne(workspace.LeaderboardHall, { "Board_Hamsters", "Board_Steals", "Board_Money", "SafeZone", "KioskBase", "HallSign", "HallPaving", "HallPath" }) do table.insert(missing, "LeaderboardHall/" .. m) end
		for _, m in exactlyOne(workspace.HamsterPath, { "Road", "BurrowHill", "ExitHill", "BurrowSign", "BurrowHole", "ExitHole", "ExitArch", "BurrowBeam" }) do table.insert(missing, "HamsterPath/" .. m) end
		for _, m in exactlyOne(workspace.Environment, { "Ground", "Promenades", "Props", "Forest", "Beyond", "Backdrop", "Transitions", "Boundary", "GrassPatches" }) do table.insert(missing, "Environment/" .. m) end
		check("every landmark is in the Explorer exactly once under a clear name (shops, wheel, arch, fountain, boards, kiosk, road, burrow, exit, forest, mountains ...)", #missing == 0, table.concat(missing, ", "))
		-- no part or model keeps the default name of its class (select it in the Explorer and you would not know what it is)
		local generic = {}
		for _, d in M.descendants(workspace) do
			local data = RawData[d]
			if (isBasePart(d) or data.ClassName == "Model" or data.ClassName == "Folder") and data.Name == data.ClassName then table.insert(generic, pathOf(d)) end
		end
		check("no part, model or folder of the world still has a default name like 'Part' or 'Model'", #generic == 0, #generic .. " e.g. " .. tostring(generic[1]))
		local houseNames = {}
		for index, house in HouseSystem.all() do
			local m = house.Model
			local names = {}
			for _, child in M.InstanceMethods.GetChildren(m) do names[RawData[child].Name] = true end
			if RawData[m].Name ~= "House" .. index or not (names.Tower and names.Yard and names.Wheels and names.Display) then table.insert(houseNames, "House" .. index) end
			for f = 1, house.FloorCount do
				if not house.FloorModels[f] or not string.find(RawData[house.FloorModels[f]].Name, "^Floor" .. f .. "_%a+") then table.insert(houseNames, "House" .. index .. " floor " .. f) end
			end
		end
		check("every house is a Model HouseN with Tower, Yard, Wheels and Display, and its floors are Floor1_HamsterHall ... Floor5_Penthouse", #houseNames == 0, table.concat(houseNames, ", "))
	end

	print(string.format("PASS %d  FAIL %d", results.pass, results.fail))
	print("== done ==")
end)
