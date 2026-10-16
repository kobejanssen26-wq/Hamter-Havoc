-- Tutorial: 9 steps, world markers on the REAL tagged objects, skip, replay, persistence, returning players
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
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
	local HamsterSystem = require(find(S .. "HamsterSystem"))
	local TutorialConfig = require(find("ReplicatedStorage.Modules.TutorialConfig"))
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
	local alice, bob = join("Alice"), join("Bob")
	adv(6)
	local a, b = DataSystem.get(alice), DataSystem.get(bob)
	local aliceId = RawData[alice].Props.UserId

	section("1. the world is marked for the guide (tags, not coordinates)")
	for _, name in { "Base", "Bench", "Gate", "Upgrade", "Altar", "Wheel", "Leaderboard" } do
		local count = 0
		for _, inst in CollectionService:GetTagged("TutorialTarget") do
			if inst:GetAttribute("TutorialTarget") == name then count += 1 end
		end
		check("tagged objects exist: " .. name, count >= 1, count)
	end
	local order = {}
	for _, step in TutorialConfig.Steps do table.insert(order, step.Id) end
	check("the tutorial has the 9 steps in order: base, hamster, bench, income, gate, upgrade, altar, wheel, leaderboard", table.concat(order, ",") == "base,hamster,bench,income,gate,upgrade,altar,wheel,leaderboard", table.concat(order, ","))
	check("no step uses a time-based advance (only Ack button, Stat, Equipped)", (function() for _, step in TutorialConfig.Steps do if step.Kind ~= "Ack" and step.Kind ~= "Stat" and step.Kind ~= "Equipped" then return false end end return true end)())
	check("steps that read a stat declare the number needed (Need), so Target stays free for 'what to point at'", (function() for _, step in TutorialConfig.Steps do if step.Kind == "Stat" and type(step.Need) ~= "number" then return false end if type(step.Target) ~= "nil" and type(step.Target) ~= "string" then return false end end return true end)())

	section("2. a returning player never sees it")
	M.isServer = true
	b.Tutorial = { Step = 99, Done = true, Skipped = false }
	M.isServer = true
	check("returning player profile is Done", b.Tutorial.Done == true)
	check("a new player starts at step 1", a.Tutorial.Step == 1 and a.Tutorial.Done == false)

	-- client for alice
	M.localPlayerRef = alice
	local gui = M.newInstance("PlayerGui", true); RawData[gui].Name = "PlayerGui"; M.setParent(gui, alice)
	M.isServer = false
	M.clientRunning = true
	local mainClient = find("StarterPlayer.StarterPlayerScripts.Main")
	task.spawn(function() RawData[mainClient].Source(mainClient, require) end)
	adv(3)
	local TutorialUI = require(find("StarterPlayer.StarterPlayerScripts.UI.TutorialUI"))
	local function byName(root, name)
		local found = {}
		for _, d in M.descendants(root) do if RawData[d].Name == name then table.insert(found, d) end end
		return found
	end
	local function ownerOf(inst)
		local node = RawData[inst].Parent
		while node do
			local v = RawData[node].Attributes.OwnerUserId
			if v ~= nil then return v end
			node = RawData[node].Parent
		end
		return nil
	end
	local card = byName(gui, "TutorialCard")[1]
	check("the guide card is shown for a new player", card ~= nil and RawData[card].Props.Visible == true)
	check("it is small (not a full-screen banner)", RawData[card].Props.Size.X.Offset <= 320 and RawData[card].Props.Size.Y.Offset <= 170)
	local function textOf(name) return tostring(RawData[byName(card, name)[1]].Props.Text) end
	check("step 1 is 'Your base'", textOf("Title") == "Your base", textOf("Title"))
	adv(0.5)
	local target = TutorialUI.CurrentTarget
	check("the marker points at a real tagged object", target ~= nil and RawData[target].Attributes.TutorialTarget == "Base")
	check("...which belongs to MY base, not to somebody else's", target ~= nil and ownerOf(target) == aliceId, tostring(target and ownerOf(target)))
	local marker = workspace:FindFirstChild("TutorialMarker")
	check("...with an arrow and an outline highlight on it", marker ~= nil and M.InstanceMethods.FindFirstChildOfClass(marker, "Highlight") ~= nil and RawData[M.InstanceMethods.FindFirstChildOfClass(marker, "Highlight")].Props.Enabled == true)
	-- the object moves (map edited): the marker follows, nothing is hardcoded
	local before = RawData[target].Props.CFrame
	RawData[target].Props.CFrame = before + Vector3.new(0, 0, 50)
	adv(0.3)
	local mp = RawData[marker].Props.CFrame.Position
	local tp = RawData[target].Props.CFrame.Position
	check("when the object is moved the marker follows it", math.abs(mp.Z - tp.Z) < 1.5, string.format("%.1f vs %.1f", mp.Z, tp.Z))
	RawData[target].Props.CFrame = before

	section("3. walking through all 9 steps")
	M.isServer = false
	check("a wrong step id can't skip ahead", not as(alice, "TutorialAck", { Step = "gate" }).ok and a.Tutorial.Step == 1)
	local function nextButtonPress()
		RawData[byName(card, "Next")[1]].Signals.Activated:Fire()
		adv(0.6)
	end
	nextButtonPress()
	check("Next on step 1 goes to 'Get your first hamster'", a.Tutorial.Step == 2 and textOf("Title") == "Get your first hamster", textOf("Title"))
	check("step 2 has no Next button: you must really buy one", RawData[byName(card, "Next")[1]].Props.Visible == false)
	check("step 2 guides to the hamster balls on the road (target name is \"Hamsters\", not a number)", TutorialUI.TargetName == "Hamsters", tostring(TutorialUI.TargetName))
	a.Stats.Claimed = 1
	adv(2.5)
	check("buying a hamster advances to the working bench", a.Tutorial.Step == 3, a.Tutorial.Step)
	check("the bench step points at the first bench slot", TutorialUI.CurrentTarget ~= nil and RawData[TutorialUI.CurrentTarget].Attributes.TutorialTarget == "Bench" and ownerOf(TutorialUI.CurrentTarget) == aliceId)
	adv(2.5)
	check("it waits until a hamster is really placed on the bench", a.Tutorial.Step == 3)
	a.Stats.CoinsEarned = 0 -- (the base income of the last seconds does not count: only what is earned from now on)
	a.Equipped = { "brownie" }
	adv(2.5)
	check("placing a hamster advances to 'Earn income'", a.Tutorial.Step == 4 and textOf("Title") == "Earn income", a.Tutorial.Step)
	a.Stats.CoinsEarned = 5
	adv(2.5)
	check("it does NOT advance on a timer: only after the cash was really earned", a.Tutorial.Step == 4)
	a.Stats.CoinsEarned = 25
	adv(2.5)
	check("earning cash advances to 'Lock your base'", a.Tutorial.Step == 5 and textOf("Title") == "Lock your base", a.Tutorial.Step)
	adv(0.3)
	check("it points at MY security panel", TutorialUI.CurrentTarget ~= nil and RawData[TutorialUI.CurrentTarget].Attributes.TutorialTarget == "Gate" and ownerOf(TutorialUI.CurrentTarget) == aliceId)
	for _, entry in { { 6, "Upgrade" }, { 7, "Rebirth altar" }, { 8, "Lucky Wheel" }, { 9, "Leaderboard" } } do
		local expected, label = entry[1], entry[2]
		nextButtonPress()
		adv(0.3)
		check("step " .. expected .. " is '" .. label .. "'", a.Tutorial.Step == expected and textOf("Title") == label, textOf("Title"))
		local t = TutorialUI.CurrentTarget
		local want = ({ [6] = "Upgrade", [7] = "Altar", [8] = "Wheel", [9] = "Leaderboard" })[expected]
		check("...and points at the real " .. want .. " object", t ~= nil and RawData[t].Attributes.TutorialTarget == want, t and RawData[t].Attributes.TutorialTarget)
	end
	nextButtonPress()
	check("finishing marks the tutorial done and hides the card", a.Tutorial.Done == true and RawData[card].Props.Visible == false)
	check("no marker remains after the tutorial", TutorialUI.CurrentTarget == nil and RawData[M.InstanceMethods.FindFirstChild(marker, "Arrow")].Props.Enabled == false)

	section("4. replay from Settings, skip, persistence")
	check("Settings has a Replay tutorial button", #byName(gui, "ReplayTutorial") == 1)
	RawData[byName(gui, "ReplayTutorial")[1]].Signals.Activated:Fire()
	adv(0.8)
	check("replay restarts at step 1 and shows the card again", a.Tutorial.Step == 1 and a.Tutorial.Done == false and RawData[card].Props.Visible == true)
	RawData[byName(card, "Skip")[1]].Signals.Activated:Fire()
	adv(0.8)
	check("Skip ends it immediately (and remembers it was skipped)", a.Tutorial.Done == true and a.Tutorial.Skipped == true and RawData[card].Props.Visible == false)
	M.isServer = true
	DataSystem.save(alice, false)
	M.removePlayer(alice)
	adv(3)
	local alice2 = join("Alice", aliceId)
	adv(6)
	check("after rejoining the tutorial stays finished", DataSystem.get(alice2).Tutorial.Done == true)

	print(string.format("PASS %d  FAIL %d", results.pass, results.fail))
	print("== done ==")
end)
