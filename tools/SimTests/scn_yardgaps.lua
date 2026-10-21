-- Yard boundary audit: the hedge + picket-fence ring around every lot must be closed (except the gate opening), in every house
-- (1-8, north AND south row, all in the house-local frame), at every floor count, joined without gaps or clipping, with nothing
-- sticking through it, a lawn under the whole lot and no two ground slabs in the same plane. Runs on the REAL builders.
-- (The existing audits scn_houses / scn_audit compare pieces with each other; none of them looks at the PERIMETER, so a hole
-- between two runs of the boundary - the front corners of every lot - passed them all.)
local results = { pass = 0, fail = 0 }
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end
local adv = M.Sim.advance

local GAP = 0.6 -- an uncovered stretch of the boundary longer than this is a hole
local GATE_HALF = 9 -- the intended opening of the front fence: |x| <= 9 (the gate pylons stand at x = +-7.4)
local CHAR_RADIUS = 1.0 -- a Roblox character is 2 studs wide: a gap narrower than 2 studs cannot be walked through
local MAX_BURY = 0.25 -- a picket / rail may touch a hedge bush, but not stick more than this far into it
local CELL = 0.25
local RAIL_HEIGHTS = { 1.2, 2.7 } -- the heights of the two fence rails: a visible boundary has to be there at both

