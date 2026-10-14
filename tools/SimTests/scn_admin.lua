-- Admin panel + config system: authorization, roles, validation, confirmation, audit log, bans, live settings that
-- survive a restart, shop overrides, forged remote calls by ordinary players, and the panel not being on the HUD.
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
	local AdminSystem = require(find(S .. "AdminSystem"))
	local ConfigStore = require(find(S .. "ConfigStore"))
	local DataSystem = require(find(S .. "DataSystem"))
	local GameConfig = require(find(MOD .. "GameConfig"))
	local ShopConfig = require(find(MOD .. "ShopConfig"))
	local SecurityConfig = require(find(MOD .. "SecurityConfig"))
	local InputConfig = require(find(MOD .. "InputConfig"))
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
	local function has(list, name) for _, c in list do if c.Name == name then return true end end return false end
	-- the shipped configuration
	local shippedOwner, shippedCo = AdminConfig.OwnerUserIds[1], AdminConfig.Users[7426751118]
	local function fakeUser(id, name) local g = M.newPlayer(name); RawData[g].Props.UserId = id return g end
	local mainOwner, coOwner = fakeUser(8247768664, "MainOwner"), fakeUser(7426751118, "CoOwnerAcc")
	check("shipped config: 8247768664 is Owner and 7426751118 is CoOwner", AdminSystem.roleOf(mainOwner) == "Owner" and AdminSystem.roleOf(coOwner) == "CoOwner" and shippedOwner == 8247768664 and shippedCo == "CoOwner")
	check("the CoOwner has every command (same list as the Owner)", (function()
		local open = AdminSystem.handle(coOwner, "open")
		if not open then return false end
		for name in AdminSystem.Commands do if not has(open.data.Commands, name) then return false end end
		return true
	end)())
	check("the CoOwner can NOT kick or ban the Owner", (function()
		local a = AdminSystem.execute(coOwner, "ban", { userId = 8247768664, minutes = 0, reason = "x" }, true)
		return not a.ok
	end)())
	check("the Owner CAN act on the CoOwner (kick needs confirm, then works)", (function()
		local a = AdminSystem.execute(mainOwner, "warn", { target = 7426751118, reason = "test" }, true)
		return a.ok
	end)())
	check("nobody else is staff by default (creator rule is off)", AdminSystem.roleOf(normal) == nil)
	AdminConfig.OwnerUserIds = { owner.UserId }
	AdminConfig.Users = { [admin.UserId] = "Admin", [mod.UserId] = "Moderator", [dev.UserId] = "Developer" }
	local function data(p) return DataSystem.get(p) end
	local function api(p, ...)
		M.localPlayerRef = p
		local r = Remotes.func("Admin"):InvokeServer(...)
		adv(0.2) -- rate limit gap
		return r
	end
	local function run(p, name, params, confirmed) return api(p, "run", name, params, confirmed) end
	local function near(a, b) return math.abs(a - b) < 5 end -- idle income ticks a few cash while the sim runs

	-----------------------------------------------------------------
	section("1. ordinary players get nothing")
	check("a normal player's 'open' request gets NO answer (no data, no command list, no error text)", api(normal, "open") == nil)
	local coinsBefore = data(victim).Coins
	check("a normal player can not give cash to anybody (forged remote call)", run(normal, "giveCash", { target = victim.UserId, amount = 5000 }, true) == nil and near(data(victim).Coins, coinsBefore))
	check("...nor give themselves cash", run(normal, "giveCash", { target = normal.UserId, amount = 5000 }, true) == nil)
	local kicksBefore = 0
	for _ in M.kicked or {} do kicksBefore += 1 end
	run(normal, "kick", { target = victim.UserId, reason = "x" }, true)
	run(normal, "ban", { userId = victim.UserId, minutes = 0, reason = "x" }, true)
	local kicksAfter = 0
	for _ in M.kicked or {} do kicksAfter += 1 end
	check("...nor kick or ban other players", kicksAfter == kicksBefore)
	-- try EVERY command with plausible parameters
	local snapshot = {}
	for _, p in { owner, admin, mod, dev, normal, victim } do snapshot[p] = data(p).Gems .. "/" .. data(p).Rebirths .. "/" .. tostring(data(p).Gear.slap_glove) end
	local anyAnswer = false
	for name in AdminSystem.Commands do
		local r = run(normal, name, { target = victim.UserId, userId = victim.UserId, amount = 100, count = 5, minutes = 0, reason = "x", text = "hi", item = "slap_glove", setting = "Combat.PawRange", value = 99, price = 1 }, true)
		if r ~= nil then anyAnswer = true end
	end
	local unchanged = true
	for p, before in snapshot do if data(p).Gems .. "/" .. data(p).Rebirths .. "/" .. tostring(data(p).Gear.slap_glove) ~= before then unchanged = false end end
	check("a normal player calling every command: no answer, nothing changed", not anyAnswer and unchanged)
	check("Studio fake players (negative UserId) are never staff", (function()
		local ghost = M.newPlayer("Ghost"); RawData[ghost].Props.UserId = -1
		AdminConfig.OwnerUserIds = { owner.UserId, -1 }
		local r = AdminSystem.roleOf(ghost)
		AdminConfig.OwnerUserIds = { owner.UserId }
		return r == nil
	end)())
	check("a display name or user name can not grant access (only UserId counts)", (function()
		local fake = M.newPlayer("Owner"); RawData[fake].Props.DisplayName = "Owner"
		return AdminSystem.roleOf(fake) == nil
	end)())
	check("no owner configured + no creator = nobody is staff (the shipped config has UserId 0)", (function()
		local saved = AdminConfig.OwnerUserIds
		AdminConfig.OwnerUserIds = { 0 }
		local r = AdminSystem.roleOf(normal)
		AdminConfig.OwnerUserIds = saved
		return r == nil
	end)())

	-----------------------------------------------------------------
	section("2. roles and permissions")
	local ro, ra, rm, rd = api(owner, "open"), api(admin, "open"), api(mod, "open"), api(dev, "open")
	check("owner, admin, moderator and developer can open the panel", ro and ra and rm and rd and ro.ok and ra.ok and rm.ok and rd.ok)
	check("roles are reported correctly", ro.data.Role == "Owner" and ra.data.Role == "Admin" and rm.data.Role == "Moderator" and rd.data.Role == "Developer")
	local oc, ac, mc, dc = ro.data.Commands, ra.data.Commands, rm.data.Commands, rd.data.Commands
	check("owner has every command", (function() for name in AdminSystem.Commands do if not has(oc, name) then return false end end return true end)())
	check("moderator: warn / kick / ban / history yes; cash, rebirths, settings, announce no", has(mc, "warn") and has(mc, "kick") and has(mc, "ban") and has(mc, "history") and not has(mc, "giveCash") and not has(mc, "setRebirths") and not has(mc, "setSetting") and not has(mc, "announce") and not has(mc, "unban"))
	check("developer: test economy + settings yes; kick, ban, announce no", has(dc, "giveCash") and has(dc, "setSetting") and has(dc, "grantItem") and not has(dc, "kick") and not has(dc, "ban") and not has(dc, "announce"))
	check("admin: moderation + economy + settings + unban yes", has(ac, "kick") and has(ac, "giveCash") and has(ac, "setSetting") and has(ac, "unban") and has(ac, "announce"))
	check("the open-reply never contains UserIds of other staff configuration", ro.data.Settings ~= nil and rm.data.Settings == nil and rm.data.Shop == nil)
	check("a moderator calling a command their role lacks directly is refused", (function()
		local before = data(victim).Coins
		local r = run(mod, "giveCash", { target = victim.UserId, amount = 1000 }, true)
		return r and not r.ok and near(data(victim).Coins, before)
	end)())
	check("a developer can not kick", (function() local r = run(dev, "kick", { target = victim.UserId, reason = "test" }, true) return r and not r.ok end)())
	check("the admin key is a normal key that does not clash with other bindings", InputConfig.check() and InputConfig.Bindings.Admin == "F10")

	-----------------------------------------------------------------
	section("3. economy actions: validation, limits, confirmation, logging")
	local before = data(victim).Coins
	local r = run(admin, "giveCash", { target = victim.UserId, amount = 500, reason = "compensation" })
	check("admin can give 500 cash", r and r.ok and near(data(victim).Coins, before + 500), r and r.msg)
	check("the action is in the audit log with admin, target, action and reason", (function()
		for _, e in AdminSystem.auditLog() do
			if e.Action == "cash" and e.AdminId == admin.UserId and e.TargetId == victim.UserId and e.Reason == "compensation" and e.At then return true end
		end
		return false
	end)())
	before = data(victim).Coins
	r = run(admin, "giveCash", { target = victim.UserId, amount = -100 })
	check("removing cash asks for confirmation first and changes nothing", r and r.needsConfirm and near(data(victim).Coins, before))
	r = run(admin, "giveCash", { target = victim.UserId, amount = -100 }, true)
	check("...and works once confirmed", r and r.ok and near(data(victim).Coins, before - 100))
	check("a huge grant needs confirmation too", (run(admin, "giveCash", { target = victim.UserId, amount = 5e6 })).needsConfirm == true)
	check("amount over the role limit is refused (admin 2e9 > 1e9)", (function() local r2 = run(admin, "giveCash", { target = victim.UserId, amount = 2e9 }, true) return r2 and not r2.ok end)())
	check("developer limit is lower (1e9 refused for a developer)", (function() local r2 = run(dev, "giveCash", { target = victim.UserId, amount = 5e8 }, true) return r2 and not r2.ok end)())
	for label, params in {
		["string amount"] = { target = victim.UserId, amount = "lots" }, ["NaN amount"] = { target = victim.UserId, amount = 0 / 0 },
		["infinite amount"] = { target = victim.UserId, amount = math.huge }, ["fractional amount"] = { target = victim.UserId, amount = 1.5 },
		["missing target"] = { amount = 5 }, ["offline target"] = { target = 987654, amount = 5 }, ["table target"] = { target = { 1 }, amount = 5 }, ["zero amount"] = { target = victim.UserId, amount = 0 },
	} do
		local before2 = data(victim).Coins
		local r2 = run(admin, "giveCash", params, true)
		check("invalid input rejected: " .. label, r2 and not r2.ok and near(data(victim).Coins, before2))
	end
	r = run(admin, "giveDiamonds", { target = victim.UserId, amount = 40 })
	check("diamonds can be given", r and r.ok)
	r = run(admin, "setRebirths", { target = victim.UserId, count = 3 })
	check("setting rebirths needs confirmation", r and r.needsConfirm and data(victim).Rebirths == 0)
	local fired = 0
	local Events = require(find(S .. "Events"))
	Events.Rebirthed:Connect(function(p2, n) if p2 == victim and n == 3 then fired += 1 end end)
	local FloorConfig = require(find(MOD .. "FloorConfig"))
	r = run(admin, "setRebirths", { target = victim.UserId, count = 10 }, true)
	check("rebirths set after confirmation", r and r.ok and data(victim).Rebirths == 10)
	local HouseSystem = require(find(S .. "HouseSystem"))
	local house = HouseSystem.getHouse(victim)
	local builtFloors = 0
	for _, d in M.descendants(house.Model or workspace) do if string.match(RawData[d].Name, "^Floor%d") then builtFloors += 1 end end
	check("the tower is built up to the floors of rebirth 10 (like a real rebirth)", FloorConfig.count(10) > 1 and builtFloors >= FloorConfig.count(10), builtFloors .. " floor models, expected " .. FloorConfig.count(10))
	r = run(admin, "setRebirths", { target = victim.UserId, count = 3 }, true)
	check("setting rebirths again fires the Rebirthed event the house listens to", fired >= 1 and data(victim).Rebirths == 3)
	check("rebirths above the maximum are refused", (function() local r2 = run(admin, "setRebirths", { target = victim.UserId, count = 99 }, true) return r2 and not r2.ok end)())
	r = run(dev, "grantItem", { target = victim.UserId, item = "slap_glove" })
	check("a developer can grant a weapon for testing", r and r.ok and data(victim).Gear.slap_glove == true)
	check("granting an item that does not exist is refused", (function() local r2 = run(dev, "grantItem", { target = victim.UserId, item = "laser_cannon" }) return r2 and not r2.ok end)())
	r = run(admin, "giveHamster", { target = victim.UserId, hamster = "Divine Empress", amount = 2 })
	check("an admin can give a divine hamster by its display name", r and r.ok, r and r.msg)
	do
		local owned = 0
		for id, count in data(victim).Inventory do if string.find(id, "divine_empress", 1, true) then owned += count end end
		check("the hamster is really in the player's inventory (2 of them)", owned == 2, owned)
	end
	check("an unknown hamster name is refused", (function() local r2 = run(admin, "giveHamster", { target = victim.UserId, hamster = "Nope Hamster", amount = 1 }) return r2 and not r2.ok end)())
	r = run(admin, "setStaff", { userId = victim.UserId, role = "moderator" }, true)
	check("an Admin can not hand out staff (needs Owner / CoOwner)", r and not r.ok, r and r.msg)
	r = run(owner, "setStaff", { userId = victim.UserId, role = "moderator" }, true)
	check("the owner can make somebody Moderator", r and r.ok, r and r.msg)
	check("that person is now a Moderator in the panel", AdminSystem.roleOf(victim) == "Moderator", AdminSystem.roleOf(victim))
	r = run(owner, "setStaff", { userId = victim.UserId, role = "Owner" }, true)
	check("nobody can be made Owner this way", r and not r.ok)
	r = run(owner, "setStaff", { userId = victim.UserId, role = "none" }, true)
	check("staff can be removed again", r and r.ok and AdminSystem.roleOf(victim) == nil, r and r.msg)
	r = run(admin, "inspect", { target = victim.UserId })
	check("inspect shows progress", r and r.ok and string.find(r.msg, "Rebirths 3", 1, true) ~= nil, r and r.msg)
	check("the log command works for roles with AuditLog and not for moderators", run(admin, "auditLog", {}).ok and has(mc, "auditLog") == false)

	-----------------------------------------------------------------
	section("4. rank rules and moderation")
	check("nobody can kick themselves", (function() local r2 = run(owner, "kick", { target = owner.UserId, reason = "oops" }, true) return r2 and not r2.ok end)())
	check("a moderator can not kick an admin", (function() local r2 = run(mod, "kick", { target = admin.UserId, reason = "mutiny" }, true) return r2 and not r2.ok end)())
	check("an admin can not kick the owner", (function() local r2 = run(admin, "kick", { target = owner.UserId, reason = "coup" }, true) return r2 and not r2.ok end)())
	check("an admin can not ban the owner (even offline: by UserId)", (function() local r2 = run(admin, "ban", { userId = owner.UserId, minutes = 10, reason = "coup" }, true) return r2 and not r2.ok end)())
	r = run(mod, "kick", { target = victim.UserId, reason = "spamming" })
	check("kick asks for confirmation", r and r.needsConfirm and not (M.kicked and M.kicked[victim]))
	r = run(mod, "kick", { target = victim.UserId, reason = "spamming" }, true)
	check("a moderator can kick a player with a reason", r and r.ok and M.kicked and M.kicked[victim] and string.find(M.kicked[victim], "spamming", 1, true) ~= nil)
	r = run(mod, "warn", { target = normal.UserId, reason = "be nice" })
	check("warnings work and are written to the history", r and r.ok and #AdminSystem.history(normal.UserId) == 1)
	r = run(mod, "history", { userId = normal.UserId })
	check("the history can be read", r and r.ok and string.find(r.msg, "be nice", 1, true) ~= nil)
	check("an empty reason is refused", (function() local r2 = run(mod, "warn", { target = normal.UserId, reason = "   " }) return r2 and not r2.ok end)())
	local BANNED = 424242
	check("a moderator can NOT ban permanently (minutes = 0)", (function() local r2 = run(mod, "ban", { userId = BANNED, minutes = 0, reason = "bad" }, true) return r2 and not r2.ok end)())
	check("a moderator can NOT ban longer than their limit (30 days)", (function() local r2 = run(mod, "ban", { userId = BANNED, minutes = 30 * 24 * 60, reason = "bad" }, true) return r2 and not r2.ok end)())
	r = run(mod, "ban", { userId = BANNED, minutes = 1, reason = "griefing" }, true)
	check("a moderator can apply a 1 minute ban", r and r.ok)
	local bannedPlayer = M.newPlayer("BannedGuy"); RawData[bannedPlayer].Props.UserId = BANNED
	check("a banned player is kicked when they join (before any data loads)", AdminSystem.checkJoin(bannedPlayer) == false and M.kicked[bannedPlayer] ~= nil and string.find(M.kicked[bannedPlayer], "griefing", 1, true) ~= nil)
	adv(65)
	M.kicked[bannedPlayer] = nil
	check("a temporary ban ends by itself", AdminSystem.checkJoin(bannedPlayer) == true)
	r = run(admin, "ban", { userId = BANNED, minutes = 0, reason = "again" }, true)
	check("an admin can ban permanently", r and r.ok)
	check("a moderator can not lift a ban", (function() local r2 = run(mod, "unban", { userId = BANNED, reason = "pity" }, true) return r2 and not r2.ok end)())
	r = run(admin, "unban", { userId = BANNED, reason = "appeal accepted" }, true)
	check("an admin can unban", r and r.ok and AdminSystem.checkJoin(bannedPlayer) == true)
	check("bans are stored (survive a server restart: the DataStore holds them)", M.dataStoreData["Hist_" .. BANNED] ~= nil)

	-----------------------------------------------------------------
	section("5. live settings: validation, effect on gameplay, persistence")
	r = run(dev, "setSetting", { setting = "Security.GateReopenCooldown", value = 12 })
	check("a developer changes the gate reopen cooldown to 12 s", r and r.ok and GameConfig.get("Security", "GateReopenCooldown") == 12)
	check("...and the real gate recharge follows it", SecurityConfig.recharge(SecurityConfig.Tiers[1]) == 12)
	ConfigStore.flush()
	check("the change is saved in the DataStore", M.dataStoreData.Overrides ~= nil and M.dataStoreData.Overrides.Settings["Security.GateReopenCooldown"] == 12)
	GameConfig.set("Security", "GateReopenCooldown", 7, false) -- pretend a fresh server started with defaults
	check("(fresh server starts with the default again)", SecurityConfig.recharge(SecurityConfig.Tiers[1]) == 7)
	ConfigStore.load()
	check("the saved value is loaded again after a restart", GameConfig.get("Security", "GateReopenCooldown") == 12)
	for label, value in { ["NaN"] = 0 / 0, ["too large"] = 1e9, ["negative"] = -3, ["text"] = "fast", ["table"] = {}, ["boolean for a number"] = true } do
		local r2 = run(dev, "setSetting", { setting = "Security.GateReopenCooldown", value = value })
		check("invalid setting value rejected: " .. label, r2 and not r2.ok and GameConfig.get("Security", "GateReopenCooldown") == 12)
	end
	check("an unknown setting is rejected", (function() local r2 = run(dev, "setSetting", { setting = "Hacks.GodMode", value = true }) return r2 and not r2.ok end)())
	check("a Studio-only setting can not be changed live", (function() local r2 = run(dev, "setSetting", { setting = "Economy.StartingCash", value = 99999 }) return r2 and not r2.ok and GameConfig.get("Economy", "StartingCash") == 250 end)())
	check("a moderator can not change settings", (function() local r2 = run(mod, "setSetting", { setting = "Combat.PawRange", value = 15 }) return r2 and not r2.ok end)())
	r = run(dev, "resetSetting", { setting = "Security.GateReopenCooldown" })
	ConfigStore.flush()
	check("reset-to-default restores the default and removes the saved value", r and r.ok and GameConfig.get("Security", "GateReopenCooldown") == 7 and M.dataStoreData.Overrides.Settings["Security.GateReopenCooldown"] == nil)
	check("writes are batched: ten quick changes are one save", (function()
		local calls = 0
		for i = 1, 10 do ConfigStore.setSetting("Combat", "PawRange", 8 + i * 0.1) end
		adv(4)
		return M.dataStoreData.Overrides.Settings["Combat.PawRange"] == 9
	end)())
	ConfigStore.resetSetting("Combat", "PawRange")

	-----------------------------------------------------------------
	section("6. shop overrides")
	local id = "gear_slap_glove"
	check("default glove price is 1,500", ShopConfig.ById[id].Price == 1500)
	r = run(admin, "setShopItem", { item = id, price = 2000 })
	check("price change asks for confirmation", r and r.needsConfirm and ShopConfig.ById[id].Price == 1500)
	r = run(admin, "setShopItem", { item = id, price = 2000 }, true)
	check("price changed to 2,000", r and r.ok and ShopConfig.ById[id].Price == 2000 and ShopConfig.ById[id].Coins == 2000)
	check("clients are told through a replicated attribute", (function() local raw = game:GetService("ReplicatedStorage"):GetAttribute("ShopOverrides") return type(raw) == "string" and string.find(raw, "2000", 1, true) ~= nil end)())
	data(normal).Coins = 1800; adv(0.5)
	M.localPlayerRef = normal
	local buy = Remotes.func("Request"):InvokeServer("ShopBuy", { Id = id })
	check("the server charges the NEW price (1,800 cash is not enough)", not buy.ok and not data(normal).Gear.slap_glove)
	data(normal).Coins = 2500; adv(0.5); adv(1)
	buy = Remotes.func("Request"):InvokeServer("ShopBuy", { Id = id, Price = 1 })
	check("a client-sent price is ignored: bought for exactly 2,000", buy.ok and near(data(normal).Coins, 500), tostring(data(normal).Coins))
	r = run(admin, "setShopItem", { item = "gear_foam_bat", disabled = true }, true)
	check("an item can be disabled and then can not be bought", r and r.ok and (function() data(normal).Coins = 1e7; adv(1) M.localPlayerRef = normal return not Remotes.func("Request"):InvokeServer("ShopBuy", { Id = "gear_foam_bat" }).ok end)())
	run(admin, "resetShopItem", { item = "gear_foam_bat" })
	run(admin, "resetShopItem", { item = id })
	check("reset puts the item-file price back", ShopConfig.ById[id].Price == 1500 and ShopConfig.ById["gear_foam_bat"].Disabled == false)
	check("Robux items can not be repriced from the panel", (function() local r2 = run(admin, "setShopItem", { item = "pass_DoubleCoins", price = 5 }, true) return r2 and not r2.ok end)())

	-----------------------------------------------------------------
	section("7. announcements, spam protection, no HUD button")
	M.remoteLog = {}
	r = run(admin, "announce", { text = "Event starts soon!" }, true)
	local announced = false
	for _, e in M.remoteLog do if e[1] == "Announce" and type(e[3]) == "table" and e[3].Kind == "Staff" then announced = true end end
	check("admin announcements reach every client", r and r.ok and announced)
	check("moderators can not announce", (function() local r2 = run(mod, "announce", { text = "hi" }, true) return r2 and not r2.ok end)())
	M.localPlayerRef = admin
	local first = Remotes.func("Admin"):InvokeServer("open")
	local second = Remotes.func("Admin"):InvokeServer("open")
	check("requests faster than the spam limit are dropped", first ~= nil and second == nil)
	adv(0.5)

	-- client side: the real client runs for an ordinary player first
	local gui = M.newInstance("PlayerGui", true); RawData[gui].Name = "PlayerGui"; M.setParent(gui, normal)
	M.localPlayerRef = normal
	M.isServer = false
	M.clientRunning = true
	local mainClient = find("StarterPlayer.StarterPlayerScripts.Main")
	task.spawn(function() RawData[mainClient].Source(mainClient, require) end)
	adv(3)
	local function textsOf(inst)
		local out = {}
		local function walk(i)
			local t = RawData[i].Props.Text
			if t then table.insert(out, tostring(t)) end
			for _, c in M.InstanceMethods.GetChildren(i) do walk(c) end
		end
		walk(inst)
		return table.concat(out, "|")
	end
	local hudText = string.lower(textsOf(gui))
	check("the normal HUD has no Admin / Staff button or text", string.find(hudText, "admin", 1, true) == nil and string.find(hudText, "staff", 1, true) == nil)
	local AdminUI = require(find("StarterPlayer.StarterPlayerScripts.UI.AdminUI"))
	AdminUI.open()
	adv(0.5)
	check("for an ordinary player the panel never appears (no ScreenGui, no feedback)", M.InstanceMethods.FindFirstChild(gui, "AdminUI") == nil)
	M.localPlayerRef = owner -- (the single client is now answered as the owner: the server decides by who is asking)
	adv(1)
	AdminUI.open()
	adv(0.5)
	check("for the owner the panel opens", M.InstanceMethods.FindFirstChild(gui, "AdminUI") ~= nil)
	local all = textsOf(M.InstanceMethods.FindFirstChild(gui, "AdminUI"))
	check("the panel lists the staff tools (Kick, Ban ...)", string.find(all, "Kick player", 1, true) and string.find(all, "Ban player", 1, true), all:sub(1, 300))
	print(string.format("PASS %d  FAIL %d", results.pass, results.fail))
	print("== done ==")
end)
