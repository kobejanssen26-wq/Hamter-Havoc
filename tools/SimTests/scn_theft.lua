-- Rack theft, gate trap, rebirth gate duration, elevators
local Players = game:GetService("Players")
local adv = M.Sim.advance
local results = { pass = 0, fail = 0 }
local function section(t) print("\n== " .. t .. " ==") end
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end
local function fireJoin(p) adv(0.01) RawData[Players].Signals.PlayerAdded:Fire(p) end

task.spawn(function()
	M.isServer = true
	local mainServer = find("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	adv(1)
	local S = "ServerScriptService.Systems."
	local HamsterSystem = require(find(S .. "HamsterSystem"))
	local LB = require(find(S .. "LeaderboardService"))
	local LBConfig = require(find("ReplicatedStorage.Modules.LeaderboardConfig"))
	local function stealsStored(p, period)
		local d = M.orderedStores[LBConfig.storeName("Steals", period, LB.clock())]
		return d and d[tostring(RawData[p].Props.UserId)]
	end
	local CombatSystem = require(find(S .. "CombatSystem"))
	local SecuritySystem = require(find(S .. "SecuritySystem"))
	local HouseSystem = require(find(S .. "HouseSystem"))
	local DataSystem = require(find(S .. "DataSystem"))
	local TheftSystem = require(find(S .. "TheftSystem"))
	local TheftState = require(find(S .. "TheftState"))
	local CollectionSystem = require(find(S .. "CollectionSystem"))
	local Events = require(find(S .. "Events"))
	local SecurityConfig = require(find("ReplicatedStorage.Modules.SecurityConfig"))
	local TheftConfig = require(find("ReplicatedStorage.Modules.TheftConfig"))
	local WorldLayout = require(find("ReplicatedStorage.Modules.WorldLayout"))
	local FloorConfig = require(find("ReplicatedStorage.Modules.FloorConfig"))
	local HouseBuilder = require(find(S .. "WorldBuilder.HouseBuilder"))
	local PPS = game:GetService("ProximityPromptService")
	HamsterSystem.AutoSpawn = false

	local function join(name)
		local p = M.newPlayer(name)
		fireJoin(p)
		M.spawnCharacter(p)
		return p
	end
	local alice, bob, carol = join("Alice"), join("Bob"), join("Carol")
	adv(6)
	local function data(p) return DataSystem.get(p) end
	local function rootOf(p) return M.InstanceMethods.FindFirstChild(RawData[p].Props.Character, "HumanoidRootPart") end
	local function humanoidOf(p) return M.InstanceMethods.FindFirstChild(RawData[p].Props.Character, "Humanoid") end
	local function place(p, cf, lookAt)
		RawData[rootOf(p)].Props.CFrame = if lookAt then CFrame.lookAt(cf, lookAt) else CFrame.new(cf)
	end
	local aliceHouse, bobHouse = HouseSystem.getHouse(alice), HouseSystem.getHouse(bob)
	local function promptOf(slot) return aliceHouse.TheftPrompts[slot] end
	local function wheelPos(slot) return aliceHouse.Slots[slot].RunCFrame.Position end
	local function standAtWheel(p, slot) place(p, wheelPos(slot) + Vector3.new(0, 2, 3)) end

	-- Alice owns two equipped hamsters
	data(alice).Inventory = { brownie = 1, silver = 1 }
	data(alice).Equipped = { "brownie", "silver" }
	Events.EquippedChanged:Fire(alice)
	adv(0.5)

	section("1. locked base / protection")
	check("gate starts active", SecuritySystem.status(aliceHouse) == "Active")
	standAtWheel(bob, 1)
	local ok0 = TheftSystem.begin(bob, aliceHouse.Index, 1)
	check("cannot steal from a LOCKED base", not ok0 and not HamsterSystem.carriedBy(bob))
	check("prompt hidden while the gate is on", promptOf(1).Enabled == false)

	-- wait until the gate went off (45 s) and the new-player protection (45 s) is over
	for _ = 1, 100 do
		if SecuritySystem.status(aliceHouse) ~= "Active" then break end
		adv(1)
	end
	adv(2)
	check("gate is off now", SecuritySystem.status(aliceHouse) ~= "Active")
	check("prompt shows for a wheel with a hamster", promptOf(1).Enabled == true and promptOf(1):GetAttribute("Available") == true)
	check("prompt hidden for an empty wheel", promptOf(3).Enabled == false)

	section("2. validation")
	local okFar = TheftSystem.begin(bob, aliceHouse.Index, 1)
	place(bob, Vector3.new(0, 5, 0))
	check("too far from the wheel is refused", not TheftSystem.begin(bob, aliceHouse.Index, 1))
	standAtWheel(bob, 1)
	check("the owner cannot steal from themselves", not TheftSystem.begin(alice, aliceHouse.Index, 1))
	check("invalid arguments refused", not TheftSystem.begin(bob, "x", 1) and not TheftSystem.begin(bob, aliceHouse.Index, 1.5) and not TheftSystem.begin(bob, 999, 1) and not TheftSystem.begin(bob, aliceHouse.Index, 99))
	humanoidOf(bob).Health = 0
	check("a dead player cannot steal", not TheftSystem.begin(bob, aliceHouse.Index, 1))
	humanoidOf(bob).Health = 100

	section("3. a theft starts: nothing is awarded yet")
	adv(5)
	standAtWheel(bob, 1)
	local before = { alice = data(alice).Inventory.brownie, bob = data(bob).Inventory.brownie or 0 }
	RawData[PPS].Signals.PromptTriggered:Fire(promptOf(1), bob) -- the real prompt path
	adv(0.5)
	local e = HamsterSystem.carriedBy(bob)
	check("hamster is carried by the thief", e ~= nil and e.Theft ~= nil and e.SpeciesId == "brownie")
	check("owner's data is untouched while it is only carried", data(alice).Inventory.brownie == before.alice and (data(bob).Inventory.brownie or 0) == before.bob)
	check("the wheel is locked and the hamster is gone from it", TheftState.slotLocked(alice.UserId, 1) and aliceHouse.DisplayModels[1] == nil)
	check("prompt disabled while being stolen", promptOf(1).Enabled == false)
	check("a second thief cannot take the same hamster", (function() standAtWheel(carol, 1) return not TheftSystem.begin(carol, aliceHouse.Index, 1) end)())
	check("thief cannot carry two", (function() standAtWheel(bob, 2) adv(4.5) return not TheftSystem.begin(bob, aliceHouse.Index, 2) end)())
	check("owner cannot unequip the hamster that is being stolen", not CollectionSystem.unequip(alice, "brownie"))

	section("4. the owner hits the thief")
	place(bob, wheelPos(1) + Vector3.new(0, 2, 3))
	place(alice, wheelPos(1) + Vector3.new(0, 2, 0), wheelPos(1) + Vector3.new(0, 2, 3))
	adv(1.5)
	place(carol, Vector3.new(0, 5, 0))
	CombatSystem.slap(alice)
	adv(0.5)
	check("a valid hit ends the theft", HamsterSystem.carriedBy(bob) == nil and not TheftState.slotLocked(alice.UserId, 1))
	check("the hamster is back on its wheel, ownership unchanged", aliceHouse.DisplayModels[1] ~= nil and data(alice).Inventory.brownie == 1 and data(alice).Equipped[1] == "brownie" and (data(bob).Inventory.brownie or 0) == 0)
	check("failed theft recorded for both", data(alice).Stats.TheftsStopped == 1 and data(bob).Stats.TheftsFailed == 1, tostring(data(alice).Stats.TheftsStopped) .. "/" .. tostring(data(bob).Stats.TheftsFailed))
	check("failed theft does NOT count as a steal", (data(bob).Stats.Stolen or 0) == 0)
	check("no entity left behind", next(HamsterSystem.all()) == nil)
	LB.flush(bob)
	check("leaderboard: a failed theft scores nothing", (stealsStored(bob, "AllTime") or 0) == 0 and stealsStored(bob, "Weekly") == nil)
	check("prompt available again", promptOf(1):GetAttribute("Available") == true)

	section("5. completed theft transfers ownership exactly once")
	adv(5)
	local completed = 0
	Events.TheftCompleted:Connect(function() completed += 1 end)
	standAtWheel(bob, 2)
	check("second theft starts (silver)", TheftSystem.begin(bob, aliceHouse.Index, 2))
	local silverBall = HamsterSystem.carriedBy(bob)
	-- Bob runs to the pad of HIS house
	local pad = WorldLayout.padPosition(bobHouse.CFrame)
	place(bob, pad + Vector3.new(0, 3, 0))
	adv(1.5)
	check("completed: thief owns it, victim lost it", (data(bob).Inventory.silver or 0) == 1 and (data(alice).Inventory.silver or 0) == 0, tostring(data(bob).Inventory.silver) .. "/" .. tostring(data(alice).Inventory.silver))
	check("victim's wheel lost it too", table.find(data(alice).Equipped, "silver") == nil)
	check("thief stats: Stolen +1", data(bob).Stats.Stolen == 1)
	check("completion event fired exactly once", completed == 1)
	LB.flush(bob)
	check("leaderboard: the completed theft scored exactly 1 (week, month, year, all-time)", stealsStored(bob, "Weekly") == 1 and stealsStored(bob, "Monthly") == 1 and stealsStored(bob, "Yearly") == 1 and stealsStored(bob, "AllTime") == 1)
	check("no entity / lock left", HamsterSystem.carriedBy(bob) == nil and not TheftState.anyLocked(alice.UserId) and next(HamsterSystem.all()) == nil)
	check("completed theft cannot be settled again", (function() return TheftSystem.activeCount() == 0 end)())

	section("6. gate closes while the thief is inside")
	adv(5)
	data(alice).Rebirths = 3 -- longer gate: 45 + 3*10 = 75 s
	data(alice).Inventory.silver = 1
	table.insert(data(alice).Equipped, "silver")
	Events.EquippedChanged:Fire(alice)
	adv(0.5)
	standAtWheel(bob, 2)
	check("theft starts again", TheftSystem.begin(bob, aliceHouse.Index, 2))
	place(bob, aliceHouse.CFrame:PointToWorldSpace(Vector3.new(0, 4, 20)))
	SecuritySystem.activate(aliceHouse)
	adv(0.5)
	check("gate duration = base + 10 s per rebirth (75 s at R3)", math.abs((aliceHouse.Model:GetAttribute("SecUntil") - aliceHouse.Model:GetAttribute("SecReady")) + (SecurityConfig.duration(3) - 0)) < 100 and SecurityConfig.duration(3) == 75 and SecurityConfig.duration(0) == 45 and SecurityConfig.duration(1) == 55)
	check("thief is trapped, not zapped", TheftState.isTrapped(bob, aliceHouse.Index) and HamsterSystem.carriedBy(bob) ~= nil)
	-- tries to walk out through the closed gate
	place(bob, aliceHouse.CFrame:PointToWorldSpace(Vector3.new(0, 4, -10)))
	adv(0.5)
	local localZ = aliceHouse.CFrame:PointToObjectSpace(RawData[rootOf(bob)].Props.CFrame.Position).Z
	check("a closed gate cannot be walked through (pushed back inside)", localZ > 0, localZ)
	check("still carrying while trapped", HamsterSystem.carriedBy(bob) ~= nil)
	adv(61)
	check("escape timeout: the theft fails, hamster is safe", HamsterSystem.carriedBy(bob) == nil and not TheftState.isTrapped(bob) and (data(alice).Inventory.silver or 0) == 1)
	local z2 = aliceHouse.CFrame:PointToObjectSpace(RawData[rootOf(bob)].Props.CFrame.Position).Z
	check("after the timeout the thief is put OUTSIDE (not trapped for ever)", z2 < 0, z2)
	check("lock released, wheel shows the hamster", not TheftState.anyLocked(alice.UserId))

	section("7. gate opens by itself before the timeout")
	for _ = 1, 100 do
		if SecuritySystem.status(aliceHouse) == "Ready" then break end
		adv(1.5)
	end
	data(alice).Rebirths = 0
	adv(5)
	check("owner can steal-protect state: gate ready", SecuritySystem.status(aliceHouse) == "Ready")
	standAtWheel(bob, 2)
	check("theft again", TheftSystem.begin(bob, aliceHouse.Index, 2))
	place(bob, aliceHouse.CFrame:PointToWorldSpace(Vector3.new(0, 4, 20)))
	SecuritySystem.activate(aliceHouse)
	adv(0.5)
	check("trapped while the gate is on", TheftState.isTrapped(bob))
	adv(SecurityConfig.duration(0) + 2)
	check("the gate opening releases the thief (valid exit), theft continues", not TheftState.isTrapped(bob) and HamsterSystem.carriedBy(bob) ~= nil)
	place(bob, aliceHouse.CFrame:PointToWorldSpace(Vector3.new(0, 4, -10)))
	adv(0.5)
	check("and they can leave now", aliceHouse.CFrame:PointToObjectSpace(RawData[rootOf(bob)].Props.CFrame.Position).Z < 0)

	section("8. death / disconnect / owner leaves / rebirth")
	-- thief dies carrying it
	humanoidOf(bob).Health = 0
	adv(0.5)
	local dropped = nil
	for _, ent in HamsterSystem.all() do dropped = ent end
	check("thief dies: the ball is dropped (not lost)", dropped ~= nil and dropped.State == "Dropped" and dropped.Theft ~= nil)
	check("the hamster is still the owner's in data", (data(alice).Inventory.silver or 0) == 1)
	adv(40)
	check("an abandoned stolen ball goes back to the owner: theft ends, nothing duplicated", next(HamsterSystem.all()) == nil and not TheftState.anyLocked(alice.UserId) and (data(alice).Inventory.silver or 0) == 1 and (data(bob).Inventory.silver or 0) == 1)
	-- fresh state for the next scenarios
	M.spawnCharacter(bob)
	adv(60)
	data(alice).Equipped = { "brownie", "silver" }
	Events.EquippedChanged:Fire(alice)
	adv(0.5)
	for _ = 1, 100 do
		if SecuritySystem.status(aliceHouse) ~= "Active" then break end
		adv(1)
	end
	adv(5)
	standAtWheel(bob, 1)
	check("theft for the disconnect test", TheftSystem.begin(bob, aliceHouse.Index, 1))
	M.removePlayer(bob)
	adv(0.5)
	check("thief disconnects: theft ends, hamster stays with the owner", next(HamsterSystem.all()) == nil and not TheftState.anyLocked(alice.UserId) and data(alice).Inventory.brownie == 1)
	-- owner reborn during a theft
	local dave = join("Dave")
	adv(60)
	for _ = 1, 100 do
		if SecuritySystem.status(aliceHouse) ~= "Active" then break end
		adv(1)
	end
	standAtWheel(dave, 1)
	adv(5)
	check("theft for the rebirth test", TheftSystem.begin(dave, aliceHouse.Index, 1))
	Events.Rebirthed:Fire(alice, 1)
	adv(0.5)
	check("owner's rebirth cancels the theft safely", next(HamsterSystem.all()) == nil and not TheftState.anyLocked(alice.UserId))
	adv(5)
	standAtWheel(dave, 1)
	check("theft for the owner-leaves test", TheftSystem.begin(dave, aliceHouse.Index, 1))
	local coinsBefore = data(dave).Coins
	M.removePlayer(alice)
	adv(0.5)
	check("owner leaves: ball vanishes, thief gets nothing and no refund is paid", next(HamsterSystem.all()) == nil and HamsterSystem.carriedBy(dave) == nil and data(dave).Coins - coinsBefore < 5, data(dave).Coins - coinsBefore)

	section("9. elevators follow the unlocked floors")
	local house = HouseSystem.getHouse(dave)
	local rng = Random.new(1)
	local function elevatorModels(h)
		local list = {}
		for f = 1, FloorConfig.MaxFloors do
			local fm = h.FloorModels[f]
			local interior = fm and M.InstanceMethods.FindFirstChild(fm, "Interior")
			local shaft = interior and M.InstanceMethods.FindFirstChild(interior, "Elevator")
			list[f] = shaft ~= nil
		end
		return list
	end
	local function calls(h, f)
		local shaft = h.Elevator[f] and h.Elevator[f].Shaft
		return shaft and M.InstanceMethods.FindFirstChild(shaft, "CallUp") ~= nil, shaft and M.InstanceMethods.FindFirstChild(shaft, "CallDown") ~= nil
	end
	HouseBuilder.setFloors(house, 1, rng)
	local m1 = elevatorModels(house)
	check("one floor: NO elevator on the ground floor", not m1[1] and house.Elevator[1] == nil)
	HouseBuilder.setFloors(house, 2, rng)
	local m2 = elevatorModels(house)
	local up1, down1 = calls(house, 1)
	local up2, down2 = calls(house, 2)
	check("two floors: elevator appears on floors 1 and 2", m2[1] and m2[2])
	check("floor 1: only UP; floor 2 (top): only DOWN", up1 and not down1 and not up2 and down2)
	HouseBuilder.setFloors(house, 3, rng)
	local u2, d2 = calls(house, 2)
	local u3, d3 = calls(house, 3)
	check("three floors: floor 2 has both, floor 3 only down", u2 and d2 and not u3 and d3)
	local ok = true
	for f = 1, 3 do
		local state = FloorConfig.elevator(f, 3)
		local up, down = calls(house, f)
		ok = ok and (up or false) == state.Up and (down or false) == state.Down
	end
	check("call buttons always match FloorConfig.elevator()", ok)
	-- server-side travel validation
	local landing = function(f) return house.Landing[f] end
	place(dave, landing(1).Position)
	HouseSystem.useElevator(dave, house.Index, 1, "Up")
	local y1 = RawData[rootOf(dave)].Props.CFrame.Position.Y
	check("owner travels up to the unlocked floor 2", math.abs(y1 - landing(2).Position.Y) < 1, y1)
	HouseSystem.useElevator(dave, house.Index, 2, "Up")
	HouseSystem.useElevator(dave, house.Index, 3, "Up")
	local y3 = RawData[rootOf(dave)].Props.CFrame.Position.Y
	check("cannot go above the top unlocked floor", math.abs(y3 - landing(3).Position.Y) < 1)
	HouseSystem.useElevator(dave, house.Index, 3, "Down")
	check("can still travel DOWN", math.abs(RawData[rootOf(dave)].Props.CFrame.Position.Y - landing(2).Position.Y) < 1)
	place(dave, landing(1).Position)
	HouseSystem.useElevator(dave, house.Index, 1, "Down")
	check("no travel below the ground floor", math.abs(RawData[rootOf(dave)].Props.CFrame.Position.Y - landing(1).Position.Y) < 1)
	place(dave, landing(1).Position)
	HouseSystem.useElevator(dave, house.Index, 1, "Sideways")
	HouseSystem.useElevator(dave, house.Index, 4, "Up")
	check("junk direction / floor ignored", math.abs(RawData[rootOf(dave)].Props.CFrame.Position.Y - landing(1).Position.Y) < 1)
	HouseBuilder.setFloors(house, 1, rng)
	check("floors removed again: elevators removed again", not elevatorModels(house)[1] and not elevatorModels(house)[2])

	print(string.format("PASS %d FAIL %d errors %d", results.pass, results.fail, #M.Sim.errors))
	for i, e in M.Sim.errors do if i <= 6 then print("  err:", e) end end
end)
M.Sim.advance(0)
