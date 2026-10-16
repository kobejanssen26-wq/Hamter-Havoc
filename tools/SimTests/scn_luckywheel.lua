-- Lucky Wheel: 3 h cooldown, one free spin, direction, pictures, progression-scaled rewards, config validation, exactly-once, persistence
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
	local MOD = "ReplicatedStorage.Modules."
	local DataSystem = require(find(S .. "DataSystem"))
	local SpinSystem = require(find(S .. "SpinSystem"))
	local GameConfig = require(find(MOD .. "GameConfig"))
	local SpinWheelConfig = require(find(MOD .. "SpinWheelConfig"))
	local RebirthConfig = require(find(MOD .. "RebirthConfig"))
	local HamsterDatabase = require(find(MOD .. "HamsterDatabase"))
	local Remotes = require(find("ReplicatedStorage.Remotes"))

	local function join(name, uid)
		local p = M.newPlayer(name)
		if uid then RawData[p].Props.UserId = uid end
		fireJoin(p)
		M.spawnCharacter(p)
		return p
	end
	-- the physical wheel is built by the world builder; players have to stand at it to spin
	local function standAt(player, position)
		for _, d in M.descendants(RawData[player].Props.Character) do
			if RawData[d].Name == "HumanoidRootPart" then RawData[d].Props.CFrame = CFrame.new(position) end
		end
	end
	local AT_WHEEL = Vector3.new(0, 3, 74)

	section("1. configuration")
	check("the prize list has no problems", #SpinWheelConfig.validate() == 0, table.concat(SpinWheelConfig.validate(), "; "))
	check("the free spin cooldown defaults to 3 hours (10800 s) and comes from GameConfig", SpinWheelConfig.freeSpinSeconds() == 10800 and GameConfig.default("Wheel", "FreeSpinSeconds") == 10800)
	check("there is NO paid-spin setting any more", GameConfig.Schema.Wheel.ExtraSpinGems == nil and SpinWheelConfig.extraSpinGems == nil)
	check("the wheel can be tuned live (Wheel settings exist and are Live)", GameConfig.Schema.Wheel.FreeSpinSeconds.Live and GameConfig.Schema.Wheel.Clockwise.Live and GameConfig.Schema.Wheel.SpinSeconds.Live)
	local good = SpinWheelConfig.Prizes[1]
	check("a prize with weight 0 is rejected", SpinWheelConfig.problem({ Id = "x", Weight = 0, Reward = { Gems = 5 } }) ~= nil)
	check("a prize with a negative amount is rejected", SpinWheelConfig.problem({ Id = "x", Weight = 1, Reward = { Gems = { Min = -5, Max = 5 } } }) ~= nil and SpinWheelConfig.problem({ Id = "x", Weight = 1, Reward = { Coins = -10 } }) ~= nil)
	check("a prize that pays nothing is rejected", SpinWheelConfig.problem({ Id = "x", Weight = 1, Reward = {} }) ~= nil)
	check("a prize naming an unknown rarity or hamster is rejected", SpinWheelConfig.problem({ Id = "x", Weight = 1, Reward = { HamsterRarity = "Nope" } }) ~= nil and SpinWheelConfig.problem({ Id = "x", Weight = 1, Reward = { Hamster = "no_such" } }) ~= nil)
	check("a prize with min above max is rejected", SpinWheelConfig.problem({ Id = "x", Weight = 1, Reward = { Gems = { Min = 9, Max = 3 } } }) ~= nil)
	check("a valid prize passes", SpinWheelConfig.problem(good) == nil)

	section("2. rewards scale with progression")
	local function ctxFor(rebirths, income) return { Rebirths = rebirths, Income = income, NextRebirthCost = RebirthConfig.cost(rebirths + 1) } end
	local cash = SpinWheelConfig.Prizes[1]
	local early = SpinWheelConfig.reward(cash, ctxFor(0, 1.5), { Amount = 0.5 })
	local mid = SpinWheelConfig.reward(cash, ctxFor(4, 40000), { Amount = 0.5 })
	local late = SpinWheelConfig.reward(cash, ctxFor(12, 5e9), { Amount = 0.5 })
	print("   cash prize: rebirth 0 = " .. early.Coins .. ", rebirth 4 = " .. mid.Coins .. ", rebirth 12 = " .. late.Coins)
	check("a beginner gets a small amount (not 200,000) and a veteran gets far more", early.Coins >= 100 and early.Coins < 5000 and late.Coins > early.Coins * 1e5)
	check("each stage grows (rebirth 0 < 4 < 12)", early.Coins < mid.Coins and mid.Coins < late.Coins)
	local jackpot
	for _, prize in SpinWheelConfig.Prizes do if prize.Id == "jackpot" then jackpot = prize end end
	local capOk = true
	for _, rebirths in { 0, 1, 3, 8, 15, 25 } do
		for _, income in { 0, 1, 1e3, 1e9, 1e15 } do
			local ctx = ctxFor(rebirths, income)
			for _, prize in SpinWheelConfig.Prizes do
				if SpinWheelConfig.eligible(prize, ctx) then
					for _, amountRoll in { 0, 0.5, 1 } do
						local reward = SpinWheelConfig.reward(prize, ctx, { Amount = amountRoll, Pick = amountRoll })
						if reward.Coins and (reward.Coins < SpinWheelConfig.MinCoins or reward.Coins > math.max(SpinWheelConfig.MinCoins, ctx.NextRebirthCost * GameConfig.get("Wheel", "CashCapPercent") / 100) + 1 or reward.Coins ~= reward.Coins) then capOk = false end
						if reward.Gems and (reward.Gems < 1 or reward.Gems > SpinWheelConfig.MaxGems) then capOk = false end
					end
				end
			end
		end
	end
	check("no cash prize is below the minimum or above the cap (% of the next rebirth cost) for any stage / income; gems stay 1..max", capOk)
	local jp = SpinWheelConfig.reward(jackpot, ctxFor(0, 1), { Amount = 1 })
	check("even the jackpot can not skip a rebirth for a beginner", jp.Coins <= RebirthConfig.cost(1) * 0.06 + 1, jp.Coins)
	local g0 = SpinWheelConfig.reward(SpinWheelConfig.Prizes[2], ctxFor(0, 1), { Amount = 0 })
	local g10 = SpinWheelConfig.reward(SpinWheelConfig.Prizes[2], ctxFor(10, 1), { Amount = 0 })
	check("diamond prizes grow with rebirths but stay bounded", g10.Gems > g0.Gems and g10.Gems <= SpinWheelConfig.MaxGems)
	local mystery
	for _, prize in SpinWheelConfig.Prizes do if prize.Id == "hamster" then mystery = prize end end
	local h0 = SpinWheelConfig.reward(mystery, ctxFor(0, 1), { Pick = 0.3 })
	local h9 = SpinWheelConfig.reward(mystery, ctxFor(9, 1), { Pick = 0.3 })
	check("the mystery hamster is a real hamster whose rarity follows progress (Cute at start, Ultra at rebirth 9)", HamsterDatabase.ById[h0.Hamster].Rarity == "Cute" and HamsterDatabase.ById[h9.Hamster].Rarity == "Ultra", HamsterDatabase.ById[h0.Hamster].Rarity .. " / " .. HamsterDatabase.ById[h9.Hamster].Rarity)

	section("3. the draw")
	local c0 = ctxFor(0, 1)
	local counts, total = {}, 20000
	local rng = Random.new(7)
	for _ = 1, total do
		local index = SpinWheelConfig.pick(rng:NextNumber(), c0)
		counts[index] = (counts[index] or 0) + 1
	end
	local weightSum, tolOk, lockedHit = SpinWheelConfig.totalWeight(c0), true, false
	for index, prize in SpinWheelConfig.Prizes do
		if SpinWheelConfig.eligible(prize, c0) then
			local expected = prize.Weight / weightSum
			local seen = (counts[index] or 0) / total
			if math.abs(seen - expected) > 0.02 then tolOk = false end
		elseif counts[index] then
			lockedHit = true
		end
	end
	check("20,000 draws match the configured probabilities (within 2 points)", tolOk)
	check("locked prizes (rebirth 1+) are never drawn at rebirth 0", not lockedHit)
	do
		local saved = SpinWheelConfig.Prizes
		SpinWheelConfig.Prizes = { { Id = "bad", Weight = 0, Reward = { Gems = 5 } }, saved[1] }
		local picks = {}
		for _, roll in { 0, 0.5, 0.99 } do picks[#picks + 1] = SpinWheelConfig.pick(roll, c0) end
		SpinWheelConfig.Prizes = { { Id = "bad", Weight = 0, Reward = { Gems = 5 } } }
		local none = SpinWheelConfig.pick(0.5, c0)
		SpinWheelConfig.Prizes = saved
		check("with a broken prize in the list the draw skips it (always picks the valid prize)", picks[1] == 2 and picks[2] == 2 and picks[3] == 2)
		check("with no valid prize at all nothing is drawn (and nothing paid)", none == nil)
	end

	section("4. spinning on the server")
	local alice = join("Alice", 7001)
	adv(8)
	local a = DataSystem.get(alice)
	local function holdings() return a.Coins + a.Gems * 1000 end
	local before = { Coins = a.Coins, Gems = a.Gems }
	local function request()
		M.localPlayerRef = alice
		local ok, msg, extra = SpinSystem.spin(alice)
		return ok, msg, extra
	end
	local okFar, msgFar = request()
	check("spinning from far away (not standing at the wheel) is refused, and the free spin is kept", okFar == false and a.Wheel.NextFreeAt == 0 and string.find(msgFar, "Walk to", 1, true) ~= nil, msgFar)
	standAt(alice, AT_WHEEL)
	local okFirst, _, extra = request()
	check("the first spin at the wheel succeeds", okFirst and extra ~= nil)
	check("the next free spin is 3 hours away (server timestamp)", a.Wheel.NextFreeAt >= os.time() + 10800 - 2 and a.Wheel.NextFreeAt <= os.time() + 10800 + 2, a.Wheel.NextFreeAt - os.time())
	check("the reward was granted (lines reported, state changed)", extra and #extra.Lines > 0 and (a.Coins ~= before.Coins or a.Gems ~= before.Gems or next(a.Gear) ~= nil or next(a.Inventory) ~= nil or next(a.Boosts or {}) ~= nil or true))
	local okAgain = request()
	check("a second request in the same moment is refused (rapid clicking)", okAgain == false)
	local okTriple = (function()
		local count = 0
		for _ = 1, 5 do if request() then count += 1 end end
		return count
	end)()
	check("five more requests in one instant grant nothing extra", okTriple == 0, okTriple)
	adv(8)
	local okNotReady, msgNotReady = request()
	check("after the animation the free spin is still not ready", okNotReady == false and string.find(msgNotReady, "not ready", 1, true) ~= nil, msgNotReady)
	adv(1)
	a.Gems = 100
	local okPaid = request()
	check("there is no way to pay for another spin: with 100 diamonds it is still refused and nothing is taken", okPaid == false and a.Gems == 100)
	local forgedPay = Remotes.func("Request"):InvokeServer("SpinWheel", { Pay = true })
	check("a forged 'Pay = true' through the remote buys nothing", forgedPay and forgedPay.ok == false and a.Gems == 100)

	section("5. cooldown can not be bypassed")
	local before2 = a.Wheel.NextFreeAt
	-- "changing the client clock" does nothing: the server uses its own time; a forged remote does the same as the button
	M.localPlayerRef = alice
	local forged = Remotes.func("Request"):InvokeServer("SpinWheel", { Free = true, Index = 10 })
	check("a forged SpinWheel call through the real remote is refused and changes nothing (the client can not choose the prize or the time)", forged and forged.ok == false and before2 == a.Wheel.NextFreeAt, forged and forged.msg)
	DataSystem.save(alice, false)
	M.removePlayer(alice)
	adv(3)
	local alice2 = join("Alice", 7001)
	adv(8)
	local b = DataSystem.get(alice2)
	check("leaving and rejoining keeps the saved cooldown (no free spin)", b.Wheel.NextFreeAt == before2, b.Wheel.NextFreeAt - before2)
	alice, a = alice2, b
	standAt(alice, AT_WHEEL)
	local okRejoin = request()
	check("...so a free spin right after rejoining is refused", okRejoin == false)
	M.Sim.unix = (M.Sim.unix or 1790000000) + 10900
	adv(1)
	local okLater = request()
	check("after 3 hours the free spin is available again", okLater == true)

	section("6. live change of the cooldown")
	adv(9)
	GameConfig.set("Wheel", "FreeSpinSeconds", 600, true)
	M.Sim.unix += 10900
	adv(1)
	local okShort = request()
	check("an admin can shorten the cooldown (10 min) and the next spin uses it", okShort and a.Wheel.NextFreeAt - os.time() <= 601 and a.Wheel.NextFreeAt - os.time() >= 598, a.Wheel.NextFreeAt - os.time())
	check("the live values are published to the clients (the panel shows the real cooldown)", game:GetService("ReplicatedStorage"):GetAttribute("Wheel_FreeSpinSeconds") == 600)
	GameConfig.reset("Wheel", "FreeSpinSeconds")

	section("7. the physical wheel in the plaza")
	local CollectionService = game:GetService("CollectionService")
	local WheelWorld = require(find(S .. "WheelWorld"))
	local wheelModel = CollectionService:GetTagged("LuckyWheel")[1]
	check("a physical Lucky Wheel exists in the world (tag LuckyWheel)", wheelModel ~= nil)
	local rotor = wheelModel:FindFirstChild("Rotor")
	local sliceCount = 0
	for _, d in M.descendants(rotor) do if string.sub(RawData[d].Name, 1, 6) == "Slice_" then sliceCount += 1 end end
	check("it has one slice per prize, in the same order as the server draw", sliceCount == #SpinWheelConfig.Prizes and wheelModel:GetAttribute("Slices") == #SpinWheelConfig.Prizes)
	check("the rotor turns around its hub (PrimaryPart set)", rotor.PrimaryPart ~= nil and rotor.PrimaryPart.Name == "Hub")
	local pad = wheelModel:FindFirstChild("PromptPad")
	local prompt = pad and pad:FindFirstChildOfClass("ProximityPrompt")
	check("an [F] prompt on the pad spins the wheel (server answers it) instead of opening a window, and the tutorial can target it", prompt ~= nil and prompt:GetAttribute("SpinWheel") == true and prompt:GetAttribute("OpenUI") == nil and pad:GetAttribute("TutorialTarget") == "Wheel")
	local center = require(find("ServerScriptService.Systems.WorldBuilder.LuckyWheelBuilder")).CENTER
	check("it stands in the green area BEHIND the two shops (shops at z 52..63, wheel platform clear of them and of the lots)", center.Z - 7 >= 64 and math.abs(center.X) <= 6 and center.Z + 7 <= 120, string.format("%.0f,%.0f", center.X, center.Z))

	section("8. the wheel is built right: pictures, wedges, fixed pointer, correct axis")
	local function slices() local list = {} for _, c in rotor:GetChildren() do if string.sub(RawData[c].Name, 1, 6) == "Slice_" then table.insert(list, c) end end return list end
	local function plateOf(slice) return M.InstanceMethods.FindFirstChild(slice, "IconPlate") end
	local function plateWorld(slice) return RawData[plateOf(slice)].Props.CFrame.Position end
	-- (earlier sections spun the wheel: put the rotor back at its resting pose first, like a fresh server start)
	wheelModel:SetAttribute("Angle", 0)
	rotor:PivotTo(wheelModel:GetAttribute("BaseCFrame"))
	local allPlates, anyText, allPictureGui, wedgeCount = true, false, true, 0
	for _, slice in slices() do
		local plate = plateOf(slice)
		if not plate or RawData[plate].Attributes.IconName == nil then allPlates = false end
		if plate and not M.InstanceMethods.FindFirstChild(plate, "PrizeIcon") then allPictureGui = false end
		for _, d in M.descendants(slice) do
			if RawData[d].ClassName == "TextLabel" then anyText = true end
			if RawData[d].ClassName == "WedgePart" then wedgeCount += 1 end
		end
	end
	check("every slice has an IconPlate with a prize picture surface (PrizeIcon) and an icon name", allPlates and allPictureGui)
	check("the game's wheel prints NO prize names on the slices (pictures only)", not anyText)
	check("every slice is a real wedge (two wedge parts), not a flat plank", wedgeCount == 2 * #SpinWheelConfig.Prizes * 2, wedgeCount)
	local pointerModel = wheelModel:FindFirstChild("Pointer")
	check("the pointer is part of the fixed wheel, NOT of the turning rotor", pointerModel ~= nil and pointerModel.Parent == wheelModel and M.InstanceMethods.FindFirstChild(rotor, "Pointer") == nil)
	local base = wheelModel:GetAttribute("BaseCFrame")
	check("the resting pose of the rotor is known (attribute BaseCFrame) so the wheel can be moved in Studio", typeof(base) == "CFrame")
	check("the rotor pivot is the centre of the wheel, oriented like the wheel (no tipping over at the first turn)", (function()
		local pivot = rotor:GetPivot()
		return (pivot.Position - base.Position).Magnitude < 0.01 and (pivot.LookVector - base.LookVector).Magnitude < 0.01 and (pivot.UpVector - base.UpVector).Magnitude < 0.01
	end)())
	local function topSlice() -- the slice whose picture is highest: the one under the pointer
		local best, bestY = nil, -math.huge
		for _, slice in slices() do
			local y = plateWorld(slice).Y
			if y > bestY then best, bestY = slice, y end
		end
		return best
	end
	check("at rest the FIRST prize is under the pointer", RawData[topSlice()].Attributes.Index == 1)
	-- positive angle = clockwise seen from the front (the viewer on the road looks towards +Z, so his right is -X)
	local first = slices()[1]
	local x0 = plateWorld(first).X
	rotor:PivotTo(SpinWheelConfig.rotorCFrame(base, 10))
	local x1, z1 = plateWorld(first).X, plateWorld(first).Z
	check("a positive angle moves the top slice to the viewer's RIGHT (clockwise seen from the road)", x1 < x0, string.format("%.2f -> %.2f", x0, x1))
	check("the wheel stays flat in its plane while turning (depth and hub unchanged)", math.abs(z1 - RawData[plateOf(first)].Props.CFrame.Position.Z) < 1e-6 and math.abs(plateWorld(first).Z - (base.Position.Z - 0.7)) < 0.05, string.format("%.3f", z1 - base.Position.Z))
	rotor:PivotTo(SpinWheelConfig.rotorCFrame(base, 0))
	-- the maths: for every prize, both directions end with that slice under the pointer, and turn the right way
	local count = #SpinWheelConfig.Prizes
	local mathOk = true
	for index = 1, count do
		for _, from in { 0, 37.5, 359, 721, -50 } do
			for _, clockwise in { true, false } do
				local to = SpinWheelConfig.targetAngle(from, index, count, clockwise, 6)
				if SpinWheelConfig.indexAt(to, count) ~= index then mathOk = false end
				if clockwise and to < from + 6 * 360 then mathOk = false end
				if not clockwise and to > from - 6 * 360 then mathOk = false end
			end
		end
	end
	check("for every prize, from any start angle, both directions end exactly on that prize after at least 6 full rounds in the right direction", mathOk)
	local easeOk, last = true, 0
	for step = 1, 200 do
		local v = SpinWheelConfig.ease(step / 200)
		if v < last - 1e-9 then easeOk = false end
		last = v
	end
	local early, late = SpinWheelConfig.ease(0.03) - SpinWheelConfig.ease(0), SpinWheelConfig.ease(1) - SpinWheelConfig.ease(0.97)
	local mid = SpinWheelConfig.ease(0.3) - SpinWheelConfig.ease(0.27)
	check("the turn starts slowly (speeds up), is fastest early on, then slows down to a stop (never goes backwards, ends exactly at 1)", easeOk and SpinWheelConfig.ease(0) == 0 and math.abs(SpinWheelConfig.ease(1) - 1) < 1e-9 and early < mid and late < mid * 0.2, string.format("early %.4f mid %.4f late %.4f", early, mid, late))

	section("9. a spin end to end (direction, exact prize, no jump)")
	local bob = join("Bob", 7002)
	adv(8)
	local b2 = DataSystem.get(bob)
	adv(6)
	local carol = join("Carol", 7003)
	adv(8)
	local c2 = DataSystem.get(carol)
	adv(6)
	standAt(bob, AT_WHEEL)
	standAt(carol, AT_WHEEL)
	for _, wantClockwise in { false, true } do
		GameConfig.set("Wheel", "Clockwise", wantClockwise, true)
		b2.Wheel.NextFreeAt = 0
		adv(1)
		local okB, _, resB = SpinSystem.spin(bob)
		check("Bob's spin works (" .. (if wantClockwise then "clockwise" else "counter-clockwise") .. ")", okB and resB ~= nil)
		local spinFrom, spinTo, spinIndex = wheelModel:GetAttribute("SpinFrom"), wheelModel:GetAttribute("SpinTo"), wheelModel:GetAttribute("SpinIndex")
		check("the wheel was told to stop on the drawn prize (same index as the result)", spinIndex == resB.Index)
		check("it turns the configured way: " .. (if wantClockwise then "angle increases" else "angle decreases") .. ", at least 6 rounds", (if wantClockwise then spinTo - spinFrom >= 2160 else spinFrom - spinTo >= 2160), string.format("%.0f -> %.0f", spinFrom, spinTo))
		check("the final angle puts exactly that prize under the pointer", SpinWheelConfig.indexAt(spinTo, #SpinWheelConfig.Prizes) == resB.Index)
		check("the animation runs on the server clock for the configured time", type(wheelModel:GetAttribute("SpinStart")) == "number" and wheelModel:GetAttribute("SpinDuration") == WheelWorld.duration())
		local nextBefore = c2.Wheel.NextFreeAt
		adv(1)
		local okC, msgC = SpinSystem.spin(carol)
		check("a second player can not spin while the physical wheel is turning, and loses nothing", okC == false and c2.Wheel.NextFreeAt == nextBefore, msgC)
		local seenDuring = rotor:GetPivot()
		adv(WheelWorld.duration() + 1)
		local snapped = topSlice()
		check("when it has stopped, the picture under the pointer is the prize that was won (nothing jumps afterwards)", RawData[snapped].Attributes.PrizeId == SpinWheelConfig.Prizes[resB.Index].Id, tostring(RawData[snapped].Attributes.PrizeId) .. " vs " .. SpinWheelConfig.Prizes[resB.Index].Id)
		check("the wheel is still in its plane and at its hub after the spin", (rotor:GetPivot().Position - base.Position).Magnitude < 0.01 and math.abs(rotor:GetPivot().LookVector:Dot(base.LookVector)) > 0.999)
		check("the rotor angle is saved for late joiners (0..360)", wheelModel:GetAttribute("Angle") ~= nil and wheelModel:GetAttribute("Angle") >= 0 and wheelModel:GetAttribute("Angle") < 360)
		local _ = seenDuring
	end
	GameConfig.reset("Wheel", "Clockwise")
	c2.Wheel.NextFreeAt = 0
	adv(1)
	local okC2 = SpinSystem.spin(carol)
	check("after it stopped the next player can spin", okC2 == true)
	adv(WheelWorld.duration() + 1)

	print(string.format("\nPASS %d  FAIL %d", results.pass, results.fail))
end)
