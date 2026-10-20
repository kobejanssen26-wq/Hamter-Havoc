-- Admin base management: permissions per role, lasers on/off/reset really change the gate, bench vs owned removal,
-- reason + confirmation required, audit log entries, forged calls by ordinary players do nothing.
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
	local AdminSystem = require(find(S .. "AdminSystem"))
	local DataSystem = require(find(S .. "DataSystem"))
	local HouseSystem = require(find(S .. "HouseSystem"))
	local SecuritySystem = require(find(S .. "SecuritySystem"))
	local CollectionSystem = require(find(S .. "CollectionSystem"))
	local AdminConfig = require(find("ServerScriptService.Config.AdminConfig"))
	local Remotes = require(find("ReplicatedStorage.Remotes"))

	local function join(name)
		local p = M.newPlayer(name)
		fireJoin(p)
		M.spawnCharacter(p)
		return p
	end
	local owner, admin, mod, dev, normal, victim = join("Owner"), join("Admin"), join("Mod"), join("Dev"), join("Normal"), join("Victim")
	adv(8)
	AdminConfig.OwnerUserIds = { owner.UserId }
	AdminConfig.Users = { [admin.UserId] = "Admin", [mod.UserId] = "Moderator", [dev.UserId] = "Developer" }
	local function data(p) return DataSystem.get(p) end
	local function api(p, ...)
		M.localPlayerRef = p
		local r = Remotes.func("Admin"):InvokeServer(...)
		adv(0.2)
		return r
	end
	local function run(p, name, params, confirmed) return api(p, "run", name, params, confirmed) end
	local function has(list, name) for _, c in list do if c.Name == name then return true end end return false end

	local HamsterDatabase = require(find("ReplicatedStorage.Modules.HamsterDatabase"))
	local other = "silver"
	for _, species in HamsterDatabase.Species do
		if species.Id ~= "silver" then other = species.Id break end
	end
	local d = data(victim)
	d.Inventory = { silver = 2, [other] = 1 }
	d.Equipped = { "silver", other }
	local house = HouseSystem.getHouse(victim)

	section("1. who may see / control what")
	local function cmds(p) local o = api(p, "open") return o and o.data.Commands or {} end
	check("Owner and Admin have all four base commands", has(cmds(owner), "baseInfo") and has(cmds(owner), "hamsterRemove") and has(cmds(admin), "baseSecurity") and has(cmds(admin), "benchRemove") and has(cmds(admin), "hamsterRemove"))
	check("a Moderator may only inspect (baseInfo yes, baseSecurity / benchRemove / hamsterRemove no)", has(cmds(mod), "baseInfo") and not has(cmds(mod), "baseSecurity") and not has(cmds(mod), "benchRemove") and not has(cmds(mod), "hamsterRemove"))
	check("a Developer may inspect and switch lasers, but never delete hamsters", has(cmds(dev), "baseInfo") and has(cmds(dev), "baseSecurity") and not has(cmds(dev), "hamsterRemove"))
	check("an ordinary player gets no answer at all", api(normal, "open") == nil and run(normal, "hamsterRemove", { target = victim.UserId, hamster = "silver", reason = "x" }, true) == nil and run(normal, "baseInfo", { target = victim.UserId }) == nil)
	check("a forged hamsterRemove by a Moderator is refused", not run(mod, "hamsterRemove", { target = victim.UserId, hamster = "silver", reason = "x" }, true).ok and data(victim).Inventory.silver == 2)

	section("2. inspect base")
	local info = run(admin, "baseInfo", { target = victim.UserId })
	check("baseInfo returns owner, gate, bench and owned lists", info.ok and info.data.UserId == victim.UserId and #info.data.Bench == 2 and #info.data.Owned == 2 and info.data.Gate ~= nil, info.msg)
	local silverRow
	for _, row in info.data.Owned do if row.Id == "silver" then silverRow = row end end
	check("owned rows say how many are placed", silverRow and silverRow.Owned == 2 and silverRow.Placed == 1)
	check("the gate state is the real one", info.data.Gate.State == SecuritySystem.status(house))

	section("3. lasers")
	SecuritySystem.adminSet(house, "reset")
	local needs = run(admin, "baseSecurity", { target = victim.UserId, mode = "on", reason = "test" }, false)
	check("switching lasers asks for confirmation first", needs and needs.needsConfirm == true and SecuritySystem.status(house) ~= "Active")
	check("a reason is required", not run(admin, "baseSecurity", { target = victim.UserId, mode = "on", reason = "" }, true).ok)
	check("a bad mode is refused", not run(admin, "baseSecurity", { target = victim.UserId, mode = "explode", reason = "x" }, true).ok)
	local on = run(admin, "baseSecurity", { target = victim.UserId, mode = "on", reason = "test" }, true)
	check("lasers ON really activates the gate", on.ok and SecuritySystem.status(house) == "Active" and house.Model:GetAttribute("SecState") == "Active", on.msg)
	local off = run(admin, "baseSecurity", { target = victim.UserId, mode = "off", reason = "test" }, true)
	check("lasers OFF stops them at once", off.ok and SecuritySystem.status(house) == "Ready")
	run(admin, "baseSecurity", { target = victim.UserId, mode = "on", reason = "test" }, true)
	local reset = run(admin, "baseSecurity", { target = victim.UserId, mode = "reset", reason = "test" }, true)
	check("reset clears the timers", reset.ok and SecuritySystem.status(house) == "Ready" and house.Model:GetAttribute("SecUntil") == 0 and house.Model:GetAttribute("SecReady") == 0)
	check("the owner can switch it on again after a reset", SecuritySystem.activate(house) and SecuritySystem.status(house) == "Active")
	check("a Moderator can not touch the lasers", not run(mod, "baseSecurity", { target = victim.UserId, mode = "off", reason = "x" }, true).ok and SecuritySystem.status(house) == "Active")

	section("4. bench vs owned")
	local before = data(victim).Inventory.silver
	local off1 = run(admin, "benchRemove", { target = victim.UserId, hamster = "silver", reason = "cleanup" }, true)
	check("taking a hamster off the bench keeps it owned", off1.ok and data(victim).Inventory.silver == before and not table.find(data(victim).Equipped, "silver") and table.find(data(victim).Equipped, other) ~= nil, off1.msg)
	check("taking off an unplaced hamster is refused", not run(admin, "benchRemove", { target = victim.UserId, hamster = "silver", reason = "again" }, true).ok)
	check("hamsterRemove needs confirmation and a reason", run(admin, "hamsterRemove", { target = victim.UserId, hamster = other, reason = "dupe" }, false).needsConfirm == true and not run(admin, "hamsterRemove", { target = victim.UserId, hamster = other, reason = "" }, true).ok and data(victim).Inventory[other] == 1)
	local del = run(admin, "hamsterRemove", { target = victim.UserId, hamster = other, reason = "dupe" }, true)
	check("deleting an owned+placed hamster removes it from the bench as well", del.ok and data(victim).Inventory[other] == nil and not table.find(data(victim).Equipped, other), del.msg)
	check("deleting more than they own is refused", not run(admin, "hamsterRemove", { target = victim.UserId, hamster = "silver", amount = 9, reason = "x" }, true).ok and data(victim).Inventory.silver == 2)
	data(victim).Equipped = { "silver", "silver" }
	local del2 = run(admin, "hamsterRemove", { target = victim.UserId, hamster = "silver", amount = 1, reason = "one" }, true)
	check("with 2 placed and 1 deleted, only one stays placed (never more placed than owned)", del2.ok and data(victim).Inventory.silver == 1 and #data(victim).Equipped == 1)

	section("5. protection + audit")
	check("an Admin can not act on the Owner", not run(admin, "hamsterRemove", { target = owner.UserId, hamster = "silver", reason = "x" }, true).ok and not run(admin, "benchRemove", { target = owner.UserId, hamster = "silver", reason = "x" }, true).ok)
	local log = AdminSystem.auditLog()
	local seen = {}
	for _, entry in log do seen[entry.Action] = (seen[entry.Action] or 0) + 1 end
	check("every successful action is in the audit log (lasers, bench, delete)", (seen.baseSecurity or 0) >= 4 and (seen.benchRemove or 0) >= 1 and (seen.hamsterRemove or 0) >= 2, seen.baseSecurity)
	local last = log[#log]
	check("an entry names who, what, on whom and why", last.AdminId == admin.UserId and last.TargetId == victim.UserId and last.Reason ~= "" and last.Detail ~= "")

	print(string.format("PASS %d  FAIL %d", results.pass, results.fail))
	print("== done ==")
end)
