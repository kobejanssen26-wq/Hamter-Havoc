--[[
	Economy simulation. Plays the real configs (RarityConfig, HamsterDatabase, EconomyMath,
	RebirthConfig, UpgradeConfig, FloorConfig) second by second for one player on a 1-player server
	(the slowest case: fewest spawns) and prints where they are after 5 min ... 12 h.

	Player model: claims a ball when it can afford it and it improves income (or it is needed for the
	next rebirth), catches 85% of them (others steal / it is too far), the ball needs ~25 s to roll home,
	buys coin upgrades with a short payback, rebirths as soon as all requirements are met and saves up
	once only coins are missing. No daily rewards, quests or codes (those are extra on top).

	usage: lune run tools/lune/economy_sim.luau [hours=12] [seed=7] [profile=active|casual]
]]

local process = require("@lune/process")
local Runtime = require("./runtime")

local HOURS = tonumber(process.args[1]) or 12
local SEED = tonumber(process.args[2]) or 7
local PROFILE = process.args[3] or "active"

Runtime.boot(process.env.PROJECT or ".")
Runtime.quiet = true
local RarityConfig = Runtime.mod("RarityConfig")
local HamsterDatabase = Runtime.mod("HamsterDatabase")
local EconomyMath = Runtime.mod("EconomyMath")
local RebirthConfig = Runtime.mod("RebirthConfig")
local UpgradeConfig = Runtime.mod("UpgradeConfig")
local FloorConfig = Runtime.mod("FloorConfig")
local Template = Runtime.mod("ProfileTemplate")

local random = Runtime.Random.new(SEED)
local CATCH = if PROFILE == "casual" then 0.55 else 0.85
local ATTENTION = if PROFILE == "casual" then 0.6 else 1 -- share of spawns the player even looks at
local TRANSIT = 25
local SPAWN_INTERVAL = 5.25

local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in t do
		c[k] = deepCopy(v)
	end
	return c
end

local data = deepCopy(Template)
local now = 0
local pending = {} -- { At, SpeciesId }
local log = {}
local rebirthTimes = {}

local function rarityOf(id)
	local s = HamsterDatabase.ById[id]
	return s and s.Rarity
end

