-- Z-fighting detector for the apartment towers: two visible surfaces that face the same way, lie in (almost) the same plane and
-- overlap draw the SAME pixels, so the GPU flips between them frame by frame (the floor "glitches"). Runs on the REAL builders.
--
-- For houses 1, 2 (north row) and 5, 8 (south row = the north row turned 180 degrees) at every floor count 1..5 it collects every
-- visible anchored part in and around the lot (the house model AND the world around it: ground, paths, promenade), builds the
-- faces of each part (a box has 6, a cylinder its 2 discs, a sphere-mesh blob none), and reports every pair of faces from different
-- parts whose normals are parallel (3 degrees), whose planes are closer than TOL (0.03; 0.05 for upward faces = floors) and whose
-- overlap is larger than 0.02 square studs AND still visible there (the overlap is sampled; a sample buried inside a third opaque part
-- does not count). Opposite-facing touching faces are hidden by each other and are not reported.
--   FIGHT = the planes are the same (gap < 0.005): the surfaces flicker from any distance.
--   NEAR  = the planes are 0.005 .. TOL apart: the surfaces shimmer from a distance or at a grazing angle.
--   "same look" = both parts have the same Material and Color. Of an untextured material (SmoothPlastic, Neon, Glass) that is
--   pixel-identical whichever surface wins (listed, not gated); of a textured one (wood, marble, stone, slate) the patterns differ.
-- A second probe looks at the ground itself: it walks over floor 1 (the whole interior) and floors 2-5, and along the way in through
-- the door, and checks that exactly one surface is on top at every spot.
-- The first block of checks is a self-test of the detector (synthetic plates): it proves the pair search sees flush tops, discs and
-- turned parts and stays quiet about steps, buried faces, touching faces and slits.
local results = { pass = 0, fail = 0 }
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end
local adv = M.Sim.advance

local COS3 = math.cos(math.rad(3))
local TOL_SIDE, TOL_UP, EXACT = 0.03, 0.05, 0.005
local MIN_AREA = 0.02
local OPAQUE = 0.05 -- parts with a Transparency up to this hide what is behind them
local HOUSES = { [1] = true, [2] = true, [5] = true, [8] = true }
-- materials without a texture: two flush surfaces of the same colour are pixel-identical, so flipping between them is invisible
local UNTEXTURED = { SmoothPlastic = true, Plastic = true, Neon = true, Glass = true }

