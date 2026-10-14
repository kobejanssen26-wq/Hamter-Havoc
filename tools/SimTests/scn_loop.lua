-- Full-loop scenarios: claim -> transport -> steal -> carry -> slap -> drop -> recover -> secure -> wheel -> money
local results = { pass = 0, fail = 0 }
local function section(t) print("\n== " .. t .. " ==") end
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end
local function report()
	if #M.Sim.errors > 0 then
		print("  game errors:", #M.Sim.errors)
		for i, e in M.Sim.errors do if i <= 6 then print("   ", e) end end
	end
end
local Players = game:GetService("Players")
local function fireJoin(p) M.Sim.advance(0.01) RawData[Players].Signals.PlayerAdded:Fire(p) end
local adv = M.Sim.advance

task.spawn(function()
	section("boot")
	M.isServer = true
	local mainServer = find("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	adv(1)
	local Systems = "ServerScriptService.Systems."
	local HamsterSystem = require(find(Systems .. "HamsterSystem"))
	local CombatSystem = require(find(Systems .. "CombatSystem"))
	local SecuritySystem = require(find(Systems .. "SecuritySystem"))
	local HouseSystem = require(find(Systems .. "HouseSystem"))
	local DataSystem = require(find(Systems .. "DataSystem"))
	local PlayerState = require(find(Systems .. "PlayerState"))
	local EconomySystem = require(find(Systems .. "EconomySystem"))
	local Remotes = require(find("ReplicatedStorage.Remotes"))
	local HamsterDatabase = require(find("ReplicatedStorage.Modules.HamsterDatabase"))
	local WorldLayout = require(find("ReplicatedStorage.Modules.WorldLayout"))
	local RarityConfig = require(find("ReplicatedStorage.Modules.RarityConfig"))
	local CollectionService = game:GetService("CollectionService")
	HamsterSystem.AutoSpawn = false
	report()

	local function join(name)
		local p = M.newPlayer(name)
		fireJoin(p)
		M.spawnCharacter(p)
		return p
	end
	local alice, bob, carol = join("Alice"), join("Bob"), join("Carol")
	adv(6)
	print("houses:", alice:GetAttribute("HouseId"), bob:GetAttribute("HouseId"), carol:GetAttribute("HouseId"))

	-- the client of Alice
	M.localPlayerRef = alice
	local gui = M.newInstance("PlayerGui", true); RawData[gui].Name = "PlayerGui"; M.setParent(gui, alice)
	M.isServer = false
	M.clientRunning = true
	local mainClient = find("StarterPlayer.StarterPlayerScripts.Main")
	task.spawn(function() RawData[mainClient].Source(mainClient, require) end)
	adv(4)
	print("client ready:", alice:GetAttribute("ClientReady"))
	report()

	local function rootOf(p) return M.InstanceMethods.FindFirstChild(RawData[p].Props.Character, "HumanoidRootPart") end
	local function humanoidOf(p) return M.InstanceMethods.FindFirstChild(RawData[p].Props.Character, "Humanoid") end
	local function posOf(p) return RawData[rootOf(p)].Props.CFrame.Position end
	local function place(p, x, y, z, lookAt)
		local pos = Vector3.new(x, y, z)
		RawData[rootOf(p)].Props.CFrame = if lookAt then CFrame.lookAt(pos, lookAt) else CFrame.new(x, y, z)
	end
	local function data(p) return DataSystem.get(p) end
	local function speciesOf(rarity, index) return HamsterDatabase.Spawnable[rarity][index or 1] end
	local function untilTrue(cond, maxSeconds, step)
		local t = 0
		step = step or 0.1
		while t < maxSeconds do
			if cond() then return true, t end
			adv(step)
			t += step
		end
		return cond(), t
	end
	local function walkTo(p, target, maxTime)
		local t = 0
		while t < maxTime do
			local pos = posOf(p)
			local d = Vector3.new(target.X - pos.X, 0, target.Z - pos.Z)
			if d.Magnitude < 1.2 then return true, t end
			local speed = RawData[humanoidOf(p)].Props.WalkSpeed
			local step = math.min(d.Magnitude, speed * 0.1)
			local new = pos + d.Unit * step
			RawData[rootOf(p)].Props.CFrame = CFrame.lookAt(Vector3.new(new.X, 3, new.Z), Vector3.new(new.X + d.Unit.X, 3, new.Z + d.Unit.Z))
			adv(0.1)
			t += 0.1
		end
		return false, t
	end
	local function spawnBall(rarity, sponsor, index)
		local e = HamsterSystem.spawn(speciesOf(rarity, index), sponsor or alice)
		return e
	end
	local function nearBall(p, e, dz)
		place(p, e.Position.X, 3, e.Position.Z + (dz or 9))
	end
	local function houseOf(p) return HouseSystem.getHouse(p) end
	local function padOf(p) return WorldLayout.padPosition(houseOf(p).CFrame) end
	local function notices(p, pattern)
		local n = 0
		for _, l in M.remoteLog or {} do
			if l[1] == "Notify" and l[2] == RawData[p].Name and string.find(tostring(l[3]), pattern, 1, true) then n += 1 end
		end
		return n
	end

	-------------------------------------------------------------------
	section("TEST 1: claim a Basic hamster and bring it home")
	-------------------------------------------------------------------
	data(alice).Coins = 5000000; EconomySystem.updateAttributes(alice)
	local e1 = spawnBall("Basic")
	adv(2)
	check("ball spawned and travelling", e1 and e1.State == "Travelling", e1 and e1.State)
	local coinsBefore = data(alice).Coins
	local inventoryBefore = 0
	for _, v in data(alice).Inventory do inventoryBefore += v end
	adv(3)
	nearBall(alice, e1)
	HamsterSystem.interact(alice, e1.Id)
	check("claim: state InTransit (not owned yet)", e1.State == "InTransit", e1.State)
	check("claim: price paid", data(alice).Coins <= coinsBefore - e1.Price + 5, string.format("%d -> %d", coinsBefore, data(alice).Coins))
	local inv1 = 0
	for _, v in data(alice).Inventory do inv1 += v end
	check("claimed != owned (inventory unchanged)", inv1 == inventoryBefore)
	local states = { InTransit = true }
	local secured, took = untilTrue(function() states[e1.State] = true return HamsterSystem.get(e1.Id) == nil end, 120)
	local inv2 = 0
	for _, v in data(alice).Inventory do inv2 += v end
	check("rolled home and was secured", secured and inv2 == inventoryBefore + 1, string.format("%.1fs, inv %d -> %d", took, inventoryBefore, inv2))
	report()
	adv(1)

	-------------------------------------------------------------------
	section("TEST 11/12: hamster runs on a wheel and earns money")
	-------------------------------------------------------------------
	local house = houseOf(alice)
	local wheelHamsters = 0
	for _, m in CollectionService:GetTagged("WheelHamster") do wheelHamsters += 1 end
	check("wheel hamster model exists (tagged WheelHamster)", wheelHamsters >= 1, wheelHamsters)
	local slot1 = house.Slots[1]
	check("wheel built for the unlocked slot", slot1.Wheel ~= nil)
	check("wheel spins while a hamster works", slot1.Wheel and slot1.Wheel:GetAttribute("Speed") > 0, slot1.Wheel and slot1.Wheel:GetAttribute("Speed"))
	local c0 = data(alice).Coins
	adv(10)
	local gained = data(alice).Coins - c0
	check("working hamster generates money", gained > 0, string.format("+%.1f in 10s (%.2f/s)", gained, gained / 10))
	report()

	-------------------------------------------------------------------
	section("TEST 2/3/4: Legendary claimed by Alice, stolen by Bob, slapped loose, recovered")
	-------------------------------------------------------------------
	data(alice).Coins = 9e12; EconomySystem.updateAttributes(alice)
	local legend = spawnBall("Legendary")
	adv(2)
	nearBall(alice, legend)
	HamsterSystem.interact(alice, legend.Id)
	check("Alice claimed the Legendary", legend.State == "InTransit" and legend.Payer == alice, legend.State)
	adv(4)
	place(bob, legend.Position.X, 3, legend.Position.Z + 6)
	HamsterSystem.interact(bob, legend.Id)
	check("Bob started stealing (channel, not instant)", legend.State == "InTransit" and HamsterSystem.isChanneling(bob))
	local carried = untilTrue(function() if legend.State ~= "Carried" then place(bob, legend.Position.X, 3, legend.Position.Z + 3) end return legend.State == "Carried" end, 5)
	check("steal completes after the hold: Carried by Bob", carried and legend.Holder == bob, legend.State)
	check("Alice was warned", notices(alice, "STOLEN") >= 1)
	check("Bob is slowed while carrying", RawData[humanoidOf(bob)].Props.WalkSpeed < 16, RawData[humanoidOf(bob)].Props.WalkSpeed)
	-- Bob runs away from his spot; Alice chases and slaps
	walkTo(bob, Vector3.new(posOf(bob).X + 25, 3, posOf(bob).Z + 10), 3)
	local dropped, stunned, slaps = false, false, 0
	for attempt = 1, 12 do
		local bp = posOf(bob)
		place(alice, bp.X - 4, 3, bp.Z, bp)
		CombatSystem.slap(alice)
		slaps += 1
		adv(0.2)
		stunned = stunned or PlayerState.isStunned(bob)
		if legend.State == "Dropped" or legend.State == "Recoverable" then dropped = true break end
		adv(2.4) -- cooldown + immunity
	end
	check("slap knocked it loose: Dropped", dropped, legend.State .. " after " .. slaps .. " slaps")
	check("Bob was stunned by the slap", stunned)
	check("Bob got knocked back (client told)", (function() for _, l in M.remoteLog or {} do if l[1] == "Knockback" then return true end end return false end)())
	adv(2)
	check("becomes Recoverable after the grace time", legend.State == "Recoverable", legend.State)
	-- Alice recovers it
	place(alice, legend.Position.X, 3, legend.Position.Z - 5)
	HamsterSystem.interact(alice, legend.Id)
	local recovered = untilTrue(function() return legend.State == "Carried" and legend.Holder == alice end, 3)
	check("Alice recovered it (carried by Alice)", recovered, legend.State)
	check("recover message", notices(alice, "RECOVERED") >= 1)
	local home, t2 = walkTo(alice, padOf(alice), 40)
	adv(1)
	check("Alice walked it home: SECURED, no teleport", HamsterSystem.get(legend.Id) == nil and (data(alice).Inventory[legend.SpeciesId] or 0) >= 1, string.format("%.1fs walk", t2))
	report()

	-------------------------------------------------------------------
	section("TEST 5: thief gets the hamster into his own house")
	-------------------------------------------------------------------
	local epic = spawnBall("Epic")
	adv(2)
	local alicePadBefore = data(alice).Coins
	nearBall(alice, epic)
	HamsterSystem.interact(alice, epic.Id)
	adv(3)
	place(bob, epic.Position.X, 3, epic.Position.Z + 6)
	HamsterSystem.interact(bob, epic.Id)
	untilTrue(function() if epic.State ~= "Carried" then place(bob, epic.Position.X, 3, epic.Position.Z + 3) end return epic.State == "Carried" end, 5)
	check("Bob carries Alice's Epic", epic.Holder == bob)
	local bobInvBefore = data(bob).Inventory[epic.SpeciesId] or 0
	local coinsAliceBefore = data(alice).Coins
	local ok, tw = walkTo(bob, padOf(bob), 80)
	adv(1)
	check("Bob walked it to HIS pad", ok, string.format("%.1fs", tw))
	check("secured for Bob (permanent)", HamsterSystem.get(epic.Id) == nil and (data(bob).Inventory[epic.SpeciesId] or 0) == bobInvBefore + 1)
	check("Alice got 25% insurance", data(alice).Coins - coinsAliceBefore > epic.Price * 0.2, data(alice).Coins - coinsAliceBefore)
	report()

	-------------------------------------------------------------------
	section("TEST 6/7/8: security timer, manual reactivation, entering other houses")
	-------------------------------------------------------------------
	local aliceHouse = houseOf(alice)
	SecuritySystem.activate(aliceHouse)
	adv(0.5)
	check("gate switches on: lasers visible", SecuritySystem.status(aliceHouse) == "Active" and aliceHouse.Security.Beams[1].Transparency < 0.5 and aliceHouse.Security.Prompt.Enabled == false)
	local untilT = aliceHouse.Model:GetAttribute("SecUntil")
	check("timer published for clients (SecUntil in the future, ~45s)", untilT - workspace:GetServerTimeNow() > 40, untilT - workspace:GetServerTimeNow())
	local expired, tExpire = untilTrue(function() return SecuritySystem.status(aliceHouse) ~= "Active" end, 130, 0.25)
	check("security expires on its own", expired and SecuritySystem.status(aliceHouse) == "Recharging", string.format("%.1fs, now %s", tExpire, SecuritySystem.status(aliceHouse)))
	check("lasers off + prompt still disabled while recharging", aliceHouse.Security.Beams[1].Transparency == 1 and aliceHouse.Security.Prompt.Enabled == false)
	local tryEarly = SecuritySystem.status(aliceHouse)
	RawData[game:GetService("ProximityPromptService")].Signals.PromptTriggered:Fire(aliceHouse.Security.Prompt, alice)
	adv(0.3)
	check("cannot reactivate while recharging", SecuritySystem.status(aliceHouse) == tryEarly)
	local ready = untilTrue(function() return SecuritySystem.status(aliceHouse) == "Ready" end, 30, 0.25)
	adv(0.5)
	check("gate becomes Ready (button usable)", ready and aliceHouse.Security.Prompt.Enabled == true, string.format("ready=%s status=%s enabled=%s", tostring(ready), SecuritySystem.status(aliceHouse), tostring(aliceHouse.Security.Prompt.Enabled)))
	-- somebody else pressing the button does nothing
	RawData[game:GetService("ProximityPromptService")].Signals.PromptTriggered:Fire(aliceHouse.Security.Prompt, bob)
	adv(0.3)
	check("only the owner can use the panel", SecuritySystem.status(aliceHouse) == "Ready")
	-- Carol walks into Alice's open house
	place(carol, aliceHouse.GatePosition.X, 3, aliceHouse.GatePosition.Z - 6 * WorldLayout.side(aliceHouse.Index))
	local entered = walkTo(carol, aliceHouse.CFrame:PointToWorldSpace(Vector3.new(0, 3, 22)), 20)
	adv(2)
	check("Carol can walk into Alice's house while security is off", entered and WorldLayout.inLot(aliceHouse.CFrame, posOf(carol)) and not PlayerState.isStunned(carol))
	-- Alice presses the button
	local PPS = game:GetService("ProximityPromptService")
	RawData[PPS].Signals.PromptTriggered:Fire(aliceHouse.Security.Prompt, alice)
	adv(0.6)
	check("Alice reactivates security manually", SecuritySystem.status(aliceHouse) == "Active", SecuritySystem.status(aliceHouse))
	adv(1)
	check("active gate zapped Carol out of the lot", not WorldLayout.inLot(aliceHouse.CFrame, posOf(carol)) or PlayerState.isStunned(carol), tostring(posOf(carol)))
	report()

	-------------------------------------------------------------------
	section("TEST 8b: steal from INSIDE an open house, then the owner re-arms the gate")
	-------------------------------------------------------------------
	untilTrue(function() return SecuritySystem.status(aliceHouse) ~= "Active" end, 130, 0.5)
	untilTrue(function() return SecuritySystem.status(aliceHouse) == "Ready" end, 40, 0.5)
	adv(0.5)
	check("owner's gate is open (off, ready)", SecuritySystem.status(aliceHouse) == "Ready")
	local function lotPoint(house, x, z) return house.CFrame:PointToWorldSpace(Vector3.new(x, 3, z)) end
	local waitSpot = lotPoint(aliceHouse, 7, 21)
	place(bob, waitSpot.X, 3, waitSpot.Z)
	local inside = HamsterSystem.spawn(speciesOf("Epic", 2), alice)
	adv(2)
	nearBall(alice, inside)
	data(alice).Coins = 9e12
	HamsterSystem.interact(alice, inside.Id)
	check("Alice claimed it; it rolls home", inside.State == "InTransit")
	local atDoor = untilTrue(function() return WorldLayout.inLot(aliceHouse.CFrame, inside.Position) and (inside.Position - posOf(bob)).Magnitude < 9 end, 120, 0.1)
	check("the ball rolled into the house past the waiting thief", atDoor, tostring(inside.Position))
	HamsterSystem.interact(bob, inside.Id)
	local stolenInside = untilTrue(function() return inside.State == "Carried" end, 4)
	check("Bob stole it INSIDE Alice's house (not instant, not secured)", stolenInside and inside.Holder == bob and HamsterSystem.get(inside.Id) ~= nil)
	-- Alice runs to the panel and switches the gate on again
	local pylonPos = aliceHouse.Security.Prompt.Parent.Position
	place(alice, pylonPos.X, 3, pylonPos.Z + 4)
	RawData[game:GetService("ProximityPromptService")].Signals.PromptTriggered:Fire(aliceHouse.Security.Prompt, alice)
	adv(1.5)
	check("gate is on again", SecuritySystem.status(aliceHouse) == "Active")
	check("the zap made Bob drop the hamster", inside.State == "Dropped" or inside.State == "Recoverable", inside.State)
	check("Bob was stunned and thrown out of the lot", PlayerState.isStunned(bob) or not WorldLayout.inLot(aliceHouse.CFrame, posOf(bob)))
	adv(2)
	place(alice, inside.Position.X, 3, inside.Position.Z - 3)
	HamsterSystem.interact(alice, inside.Id)
	untilTrue(function() return inside.State == "Carried" and inside.Holder == alice end, 3)
	local gotHome = walkTo(alice, padOf(alice), 30)
	adv(1)
	check("Alice recovered and secured it", HamsterSystem.get(inside.Id) == nil and (data(alice).Inventory[inside.SpeciesId] or 0) >= 1)
	report()

	-------------------------------------------------------------------
	section("fairness: both rows have identical routes")
	-------------------------------------------------------------------
	local Route = require(find("ReplicatedStorage.Modules.Route"))
	local worst = 0
	for i = 1, #WorldLayout.HouseColumns do
		local north = WorldLayout.transitRoute(WorldLayout.houseCFrame(i), Vector3.new(-30, 0.28, 4))
		local south = WorldLayout.transitRoute(WorldLayout.houseCFrame(i + #WorldLayout.HouseColumns), Vector3.new(-30, 0.28, -4))
		worst = math.max(worst, math.abs(north.Length - south.Length))
	end
	check("mirrored houses have equal route length from the mirrored road spot", worst < 0.05, string.format("max difference %.4f", worst))
	local lengths = {}
	for i = 1, WorldLayout.HouseCount do
		local cf = WorldLayout.houseCFrame(i)
		table.insert(lengths, math.abs(cf.Position.Z))
	end
	check("every gate is the same distance from the road", math.max(table.unpack(lengths)) == math.min(table.unpack(lengths)))

	-------------------------------------------------------------------
	section("balls steer around people on the road")
	-------------------------------------------------------------------
	for _, e in HamsterSystem.all() do end
	local avoid = HamsterSystem.spawn(speciesOf("Basic", 3), alice)
	adv(1.6)
	avoid.Lat, avoid.LatTarget, avoid.HomeLat = -4, -4, -4
	place(carol, avoid.Position.X + 40, 3, -4)
	local closest = 1e9
	local tt = 0
	while tt < 15 and HamsterSystem.get(avoid.Id) do
		adv(0.05)
		tt += 0.05
		local cp = posOf(carol)
		local d = math.sqrt((avoid.Position.X - cp.X) ^ 2 + (avoid.Position.Z - cp.Z) ^ 2) - avoid.Radius
		closest = math.min(closest, d)
	end
	check("ball rolled around the person (never through them)", closest > 1.0, string.format("closest %.2f studs from the ball surface", closest))
	place(carol, 0, 3, -60)

	-------------------------------------------------------------------
	section("TEST 9/10: balls never overlap; a fast Legendary overtakes a slow Basic")
	-------------------------------------------------------------------
	for _, e in HamsterSystem.all() do e.Static = false end
	adv(1)
	local slow = spawnBall("Basic")
	slow.Lat, slow.LatTarget, slow.HomeLat = 4, 4, 4
	adv(6)
	local fast = spawnBall("Legendary", alice, 2)
	if not fast then adv(1) fast = spawnBall("Legendary", alice, 2) end
	fast.Lat, fast.LatTarget, fast.HomeLat = 4, 4, 4
	fast.Dist = math.max(0, slow.Dist - 60)
	local minGap, passed, usedOtherLane, overlaps = 1e9, false, false, 0
	local t = 0
	while t < 40 and HamsterSystem.get(fast.Id) and HamsterSystem.get(slow.Id) do
		adv(0.05)
		t += 0.05
		local d = (fast.Position - slow.Position)
		local gap = math.sqrt(d.X * d.X + d.Z * d.Z) - (fast.Radius + slow.Radius)
		minGap = math.min(minGap, gap)
		if gap < -0.05 then overlaps += 1 end
		if fast.Position.X > slow.Position.X + 4 then passed = true end
		if math.abs(fast.Lat - 4) > 2 then usedOtherLane = true end
	end
	check("fast Legendary passed the slow Basic", passed, string.format("t=%.1fs", t))
	check("it went around (used the other lane)", usedOtherLane)
	check("never overlapped", overlaps == 0, string.format("min gap %.2f studs, %d overlap ticks", minGap, overlaps))
	-- crowd: 7 mixed balls, check pairwise overlap every tick
	local rarities = { "Basic", "Cute", "Rare", "Epic", "Basic", "Legendary", "Mythic" }
	for index, rarity in rarities do
		local e
		for _ = 1, 8 do
			e = HamsterSystem.spawn(speciesOf(rarity, 1), alice)
			if e then break end
			adv(0.5)
		end
		adv(0.7)
	end
	local worst, crowdOverlaps = 1e9, 0
	for _ = 1, 600 do
		adv(0.05)
		local list = {}
		for _, e in HamsterSystem.all() do if e.State ~= "Carried" then table.insert(list, e) end end
		for i = 1, #list do
			for j = i + 1, #list do
				local a, b = list[i], list[j]
				local dx, dz = a.Position.X - b.Position.X, a.Position.Z - b.Position.Z
				local gap = math.sqrt(dx * dx + dz * dz) - (a.Radius + b.Radius)
				worst = math.min(worst, gap)
				if gap < -0.05 then crowdOverlaps += 1 end
			end
		end
	end
	check("crowd of mixed balls: no overlap", crowdOverlaps == 0, string.format("worst gap %.2f", worst))
	report()

	-------------------------------------------------------------------
	section("client view of all this")
	-------------------------------------------------------------------
	local folder = workspace:FindFirstChild("ClientHamsters")
	print("  client balls rendered:", folder and #folder:GetChildren() or 0)
	report()

	-------------------------------------------------------------------
	section("client: wheel hamster runs, wheel turns (camera next to the house)")
	-------------------------------------------------------------------
	local wheelHouse = houseOf(alice)
	local wheelSlot = wheelHouse.Slots[1]
	local cam = workspace.CurrentCamera
	local wheelPos = wheelSlot.Center.Position
	RawData[cam].Props.CFrame = CFrame.new(wheelPos.X, wheelPos.Y + 3, wheelPos.Z - 12)
	adv(1.2)
	local worker = nil
	for _, m in CollectionService:GetTagged("WheelHamster") do if (m.PrimaryPart.Position - wheelPos).Magnitude < 8 then worker = m end end
	check("a working hamster sits in wheel 1", worker ~= nil)
	local function pivotKey(m) local c = m:GetPivot() return c.r[1] + c.r[2] * 3 + c.r[4] * 7 end
	local k1 = pivotKey(wheelSlot.Wheel)
	local function jointKey(m)
		for _, d in M.descendants(m) do
			if RawData[d].Name == "PawFLJ" then
				local t = RawData[d].Props.Transform
				return t and (t.r[5] * 10 + t.r[6] * 7 + t.Y * 3 + t.Z)
			end
		end
	end
	local jointBefore = jointKey(worker)
	adv(0.31)
	local jointMid = jointKey(worker)
	adv(0.21)
	local jointAfter = jointKey(worker)
	local k2 = pivotKey(wheelSlot.Wheel)
	check("wheel is rotating (client animation)", math.abs(k1 - k2) > 1e-4, string.format("%.4f -> %.4f", k1, k2))
	check("hamster legs are animating (running)", jointBefore ~= nil and (jointBefore ~= jointMid or jointMid ~= jointAfter), string.format("%s %s %s", tostring(jointBefore), tostring(jointMid), tostring(jointAfter)))
	RawData[cam].Props.CFrame = CFrame.new(0, 30, -60)
	report()

	-------------------------------------------------------------------
	section("anti-grief: carrier leaves, carry timeout, out of bounds, payer leaves")
	-------------------------------------------------------------------
	-- (a) the carrier leaves the game: ball is dropped, rolls back to the payer, payer secures it
	local dave = join("Dave")
	adv(5)
	data(carol).Coins = 9e12
	local ballA = spawnBall("Rare")
	adv(2)
	nearBall(carol, ballA)
	HamsterSystem.interact(carol, ballA.Id)
	adv(2)
	place(dave, ballA.Position.X, 3, ballA.Position.Z + 6)
	HamsterSystem.interact(dave, ballA.Id)
	untilTrue(function() if ballA.State ~= "Carried" then place(dave, ballA.Position.X, 3, ballA.Position.Z + 3) end return ballA.State == "Carried" end, 4)
	check("Dave stole Carol's Rare", ballA.Holder == dave)
	M.removePlayer(dave)
	adv(0.5)
	check("carrier left: the ball is dropped (not lost, not teleported)", ballA.State == "Dropped" or ballA.State == "Recoverable", ballA.State)
	local carolInv = data(carol).Inventory[ballA.SpeciesId] or 0
	local rolledBack = untilTrue(function() return ballA.State == "InTransit" end, 40)
	check("abandoned ball rolls back to its payer", rolledBack and ballA.Payer == carol)
	local carolPad = padOf(carol)
	untilTrue(function() return HamsterSystem.get(ballA.Id) == nil end, 120)
	check("and gets secured for Carol", (data(carol).Inventory[ballA.SpeciesId] or 0) == carolInv + 1)

	-- (b) carrying too long: the ball slips away and the carrier can't instantly re-grab it
	local ballB = spawnBall("Cute")
	adv(2)
	nearBall(carol, ballB)
	HamsterSystem.interact(carol, ballB.Id)
	adv(2)
	place(bob, ballB.Position.X, 3, ballB.Position.Z + 6)
	HamsterSystem.interact(bob, ballB.Id)
	untilTrue(function() if ballB.State ~= "Carried" then place(bob, ballB.Position.X, 3, ballB.Position.Z + 3) end return ballB.State == "Carried" end, 4)
	local fixed = Vector3.new(0, 3, 0)
	place(bob, 0, 3, -60)
	adv(78)
	check("carry timeout drops the ball after ~75s", ballB.State == "Dropped" or ballB.State == "Recoverable", ballB.State)
	adv(1.7)
	HamsterSystem.interact(bob, ballB.Id)
	adv(0.2)
	check("the carrier is banned from instantly re-grabbing", not HamsterSystem.isChanneling(bob))

	-- (c) out of bounds
	local ballC = spawnBall("Basic", alice, 4)
	adv(2)
	nearBall(carol, ballC)
	data(carol).Coins = 9e12
	HamsterSystem.interact(carol, ballC.Id)
	adv(2)
	place(bob, ballC.Position.X, 3, ballC.Position.Z + 6)
	HamsterSystem.interact(bob, ballC.Id)
	untilTrue(function() if ballC.State ~= "Carried" then place(bob, ballC.Position.X, 3, ballC.Position.Z + 3) end return ballC.State == "Carried" end, 4)
	place(bob, 600, 3, 0)
	adv(0.5)
	check("leaving the playing field drops the ball back inside the map", (ballC.State == "Dropped" or ballC.State == "Recoverable") and math.abs(ballC.Position.X) <= WorldLayout.GroundHalfX, tostring(ballC.Position))
	place(bob, 0, 3, -60)

	-- (d) payer leaves: the ball disappears and the price is refunded
	local erin = join("Erin")
	adv(5)
	data(erin).Coins = 1000000
	local ballD = spawnBall("Epic", alice, 3)
	adv(2)
	nearBall(erin, ballD)
	local before = data(erin).Coins
	HamsterSystem.interact(erin, ballD.Id)
	check("Erin paid for the ball", data(erin).Coins < before)
	local dData = data(erin)
	M.removePlayer(erin)
	adv(0.5)
	check("payer left: ball removed", HamsterSystem.get(ballD.Id) == nil)
	check("payer was refunded before the profile was saved", dData.Coins >= before - 5, string.format("%.0f vs %.0f", dData.Coins, before))
	report()

	-------------------------------------------------------------------
	section("Index UI: modes, inspect, milestones, final reward")
	-------------------------------------------------------------------
	local UIKit = require(find("StarterPlayer.StarterPlayerScripts.UI.UIKit"))
	local panel = UIKit.getPanel("Index")
	check("index panel exists", panel ~= nil)
	panel:Open()
	adv(0.6)
	local playerGui = RawData[alice].Props.PlayerGui or gui
	local function findNamed(root, name)
		for _, d in M.descendants(root) do
			if RawData[d].Name == name then return d end
		end
	end
	local clicks = 0
	for _, modeName in { "Theme", "World", "Event", "Rewards", "Rarity" } do
		local button = findNamed(gui, "Mode_" .. modeName)
		if button then
			RawData[button].Signals.Activated:Fire()
			adv(0.3)
			clicks += 1
		end
	end
	check("all five Index modes render without errors", clicks == 5 and #M.Sim.errors == 0, #M.Sim.errors)
	-- click a hamster card (opens the inspect popup)
	local card = nil
	for _, d in M.descendants(gui) do
		if RawData[d].ClassName == "TextButton" and RawData[d].Props.ZIndex == 5 then card = d break end
	end
	if card then RawData[card].Signals.Activated:Fire() adv(0.3) end
	check("inspect popup opens on a card click", card ~= nil and #M.Sim.errors == 0)
	-- milestones and the final reward are derived from data
	local IndexRewardConfig = require(find("ReplicatedStorage.Modules.IndexRewardConfig"))
	local EconomyMath = require(find("ReplicatedStorage.Modules.EconomyMath"))
	local d = data(alice)
	local coinBefore = EconomyMath.coinMultiplier(d, os.time())
	for _, species in HamsterDatabase.ByRarity["Basic"] do d.Index[species.Id] = true end
	local coinAfter = EconomyMath.coinMultiplier(d, os.time())
	check("Basic milestone: +5% coins (+ index bonus)", coinAfter / coinBefore > 1.05, string.format("x%.3f", coinAfter / coinBefore))
	check("Basic set complete gives the title", IndexRewardConfig.title(d) == "Basic Collector", IndexRewardConfig.title(d))
	for _, species in HamsterDatabase.Species do d.Index[species.Id] = true end
	check("whole Index gives the Hamster Master title", IndexRewardConfig.title(d) == "Hamster Master")
	local gemsBefore = d.Gems
	local claim = Remotes.func("Request"):InvokeServer("ClaimIndexReward", { Rarity = IndexRewardConfig.FinalKey })
	check("final prestige reward can be claimed once", claim.ok and d.Gems > gemsBefore, claim.msg)
	local again = Remotes.func("Request"):InvokeServer("ClaimIndexReward", { Rarity = IndexRewardConfig.FinalKey })
	check("...and not twice", not again.ok, again.msg)
	panel:Close()
	report()

	-------------------------------------------------------------------
	section("TEST 13: rebirth")
	-------------------------------------------------------------------
	local Remotes2 = Remotes
	local RebirthConfig = require(find("ReplicatedStorage.Modules.RebirthConfig"))
	data(alice).Coins = 10; EconomySystem.updateAttributes(alice)
	local rFail = Remotes2.func("Request"):InvokeServer("Rebirth", {})
	check("rebirth refused while requirements are unmet", not rFail.ok and data(alice).Rebirths == 0, rFail.msg)
	local CollectionSystem0 = require(find(Systems .. "CollectionSystem"))
	for i = 1, 6 do CollectionSystem0.grant(alice, HamsterDatabase.Spawnable["Rare"][i].Id, "Reward") end
	data(alice).Coins = RebirthConfig.cost(1) + 10; EconomySystem.updateAttributes(alice)
	local rNoSilver = Remotes2.func("Request"):InvokeServer("Rebirth", {})
	check("rebirth refused without the Silver hamster even with cash + hamsters", not rNoSilver.ok and data(alice).Rebirths == 0, rNoSilver.msg)
	CollectionSystem0.grant(alice, "silver", "Reward")
	data(alice).Coins = RebirthConfig.cost(1) + 10; EconomySystem.updateAttributes(alice)
	local slotsBefore = EconomyMath.slots(data(alice))
	local before_rebirth_total = 0
	for _, v in data(alice).Inventory do before_rebirth_total += v end
	local r = Remotes2.func("Request"):InvokeServer("Rebirth", {})
	check("rebirth succeeds", r.ok and data(alice).Rebirths == 1, r.msg)
	check("rebirth resets coins to starting coins", data(alice).Coins <= RebirthConfig.startingCoins(1) + 50, data(alice).Coins)
	check("rebirth gives +1 hamster slot", EconomyMath.slots(data(alice)) == slotsBefore + 1, EconomyMath.slots(data(alice)) .. " vs " .. slotsBefore)
	local kept = 0
	for _, v in data(alice).Inventory do kept += v end
	check("rebirth keeps the whole collection", kept == before_rebirth_total, kept .. " vs " .. tostring(before_rebirth_total))
	
	check("rebirth gives a better security tier", aliceHouse.Model:GetAttribute("SecTier") == "Advanced Security", aliceHouse.Model:GetAttribute("SecTier"))
	report()

	-------------------------------------------------------------------
	section("TEST 14: data saves and loads")
	-------------------------------------------------------------------
	local CollectionSystem = require(find(Systems .. "CollectionSystem"))
	CollectionSystem.grant(alice, speciesOf("Rare").Id, "Collect")
	adv(0.5)
	local aliceUserId = RawData[alice].Props.UserId
	local savedRebirths, savedInv = data(alice).Rebirths, 0
	for _, v in data(alice).Inventory do savedInv += v end
	local before = savedInv
	M.removePlayer(alice)
	adv(3)
	local alice2 = M.newPlayer("Alice")
	RawData[alice2].Props.UserId = aliceUserId
	fireJoin(alice2)
	M.spawnCharacter(alice2)
	adv(6)
	local loaded = DataSystem.get(alice2)
	local inv3 = 0
	for _, v in (loaded and loaded.Inventory or {}) do inv3 += v end
	check("profile reloaded after rejoin", loaded ~= nil and loaded.Rebirths == savedRebirths, loaded and loaded.Rebirths)
	check("collection preserved", loaded ~= nil and inv3 == before, string.format("%d vs %d", inv3, before))
	report()

	-------------------------------------------------------------------
	section("TEST 15: hotbar items, shop, tutorial, banners")
	-------------------------------------------------------------------
	M.localPlayerRef = alice2
	local Req = Remotes.func("Request")
	local function req(action, payload) return Req:InvokeServer(action, payload or {}) end
	local d = data(alice2)
	check("new tutorial data present for a fresh/old profile", d.Tutorial ~= nil)
	-- shop: diamonds
	d.Gems = 1000; d.Items = {}
	local r1 = req("ShopBuy", { Id = "boost_coins", Price = 1 })
	check("buy boost with diamonds (client price ignored)", r1.ok and d.Gems == 880 and d.Items.item_coins == 1, d.Gems)
	local r2 = req("ShopBuy", { Id = "boost_coins" })
	check("double click is refused (no second charge)", not r2.ok and d.Gems == 880 and d.Items.item_coins == 1, r2.msg)
	adv(0.6)
	d.Gems = 5
	local r3 = req("ShopBuy", { Id = "boost_luck" })
	check("insufficient diamonds: nothing taken, nothing granted", not r3.ok and d.Gems == 5 and (d.Items.item_luck or 0) == 0, r3.msg)
	check("unknown item refused", not req("ShopBuy", { Id = "gold_sword" }).ok)
	check("unavailable Robux item refused", not req("ShopBuy", { Id = "pass_coins" }).ok)
	d.Coins = 10000
	local r4 = req("ShopBuy", { Id = "tonic_cash" })
	check("buy item with cash", r4.ok and d.Coins == 7500 and d.Items.item_speed == 1, d.Coins)
	adv(0.6)
	d.Coins = 100
	check("not enough cash refused", not req("ShopBuy", { Id = "tonic_cash" }).ok and d.Coins == 100)
	adv(0.6)
	-- hotbar use
	local u1 = req("UseItem", { Id = "item_coins" })
	check("use owned item: boost active, count removed", u1.ok and d.Items.item_coins == nil and (d.Boosts.Coins2x or 0) > os.time(), u1.msg)
	adv(0.6)
	check("cannot use an item you do not own", not req("UseItem", { Id = "item_coins" }).ok)
	check("cannot use unknown / ability slots as items", not req("UseItem", { Id = "nope" }).ok and not req("UseItem", { Id = "slap" }).ok)
	d.Items.item_pouch = 1; d.Coins = 0
	adv(0.6)
	local u2 = req("UseItem", { Id = "item_pouch" })
	check("cash pouch pays out", u2.ok and d.Coins >= 1000 and d.Items.item_pouch == nil, d.Coins)
	-- shop categories only contain real items
	local ShopConfig = require(find("ReplicatedStorage.Modules.ShopConfig"))
	local cats = ShopConfig.categories()
	local names = {}
	for _, c in cats do table.insert(names, c.Id .. ":" .. #c.Items) end
	print("  shop categories:", table.concat(names, ", "))
	local hasEquipment, hasLimited, hasPasses = false, false, false
	for _, c in cats do hasEquipment = hasEquipment or c.Id == "Equipment"; hasLimited = hasLimited or c.Id == "Limited"; hasPasses = hasPasses or c.Id == "Gamepasses" end
	check("empty Limited category is hidden, Equipment (real items) and Game Passes shown", hasEquipment and not hasLimited and hasPasses)
	-- tutorial
	d.Tutorial = { Step = 1, Done = false, Skipped = false }
	check("ack of a later step is refused", not req("TutorialAck", { Step = "gate" }).ok and d.Tutorial.Step == 1)
	check("base ack", req("TutorialAck", { Step = "base" }).ok and d.Tutorial.Step == 2)
	check("hamster step cannot be skipped by button", not req("TutorialAck", { Step = "hamster" }).ok and d.Tutorial.Step == 2)
	d.Stats.Claimed = math.max(d.Stats.Claimed, 1); adv(2.5)
	check("buying a hamster advances the tutorial (a hamster is already on the bench here, so it moves on)", d.Tutorial.Step >= 3, d.Tutorial.Step)
	d.Equipped = d.Equipped or {}
	if #d.Equipped == 0 then d.Equipped = { "brownie" } end
	d.Stats.CoinsEarned = 0 -- (this test player has played a long time: start the income step from zero)
	adv(2.5)
	check("placing a hamster on the bench advances past 'bench' (the income step follows; this rich test player passes it at once - scn_tutorial tests the exact sequence)", d.Tutorial.Step >= 4, d.Tutorial.Step)
	check("the income step can never be skipped with a button", not req("TutorialAck", { Step = "income" }).ok)
	d.Stats.CoinsEarned = math.max(d.Stats.CoinsEarned, 50); adv(2.5)
	check("by now the tutorial is at 'lock your base'", d.Tutorial.Step == 5, d.Tutorial.Step)
	check("gate ack", req("TutorialAck", { Step = "gate" }).ok and d.Tutorial.Step == 6)
	check("upgrade ack", req("TutorialAck", { Step = "upgrade" }).ok and d.Tutorial.Step == 7)
	check("altar ack", req("TutorialAck", { Step = "altar" }).ok and d.Tutorial.Step == 8)
	check("wheel ack", req("TutorialAck", { Step = "wheel" }).ok and d.Tutorial.Step == 9)
	check("final ack completes it", req("TutorialAck", { Step = "leaderboard" }).ok and d.Tutorial.Done == true)
	check("done tutorial cannot be restarted/acked", not req("TutorialAck", { Step = "base" }).ok)
	d.Tutorial = { Step = 2, Done = false, Skipped = false }
	check("skip finishes the tutorial", req("TutorialSkip").ok and d.Tutorial.Done and d.Tutorial.Skipped)
	-- banners: Bob's base (starts locked)
	local bobHouse = HouseSystem.getHouse(bob)
	local tier = require(find("ReplicatedStorage.Modules.SecurityConfig")).tier(0)
	for _ = 1, 400 do
		if SecuritySystem.status(bobHouse) == "Ready" then break end
		adv(1)
	end
	M.remoteLog = {}
	local function fxCount(kind)
		local n = 0
		for _, e in M.remoteLog or {} do if e[1] == "Fx" and e[3] == kind and e[6] == bobHouse.Index then n += 1 end end
		return n
	end
	local function bannerEvents()
		local n = 0
		for _, e in M.remoteLog or {} do if e[1] == "Banner" then n += 1 end end
		return n
	end
	adv(3)
	check("no gate fx without a real transition", fxCount("SecurityOn") == 0 and fxCount("SecurityOff") == 0)
	SecuritySystem.activate(bobHouse); adv(0.6)
	check("turning the gate on -> exactly one SecurityOn effect", fxCount("SecurityOn") == 1 and fxCount("SecurityOff") == 0, fxCount("SecurityOn"))
	adv(require(find("ReplicatedStorage.Modules.SecurityConfig")).duration(0) + 1)
	check("gate switches off -> exactly one SecurityOff effect", fxCount("SecurityOff") == 1 and fxCount("SecurityOn") == 1, fxCount("SecurityOff"))
	adv(require(find("ReplicatedStorage.Modules.SecurityConfig")).recharge(tier) + 2)
	check("recharge finishing plays no extra gate effect", fxCount("SecurityOn") == 1 and fxCount("SecurityOff") == 1)
	check("the big base banner is never sent", bannerEvents() == 0)
	-- migration: a profile saved before the tutorial existed is treated as finished
	d.Tutorial = nil
	local aliceUserId2 = RawData[alice2].Props.UserId
	M.removePlayer(alice2)
	adv(3)
	local alice3 = M.newPlayer("Alice")
	RawData[alice3].Props.UserId = aliceUserId2
	fireJoin(alice3)
	M.spawnCharacter(alice3)
	adv(6)
	local d3 = DataSystem.get(alice3)
	check("old profile without Tutorial data -> tutorial marked done", d3 and d3.Tutorial and d3.Tutorial.Done == true)
	check("items persist across rejoin", d3 and type(d3.Items) == "table")
	report()

	section("summary")
	print(string.format("PASS %d  FAIL %d  game errors %d", results.pass, results.fail, #M.Sim.errors))
end)
M.Sim.advance(0)
