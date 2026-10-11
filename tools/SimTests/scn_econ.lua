local HamsterDatabase = require(find("ReplicatedStorage.Modules.HamsterDatabase"))
local RarityConfig = require(find("ReplicatedStorage.Modules.RarityConfig"))
local RebirthConfig = require(find("ReplicatedStorage.Modules.RebirthConfig"))
local FloorConfig = require(find("ReplicatedStorage.Modules.FloorConfig"))
local Format = require(find("ReplicatedStorage.Modules.Format"))
local fails = 0
local function check(name, cond, detail) if not cond then fails += 1 end print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or "")) end
local prevMaxPrice, prevMaxIncome = 0, 0
print("rarity      price(min..max)          income/s(min..max)    payback")
for _, id in RarityConfig.Order do
	local lo, hi, ilo, ihi = math.huge, 0, math.huge, 0
	for _, s in HamsterDatabase.Spawnable[id] do
		lo = math.min(lo, HamsterDatabase.price(s)) hi = math.max(hi, HamsterDatabase.price(s))
		ilo = math.min(ilo, HamsterDatabase.income(s)) ihi = math.max(ihi, HamsterDatabase.income(s))
	end
	print(string.format("%-10s %9s..%-9s  %9s..%-9s  %ds", id, Format.short(lo), Format.short(hi), Format.short(ilo), Format.short(ihi), RarityConfig.ById[id].Payback))
	check(id .. ": cheapest costs more than the dearest of the rarity below", lo > prevMaxPrice)
	check(id .. ": lowest income beats the best income of the rarity below", ilo > prevMaxIncome)
	prevMaxPrice, prevMaxIncome = hi, ihi
	for _, s in HamsterDatabase.ByRarity[id] do
		if s.Exclusive then check(s.Name .. " (exclusive) stays below the next rarity", HamsterDatabase.price(s) < (RarityConfig.ById[id].BasePrice * 4)) end
	end
end
local c0 = RarityConfig.chances(0, 1)
print("spawn chances at rebirth 0, no luck:")
for _, id in RarityConfig.Order do if c0[id] then print(string.format("   %-10s %.3f%%", id, c0[id] * 100)) end end
check("Basic..Rare are common (>= 5% each)", c0.Basic >= 0.4 and c0.Cute >= 0.2 and c0.Shiny >= 0.1 and c0.Rare >= 0.05)
check("Epic/Ultra occasional (0.5%-5%)", c0.Epic > 0.005 and c0.Epic < 0.05 and c0.Ultra > 0.005 and c0.Ultra < 0.05)
check("Legendary rare (<2%)", c0.Legendary < 0.02)
check("Mythic and above hidden before rebirth 2", c0.Mythic == nil)
print("rebirth table:")
for n = 1, RebirthConfig.MaxRebirths do
	local req = RebirthConfig.requirements(n)
	local rewards = RebirthConfig.rewards(n, 0)
	local texts = {}
	for _, r in rewards do table.insert(texts, r.Text) end
	if n <= 12 or n % 5 == 0 then print(string.format("  R%-2d  %9s  %2d hamsters  %-9s  floors=%d slots=%d keep=%d | %s", n, Format.short(req[1].Need), req[2].Need, req[3].Label, FloorConfig.count(n), 3 + n, RebirthConfig.keepsakes(n), table.concat(texts, "; "))) end
end
check("rebirth cost strictly increasing", RebirthConfig.cost(2) > RebirthConfig.cost(1) and RebirthConfig.cost(25) > RebirthConfig.cost(24))
check("floors unlock at 3/6/10/15", FloorConfig.count(2) == 1 and FloorConfig.count(3) == 2 and FloorConfig.count(6) == 3 and FloorConfig.count(10) == 4 and FloorConfig.count(15) == 5)
-- requirement check on a fake profile
check("first rebirth costs exactly 700,000", RebirthConfig.cost(1) == 700000)
local data = { Coins = 5e6, Inventory = { silver = 4 } }
local ok, list = RebirthConfig.check(data, 1)
check("rebirth 1 possible with 5M coins, 4 hamsters incl. Silver", ok)
data.Inventory = { [HamsterDatabase.Spawnable.Basic[1].Id] = 4 }
ok, list = RebirthConfig.check(data, 1)
check("...but not without Silver", not ok)
data.Inventory = { [HamsterDatabase.Spawnable.Shiny[1].Id] = 4 }
data.Inventory.silver = nil
ok, list = RebirthConfig.check(data, 1)
check("...another Shiny does not replace Silver", not ok)
data.Coins = 699999; data.Inventory = { silver = 4 }
ok, list = RebirthConfig.check(data, 1)
check("...and 699,999 coins is not enough", not ok)
data.Coins = 5e6
data.Inventory = { silver = 1 }
ok, list = RebirthConfig.check(data, 1)
check("...and not with too few hamsters", not ok)
print("fails:", fails)
