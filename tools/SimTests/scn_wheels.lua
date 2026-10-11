-- every wheel of every house: direction, axle, wobble
local Players = game:GetService("Players")
local function fireJoin(p) M.Sim.advance(0.01) RawData[Players].Signals.PlayerAdded:Fire(p) end
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
	adv(1)
	local Systems = "ServerScriptService.Systems."
	local HouseSystem = require(find(Systems .. "HouseSystem"))
	local DataSystem = require(find(Systems .. "DataSystem"))
	local CollectionSystem = require(find(Systems .. "CollectionSystem"))
	local HamsterDatabase = require(find("ReplicatedStorage.Modules.HamsterDatabase"))
	local EconomyMath = require(find("ReplicatedStorage.Modules.EconomyMath"))
	local WorldLayout = require(find("ReplicatedStorage.Modules.WorldLayout"))
	local CollectionService = game:GetService("CollectionService")
	local players = {}
	for i = 1, WorldLayout.HouseCount do
		local p = M.newPlayer("P" .. i)
		fireJoin(p)
		M.spawnCharacter(p)
		table.insert(players, p)
	end
	adv(8)
	M.localPlayerRef = players[1]
	local gui = M.newInstance("PlayerGui", true); RawData[gui].Name = "PlayerGui"; M.setParent(gui, players[1])
	M.isServer = false
	M.clientRunning = true
	local mainClient = find("StarterPlayer.StarterPlayerScripts.Main")
	task.spawn(function() RawData[mainClient].Source(mainClient, require) end)
	adv(3)
	-- give every player a full set of hamsters, unlock every wheel they can have
	local wheelCount = 0
	for _, p in players do
		local data = DataSystem.get(p)
		data.Upgrades.ExtraStorage = 9
		data.Rebirths = 15
		for i = 1, 40 do
			local species = HamsterDatabase.Species[(i * 3) % #HamsterDatabase.Species + 1]
			CollectionSystem.grant(p, species.Id, "Reward")
		end
		CollectionSystem.equipBest(p)
		require(find(Systems .. "Events")).Rebirthed:Fire(p)
	end
	adv(2)
	local cam = workspace.CurrentCamera
	local bad, checked, wobble = 0, 0, 0
	for _, p in players do
		local house = HouseSystem.getHouse(p)
		for _, slot in house.Slots do
			if slot.Wheel then
				wheelCount += 1
				local center = slot.Center.Position
				RawData[cam].Props.CFrame = CFrame.new(center.X, center.Y + 3, center.Z - 10)
				adv(0.3)
				local runDir = slot.Wheel:GetAttribute("RunDirection")
				local pivot0 = slot.Wheel:GetPivot()
				local bottom0 = pivot0.Position + Vector3.new(0, -2.3, 0)
				local axle0 = pivot0:VectorToWorldSpace(Vector3.new(1, 0, 0))
				adv(0.1)
				local pivot1 = slot.Wheel:GetPivot()
				local moved = pivot1 * pivot0:Inverse() * bottom0
				local velocity = (moved - bottom0) / 0.1
				local axle1 = pivot1:VectorToWorldSpace(Vector3.new(1, 0, 0))
				checked += 1
				-- the floor under the runner must move against the run direction
				if velocity:Dot(runDir) >= -0.5 then bad += 1 if bad <= 4 then print('BAD', house.Index, slot.Index, 'vel', velocity, 'center', center, 'p0', pivot0.Position, 'p1', pivot1.Position, 'r0', pivot0.r[1], pivot0.r[2], pivot0.r[3], 'r1', pivot1.r[1], pivot1.r[2], pivot1.r[3]) end end
				-- the axle must not move (no wobble) and must be horizontal across the wheel (along the house Z axis)
				if (axle1 - axle0).Magnitude > 1e-3 then wobble += 1 end
				local houseZ = house.CFrame:VectorToWorldSpace(Vector3.new(0, 0, 1))
				if math.abs(axle1:Dot(houseZ)) < 0.999 then wobble += 1 end
			end
		end
	end
	check("wheels tested", checked >= WorldLayout.HouseCount * 24, string.format("%d wheels in %d houses", checked, WorldLayout.HouseCount))
	check("every wheel's floor moves AGAINST the hamster's run direction", bad == 0, bad .. " wrong")
	check("every wheel turns about its axle (no wobble)", wobble == 0, wobble .. " wobbling")
	-- tower: 5 floors, landings, elevator buttons, stations on every floor
	local FloorConfig = require(find("ReplicatedStorage.Modules.FloorConfig"))
	local towerOk, perFloor = true, {}
	for _, p in players do
		local house = HouseSystem.getHouse(p)
		if house.FloorCount ~= 5 then towerOk = false end
		for f = 1, 5 do
			if not house.Landing[f] or not house.Elevator[f] or not house.FloorModels[f] then towerOk = false end
		end
		if house.Elevator[5].Up ~= nil or house.Elevator[1].Up == nil or house.Elevator[1].Down ~= nil or house.Elevator[5].Down == nil then towerOk = false end
		for _, slot in house.Slots do perFloor[slot.Floor] = (perFloor[slot.Floor] or 0) + 1 end
	end
	check("rebirth 15 gives every house a 5 floor tower with elevator + landings", towerOk)
	check("8 stations per floor", perFloor[1] == 64 and perFloor[5] == 64, perFloor[1] .. "/" .. tostring(perFloor[5]))
	print(string.format("PASS %d FAIL %d errors %d", results.pass, results.fail, #M.Sim.errors))
	for i, e in M.Sim.errors do if i <= 5 then print(e) end end
end)
M.Sim.advance(0)
