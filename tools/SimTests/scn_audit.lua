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

	-- 4. the walking route plaza -> Leaderboard Hall is clear: no collidable part stands in the lane x = -4.5..4.5, z = -100..-31
	-- (every collidable part counts here, even thin ones; the floor itself - thinner than 0.5 and lower than 0.5 studs - does not)
	local function laneBlockers(x0, x1, z0, z1)
		local found = {}
		for _, d in M.descendants(workspace) do
			local data = RawData[d]
			if data.Props and M.InstanceMethods.IsA(d, "BasePart") and data.Props.CanCollide ~= false and data.Props.Anchored and data.Name ~= "Baseplate" then
				local cf, size = data.Props.CFrame, data.Props.Size
				local r = cf.r
				local hx = math.abs(r[1]) * size.X / 2 + math.abs(r[2]) * size.Y / 2 + math.abs(r[3]) * size.Z / 2
				local hy = math.abs(r[4]) * size.X / 2 + math.abs(r[5]) * size.Y / 2 + math.abs(r[6]) * size.Z / 2
				local hz = math.abs(r[7]) * size.X / 2 + math.abs(r[8]) * size.Y / 2 + math.abs(r[9]) * size.Z / 2
				local top, bottom = cf.Y + hy, cf.Y - hy
				local isFloor = top < 0.5
				if not isFloor and bottom < 6.5 and top > 0.5 and cf.X + hx > x0 and cf.X - hx < x1 and cf.Z + hz > z0 and cf.Z - hz < z1 then
					table.insert(found, string.format("%s at (%.0f,%.1f,%.0f) size %.1fx%.1fx%.1f", data.Name, cf.X, cf.Y, cf.Z, size.X, size.Y, size.Z))
				end
			end
		end
		return found
	end
	local blockers = laneBlockers(-4.5, 4.5, -100, -31)
	for index = 1, math.min(#blockers, 10) do print("   BLOCKS", blockers[index]) end
	check("the route from the plaza to the Leaderboard Hall is clear (no fountain, sign or prop in the lane)", #blockers == 0, #blockers)
	check("self-test: the lane check does see a block dropped into the route", (function()
		local probe = M.newInstance("Part", true)
		RawData[probe].Name = "RouteProbe"
		RawData[probe].Props.Anchored = true
		RawData[probe].Props.Size = Vector3.new(6, 4, 6)
		RawData[probe].Props.CFrame = CFrame.new(0, 2, -60)
		M.setParent(probe, workspace)
		local seen = #laneBlockers(-4.5, 4.5, -100, -31)
		M.InstanceMethods.Destroy(probe)
		return seen >= 1
	end)())


	-- every tree: the trunk reaches INTO a crown (not floating above it, not a gap), stands on one spot, trunk is not wider than the crown
	local treeCount, treeBad = 0, {}
	for _, d in M.descendants(workspace) do
		local data = RawData[d]
		if data.ClassName == "Model" and string.sub(data.Name, 1, 5) == "Tree_" then
			treeCount += 1
			local trunk, crowns = nil, {}
			for _, child in M.descendants(d) do
				local name = RawData[child].Name
				if name == "Trunk" then trunk = child
				elseif string.sub(name, 1, 6) == "Canopy" or string.sub(name, 1, 7) == "Needles" then table.insert(crowns, child) end
			end
			local ok = false
			if trunk and #crowns > 0 then
				local tcf, tsz = RawData[trunk].Props.CFrame, RawData[trunk].Props.Size
				local topY = tcf.Y + tsz.X / 2 -- (a cylinder's length is its X size, standing up)
				for _, crown in crowns do
					local ccf, csz = RawData[crown].Props.CFrame, RawData[crown].Props.Size
					local dx, dy, dz = (tcf.X - ccf.X) / (csz.X / 2), (topY - ccf.Y) / (csz.Y / 2), (tcf.Z - ccf.Z) / (csz.Z / 2)
					if dx * dx + dy * dy + dz * dz <= 0.8 then ok = true end
				end
			end
			if not ok then table.insert(treeBad, data.Name .. "@" .. (trunk and string.format("%.0f,%.0f", RawData[trunk].Props.CFrame.X, RawData[trunk].Props.CFrame.Z) or "no trunk")) end
		end
	end
	check("all " .. treeCount .. " trees have their trunk reaching into the crown (no floating crowns, any scale)", treeCount > 100 and #treeBad == 0, #treeBad .. " bad, e.g. " .. tostring(treeBad[1]))

	-- 5. EVERY visible decoration (also the non-colliding ones: moss, bushes, rocks, flowers, hills, lamps...) rests on something.
	-- Only these are meant to hang in the air: the wheel's bulbs, sign and pointer, the shop lamps.
	do
		local HANGING = { Bulb = true, ShopLamp = true, Sign = true }
		local all = {}
		for _, d in M.descendants(workspace) do
			local data = RawData[d]
			if data.Props and data.Props.Size and data.Props.CFrame and M.InstanceMethods.IsA(d, "BasePart") and data.Props.Anchored and data.Props.Transparency ~= 1 then
				local chain, node = {}, d
				while node and node ~= workspace do table.insert(chain, 1, RawData[node].Name) node = RawData[node].Parent end
				local p = { Name = data.Name, Path = table.concat(chain, "/"), CF = data.Props.CFrame, Size = data.Props.Size }
				p.HX, p.HY, p.HZ = halfExtents(p)
				table.insert(all, p)
			end
		end
		local air = {}
		for _, p in all do
			local bottom = p.CF.Y - p.HY
			if bottom > 0.45 and not HANGING[p.Name] and not string.find(p.Path, "LuckyWheel/Pointer", 1, true) and not string.find(p.Path, "Clouds", 1, true) and not string.find(p.Path, "PlayerHouses/House%d/Tower") then
				local supported = false
				for _, q in all do
					if q ~= p then
						local qTop, qBottom = q.CF.Y + q.HY, q.CF.Y - q.HY
						if (math.abs(qTop - bottom) < 0.7 or (qBottom < bottom - 0.05 and qTop > bottom + 0.05)) and math.abs(q.CF.X - p.CF.X) < q.HX + p.HX and math.abs(q.CF.Z - p.CF.Z) < q.HZ + p.HZ then
							supported = true
							break
						end
					end
				end
				if not supported then table.insert(air, string.format("%s at (%.0f,%.1f,%.0f)", p.Path, p.CF.X, p.CF.Y, p.CF.Z)) end
			end
		end
		for index = 1, math.min(#air, 10) do print("   AIR", air[index]) end
		check("no decoration of any kind hovers in the air (" .. #all .. " visible parts checked, hanging signs / bulbs / lamps excepted)", #air == 0, #air)
		-- a probe the audit must catch: a moss clump floating a metre above the lawn
		local moss = { Name = "ProbeMoss", Path = "Environment/ProbeMoss", CF = CFrame.new(40, 3, 40), Size = Vector3.new(2, 1, 2) }
		moss.HX, moss.HY, moss.HZ = halfExtents(moss)
		local held = false
		for _, q in all do
			if math.abs(q.CF.X - 40) < q.HX + moss.HX and math.abs(q.CF.Z - 40) < q.HZ + moss.HZ and (math.abs(q.CF.Y + q.HY - (moss.CF.Y - moss.HY)) < 0.7) then held = true end
		end
		check("self-test: a clump floating above the lawn would not count as supported", not held)

		-- trees: crown and trunk must not sit inside a wall, a building or a mountain
		local treeIntruders = {}
		local wedges = {}
		for _, q in all do
			if string.find(q.Path, "Backdrop", 1, true) or string.find(q.Path, "Cliff", 1, true) then table.insert(wedges, q) end
		end
		for _, d in M.descendants(workspace) do
			local data = RawData[d]
			if data.ClassName == "Model" and string.sub(data.Name, 1, 5) == "Tree_" then
				for _, part in M.descendants(d) do
					local pd = RawData[part]
					if pd.Props and pd.Props.Size and pd.Props.CFrame and M.InstanceMethods.IsA(part, "BasePart") and pd.ClassName ~= "WedgePart" then
						local tp = { Name = pd.Name, CF = pd.Props.CFrame, Size = pd.Props.Size * 0.8, Group = "Tree" }
						tp.HX, tp.HY, tp.HZ = halfExtents(tp)
						for _, q in solids do
							local own, node = false, q.Part
							while node and node ~= workspace do
								if node == d then own = true break end
								node = RawData[node].Parent
							end
							if not own and q.Group ~= "Tree" and not string.find(q.Name, "Hill", 1, true) and math.abs(q.CF.X - tp.CF.X) < q.HX + tp.HX and math.abs(q.CF.Z - tp.CF.Z) < q.HZ + tp.HZ and math.abs(q.CF.Y - tp.CF.Y) < q.HY + tp.HY then
								if penetration(tp, q) > 0.8 and not (string.sub(q.Name, 1, 5) == "Tree_") then
									table.insert(treeIntruders, string.format("%s in %s[%s] at (%.0f,%.0f)", pd.Name, q.Name, q.Group, tp.CF.X, tp.CF.Z))
									break
								end
							end
						end
					end
				end
			end
		end
		table.sort(treeIntruders)
		for index = 1, math.min(#treeIntruders, 10) do print("   TREEHIT", treeIntruders[index]) end
		check("no tree part stands inside a wall, building, fence or other solid", #treeIntruders == 0, #treeIntruders)
	end

	-- two physical shops, each opening its own shop, and the wheel behind them
	local plazaFolder = workspace.HamsterPlaza
	local function shopPrompt(modelName)
		local model = plazaFolder:FindFirstChild(modelName)
		local counter = model and M.InstanceMethods.FindFirstChild(model, "Counter")
		return model, counter and counter:FindFirstChildOfClass("ProximityPrompt")
	end
	local coinsModel, coinsPrompt = shopPrompt("CoinsShop")
	local robuxModel, robuxPrompt = shopPrompt("RobuxShop")
	check("a Coins Shop and a Robux Shop building exist (the old single ShopHouse is gone)", coinsModel ~= nil and robuxModel ~= nil and plazaFolder:FindFirstChild("ShopHouse") == nil)
	check("each has an [F] prompt that opens its OWN window (Coins Shop -> Shop, Robux Shop -> RobuxShop)", coinsPrompt ~= nil and robuxPrompt ~= nil and coinsPrompt:GetAttribute("OpenUI") == "Shop" and robuxPrompt:GetAttribute("OpenUI") == "RobuxShop")
	local ShopConfigModule = require(find("ReplicatedStorage.Modules.ShopConfig"))
	local function categoryKind(id)
		for _, c in ShopConfigModule.categories() do if c.Id == id then return c end end
	end
	local coinsCat, robuxCat = categoryKind(coinsPrompt:GetAttribute("Focus")), categoryKind(robuxPrompt:GetAttribute("Focus"))
	check("the Coins Shop opens on a cash category and the Robux Shop on the game pass category", coinsCat ~= nil and robuxCat ~= nil and coinsCat.Id ~= "Gamepasses" and robuxCat.Id == "Gamepasses", tostring(coinsPrompt:GetAttribute("Focus")) .. "/" .. tostring(robuxPrompt:GetAttribute("Focus")))
	local cx, rx = RawData[coinsModel:FindFirstChild("Counter", true)].Props.CFrame.X, RawData[robuxModel:FindFirstChild("Counter", true)].Props.CFrame.X
	check("the shops are mirrored left/right with a walkway of at least 10 studs between them", cx < 0 and rx > 0 and (rx - cx) - 16 >= 10, string.format("%.0f/%.0f", cx, rx))
	local sign1 = coinsModel:FindFirstChild("Sign")
	check("they carry their own sign text", sign1 ~= nil)

	-- the Like & Favorite board: informational, makes no claims, uses only Roblox's own invite window
	do
		local board = plazaFolder:FindFirstChild("FavoritesBoard")
		check("a Like & Favorite board stands in the plaza, near the guest spawn (not in a path)", board ~= nil and (function()
			local spawnPart = workspace.SpawnLocations:FindFirstChild("PlazaSpawn")
			local boardPart = board and board:FindFirstChild("Board")
			if not spawnPart or not boardPart then return false end
			local a, b = RawData[spawnPart].Props.CFrame.Position, RawData[boardPart].Props.CFrame.Position
			local flat = math.sqrt((a.X - b.X) ^ 2 + (a.Z - b.Z) ^ 2)
			return flat < 16 and math.abs(b.Z) > 14 and math.abs(b.X) > 20
		end)())
		local texts = {}
		for _, d in M.descendants(board) do
			if RawData[d].ClassName == "TextLabel" then table.insert(texts, string.lower(tostring(RawData[d].Props.Text))) end
		end
		local all = table.concat(texts, "|")
		check("the board explains Like and Favorite in short words", string.find(all, "like the game", 1, true) ~= nil and string.find(all, "favorites", 1, true) ~= nil and string.find(all, "invite friends", 1, true) ~= nil)
		check("it never claims that anything was liked, favorited or rewarded", string.find(all, "thank", 1, true) == nil and string.find(all, "reward", 1, true) == nil and string.find(all, "you liked", 1, true) == nil and string.find(all, "free ", 1, true) == nil)
		local prompt
		for _, d in M.descendants(board) do if RawData[d].ClassName == "ProximityPrompt" then prompt = d end end
		check("its only action is the invite prompt (answered by the client with Roblox's invite window), nothing is granted by the server", prompt ~= nil and prompt:GetAttribute("InviteFriends") == true and prompt:GetAttribute("OpenUI") == nil and prompt:GetAttribute("SpinWheel") == nil)
		check("its pictures are marked for the client (WorldIcon + IconName) and drawn from the icon library", (function()
			local n = 0
			for _, d in M.descendants(board) do if RawData[d].Name == "IconHost" and RawData[d].Attributes.IconName ~= nil and M.InstanceMethods.HasTag(d, "WorldIcon") then n += 1 end end
			return n == 3
		end)())
	end

	-- the audit must be able to see a real problem: drop a block into the middle of the shop and look for it
	local shop = workspace.HamsterPlaza:FindFirstChild("CoinsShop")
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
	check("self-test: the audit detects a block dropped into the Coins Shop", detected >= 1, detected)

	print(string.format("PASS %d  FAIL %d", results.pass, results.fail))
	print("== done ==")
end)
