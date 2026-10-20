-- Character actions (ActionCatalog -> ActionFx on the server -> ActionAnimator on every client): the server announces only
-- things that really happened, spam is throttled, unknown ids are ignored, and the client pose moves the joints and puts them back.
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
	local DataSystem = require(find(S .. "DataSystem"))
	local ActionFx = require(find(S .. "ActionFx"))
	local ActionCatalog = require(find("ReplicatedStorage.Modules.ActionCatalog"))
	local AudioConfig = require(find("ReplicatedStorage.Modules.AudioConfig"))
	local Remotes = require(find("ReplicatedStorage.Remotes"))
	local ActionAnimator = require(find("StarterPlayer.StarterPlayerScripts.Controllers.ActionAnimator"))

	local p = M.newPlayer("Anna")
	fireJoin(p)
	M.spawnCharacter(p)
	adv(8)
	local data = DataSystem.get(p)
	local function ask(action, payload)
		M.localPlayerRef = p
		return Remotes.func("Request"):InvokeServer(action, payload or {})
	end
	local function actionsLogged()
		local list = {}
		for _, e in M.remoteLog or {} do
			if e[1] == "Fx" and e[2] == "ALL" and e[3] == "Action" then table.insert(list, e[4]) end
		end
		return list
	end
	local function count(id)
		local n = 0
		for _, a in actionsLogged() do if a == id then n += 1 end end
		return n
	end

	section("1. the catalog")
	local valid = true
	local poses = ActionAnimator.Poses
	for _, entry in ActionCatalog.List do
		local ok = type(entry.Id) == "string" and type(entry.Name) == "string" and poses[entry.Pose] ~= nil and entry.Cooldown >= 0 and entry.Duration > 0 and type(entry.Availability) == "string" and type(entry.Trigger) == "string"
		if entry.Sound and not AudioConfig.Sfx[entry.Sound] then ok = false end
		if not ok then valid = false print("   BAD", entry.Id) end
	end
	check("every action has a name, a known pose, a real sound name, a cooldown, a duration, availability and trigger", valid)
	check("the catalog contains no asset ids (nothing invented)", (function()
		for _, entry in ActionCatalog.List do
			for _, value in entry do if type(value) == "string" and string.find(value, "rbxassetid", 1, true) then return false end end
		end
		return true
	end)())
	for _, id in { "PickUpHamster", "PlaceHamster", "TakeHamster", "Buy", "OpenReward", "ClaimReward", "EquipItem", "Celebrate", "Slap" } do
		check("catalog has " .. id, ActionCatalog.ById[id] ~= nil)
	end

	section("2. the server announces only real events")
	M.remoteLog = {}
	check("an unknown action id is ignored", ActionFx.play(p, "Teleport") == false and #actionsLogged() == 0)
	data.Inventory = { silver = 1 }
	data.Equipped = {}
	check("placing a hamster you own announces PlaceHamster", ask("Equip", { Id = "silver" }).ok and count("PlaceHamster") == 1)
	adv(0.5)
	local failed = ask("Equip", { Id = "silver" })
	check("a refused placement (no free copy) announces nothing", not failed.ok and count("PlaceHamster") == 1, failed.msg)
	check("taking it off the bench announces TakeHamster", ask("Unequip", { Id = "silver" }).ok and count("TakeHamster") == 1)
	adv(0.5)
	check("taking off a hamster that is not placed announces nothing", not ask("Unequip", { Id = "silver" }).ok and count("TakeHamster") == 1)
	data.Coins = 1e9
	local before = #actionsLogged()
	local up = ask("BuyUpgrade", { Id = "HamsterTraining" })
	check("a successful purchase announces Buy", up.ok and count("Buy") == 1, up.msg)
	adv(0.6)
	data.Coins = 0
	local poor = ask("BuyUpgrade", { Id = "CollectionRange" })
	check("a refused purchase (no cash) announces nothing", not poor.ok and count("Buy") == 1, poor.msg)
	data.Coins = 1e9
	local daily = ask("ClaimDaily")
	check("a claimed daily reward announces ClaimReward", daily.ok and count("ClaimReward") == 1, daily.msg)
	adv(1)
	check("claiming it again (already claimed) announces nothing", not ask("ClaimDaily").ok and count("ClaimReward") == 1)

	section("3. spam protection")
	M.remoteLog = {}
	adv(3)
	local sent = 0
	for _ = 1, 20 do if ActionFx.play(p, "Buy") then sent += 1 end end
	check("20 instant Buy announcements -> only one goes out (cooldown)", sent == 1 and count("Buy") == 1, sent)
	adv(1)
	check("after the cooldown it works again", ActionFx.play(p, "Buy") == true)

	section("4. the client draws it (R15 joints move and are restored)")
	local character = RawData[p].Props.Character
	local function part(name, parent)
		local x = M.newInstance("Part", true)
		RawData[x].Name = name
		M.setParent(x, parent)
		return x
	end
	local torso = part("UpperTorso", character)
	local arm = part("RightUpperArm", character)
	local larm = part("LeftUpperArm", character)
	local head = part("Head", character)
	local function joint(name, parent, c0)
		local m = M.newInstance("Motor6D", true)
		RawData[m].Name = name
		RawData[m].Props.C0 = c0
		M.setParent(m, parent)
		return m
	end
	local rs = joint("RightShoulder", arm, CFrame.new(1, 0.5, 0))
	local ls = joint("LeftShoulder", larm, CFrame.new(-1, 0.5, 0))
	local neck = joint("Neck", head, CFrame.new(0, 1, 0))
	local rest = RawData[rs].Props.C0
	check("a known action starts a pose", ActionAnimator.play(p, "PlaceHamster", Vector3.new(0, 5, 0)) == true)
	adv(0.1)
	local mid = RawData[rs].Props.C0
	local function tilt(cf) return cf.UpVector.Y end
	check("the shoulder moved during the pose", math.abs(tilt(mid) - tilt(rest)) > 0.05, tilt(mid))
	adv(2)
	check("...and every joint is back exactly where it was", math.abs(tilt(RawData[rs].Props.C0) - tilt(rest)) < 1e-6 and math.abs(tilt(RawData[ls].Props.C0) - 1) < 1e-6 and math.abs(tilt(RawData[neck].Props.C0) - 1) < 1e-6)
	ActionAnimator.play(p, "ArmsUp")
	adv(0.2)
	ActionAnimator.play(p, "Buy") -- overlapping actions
	adv(2)
	check("two overlapping actions still restore the original joints", math.abs(tilt(RawData[rs].Props.C0) - tilt(rest)) < 1e-6 and math.abs(tilt(RawData[neck].Props.C0) - 1) < 1e-6)
	check("an unknown action id on the client does nothing", ActionAnimator.play(p, "Nope") == false)
	RawData[character].Props.Parent = nil
	check("a player without a character is ignored", pcall(ActionAnimator.playForUserId, 999999, "Buy", nil))

	print(string.format("PASS %d  FAIL %d", results.pass, results.fail))
	print("== done ==")
end)
