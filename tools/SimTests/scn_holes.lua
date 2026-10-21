-- Tower shell audit: every house (north row AND south row), every floor count 1..5, must be a CLOSED shell.
-- The only openings are the entrance (floor 1, front, 10 wide) and the glass panes. Everything is cast ANALYTICALLY here
-- (ray against oriented box / cylinder / ellipsoid of the REAL builders' parts, house-local frame), the mock Raycast is not used.
--
--   T1  facade      a ray from outside straight at the facade of a floor must hit a wall / glass / pillar AT the facade
--                   (entering the tower unobstructed = a hole in the wall; the entrance door is whitelisted)
--   T2  ceiling     a ray straight up from just under the ceiling of a floor must hit a slab / roof (else you see the sky)
--   T3  floor       a ray straight down from just above the floor must hit that floor's slab (else you fall into the floor below)
--                   (T3v counts every visible part, T3c only parts you can stand on)
--   T7  see-through a horizontal line through the inside of the tower that no part blocks at all (you look through the house)
--   T6  from above  a ray straight down from the sky must not land in a room (floor, slab inside the walls, furniture): that is a hole in
--                   the roof / in the ledge where a narrower floor sits on a wider one
--   T8  state       the shell must not depend on the way the floor count was reached (grow, shrink, jump)
--   T9  z-fight     two parts of a different colour with coplanar, overlapping, same-facing, EXPOSED faces (flicker / glitching faces)
--   T9b near-fight  the same for upward faces that are less than 0.025 studs apart (rugs, the arrival pad), incl. discs and turned boxes
--   T10 from inside rays sideways from the middle of every floor must hit a wall / glass / pillar AT the facade (the same as T1, seen from the room)
--   T11 gable       a floor-1 house: a ray along z through the attic must stop at the gable (no notch between the gable steps and the roof)
--   T12 corners     rays at 45 degrees onto the four corners of every floor must hit the corner column / its walls (no vertical seam)
-- T1 / T10 / T12 are cast against the SHELL only (walls, glass, columns, slabs): a balcony, canopy or planter in front of a wall can not hide a
-- hole in it. The last block cuts holes into a clean tower on purpose and checks that the audit sees them (so a green run means something).
local results = { pass = 0, fail = 0 }
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end
local adv = M.Sim.advance

local STEP = 0.25 -- lateral sample spacing (studs)
local YSTEP = 0.2 -- vertical sample spacing for the horizontal casts
local CELL = 1.0 -- bucket size of the spatial index
local ROOFING = { Slab = true, RoofSlab = true, Roof = true, Ridge = true, Gable = true } -- what can be the ceiling over a line of sight
local VERBOSE_HOUSES = { [1] = true, [5] = true } -- one north and one south house print every cluster, the others only the totals

task.spawn(function()
	M.isServer = true
	local mainServer = find("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	adv(3)
	local HouseSystem = require(find("ServerScriptService.Systems.HouseSystem"))
	local HouseBuilder = require(find("ServerScriptService.Systems.WorldBuilder.HouseBuilder"))
	local WorldLayout = require(find("ReplicatedStorage.Modules.WorldLayout"))

	local Z0, Z1 = WorldLayout.TowerFront, WorldLayout.TowerBack
	local FH = WorldLayout.FloorHeight
	local WALL_H = FH - 0.8 -- the walls stop under the slab of the next floor (Tower.luau)
	local DOOR_H = 9.2 -- height of the door opening above the floor (Tower.luau DoorHeader)
	local hwOf = WorldLayout.FloorHalfWidth
	local floorY = WorldLayout.floorY

	---------------------------------------------------------------------------
	-- parts in the house-local frame
	---------------------------------------------------------------------------
	local function describe(inst, house, root)
		local data = RawData[inst]
		local props = data.Props
		local lc = house.CFrame:ToObjectSpace(props.CFrame)
		local r = lc.r
		local size = props.Size
		local shape = if props.Shape then props.Shape.Name else "Block"
		local kind = "box"
		if shape == "Cylinder" then kind = "cyl" elseif shape == "Ball" then kind = "ell" end
		for _, child in data.Children do
			local mesh = RawData[child]
			if mesh.ClassName == "SpecialMesh" and mesh.Props.MeshType and mesh.Props.MeshType.Name == "Sphere" then kind = "ell" end
		end
		local chain, node = {}, inst
		while node and node ~= root do
			table.insert(chain, 1, RawData[node].Name)
			node = RawData[node].Parent
		end
		local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
		local h = { hx, hy, hz }
		local min, max = {}, {}
		local c = { lc.X, lc.Y, lc.Z }
		for k = 1, 3 do
			local extent = 0
			for i = 1, 3 do extent += math.abs(r[(k - 1) * 3 + i]) * h[i] end
			min[k], max[k] = c[k] - extent, c[k] + extent
		end
		local transparency = props.Transparency or 0
		return {
			Inst = inst, Name = data.Name, Chain = table.concat(chain, "/"), Kind = kind, Wedge = data.ClassName == "WedgePart",
			cx = lc.X, cy = lc.Y, cz = lc.Z, r1 = r[1], r2 = r[2], r3 = r[3], r4 = r[4], r5 = r[5], r6 = r[6], r7 = r[7], r8 = r[8], r9 = r[9],
			hx = hx, hy = hy, hz = hz, Min = min, Max = max,
			Transparency = transparency, Solid = props.CanCollide ~= false,
			Glass = transparency >= 0.05, -- 0.05 .. 0.95: a see-through pane
			Color = props.Color, Material = if props.Material then props.Material.Name else "Plastic",
			Top = chain[1] or "?",
		}
	end

	-- every visible part under `root` (default: the tower = floors, interior, entrance, balconies, roof)
	local function collect(house, root)
		root = root or house.Tower
		local parts = {}
		for _, d in M.descendants(root) do
			local data = RawData[d]
			if data.Props and data.Props.Size and data.Props.CFrame and M.InstanceMethods.IsA(d, "BasePart") and data.Props.Anchored and (data.Props.Transparency or 0) < 0.95 then
				table.insert(parts, describe(d, house, root))
			end
		end
		return parts
	end

	---------------------------------------------------------------------------
	-- ray queries (axis-aligned rays only: that is all the audit needs) with a spatial index
	---------------------------------------------------------------------------
	local function cellKey(a, b) return (math.floor(a / CELL) + 4000) * 16384 + (math.floor(b / CELL) + 4000) end

	-- the index for rays travelling along `axis` (1 x, 2 y, 3 z): parts bucketed by their extent in the other two axes
	local function buildIndex(parts, axis)
		local u, v = if axis == 1 then 2 else 1, if axis == 3 then 2 else 3
		local cells = {}
		for _, part in parts do
			for cu = math.floor(part.Min[u] / CELL), math.floor(part.Max[u] / CELL) do
				for cv = math.floor(part.Min[v] / CELL), math.floor(part.Max[v] / CELL) do
					local key = (cu + 4000) * 16384 + (cv + 4000)
					local list = cells[key]
					if not list then list = {} cells[key] = list end
					table.insert(list, part)
				end
			end
		end
		return { U = u, V = v, Cells = cells }
	end

	local function newScene(parts)
		return { Parts = parts, Index = { buildIndex(parts, 1), buildIndex(parts, 2), buildIndex(parts, 3) } }
	end

	-- t along the unit ray (o + t d) where it first enters the part, 0 when it starts inside, nil on a miss
	local function hitPart(part, ox, oy, oz, dx, dy, dz)
		local ex, ey, ez = ox - part.cx, oy - part.cy, oz - part.cz
		local lox, loy, loz = part.r1 * ex + part.r4 * ey + part.r7 * ez, part.r2 * ex + part.r5 * ey + part.r8 * ez, part.r3 * ex + part.r6 * ey + part.r9 * ez
		local ldx, ldy, ldz = part.r1 * dx + part.r4 * dy + part.r7 * dz, part.r2 * dx + part.r5 * dy + part.r8 * dz, part.r3 * dx + part.r6 * dy + part.r9 * dz
		local hx, hy, hz = part.hx, part.hy, part.hz
		local kind = part.Kind
		if kind == "ell" then
			local qx0, qy0, qz0, qx1, qy1, qz1 = lox / hx, loy / hy, loz / hz, ldx / hx, ldy / hy, ldz / hz
			local a = qx1 * qx1 + qy1 * qy1 + qz1 * qz1
			local b = 2 * (qx0 * qx1 + qy0 * qy1 + qz0 * qz1)
			local c = qx0 * qx0 + qy0 * qy0 + qz0 * qz0 - 1
			if a < 1e-12 then return nil end
			local disc = b * b - 4 * a * c
			if disc < 0 then return nil end
			local root = math.sqrt(disc)
			local t0, t1 = (-b - root) / (2 * a), (-b + root) / (2 * a)
			if t1 < 0 then return nil end
			return math.max(t0, 0)
		end
		local lo, hi = 0, math.huge
		-- slab test on x (for a cylinder this is the axis), then y / z (box) or the circle (cylinder)
		if math.abs(ldx) < 1e-9 then
			if math.abs(lox) > hx then return nil end
		else
			local t1, t2 = (-hx - lox) / ldx, (hx - lox) / ldx
			if t1 > t2 then t1, t2 = t2, t1 end
			lo, hi = math.max(lo, t1), math.min(hi, t2)
		end
		if kind == "cyl" then
			local radius = math.min(hy, hz)
			local a = ldy * ldy + ldz * ldz
			local b = 2 * (loy * ldy + loz * ldz)
			local c = loy * loy + loz * loz - radius * radius
			if a < 1e-12 then
				if c > 0 then return nil end
			else
				local disc = b * b - 4 * a * c
				if disc < 0 then return nil end
				local root = math.sqrt(disc)
				lo, hi = math.max(lo, (-b - root) / (2 * a)), math.min(hi, (-b + root) / (2 * a))
			end
		else
			if math.abs(ldy) < 1e-9 then
				if math.abs(loy) > hy then return nil end
			else
				local t1, t2 = (-hy - loy) / ldy, (hy - loy) / ldy
				if t1 > t2 then t1, t2 = t2, t1 end
				lo, hi = math.max(lo, t1), math.min(hi, t2)
			end
			if math.abs(ldz) < 1e-9 then
				if math.abs(loz) > hz then return nil end
			else
				local t1, t2 = (-hz - loz) / ldz, (hz - loz) / ldz
				if t1 > t2 then t1, t2 = t2, t1 end
				lo, hi = math.max(lo, t1), math.min(hi, t2)
			end
		end
		if part.Wedge then
			-- a WedgePart is the half of its box below the slope: the right angle is at the back-bottom (+z, -y), the slope rises towards +z
			local a, b = loy / hy - loz / hz, ldy / hy - ldz / hz
			if math.abs(b) < 1e-12 then
				if a > 0 then return nil end
			elseif b > 0 then
				hi = math.min(hi, -a / b)
			else
				lo = math.max(lo, -a / b)
			end
		end
		if hi < lo then return nil end
		return lo
	end

	-- first part hit by the axis-aligned ray starting at (ox, oy, oz) going along `axis` * `sign`. Returns t, part.
	local function cast(scene, axis, sign, ox, oy, oz)
		local index = scene.Index[axis]
		local origin = { ox, oy, oz }
		local list = index.Cells[cellKey(origin[index.U], origin[index.V])]
		if not list then return nil, nil end
		local dx, dy, dz = if axis == 1 then sign else 0, if axis == 2 then sign else 0, if axis == 3 then sign else 0
		local best, bestPart = math.huge, nil
		for _, part in list do
			local t = hitPart(part, ox, oy, oz, dx, dy, dz)
			if t and t < best then best, bestPart = t, part end
		end
		if bestPart then return best, bestPart end
		return nil, nil
	end

	---------------------------------------------------------------------------
	-- clustering of failing samples
	---------------------------------------------------------------------------
	-- cells: list of { u = , v = , note = } -> list of clusters { u0, u1, v0, v1, count, notes }, biggest first
	local function clusterize(cells, step)
		local byKey, seen, clusters = {}, {}, {}
		local function key(i, j) return i * 100003 + j end
		for _, c in cells do
			byKey[key(math.floor(c.u / step + 0.5), math.floor(c.v / step + 0.5))] = c
		end
		for k, c in byKey do
			if not seen[k] then
				local cluster = { u0 = math.huge, u1 = -math.huge, v0 = math.huge, v1 = -math.huge, count = 0, notes = {} }
				local stack = { c }
				seen[k] = true
				while #stack > 0 do
					local cur = table.remove(stack)
					cluster.u0, cluster.u1 = math.min(cluster.u0, cur.u), math.max(cluster.u1, cur.u)
					cluster.v0, cluster.v1 = math.min(cluster.v0, cur.v), math.max(cluster.v1, cur.v)
					cluster.count += 1
					cluster.notes[cur.note] = (cluster.notes[cur.note] or 0) + 1
					local i, j = math.floor(cur.u / step + 0.5), math.floor(cur.v / step + 0.5)
					for _, d in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
						local nk = key(i + d[1], j + d[2])
						if byKey[nk] and not seen[nk] then
							seen[nk] = true
							table.insert(stack, byKey[nk])
						end
					end
				end
				table.insert(clusters, cluster)
			end
		end
		table.sort(clusters, function(a, b) return a.count > b.count end)
		return clusters
	end

	local function noteText(notes)
		local names = {}
		for name, n in notes do table.insert(names, { name, n }) end
		table.sort(names, function(a, b) return a[2] > b[2] end)
		local out = {}
		for i = 1, math.min(#names, 3) do table.insert(out, string.format("%s x%d", names[i][1], names[i][2])) end
		return table.concat(out, ", ")
	end

	---------------------------------------------------------------------------
	-- the tests of one house in one state
	---------------------------------------------------------------------------
	local totals
	local quiet = false
	local function resetTotals() totals = { T1 = 0, T2 = 0, T3v = 0, T3c = 0, T4 = 0, T5 = 0, T6 = 0, T7 = 0, T9 = 0, T9b = 0, T10 = 0, T11 = 0, T12 = 0 } end
	resetTotals()

	local function report(house, count, test, label, clusters, step, uName, vName)
		local area = 0
		for _, c in clusters do area += c.count * step * step end
		totals[test] += #clusters
		if #clusters == 0 or quiet then return end
		print(string.format("   %s house %d floors=%d %s: %d opening(s), %.1f sq studs", test, house.Index, count, label, #clusters, area))
		if VERBOSE_HOUSES[house.Index] then
			for i = 1, math.min(#clusters, 6) do
				local c = clusters[i]
				print(string.format("        %s %.2f..%.2f  %s %.2f..%.2f  (%.1f sq studs)  first hit: %s", uName, c.u0 - step / 2, c.u1 + step / 2, vName, c.v0 - step / 2, c.v1 + step / 2, c.count * step * step, noteText(c.notes)))
			end
			if #clusters > 6 then print(string.format("        ... and %d more", #clusters - 6)) end
		end
	end

	local function auditHouse(house, count)
		local parts = collect(house)
		local scene = newScene(parts)
		local structure, structureSolid = {}, {}
		for _, part in parts do
			local name = part.Name
			if name == "Slab" or name == "Floor" or name == "FloorSurface" or name == "Foundation" or name == "BalconySlab" or name == "RoofSlab" then
				table.insert(structure, part)
				if part.Solid then table.insert(structureSolid, part) end
			end
		end
		local structureScene, structureSolidScene = newScene(structure), newScene(structureSolid)
		-- the shell alone (walls, glass, columns, slabs, fascia: no furniture, balcony, canopy or planter that could hide a hole behind it)
		local shellParts, roofParts = {}, {}
		for _, part in parts do
			if string.find(part.Chain, "/Shell/", 1, true) then table.insert(shellParts, part) end
			if ROOFING[part.Name] then table.insert(roofParts, part) end
		end
		local shellScene, roofScene = newScene(shellParts), newScene(roofParts)
		local glassHits = { front = 0, back = 0, left = 0, right = 0 }
		local opaqueHits = { front = 0, back = 0, left = 0, right = 0 }

		-----------------------------------------------------------------------
		-- T1: facade, from outside towards every floor's wall band
		-----------------------------------------------------------------------
		for f = 1, count do
			local hw = hwOf[f]
			local y0 = floorY(f)
			local yLow = if f == 1 then 0.025 else y0 + 0.025
			local sides = {
				{ Name = "front", Axis = 3, Sign = 1, Plane = Z0, Lateral = { -hw, hw }, Origin = -40 },
				{ Name = "back", Axis = 3, Sign = -1, Plane = Z1, Lateral = { -hw, hw }, Origin = 130 },
				{ Name = "left", Axis = 1, Sign = 1, Plane = -hw, Lateral = { Z0, Z1 }, Origin = -70 },
				{ Name = "right", Axis = 1, Sign = -1, Plane = hw, Lateral = { Z0, Z1 }, Origin = 70 },
			}
			for _, side in sides do
				local cells = {}
				local lateral = side.Lateral[1] + STEP / 2
				while lateral < side.Lateral[2] do
					local y = yLow
					while y < y0 + WALL_H - 0.02 do
						local ox, oy, oz
						if side.Axis == 3 then ox, oy, oz = lateral, y, side.Origin else ox, oy, oz = side.Origin, y, lateral end
						local t, part = cast(shellScene, side.Axis, side.Sign, ox, oy, oz)
						-- distance from the facade plane to the first hit, measured inwards
						local inward = math.huge
						if t then
							local hit = (if side.Axis == 3 then oz else ox) + side.Sign * t
							inward = side.Sign * (hit - side.Plane)
							if inward <= 0.9 then
								if part.Glass then glassHits[side.Name] += 1 else opaqueHits[side.Name] += 1 end
							end
						end
						if inward > 0.9 then
							local door = side.Name == "front" and f == 1 and math.abs(lateral) <= WorldLayout.DoorHalfWidth + 0.05 and y - y0 <= DOOR_H + 0.05
							if not door then
								cells[#cells + 1] = { u = lateral, v = y, note = if part then (part.Chain .. " (deep)") else "NOTHING" }
							end
						end
						y += STEP
					end
					lateral += STEP
				end
				report(house, count, "T1", string.format("floor %d %s facade", f, side.Name), clusterize(cells, STEP), STEP, if side.Axis == 3 then "x" else "z", "y")
			end
		end

		-----------------------------------------------------------------------
		-- T2: ceilings (a ray up from just under the ceiling of every floor)
		-----------------------------------------------------------------------
		for f = 1, count do
			local hw = hwOf[f]
			local yStart = floorY(f) + WALL_H - 0.02
			local cells, hanging = {}, {}
			local x = -hw + 0.3 + STEP / 2
			while x < hw - 0.3 do
				local z = Z0 + 0.3 + STEP / 2
				while z < Z1 - 0.3 do
					-- the ceiling must be a slab / roof part (a corner column or a lamp is no ceiling)
					local t, part = cast(roofScene, 2, 1, x, yStart, z)
					local covered = t ~= nil and (t < 0.15 or count == 1)
					local ta, any = cast(scene, 2, 1, x, yStart, z)
					if not covered then
						cells[#cells + 1] = { u = x, v = z, note = if part then string.format("%s (+%.1f above)", part.Chain, t) elseif any then string.format("SKY (first part above: %s)", any.Chain) else "SKY" }
					elseif ta and ta >= 0.15 and not ROOFING[any.Name] then
						-- something that is not the roof itself hangs down into the room under the gabled roof (the chimney)
						hanging[#hanging + 1] = { u = x, v = z, note = string.format("%s (%.1f above the wall top)", any.Chain, ta) }
					end
					z += STEP
				end
				x += STEP
			end
			report(house, count, "T2", string.format("ceiling of floor %d", f), clusterize(cells, STEP), STEP, "x", "z")
			report(house, count, "T5", string.format("things hanging from the ceiling of floor %d", f), clusterize(hanging, STEP), STEP, "x", "z")
		end

		-----------------------------------------------------------------------
		-- T3: floors (a ray down from just above the floor surface)
		-----------------------------------------------------------------------
		for f = 1, count do
			local hw = hwOf[f]
			local y0 = floorY(f)
			for _, mode in { "v", "c" } do
				local sc = if mode == "v" then structureScene else structureSolidScene
				local cells = {}
				local x = -hw + 0.3 + STEP / 2
				while x < hw - 0.3 do
					local z = Z0 + 0.3 + STEP / 2
					while z < Z1 - 0.3 do
						local t = cast(sc, 2, -1, x, y0 + 0.45, z)
						local hitY = if t then y0 + 0.45 - t else -math.huge
						if hitY < y0 - 0.25 then
							-- what is below: look further down with ALL parts to name it
							local _, below = cast(scene, 2, -1, x, y0 - 0.9, z)
							cells[#cells + 1] = { u = x, v = z, note = if below then ("see " .. below.Chain) else "GROUND/NOTHING" }
						end
						z += STEP
					end
					x += STEP
				end
				report(house, count, "T3" .. mode, string.format("floor %d surface", f), clusterize(cells, STEP), STEP, "x", "z")
			end
		end

		-----------------------------------------------------------------------
		-- T4: the roof sits ON the wall tops: no slit between a wall top and what is above it (gabled roof: the eaves)
		-----------------------------------------------------------------------
		if count == 1 then
			local top = floorY(1) + WALL_H
			local cells = {}
			for _, side in { -1, 1 } do
				for _, dx in { -0.3, 0, 0.3 } do
					local x = side * (hwOf[1] + dx)
					local z = Z0 + 1
					while z < Z1 do
						local t, part = cast(scene, 2, 1, x, top + 0.001, z)
						if not t or t > 0.06 then
							cells[#cells + 1] = { u = z, v = x, note = if part then string.format("%s %.2f above the wall top", part.Chain, t) else "SKY" }
						end
						z += 1
					end
				end
			end
			report(house, count, "T4", "eave (wall top to roof underside)", clusterize(cells, 1), 1, "z", "x")
		end

		-----------------------------------------------------------------------
		-- T6: from the sky straight down: the first thing hit must not be inside a room
		-----------------------------------------------------------------------
		do
			local cells = {}
			local x = -hwOf[1] - 1 + STEP / 2
			while x < hwOf[1] + 1 do
				local z = Z0 - 1 + STEP / 2
				while z < Z1 + 1 do
					local t, part = cast(scene, 2, -1, x, 200, z)
					if part then
						local floorNo = tonumber(string.match(part.Chain, "^Floor(%d)_"))
						-- a room = furniture, the floor itself, or the slab INSIDE the walls of its floor (the rim outside the walls is a ledge)
						local room = floorNo ~= nil
							and (string.find(part.Chain, "/Interior/", 1, true) ~= nil
								or part.Name == "Floor"
								or part.Name == "FloorSurface"
								or (part.Name == "Slab" and math.abs(x) < hwOf[floorNo] - 0.35 and z > Z0 + 0.35 and z < Z1 - 0.35))
						if room then
							cells[#cells + 1] = { u = x, v = z, note = string.format("%s (%.1f below the sky)", part.Chain, t) }
						end
					end
					z += STEP
				end
				x += STEP
			end
			report(house, count, "T6", "the sky sees into a room", clusterize(cells, STEP), STEP, "x", "z")
		end

		-----------------------------------------------------------------------
		-- T10: from the middle of every floor sideways: the first thing hit must be the facade itself
		-----------------------------------------------------------------------
		for f = 1, count do
			local hw = hwOf[f]
			local y0 = floorY(f)
			local sides = {
				{ Name = "left", Axis = 1, Sign = -1, Plane = -hw, Origin = 0, Lateral = { Z0 + 0.6, Z1 - 0.6 } },
				{ Name = "right", Axis = 1, Sign = 1, Plane = hw, Origin = 0, Lateral = { Z0 + 0.6, Z1 - 0.6 } },
				{ Name = "front", Axis = 3, Sign = -1, Plane = Z0, Origin = (Z0 + Z1) / 2, Lateral = { -hw + 0.3, hw - 0.3 } },
				{ Name = "back", Axis = 3, Sign = 1, Plane = Z1, Origin = (Z0 + Z1) / 2, Lateral = { -hw + 0.3, hw - 0.3 } },
			}
			for _, side in sides do
				local cells = {}
				local lateral = side.Lateral[1] + STEP / 2
				while lateral < side.Lateral[2] do
					local y = y0 + 0.025
					while y < y0 + WALL_H - 0.02 do
						local ox, oz = if side.Axis == 1 then side.Origin else lateral, if side.Axis == 1 then lateral else side.Origin
						local t, part = cast(shellScene, side.Axis, side.Sign, ox, y, oz)
						local off = math.huge
						if t then off = math.abs((if side.Axis == 1 then ox else oz) + side.Sign * t - side.Plane) end
						if off > 0.9 then
							local door = side.Name == "front" and f == 1 and math.abs(lateral) <= WorldLayout.DoorHalfWidth + 0.05 and y - y0 <= DOOR_H + 0.05
							if not door then
								cells[#cells + 1] = { u = lateral, v = y, note = if part then string.format("%s (%.1f off the facade)", part.Chain, off) else "NOTHING" }
							end
						end
						y += STEP
					end
					lateral += STEP
				end
				report(house, count, "T10", string.format("floor %d %s facade seen from inside", f, side.Name), clusterize(cells, STEP), STEP, if side.Axis == 1 then "z" else "x", "y")
			end
		end

		-----------------------------------------------------------------------
		-- T11: a gabled roof (one floor): a line of sight along z through the attic must be stopped by the gable, not slip through a notch
		-----------------------------------------------------------------------
		if count == 1 then
			local top = floorY(1) + WALL_H
			local cells = {}
			local x = -hwOf[1] + 0.3 + STEP / 2
			while x < hwOf[1] - 0.3 do
				local y = top + 0.05
				while y < top + 14 do
					-- (x, y) is in the attic when the roof is above it somewhere along the house
					if cast(roofScene, 2, 1, x, y, (Z0 + Z1) / 2) then
						local t, part = cast(scene, 3, 1, x, y, -60)
						if not t or -60 + t > Z0 + 1.2 then
							cells[#cells + 1] = { u = x, v = y, note = if part then string.format("%s (first hit at z %.1f)", part.Chain, -60 + t) else "SEE-THROUGH" }
						end
					end
					y += YSTEP
				end
				x += STEP
			end
			report(house, count, "T11", "gable front: notch / gap between the gable and the roof", clusterize(cells, math.max(STEP, YSTEP)), math.max(STEP, YSTEP), "x", "y")
		end

		-----------------------------------------------------------------------
		-- T12: rays at 45 degrees onto the four corners of every floor
		-----------------------------------------------------------------------
		do
			local diag = math.sqrt(0.5)
			for f = 1, count do
				local hw = hwOf[f]
				local y0 = floorY(f)
				local cells = {}
				for _, sx in { -1, 1 } do
					for _, corner in { { Z = Z0, Out = -1 }, { Z = Z1, Out = 1 } } do
						local cx, cz = sx * hw, corner.Z
						local ox, oz = sx * diag, corner.Out * diag -- outwards; the ray travels the other way
						local s = -1.2
						while s <= 1.2 do
							local y = y0 + 0.23 -- (not on the 2.2 seam between the lower band and the glass: a ray exactly on it can slip between the two boxes)
							while y < y0 + WALL_H - 0.1 do
								local px, pz = cx + ox * 30 - oz * s, cz + oz * 30 + ox * s
								local best, bestPart = math.huge, nil
								for _, part in shellParts do
									local t = hitPart(part, px, y, pz, -ox, 0, -oz)
									if t and t < best then best, bestPart = t, part end
								end
								local away = math.huge
								if bestPart then away = math.sqrt((px - ox * best - cx) ^ 2 + (pz - oz * best - cz) ^ 2) end
								if away > 2.2 then
									cells[#cells + 1] = { u = s, v = y, note = if bestPart then string.format("%s (%.1f from the corner)", bestPart.Chain, away) else "NOTHING" }
								end
								y += 0.5
							end
							s += 0.1
						end
					end
				end
				report(house, count, "T12", string.format("floor %d corners", f), clusterize(cells, 0.5), 0.5, "s", "y")
			end
		end

		-----------------------------------------------------------------------
		-- T7: horizontal lines through the inside of the tower that nothing blocks
		-----------------------------------------------------------------------
		local topY = floorY(count) + FH + (if count >= 2 then 1.4 else 11)
		-- is the horizontal line (along `axis`, at this lateral position and height) inside the tower? = somewhere on it a slab / roof
		-- is above AND something below it (a chimney cap or the emblem above a line does not make it "inside")
		local function insideTower(axis, lateral, y)
			local pos = if axis == 3 then Z0 + 1 else -hwOf[1] + 0.5
			local last = if axis == 3 then Z1 - 1 else hwOf[1] - 0.5
			while pos <= last do
				local x, z = if axis == 3 then lateral else pos, if axis == 3 then pos else lateral
				local _, above = cast(scene, 2, 1, x, y, z)
				if above and ROOFING[above.Name] and cast(scene, 2, -1, x, y, z) then return true end
				pos += 2
			end
			return false
		end
		for _, axis in { 3, 1 } do
			local cells = {}
			local lateralFrom, lateralTo = if axis == 3 then -hwOf[1] - 1 else Z0 - 0.5, if axis == 3 then hwOf[1] + 1 else Z1 + 0.5
			local lateral = lateralFrom + STEP / 2
			while lateral < lateralTo do
				local y = 0.05
				while y < topY do
					local ox, oy, oz
					if axis == 3 then ox, oy, oz = lateral, y, -60 else ox, oy, oz = -80, y, lateral end
					if not cast(scene, axis, 1, ox, oy, oz) and insideTower(axis, lateral, y) then
						cells[#cells + 1] = { u = lateral, v = y, note = "see-through" }
					end
					y += YSTEP
				end
				lateral += STEP
			end
			local step = math.max(STEP, YSTEP)
			report(house, count, "T7", if axis == 3 then "line along z (front to back)" else "line along x (side to side)", clusterize(cells, step), step, if axis == 3 then "x" else "z", "y")
		end

		-----------------------------------------------------------------------
		-- T9: coplanar, overlapping, same-facing, exposed faces of different colours (z-fighting)
		-----------------------------------------------------------------------
		-- the tower plus whatever of the yard lies at ground level (lawn, driveway, apron, steps meet the foundation there)
		local groundParts = {}
		for _, part in collect(house, house.Model) do
			if not string.find(part.Chain, "^Yard") or part.Min[2] < 1.5 then table.insert(groundParts, part) end
		end
		parts = groundParts
		local axisAligned = {}
		for _, part in parts do
			if part.Kind == "box" and not part.Wedge and not part.Glass then
				local ok = true
				-- the rotation must be a multiple of 90 degrees about some axis (every entry 0 or +-1)
				for _, v in { part.r1, part.r2, part.r3, part.r4, part.r5, part.r6, part.r7, part.r8, part.r9 } do
					if math.abs(v) > 1e-3 and math.abs(math.abs(v) - 1) > 1e-3 then ok = false end
				end
				if ok then table.insert(axisAligned, part) end
			end
		end
		local zfights = {}
		local function sameColor(a, b)
			return math.abs(a.Color.R - b.Color.R) + math.abs(a.Color.G - b.Color.G) + math.abs(a.Color.B - b.Color.B) < 0.02 and a.Material == b.Material
		end
		-- is the point inside some other visible, non-glass box? (then a face there is hidden and cannot flicker)
		local function covered(x, y, z, a, b)
			if y < 0.005 then return true end -- on the ground
			for _, p in parts do
				if p ~= a and p ~= b and not p.Glass and p.Kind == "box" then
					local ex, ey, ez = x - p.cx, y - p.cy, z - p.cz
					local lx, ly, lz = p.r1 * ex + p.r4 * ey + p.r7 * ez, p.r2 * ex + p.r5 * ey + p.r8 * ez, p.r3 * ex + p.r6 * ey + p.r9 * ez
					if math.abs(lx) < p.hx - 1e-4 and math.abs(ly) < p.hy - 1e-4 and math.abs(lz) < p.hz - 1e-4 then return true end
				end
			end
			return false
		end
		for i = 1, #axisAligned do
			local a = axisAligned[i]
			for j = i + 1, #axisAligned do
				local b = axisAligned[j]
				if a.Min[1] < b.Max[1] - 1e-4 and b.Min[1] < a.Max[1] - 1e-4 and a.Min[2] < b.Max[2] - 1e-4 and b.Min[2] < a.Max[2] - 1e-4 and a.Min[3] < b.Max[3] - 1e-4 and b.Min[3] < a.Max[3] - 1e-4 then
					-- the boxes overlap; a face of a and a face of b are coplanar when a min/max (same side) coincide on one axis
					for k = 1, 3 do
						for _, side in { "Min", "Max" } do
							if math.abs(a[side][k] - b[side][k]) < 0.002 and not sameColor(a, b) then
								-- overlap of the two faces in the other two axes
								local area, centre = 1, { 0, 0, 0 }
								for m = 1, 3 do
									if m ~= k then
										local lo, hi = math.max(a.Min[m], b.Min[m]), math.min(a.Max[m], b.Max[m])
										area *= math.max(0, hi - lo)
										centre[m] = (lo + hi) / 2
									end
								end
								if area > 0.05 then
									centre[k] = a[side][k] + (if side == "Max" then 0.03 else -0.03)
									if not covered(centre[1], centre[2], centre[3], a, b) then
										local key = string.format("%s:%s x %s:%s  %s%s face", a.Chain, a.Name, b.Chain, b.Name, side, ({ "X", "Y", "Z" })[k])
										zfights[key] = { Area = area, Centre = centre }
									end
								end
							end
						end
					end
				end
			end
		end
		local zkeys = {}
		for key in zfights do table.insert(zkeys, key) end
		table.sort(zkeys, function(x, y) return zfights[x].Area > zfights[y].Area end)
		totals.T9 += #zkeys
		if #zkeys > 0 and not quiet then
			print(string.format("   T9 house %d floors=%d: %d exposed coplanar overlapping face pair(s) of different colour", house.Index, count, #zkeys))
			if VERBOSE_HOUSES[house.Index] and count == 5 then
				for i = 1, math.min(#zkeys, 40) do
					local z = zfights[zkeys[i]]
					print(string.format("        %7.2f sq at (%.1f, %.1f, %.1f)  %s", z.Area, z.Centre[1], z.Centre[2], z.Centre[3], zkeys[i]))
				end
				if #zkeys > 40 then print(string.format("        ... and %d more", #zkeys - 40)) end
			end
		end

		-----------------------------------------------------------------------
		-- T9b: upward faces of a different colour that lie less than NEAR (0.025) studs apart and overlap: they flicker at a distance.
		-- Boxes turned about the vertical axis and upright cylinders (rugs, the arrival pad) are included; exactly coplanar faces of
		-- axis-aligned boxes are T9's. A third part covering the spot (a table on the rug) hides the pair.
		-----------------------------------------------------------------------
		do
			local NEAR, EPS = 0.025, 1e-3
			local faces, buckets = {}, {}
			for _, part in parts do
				local face
				if not part.Glass and not part.Wedge then
					if part.Kind == "box" and part.r5 > 1 - EPS and math.abs(part.r2) < EPS and math.abs(part.r4) < EPS and math.abs(part.r6) < EPS and math.abs(part.r8) < EPS then
						local ex, ez = math.abs(part.r1) * part.hx + math.abs(part.r3) * part.hz, math.abs(part.r7) * part.hx + math.abs(part.r9) * part.hz
						face = { Part = part, Y = part.cy + part.hy, X0 = part.cx - ex, X1 = part.cx + ex, Z0 = part.cz - ez, Z1 = part.cz + ez, Rect = true }
					elseif part.Kind == "cyl" and math.abs(part.r4) > 1 - EPS then
						local radius = math.min(part.hy, part.hz)
						face = { Part = part, Y = part.cy + part.hx, X0 = part.cx - radius, X1 = part.cx + radius, Z0 = part.cz - radius, Z1 = part.cz + radius, Radius = radius }
					end
				end
				if face then
					table.insert(faces, face)
					face.Index = #faces
					local key = math.floor(face.Y / 0.04)
					local list = buckets[key]
					if not list then list = {} buckets[key] = list end
					table.insert(list, face)
				end
			end
			local function inside(face, x, z)
				local part = face.Part
				if face.Radius then
					return (x - part.cx) ^ 2 + (z - part.cz) ^ 2 <= face.Radius ^ 2
				end
				local dx, dz = x - part.cx, z - part.cz
				return math.abs(part.r1 * dx + part.r7 * dz) <= part.hx and math.abs(part.r3 * dx + part.r9 * dz) <= part.hz
			end
			local near = {}
			for _, a in faces do
				for bucket = math.floor(a.Y / 0.04) - 1, math.floor(a.Y / 0.04) + 1 do
					for _, b in buckets[bucket] or {} do
						local dy = math.abs(a.Y - b.Y)
						local axisAlignedPair = a.Rect and b.Rect and math.abs(a.Part.r1) * math.abs(a.Part.r7) < EPS and math.abs(b.Part.r1) * math.abs(b.Part.r7) < EPS
						-- every pair once; two axis-aligned boxes at the same height are T9's
						if b.Index > a.Index and dy <= NEAR and not (axisAlignedPair and dy < 0.002) and not sameColor(a.Part, b.Part) then
							local x0, x1, z0, z1 = math.max(a.X0, b.X0), math.min(a.X1, b.X1), math.max(a.Z0, b.Z0), math.min(a.Z1, b.Z1)
							if x1 > x0 and z1 > z0 then
								local nx, nz = math.clamp(math.ceil((x1 - x0) / 0.25), 1, 60), math.clamp(math.ceil((z1 - z0) / 0.25), 1, 60)
								local cell = ((x1 - x0) / nx) * ((z1 - z0) / nz)
								local hits, cx, cz = 0, 0, 0
								for i = 1, nx do
									for j = 1, nz do
										local x, z = x0 + (i - 0.5) * (x1 - x0) / nx, z0 + (j - 0.5) * (z1 - z0) / nz
										if inside(a, x, z) and inside(b, x, z) and not covered(x, math.max(a.Y, b.Y) + 0.03, z, a.Part, b.Part) then
											hits += 1
											cx, cz = cx + x, cz + z
										end
									end
								end
								if hits * cell > 0.05 then
									local key = string.format("%s:%s x %s:%s  dy %.3f", a.Part.Chain, a.Part.Name, b.Part.Chain, b.Part.Name, dy)
									near[key] = { Area = hits * cell, X = cx / hits, Y = math.max(a.Y, b.Y), Z = cz / hits }
								end
							end
						end
					end
				end
			end
			local nkeys = {}
			for key in near do table.insert(nkeys, key) end
			table.sort(nkeys, function(x, y) return near[x].Area > near[y].Area end)
			totals.T9b += #nkeys
			if #nkeys > 0 and not quiet then
				print(string.format("   T9b house %d floors=%d: %d near-coplanar (< %.3f studs) upward face pair(s) of different colour", house.Index, count, #nkeys, NEAR))
				if VERBOSE_HOUSES[house.Index] and count == 5 then
					for i = 1, math.min(#nkeys, 25) do
						local z = near[nkeys[i]]
						print(string.format("        %7.2f sq at (%.1f, %.2f, %.1f)  %s", z.Area, z.X, z.Y, z.Z, nkeys[i]))
					end
					if #nkeys > 25 then print(string.format("        ... and %d more", #nkeys - 25)) end
				end
			end
		end

		-- what the facades are made of (informational: a facade of glass is a design choice, but it reads as "open" from outside)
		if VERBOSE_HOUSES[house.Index] and (count == 1 or count == 3 or count == 5) and not quiet then
			local line = {}
			for _, name in { "front", "left", "back", "right" } do
				local total = glassHits[name] + opaqueHits[name]
				table.insert(line, string.format("%s %d%%", name, math.floor(100 * glassHits[name] / math.max(total, 1) + 0.5)))
			end
			print(string.format("   (house %d floors=%d: share of the facade bands that is see-through glass: %s)", house.Index, count, table.concat(line, ", ")))
		end
		return parts
	end

	---------------------------------------------------------------------------
	-- run: houses 1, 2 (north row) and 5, 8 (south row) grow floor by floor like in the game
	---------------------------------------------------------------------------
	local wedges, shapes = 0, {}
	for _, house in HouseSystem.all() do
		if house.Index == 1 or house.Index == 2 or house.Index == 5 or house.Index == 8 then
			for count = 1, 5 do
				HouseBuilder.setFloors(house, count, Random.new(count))
				adv(0.2)
				local parts = auditHouse(house, count)
				for _, part in parts do
					if part.Wedge then wedges += 1 end
					shapes[part.Kind] = (shapes[part.Kind] or 0) + 1
				end
			end
		end
	end
	print(string.format("   (part kinds seen: box %d, cyl %d, ellipsoid %d, wedge %d)", shapes.box or 0, shapes.cyl or 0, shapes.ell or 0, wedges))

	check("T1 every facade (front, back, both sides; floors 1-5; both rows) is closed: only the entrance is open", totals.T1 == 0, totals.T1 .. " opening(s)")
	check("T2 every floor has a closed ceiling (slab or roof over the whole inside)", totals.T2 == 0, totals.T2 .. " opening(s)")
	check("T3v every floor surface is closed (nothing to see through)", totals.T3v == 0, totals.T3v .. " opening(s)")
	check("T3c every floor can be stood on over its whole inside (nothing to fall through)", totals.T3c == 0, totals.T3c .. " opening(s)")
	check("T4 the roof of a one-floor house sits on the wall tops (no slit under the eaves)", totals.T4 == 0, totals.T4 .. " slit(s)")
	check("T5 nothing of the roof hangs down into a room (the chimney stops at the roof)", totals.T5 == 0, totals.T5 .. " object(s)")
	check("T6 from the sky you never land in a room (roof and ledges are closed)", totals.T6 == 0, totals.T6 .. " opening(s)")
	check("T7 you can not look straight through the tower (front to back or side to side)", totals.T7 == 0, totals.T7 .. " see-through region(s)")
	check("T9 no two differently coloured parts share an exposed coplanar, overlapping face (z-fighting)", totals.T9 == 0, totals.T9 .. " face pair(s)")
	check("T9b no two differently coloured upward faces lie less than 0.025 studs apart and overlap (flicker at a distance)", totals.T9b == 0, totals.T9b .. " face pair(s)")
	check("T10 seen from inside every facade is closed (walls, glass and columns at the facade; only the entrance is open)", totals.T10 == 0, totals.T10 .. " opening(s)")
	check("T11 the gable of a one-floor house is closed up to the roof (no notch you can look into)", totals.T11 == 0, totals.T11 .. " notch(es)")
	check("T12 the four corners of every floor are closed (no vertical seam at 45 degrees)", totals.T12 == 0, totals.T12 .. " seam(s)")

	---------------------------------------------------------------------------
	-- T8: the shell does not depend on the way the floor count was reached
	---------------------------------------------------------------------------
	local function signature(house)
		local lines = {}
		for _, d in M.descendants(house.Tower) do
			local data = RawData[d]
			if data.Props and data.Props.Size and data.Props.CFrame and M.InstanceMethods.IsA(d, "BasePart") then
				local lc = house.CFrame:ToObjectSpace(data.Props.CFrame)
				local node, chain = d, {}
				while node and node ~= house.Tower do table.insert(chain, 1, RawData[node].Name) node = RawData[node].Parent end
				table.insert(lines, string.format("%s|%.2f,%.2f,%.2f|%.2f,%.2f,%.2f|%.2f", table.concat(chain, "/"), lc.X, lc.Y, lc.Z, data.Props.Size.X, data.Props.Size.Y, data.Props.Size.Z, data.Props.Transparency or 0))
			end
		end
		table.sort(lines)
		return lines
	end
	local function diff(a, b)
		local have = {}
		for _, line in a do have[line] = (have[line] or 0) + 1 end
		local extra, missing = {}, {}
		for _, line in b do
			if have[line] and have[line] > 0 then have[line] -= 1 else table.insert(extra, line) end
		end
		for line, n in have do if n > 0 then table.insert(missing, line) end end
		return extra, missing
	end
	local houses = HouseSystem.all()
	local reference = {}
	do
		-- the reference for every count: a house grown 1 -> count in single steps
		local house = houses[3]
		for count = 1, 5 do
			HouseBuilder.setFloors(house, count, Random.new(count))
			adv(0.1)
			reference[count] = signature(house)
		end
	end
	local mismatches = 0
	local paths = {
		{ "shrink 5 -> n", houses[4], { 5, 4, 3, 2, 1 } },
		{ "jump 1 -> 5 -> 2 -> 4 -> 1 -> 3", houses[6], { 1, 5, 2, 4, 1, 3 } },
	}
	for _, path in paths do
		local label, house, sequence = path[1], path[2], path[3]
		for _, count in sequence do
			HouseBuilder.setFloors(house, count, Random.new(count))
			adv(0.1)
			local extra, missing = diff(reference[count], signature(house))
			if #extra > 0 or #missing > 0 then
				mismatches += 1
				print(string.format("   T8 %s: at floors=%d the house differs from the grown one: %d extra, %d missing", label, count, #extra, #missing))
				for i = 1, math.min(#extra, 4) do print("        extra   " .. extra[i]) end
				for i = 1, math.min(#missing, 4) do print("        missing " .. missing[i]) end
			end
		end
	end
	check("T8 the tower looks the same whatever way its floor count was reached (grow, shrink, jump)", mismatches == 0, mismatches .. " mismatch(es)")

	---------------------------------------------------------------------------
	-- self-test: the audit must SEE holes that are cut into a clean tower on purpose (house 7, which nothing above touched)
	---------------------------------------------------------------------------
	do
		-- the ray tests understand WedgeParts (a fix may well build the gable from wedges): a unit wedge, slope rising towards +z
		local wedge = { Kind = "box", Wedge = true, cx = 0, cy = 0, cz = 0, r1 = 1, r2 = 0, r3 = 0, r4 = 0, r5 = 1, r6 = 0, r7 = 0, r8 = 0, r9 = 1, hx = 1, hy = 1, hz = 1 }
		local down1, down2 = hitPart(wedge, 0, 5, 0.9, 0, -1, 0), hitPart(wedge, 0, 5, -0.9, 0, -1, 0)
		local along, over = hitPart(wedge, 0, 0.5, -5, 0, 0, 1), hitPart(wedge, 0, 0.5, 5, 0, 0, -1)
		check("self-test: the ray cast treats a WedgePart as a wedge (slope rises towards +z)", down1 and down2 and along and over and math.abs(down1 - 4.1) < 1e-6 and math.abs(down2 - 5.9) < 1e-6 and math.abs(along - 5.5) < 1e-6 and math.abs(over - 4) < 1e-6, string.format("%s %s %s %s", tostring(down1), tostring(down2), tostring(along), tostring(over)))
	end
	do
		local house = houses[7]
		local function build(count)
			HouseBuilder.setFloors(house, 1, Random.new(1))
			HouseBuilder.setFloors(house, count, Random.new(count))
			adv(0.1)
		end
		-- destroys every part called `name` (on floor `floor` when given) whose centre satisfies `where` (local x, y, z)
		local function cut(floor, name, where)
			local n = 0
			for _, d in M.descendants(house.Tower) do
				local data = RawData[d]
				if data.Name == name and data.Props and data.Props.CFrame then
					local node, top = d, nil
					while node and node ~= house.Tower do top = RawData[node].Name node = RawData[node].Parent end
					local lc = house.CFrame:ToObjectSpace(data.Props.CFrame)
					if (not floor or string.find(top or "", "Floor" .. floor .. "_", 1, true)) and (not where or where(lc.X, lc.Y, lc.Z)) then
						d:Destroy()
						n += 1
					end
				end
			end
			return n
		end
		local function run()
			local saved = totals
			resetTotals()
			quiet = true
			auditHouse(house, house.FloorCount)
			local got = totals
			totals = saved
			quiet = false
			return got
		end
		build(3)
		local clean = run()
		check("self-test: the audit finds nothing in a clean 3-floor tower (T1, T2, T3, T6, T7, T10, T12)", clean.T1 + clean.T2 + clean.T3v + clean.T3c + clean.T6 + clean.T7 + clean.T10 + clean.T12 == 0, string.format("T1 %d T2 %d T3v %d T3c %d T6 %d T7 %d T10 %d T12 %d", clean.T1, clean.T2, clean.T3v, clean.T3c, clean.T6, clean.T7, clean.T10, clean.T12))
		build(3)
		local n = cut(2, "WallPier", function(x) return x < -20 end)
		local got = run()
		check("self-test: a missing wall pier of floor 2 (left side) is reported by T1 and T10", n > 0 and got.T1 > 0 and got.T10 > 0, string.format("cut %d, T1 %d, T10 %d", n, got.T1, got.T10))
		build(3)
		-- (the floor of an upper storey is two layers: the slab and the collidable floor surface on it; a floor you can fall through is both gone)
		n = cut(3, "Slab") + cut(3, "FloorSurface")
		got = run()
		check("self-test: a missing slab with its floor surface (ceiling of floor 2, floor of floor 3) is reported by T2 and T3c", n > 0 and got.T2 > 0 and got.T3c > 0, string.format("cut %d, T2 %d, T3c %d", n, got.T2, got.T3c))
		build(3)
		n = cut(3, "Slab")
		got = run()
		check("self-test: a missing slab under an intact floor surface is reported by T2 only (you can still stand on the floor surface)", n > 0 and got.T2 > 0 and got.T3c == 0, string.format("cut %d, T2 %d, T3c %d", n, got.T2, got.T3c))
		build(2)
		n = cut(nil, "RoofSlab")
		got = run()
		check("self-test: a missing roof slab is reported by T2 and T6", n > 0 and got.T2 > 0 and got.T6 > 0, string.format("cut %d, T2 %d, T6 %d", n, got.T2, got.T6))
		build(2)
		n = cut(1, "FrontLower", function(x) return x < -8 end) + cut(1, "Glass", function(x) return x < -8 end) + cut(1, "FrontUpper", function(x) return x < -8 end)
		got = run()
		check("self-test: a missing front wall (floor 1, left of the door) is reported by T1", n > 0 and got.T1 > 0, string.format("cut %d, T1 %d", n, got.T1))
		build(2)
		n = cut(1, "Foundation") + cut(1, "Floor")
		got = run()
		check("self-test: a missing ground floor (floor + foundation) is reported by T3v and T3c", n > 0 and got.T3v > 0 and got.T3c > 0, string.format("cut %d, T3v %d, T3c %d", n, got.T3v, got.T3c))
		build(1)
		n = cut(nil, "Gable", function(x, y, z) return z < 30 end)
		got = run()
		check("self-test: a missing front gable (one-floor house) is reported by T11", n > 0 and got.T11 > 0, string.format("cut %d, T11 %d", n, got.T11))
	end

	print(string.format("\nPASS %d  FAIL %d", results.pass, results.fail))
end)
