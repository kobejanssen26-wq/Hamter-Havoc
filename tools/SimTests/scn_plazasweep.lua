-- Plaza sweep: every building and prop OUTSIDE the player houses (two shops, Lucky Wheel, Leaderboard Hall, arch, fountain, burrow / exit tunnel,
-- Like & Favorite boards, signpost, benches, lamps, paving, road, promenades, lawn) is checked for the defect classes reported on the houses:
-- holes, z-fighting faces, parts standing on a path, hovering and buried parts. Everything is analytic on the parts the REAL builders produce
-- (CFrame + Size of every part); the mock Raycast is not used.
--
--   P1  z-fight     two visible parts of a different colour / material with a face pair that is parallel (3 degrees), faces the same way, lies
--                   within 0.03 studs (0.05 for upward faces) and overlaps by more than 0.02 square studs, where the overlap is not hidden by a
--                   third opaque part. Boxes, cylinder caps and wedge faces. HARD = 0.012 studs apart or less (truly coplanar), SOFT = the rest.
--   P2  closed      every shop is a closed shell: rays from sample points in the room and under the roof, 160 directions each, must hit a wall,
--                   roof, gable or glass part. An escaping ray is a hole. The doorway is the only intended opening.
--   P3  see-through no straight line along x, y or z runs through a shop (gable end to gable end, front to back, sky to floor)
--   P4  wheel       seen from the road the Lucky Wheel inside its slices shows only slices / dividers / hub / rim (no backplate seam); closed from behind
--   P5  connected   the parts of one object (a shop, the arch, a board, a bench, a lamp ...) form ONE cluster (touch or overlap, 0.03 studs)
--   P6  buried      a visible part that lies completely inside other opaque parts (water under a rim, a window pane inside a wall)
--   P7  hover       a part that hovers 0.03 .. 0.7 studs over what should carry it (barrel next to the foundation, bench back over the seat)
--   P8  on paths    solid props whose footprint stands on a paved walkway (the by-design cases are listed with their reason)
-- The last block plants a defect of every kind and checks that each detector sees it (so a green run means something).
local results = { pass = 0, fail = 0 }
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end
local adv = M.Sim.advance

local HARD_GAP = 0.012 -- faces this close (or closer) are z-fighting for sure
local TOUCH = 0.03 -- parts closer than this count as touching (P5)

-- Hanging / floating by design: part name -> why it may stay detached from the rest of its object (P5)
local HANGING_BY_DESIGN = {
	ShopLamp = "a lamp hanging in the middle of the shop",
	Bulb = "the wheel's bulbs ring the rim",
}
local function hangingByDesign(p)
	return HANGING_BY_DESIGN[p.Name] ~= nil or string.find(p.Path, "/LuckyWheel/Pointer/", 1, true) ~= nil -- the wheel's fixed pointer hovers in front of the rim
end
-- Solid props that stand on a pavement ON PURPOSE (model name -> reason) (P8)
local ON_PAVEMENT_BY_DESIGN = {
	PlazaArch = "the arch stands on the plaza paving, the road runs under it",
	LuckyWheel = "the round platform is where the wheel path ends",
	CoinsShop = "steps and barrels stand on the shop approach in front of the door",
	RobuxShop = "steps and barrels stand on the shop approach in front of the door",
	KioskBase = "the kiosk stands in the middle of the hall paving",
	Board_Hamsters = "the hall boards stand on the paved square",
	Board_Steals = "the hall boards stand on the paved square",
	Board_Money = "the hall boards stand on the paved square",
	Bench = "a bench in the paved hall",
	BurrowHill = "the road runs into the burrow hill",
	ExitHill = "the road runs into the exit hill",
	Lamp = "lamps line the edge of a path (their foot may touch it)",
	Flowers = "flower beds line the edge of a path",
}

---------------------------------------------------------------------------
-- small vector helpers on plain { x, y, z } tables
---------------------------------------------------------------------------
local function dot(a, b) return a[1] * b[1] + a[2] * b[2] + a[3] * b[3] end
local function cross(a, b) return { a[2] * b[3] - a[3] * b[2], a[3] * b[1] - a[1] * b[3], a[1] * b[2] - a[2] * b[1] } end
local function norm(a)
	local l = math.sqrt(dot(a, a))
	if l < 1e-12 then return { 0, 0, 0 } end
	return { a[1] / l, a[2] / l, a[3] / l }
end