task.spawn(function()
	M.isServer = true
	local mainServer = find("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	adv(3)
	local HouseSystem = require(find("ServerScriptService.Systems.HouseSystem"))
	local HouseBuilder = require(find("ServerScriptService.Systems.WorldBuilder.HouseBuilder"))
	local WorldLayout = require(find("ReplicatedStorage.Modules.WorldLayout"))

	-----------------------------------------------------------------------
	-- parts and faces
	-----------------------------------------------------------------------
	local function chainOf(node, base)
		local names = {}
		while node and node ~= base do
			table.insert(names, 1, RawData[node].Name)
			node = RawData[node].Parent
		end
		return table.concat(names, "/")
	end

	local SKIPPED = { wedge = 0, mesh = 0 }
	-- returns nil when the part is not a visible anchored solid
	local function describe(inst, base)
		local data = RawData[inst]
		local props = data.Props
		if not (props and props.Size and props.CFrame and props.Anchored and M.InstanceMethods.IsA(inst, "BasePart")) then return nil end
		local size, cf = props.Size, props.CFrame
		local transparency = props.Transparency or 0
		if transparency >= 0.95 or math.min(size.X, size.Y, size.Z) < 0.02 then return nil end
		local kind = "box"
		local shape = props.Shape and props.Shape.Name
		if data.ClassName == "WedgePart" or data.ClassName == "CornerWedgePart" or shape == "Wedge" or shape == "CornerWedge" then
			kind = "wedge"
		elseif data.ClassName == "MeshPart" then
			kind = "mesh"
		elseif shape == "Cylinder" then
			kind = "cyl"
		elseif shape == "Ball" then
			kind = "ell"
		else
			for _, child in data.Children do
				local childData = RawData[child]
				if childData.ClassName == "SpecialMesh" then
					local meshType = childData.Props.MeshType and childData.Props.MeshType.Name
					kind = if meshType == "Sphere" then "ell" else "mesh"
				end
			end
		end
		if kind == "wedge" or kind == "mesh" then
			SKIPPED[kind] += 1
			return nil
		end
		local r = cf.r
		local part = {
			Inst = inst,
			Name = data.Name,
			Chain = chainOf(inst, base),
			Kind = kind,
			Px = cf.X, Py = cf.Y, Pz = cf.Z,
			Ex = { r[1], r[4], r[7] }, Ey = { r[2], r[5], r[8] }, Ez = { r[3], r[6], r[9] },
			Hx = size.X / 2, Hy = size.Y / 2, Hz = size.Z / 2,
			Opaque = transparency <= OPAQUE,
			Look = tostring(props.Material and props.Material.Name) .. "|" .. (props.Color and string.format("%.3f,%.3f,%.3f", props.Color.R, props.Color.G, props.Color.B) or "?"),
			Color = props.Color,
			Material = props.Material and props.Material.Name or "?",
			Transparency = transparency,
		}
		part.AX = math.abs(r[1]) * part.Hx + math.abs(r[2]) * part.Hy + math.abs(r[3]) * part.Hz
		part.AY = math.abs(r[4]) * part.Hx + math.abs(r[5]) * part.Hy + math.abs(r[6]) * part.Hz
		part.AZ = math.abs(r[7]) * part.Hx + math.abs(r[8]) * part.Hy + math.abs(r[9]) * part.Hz
		return part
	end

	local function makeFace(part, nx, ny, nz, cx, cy, cz, verts)
		local radius = 0
		for _, v in verts do
			radius = math.max(radius, math.sqrt((v[1] - cx) ^ 2 + (v[2] - cy) ^ 2 + (v[3] - cz) ^ 2))
		end
		return { Part = part, Nx = nx, Ny = ny, Nz = nz, Cx = cx, Cy = cy, Cz = cz, Verts = verts, Radius = radius }
	end

	local function facesOf(part)
		local faces = {}
		if part.Kind == "ell" then return faces end
		local axes = { part.Ex, part.Ey, part.Ez }
		local half = { part.Hx, part.Hy, part.Hz }
		if part.Kind == "cyl" then
			-- a cylinder's axis is local X: its two flat ends are discs (ellipses when Y ~= Z)
			for _, s in { -1, 1 } do
				local a = part.Ex
				local cx, cy, cz = part.Px + s * a[1] * part.Hx, part.Py + s * a[2] * part.Hx, part.Pz + s * a[3] * part.Hx
				local verts = {}
				for step = 0, 23 do
					local t = step / 24 * 2 * math.pi
					local cu, cv = math.cos(t) * part.Hy, math.sin(t) * part.Hz
					table.insert(verts, { cx + part.Ey[1] * cu + part.Ez[1] * cv, cy + part.Ey[2] * cu + part.Ez[2] * cv, cz + part.Ey[3] * cu + part.Ez[3] * cv })
				end
				table.insert(faces, makeFace(part, a[1] * s, a[2] * s, a[3] * s, cx, cy, cz, verts))
			end
			return faces
		end
		for i = 1, 3 do
			local j, k = i % 3 + 1, (i + 1) % 3 + 1
			local a, u, v = axes[i], axes[j], axes[k]
			local hu, hv = half[j], half[k]
			for _, s in { -1, 1 } do
				local cx, cy, cz = part.Px + s * a[1] * half[i], part.Py + s * a[2] * half[i], part.Pz + s * a[3] * half[i]
				local verts = {}
				for _, corner in { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } } do
					table.insert(verts, { cx + u[1] * hu * corner[1] + v[1] * hv * corner[2], cy + u[2] * hu * corner[1] + v[2] * hv * corner[2], cz + u[3] * hu * corner[1] + v[3] * hv * corner[2] })
				end
				table.insert(faces, makeFace(part, a[1] * s, a[2] * s, a[3] * s, cx, cy, cz, verts))
			end
		end
		return faces
	end

	-----------------------------------------------------------------------
	-- occluders: is a point buried inside an opaque solid?
	-----------------------------------------------------------------------
	local CELL = 4
	local function cellKey(cx, cy, cz) return (cx + 600) * 1048576 + (cy + 600) * 1024 + (cz + 600) end
	local function buildGrid(parts)
		local grid, big = {}, {}
		for _, p in parts do
			if p.Opaque then
				local x0, x1 = math.floor((p.Px - p.AX) / CELL), math.floor((p.Px + p.AX) / CELL)
				local y0, y1 = math.floor((p.Py - p.AY) / CELL), math.floor((p.Py + p.AY) / CELL)
				local z0, z1 = math.floor((p.Pz - p.AZ) / CELL), math.floor((p.Pz + p.AZ) / CELL)
				if (x1 - x0 + 1) * (y1 - y0 + 1) * (z1 - z0 + 1) > 300 then
					table.insert(big, p)
				else
					for cx = x0, x1 do for cy = y0, y1 do for cz = z0, z1 do
						local key = cellKey(cx, cy, cz)
						local list = grid[key]
						if not list then list = {} grid[key] = list end
						table.insert(list, p)
					end end end
				end
			end
		end
		return { Grid = grid, Big = big }
	end
	local MARGIN = 0.001
	local function inside(p, x, y, z)
		local dx, dy, dz = x - p.Px, y - p.Py, z - p.Pz
		local lx = dx * p.Ex[1] + dy * p.Ex[2] + dz * p.Ex[3]
		local ly = dx * p.Ey[1] + dy * p.Ey[2] + dz * p.Ey[3]
		local lz = dx * p.Ez[1] + dy * p.Ez[2] + dz * p.Ez[3]
		if p.Kind == "box" then
			return math.abs(lx) < p.Hx - MARGIN and math.abs(ly) < p.Hy - MARGIN and math.abs(lz) < p.Hz - MARGIN
		elseif p.Kind == "cyl" then
			return math.abs(lx) < p.Hx - MARGIN and (ly / p.Hy) ^ 2 + (lz / p.Hz) ^ 2 < 0.98
		end
		return (lx / p.Hx) ^ 2 + (ly / p.Hy) ^ 2 + (lz / p.Hz) ^ 2 < 0.98
	end
	local function buried(occluders, own, x, y, z)
		local list = occluders.Grid[cellKey(math.floor(x / CELL), math.floor(y / CELL), math.floor(z / CELL))]
		if list then
			for _, p in list do
				if p ~= own and inside(p, x, y, z) then return true end
			end
		end
		for _, p in occluders.Big do
			if p ~= own and inside(p, x, y, z) then return true end
		end
		return false
	end

	-- Is the face point (x, y, z) with normal n hidden? Either another opaque solid covers it (a point 0.005 in front of it is
	-- inside that solid) or it faces a surface closer than 0.05 (nobody can look into such a slit).
	local function hidden(occluders, own, x, y, z, nx, ny, nz)
		return buried(occluders, own, x + nx * 0.005, y + ny * 0.005, z + nz * 0.005) or buried(occluders, own, x + nx * 0.05, y + ny * 0.05, z + nz * 0.05)
	end

	-----------------------------------------------------------------------
	-- polygon clipping (convex polygons in a plane)
	-----------------------------------------------------------------------
	local function area(poly)
		local sum = 0
		for i = 1, #poly do
			local a, b = poly[i], poly[i % #poly + 1]
			sum += a[1] * b[2] - b[1] * a[2]
		end
		return sum / 2
	end
	local function clip(subject, clipper) -- clipper is counter-clockwise
		local output = subject
		for i = 1, #clipper do
			local a, b = clipper[i], clipper[i % #clipper + 1]
			local input = output
			output = {}
			if #input == 0 then break end
			local function side(p) return (b[1] - a[1]) * (p[2] - a[2]) - (b[2] - a[2]) * (p[1] - a[1]) end
			local function cross(s, e, ss, es)
				local t = ss / (ss - es)
				return { s[1] + (e[1] - s[1]) * t, s[2] + (e[2] - s[2]) * t }
			end
			local s = input[#input]
			local ss = side(s)
			for _, e in input do
				local es = side(e)
				if es >= 0 then
					if ss < 0 then table.insert(output, cross(s, e, ss, es)) end
					table.insert(output, e)
				elseif ss >= 0 then
					table.insert(output, cross(s, e, ss, es))
				end
				s, ss = e, es
			end
		end
		return output
	end
	local function contains(poly, x, y, margin)
		for i = 1, #poly do
			local a, b = poly[i], poly[i % #poly + 1]
			local length = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
			if length > 0 and ((b[1] - a[1]) * (y - a[2]) - (b[2] - a[2]) * (x - a[1])) / length < (margin or -1e-9) then return false end
		end
		return true
	end

	-- the 2D basis of a face's plane
	local function basisOf(f)
		local ux, uy, uz
		if math.abs(f.Ny) < 0.9 then
			ux, uy, uz = f.Nz, 0, -f.Nx -- n x up
		else
			ux, uy, uz = 0, -f.Nz, f.Ny -- n x x
		end
		local len = math.sqrt(ux * ux + uy * uy + uz * uz)
		ux, uy, uz = ux / len, uy / len, uz / len
		local vx, vy, vz = f.Ny * uz - f.Nz * uy, f.Nz * ux - f.Nx * uz, f.Nx * uy - f.Ny * ux
		return { ux, uy, uz }, { vx, vy, vz }
	end
	local function project(verts, f, u, v)
		local poly = {}
		for _, p in verts do
			local dx, dy, dz = p[1] - f.Cx, p[2] - f.Cy, p[3] - f.Cz
			table.insert(poly, { dx * u[1] + dy * u[2] + dz * u[3], dx * v[1] + dy * v[2] + dz * v[3] })
		end
		if area(poly) < 0 then
			local flipped = {}
			for i = #poly, 1, -1 do table.insert(flipped, poly[i]) end
			poly = flipped
		end
		return poly
	end

	-----------------------------------------------------------------------
	-- the pair search
	-----------------------------------------------------------------------
	-- Groups faces that point the same way (within 5 degrees), sorts every group by plane offset and compares neighbours.
	local function findPairs(faces, occluders)
		local keyed = {}
		for _, f in faces do
			local key = string.format("%d,%d,%d", math.floor(f.Nx * 10 + 0.5), math.floor(f.Ny * 10 + 0.5), math.floor(f.Nz * 10 + 0.5))
			local entry = keyed[key]
			if not entry then entry = { Nx = f.Nx, Ny = f.Ny, Nz = f.Nz, Faces = {} } keyed[key] = entry end
			table.insert(entry.Faces, f)
		end
		local list = {}
		for _, entry in keyed do table.insert(list, entry) end
		table.sort(list, function(a, b) return #a.Faces > #b.Faces end)
		local groups = {}
		for _, entry in list do
			local home
			for _, group in groups do
				if entry.Nx * group.Nx + entry.Ny * group.Ny + entry.Nz * group.Nz >= math.cos(math.rad(5)) then home = group break end
			end
			if not home then home = { Nx = entry.Nx, Ny = entry.Ny, Nz = entry.Nz, Faces = {} } table.insert(groups, home) end
			for _, f in entry.Faces do table.insert(home.Faces, f) end
		end

		local hits = {}
		for _, group in groups do
			local items = group.Faces
			for _, f in items do f.D = f.Cx * group.Nx + f.Cy * group.Ny + f.Cz * group.Nz end
			table.sort(items, function(a, b) return a.D < b.D end)
			for i = 1, #items do
				local a = items[i]
				for j = i + 1, #items do
					local b = items[j]
					if b.D - a.D > 0.35 then break end -- (generous: tilted faces change their offset along the face)
					if a.Part ~= b.Part then
						local dx, dy, dz = b.Cx - a.Cx, b.Cy - a.Cy, b.Cz - a.Cz
						if dx * dx + dy * dy + dz * dz < (a.Radius + b.Radius) ^ 2 and a.Nx * b.Nx + a.Ny * b.Ny + a.Nz * b.Nz >= COS3 then
							local u, v = basisOf(a)
							local pa = project(a.Verts, a, u, v)
							local pb = project(b.Verts, a, u, v)
							local overlap = clip(pb, pa)
							local size = if #overlap >= 3 then area(overlap) else 0
							if size > MIN_AREA then
								-- the overlap, its centre and the distance between the two planes there
								local mx, my = 0, 0
								for _, p in overlap do mx += p[1] / #overlap my += p[2] / #overlap end
								local qx, qy, qz = a.Cx + u[1] * mx + v[1] * my, a.Cy + u[2] * mx + v[2] * my, a.Cz + u[3] * mx + v[3] * my
								local gap = math.abs(b.Nx * (qx - b.Cx) + b.Ny * (qy - b.Cy) + b.Nz * (qz - b.Cz))
								local tol = if a.Ny > 0.9 and b.Ny > 0.9 then TOL_UP else TOL_SIDE
								if gap <= tol then
									-- sample the overlap: where is BOTH surfaces visible (not buried inside a third opaque solid)?
									local minX, maxX, minY, maxY = math.huge, -math.huge, math.huge, -math.huge
									for _, p in overlap do
										minX, maxX, minY, maxY = math.min(minX, p[1]), math.max(maxX, p[1]), math.min(minY, p[2]), math.max(maxY, p[2])
									end
									local samples, visible = 0, 0
									for gx = 1, 5 do
										for gy = 1, 5 do
											local sx, sy = minX + (maxX - minX) * (gx - 0.5) / 5, minY + (maxY - minY) * (gy - 0.5) / 5
											if contains(overlap, sx, sy) then
												samples += 1
												local ax, ay, az = a.Cx + u[1] * sx + v[1] * sy, a.Cy + u[2] * sx + v[2] * sy, a.Cz + u[3] * sx + v[3] * sy
												local off = b.Nx * (ax - b.Cx) + b.Ny * (ay - b.Cy) + b.Nz * (az - b.Cz)
												local bx, by, bz = ax - b.Nx * off, ay - b.Ny * off, az - b.Nz * off
												if not hidden(occluders, a.Part, ax, ay, az, a.Nx, a.Ny, a.Nz) and not hidden(occluders, b.Part, bx, by, bz, b.Nx, b.Ny, b.Nz) then
													visible += 1
												end
											end
										end
									end
									if samples == 0 then samples = 1 end
									local visibleArea = size * visible / samples
									if visibleArea > MIN_AREA then
										table.insert(hits, { A = a, B = b, Area = visibleArea, Gap = gap, X = qx, Y = qy, Z = qz, Fight = gap < EXACT })
									end
								end
							end
						end
					end
				end
			end
		end
		return hits
	end

	-----------------------------------------------------------------------
	-- self-test: the detector must see a z-fight where there is one and stay quiet where there is none
	-----------------------------------------------------------------------
	do
		local folder = Instance.new("Folder")
		folder.Name = "FightSelfTest"
		folder.Parent = workspace
		local RED, BLUE = Color3.fromRGB(220, 60, 60), Color3.fromRGB(60, 60, 220)
		local function box(x, y, z, sx, sy, sz, color, rotation)
			local part = Instance.new("Part")
			part.Anchored = true
			part.Size = Vector3.new(sx, sy, sz)
			part.CFrame = CFrame.new(x, y, z) * (rotation or CFrame.new())
			part.Color = color
			part.Material = Enum.Material.SmoothPlastic
			part.Parent = folder
			return part
		end
		local function run(parts)
			local described = {}
			for _, inst in parts do table.insert(described, describe(inst, folder)) end
			local faces = {}
			for _, p in described do for _, f in facesOf(p) do table.insert(faces, f) end end
			return findPairs(faces, buildGrid(described))
		end
		local function clear() folder:ClearAllChildren() end
		local function up(hits)
			local out = {}
			for _, hit in hits do if hit.A.Ny > 0.9 then table.insert(out, hit) end end
			return out
		end
		local function glassy(part) part.Transparency = 0.5 return part end
		-- 1. two 4x4 plates with the same top (y = 0.5), overlapping 2 x 4 = 8 square studs
		local hits = up(run({ box(5000, 0, 0, 4, 1, 4, RED), box(5002, 0, 0, 4, 1, 4, BLUE) }))
		check("self-test: two flush tops that overlap 8 square studs are reported as FIGHT (8.0)", #hits == 1 and hits[1].Fight and math.abs(hits[1].Area - 8) < 0.2, #hits == 1 and string.format("%.2f", hits[1].Area) or #hits)
		clear()
		-- 2. a see-through plate 0.2 above: both tops are visible, but 0.2 apart is a clear step (not reported); 0.02 apart is NEAR
		check("self-test: tops 0.2 apart are not reported", #up(run({ box(5000, 0, 0, 4, 1, 4, RED), glassy(box(5002, 0.2, 0, 4, 1, 4, BLUE)) })) == 0)
		clear()
		hits = up(run({ box(5000, 0, 0, 4, 1, 4, RED), glassy(box(5002, 0.02, 0, 4, 1, 4, BLUE)) }))
		check("self-test: tops 0.02 apart (one see-through) are reported as NEAR", #hits == 1 and not hits[1].Fight, #hits)
		clear()
		-- 3. the same pair but the higher plate is opaque: it covers the lower top, nothing to see
		check("self-test: a top 0.02 under an opaque plate is hidden, not reported", #up(run({ box(5000, 0, 0, 4, 1, 4, RED), box(5002, 0.02, 0, 4, 1, 4, BLUE) })) == 0)
		clear()
		-- 4. flush tops buried inside a third opaque solid are not visible: not reported
		check("self-test: a flush pair buried inside a third opaque solid is not reported", #up(run({ box(5000, 0, 0, 4, 1, 4, RED), box(5002, 0, 0, 4, 1, 4, BLUE), box(5001, 1, 0, 12, 4, 12, RED) })) == 0)
		clear()
		-- 5. a disc whose top is flush with a plate (cylinder end = circle of radius 1: ~3.1 square studs)
		local disc = box(5000, 0.45, 0, 0.1, 2, 2, BLUE, CFrame.Angles(0, 0, math.rad(90)))
		disc.Shape = Enum.PartType.Cylinder
		hits = up(run({ box(5000, 0, 0, 8, 1, 8, RED), disc }))
		check("self-test: a disc flush with a plate is reported (area of the disc)", #hits == 1 and hits[1].Fight and hits[1].Area > 2.9 and hits[1].Area < 3.2, #hits == 1 and string.format("%.2f", hits[1].Area) or #hits)
		clear()
		-- 6. rotated parts: two 6x2 plates crossing at 90 degrees overlap 2 x 2
		hits = up(run({ box(5000, 0, 0, 6, 1, 2, RED), box(5000, 0, 0, 6, 1, 2, BLUE, CFrame.Angles(0, math.rad(90), 0)) }))
		check("self-test: crossed plates (one turned 90 degrees) with flush tops overlap 4 square studs", #hits == 1 and math.abs(hits[1].Area - 4) < 0.2, #hits == 1 and string.format("%.2f", hits[1].Area) or #hits)
		clear()
		-- 7. a plate tilted by 5 degrees is not parallel (3 degree limit); a plate resting on another (opposite faces) is fine
		check("self-test: a plate tilted by 5 degrees is not reported", #up(run({ box(5000, 0, 0, 4, 1, 4, RED), glassy(box(5000, 0.6, 0, 4, 1, 4, BLUE, CFrame.Angles(0, 0, math.rad(5)))) })) == 0)
		clear()
		check("self-test: a plate resting on another (touching, opposite faces) is not reported", #run({ box(5000, 0, 0, 4, 1, 4, RED), box(5000, 1, 0, 3, 1, 3, BLUE) }) == 0)
		clear()
		-- 8. two plates 0.01 above a floor share their bottoms, but nobody can see into the slit: not reported
		check("self-test: faces that look into a 0.01 slit are not reported", #run({ box(5000, 0, 0, 20, 1, 20, RED), box(5000, 0.57, 0, 4, 0.06, 4, BLUE), box(5000, 0.58, 0, 2, 0.08, 2, RED) }) == 0)
		clear()
		folder:Destroy()
	end

	-----------------------------------------------------------------------
	-- collect the world once (everything that is not a house), then every house in every floor state
	-----------------------------------------------------------------------
	local statics = {}
	for _, d in M.descendants(workspace) do
		local top = d
		while RawData[top].Parent and RawData[top].Parent ~= workspace do top = RawData[top].Parent end
		if RawData[top].Name ~= "PlayerHouses" then
			local part = describe(d, workspace)
			if part then table.insert(statics, part) end
		end
	end
	print("   static world parts (outside the houses):", #statics)

	local signatures = {} -- signature -> summary over every house / floor count
	local scans = 0

	-- the probe: what is on top of the ground at a point of a house (local x, z) around the height y0?
	local function newProbe(faces, hcf)
		local ups = {}
		for _, f in faces do
			if f.Ny > 0.995 then table.insert(ups, f) end
		end
		local index = {}
		for _, f in ups do
			local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
			for _, p in f.Verts do
				minX, maxX, minZ, maxZ = math.min(minX, p[1]), math.max(maxX, p[1]), math.min(minZ, p[3]), math.max(maxZ, p[3])
			end
			f.MinX, f.MaxX, f.MinZ, f.MaxZ = minX, maxX, minZ, maxZ
			for cx = math.floor(minX / CELL), math.floor(maxX / CELL) do
				for cz = math.floor(minZ / CELL), math.floor(maxZ / CELL) do
					local key = cx * 4096 + cz
					local list = index[key]
					if not list then list = {} index[key] = list end
					table.insert(list, f)
				end
			end
		end
		-- horizontal polygon test for an up-facing face (flat in xz)
		local function covers(f, x, z)
			if x < f.MinX or x > f.MaxX or z < f.MinZ or z > f.MaxZ then return false end
			if not f.Poly then
				local poly = {}
				for _, p in f.Verts do table.insert(poly, { p[1], p[3] }) end
				if area(poly) < 0 then
					local flipped = {}
					for i = #poly, 1, -1 do table.insert(flipped, poly[i]) end
					poly = flipped
				end
				f.Poly = poly
			end
			return contains(f.Poly, x, z, 0.03) -- (a spot right at the rim of a disc is not a fight, just an edge)
		end
		-- all up-facing surfaces under the world point (x, z) with y in [lo, hi], highest first
		return function(localX, localZ, lo, hi)
			local wp = hcf * Vector3.new(localX, 0, localZ)
			local found = {}
			for _, f in index[math.floor(wp.X / CELL) * 4096 + math.floor(wp.Z / CELL)] or {} do
				local y = f.Cy
				if y >= lo and y <= hi and covers(f, wp.X, wp.Z) then table.insert(found, f) end
			end
			table.sort(found, function(a, b) return a.Cy > b.Cy end)
			return found
		end
	end

	local function describeFace(f)
		return string.format("%s [%s y=%.3f]", f.Part.Chain, f.Part.Material, f.Cy)
	end

	local floorProbe = {} -- signature -> { count, example }
	local doorProfiles = {}

	for _, house in HouseSystem.all() do
		if HOUSES[house.Index] then
			local hcf = house.CFrame
			-- the world box of the lot (+ margin) that matters for this house
			local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
			for _, corner in { { -42, -12 }, { 42, -12 }, { 42, 100 }, { -42, 100 } } do
				local w = hcf * Vector3.new(corner[1], 0, corner[2])
				minX, maxX, minZ, maxZ = math.min(minX, w.X), math.max(maxX, w.X), math.min(minZ, w.Z), math.max(maxZ, w.Z)
			end
			local nearStatics = {}
			for _, p in statics do
				if p.Px + p.AX >= minX and p.Px - p.AX <= maxX and p.Pz + p.AZ >= minZ and p.Pz - p.AZ <= maxZ then table.insert(nearStatics, p) end
			end
			for count = 1, 5 do
				HouseBuilder.setFloors(house, count, Random.new(count))
				for slotIndex in house.Slots do HouseBuilder.setWheel(house, slotIndex, true) end -- (an owned house has its wheels standing on the floors)
				adv(0.2)
				local parts = {}
				for _, p in nearStatics do table.insert(parts, p) end
				for _, d in M.descendants(house.Model) do
					local part = describe(d, house.Model)
					if part then table.insert(parts, part) end
				end
				local faces = {}
				for _, p in parts do
					for _, f in facesOf(p) do table.insert(faces, f) end
				end
				local occluders = buildGrid(parts)
				local hits = findPairs(faces, occluders)
				scans += 1
				local inv = hcf:Inverse()
				local seenThisScan = {}
				for _, hit in hits do
					local nameA, nameB = hit.A.Part.Chain, hit.B.Part.Chain
					if nameA > nameB then nameA, nameB = nameB, nameA end
					local localN = inv:VectorToWorldSpace(Vector3.new(hit.A.Nx, hit.A.Ny, hit.A.Nz))
					local lp = inv * Vector3.new(hit.X, hit.Y, hit.Z)
					local plane = lp.X * localN.X + lp.Y * localN.Y + lp.Z * localN.Z
					local sig = string.format("%s  x  %s  n=(%d,%d,%d) plane=%.2f", nameA, nameB, math.floor(localN.X + 0.5), math.floor(localN.Y + 0.5), math.floor(localN.Z + 0.5), plane)
					local entry = signatures[sig]
					if not entry then
						entry = { Sig = sig, A = hit.A.Part, B = hit.B.Part, Gap = hit.Gap, Fight = hit.Fight, MaxArea = 0, Floors = {}, Houses = {}, Plane = plane, Normal = localN, Example = lp,
							SameLook = hit.A.Part.Look == hit.B.Part.Look }
						signatures[sig] = entry
					end
					seenThisScan[sig] = (seenThisScan[sig] or 0) + hit.Area
					entry.Floors[count] = true
					entry.Houses[house.Index] = true
					entry.Gap = math.max(entry.Gap, hit.Gap)
					if hit.Area > (entry.BestPiece or 0) then entry.BestPiece = hit.Area entry.Example = lp end
				end
				for sig, total in seenThisScan do
					signatures[sig].MaxArea = math.max(signatures[sig].MaxArea, total)
				end

				-----------------------------------------------------------
				-- ground probe: floor 1 interior grid, floors 2..count interior grids, and the door transition
				-----------------------------------------------------------
				if house.Index == 1 or house.Index == 5 then
					local probe = newProbe(faces, hcf)
					for floor = 1, count do
						local y0 = WorldLayout.floorY(floor)
						local hw = WorldLayout.FloorHalfWidth[floor]
						local x = -hw + 0.5
						while x <= hw - 0.5 do
							local z = WorldLayout.TowerFront + 1.5
							while z <= WorldLayout.TowerBack - 1.5 do
								local found = probe(x, z, y0 - 0.35, y0 + 0.45)
								-- the ground is hidden where furniture stands on it: only judge spots whose top surface is within 0.45 of the floor
								if #found >= 2 then
									local top = found[1]
									local rivals = {}
									for index = 2, #found do
										if top.Cy - found[index].Cy <= TOL_UP then table.insert(rivals, found[index]) end
									end
									if #rivals > 0 then
										local rival = rivals[1]
										-- is the rival buried below something that is not the top face? Its own sample must be visible
										local wp = hcf * Vector3.new(x, 0, z)
										if not hidden(occluders, rival.Part, wp.X, rival.Cy, wp.Z, 0, 1, 0) and not hidden(occluders, top.Part, wp.X, top.Cy, wp.Z, 0, 1, 0) then
											local key = string.format("floor%d: %s  vs  %s  (gap %.3f)", floor, describeFace(top), describeFace(rival), top.Cy - rival.Cy)
											local e = floorProbe[key]
											if not e then e = { Count = 0, Floor = floor, Gap = top.Cy - rival.Cy, Houses = {}, Counts = {}, Example = { x, z } } floorProbe[key] = e end
											e.Count += 1
											e.Houses[house.Index] = true
											e.Counts[count] = true
										end
									end
								end
								z += 1
							end
							x += 1
						end
					end

					-- the way in through the door (house 1 / 5, only recorded at floors = 1 and 3 to keep the output short)
					if count == 1 or count == 3 then
						for _, x in { 0, 4.5, -4.5 } do
							local profile, last = {}, nil
							local z = 2
							while z <= 40 do
								local found = probe(x, z, -0.2, 1.5)
								local top = found[1]
								local tag = top and string.format("%s [%s] y=%.2f", top.Part.Name, top.Part.Material, top.Cy) or "(nothing)"
								local rivalTag = ""
								if top then
									local wp = hcf * Vector3.new(x, 0, z)
									for index = 2, #found do
										if top.Cy - found[index].Cy <= TOL_UP and not hidden(occluders, found[index].Part, wp.X, found[index].Cy, wp.Z, 0, 1, 0) then
											rivalTag = rivalTag .. string.format(" + FIGHTS WITH %s [%s] y=%.3f", found[index].Part.Name, found[index].Part.Material, found[index].Cy)
										end
									end
								end
								local full = tag .. rivalTag
								if full ~= last then table.insert(profile, string.format("z=%5.1f  %s", z, full)) last = full end
								z += 0.1
							end
							table.insert(doorProfiles, { House = house.Index, Count = count, X = x, Lines = profile })
						end
					end
				end
			end
		end
	end
	print(string.format("   scans: %d (4 houses x 5 floor counts); skipped (not analysed): %d wedge parts, %d mesh parts", scans, SKIPPED.wedge, SKIPPED.mesh))

	-----------------------------------------------------------------------
	-- report
	-----------------------------------------------------------------------
	local list = {}
	for _, e in signatures do table.insert(list, e) end
	table.sort(list, function(a, b)
		if a.Fight ~= b.Fight then return a.Fight end
		return a.MaxArea > b.MaxArea
	end)
	local function setText(set)
		local keys = {}
		for k in set do table.insert(keys, k) end
		table.sort(keys)
		return table.concat(keys, ",")
	end
	local ZONES = { "Tower", "Yard", "Wheels", "World" }
	local function zone(e)
		local c = e.A.Chain .. "|" .. e.B.Chain
		if string.find(c, "Tower/", 1, true) then return "Tower" end
		if string.find(c, "Yard/", 1, true) then return "Yard" end
		if string.find(c, "Wheels/", 1, true) then return "Wheels" end
		return "World"
	end
	local counts = {}
	for _, z in ZONES do counts[z] = { fight = 0, near = 0, fightLook = 0 } end
	for _, e in list do
		local z = zone(e)
		if e.Fight then
			if e.SameLook then counts[z].fightLook += 1 else counts[z].fight += 1 end
		else
			counts[z].near += 1
		end
	end
	print(string.format("\n   distinct z-fight signatures: %d", #list))
	for _, z in ZONES do
		print(string.format("   %-6s FIGHT (different look) %d   FIGHT (same look) %d   NEAR %d", z, counts[z].fight, counts[z].fightLook, counts[z].near))
	end
	local function show(e)
		print(string.format("   %-6s %s %-4s area %7.2f gap %.3f  floors=%s houses=%s  %s  at local (%.1f, %.2f, %.1f)  A=%s/%s B=%s/%s", zone(e), if e.Fight then "FIGHT" else "NEAR ", if e.SameLook then "same" else "diff",
			e.MaxArea, e.Gap, setText(e.Floors), setText(e.Houses), e.Sig, e.Example.X, e.Example.Y, e.Example.Z, e.A.Material, e.A.Look:match("|(.*)") or "", e.B.Material, e.B.Look:match("|(.*)") or ""))
	end
	print("\n   --- FIGHT between surfaces of DIFFERENT look (visible flicker), by visible overlap area (largest sum within one scan) ---")
	for _, e in list do if e.Fight and not e.SameLook then show(e) end end
	print("\n   --- NEAR (planes 0.005 .. 0.05 apart: shimmer from a distance), first 25 ---")
	local shown = 0
	for _, e in list do if not e.Fight and shown < 25 then shown += 1 show(e) end end
	print("\n   --- FIGHT between surfaces of the SAME look and a TEXTURED material (gated: the patterns can differ) ---")
	for _, e in list do if e.Fight and e.SameLook and not UNTEXTURED[e.A.Material] then show(e) end end
	print("\n   --- FIGHT between surfaces of the SAME look and an untextured material (pixel-identical, not gated), first 12 ---")
	shown = 0
	for _, e in list do if e.Fight and e.SameLook and UNTEXTURED[e.A.Material] and shown < 12 then shown += 1 show(e) end end

	print("\n   --- ground probe: spots where two up-facing surfaces are within 0.05 of each other on the walking surface ---")
	local probeList = {}
	for key, e in floorProbe do table.insert(probeList, { Key = key, E = e }) end
	table.sort(probeList, function(a, b) return a.E.Count > b.E.Count end)
	for index = 1, math.min(#probeList, 25) do
		local e = probeList[index].E
		print(string.format("   %5d spots  houses=%s floor counts=%s  e.g. local x=%.1f z=%.1f   %s", e.Count, setText(e.Houses), setText(e.Counts), e.Example[1], e.Example[2], probeList[index].Key))
	end

	print("\n   --- the way in through the door (topmost up-facing surface, local x = 0 / +-4.5, z = 2 .. 40) ---")
	for _, profile in doorProfiles do
		if profile.House == 1 and profile.Count == 1 then
			print(string.format("   house %d, %d floor(s), x=%.1f:", profile.House, profile.Count, profile.X))
			for _, line in profile.Lines do print("      " .. line) end
		end
	end

	-----------------------------------------------------------------------
	-- verdicts
	-----------------------------------------------------------------------
	local tower = { fight = {}, near = {}, fightLook = {}, fightLookSide = {} }
	local floor1, entrance, lotGround = {}, {}, {}
	for _, e in list do
		local lp = e.Example
		local flat = math.abs(e.Normal.Y) > 0.9
		if zone(e) == "Tower" then
			if e.Fight and e.SameLook then
				table.insert(if UNTEXTURED[e.A.Material] then tower.fightLookSide else tower.fightLook, e)
			else
				table.insert(if e.Fight then tower.fight else tower.near, e)
			end
		end
		-- the lobby of floor 1: inside the walls (local x -21.7..21.7, z 26.3..69.7), surfaces up to 0.4 above the floor top
		if flat and math.abs(lp.X) <= 21.7 and lp.Z >= WorldLayout.TowerFront + 0.3 and lp.Z <= WorldLayout.TowerBack - 0.3 and lp.Y > WorldLayout.FloorBase - 0.3 and lp.Y < WorldLayout.FloorBase + 0.4 then
			table.insert(floor1, e)
		end
		-- the way in: gate line to the lobby, the width of the driveway + steps (local x -9..9, z -3..27), ground level
		if flat and math.abs(lp.X) <= 9 and lp.Z >= -3 and lp.Z <= WorldLayout.TowerFront + 1 and lp.Y < WorldLayout.FloorBase + 0.4 and not e.SameLook and e.Fight then
			table.insert(entrance, e)
		end
		-- the whole lot at ground level (x +-34, z 0..86): the lawn, driveway, steps, altar, pond...
		if flat and math.abs(lp.X) <= WorldLayout.LotHalfWidth and lp.Z >= 0 and lp.Z <= WorldLayout.LotDepth and lp.Y < 1.2 and not e.SameLook and e.Fight and zone(e) ~= "Tower" then
			table.insert(lotGround, e)
		end
	end
	local function names(entries)
		local out = {}
		for index = 1, math.min(#entries, 6) do table.insert(out, entries[index].Sig) end
		return table.concat(out, " ;; ")
	end
	check("tower: no two visible surfaces of different look are flush (same direction, same plane) - no z-fighting", #tower.fight == 0, #tower.fight .. " signatures")
	check("tower: no two flush surfaces of the same colour and a TEXTURED material (wood, marble, stone: the patterns would differ)", #tower.fightLook == 0, #tower.fightLook .. " signatures: " .. names(tower.fightLook))
	print(string.format("  [info] %d flush surface pairs of the same colour and an untextured material (sofa arm on sofa base, corner post on wall...): pixel-identical, not gated", #tower.fightLookSide))
	check("tower: no near-coplanar (0.005-0.05 apart) overlapping surfaces that shimmer at a distance", #tower.near == 0, #tower.near .. " signatures")
	check("floor 1 lobby (inside the walls): no two surfaces fight over the floor, the pad or the rugs", #floor1 == 0, #floor1 .. " signatures: " .. names(floor1))
	check("the way in (gate line to the lobby, x +-9): no two ground surfaces of different look are flush", #entrance == 0, #entrance .. " signatures: " .. names(entrance))
	check("the lot outside the tower (lawn, driveway, apron, altar...): no two ground surfaces of different look are flush", #lotGround == 0, #lotGround .. " signatures: " .. names(lotGround))
	local floorFights = 0
	for _, e in probeList do floorFights += e.E.Count end
	check("walking probe: exactly one surface is on top at every sampled spot of every floor interior (floors 1-5)", floorFights == 0, floorFights .. " spots")
	local doorFights = 0
	for _, profile in doorProfiles do
		for _, line in profile.Lines do if string.find(line, "FIGHTS WITH", 1, true) then doorFights += 1 end end
	end
	check("the way through the door (house 1 and 5, 1 and 3 floors): no two surfaces fight under the player's feet", doorFights == 0, doorFights .. " profile segments")
	print(string.format("\nPASS %d  FAIL %d", results.pass, results.fail))
end)
