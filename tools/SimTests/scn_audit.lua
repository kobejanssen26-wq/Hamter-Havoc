-- Geometry audit of the generated world: solid objects that intersect, objects stuck in buildings, floating props,
-- things below the ground. Runs on the REAL builders (so it catches what the builders produce, not what a saved copy says).
local adv = M.Sim.advance
local results = { pass = 0, fail = 0 }
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end

task.spawn(function()
	M.isServer = true
	local mainServer = find("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	adv(3)

	-- collect solid parts with their group (what they belong to)
	local solids = {}
	local function groupOf(part)
		local chain = {}
		local node = part
		while node and node ~= workspace do
			table.insert(chain, 1, node)
			node = RawData[node].Parent
		end
		local top = chain[1] and RawData[chain[1]].Name or "?"
		local second = chain[2] and RawData[chain[2]].Name or ""
		if top == "PlayerHouses" then
			return top .. "/" .. second
		elseif top == "Environment" then
			return top .. "/" .. second
		elseif top == "HamsterPlaza" then
			return top .. "/" .. (RawData[chain[2]].ClassName == "Model" and second or "plaza")
		end
		return top
	end
	local skipGroups = { ["Environment/Ground"] = true, ["Environment/Beyond"] = true, ["Environment/Boundary"] = true, ["Environment/Backdrop"] = true, ["Environment/GrassPatches"] = true, ["Environment/Promenades"] = true }
	for _, d in M.descendants(workspace) do
		local data = RawData[d]
		if data.Props and data.ClassName ~= "Model" and M.InstanceMethods.IsA(d, "BasePart") and data.Props.CanCollide ~= false and data.Props.Anchored then
			local size = data.Props.Size
			local group = groupOf(d)
			if not skipGroups[group] and math.min(size.X, size.Y, size.Z) >= 0.5 and data.Name ~= "Baseplate" then
				table.insert(solids, { Part = d, Name = data.Name, Group = group, CF = data.Props.CFrame, Size = size })
			end
		end
	end
	print("   solid parts audited:", #solids)

	-- OBB overlap by separating axis, returns the smallest penetration depth (<= 0 means separated)
	local function axes(cf)
		local r = cf.r
		return { Vector3.new(r[1], r[4], r[7]), Vector3.new(r[2], r[5], r[8]), Vector3.new(r[3], r[6], r[9]) }
	end
	local function penetration(a, b)
		local ax, bx = axes(a.CF), axes(b.CF)
		local delta = Vector3.new(b.CF.X - a.CF.X, b.CF.Y - a.CF.Y, b.CF.Z - a.CF.Z)
		local candidates = {}
		for i = 1, 3 do table.insert(candidates, ax[i]) table.insert(candidates, bx[i]) end
		for i = 1, 3 do for j = 1, 3 do
			local c = ax[i]:Cross(bx[j])
			if c.Magnitude > 1e-4 then table.insert(candidates, c.Unit) end
		end end
		local smallest = math.huge
		local ha = { a.Size.X / 2, a.Size.Y / 2, a.Size.Z / 2 }
		local hb = { b.Size.X / 2, b.Size.Y / 2, b.Size.Z / 2 }
		for _, axis in candidates do
			local ra, rb = 0, 0
			for i = 1, 3 do
				ra += ha[i] * math.abs(ax[i]:Dot(axis))
				rb += hb[i] * math.abs(bx[i]:Dot(axis))
			end
			local overlap = ra + rb - math.abs(delta:Dot(axis))
			if overlap <= 0 then return 0 end
			smallest = math.min(smallest, overlap)
		end
		return smallest
	end
	-- world-aligned half extents of a rotated box
	local function halfExtents(p)
		local r = p.CF.r
		local hx, hy, hz = p.Size.X / 2, p.Size.Y / 2, p.Size.Z / 2
		return math.abs(r[1]) * hx + math.abs(r[2]) * hy + math.abs(r[3]) * hz, math.abs(r[4]) * hx + math.abs(r[5]) * hy + math.abs(r[6]) * hz, math.abs(r[7]) * hx + math.abs(r[8]) * hy + math.abs(r[9]) * hz
	end
	for _, p in solids do p.HX, p.HY, p.HZ = halfExtents(p) end
	local function radius(p) return math.sqrt(p.Size.X ^ 2 + p.Size.Y ^ 2 + p.Size.Z ^ 2) / 2 end

	-- 1. solid objects of DIFFERENT groups must not interpenetrate
	local cells = {}
	local CELL = 24
	for index, p in solids do
		local r = radius(p)
		for cx = math.floor((p.CF.X - r) / CELL), math.floor((p.CF.X + r) / CELL) do
			for cz = math.floor((p.CF.Z - r) / CELL), math.floor((p.CF.Z + r) / CELL) do
				local key = cx .. "," .. cz
				cells[key] = cells[key] or {}
				table.insert(cells[key], index)
			end
		end
	end
	local seen, hits = {}, {}
	for _, list in cells do
		for i = 1, #list do
			for j = i + 1, #list do
				local a, b = solids[list[i]], solids[list[j]]
				local key = math.min(list[i], list[j]) .. ":" .. math.max(list[i], list[j])
				if a.Group ~= b.Group and not seen[key] then
					seen[key] = true
					local d = Vector3.new(a.CF.X - b.CF.X, a.CF.Y - b.CF.Y, a.CF.Z - b.CF.Z).Magnitude
					if d < radius(a) + radius(b) then
						local depth = penetration(a, b)
						if depth > 0.6 then
							table.insert(hits, string.format("%s[%s] x %s[%s] depth %.1f at (%.0f,%.0f)", a.Name, a.Group, b.Name, b.Group, depth, a.CF.X, a.CF.Z))
						end
					end
				end
			end
		end
	end
	table.sort(hits)
	for index = 1, math.min(#hits, 25) do print("   HIT", hits[index]) end
	check("no solid objects of different buildings / props interpenetrate", #hits == 0, #hits .. " intersections")

	-- 2. nothing is buried: every solid reaches above the ground
	local buried = 0
	for _, p in solids do
		if p.CF.Y + p.HY < 0.05 then buried += 1 end
	end
	check("no solid part is buried below ground level", buried == 0, buried)

	-- 3. floating props: a solid part whose underside is well above the ground must rest on another solid part
	local floating = {}
	for _, p in solids do
		local bottom = p.CF.Y - p.HY
		if bottom > 0.9 and p.Group ~= "PlayerHouses/" and string.sub(p.Group, 1, 12) ~= "PlayerHouses" then
			local supported = false
			for _, q in solids do
				if q ~= p then
					local qTop = q.CF.Y + q.HY
					local qBottom = q.CF.Y - q.HY
					if math.abs(qTop - bottom) < 0.6 or (qBottom < bottom and qTop > bottom) then
						local dx, dz = math.abs(q.CF.X - p.CF.X), math.abs(q.CF.Z - p.CF.Z)
						if dx < q.HX + p.HX + 0.2 and dz < q.HZ + p.HZ + 0.2 then
							supported = true
							break
						end
					end
				end
			end
			if not supported then table.insert(floating, string.format("%s[%s] y=%.1f at (%.0f,%.0f)", p.Name, p.Group, bottom, p.CF.X, p.CF.Z)) end
		end
	end
	table.sort(floating)
	for index = 1, math.min(#floating, 15) do print("   FLOAT", floating[index]) end
	check("no floating solid decorations outside the houses", #floating == 0, #floating)

	-- the audit must be able to see a real problem: drop a block into the middle of the shop and look for it
	local shop = workspace.HamsterPlaza:FindFirstChild("ShopHouse")
	local counter = shop and M.InstanceMethods.FindFirstChild(shop, "Counter")
	local probe = M.newInstance("Part", true)
	RawData[probe].Name = "AuditProbe"
	RawData[probe].Props.Anchored = true
	RawData[probe].Props.Size = Vector3.new(4, 4, 4)
	RawData[probe].Props.CFrame = RawData[counter].Props.CFrame
	local pp = { Name = "AuditProbe", Group = "Probe", CF = RawData[probe].Props.CFrame, Size = Vector3.new(4, 4, 4) }
	local detected = 0
	for _, q in solids do
		if q.Group ~= "Probe" and penetration(pp, q) > 0.6 then detected += 1 end
	end
	check("self-test: the audit detects a block dropped into the shop", detected >= 1, detected)

	print(string.format("PASS %d  FAIL %d", results.pass, results.fail))
	print("== done ==")
end)
