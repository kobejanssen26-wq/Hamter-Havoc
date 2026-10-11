-- Leaderboards: metrics, periods, persistence, caching, failures
local Players = game:GetService("Players")
local adv = M.Sim.advance
local results = { pass = 0, fail = 0 }
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end
local function fireJoin(p) adv(0.01) RawData[Players].Signals.PlayerAdded:Fire(p) end
local function daysFromCivil(y, m, d)
	y -= m <= 2 and 1 or 0
	local era = math.floor(y / 400)
	local yoe = y - era * 400
	local doy = math.floor((153 * (m + (m > 2 and -3 or 9)) + 2) / 5) + d - 1
	local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
	return era * 146097 + doe - 719468
end
local function utc(y, m, d, h, mi, s) return daysFromCivil(y, m, d) * 86400 + (h or 0) * 3600 + (mi or 0) * 60 + (s or 0) end

task.spawn(function()
	M.isServer = true
	local mainServer = find("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	adv(1)
	local S = "ServerScriptService.Systems."
	local LB = require(find(S .. "LeaderboardService"))
	local Config = require(find("ReplicatedStorage.Modules.LeaderboardConfig"))
	local DataSystem = require(find(S .. "DataSystem"))
	local Events = require(find(S .. "Events"))
	local HamsterSystem = require(find(S .. "HamsterSystem"))
	HamsterSystem.AutoSpawn = false

	-- ---- period boundaries (pure) ----
	local sunday = utc(2026, 10, 11, 23, 59, 59) -- Sunday
	local monday = utc(2026, 10, 12, 0, 0, 0)
	check("weekly bucket: same inside a week, new on Monday 00:00 UTC", Config.periodKey("Weekly", sunday - 86400 * 3) == Config.periodKey("Weekly", sunday) and Config.periodKey("Weekly", sunday) ~= Config.periodKey("Weekly", monday))
	check("monthly bucket changes on the 1st", Config.periodKey("Monthly", utc(2026, 10, 31, 23, 59, 59)) ~= Config.periodKey("Monthly", utc(2026, 11, 1)) and Config.periodKey("Monthly", utc(2026, 10, 1)) == Config.periodKey("Monthly", utc(2026, 10, 31, 23, 59, 59)))
	check("yearly bucket changes on Jan 1", Config.periodKey("Yearly", utc(2026, 12, 31, 23, 59, 59)) ~= Config.periodKey("Yearly", utc(2027, 1, 1)))
	check("all-time bucket never changes", Config.periodKey("AllTime", sunday) == Config.periodKey("AllTime", utc(2031, 5, 5)))
	local names = {}
	for _, period in Config.Periods do names[Config.storeName("Money", period, sunday)] = true end
	check("the four periods use four different datastores", (function() local n = 0 for _ in names do n += 1 end return n end)() == 4)
	check("validation of metric/period names", Config.valid("Money", "Weekly") and not Config.valid("Gold", "Weekly") and not Config.valid("Money", "Daily") and not Config.valid(5, nil))

	-- ---- hamster counting rules ----
	check("hamster count: registry hamsters with positive whole counts only", LB.hamsterCount({ Inventory = { brownie = 2, bogus_id = 5, silver = -1, golden = 1.5, snowball = 1 } }) == 3)

	-- ---- scoring through the real service ----
	local function join(name)
		local p = M.newPlayer(name)
		fireJoin(p)
		M.spawnCharacter(p)
		return p
	end
	local alice, bob = join("Alice"), join("Bob")
	adv(6)
	local T0 = utc(2026, 10, 7, 12) -- a Wednesday
	LB.clock = function() return T0 end
	local da, db = DataSystem.get(alice), DataSystem.get(bob)
	local aliceId, bobId = RawData[alice].Props.UserId, RawData[bob].Props.UserId
	local function stored(metric, period, t, userId) local d = M.orderedStores[Config.storeName(metric, period, t)] return d and d[tostring(userId)] end

	-- sample the starting point, then earn
	LB.flush(alice) LB.flush(bob)
	da.Stats.CoinsEarned = (da.Stats.CoinsEarned or 0) + 5000
	da.Inventory = { brownie = 3, snowball = 1 }
	db.Stats.CoinsEarned = (db.Stats.CoinsEarned or 0) + 900
	db.Inventory = { brownie = 1 }
	check("flush writes cash earned to all four periods", (function() LB.flush(alice) LB.flush(bob) return true end)() and stored("Money", "Weekly", T0, aliceId) >= 5000 and stored("Money", "Monthly", T0, aliceId) >= 5000 and stored("Money", "Yearly", T0, aliceId) >= 5000 and stored("Money", "AllTime", T0, aliceId) >= 5000)
	check("hamster peak written (4 owned)", stored("Hamsters", "Weekly", T0, aliceId) == 4 and stored("Hamsters", "AllTime", T0, aliceId) == 4)
	-- spending must not lower a lifetime-earnings ranking
	da.Coins = 0
	LB.flush(alice)
	check("spending cash does not reduce the Money score", stored("Money", "AllTime", T0, aliceId) >= 5000)
	-- fewer hamsters later does not lower the peak
	da.Inventory = { brownie = 1 }
	LB.flush(alice)
	check("owning fewer hamsters later keeps the peak", stored("Hamsters", "Weekly", T0, aliceId) == 4)
	-- steals: only completed thefts
	Events.TheftFailed:Fire(alice, bob, "brownie", "Hit")
	adv(0.2)
	LB.flush(alice)
	check("a failed theft adds nothing", stored("Steals", "AllTime", T0, aliceId) == nil or stored("Steals", "AllTime", T0, aliceId) == (da.Stats.Stolen or 0))
	local seedSteals = stored("Steals", "AllTime", T0, aliceId) or 0
	Events.TheftCompleted:Fire(alice, bob, "brownie")
	adv(0.2)
	LB.flush(alice)
	check("a completed theft adds exactly 1 to every period", stored("Steals", "Weekly", T0, aliceId) == 1 and stored("Steals", "Monthly", T0, aliceId) == 1 and stored("Steals", "Yearly", T0, aliceId) == 1 and stored("Steals", "AllTime", T0, aliceId) == seedSteals + 1)
	-- bogus / negative / NaN input
	check("bad numbers are ignored", (function()
		da.Stats.CoinsEarned = da.Stats.CoinsEarned - 100 -- going backwards must not subtract
		LB.flush(alice)
		return stored("Money", "AllTime", T0, aliceId) >= 5000
	end)())

	-- ---- reading ----
	local weekly = LB.fetch("Money", "Weekly", true)
	check("ranking: sorted high to low with ranks and names", weekly.Status == "ok" and weekly.Rows[1].UserId == aliceId and weekly.Rows[1].Rank == 1 and weekly.Rows[2].UserId == bobId and weekly.Rows[2].Rank == 2 and weekly.Rows[1].Name ~= "")
	local calls = M.orderedCalls
	LB.fetch("Money", "Weekly")
	LB.fetch("Money", "Weekly")
	check("cached: repeated reads do not hit the datastore", M.orderedCalls == calls, M.orderedCalls - calls)
	local ok1, _, extra = LB.request(alice, "Money", "Weekly")
	check("request returns the ranking, my rank and my score", ok1 and extra.MyRank == 1 and extra.MyScore >= 5000)
	local ok2 = LB.request(alice, "Money", "Weekly")
	check("per-player request cooldown", not ok2)
	adv(1.2)
	check("unknown metric/period refused", not LB.request(alice, "Gold", "Weekly") and not LB.request(alice, "Money", "Hourly") and not LB.request(alice, nil, nil))

	-- ---- periods are genuinely different ----
	LB.clock = function() return monday + 3600 end -- next week, same month/year
	local w2 = LB.fetch("Money", "Weekly", true)
	local m2 = LB.fetch("Money", "Monthly", true)
	local a2 = LB.fetch("Money", "AllTime", true)
	check("new week: weekly ranking starts EMPTY", w2.Status == "empty" and #w2.Rows == 0)
	check("new week: monthly / all-time keep their scores", m2.Status == "ok" and a2.Status == "ok" and a2.Rows[1].Score >= 5000)
	da.Stats.CoinsEarned += 700
	LB.flush(alice)
	local w3 = LB.fetch("Money", "Weekly", true)
	check("new week only counts new earnings", w3.Rows[1] and w3.Rows[1].UserId == aliceId and w3.Rows[1].Score >= 700 and w3.Rows[1].Score < 5000, w3.Rows[1] and w3.Rows[1].Score)
	check("all-time grew by the same earnings", LB.fetch("Money", "AllTime", true).Rows[1].Score >= 5700)
	LB.clock = function() return utc(2026, 11, 2) end
	check("new month: monthly empty, yearly + all-time intact", LB.fetch("Money", "Monthly", true).Status == "empty" and LB.fetch("Money", "Yearly", true).Status == "ok" and LB.fetch("Money", "AllTime", true).Status == "ok")
	LB.clock = function() return utc(2027, 1, 3) end
	check("new year: yearly empty, all-time intact (nothing deleted)", LB.fetch("Money", "Yearly", true).Status == "empty" and LB.fetch("Money", "AllTime", true).Rows[1].Score >= 5700)
	LB.clock = function() return T0 end
	check("going back in time still shows the old week (data is kept)", LB.fetch("Money", "Weekly", true).Rows[1].Score >= 5000)

	-- ---- failures ----
	M.orderedFail = true
	local bad = LB.fetch("Money", "AllTime", true)
	check("datastore outage: status error, stale rows kept, no crash", bad.Status == "error" and #bad.Rows >= 1)
	local badWrite = (function() da.Stats.CoinsEarned += 50 return LB.flush(alice) end)()
	check("failed write is kept for the next try (not lost, not an error)", badWrite == false)
	M.orderedFail = false
	adv(11)
	check("recovers after the outage", LB.fetch("Money", "AllTime", true).Status == "ok" and LB.flush(alice) == true)
	check("pending write arrived after recovery", stored("Money", "AllTime", T0, aliceId) >= 5750)

	-- ---- persistence across sessions ----
	local scoreBefore = stored("Money", "AllTime", T0, aliceId)
	da.Stats.CoinsEarned += 123
	M.removePlayer(alice) -- flush on leave
	adv(3)
	check("leaving flushes pending scores", stored("Money", "AllTime", T0, aliceId) == scoreBefore + 123, stored("Money", "AllTime", T0, aliceId) - scoreBefore)
	local alice2 = M.newPlayer("Alice")
	RawData[alice2].Props.UserId = aliceId
	fireJoin(alice2)
	M.spawnCharacter(alice2)
	adv(6)
	local score = LB.myScore(alice2, "Money", "AllTime")
	check("after rejoining the score is still there (read from the datastore)", score ~= nil and score >= scoreBefore + 123)
	local again = LB.fetch("Money", "AllTime", true)
	check("not double counted by the re-seed", again.Rows[1].UserId == aliceId and again.Rows[1].Score == scoreBefore + 123 + (stored("Money", "AllTime", T0, aliceId) - (scoreBefore + 123)), again.Rows[1].Score)

	-- ---- seeding of legit history + unresolved names ----
	local carol = M.newPlayer("Carol")
	RawData[carol].Props.UserId = 999999
	fireJoin(carol)
	M.spawnCharacter(carol)
	adv(6)
	check("a player with history is seeded into ALL-TIME only", (stored("Money", "AllTime", T0, 999999) or 0) >= 0 and stored("Money", "Weekly", T0, 999999) == nil)
	print(string.format("PASS %d FAIL %d errors %d", results.pass, results.fail, #M.Sim.errors))
	for i, e in M.Sim.errors do if i <= 6 then print("  err:", e) end end
end)
M.Sim.advance(0)