task.spawn(function()
	M.isServer = true
	local mainServer = find("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	adv(3)
	local HouseSystem = require(find("ServerScriptService.Systems.HouseSystem"))
	local HouseBuilder = require(find("ServerScriptService.Systems.WorldBuilder.HouseBuilder"))
	local WorldLayout = require(find("ReplicatedStorage.Modules.WorldLayout"))

	local half = WorldLayout.LotHalfWidth
	local depth = WorldLayout.LotDepth
	local lineX = half - 0.5 -- the hedge / fence centre line (Yard.luau: P(+-(half - 0.5), ...), z = depth - 0.5 at the back)
	local lineZ = depth - 0.5

	---------------------------------------------------------------------------
	-- parts in the house-local frame
	---------------------------------------------------------------------------
	local function describe(inst, houseCFrame)
		local data = RawData[inst]
		local props = data.Props
		local lc = houseCFrame:ToObjectSpace(props.CFrame)
		local r = lc.r
		local size = props.Size
		local shape = if props.Shape then props.Shape.Name else "Block"
		local ellipsoid = shape == "Ball"
		for _, child in data.Children do
			local mesh = RawData[child]
			if mesh.ClassName == "SpecialMesh" and mesh.Props.MeshType and mesh.Props.MeshType.Name == "Sphere" then
				ellipsoid = true
			end
		end
		local axes = { { r[1], r[4], r[7] }, { r[2], r[5], r[8] }, { r[3], r[6], r[9] } }
		local halves = { size.X / 2, size.Y / 2, size.Z / 2 }
		local min, max = { 0, 0, 0 }, { 0, 0, 0 }
		local center = { lc.X, lc.Y, lc.Z }
		for k = 1, 3 do
			local extent = 0
			for i = 1, 3 do extent += math.abs(axes[i][k]) * halves[i] end
			min[k], max[k] = center[k] - extent, center[k] + extent
		end
		local parentData = RawData[data.Parent]
		return {
			Inst = inst,
			Name = data.Name,
			Group = parentData and parentData.Name or "?",
			C = center, A = axes, H = halves, Min = min, Max = max,
			Ellipsoid = ellipsoid, -- looks like an ellipsoid (sphere mesh or Shape Ball)
			BallCollider = shape == "Ball", -- collides like one (a SpecialMesh sphere still collides as its bounding box)
			Shape = shape,
			Solid = props.CanCollide ~= false,
			Transparency = props.Transparency or 0,
			ColorKey = if props.Color then string.format("%.3f,%.3f,%.3f", props.Color.R, props.Color.G, props.Color.B) else "?",
			Material = if props.Material then props.Material.Name else "Plastic",
		}
	end

	local function collect(house)
		local parts = {}
		for _, d in M.descendants(house.Model) do
			local data = RawData[d]
			if data.Props and data.Props.Size and data.Props.CFrame and M.InstanceMethods.IsA(d, "BasePart") and data.Props.Anchored then
				table.insert(parts, describe(d, house.CFrame))
			end
		end
		return parts
	end

	local function world(house, x, z)
		local p = house.CFrame:PointToWorldSpace(Vector3.new(x, 0, z))
		return string.format("world (%.1f, %.1f)", p.X, p.Z)
	end

	---------------------------------------------------------------------------
	-- coverage of a boundary line: which stretch of the line (at a height) is inside some part
	---------------------------------------------------------------------------
	-- Intersection of the line  p(t) = (px + dx t, y, pz + dz t), t in [0, L]  with the part (box or ellipsoid), as {t0, t1} or nil.
	local function lineInterval(part, y, px, pz, dx, dz, L, asEllipsoid)
		local ox, oy, oz = px - part.C[1], y - part.C[2], pz - part.C[3]
		local lo, hi = 0, L
		if asEllipsoid then
			local a, b, c = 0, 0, -1
			for i = 1, 3 do
				local axis, h = part.A[i], part.H[i]
				local q0 = (ox * axis[1] + oy * axis[2] + oz * axis[3]) / h
				local qd = (dx * axis[1] + dz * axis[3]) / h
				a += qd * qd
				b += 2 * q0 * qd
				c += q0 * q0
			end
			if a < 1e-12 then return nil end
			local disc = b * b - 4 * a * c
			if disc < 0 then return nil end
			local root = math.sqrt(disc)
			lo, hi = math.max(lo, (-b - root) / (2 * a)), math.min(hi, (-b + root) / (2 * a))
		else
			for i = 1, 3 do
				local axis, h = part.A[i], part.H[i]
				local q0 = ox * axis[1] + oy * axis[2] + oz * axis[3]
				local qd = dx * axis[1] + dz * axis[3]
				if math.abs(qd) < 1e-9 then
					if math.abs(q0) > h + 1e-6 then return nil end
				else
					local t1, t2 = (-h - q0) / qd, (h - q0) / qd
					if t1 > t2 then t1, t2 = t2, t1 end
					lo, hi = math.max(lo, t1), math.min(hi, t2)
				end
			end
		end
		if hi < lo - 1e-9 then return nil end
		return { lo, hi }
	end

	-- the stretches of [0, L] that no interval covers, minus `exempt` ({a, b} list)
	local function uncovered(intervals, L, exempt)
		table.sort(intervals, function(a, b) return a[1] < b[1] end)
		local gaps = {}
		local cursor = 0
		for _, iv in intervals do
			if iv[1] > cursor + 1e-6 then table.insert(gaps, { cursor, math.min(iv[1], L) }) end
			cursor = math.max(cursor, iv[2])
		end
		if cursor < L - 1e-6 then table.insert(gaps, { cursor, L }) end
		local result = {}
		for _, gap in gaps do
			local pieces = { gap }
			for _, ex in exempt or {} do
				local nextPieces = {}
				for _, piece in pieces do
					if ex[2] <= piece[1] or ex[1] >= piece[2] then
						table.insert(nextPieces, piece)
					else
						if ex[1] > piece[1] then table.insert(nextPieces, { piece[1], ex[1] }) end
						if ex[2] < piece[2] then table.insert(nextPieces, { ex[2], piece[2] }) end
					end
				end
				pieces = nextPieces
			end
			for _, piece in pieces do
				if piece[2] - piece[1] > 1e-6 then table.insert(result, piece) end
			end
		end
		return result
	end

	-- the four edges of the boundary ring (local frame). t runs along the edge from `p0` in direction `d`.
	local EDGES = {
		{ Name = "front (z=0)", P0 = { -lineX, 0 }, D = { 1, 0 }, L = lineX * 2, Gate = { lineX - GATE_HALF, lineX + GATE_HALF } },
		{ Name = "right (x=+" .. lineX .. ")", P0 = { lineX, 0 }, D = { 0, 1 }, L = lineZ },
		{ Name = "back (z=" .. lineZ .. ")", P0 = { -lineX, lineZ }, D = { 1, 0 }, L = lineX * 2 },
		{ Name = "left (x=-" .. lineX .. ")", P0 = { -lineX, 0 }, D = { 0, 1 }, L = lineZ },
	}
	local function edgePoint(edge, t)
		return edge.P0[1] + edge.D[1] * t, edge.P0[2] + edge.D[2] * t
	end

	-- uncovered stretches of one edge. layer "visible": a visible part (hedge bush / rail / picket / pylon) at BOTH rail heights;
	-- layer "solid": something a character bumps into (CanCollide, as Roblox collides it) at belly height.
	local function edgeGaps(parts, edge, layer)
		local heights = if layer == "visible" then RAIL_HEIGHTS else { 1.0 }
		local gapsAtHeight = {}
		for _, y in heights do
			local intervals = {}
			for _, part in parts do
				local eligible
				if layer == "visible" then
					eligible = part.Transparency < 0.5 and part.Name ~= "Lawn" and part.Name ~= "Barrier" and (part.Name == "Hedge" or part.Name == "Picket" or part.Name == "RailTop" or part.Name == "RailLow" or part.Name == "GatePylon")
				else
					eligible = part.Solid
				end
				if eligible then
					local iv = lineInterval(part, y, edge.P0[1], edge.P0[2], edge.D[1], edge.D[2], edge.L, if layer == "visible" then part.Ellipsoid else part.BallCollider)
					if iv then table.insert(intervals, iv) end
				end
			end
			for _, gap in uncovered(intervals, edge.L, if edge.Gate then { edge.Gate } else nil) do
				table.insert(gapsAtHeight, { gap[1], gap[2], y })
			end
		end
		-- merge the gaps of the different heights (a hole at any height counts)
		table.sort(gapsAtHeight, function(a, b) return a[1] < b[1] end)
		local merged = {}
		for _, gap in gapsAtHeight do
			local last = merged[#merged]
			if last and gap[1] <= last[2] + 1e-6 then
				last[2] = math.max(last[2], gap[2])
			else
				table.insert(merged, { gap[1], gap[2] })
			end
		end
		return merged
	end

	---------------------------------------------------------------------------
	-- walk-through test: can a 2-stud character get from the street into the lot other than through the gate?
	---------------------------------------------------------------------------
	local X0, X1, Z0, Z1 = -half - 14, half + 14, -12, depth + 14
	local NX, NZ = math.ceil((X1 - X0) / CELL), math.ceil((Z1 - Z0) / CELL)
	local function leaks(parts)
		local blocked = table.create(NX * NZ, false)
		local function mark(part, inflate)
			local ix0 = math.max(1, math.floor((part.Min[1] - inflate - X0) / CELL))
			local ix1 = math.min(NX, math.ceil((part.Max[1] + inflate - X0) / CELL) + 1)
			local iz0 = math.max(1, math.floor((part.Min[3] - inflate - Z0) / CELL))
			local iz1 = math.min(NZ, math.ceil((part.Max[3] + inflate - Z0) / CELL) + 1)
			for ix = ix0, ix1 do
				local cx = X0 + (ix - 0.5) * CELL
				for iz = iz0, iz1 do
					local cz = Z0 + (iz - 0.5) * CELL
					local inside = true
					for i = 1, 3 do
						local axis = part.A[i]
						-- the footprint test: only the horizontal part of the axes counts (all yard parts are upright)
						if math.abs(axis[2]) < 0.5 then
							local q = (cx - part.C[1]) * axis[1] + (cz - part.C[3]) * axis[3]
							if math.abs(q) > part.H[i] + inflate then inside = false break end
						end
					end
					if inside then blocked[(iz - 1) * NX + ix] = true end
				end
			end
		end
		for _, part in parts do
			-- something that stops a walking character: collides, taller than a step (2 studs), starts below head height
			if part.Solid and part.Max[2] > 2 and part.Min[2] < 4.5 then
				mark(part, CHAR_RADIUS)
			end
		end
		-- the intended entrance (between the gate pylons) counts as closed: what is left is a leak
		mark({ Min = { -6.5, 0, -0.3 }, Max = { 6.5, 4, 0.3 }, C = { 0, 2, 0 }, A = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }, H = { 6.5, 2, 0.3 } }, CHAR_RADIUS)
		local function cellOf(x, z) return math.floor((x - X0) / CELL) + 1, math.floor((z - Z0) / CELL) + 1 end
		local sx, sz = cellOf(-half - 8, -6)
		local seen = table.create(NX * NZ, 0)
		local queue = { (sz - 1) * NX + sx }
		seen[queue[1]] = -1
		local head = 1
		local leakCell
		while head <= #queue do
			local index = queue[head]
			head += 1
			local ix = (index - 1) % NX + 1
			local iz = (index - 1) // NX + 1
			local x, z = X0 + (ix - 0.5) * CELL, Z0 + (iz - 0.5) * CELL
			if not leakCell and math.abs(x) < half - 3 and z > 2 and z < depth - 3 then leakCell = index end
			for _, step in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
				local jx, jz = ix + step[1], iz + step[2]
				if jx >= 1 and jx <= NX and jz >= 1 and jz <= NZ then
					local j = (jz - 1) * NX + jx
					if seen[j] == 0 and not blocked[j] then
						seen[j] = index
						table.insert(queue, j)
					end
				end
			end
		end
		if not leakCell then return nil end
		-- walk back along the path to the street and report the first cell inside the lot rectangle
		local path = {}
		local cursor = leakCell
		while cursor ~= -1 and cursor ~= 0 do
			local ix = (cursor - 1) % NX + 1
			local iz = (cursor - 1) // NX + 1
			table.insert(path, { X0 + (ix - 0.5) * CELL, Z0 + (iz - 0.5) * CELL })
			cursor = seen[cursor]
		end
		local entry = path[1]
		for index = #path, 1, -1 do
			local point = path[index]
			if point[2] >= 0 and math.abs(point[1]) <= lineX then entry = point break end
		end
		return entry, #queue
	end

	-- every uncovered stretch longer than GAP of the four edges, both layers. Gaps within GAP of a corner count as touching it (the
	-- end picket / rail of the neighbouring run covers the first half stud of the edge itself).
	local function ringProblems(house, parts)
		local problems = {}
		for edgeIndex, edge in EDGES do
			for _, layer in { "visible", "solid" } do
				for _, gap in edgeGaps(parts, edge, layer) do
					if gap[2] - gap[1] > GAP then
						local ax, az = edgePoint(edge, gap[1])
						local bx, bz = edgePoint(edge, gap[2])
						table.insert(problems, { Edge = edgeIndex, Layer = layer, Length = gap[2] - gap[1], A = { ax, az }, B = { bx, bz }, AtStart = gap[1] < GAP, AtEnd = gap[2] > edge.L - GAP })
					end
				end
			end
		end
		return problems
	end
	local function describeProblem(house, problem)
		local notes = {}
		if problem.AtStart then table.insert(notes, string.format("starts at the corner (%.1f, %.1f)", problem.A[1], problem.A[2])) end
		if problem.AtEnd then table.insert(notes, string.format("ends at the corner (%.1f, %.1f)", problem.B[1], problem.B[2])) end
		return string.format("house %d  %s edge, %s layer: open %.2f studs from local (%.2f, %.2f) to (%.2f, %.2f)  [%s -> %s] %s", house.Index, EDGES[problem.Edge].Name, problem.Layer, problem.Length, problem.A[1], problem.A[2], problem.B[1], problem.B[2], world(house, problem.A[1], problem.A[2]), world(house, problem.B[1], problem.B[2]), table.concat(notes, ", "))
	end

	-- How deep (studs) does `part` (a box, cylinder or ball) sink into `other`? Samples the part and measures the deepest sample that lies
	-- inside `other`: a hedge bush (ellipsoid: depth to its surface along the smallest radius) or a fence part (box: depth to its nearest face).
	-- Touching is 0; a picket that stands IN a bush, or a pond bank that reaches into one, is a clip.
	local function sinkDepth(part, other, otherIsEllipsoid)
		for k = 1, 3 do
			if part.Max[k] < other.Min[k] or part.Min[k] > other.Max[k] then return 0 end
		end
		local steps = {}
		for i = 1, 3 do steps[i] = math.max(2, math.min(60, math.ceil(part.H[i] * 2 / 0.25))) end
		local radius = math.min(other.H[1], other.H[2], other.H[3])
		local deepest = 0
		for a = 0, steps[1] do
			local ua = (a / steps[1] * 2 - 1) * part.H[1]
			for b = 0, steps[2] do
				local ub = (b / steps[2] * 2 - 1) * part.H[2]
				for c = 0, steps[3] do
					local uc = (c / steps[3] * 2 - 1) * part.H[3]
					-- (a cylinder's axis is its local X: samples outside its round section are not part of it; a ball is round all over)
					local round = (ub / part.H[2]) ^ 2 + (uc / part.H[3]) ^ 2
					local inside = if part.Ellipsoid then round + (ua / part.H[1]) ^ 2 <= 1 elseif part.Shape == "Cylinder" then round <= 1 else true
					if inside then
						local norm, face = 0, math.huge
						for i = 1, 3 do
							local q = 0
							for k = 1, 3 do
								local p = part.C[k] + part.A[1][k] * ua + part.A[2][k] * ub + part.A[3][k] * uc
								q += (p - other.C[k]) * other.A[i][k]
							end
							norm += (q / other.H[i]) ^ 2
							face = math.min(face, other.H[i] - math.abs(q))
						end
						if otherIsEllipsoid then
							if norm < 1 then deepest = math.max(deepest, (1 - math.sqrt(norm)) * radius) end
						elseif face > 0 then
							deepest = math.max(deepest, face)
						end
					end
				end
			end
		end
		return deepest
	end

	---------------------------------------------------------------------------
	-- run over all houses
	---------------------------------------------------------------------------
	local houses = HouseSystem.all()
	local visibleGapLines, solidGapLines, cornerLines, backCornerLines, leakLines, clipLines, buryLines = {}, {}, {}, {}, {}, {}, {}
	local houseParts = {}
	for _, house in houses do
		HouseBuilder.setFloors(house, 1, Random.new(1))
		adv(0.2)
		local parts = collect(house)
		houseParts[house.Index] = parts

		for _, problem in ringProblems(house, parts) do
			local line = describeProblem(house, problem)
			table.insert(if problem.Layer == "visible" then visibleGapLines else solidGapLines, line)
			if problem.AtStart or problem.AtEnd then table.insert(cornerLines, line) end
			if problem.Edge == 3 and (problem.AtStart or problem.AtEnd) or (problem.Edge == 2 or problem.Edge == 4) and problem.AtEnd then table.insert(backCornerLines, line) end
		end

		-- hedge / fence clipping at the joints: a fence part must not stick out through the far side of a hedge bush,
		-- and a hedge bush must not stick out in front of the fence line (the street side)
		for _, part in parts do
			if part.Group == "Fence" and (part.Name == "Picket" or part.Name == "RailTop" or part.Name == "RailLow") then
				if part.Max[1] > lineX + 0.35 or part.Min[1] < -lineX - 0.35 then
					table.insert(clipLines, string.format("house %d fence %s sticks out of the hedge line: local x %.2f .. %.2f (hedge centre line %.1f)", house.Index, part.Name, part.Min[1], part.Max[1], lineX))
				end
			end
			if part.Group == "Hedge" and part.Name == "Hedge" and part.Min[3] < -0.6 then
				table.insert(clipLines, string.format("house %d hedge bush sticks out in front of the fence line: local z min %.2f at x %.2f", house.Index, part.Min[3], part.C[1]))
			end
		end

		for _, part in parts do
			if part.Group == "Fence" and (part.Name == "Picket" or part.Name == "RailTop" or part.Name == "RailLow") then
				for _, bush in parts do
					if bush.Group == "Hedge" and bush.Name == "Hedge" then
						local depth = sinkDepth(part, bush, true)
						if depth > MAX_BURY then
							table.insert(buryLines, string.format("house %d fence %s at local (%.1f, %.1f) sticks %.2f studs into the hedge bush at local (%.1f, %.1f)", house.Index, part.Name, part.C[1], part.C[3], depth, bush.C[1], bush.C[3]))
						end
					end
				end
			end
		end

		local entry, reachable = leaks(parts)
		if entry then
			table.insert(leakLines, string.format("house %d: a 2-stud character walks from the street into the lot without using the gate, first cell inside the lot rectangle: local (%.1f, %.1f) = %s  (%d cells reachable)", house.Index, entry[1], entry[2], world(house, entry[1], entry[2]), reachable))
		end
	end

	local function show(lines, limit)
		for i = 1, math.min(#lines, limit or 40) do print("   ", lines[i]) end
		if #lines > (limit or 40) then print("   ... and " .. (#lines - (limit or 40)) .. " more") end
	end
	check(string.format("1. every house (1-8): the VISIBLE hedge/fence ring has no hole longer than %.1f studs (gate opening |x| <= %d excepted)", GAP, GATE_HALF), #visibleGapLines == 0, #visibleGapLines .. " holes")
	show(visibleGapLines)
	check(string.format("2. every house (1-8): the SOLID barrier ring (what blocks a character) has no hole longer than %.1f studs", GAP), #solidGapLines == 0, #solidGapLines .. " holes")
	show(solidGapLines)
	check("3. every house: hedge and fence meet at all four corners (no run ends short of the corner)", #cornerLines == 0, #cornerLines .. " open corner ends")
	show(cornerLines, 16)
	check("4. every house: a 2-stud character cannot walk from the street into the lot except through the gate", #leakLines == 0, #leakLines .. " houses leak")
	show(leakLines)
	-- the yard is built once, but the tower grows around it with every rebirth: the ring must stay closed (and nothing of the tower may
	-- open or block it) at every floor count, in the north row and in the south row
	do
		local lines = {}
		for _, index in { 1, 5 } do
			local house = houses[index]
			for count = 2, 5 do
				HouseBuilder.setFloors(house, count, Random.new(count))
				adv(0.2)
				local parts = collect(house)
				for _, problem in ringProblems(house, parts) do table.insert(lines, string.format("floors %d: %s", count, describeProblem(house, problem))) end
				local entry = leaks(parts)
				if entry then table.insert(lines, string.format("house %d floors %d: a character walks into the lot at local (%.1f, %.1f)", index, count, entry[1], entry[2])) end
			end
			HouseBuilder.setFloors(house, 1, Random.new(1))
		end
		adv(0.2)
		check("4b. houses 1 and 5 with 2, 3, 4 and 5 floors: the ring is as closed as with 1 floor (no hole, no walk-through)", #lines == 0, #lines .. " problems")
		show(lines, 12)
	end

	check("5. every house: hedge and fence do not clip through each other at the joints (no fence part past the hedge line, no bush in front of the fence)", #clipLines == 0, #clipLines .. " clips")
	show(clipLines)
	check(string.format("5b. every house: no picket / rail is buried more than %.2f stud in a hedge bush (the fence ends AT the hedge, it does not stick through it)", MAX_BURY), #buryLines == 0, #buryLines .. " buried")
	show(buryLines)

	check("6. the back hedge meets both side hedges (no run of the back corners ends short of the corner, visible and solid)", #backCornerLines == 0, #backCornerLines)
	show(backCornerLines)

	---------------------------------------------------------------------------
	-- nothing stands in / sticks through the hedge and fence line (all floor counts)
	---------------------------------------------------------------------------
	do
		local bands = {
			{ Name = "left hedge", Min = { -lineX - 1.3, 0 }, Max = { -lineX + 1.3, depth + 5 } },
			{ Name = "right hedge", Min = { lineX - 1.3, 0 }, Max = { lineX + 1.3, depth + 5 } },
			{ Name = "back hedge", Min = { -lineX - 1.3, lineZ - 1.3 }, Max = { lineX + 1.3, lineZ + 1.3 } },
			{ Name = "front fence left", Min = { -lineX - 1.3, -0.55 }, Max = { -GATE_HALF, 0.55 } },
			{ Name = "front fence right", Min = { GATE_HALF, -0.55 }, Max = { lineX + 1.3, 0.55 } },
		}
		local solidHits, foliageNotes = {}, {}
		local seenHits = {}
		for _, index in { 1, 2, 5, 8 } do
			local house = houses[index]
			for count = 1, 5 do
				HouseBuilder.setFloors(house, count, Random.new(count))
				adv(0.2)
				local all = collect(house)
				local boundary = {}
				for _, part in all do
					if (part.Group == "Hedge" and part.Name == "Hedge") or (part.Group == "Fence" and (part.Name == "Picket" or part.Name == "RailTop" or part.Name == "RailLow")) then
						table.insert(boundary, part)
					end
				end
				for _, part in all do
					local isBoundary = part.Group == "Hedge" or part.Group == "Fence"
					local flat = part.Max[2] < 0.3
					if not isBoundary and not flat and part.Min[2] < 4.7 and part.Transparency < 0.9 then
						-- (first the cheap bounding-box test against the hedge / fence bands, then the real shapes: a bush is an ellipsoid,
						-- so a flat ring at ground level that reaches into the band does not touch the bush)
						for _, band in bands do
							local ox = math.min(part.Max[1], band.Max[1]) - math.max(part.Min[1], band.Min[1])
							local oz = math.min(part.Max[3], band.Max[2]) - math.max(part.Min[3], band.Min[2])
							if ox > 0.1 and oz > 0.1 then
								local sunk, into = 0, nil
								for _, other in boundary do
									local depth = sinkDepth(part, other, other.Group == "Hedge")
									if depth > sunk then sunk, into = depth, other end
								end
								local key = string.format("%d|%s|%s|%.1f|%.1f", index, part.Group .. "/" .. part.Name, band.Name, part.C[1], part.C[3])
								if sunk > MAX_BURY and not seenHits[key] then
									seenHits[key] = true
									local line = string.format("house %d (floors %d) %s/%s at local (%.1f, %.1f), y %.1f..%.1f sinks %.2f studs into the %s (%s at local (%.1f, %.1f))", index, count, part.Group, part.Name, part.C[1], part.C[3], part.Min[2], part.Max[2], sunk, band.Name, into.Name, into.C[1], into.C[3])
									table.insert(if part.Material == "Grass" then foliageNotes else solidHits, line)
								end
							end
						end
					end
				end
			end
		end
		check("7. nothing solid (altar, mailbox, sign, bench, lamp, pond, tower part) stands in or sinks into the hedge/fence line (houses 1,2,5,8 x floors 1-5)", #solidHits == 0, #solidHits)
		show(solidHits)
		print("   (info: foliage (tree crowns) that leans into the hedge, harmless: " .. #foliageNotes .. ")")
		show(foliageNotes, 4)
		for _, house in { houses[1], houses[2], houses[5], houses[8] } do HouseBuilder.setFloors(house, 1, Random.new(1)) end
		adv(0.2)
	end

	---------------------------------------------------------------------------
	-- the lawn, the ground slabs, the neighbour lots
	---------------------------------------------------------------------------
	do
		local bad = {}
		for _, house in houses do
			local lawn
			for _, part in houseParts[house.Index] do
				if part.Name == "Lawn" then lawn = part end
			end
			if not lawn then
				table.insert(bad, "house " .. house.Index .. ": no Lawn")
			elseif lawn.Min[1] > -half + 1e-3 or lawn.Max[1] < half - 1e-3 or lawn.Min[3] > 1e-3 or lawn.Max[3] < depth - 1e-3 then
				table.insert(bad, string.format("house %d: Lawn covers x %.1f..%.1f z %.1f..%.1f, the lot is x +-%d z 0..%d", house.Index, lawn.Min[1], lawn.Max[1], lawn.Min[3], lawn.Max[3], half, depth))
			end
		end
		check("8. the Lawn part covers the whole lot rectangle of every house (no bare ground inside the hedge ring)", #bad == 0, #bad)
		show(bad)
	end

	do
		-- ground-level slabs (flat top below 1 stud, visible) that lie in the SAME plane and overlap, with a different colour or material:
		-- they z-fight (flicker). The house's own parts plus the Environment slabs near it (promenade, gate path, grass patches).
		local function flatTop(part)
			if part.Ellipsoid or part.Transparency > 0.5 or part.Shape == "Ball" then return nil end
			for i = 1, 3 do
				if math.abs(part.A[i][2]) > 0.999 then
					if part.Shape == "Cylinder" and i ~= 1 then return nil end
					return part.C[2] + part.H[i]
				end
			end
			return nil
		end
		local environmentParts = {}
		local environment = workspace:FindFirstChild("Environment")
		if environment then
			for _, name in { "Promenades", "GrassPatches" } do
				local folder = environment:FindFirstChild(name)
				if folder then
					for _, d in M.descendants(folder) do
						if RawData[d].Props and RawData[d].Props.Size and M.InstanceMethods.IsA(d, "BasePart") then table.insert(environmentParts, d) end
					end
				end
			end
		end
		local fights, near = {}, {}
		local seenKinds = {}
		for _, house in houses do
			local flats = {}
			local function add(part, source)
				local top = flatTop(part)
				if top and top < 1.0 and part.Min[2] < 0.7 then table.insert(flats, { Part = part, Top = top, Label = source .. "/" .. part.Name }) end
			end
			for _, part in houseParts[house.Index] do add(part, part.Group) end
			for _, d in environmentParts do
				local part = describe(d, house.CFrame)
				if part.Max[1] > -half - 12 and part.Min[1] < half + 12 and part.Max[3] > -12 and part.Min[3] < depth + 12 then add(part, "Environment") end
			end
			local lawn
			for _, part in houseParts[house.Index] do
				if part.Name == "Lawn" then lawn = part end
			end
			for i = 1, #flats do
				for j = i + 1, #flats do
					local a, b = flats[i], flats[j]
					local x0, x1 = math.max(a.Part.Min[1], b.Part.Min[1]), math.min(a.Part.Max[1], b.Part.Max[1])
					local z0, z1 = math.max(a.Part.Min[3], b.Part.Min[3]), math.min(a.Part.Max[3], b.Part.Max[3])
					local ox, oz = x1 - x0, z1 - z0
					local different = a.Part.ColorKey ~= b.Part.ColorKey or a.Part.Material ~= b.Part.Material
					-- (a pair that lies completely under the lawn cannot be seen)
					local underLawn = lawn ~= nil and lawn.Max[2] > math.max(a.Top, b.Top) + 0.02 and x0 >= lawn.Min[1] and x1 <= lawn.Max[1] and z0 >= lawn.Min[3] and z1 <= lawn.Max[3]
					if ox > 0.2 and oz > 0.2 and different and not underLawn then
						local delta = math.abs(a.Top - b.Top)
						local names = { a.Label, b.Label }
						table.sort(names)
						local key = string.format("%s | %s | %.3f", names[1], names[2], delta)
						if delta < 0.05 then
							local entry = seenKinds[key]
							if not entry then
								entry = { Houses = {}, Delta = delta, Text = string.format("%s and %s: tops y=%.3f / %.3f (diff %.3f), overlap %.1f x %.1f studs at local x %.1f..%.1f z %.1f..%.1f", a.Label, b.Label, a.Top, b.Top, delta, ox, oz, math.max(a.Part.Min[1], b.Part.Min[1]), math.min(a.Part.Max[1], b.Part.Max[1]), math.max(a.Part.Min[3], b.Part.Min[3]), math.min(a.Part.Max[3], b.Part.Max[3])) }
								seenKinds[key] = entry
								table.insert(if delta < 0.015 then fights else near, entry)
							end
							if entry.Houses[#entry.Houses] ~= house.Index then table.insert(entry.Houses, house.Index) end
						end
					end
				end
			end
		end
		local function listKinds(kinds, limit)
			table.sort(kinds, function(a, b) return a.Text < b.Text end)
			for i = 1, math.min(#kinds, limit) do print("   ", kinds[i].Text, "(houses " .. table.concat(kinds[i].Houses, ",") .. ")") end
			if #kinds > limit then print("   ... and " .. (#kinds - limit) .. " more kinds") end
		end
		local yardFights, otherFights = {}, {}
		for _, kind in fights do
			if string.find(kind.Text, "^Environment/Patch and Environment/Patch") then
				-- (the grass patches are checked over the whole map in 9c)
			else
				table.insert(if string.find(kind.Text, "^Yard/") or string.find(kind.Text, " and Yard/") then yardFights else otherFights, kind)
			end
		end
		check("9a. no two ground slabs of the YARD (lawn, driveway, apron, steps, altar, pond ...) lie in the same plane and overlap (z-fighting)", #yardFights == 0, #yardFights .. " kinds of pairs")
		listKinds(yardFights, 12)
		check("9b. no two ground slabs of the TOWER ENTRANCE / interior / environment (foundation, step, grass patches ...) lie in the same plane and overlap", #otherFights == 0, #otherFights .. " kinds of pairs")
		listKinds(otherFights, 12)
		print("   (info: slabs of a different colour less than 0.05 stud apart, may flicker at a distance: " .. #near .. " kinds)")
		listKinds(near, 14)

		-- the soft grass patches of the whole Environment are cylinders with all the same top: where a light and a dark one overlap they
		-- lie in one plane and flicker (z-fighting), anywhere on the lawn
		local patches = {}
		local patchFolder = environment and environment:FindFirstChild("GrassPatches")
		if patchFolder then
			for _, d in patchFolder:GetChildren() do
				local data = RawData[d]
				if data.Props and data.Props.Size and M.InstanceMethods.IsA(d, "BasePart") then
					local c = data.Props.CFrame
					local color = data.Props.Color
					table.insert(patches, { X = c.X, Z = c.Z, Top = c.Y + data.Props.Size.X / 2, R = data.Props.Size.Y / 2, Color = string.format("%.3f,%.3f,%.3f", color.R, color.G, color.B) })
				end
			end
		end
		local patchFights = {}
		for i = 1, #patches do
			for j = i + 1, #patches do
				local a, b = patches[i], patches[j]
				local distance = math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2)
				if distance < a.R + b.R - 0.2 and a.Color ~= b.Color and math.abs(a.Top - b.Top) < 0.015 then
					table.insert(patchFights, string.format("grass patch at world (%.0f, %.0f) r %.1f and patch at (%.0f, %.0f) r %.1f overlap by %.1f studs in the same plane (tops %.3f / %.3f)", a.X, a.Z, a.R, b.X, b.Z, b.R, a.R + b.R - distance, a.Top, b.Top))
				end
			end
		end
		check("9c. no two grass patches of a different colour overlap in the same plane (whole map, " .. #patches .. " patches)", #patches > 0 and #patchFights == 0, #patchFights .. " pairs")
		show(patchFights, 12)
	end

	do
		-- lots of neighbours: world rectangles of lot + hedge, gap between them, what stands in the gap
		local function lotRect(house)
			local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
			for _, corner in { { -lineX - 1.3, -0.55 }, { lineX + 1.3, -0.55 }, { lineX + 1.3, lineZ + 1.3 }, { -lineX - 1.3, lineZ + 1.3 } } do
				local p = house.CFrame:PointToWorldSpace(Vector3.new(corner[1], 0, corner[2]))
				minX, maxX, minZ, maxZ = math.min(minX, p.X), math.max(maxX, p.X), math.min(minZ, p.Z), math.max(maxZ, p.Z)
			end
			return { MinX = minX, MaxX = maxX, MinZ = minZ, MaxZ = maxZ }
		end
		local overlaps, gaps = {}, {}
		for i = 1, #houses do
			for j = i + 1, #houses do
				local a, b = lotRect(houses[i]), lotRect(houses[j])
				local gx = math.max(a.MinX, b.MinX) - math.min(a.MaxX, b.MaxX)
				local gz = math.max(a.MinZ, b.MinZ) - math.min(a.MaxZ, b.MaxZ)
				if gx < 0 and gz < 0 then
					table.insert(overlaps, string.format("lots of house %d and %d overlap by %.1f x %.1f studs", i, j, -gx, -gz))
				elseif gz < 0 and gx < 40 then
					table.insert(gaps, string.format("house %d and %d: %.1f studs of open lawn between the hedges (x %.1f .. %.1f)", i, j, gx, math.min(a.MaxX, b.MaxX), math.max(a.MinX, b.MinX)))
				end
			end
		end
		check("10. the 8 lots (hedge outer faces included) do not overlap each other", #overlaps == 0, #overlaps)
		show(overlaps)
		for _, line in gaps do print("   (info)", line) end

		-- what is built in the strip between two neighbouring lots of the north row (houses 1-2, 2-3, 3-4)?
		local skip = { Ground = true, OuterGround = true, GrassPatches = true, Patch = true, Beyond = true, Boundary = true, Backdrop = true }
		for index = 1, 3 do
			local a, b = lotRect(houses[index]), lotRect(houses[index + 1])
			local names = {}
			for _, d in M.descendants(workspace) do
				local data = RawData[d]
				if data.Props and data.Props.Size and data.Props.CFrame and M.InstanceMethods.IsA(d, "BasePart") and not skip[data.Name] then
					local p = data.Props.CFrame.Position
					local parentName = RawData[data.Parent] and RawData[data.Parent].Name or "?"
					if not skip[parentName] and p.X > a.MaxX and p.X < b.MinX and p.Z > a.MinZ and p.Z < a.MaxZ then
						names[data.Name] = (names[data.Name] or 0) + 1
					end
				end
			end
			local list = {}
			for name, count in names do table.insert(list, name .. " x" .. count) end
			table.sort(list)
			print(string.format("   (info) strip between house %d and %d: x %.1f .. %.1f, contains: %s", index, index + 1, a.MaxX, b.MinX, if #list == 0 then "nothing (open lawn)" else table.concat(list, ", ")))
		end
	end

	---------------------------------------------------------------------------
	-- garden props do not sit inside each other (the house audit scn_houses compares pieces of DIFFERENT parts of the house, so
	-- two objects of the yard are never compared there)
	---------------------------------------------------------------------------
	do
		-- an object is one cluster (the altar with its stones, the mailbox with its post ...): parts of one cluster may touch
		local function cluster(part)
			local name = part.Name
			if string.find(name, "^Altar") or name == "RuneStone" or name == "Rune" or name == "StepStone" then return "altar" end
			if string.find(name, "^Mail") then return "mailbox" end
			if name == "SignPost" or name == "SignBoard" then return "namesign" end
			if string.find(name, "^Gate") or string.find(name, "^Laser") or string.find(name, "^Security") then return "gate" end
			if string.find(name, "^Panel") then return "panel" end
			-- a model (lamp, bench, pond ...) is one object; a loose part of the yard is its own
			if part.Group == "Yard" then return part.Inst end
			return RawData[part.Inst].Parent
		end
		local function penetration(a, b)
			local candidates = {}
			for i = 1, 3 do
				table.insert(candidates, Vector3.new(a.A[i][1], a.A[i][2], a.A[i][3]))
				table.insert(candidates, Vector3.new(b.A[i][1], b.A[i][2], b.A[i][3]))
			end
			for i = 1, 3 do
				for j = 1, 3 do
					local c = Vector3.new(a.A[i][1], a.A[i][2], a.A[i][3]):Cross(Vector3.new(b.A[j][1], b.A[j][2], b.A[j][3]))
					if c.Magnitude > 1e-4 then table.insert(candidates, c.Unit) end
				end
			end
			local delta = Vector3.new(b.C[1] - a.C[1], b.C[2] - a.C[2], b.C[3] - a.C[3])
			local smallest = math.huge
			for _, axis in candidates do
				local ra, rb = 0, 0
				for i = 1, 3 do
					ra += a.H[i] * math.abs(a.A[i][1] * axis.X + a.A[i][2] * axis.Y + a.A[i][3] * axis.Z)
					rb += b.H[i] * math.abs(b.A[i][1] * axis.X + b.A[i][2] * axis.Y + b.A[i][3] * axis.Z)
				end
				local overlap = ra + rb - math.abs(delta:Dot(axis))
				if overlap <= 0 then return 0 end
				smallest = math.min(smallest, overlap)
			end
			return smallest
		end
		local ignored = { Lawn = true, Driveway = true, DrivewayEdge = true, GateApron = true, StepStone = true, Rune = true, Barrier = true }
		local hits = {}
		for _, house in { houses[1], houses[5] } do
			local props = {}
			for _, part in houseParts[house.Index] do
				local yardPart = false
				local node = RawData[part.Inst]
				while node do
					if node.Name == "Yard" and node.ClassName == "Model" then yardPart = true break end
					node = RawData[node.Parent]
				end
				if yardPart and part.Group ~= "Hedge" and part.Group ~= "Fence" and not ignored[part.Name] and part.Material ~= "Grass" and part.Transparency < 0.8 and not part.Ellipsoid and math.min(part.H[1], part.H[2], part.H[3]) >= 0.05 then
					table.insert(props, part)
				end
			end
			for i = 1, #props do
				for j = i + 1, #props do
					local a, b = props[i], props[j]
					if cluster(a) ~= cluster(b) then
						local depth = penetration(a, b)
						if depth > 0.1 then
							table.insert(hits, string.format("house %d: %s/%s (%.1f, %.1f) and %s/%s (%.1f, %.1f) interpenetrate by %.2f studs", house.Index, a.Group, a.Name, a.C[1], a.C[3], b.Group, b.Name, b.C[1], b.C[3], depth))
						end
					end
				end
			end
		end
		check("11. garden props (altar, bench, signs, mailbox, lamps, flower bed, gate, panel, pond) do not interpenetrate each other (houses 1 and 5)", #hits == 0, #hits)
		show(hits)
	end

	---------------------------------------------------------------------------
	-- self-test: the detector must see a hole when there is one AND a closed ring when there is none (so a red result above is the
	-- geometry, never the detector): take both side hedges of house 1 away, then put them back from the gate line to the back hedge
	---------------------------------------------------------------------------
	do
		local Decor = require(find("ServerScriptService.Systems.WorldBuilder.Decor"))
		local house = houses[1]
		local yard = house.Model:FindFirstChild("Yard")
		for _, model in yard:GetChildren() do
			local barrier = model.Name == "Hedge" and model:FindFirstChild("Barrier")
			if barrier and math.abs(house.CFrame:ToObjectSpace(barrier.CFrame).X) > 1 then model:Destroy() end
		end
		local opened = collect(house)
		local holes = #ringProblems(house, opened)
		local walksThrough = leaks(opened) ~= nil
		for _, side in { -1, 1 } do
			Decor.hedgeRun(yard, house.CFrame:PointToWorldSpace(Vector3.new(side * lineX, 0, 0)), house.CFrame:PointToWorldSpace(Vector3.new(side * lineX, 0, lineZ)), Random.new(7))
		end
		local closed = collect(house)
		local problems = ringProblems(house, closed)
		local stillLeaks = leaks(closed) ~= nil
		check("0. detector self-test: sees the holes when both side hedges of house 1 are gone, and a closed ring when they are rebuilt from the gate line", holes > 0 and walksThrough and #problems == 0 and not stillLeaks, string.format("without the hedge: %d holes, walk-through %s; rebuilt: %d holes, walk-through %s", holes, tostring(walksThrough), #problems, tostring(stillLeaks)))
		for _, problem in problems do print("   ", describeProblem(house, problem)) end
	end

	do
		-- the penetration measure itself, on shapes with a known overlap: a 2x2x2 box whose side sinks 0.5 into another box / into a ball of radius 1
		local function shape(x: number, ellipsoid: boolean)
			return { C = { x, 0, 0 }, A = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }, H = { 1, 1, 1 }, Min = { x - 1, -1, -1 }, Max = { x + 1, 1, 1 }, Shape = "Block", Ellipsoid = ellipsoid }
		end
		local intoBox = sinkDepth(shape(0, false), shape(1.5, false), false)
		local intoBall = sinkDepth(shape(0, false), shape(1.5, true), true)
		local apart = sinkDepth(shape(0, false), shape(2.5, false), false)
		check("0b. detector self-test: the sink depth of a known overlap is measured (0.5 into a box, 0.5 into a ball, 0 when apart)", math.abs(intoBox - 0.5) < 0.01 and math.abs(intoBall - 0.5) < 0.01 and apart == 0, string.format("box %.2f, ball %.2f, apart %.2f", intoBox, intoBall, apart))
	end

	print(string.format("\nPASS %d  FAIL %d", results.pass, results.fail))
end)