task.spawn(function()
	M.isServer = true
	local mainServer = find("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	adv(3)

	---------------------------------------------------------------------------
	-- part descriptions (world frame)
	---------------------------------------------------------------------------
	local function pathOf(inst)
		local chain, node = {}, inst
		while node and node ~= workspace do
			table.insert(chain, 1, RawData[node].Name)
			node = RawData[node].Parent
		end
		return table.concat(chain, "/"), chain
	end

	local function finish(p)
		local min, max = {}, {}
		for k = 1, 3 do
			local e = 0
			for i = 1, 3 do e += math.abs(p.Ax[i][k]) * p.H[i] end
			min[k], max[k] = p.C[k] - e, p.C[k] + e
		end
		p.Min, p.Max = min, max
		p.Opaque = p.Transparency < 0.05
		return p
	end

	local function describe(inst)
		local data = RawData[inst]
		local props = data.Props
		local cf, size = props.CFrame, props.Size
		local r = cf.r
		local shape = if props.Shape then props.Shape.Name else "Block"
		local kind = "box"
		if data.ClassName == "WedgePart" then kind = "wedge"
		elseif shape == "Cylinder" then kind = "cyl"
		elseif shape == "Ball" then kind = "ell" end
		for _, child in data.Children do
			local mesh = RawData[child]
			if mesh.ClassName == "SpecialMesh" and mesh.Props.MeshType and mesh.Props.MeshType.Name == "Sphere" then kind = "ell" end
		end
		local path, chain = pathOf(inst)
		return finish({
			Inst = inst, Name = data.Name, Path = path, Chain = chain, Kind = kind, C = { cf.X, cf.Y, cf.Z },
			Ax = { { r[1], r[4], r[7] }, { r[2], r[5], r[8] }, { r[3], r[6], r[9] } }, H = { size.X / 2, size.Y / 2, size.Z / 2 },
			Transparency = props.Transparency or 0, Solid = props.CanCollide ~= false,
			Color = props.Color, Material = if props.Material then props.Material.Name else "Plastic",
		})
	end

	-- a planted part for the self-tests (axis-aligned box)
	local probeCount = 0
	local function probe(name, size, centre, color, material, transparency)
		probeCount += 1
		return finish({
			Name = name, Path = "Probe/" .. name, Chain = { "Probe", name }, Kind = "box", C = { centre[1], centre[2], centre[3] },
			Ax = { { 1, 0, 0 }, { 0, 1, 0 }, { 0, 0, 1 } }, H = { size[1] / 2, size[2] / 2, size[3] / 2 }, Transparency = transparency or 0, Solid = true,
			Color = color, Material = material or "Plastic", Scoped = true, Index = 100000 + probeCount,
		})
	end

	-- which parts the sweep looks at: the whole plaza, hall and road + the walkways, props and lawn of the Environment
	local ENV_KEEP = { Ground = true, GrassPatches = true, Promenades = true, Props = true }
	local function inScope(chain)
		local top, second = chain[1], chain[2]
		if top == "HamsterPlaza" then return second ~= "PlazaStatue" end
		if top == "LeaderboardHall" or top == "HamsterPath" then return true end
		if top == "Environment" then return ENV_KEEP[second] == true end
		return false
	end

	-- (the houses are not part of this sweep but they cover the lawn and the promenade ends: parts of PlayerHouses only ever hide faces)
	local parts, scoped = {}, {}
	for _, d in M.descendants(workspace) do
		local data = RawData[d]
		if data.Props and data.Props.Size and data.Props.CFrame and M.InstanceMethods.IsA(d, "BasePart") and data.Props.Anchored and (data.Props.Transparency or 0) < 0.95 then
			local _, chain = pathOf(d)
			if inScope(chain) then
				local p = describe(d)
				p.Scoped = true
				table.insert(parts, p)
				table.insert(scoped, p)
			elseif chain[1] == "PlayerHouses" then
				local p = describe(d)
				p.Scoped = false
				table.insert(parts, p)
			end
		end
	end
	for index, p in parts do p.Index = index end
	print("   parts in scope:", #scoped, "(+ " .. (#parts - #scoped) .. " house parts that only hide faces)")

	---------------------------------------------------------------------------
	-- point-in-part, spatial grid, "is this spot hidden under another opaque part"
	---------------------------------------------------------------------------
	local function contains(p, x, y, z)
		local ex, ey, ez = x - p.C[1], y - p.C[2], z - p.C[3]
		local A = p.Ax
		local lx = A[1][1] * ex + A[1][2] * ey + A[1][3] * ez
		local ly = A[2][1] * ex + A[2][2] * ey + A[2][3] * ez
		local lz = A[3][1] * ex + A[3][2] * ey + A[3][3] * ez
		local hx, hy, hz = p.H[1], p.H[2], p.H[3]
		if p.Kind == "box" then
			return math.abs(lx) <= hx and math.abs(ly) <= hy and math.abs(lz) <= hz
		elseif p.Kind == "cyl" then
			return math.abs(lx) <= hx and (ly / hy) ^ 2 + (lz / hz) ^ 2 <= 1
		elseif p.Kind == "ell" then
			return (lx / hx) ^ 2 + (ly / hy) ^ 2 + (lz / hz) ^ 2 <= 1
		end
		return math.abs(lx) <= hx and math.abs(ly) <= hy and math.abs(lz) <= hz and ly / hy <= lz / hz -- wedge: the slope runs from the front-bottom to the back-top edge
	end

	local CELL = 8
	local BIG, grid = {}, {}
	local function cellRange(p, grow)
		return math.floor((p.Min[1] - grow) / CELL), math.floor((p.Max[1] + grow) / CELL), math.floor((p.Min[3] - grow) / CELL), math.floor((p.Max[3] + grow) / CELL)
	end
	for _, p in parts do
		local x0, x1, z0, z1 = cellRange(p, 0.1)
		if (x1 - x0 + 1) * (z1 - z0 + 1) > 60 then
			table.insert(BIG, p)
		else
			for cx = x0, x1 do
				for cz = z0, z1 do
					local key = cx * 100003 + cz
					local list = grid[key]
					if not list then list = {} grid[key] = list end
					table.insert(list, p)
				end
			end
		end
	end
	local extraCovers = {} -- planted parts of the self-tests that hide things
	local function hiddenAt(x, y, z, skipA, skipB)
		local function test(p)
			return p ~= skipA and p ~= skipB and p.Opaque and x >= p.Min[1] - 0.01 and x <= p.Max[1] + 0.01 and y >= p.Min[2] - 0.01 and y <= p.Max[2] + 0.01 and z >= p.Min[3] - 0.01 and z <= p.Max[3] + 0.01 and contains(p, x, y, z)
		end
		for _, p in grid[math.floor(x / CELL) * 100003 + math.floor(z / CELL)] or {} do if test(p) then return true end end
		for _, p in BIG do if test(p) then return true end end
		for _, p in extraCovers do if test(p) then return true end end
		return false
	end

	---------------------------------------------------------------------------
	-- faces of the parts and the face-pair z-fight analysis (P1)
	---------------------------------------------------------------------------
	local function world(p, lx, ly, lz)
		return {
			p.C[1] + p.Ax[1][1] * lx + p.Ax[2][1] * ly + p.Ax[3][1] * lz,
			p.C[2] + p.Ax[1][2] * lx + p.Ax[2][2] * ly + p.Ax[3][2] * lz,
			p.C[3] + p.Ax[1][3] * lx + p.Ax[2][3] * ly + p.Ax[3][3] * lz,
		}
	end
	local function addFace(list, p, n, poly)
		table.insert(list, { Part = p, N = n, D = dot(n, poly[1]), Poly = poly })
	end
	local SEG = 24
	local function facesOf(p)
		local list = {}
		local hx, hy, hz = p.H[1], p.H[2], p.H[3]
		if p.Kind == "box" then
			local ext = { hx, hy, hz }
			for k = 1, 3 do
				local m, o = (k % 3) + 1, ((k + 1) % 3) + 1
				for _, s in { -1, 1 } do
					local function pt(a, b)
						local l = { 0, 0, 0 }
						l[k], l[m], l[o] = s * ext[k], a * ext[m], b * ext[o]
						return world(p, l[1], l[2], l[3])
					end
					addFace(list, p, { s * p.Ax[k][1], s * p.Ax[k][2], s * p.Ax[k][3] }, { pt(1, 1), pt(-1, 1), pt(-1, -1), pt(1, -1) })
				end
			end
		elseif p.Kind == "cyl" then
			for _, s in { -1, 1 } do
				local poly = {}
				for i = 0, SEG - 1 do
					local t = i / SEG * 2 * math.pi
					table.insert(poly, world(p, s * hx, hy * math.cos(t), hz * math.sin(t)))
				end
				addFace(list, p, { s * p.Ax[1][1], s * p.Ax[1][2], s * p.Ax[1][3] }, poly)
			end
		elseif p.Kind == "wedge" then
			for _, s in { -1, 1 } do
				addFace(list, p, { s * p.Ax[1][1], s * p.Ax[1][2], s * p.Ax[1][3] }, { world(p, s * hx, -hy, -hz), world(p, s * hx, -hy, hz), world(p, s * hx, hy, hz) })
			end
			addFace(list, p, { -p.Ax[2][1], -p.Ax[2][2], -p.Ax[2][3] }, { world(p, -hx, -hy, -hz), world(p, hx, -hy, -hz), world(p, hx, -hy, hz), world(p, -hx, -hy, hz) })
			addFace(list, p, { p.Ax[3][1], p.Ax[3][2], p.Ax[3][3] }, { world(p, -hx, -hy, hz), world(p, hx, -hy, hz), world(p, hx, hy, hz), world(p, -hx, hy, hz) })
			local ln = norm({ 0, 1 / hy, -1 / hz })
			local slope = { ln[2] * p.Ax[2][1] + ln[3] * p.Ax[3][1], ln[2] * p.Ax[2][2] + ln[3] * p.Ax[3][2], ln[2] * p.Ax[2][3] + ln[3] * p.Ax[3][3] }
			addFace(list, p, slope, { world(p, -hx, -hy, -hz), world(p, hx, -hy, -hz), world(p, hx, hy, hz), world(p, -hx, hy, hz) })
		end
		return list
	end
	local faceStore = {}
	local function faceCache(p)
		local list = faceStore[p]
		if not list then list = facesOf(p) faceStore[p] = list end
		return list
	end

	-- 2D polygons in the plane of a face: counter-clockwise, clipped against each other (both are convex)
	local function basis(n)
		local helper = if math.abs(n[1]) < 0.9 then { 1, 0, 0 } else { 0, 1, 0 }
		local u = norm(cross(n, helper))
		return u, cross(n, u)
	end
	local function ccw(poly)
		local area = 0
		for i = 1, #poly do
			local a, b = poly[i], poly[i % #poly + 1]
			area += a[1] * b[2] - b[1] * a[2]
		end
		if area < 0 then
			local rev = {}
			for i = #poly, 1, -1 do table.insert(rev, poly[i]) end
			return rev, -area / 2
		end
		return poly, area / 2
	end
	local function project(poly, u, v)
		local out = {}
		for _, q in poly do table.insert(out, { dot(q, u), dot(q, v) }) end
		return (ccw(out))
	end
	local function clip(subject, clipper)
		local output = subject
		for i = 1, #clipper do
			local a, b = clipper[i], clipper[i % #clipper + 1]
			local input = output
			output = {}
			if #input == 0 then break end
			local function inside(q) return (b[1] - a[1]) * (q[2] - a[2]) - (b[2] - a[2]) * (q[1] - a[1]) >= -1e-9 end
			local function intersect(p1, p2)
				local d1x, d1y = p2[1] - p1[1], p2[2] - p1[2]
				local d2x, d2y = b[1] - a[1], b[2] - a[2]
				local den = d1x * d2y - d1y * d2x
				if math.abs(den) < 1e-12 then return p1 end
				local t = ((a[1] - p1[1]) * d2y - (a[2] - p1[2]) * d2x) / den
				return { p1[1] + t * d1x, p1[2] + t * d1y }
			end
			local prev = input[#input]
			for _, cur in input do
				if inside(cur) then
					if not inside(prev) then table.insert(output, intersect(prev, cur)) end
					table.insert(output, cur)
				elseif inside(prev) then
					table.insert(output, intersect(prev, cur))
				end
				prev = cur
			end
		end
		return output
	end
	local function polyArea(poly)
		local area, cx, cy = 0, 0, 0
		for i = 1, #poly do
			local a, b = poly[i], poly[i % #poly + 1]
			local w = a[1] * b[2] - b[1] * a[2]
			area += w
			cx += (a[1] + b[1]) * w
			cy += (a[2] + b[2]) * w
		end
		if math.abs(area) < 1e-9 then return 0, 0, 0 end
		return math.abs(area) / 2, cx / (3 * area), cy / (3 * area)
	end

	local COS3 = math.cos(math.rad(3))
	local function sameLook(a, b)
		return math.abs(a.Color.R - b.Color.R) + math.abs(a.Color.G - b.Color.G) + math.abs(a.Color.B - b.Color.B) < 0.02 and a.Material == b.Material and math.abs(a.Transparency - b.Transparency) < 0.05
	end

	-- every exposed face pair of two parts that z-fights: list of { Area, Gap, Centre, Up, N }
	local function zfightPair(a, b)
		local found = {}
		for _, fa in faceCache(a) do
			for _, fb in faceCache(b) do
				if dot(fa.N, fb.N) > COS3 then
					local up = fa.N[2] > 0.9 and fb.N[2] > 0.9
					local tol = if up then 0.05 else 0.03
					local u, v = basis(fa.N)
					local overlap = clip(project(fa.Poly, u, v), project(fb.Poly, u, v))
					if #overlap >= 3 then
						local area, cx, cy = polyArea(overlap)
						if area > 0.02 then
							-- plane distance measured at the middle of the overlap
							local centre = { fa.D * fa.N[1] + u[1] * cx + v[1] * cy, fa.D * fa.N[2] + u[2] * cx + v[2] * cy, fa.D * fa.N[3] + u[3] * cx + v[3] * cy }
							local gap = math.abs(dot(fb.N, centre) - fb.D)
							if gap <= tol then
								-- is any of it visible? sample the middle and the corners pulled to the middle
								local samples = { { cx, cy } }
								for _, q in overlap do table.insert(samples, { cx + (q[1] - cx) * 0.85, cy + (q[2] - cy) * 0.85 }) end
								local exposed, firstExposed = 0, nil
								for _, s in samples do
									local P = { fa.D * fa.N[1] + u[1] * s[1] + v[1] * s[2], fa.D * fa.N[2] + u[2] * s[1] + v[2] * s[2], fa.D * fa.N[3] + u[3] * s[1] + v[3] * s[2] }
									-- a point just above the HIGHER of the two faces: only a third part covering that spot hides the pair
									local lift = math.max(0, fb.D - dot(fb.N, P)) + 0.004
									local Q = { P[1] + fa.N[1] * lift, P[2] + fa.N[2] * lift, P[3] + fa.N[3] * lift }
									if not hiddenAt(Q[1], Q[2], Q[3], a, b) then
										exposed += 1
										firstExposed = firstExposed or Q
									end
								end
								if exposed > 0 then
									table.insert(found, { Area = area * exposed / #samples, Gap = gap, Centre = firstExposed or centre, Up = up, N = fa.N })
								end
							end
						end
					end
				end
			end
		end
		return found
	end

	-- pairs of parts whose boxes come within 0.06 of each other
	local function candidatePairs(list)
		local out, seen = {}, {}
		local function consider(a, b)
			if a.Index == b.Index then return end
			local lo, hi = math.min(a.Index, b.Index), math.max(a.Index, b.Index)
			local key = lo * 1000003 + hi
			if seen[key] then return end
			seen[key] = true
			if a.Min[1] < b.Max[1] + 0.06 and b.Min[1] < a.Max[1] + 0.06 and a.Min[2] < b.Max[2] + 0.06 and b.Min[2] < a.Max[2] + 0.06 and a.Min[3] < b.Max[3] + 0.06 and b.Min[3] < a.Max[3] + 0.06 then
				table.insert(out, { a, b })
			end
		end
		for _, a in list do
			local x0, x1, z0, z1 = cellRange(a, 0.1)
			if (x1 - x0 + 1) * (z1 - z0 + 1) <= 60 then
				for cx = x0, x1 do
					for cz = z0, z1 do
						for _, b in grid[cx * 100003 + cz] or {} do consider(a, b) end
					end
				end
			end
			for _, b in BIG do consider(a, b) end
		end
		return out
	end

	local function findZFights(list)
		local out = {}
		for _, pr in candidatePairs(list) do
			local a, b = pr[1], pr[2]
			if a.Scoped and b.Scoped and not sameLook(a, b) then
				for _, hit in zfightPair(a, b) do
					table.insert(out, { A = a, B = b, Area = hit.Area, Gap = hit.Gap, Centre = hit.Centre, Up = hit.Up, N = hit.N })
				end
			end
		end
		return out
	end

	-- group by the two part names + the model they sit in, so that 60 identical meetings count once
	local function groupZFights(zfights)
		local groups = {}
		for _, z in zfights do
			local ka = (z.A.Chain[1] or "") .. "/" .. (z.A.Chain[2] or "") .. ":" .. z.A.Name
			local kb = (z.B.Chain[1] or "") .. "/" .. (z.B.Chain[2] or "") .. ":" .. z.B.Name
			if ka > kb then ka, kb = kb, ka end
			local key = ka .. "  x  " .. kb
			local g = groups[key]
			if not g then g = { Key = key, Count = 0, Area = 0, MaxGap = 0, MinGap = 1, Sample = z, All = {} } groups[key] = g end
			g.Count += 1
			g.Area += z.Area
			g.MaxGap, g.MinGap = math.max(g.MaxGap, z.Gap), math.min(g.MinGap, z.Gap)
			table.insert(g.All, z)
			if z.Area > g.Sample.Area then g.Sample = z end
		end
		local list = {}
		for _, g in groups do table.insert(list, g) end
		table.sort(list, function(x, y) return x.Area > y.Area end)
		return list
	end

	local zfights = findZFights(scoped)
	local hardList, softList = {}, {}
	for _, z in zfights do table.insert(if z.Gap <= HARD_GAP then hardList else softList, z) end
	local hard, soft = groupZFights(hardList), groupZFights(softList)
	local function printGroups(tag, groups, limit)
		for i = 1, math.min(#groups, limit) do
			local g = groups[i]
			local s = g.Sample
			print(string.format("   %s %-92s n=%-3d area=%8.2f gap %.3f..%.3f  e.g. at (%.1f, %.3f, %.1f) %s", tag, g.Key, g.Count, g.Area, g.MinGap, g.MaxGap, s.Centre[1], s.Centre[2], s.Centre[3], if s.Up then "up" else string.format("n=(%.1f,%.1f,%.1f)", s.N[1], s.N[2], s.N[3])))
		end
	end
	print(string.format("   P1: %d exposed face pairs: %d hard (<= %.3f studs) in %d groups, %d soft in %d groups", #zfights, #hardList, HARD_GAP, #hard, #softList, #soft))
	printGroups("ZFIGHT-HARD", hard, 40)
	printGroups("ZFIGHT-SOFT", soft, 40)
	-- where exactly are the lawn patches that fight?
	for _, g in hard do
		if string.find(g.Key, "GrassPatches:Patch  x  Environment/GrassPatches:Patch", 1, true) then
			for j = 1, math.min(#g.All, 12) do
				local z = g.All[j]
				print(string.format("      lawn patches fight: %7.1f sq studs at (%.1f, %.3f, %.1f)", z.Area, z.Centre[1], z.Centre[2], z.Centre[3]))
			end
		end
	end
	check("P1 no two visible plaza / hall / road / ground parts have coplanar (<= 0.012 studs) overlapping same-facing exposed faces of a different colour", #hard == 0, #hardList .. " face pairs, " .. #hard .. " groups")
	check("P1b no two of them lie closer than 0.03 studs (0.05 for upward faces) with an exposed overlap either (flicker at a distance)", #soft == 0, #softList .. " face pairs, " .. #soft .. " groups")

	---------------------------------------------------------------------------
	-- ray casting against the parts (analytic: box, cylinder, ellipsoid, wedge)
	---------------------------------------------------------------------------
	-- t along the ray where it first enters the part (0 when it starts inside), nil on a miss
	local function rayPart(p, ox, oy, oz, dx, dy, dz)
		local A = p.Ax
		local ex, ey, ez = ox - p.C[1], oy - p.C[2], oz - p.C[3]
		local lox, loy, loz = A[1][1] * ex + A[1][2] * ey + A[1][3] * ez, A[2][1] * ex + A[2][2] * ey + A[2][3] * ez, A[3][1] * ex + A[3][2] * ey + A[3][3] * ez
		local ldx, ldy, ldz = A[1][1] * dx + A[1][2] * dy + A[1][3] * dz, A[2][1] * dx + A[2][2] * dy + A[2][3] * dz, A[3][1] * dx + A[3][2] * dy + A[3][3] * dz
		local hx, hy, hz = p.H[1], p.H[2], p.H[3]
		if p.Kind == "ell" then
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
		if math.abs(ldx) < 1e-9 then
			if math.abs(lox) > hx then return nil end
		else
			local t1, t2 = (-hx - lox) / ldx, (hx - lox) / ldx
			if t1 > t2 then t1, t2 = t2, t1 end
			lo, hi = math.max(lo, t1), math.min(hi, t2)
		end
		if p.Kind == "cyl" then
			local qy0, qz0, qy1, qz1 = loy / hy, loz / hz, ldy / hy, ldz / hz
			local a = qy1 * qy1 + qz1 * qz1
			local b = 2 * (qy0 * qy1 + qz0 * qz1)
			local c = qy0 * qy0 + qz0 * qz0 - 1
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
			if p.Kind == "wedge" then
				local f0, f1 = loy / hy - loz / hz, ldy / hy - ldz / hz
				if math.abs(f1) < 1e-12 then
					if f0 > 0 then return nil end
				else
					local tt = -f0 / f1
					if f1 > 0 then hi = math.min(hi, tt) else lo = math.max(lo, tt) end
				end
			end
		end
		if hi < lo then return nil end
		return lo
	end

	-- first hit among `list`: t, part (world box slab test first)
	local function castScene(list, ox, oy, oz, dx, dy, dz)
		local best, bestPart = math.huge, nil
		local o, d = { ox, oy, oz }, { dx, dy, dz }
		for _, p in list do
			local lo, hi = 0, math.huge
			local ok = true
			for k = 1, 3 do
				if math.abs(d[k]) < 1e-12 then
					if o[k] < p.Min[k] - 1e-6 or o[k] > p.Max[k] + 1e-6 then ok = false break end
				else
					local t1, t2 = (p.Min[k] - o[k]) / d[k], (p.Max[k] - o[k]) / d[k]
					if t1 > t2 then t1, t2 = t2, t1 end
					lo, hi = math.max(lo, t1), math.min(hi, t2)
					if hi < lo then ok = false break end
				end
			end
			if ok and lo < best then
				local t = rayPart(p, ox, oy, oz, dx, dy, dz)
				if t and t < best then best, bestPart = t, p end
			end
		end
		if bestPart then return best, bestPart end
		return nil, nil
	end

	local function sphereDirections(count)
		local dirs = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }
		local golden = math.pi * (3 - math.sqrt(5))
		for i = 0, count - 1 do
			local y = 1 - (i + 0.5) / count * 2
			local radius = math.sqrt(1 - y * y)
			local t = golden * i
			table.insert(dirs, { math.cos(t) * radius, y, math.sin(t) * radius })
		end
		return dirs
	end

	local function partsOfModel(model, names)
		local list = {}
		for _, p in scoped do
			local node = p.Inst
			while node and node ~= workspace do
				if node == model then
					if names == nil or names[p.Name] then table.insert(list, p) end
					break
				end
				node = RawData[node].Parent
			end
		end
		return list
	end

	-- 8-neighbour components of a set { ["i,j"] = {i, j} } -> list of { Count, I0, I1, J0, J1 }
	local function clusterCells(cells)
		local seen, out = {}, {}
		for key, cell in cells do
			if not seen[key] then
				local stack, comp = { cell }, { Count = 0, I0 = math.huge, I1 = -math.huge, J0 = math.huge, J1 = -math.huge }
				seen[key] = true
				while #stack > 0 do
					local c = table.remove(stack)
					comp.Count += 1
					comp.I0, comp.I1, comp.J0, comp.J1 = math.min(comp.I0, c[1]), math.max(comp.I1, c[1]), math.min(comp.J0, c[2]), math.max(comp.J1, c[2])
					for di = -1, 1 do
						for dj = -1, 1 do
							local nk = (c[1] + di) .. "," .. (c[2] + dj)
							if cells[nk] and not seen[nk] then
								seen[nk] = true
								table.insert(stack, cells[nk])
							end
						end
					end
				end
				table.insert(out, comp)
			end
		end
		table.sort(out, function(a, b) return a.Count > b.Count end)
		return out
	end

	---------------------------------------------------------------------------
	-- P2 / P3: the two shops are closed buildings
	---------------------------------------------------------------------------
	local plaza = workspace.HamsterPlaza
	local SHELL = { Foundation = true, WallBack = true, WallSide = true, WallFront = true, CornerPost = true, CornerPostBack = true, WindowGlass = true, WindowFrame = true, Lintel = true, DoorFrameTop = true, Roof = true, Ridge = true, Gable = true }
	local DIRS = sphereDirections(160)

	-- the shop's ground point in front of the door (Foundation: x centre, z = ground point + 5)
	local function shopOrigin(shell)
		for _, p in shell do
			if p.Name == "Foundation" then return p.C[1], p.C[3] - 5 end
		end
		return 0, 0
	end

	-- sample points of the room and of the space under the roof (world frame)
	local function shopSamplePoints(shell)
		local ox, oz = shopOrigin(shell)
		local roofs = {}
		for _, p in shell do if p.Name == "Roof" then table.insert(roofs, p) end end
		local points = {}
		for x = -5.6, 5.6, 1.4 do
			for _, y in { 1.4, 2.8, 4.2, 5.6, 7.0, 8.2 } do
				for z = 1.2, 8.8, 1.5 do table.insert(points, { ox + x, y, oz + z }) end
			end
		end
		for x = -5.6, 5.6, 2.8 do
			for y = 8.75, 12, 0.25 do
				for z = 0.7, 9.3, 0.25 do
					local P = { ox + x, y, oz + z }
					for _, roof in roofs do
						local e = { P[1] - roof.C[1], P[2] - roof.C[2], P[3] - roof.C[3] }
						local lx, ly, lz = dot(e, roof.Ax[1]), dot(e, roof.Ax[2]), dot(e, roof.Ax[3])
						if ly < -roof.H[2] - 0.08 and ly > -roof.H[2] - 0.8 and math.abs(lx) < roof.H[1] - 0.3 and math.abs(lz) < roof.H[3] then
							table.insert(points, P)
							break
						end
					end
				end
			end
		end
		return points
	end

	-- rays from the sample points; returns { Leaks = {{P, D}}, Door, Rays } (P in the shop frame)
	local function shopLeaks(shell)
		local ox, oz = shopOrigin(shell)
		local leaks, door, total = {}, 0, 0
		for _, P in shopSamplePoints(shell) do
			local blocked = false
			for _, p in shell do if contains(p, P[1], P[2], P[3]) then blocked = true break end end
			if not blocked then
				for _, d in DIRS do
					total += 1
					if not castScene(shell, P[1], P[2], P[3], d[1], d[2], d[3]) then
						-- the doorway: through the wall plane z = 0.2 inside x -2.7 .. 2.7, y 0.5 .. 6.1
						local through = false
						local pz = P[3] - oz
						if d[3] < -1e-6 and pz > 0.2 then
							local s = (0.2 - pz) / d[3]
							local x, y = P[1] - ox + d[1] * s, P[2] + d[2] * s
							through = math.abs(x) <= 2.7 and y >= 0.5 and y <= 6.1
						end
						if through then door += 1 else table.insert(leaks, { P = { P[1] - ox, P[2], P[3] - oz }, D = d }) end
					end
				end
			end
		end
		return { Leaks = leaks, Door = door, Rays = total }
	end

	local function shopSeeThrough(shell)
		local ox, oz = shopOrigin(shell)
		local function open(x, y, z, dx, dy, dz)
			return castScene(shell, x, y, z, dx, dy, dz) == nil and castScene(shell, x, y, z, -dx, -dy, -dz) == nil
		end
		-- a line only counts when it runs through the inside: something is above it (a roof) and something below it (floor / wall top)
		local function inside(x, y, z)
			return castScene(shell, x, y, z, 0, 1, 0) ~= nil and castScene(shell, x, y, z, 0, -1, 0) ~= nil
		end
		local found = { x = {}, z = {}, y = {} }
		for z = 0.7, 9.2, 0.125 do
			for y = 0.7, 12.5, 0.125 do
				if inside(ox, y, oz + z) and open(ox, y, oz + z, 1, 0, 0) then found.x[math.floor(z / 0.5) .. "," .. math.floor(y / 0.5)] = { math.floor(z / 0.5), math.floor(y / 0.5) } end
			end
		end
		for x = -6.2, 6.2, 0.25 do
			for y = 0.7, 12.5, 0.125 do
				if inside(ox + x, y, oz + 5) and open(ox + x, y, oz + 5, 0, 0, 1) then found.z[math.floor(x / 0.5) .. "," .. math.floor(y / 0.5)] = { math.floor(x / 0.5), math.floor(y / 0.5) } end
			end
		end
		for x = -6.5, 6.5, 0.125 do
			for z = 0.5, 9.5, 0.125 do
				if open(ox + x, 6, oz + z, 0, 1, 0) then found.y[math.floor(x / 0.5) .. "," .. math.floor(z / 0.5)] = { math.floor(x / 0.5), math.floor(z / 0.5) } end
			end
		end
		return found
	end

	local shopShells = {}
	for _, name in { "CoinsShop", "RobuxShop" } do
		local shell = partsOfModel(plaza:FindFirstChild(name), SHELL)
		shopShells[name] = shell
		local rep = shopLeaks(shell)
		print(string.format("   P2 %s: %d rays from inside, %d leave through the doorway (intended), %d escape elsewhere", name, rep.Rays, rep.Door, #rep.Leaks))
		-- where do the escaping rays cross the gable ends (x = +-6.95)? one entry per opening
		local cells, crossing, other = {}, 0, 0
		for _, leak in rep.Leaks do
			local P, d = leak.P, leak.D
			local plane = if d[1] > 0 then 6.95 else -6.95
			local s = (plane - P[1]) / d[1]
			if math.abs(d[1]) > 0.3 and s > 0 and P[2] + d[2] * s > 8.6 then
				crossing += 1
				local i, j = math.floor((P[3] + d[3] * s) / 0.25), math.floor((P[2] + d[2] * s) / 0.25)
				cells[i .. "," .. j] = { i, j }
			else
				other += 1
			end
		end
		local comps = clusterCells(cells)
		print(string.format("      %s: %d escaping rays pass through the gable ends in %d openings (z / y in the shop frame), %d through other sides", name, crossing, #comps, other))
		for i = 1, math.min(#comps, 8) do
			local c = comps[i]
			print(string.format("         GABLE opening z %.2f..%.2f  y %.2f..%.2f  (%d cells of 0.25)", c.I0 * 0.25, (c.I1 + 1) * 0.25, c.J0 * 0.25, (c.J1 + 1) * 0.25, c.Count))
		end
		-- the other escapes: which wall plane and height do they pass? (front z = -0.15, back z = 10.0)
		local planes = {}
		for _, leak in rep.Leaks do
			local P, d = leak.P, leak.D
			if not (math.abs(d[1]) > 0.3) and math.abs(d[3]) > 0.3 then
				local plane = if d[3] > 0 then 10.0 else -0.15
				local s = (plane - P[3]) / d[3]
				if s > 0 then
					local key = (if d[3] > 0 then "back" else "front") .. string.format(" wall plane at y %.2f", math.floor((P[2] + d[2] * s) / 0.25) * 0.25)
					planes[key] = (planes[key] or 0) + 1
				end
			end
		end
		local keys = {}
		for k in planes do table.insert(keys, k) end
		table.sort(keys)
		for _, k in keys do print(string.format("         ESCAPE through the %s (%d rays)", k, planes[k])) end
		check("P2 " .. name .. " is a closed shell (no ray from inside escapes except through the doorway)", #rep.Leaks == 0, #rep.Leaks .. " escaping rays")
	end
	for _, name in { "CoinsShop", "RobuxShop" } do
		local found = shopSeeThrough(shopShells[name])
		local total = 0
		for axis, cells in found do
			local comps = clusterCells(cells)
			for i = 1, math.min(#comps, 4) do
				total += comps[i].Count
				print(string.format("      SEE-THROUGH %s along %s: %d cells of 0.5x0.5 at (%s %.1f..%.1f, %s %.1f..%.1f)", name, axis, comps[i].Count, if axis == "x" then "z" else "x", comps[i].I0 * 0.5, (comps[i].I1 + 1) * 0.5, if axis == "y" then "z" else "y", comps[i].J0 * 0.5, (comps[i].J1 + 1) * 0.5))
			end
		end
		check("P3 you can not look straight through " .. name .. " (no open line along x, y or z)", total == 0, total .. " cells")
	end

	---------------------------------------------------------------------------
	-- P4: the Lucky Wheel disc
	---------------------------------------------------------------------------
	do
		local all = partsOfModel(plaza:FindFirstChild("LuckyWheel"), nil)
		local hubPart
		for _, p in all do if p.Name == "Hub" then hubPart = p end end
		local hubY, cx, cz = hubPart.C[2], hubPart.C[1], hubPart.C[3]
		local count = #require(find("ReplicatedStorage.Modules.SpinWheelConfig")).Prizes
		-- seen from the road (rays go +z): inside the apothem of the slice polygon the first thing hit must be a slice, divider, peg, hub, cap, gem or rim
		local apothem = (5.6 - 0.1) * math.cos(math.pi / count)
		local FRONT_OK = { Facet = true, Divider = true, Peg = true, Hub = true, HubCap = true, HubGem = true, Rim = true, Pointer = true, Axle = true } -- (the axle bolt shows in the middle of the hub)
		local bad, rays = {}, 0
		for x = -5.4, 5.4, 0.1 do
			for y = -5.4, 5.4, 0.1 do
				if math.sqrt(x * x + y * y) < apothem - 0.05 then
					rays += 1
					local _, hit = castScene(all, cx + x, hubY + y, cz - 30, 0, 0, 1)
					if not hit or not FRONT_OK[hit.Name] then
						bad[math.floor(x / 0.5) .. "," .. math.floor(y / 0.5)] = { math.floor(x / 0.5), math.floor(y / 0.5), Name = hit and hit.Name or "nothing" }
					end
				end
			end
		end
		local comps = clusterCells(bad)
		for i = 1, math.min(#comps, 5) do
			print(string.format("      WHEEL seam seen from the front: %d cells at x %.1f..%.1f y %.1f..%.1f", comps[i].Count, comps[i].I0 * 0.5, (comps[i].I1 + 1) * 0.5, comps[i].J0 * 0.5, (comps[i].J1 + 1) * 0.5))
		end
		check("P4 seen from the road the wheel disc inside the slices shows only slices, dividers, hub and rim (no backplate seams)", #comps == 0, #comps .. " seam clusters of " .. rays .. " rays")
		local backBad = 0
		for x = -5.4, 5.4, 0.2 do
			for y = -5.4, 5.4, 0.2 do
				if math.sqrt(x * x + y * y) < 5.4 and not castScene(all, cx + x, hubY + y, cz + 30, 0, 0, -1) then backBad += 1 end
			end
		end
		check("P4 seen from behind the wheel disc is closed (a ray hits a part everywhere inside the rim)", backBad == 0, backBad)
	end

	---------------------------------------------------------------------------
	-- objects: the parts that are meant to be one thing
	---------------------------------------------------------------------------
	local ids, idCount = {}, 0
	local function idOf(inst)
		if not ids[inst] then idCount += 1 ids[inst] = "#" .. idCount end
		return ids[inst]
	end
	local SMALL_MODELS = { Bench = true, Lamp = true, Flowers = true, Fence = true }
	local function objectOf(p)
		local chain = p.Chain
		local top = chain[1]
		if top == "HamsterPlaza" then
			-- the nearest small prop model (bench, lamp, flower bed, tree) or else the top model (shop, arch, wheel, board, fountain ...)
			local node, small, topModel = p.Inst, nil, nil
			while node and node ~= workspace do
				if RawData[node].ClassName == "Model" then
					topModel = node
					if not small and (SMALL_MODELS[RawData[node].Name] or string.sub(RawData[node].Name, 1, 5) == "Tree_") then small = node end
				end
				node = RawData[node].Parent
			end
			if small then return idOf(small) end
			if topModel and RawData[topModel].Name ~= "ReadingNook" then return idOf(topModel) end
		elseif top == "LeaderboardHall" then
			if #chain > 2 then
				local node = p.Inst
				while node and RawData[node].Parent ~= workspace.LeaderboardHall do node = RawData[node].Parent end
				return idOf(node)
			end
			local second = chain[2]
			if second == "GatePost" or second == "GatePostBase" or second == "HallSign" or second == "GateGlow" then return "Gate" end
			if second == "KioskBase" or second == "KioskCup" or second == "KioskBowl" then return "Kiosk" end
		elseif top == "HamsterPath" then
			local second = chain[2]
			if string.sub(second, 1, 6) == "Burrow" or second == "SignPostL" or second == "SignPostR" then return "Burrow" end
			if string.sub(second, 1, 4) == "Exit" then return "Exit" end
		elseif top == "Environment" and chain[2] == "Props" and #chain > 2 then
			local node = p.Inst
			while node and RawData[RawData[node].Parent].Name ~= "Props" do node = RawData[node].Parent end
			return idOf(node)
		end
		return nil
	end
	local function groupObjects(list)
		local objs = {}
		for _, p in list do
			local key = p.Object or objectOf(p)
			if key then
				p.Object = key
				local o = objs[key]
				if not o then o = { Key = key, Parts = {} } objs[key] = o end
				table.insert(o.Parts, p)
			end
		end
		return objs
	end
	local objects = groupObjects(scoped)

	-- separation of two boxes (lower bound of the real distance, 0 when they overlap), separating axis test
	local function boxGap(a, b)
		local delta = { b.C[1] - a.C[1], b.C[2] - a.C[2], b.C[3] - a.C[3] }
		local cands = {}
		for i = 1, 3 do table.insert(cands, a.Ax[i]) table.insert(cands, b.Ax[i]) end
		for i = 1, 3 do
			for j = 1, 3 do
				local c = cross(a.Ax[i], b.Ax[j])
				local len = math.sqrt(dot(c, c))
				if len > 1e-4 then table.insert(cands, { c[1] / len, c[2] / len, c[3] / len }) end
			end
		end
		local best = 0
		for _, axis in cands do
			local ra, rb = 0, 0
			for i = 1, 3 do ra += a.H[i] * math.abs(dot(a.Ax[i], axis)) rb += b.H[i] * math.abs(dot(b.Ax[i], axis)) end
			best = math.max(best, math.abs(dot(delta, axis)) - ra - rb)
		end
		return best
	end

	---------------------------------------------------------------------------
	-- P5: every object is ONE connected cluster
	---------------------------------------------------------------------------
	local function findDetached(objs)
		local detached = {}
		for _, o in objs do
			local list = o.Parts
			local comp = {}
			for i = 1, #list do comp[i] = i end
			local function root(i) while comp[i] ~= i do comp[i] = comp[comp[i]] i = comp[i] end return i end
			for i = 1, #list do
				for j = i + 1, #list do
					local a, b = list[i], list[j]
					if a.Min[1] < b.Max[1] + TOUCH and b.Min[1] < a.Max[1] + TOUCH and a.Min[2] < b.Max[2] + TOUCH and b.Min[2] < a.Max[2] + TOUCH and a.Min[3] < b.Max[3] + TOUCH and b.Min[3] < a.Max[3] + TOUCH then
						if boxGap(a, b) <= TOUCH then comp[root(i)] = root(j) end
					end
				end
			end
			local sizes = {}
			for i = 1, #list do local r = root(i) sizes[r] = (sizes[r] or 0) + 1 end
			local biggest, bigRoot = 0, nil
			for r, n in sizes do if n > biggest then biggest, bigRoot = n, r end end
			for i = 1, #list do
				if root(i) ~= bigRoot and not hangingByDesign(list[i]) then
					local gap = math.huge
					for j = 1, #list do if root(j) == bigRoot then gap = math.min(gap, boxGap(list[i], list[j])) end end
					table.insert(detached, { Part = list[i], Gap = gap })
				end
			end
		end
		table.sort(detached, function(a, b) return a.Gap > b.Gap end)
		return detached
	end
	do
		local detached = findDetached(objects)
		local byName = {}
		for _, d in detached do
			local sig = d.Part.Chain[1] .. "/" .. (d.Part.Chain[2] or "") .. ":" .. d.Part.Name
			local e = byName[sig]
			if not e then e = { Sig = sig, Count = 0, Gap = 0, Sample = d } byName[sig] = e end
			e.Count += 1
			e.Gap = math.max(e.Gap, d.Gap)
		end
		local list = {}
		for _, e in byName do table.insert(list, e) end
		table.sort(list, function(a, b) return a.Gap > b.Gap end)
		print(string.format("   P5: %d parts do not touch the rest of their object (hanging by design are skipped: shop lamp, wheel pointer, wheel bulbs)", #detached))
		for i = 1, math.min(#list, 30) do
			local e = list[i]
			local p = e.Sample.Part
			print(string.format("   DETACHED %-58s x%-3d gap %.3f  size %.2fx%.2fx%.2f at (%.1f, %.2f, %.1f)", e.Sig, e.Count, e.Gap, p.H[1] * 2, p.H[2] * 2, p.H[3] * 2, p.C[1], p.C[2], p.C[3]))
		end
		check("P5 every plaza / hall object is one connected piece (nothing hovers beside the rest of its object)", #detached == 0, #detached .. " detached parts")
	end

	---------------------------------------------------------------------------
	-- P6: parts that are completely buried inside other opaque parts
	---------------------------------------------------------------------------
	local function findBuried(list)
		local buried = {}
		local function surfacePoints(p)
			local pts = {}
			local h = p.H
			if p.Kind == "box" or p.Kind == "wedge" then
				local steps = { -1, -0.6, -0.2, 0.2, 0.6, 1 }
				for _, sx in steps do for _, sy in steps do for _, sz in steps do
					if math.abs(sx) == 1 or math.abs(sy) == 1 or math.abs(sz) == 1 then table.insert(pts, { sx * h[1], sy * h[2], sz * h[3] }) end
				end end end
			else
				for i = 0, 7 do
					local t = i / 8 * 2 * math.pi
					if p.Kind == "cyl" then
						for _, lx in { -1, 0, 1 } do table.insert(pts, { lx * h[1], h[2] * math.cos(t), h[3] * math.sin(t) }) end
					else
						for _, el in { -0.9, -0.45, 0, 0.45, 0.9 } do
							local rr = math.sqrt(1 - el * el)
							table.insert(pts, { h[1] * rr * math.cos(t), h[2] * el, h[3] * rr * math.sin(t) })
						end
					end
				end
				if p.Kind == "cyl" then table.insert(pts, { h[1], 0, 0 }) table.insert(pts, { -h[1], 0, 0 }) else table.insert(pts, { 0, h[2], 0 }) table.insert(pts, { 0, -h[2], 0 }) end
			end
			return pts
		end
		for _, p in list do
			if p.Transparency < 0.95 and math.min(p.H[1], p.H[2], p.H[3]) * 2 > 0.04 then
				local allHidden = true
				for _, l in surfacePoints(p) do
					-- a hair outside the surface, along the direction from the middle of the part
					local len = math.sqrt((l[1] / p.H[1]) ^ 2 + (l[2] / p.H[2]) ^ 2 + (l[3] / p.H[3]) ^ 2)
					local g = 1 + 0.01 / math.max(len, 1e-6)
					local w = world(p, l[1] * g, l[2] * g, l[3] * g)
					if not hiddenAt(w[1], w[2], w[3], p, nil) then allHidden = false break end
				end
				if allHidden then table.insert(buried, p) end
			end
		end
		return buried
	end
	do
		local buried = findBuried(scoped)
		print(string.format("   P6: %d parts are completely buried inside other opaque parts", #buried))
		local seen = {}
		for _, p in buried do
			local sig = p.Chain[1] .. "/" .. (p.Chain[2] or "") .. ":" .. p.Name
			if not seen[sig] then
				seen[sig] = true
				print(string.format("   BURIED %-58s size %.2fx%.2fx%.2f at (%.1f, %.2f, %.1f) transparency %.2f", sig, p.H[1] * 2, p.H[2] * 2, p.H[3] * 2, p.C[1], p.C[2], p.C[3], p.Transparency))
			end
		end
		check("P6 no visible part is completely hidden inside other parts (water under a rim, a window pane inside a wall, a hole inside a hill)", #buried == 0, #buried)
	end

	---------------------------------------------------------------------------
	-- P7: hovering parts
	---------------------------------------------------------------------------
	local function findHovering(list)
		local floaters = {}
		for _, p in list do
			if p.Transparency < 0.95 and (p.Kind == "box" or p.Kind == "cyl") then
				local f
				for _, face in faceCache(p) do if face.N[2] < -0.95 then f = face break end end
				if f then
					local y = f.Poly[1][2]
					if y > 0.12 and y < 14 then
						local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
						for _, q in f.Poly do x0, x1, z0, z1 = math.min(x0, q[1]), math.max(x1, q[1]), math.min(z0, q[3]), math.max(z1, q[3]) end
						local on, unsupported, worst = 0, 0, nil
						for i = 0, 6 do
							for j = 0, 6 do
								local x, z = x0 + (x1 - x0) * (i + 0.5) / 7, z0 + (z1 - z0) * (j + 0.5) / 7
								if contains(p, x, y + 0.01, z) then
									on += 1
									if not hiddenAt(x, y - 0.06, z, p, nil) then
										unsupported += 1
										worst = worst or { x, y, z }
									end
								end
							end
						end
						if on > 0 and unsupported / on >= 0.5 and worst then
							-- how far below is the nearest thing there? (a part 0.03 .. 0.7 below is what the eye reads as "should carry it")
							local gap = y
							for _, q in list do
								if q ~= p and q.Opaque and worst[1] >= q.Min[1] and worst[1] <= q.Max[1] and worst[3] >= q.Min[3] and worst[3] <= q.Max[3] and q.Max[2] <= y + 0.01 and contains(q, worst[1], q.Max[2] - 0.01, worst[3]) then
									gap = math.min(gap, y - q.Max[2])
								end
							end
							-- a part that a post beside it holds (it rises from below the underside to above it: a board between two posts) is held, not hovering
							local held = false
							for _, q in list do
								if q ~= p and q.Min[2] < y - 0.1 and q.Max[2] > y + 0.1 and q.Min[1] < p.Max[1] + TOUCH and p.Min[1] < q.Max[1] + TOUCH and q.Min[3] < p.Max[3] + TOUCH and p.Min[3] < q.Max[3] + TOUCH and q.Min[2] < p.Max[2] + TOUCH and boxGap(p, q) <= TOUCH then
									held = true
									break
								end
							end
							if not held and gap > 0.03 and gap <= 0.7 then table.insert(floaters, { Part = p, Fraction = unsupported / on, Gap = gap, Y = y }) end
						end
					end
				end
			end
		end
		return floaters
	end
	do
		local floaters = findHovering(scoped)
		local seen, sigs = {}, {}
		for _, fl in floaters do
			local p = fl.Part
			local sig = p.Chain[1] .. "/" .. (p.Chain[2] or "") .. ":" .. p.Name
			if not seen[sig] then seen[sig] = { Count = 0, Fl = fl } table.insert(sigs, sig) end
			seen[sig].Count += 1
		end
		table.sort(sigs)
		print(string.format("   P7: %d parts hover 0.03 .. 0.7 studs over what carries them (>= 50%% of the underside unsupported)", #floaters))
		for _, sig in sigs do
			local e = seen[sig]
			local p = e.Fl.Part
			print(string.format("   HOVER %-56s x%-3d underside y=%.2f, %3.0f%% unsupported, nearest support %.2f below  size %.2fx%.2fx%.2f at (%.1f, %.2f, %.1f)", sig, e.Count, e.Fl.Y, e.Fl.Fraction * 100, e.Fl.Gap, p.H[1] * 2, p.H[2] * 2, p.H[3] * 2, p.C[1], p.C[2], p.C[3]))
		end
		check("P7 no part hovers over (or only half rests on) what should carry it", #floaters == 0, #floaters)
	end

	---------------------------------------------------------------------------
	-- P8: props that stand ON a paved walkway (footprints = the real rotated rectangles / discs)
	---------------------------------------------------------------------------
	local function hull2(points)
		table.sort(points, function(a, b) return a[1] < b[1] or (a[1] == b[1] and a[2] < b[2]) end)
		local function cr(o, a, b) return (a[1] - o[1]) * (b[2] - o[2]) - (a[2] - o[2]) * (b[1] - o[1]) end
		local lower, upper = {}, {}
		for _, q in points do
			while #lower >= 2 and cr(lower[#lower - 1], lower[#lower], q) <= 0 do table.remove(lower) end
			table.insert(lower, q)
		end
		for i = #points, 1, -1 do
			local q = points[i]
			while #upper >= 2 and cr(upper[#upper - 1], upper[#upper], q) <= 0 do table.remove(upper) end
			table.insert(upper, q)
		end
		table.remove(lower) table.remove(upper)
		for _, q in upper do table.insert(lower, q) end
		return lower
	end
	local function footprint(p)
		local pts = {}
		if p.Kind == "ell" or (p.Kind == "cyl" and math.abs(p.Ax[1][2]) > 0.9) then
			local rx = if p.Kind == "cyl" then math.min(p.H[2], p.H[3]) else (p.Max[1] - p.Min[1]) / 2
			local rz = if p.Kind == "cyl" then rx else (p.Max[3] - p.Min[3]) / 2
			for i = 0, 15 do
				local t = i / 16 * 2 * math.pi
				table.insert(pts, { p.C[1] + rx * math.cos(t), p.C[3] + rz * math.sin(t) })
			end
			return pts
		end
		for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
			local w = world(p, sx * p.H[1], sy * p.H[2], sz * p.H[3])
			table.insert(pts, { w[1], w[3] })
		end end end
		return hull2(pts)
	end
	local WALK = { Promenade = true, GatePath = true, Road = true, AnnexPath = true, ShopApproach = true, WheelPath = true, HallPath = true, PavingOuter = true, HallPaving = true }
	local walkways = {}
	for _, p in scoped do
		if WALK[p.Name] and p.Max[2] < 0.4 then table.insert(walkways, { Name = p.Name, Poly = (ccw(footprint(p))), Part = p }) end
	end
	-- the model a part sits in, and a label with the position of the first part of its object
	local function objectLabel(p, objs)
		local o = p.Object and objs[p.Object]
		local first = o and o.Parts[1] or p
		local model = if #first.Chain > 2 then first.Chain[#first.Chain - 1] else first.Name -- a part that sits directly in a folder stands for itself
		return model, string.format("%s/%s@(%.0f,%.0f)", first.Chain[1], model, first.C[1], first.C[3])
	end
	local function findOnPath(list, objs)
		local per = {}
		for _, p in list do
			if not WALK[p.Name] and p.Transparency < 0.95 and p.Min[2] < 1.2 and p.Max[2] > 0.8 and p.Chain[2] ~= "Ground" and p.Chain[2] ~= "GrassPatches" and p.Name ~= "Curb" and p.Name ~= "PromenadeEdge" then
				local fp, area = ccw(footprint(p))
				if area > 1e-4 then
					local on, names = 0, {}
					for _, w in walkways do
						if p.Min[1] < w.Part.Max[1] and p.Max[1] > w.Part.Min[1] and p.Min[3] < w.Part.Max[3] and p.Max[3] > w.Part.Min[3] then
							local clipped = clip(fp, w.Poly)
							if #clipped >= 3 then
								local a = polyArea(clipped)
								if a > 1e-3 then on += a names[w.Name] = (names[w.Name] or 0) + a end
							end
						end
					end
					if on > 0 then
						local model, key = objectLabel(p, objs)
						local r = per[key]
						if not r then r = { Key = key, Model = model, On = 0, Area = 0, Solid = false, Names = {} } per[key] = r end
						r.On += math.min(on, area)
						r.Area += area
						r.Solid = r.Solid or p.Solid
						for n, a in names do r.Names[n] = (r.Names[n] or 0) + a end
					end
				end
			end
		end
		local out = {}
		for _, r in per do table.insert(out, r) end
		table.sort(out, function(a, b) return a.On > b.On end)
		return out
	end
	do
		local onPath = findOnPath(scoped, objects)
		print("   P8: " .. #walkways .. " walkway surfaces, " .. #onPath .. " objects overlap one")
		local bad = {}
		for _, r in onPath do
			local names = {}
			for n, a in r.Names do table.insert(names, string.format("%s %.1f", n, a)) end
			table.sort(names)
			local reason = ON_PAVEMENT_BY_DESIGN[r.Model]
			if r.On > 0.15 then
				print(string.format("   ONPATH %-46s on-path %6.1f of %6.1f sq studs solid=%-5s [%s]%s", r.Key, r.On, r.Area, tostring(r.Solid), table.concat(names, ", "), if reason then "  by design: " .. reason else ""))
				if not reason then table.insert(bad, r) end
			end
		end
		check("P8 no prop stands on a paved walkway unless it is meant to (boards, signposts, benches in the middle of a promenade)", #bad == 0, #bad .. " objects")
	end

	---------------------------------------------------------------------------
	-- self-tests: plant one defect of every kind
	---------------------------------------------------------------------------
	do
		-- P1: two coplanar slabs of different colours out in the sky, away from everything
		local red = probe("ProbeRed", { 4, 0.2, 4 }, { 300, 40.1, 300 }, Color3.new(1, 0, 0))
		local green = probe("ProbeGreen", { 4, 0.2, 4 }, { 301, 40.1, 300 }, Color3.new(0, 1, 0))
		local seen = zfightPair(red, green)
		local near = probe("ProbeNear", { 4, 0.2, 4 }, { 300, 40.12, 300 }, Color3.new(0, 0, 1)) -- 0.02 above red
		local softUp = 0
		for _, hit in zfightPair(red, near) do if hit.Up and hit.Gap > HARD_GAP then softUp += 1 end end
		local apart = probe("ProbeApart", { 4, 0.2, 4 }, { 300, 40.3, 300 }, Color3.new(0, 0, 1)) -- 0.2 above red
		check("self-test P1: coplanar slabs of different colours are seen as hard z-fighting, 0.02 apart as soft, 0.2 apart not at all", #seen >= 1 and seen[1].Gap <= HARD_GAP and softUp >= 1 and #zfightPair(red, apart) == 0)
		local cover = probe("ProbeCover", { 12, 2, 12 }, { 300.5, 40.1, 300 }, Color3.new(0.5, 0.5, 0.5))
		table.insert(extraCovers, cover)
		check("self-test P1: a third part that swallows the pair hides it", #zfightPair(red, green) == 0)
		table.remove(extraCovers)

		-- P2: take the back wall out of a shop
		local intact = shopLeaks(shopShells.CoinsShop)
		local cut = {}
		for _, p in shopShells.CoinsShop do if p.Name ~= "WallBack" then table.insert(cut, p) end end
		local cutLeaks = shopLeaks(cut)
		check("self-test P2: a shop without its back wall leaks far more rays than the real one", #cutLeaks.Leaks > #intact.Leaks + 200, #cutLeaks.Leaks .. " vs " .. #intact.Leaks)

		-- P3: a shop shell with walls only at the sides can be looked through front to back
		local open = {}
		for _, p in shopShells.CoinsShop do if p.Name == "Foundation" or p.Name == "Roof" or p.Name == "WallSide" then table.insert(open, p) end end
		local count = 0
		for _, cells in shopSeeThrough(open) do for _ in cells do count += 1 end end
		check("self-test P3: a shop with walls only at the sides can be looked through front to back", count > 20, count)

		-- P5: a part that floats beside a lamp
		local lampParts = {}
		for _, o in objects do if #o.Parts >= 4 and o.Parts[1].Name == "Base" and string.find(o.Parts[1].Path, "Lamp", 1, true) then lampParts = o.Parts break end end
		local stray = { table.unpack(lampParts) }
		table.insert(stray, probe("StrayBulb", { 1, 1, 1 }, { lampParts[1].C[1] + 6, lampParts[1].C[2], lampParts[1].C[3] }, Color3.new(1, 1, 0)))
		check("self-test P5: a part floating 6 studs beside a lamp is reported as detached, the lamp itself is one piece", #lampParts >= 4 and #findDetached({ A = { Key = "A", Parts = stray } }) == 1 and #findDetached({ B = { Key = "B", Parts = lampParts } }) == 0)

		-- P6: a window pane inside a wall, and the same pane in front of the wall
		local wall = probe("ProbeWall", { 10, 10, 1 }, { 300, 45, 320 }, Color3.new(1, 1, 1))
		table.insert(extraCovers, wall)
		local pane = probe("ProbePane", { 3, 3, 0.2 }, { 300, 45, 320 }, Color3.new(0.5, 0.8, 1), "Glass", 0.45)
		local proud = probe("ProbeProud", { 3, 3, 0.2 }, { 300, 45, 320.6 }, Color3.new(0.5, 0.8, 1), "Glass", 0.45)
		check("self-test P6: a pane inside a wall is buried, the same pane in front of the wall face is not", #findBuried({ pane }) == 1 and #findBuried({ proud }) == 0)
		table.remove(extraCovers)

		-- P7: a block hovering 0.4 over the ground, and the same block resting on it
		local ground = probe("ProbeGround", { 20, 1, 20 }, { 300, 9.5, 340 }, Color3.new(0.3, 0.6, 0.3))
		table.insert(extraCovers, ground)
		local hover = probe("ProbeHover", { 2, 2, 2 }, { 300, 11.4, 340 }, Color3.new(0.6, 0.4, 0.2))
		local rests = probe("ProbeRests", { 2, 2, 2 }, { 300, 11, 340 }, Color3.new(0.6, 0.4, 0.2))
		check("self-test P7: a block hovering 0.4 studs over the ground is reported, one that rests on it is not", #findHovering({ ground, hover }) == 1 and #findHovering({ ground, rests }) == 0)
		table.remove(extraCovers)

		-- P8: a solid post standing in the middle of the south promenade
		local standing = probe("ProbePost", { 1, 6, 1 }, { 60, 3.2, -34 }, Color3.new(0.5, 0.3, 0.2))
		standing.Chain = { "HamsterPlaza", "ProbePostModel", "ProbePost" }
		standing.Object = "Probe#1"
		local onP = findOnPath({ standing }, { ["Probe#1"] = { Key = "Probe#1", Parts = { standing } } })
		check("self-test P8: a post standing in the middle of the promenade is reported as on a path", #onP == 1 and onP[1].On > 0.9, onP[1] and onP[1].On)
	end

	print(string.format("PASS %d  FAIL %d", results.pass, results.fail))
	print("== done ==")
end)
