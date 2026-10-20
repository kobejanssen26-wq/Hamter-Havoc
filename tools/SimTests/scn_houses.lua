-- Every house at every floor count (1-5): floors, roof, balconies, entrance and yard must not interpenetrate wrongly.
local results = { pass = 0, fail = 0 }
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end
local adv = M.Sim.advance
task.spawn(function()
	M.isServer = true
	local mainServer = find("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	adv(3)
	local HouseSystem = require(find("ServerScriptService.Systems.HouseSystem"))
	local HouseBuilder = require(find("ServerScriptService.Systems.WorldBuilder.HouseBuilder"))

	local function axes(cf)
		local r = cf.r
		return { Vector3.new(r[1], r[4], r[7]), Vector3.new(r[2], r[5], r[8]), Vector3.new(r[3], r[6], r[9]) }
	end
	local function penetration(a, b)
		local ax, bx = axes(a.CF), axes(b.CF)
		local delta = Vector3.new(b.CF.X - a.CF.X, b.CF.Y - a.CF.Y, b.CF.Z - a.CF.Z)
		local cands = {}
		for i = 1, 3 do table.insert(cands, ax[i]) table.insert(cands, bx[i]) end
		for i = 1, 3 do for j = 1, 3 do
			local c = ax[i]:Cross(bx[j])
			if c.Magnitude > 1e-4 then table.insert(cands, c.Unit) end
		end end
		local smallest = math.huge
		local ha = { a.Size.X / 2, a.Size.Y / 2, a.Size.Z / 2 }
		local hb = { b.Size.X / 2, b.Size.Y / 2, b.Size.Z / 2 }
		for _, axis in cands do
			local ra, rb = 0, 0
			for i = 1, 3 do ra += ha[i] * math.abs(ax[i]:Dot(axis)) rb += hb[i] * math.abs(bx[i]:Dot(axis)) end
			local overlap = ra + rb - math.abs(delta:Dot(axis))
			if overlap <= 0 then return 0 end
			smallest = math.min(smallest, overlap)
		end
		return smallest
	end
	local function groupOf(part, houseModel)
		-- which "piece" of the house: Tower/Floor3_xxx/Shell, Tower/Roof, Yard ...
		local chain, node = {}, part
		while node and node ~= houseModel do table.insert(chain, 1, RawData[node].Name) node = RawData[node].Parent end
		return chain
	end
	local reported = {}
	local totalHits = 0
	for _, house in HouseSystem.all() do
		if house.Index == 1 or house.Index == 2 or house.Index == 5 or house.Index == 8 then
			for count = 1, 5 do
				HouseBuilder.setFloors(house, count, Random.new(count))
				adv(0.2)
				local parts = {}
				for _, d in M.descendants(house.Model) do
					local data = RawData[d]
					if data.Props and data.Props.Size and data.Props.CFrame and M.InstanceMethods.IsA(d, "BasePart") and data.Props.Anchored and (data.Props.Transparency or 0) < 0.8 and math.min(data.Props.Size.X, data.Props.Size.Y, data.Props.Size.Z) >= 0.12 then
						local chain = groupOf(d, house.Model)
						local top, second = chain[1] or "?", chain[2] or ""
						local piece = top
						if top == "Tower" then piece = "Tower/" .. second end
						table.insert(parts, { Name = data.Name, Piece = piece, Chain = table.concat(chain, "/"), CF = data.Props.CFrame, Size = data.Props.Size })
					end
				end
				for i = 1, #parts do
					for j = i + 1, #parts do
						local a, b = parts[i], parts[j]
						if a.Piece ~= b.Piece then
							local d = Vector3.new(a.CF.X - b.CF.X, a.CF.Y - b.CF.Y, a.CF.Z - b.CF.Z).Magnitude
							if d < (a.Size.Magnitude + b.Size.Magnitude) / 2 then
								local depth = penetration(a, b)
								if depth > 0.1 and (string.find(a.Piece .. b.Piece, "Floor", 1, true) or string.find(a.Piece .. b.Piece, "Roof", 1, true) or string.find(a.Piece .. b.Piece, "Yard", 1, true)) then
									local key = string.format("floors=%d  %s  x  %s", count, a.Piece .. ":" .. a.Name, b.Piece .. ":" .. b.Name)
									if not reported[key] then
										reported[key] = string.format("depth %.2f at y=%.1f (%s | %s)", depth, (a.CF.Y + b.CF.Y) / 2, a.Chain, b.Chain)
										totalHits += 1
									end
								end
							end
						end
					end
				end
			end
		end
	end
	local keys = {}
	for k in reported do table.insert(keys, k) end
	table.sort(keys)
	for i = 1, math.min(#keys, 30) do print("   HIT", keys[i], reported[keys[i]]) end
	check("no floor, roof, balcony, entrance or yard object of any house (1-5 floors, north and south row) interpenetrates another piece", totalHits == 0, totalHits)
	print(string.format("\nPASS %d  FAIL %d", results.pass, results.fail))
end)
