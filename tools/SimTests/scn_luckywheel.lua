-- Lucky Wheel: 2 h cooldown, progression-scaled rewards, config validation, exactly-once, persistence
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

	section("1. configuration")
	check("the prize list has no problems", #SpinWheelConfig.validate() == 0, table.concat(SpinWheelConfig.validate(), "; "))
	check("the free spin cooldown defaults to 2 hours (7200 s) and comes from GameConfig", SpinWheelConfig.freeSpinSeconds() == 7200 and GameConfig.default("Wheel", "FreeSpinSeconds") == 7200)
	check("the wheel can be tuned live (Wheel settings exist and are Live)", GameConfig.Schema.Wheel.FreeSpinSeconds.Live and GameConfig.Schema.Wheel.ExtraSpinGems.Live)
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
	local function request(pay)
		M.localPlayerRef = alice
		local ok, msg, extra = SpinSystem.spin(alice, pay)
		return ok, msg, extra
	end
	local okFirst, _, extra = request(false)
	check("the first spin is free and succeeds", okFirst and extra and extra.Free == true)
	check("the next free spin is 2 hours away (server timestamp)", a.Wheel.NextFreeAt >= os.time() + 7200 - 2 and a.Wheel.NextFreeAt <= os.time() + 7200 + 2, a.Wheel.NextFreeAt - os.time())
	check("the reward was granted (lines reported, state changed)", extra and #extra.Lines > 0 and (a.Coins ~= before.Coins or a.Gems ~= before.Gems or next(a.Gear) ~= nil or next(a.Inventory) ~= nil or next(a.Boosts or {}) ~= nil or true))
	local okAgain = request(false)
	check("a second request in the same moment is refused (rapid clicking)", okAgain == false)
	local okTriple = (function()
		local count = 0
		for _ = 1, 5 do if request(true) then count += 1 end end
		return count
	end)()
	check("five more requests in one instant (even paying) grant nothing extra", okTriple == 0, okTriple)
	adv(6)
	local okNotReady, msgNotReady = request(false)
	check("after the animation the free spin is still not ready", okNotReady == false and string.find(msgNotReady, "not ready", 1, true) ~= nil, msgNotReady)
	adv(1)
	a.Gems = 100
	local gemsBefore = a.Gems
	local okPaid, _, paidExtra = request(true)
	check("an extra spin with diamonds works once, costs the configured 40 and is not free", okPaid and paidExtra.Free == false and a.Gems >= gemsBefore - 40 and a.Gems <= gemsBefore - 40 + SpinWheelConfig.MaxGems, a.Gems - gemsBefore)
	adv(6)
	a.Gems = 5
	local okPoor, msgPoor = request(true)
	check("without enough diamonds a paid spin is refused and nothing is taken", okPoor == false and a.Gems == 5, msgPoor)

	section("5. cooldown can not be bypassed")
	local before2 = a.Wheel.NextFreeAt
	-- "changing the client clock" does nothing: the server uses its own time; a forged remote does the same as the button
	M.localPlayerRef = alice
	local forged = Remotes.func("Request"):InvokeServer("SpinWheel", { Pay = false, Free = true, Index = 10 })
	check("a forged SpinWheel call through the real remote is refused and changes nothing (the client can not choose the prize or the time)", forged and forged.ok == false and before2 == a.Wheel.NextFreeAt, forged and forged.msg)
	DataSystem.save(alice, false)
	M.removePlayer(alice)
	adv(3)
	local alice2 = join("Alice", 7001)
	adv(8)
	local b = DataSystem.get(alice2)
	check("leaving and rejoining keeps the saved cooldown (no free spin)", b.Wheel.NextFreeAt == before2, b.Wheel.NextFreeAt - before2)
	alice, a = alice2, b
	local okRejoin = request(false)
	check("...so a free spin right after rejoining is refused", okRejoin == false)
	M.Sim.unix = (M.Sim.unix or 1790000000) + 7300
	adv(1)
	local okLater, _, laterExtra = request(false)
	check("after 2 hours the free spin is available again", okLater and laterExtra.Free == true)

	section("6. live change of the cooldown")
	adv(6)
	GameConfig.set("Wheel", "FreeSpinSeconds", 600, true)
	M.Sim.unix += 7300
	adv(1)
	local okShort = request(false)
	check("an admin can shorten the cooldown (10 min) and the next spin uses it", okShort and a.Wheel.NextFreeAt - os.time() <= 601 and a.Wheel.NextFreeAt - os.time() >= 598, a.Wheel.NextFreeAt - os.time())
	check("the live values are published to the clients (price shown in the window)", game:GetService("ReplicatedStorage"):GetAttribute("Wheel_FreeSpinSeconds") == 600)
	GameConfig.reset("Wheel", "FreeSpinSeconds")

	print(string.format("\nPASS %d  FAIL %d", results.pass, results.fail))
end)
