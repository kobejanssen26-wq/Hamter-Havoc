-- Rebirth keeps the collection AND the working bench; save/load/rejoin keeps it too
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
	local HouseSystem = require(find(S .. "HouseSystem"))
	local CollectionSystem = require(find(S .. "CollectionSystem"))
	local EconomySystem = require(find(S .. "EconomySystem"))
	local HamsterSystem = require(find(S .. "HamsterSystem"))
	local HamsterDatabase = require(find(MOD .. "HamsterDatabase"))
	local RebirthConfig = require(find(MOD .. "RebirthConfig"))
	local EconomyMath = require(find(MOD .. "EconomyMath"))
	local UpgradeConfig = require(find(MOD .. "UpgradeConfig"))
	local Remotes = require(find("ReplicatedStorage.Remotes"))
	HamsterSystem.AutoSpawn = false

	local function join(name, userId)
		local p = M.newPlayer(name)
		if userId then RawData[p].Props.UserId = userId end
		fireJoin(p)
		M.spawnCharacter(p)
		return p
	end
	local function as(p, action, payload)
		M.localPlayerRef = p
		return Remotes.func("Request"):InvokeServer(action, payload or {})
	end
	local function same(a, b)
		if #a ~= #b then return false end
		for i = 1, #a do if a[i] ~= b[i] then return false end end
		return true
	end
	local function benchOf(p)
		local house = HouseSystem.getHouse(p)
		local list = {}
		for index, entry in house.DisplayModels do list[index] = entry.SpeciesId end
		return list
	end
	local function invTotal(inv) local n = 0 for _, v in inv do n += v end return n end
	local function copyInv(inv) return table.clone(inv) end
	local function invEqual(a, b)
		for k, v in a do if b[k] ~= v then return false end end
		for k, v in b do if a[k] ~= v then return false end end
		return true
	end

	local alice = join("Alice")
	adv(6)
	local a = DataSystem.get(alice)
	local uid = RawData[alice].Props.UserId

	-- the collection: two cheap ones, the Silver the first rebirth demands, a Rare and the best one (an Epic)
	local rare = HamsterDatabase.Spawnable.Rare[1].Id
	local epic = HamsterDatabase.Spawnable.Epic[1].Id
	a.Inventory = { brownie = 2, silver = 1, [rare] = 1, [epic] = 1 }
	-- the player's OWN setup: deliberately NOT the best hamsters, in a specific order
	a.Equipped = { "brownie", "silver", "brownie" }
	require(find(S .. "Events")).EquippedChanged:Fire(alice)
	adv(1)

	local resetId, keepId
	for id, def in UpgradeConfig.Definitions do
		if def.ResetOnRebirth and not resetId then resetId = id end
		if not def.ResetOnRebirth and not keepId then keepId = id end
	end
	a.Upgrades[resetId] = 3
	a.Upgrades[keepId] = 2
	a.Gems, a.Tokens = 5, 5

	section("1. before the rebirth")
	local benchBefore = benchOf(alice)
	check("bench shows the 3 placed hamsters in order", same(benchBefore, { "brownie", "silver", "brownie" }), table.concat(benchBefore, ","))
	check("capacity is 3", EconomyMath.slots(a) == 3, EconomyMath.slots(a))

	section("2. refused rebirth changes nothing")
	a.Coins = 5; EconomySystem.updateAttributes(alice)
	local invSnap, equipSnap = copyInv(a.Inventory), table.clone(a.Equipped)
	local r = as(alice, "Rebirth")
	check("not enough cash -> refused", not r.ok and a.Rebirths == 0, r.msg)
	check("...and the collection and bench are untouched", invEqual(a.Inventory, invSnap) and same(a.Equipped, equipSnap))

	section("3. rebirth #1")
	a.Coins = RebirthConfig.cost(1) + 10; EconomySystem.updateAttributes(alice)
	r = as(alice, "Rebirth")
	adv(1)
	check("rebirth succeeds", r.ok and a.Rebirths == 1, r.msg)
	check("owned hamsters are exactly the same (no loss, no duplicates)", invEqual(a.Inventory, invSnap) and invTotal(a.Inventory) == 5, invTotal(a.Inventory))
	check("placed hamsters keep their places (same species, same order)", same(a.Equipped, equipSnap), table.concat(a.Equipped, ","))
	check("the bench in the world still shows them in the same slots", same(benchOf(alice), benchBefore), table.concat(benchOf(alice), ","))
	check("the best hamster did NOT replace a manually placed one", table.find(a.Equipped, epic) == nil and table.find(a.Equipped, rare) == nil)
	check("capacity grew by exactly one (never shrinks)", EconomyMath.slots(a) == 4, EconomyMath.slots(a))
	check("the new slot is free for the player to fill", #a.Equipped == 3)
	check("cash and the designated upgrade reset", a.Coins <= RebirthConfig.startingCoins(1) + 50 and a.Upgrades[resetId] == nil, a.Coins)
	check("permanent upgrades stay", a.Upgrades[keepId] == 2)
	check("index/rewards persist (diamonds only go up)", a.Gems >= 5)
	local used = {}
	local dupe = false
	for _, entry in HouseSystem.getHouse(alice).DisplayModels do
		if used[entry.Model] then dupe = true end
		used[entry.Model] = true
	end
	check("no duplicated models on the bench", not dupe)

	section("4. the player fills the new slot, then saves and rejoins")
	check("equip the Epic into the new slot", as(alice, "Equip", { Id = epic }).ok and a.Equipped[4] == epic)
	adv(1)
	local benchMid = benchOf(alice)
	check("4 hamsters working", #benchMid == 4)
	DataSystem.save(alice, false)
	M.removePlayer(alice)
	adv(3)
	alice = join("Alice", uid)
	adv(6)
	a = DataSystem.get(alice)
	check("after rejoining: rebirth count, collection and bench are identical", a.Rebirths == 1 and invEqual(a.Inventory, invSnap) and same(a.Equipped, { "brownie", "silver", "brownie", epic }), table.concat(a.Equipped, ","))
	adv(2)
	check("...and the bench in the world is rebuilt identically", same(benchOf(alice), benchMid), table.concat(benchOf(alice), ","))
	check("upgrades persisted as well", a.Upgrades[keepId] == 2 and a.Upgrades[resetId] == nil)

	section("5. rebirth #2 with a full bench")
	for _, id in { rare, HamsterDatabase.Spawnable.Rare[2].Id, HamsterDatabase.Spawnable.Rare[3].Id } do
		CollectionSystem.grant(alice, id, "Reward")
	end
	check("collecting stronger hamsters with a FULL bench changes nothing on the bench", same(a.Equipped, { "brownie", "silver", "brownie", epic }), table.concat(a.Equipped, ","))
	a.Coins = RebirthConfig.cost(2) + 10; EconomySystem.updateAttributes(alice)
	local invBefore2, equipBefore2 = copyInv(a.Inventory), table.clone(a.Equipped)
	r = as(alice, "Rebirth")
	adv(1)
	check("second rebirth works", r.ok and a.Rebirths == 2, r.msg)
	check("collection unchanged by the second rebirth", invEqual(a.Inventory, invBefore2))
	check("bench order unchanged by the second rebirth", same(a.Equipped, equipBefore2), table.concat(a.Equipped, ","))
	check("world bench still matches", #benchOf(alice) == 4 and same(benchOf(alice), equipBefore2))

	section("5b. auto-place only uses free slots")
	local free = EconomyMath.slots(a) - #a.Equipped
	check("a free slot exists after rebirth #2", free >= 1, free)
	local before = table.clone(a.Equipped)
	CollectionSystem.grant(alice, HamsterDatabase.Spawnable.Cute[1].Id, "Collect")
	check("a new hamster goes onto the free slot, appended", #a.Equipped == #before + 1 and a.Equipped[#a.Equipped] == HamsterDatabase.Spawnable.Cute[1].Id)
	local prefixSame = true
	for i = 1, #before do if a.Equipped[i] ~= before[i] then prefixSame = false end end
	check("...and the hamsters already placed did not move", prefixSame)
	check("Rest (unequip) is respected until the player decides otherwise", as(alice, "Unequip", { Id = "brownie" }).ok and #a.Equipped == #before)

	section("6. UI text is honest")
	local reset, keep = table.concat(RebirthConfig.ResetList, "|"), table.concat(RebirthConfig.KeepList, "|")
	check("rebirth screen says hamsters are kept", string.find(keep, "ALL your hamsters", 1, true) ~= nil and string.find(reset, "hamster", 1, true) == nil, reset)
	check("it lists what resets (cash + coin upgrades)", string.find(reset, "Coins", 1, true) ~= nil and string.find(reset, "upgrades", 1, true) ~= nil)

	section("7. hamster catalog: new fields and balance")
	local Validator = require(find(MOD .. "ContentValidator"))
	local RarityConfig = require(find(MOD .. "RarityConfig"))
	local newIds = { "lurker_larry", "doomscroll_dot", "cozy_stream_cleo", "meme_muffin", "hype_train_hazel", "speedrun_sammy", "clip_farmer_finn", "anniversary_confetti", "main_character_mia", "algorithm_alvin", "viral_vera", "million_sub_milo", "prime_time_pixel", "npc_zero" }
	local allThere, allDescribed = true, true
	for _, id in newIds do
		local sp = HamsterDatabase.ById[id]
		if not sp then allThere = false else allDescribed = allDescribed and type(sp.Description) == "string" and #sp.Description > 10 end
	end
	check("all 14 new internet-culture hamsters are registered", allThere)
	check("each has a collection description", allDescribed)
	local issues = 0
	for _, i in HamsterDatabase.Issues do if i.Level == "error" then issues += 1 end end
	check("no content errors in the catalog", issues == 0, issues)
	local seenNames, dupName = {}, false
	for _, sp in HamsterDatabase.Species do
		if seenNames[sp.Name] then dupName = true end
		seenNames[sp.Name] = true
	end
	check("no two hamsters share a display name", not dupName)
	-- balance: custom hamsters follow the same rarity formula as the built-in ones
	local ok = true
	for _, id in newIds do
		local sp = HamsterDatabase.ById[id]
		local def = RarityConfig.ById[sp.Rarity]
		local price, income = HamsterDatabase.price(sp), HamsterDatabase.income(sp)
		if price < def.BasePrice or price > def.BasePrice * 1.8 or math.abs(income - price / def.Payback) > 1e-6 then ok = false end
	end
	check("prices/income follow the rarity formula (no outliers)", ok)
	local best = {}
	for _, sp in HamsterDatabase.Species do
		best[sp.Rarity] = math.max(best[sp.Rarity] or 0, HamsterDatabase.income(sp))
	end
	local monotone = true
	local prev = 0
	for _, id in RarityConfig.Order do
		local lowest = math.huge
		for _, sp in HamsterDatabase.ByRarity[id] do if not sp.Exclusive then lowest = math.min(lowest, HamsterDatabase.income(sp)) end end
		if lowest ~= math.huge then
			if lowest <= prev then monotone = false end
			prev = best[id]
		end
	end
	check("every rarity's weakest hamster still out-earns the best one below it", monotone)
	local confetti = HamsterDatabase.ById.anniversary_confetti
	check("limited edition: rolls before its end date", HamsterDatabase.rollable(confetti, 0, confetti.Limited.EndsAt - 100))
	check("limited edition: stops rolling after its end date", not HamsterDatabase.rollable(confetti, 0, confetti.Limited.EndsAt + 1))
	check("rarity-locked hamsters respect Unlock.MinRebirth", not HamsterDatabase.rollable({ Unlock = { MinRebirth = 3 } }, 2, 0) and HamsterDatabase.rollable({ Unlock = { MinRebirth = 3 } }, 3, 0))
	local function errs(def) local n = 0 for _, i in Validator.validateHamster(def, { Rarities = RarityConfig.ById, ExistingIds = {} }) do if i.Level == "error" then n += 1 end end return n end
	check("validator: bad Limited / too long Description are rejected", errs({ Id = "x1", DisplayName = "X", Rarity = "Basic", Limited = { EndsAt = "soon" } }) > 0 and errs({ Id = "x2", DisplayName = "X", Rarity = "Basic", Description = string.rep("a", 200) }) > 0 and errs({ Id = "x3", DisplayName = "X", Rarity = "Basic", Description = "ok", Limited = { EndsAt = 5 } }) == 0)
	-- an owned limited hamster stays after it stopped rolling
	CollectionSystem.grant(alice, "anniversary_confetti", "Reward")
	check("owning a limited hamster is permanent", a.Inventory.anniversary_confetti == 1)

	print(string.format("PASS %d  FAIL %d", results.pass, results.fail))
	print("== done ==")
end)