local function equipBest()
	local entries = {}
	for id, count in data.Inventory do
		for _ = 1, count do
			table.insert(entries, { Id = id, Income = HamsterDatabase.income(HamsterDatabase.ById[id]) })
		end
	end
	table.sort(entries, function(a, b)
		return a.Income > b.Income
	end)
	data.Equipped = {}
	for i = 1, math.min(#entries, EconomyMath.slots(data)) do
		table.insert(data.Equipped, entries[i].Id)
	end
end

local function worstEquippedIncome(): number
	local worst = math.huge
	for _, id in data.Equipped do
		worst = math.min(worst, HamsterDatabase.income(HamsterDatabase.ById[id]))
	end
	return worst
end

local function income(): number
	return EconomyMath.incomePerSecond(data, 0)
end

local function owned(): number
	local n = 0
	for _, c in data.Inventory do
		n += c
	end
	return n + #pending
end

local function bestRank(): number
	local best = 0
	for id, c in data.Inventory do
		if c > 0 then
			best = math.max(best, RarityConfig.rank(rarityOf(id)))
		end
	end
	return best
end

local function onlyCoinsMissing(): boolean
	local checks = RebirthConfig.check(data, rarityOf)
	if #checks == 0 then
		return false
	end
	for _, c in checks do
		if c.Kind ~= "Coins" and not c.Met then
			return false
		end
	end
	return true
end

local function tryBuyUpgrades()
	local inc = income()
	local saving = onlyCoinsMissing()
	local floors = FloorConfig.unlocked(data.Rebirths)
	for _, id in UpgradeConfig.Order do
		local def = UpgradeConfig.Definitions[id]
		if not UpgradeConfig.available(id, floors) then
			continue
		end
		local level = data.Upgrades[id] or 0
		local cost = UpgradeConfig.cost(id, level, data.Rebirths)
		if not cost then
			continue
		end
		if def.Currency == "Tokens" then
			if (id == "RebirthBoost" or id == "LuckyCharms") and data.Tokens >= cost then
				data.Tokens -= cost
				data.Upgrades[id] = level + 1
			end
			continue
		end
		local budget = if saving then RebirthConfig.cost(data.Rebirths + 1) * 0.02 else data.Coins * 0.5
		if cost > budget or cost > data.Coins then
			continue
		end
		local worth = false
		if id == "HamsterTraining" or id == "CoinMultiplier" or id == "TurboWheels" then
			-- marginal gain of one more level
			local before = inc
			data.Upgrades[id] = level + 1
			local after = income()
			data.Upgrades[id] = level
			worth = (after - before) * 300 > cost
		elseif id == "ExtraStorage" then
			worth = #data.Equipped >= EconomyMath.slots(data) and cost < inc * 400
		elseif id == "SpawnLuck" then
			worth = cost < inc * 900
		end
		if worth then
			data.Coins -= cost
			data.Upgrades[id] = level + 1
			inc = income()
		end
	end
end

local function rebirth()
	local n = data.Rebirths + 1
	local keep = RebirthConfig.keepBest(n)
	local kept = {}
	if keep > 0 then
		local entries = {}
		for id, c in data.Inventory do
			for _ = 1, c do
				table.insert(entries, id)
			end
		end
		table.sort(entries, function(a, b)
			return HamsterDatabase.income(HamsterDatabase.ById[a]) > HamsterDatabase.income(HamsterDatabase.ById[b])
		end)
		for i = 1, math.min(keep, #entries) do
			kept[entries[i]] = (kept[entries[i]] or 0) + 1
		end
	end
	data.Rebirths = n
	data.Coins = RebirthConfig.startingCoins(n)
	data.Inventory = kept
	for id, def in UpgradeConfig.Definitions do
		if def.ResetOnRebirth then
			data.Upgrades[id] = nil
		end
	end
	data.Gems += RebirthConfig.gemReward(n)
	data.Tokens += RebirthConfig.tokenReward(n)
	pending = {}
	equipBest()
	table.insert(rebirthTimes, now)
end

local function maybeClaim(species)
	if random:NextNumber() > ATTENTION then
		return
	end
	local price = HamsterDatabase.price(species)
	if price > data.Coins then
		return
	end
	local n = data.Rebirths + 1
	local req = if n <= RebirthConfig.MaxRebirths then RebirthConfig.requirements(n) else nil
	local inc = HamsterDatabase.income(species)
	local slots = EconomyMath.slots(data)
	local improves = (#data.Equipped + #pending < slots) or inc > worstEquippedIncome() * 1.05
	local saving = onlyCoinsMissing()
	local want = false
	if saving then
		want = improves and price < RebirthConfig.cost(n) * 0.03
	else
		want = improves
		if req and owned() < req.Hamsters and price < data.Coins * 0.15 then
			want = true
		end
		if req and RarityConfig.rank(species.Rarity) >= RarityConfig.rank(req.Rarity) and bestRank() < RarityConfig.rank(req.Rarity) then
			want = true
		end
	end
	if not want then
		return
	end
	data.Coins -= price
	if random:NextNumber() <= CATCH then
		table.insert(pending, { At = now + TRANSIT, SpeciesId = species.Id })
	end
end

local CHECKPOINTS = { 300, 900, 1800, 3600, 7200, 10800, 18000, 36000, 43200, 72000, 108000 }
local nextCheckpoint = 1
local nextSpawn = 2
local found = {}

local function bestOwnedName(): string
	local best, bestInc = "-", -1
	for id, c in data.Inventory do
		local s = HamsterDatabase.ById[id]
		if c > 0 and HamsterDatabase.income(s) > bestInc then
			best, bestInc = s.Rarity .. " " .. s.Name, HamsterDatabase.income(s)
		end
	end
	return best
end

local function fmt(n)
	if n >= 1e12 then
		return string.format("%.2fT", n / 1e12)
	elseif n >= 1e9 then
		return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif n >= 1e3 then
		return string.format("%.1fK", n / 1e3)
	end
	return string.format("%.0f", n)
end

print(string.format("profile=%s seed=%d  (1 player, spawn every %.2fs, catch %d%%)", PROFILE, SEED, SPAWN_INTERVAL, CATCH * 100))
print("time      rebirth floors slots  income/s     coins     best hamster                 bought (B/C/S/R/E/U/L/M/D/Co)")
local endTime = HOURS * 3600
while now < endTime do
	now += 1
	-- passive income
	data.Coins += income()
	-- arrivals
	for i = #pending, 1, -1 do
		local p = pending[i]
		if now >= p.At then
			table.remove(pending, i)
			data.Inventory[p.SpeciesId] = (data.Inventory[p.SpeciesId] or 0) + 1
			data.Index[p.SpeciesId] = true
			local r = rarityOf(p.SpeciesId)
			found[r] = (found[r] or 0) + 1
			equipBest()
		end
	end
	-- spawns
	if now >= nextSpawn then
		nextSpawn = now + SPAWN_INTERVAL * (0.75 + random:NextNumber() * 0.5)
		local weights = RarityConfig.adjustedWeights(data.Rebirths, EconomyMath.luck(data, 0))
		local ids, values, total = {}, {}, 0
		for _, id in RarityConfig.Order do
			if weights[id] and #HamsterDatabase.Spawnable[id] > 0 then
				table.insert(ids, id)
				table.insert(values, weights[id])
				total += weights[id]
			end
		end
		local roll = random:NextNumber() * total
		local rarity = ids[#ids]
		for i, w in values do
			roll -= w
			if roll <= 0 then
				rarity = ids[i]
				break
			end
		end
		local pool = HamsterDatabase.Spawnable[rarity]
		maybeClaim(pool[random:NextInteger(1, #pool)])
	end
	if now % 5 == 0 then
		tryBuyUpgrades()
		local _, ok = RebirthConfig.check(data, rarityOf)
		if ok then
			rebirth()
		end
	end
	if CHECKPOINTS[nextCheckpoint] and now >= CHECKPOINTS[nextCheckpoint] then
		nextCheckpoint += 1
		local counts = {}
		for _, id in { "Basic", "Cute", "Shiny", "Rare", "Epic", "Ultra", "Legendary", "Mythic", "Divine", "Cosmic" } do
			table.insert(counts, tostring(found[id] or 0))
		end
		local t = if now < 3600 then string.format("%dmin", now // 60) else string.format("%.1fh", now / 3600)
		print(string.format("%-9s R%-6d %-6d %2d/%-3d %-12s %-9s %-28s %s", t, data.Rebirths, EconomyMath.floors(data), #data.Equipped, EconomyMath.slots(data), fmt(income()), fmt(data.Coins), bestOwnedName(), table.concat(counts, "/")))
	end
end
local times = {}
for i, t in rebirthTimes do
	table.insert(times, string.format("R%d@%s", i, if t < 3600 then string.format("%dm", t // 60) else string.format("%.1fh", t / 3600)))
end
print("rebirths: " .. table.concat(times, " "))
