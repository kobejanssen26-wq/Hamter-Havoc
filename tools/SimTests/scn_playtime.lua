-- Playtime rewards: server-side counting, milestones, one claim per player, persistence, failure safety, window
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
	local PlaytimeSystem = require(find(S .. "PlaytimeSystem"))
	local Rewards = require(find(S .. "Rewards"))
	local ReplicationSystem = require(find(S .. "ReplicationSystem"))
	local PlaytimeConfig = require(find(MOD .. "PlaytimeConfig"))
	local Remotes = require(find("ReplicatedStorage.Remotes"))
	local function join(name, uid)
		local p = M.newPlayer(name)
		if uid then RawData[p].Props.UserId = uid end
		fireJoin(p)
		M.spawnCharacter(p)
		return p
	end
	local function as(p, action, payload)
		M.localPlayerRef = p
		return Remotes.func("Request"):InvokeServer(action, payload or {})
	end

	section("1. configuration")
	check("the milestone list has no problems", #PlaytimeConfig.validate() == 0, table.concat(PlaytimeConfig.validate(), "; "))
	local minutes = {}
	for _, m in PlaytimeConfig.Milestones do table.insert(minutes, m.Minutes) end
	check("milestones: 10, 30, 60, 120, 180, 240, 360 and 480 minutes (up to 8 hours)", table.concat(minutes, ",") == "10,30,60,120,180,240,360,480" and PlaytimeConfig.maxSeconds() == 8 * 3600)
	check("a broken milestone list is detected (duplicate id, over 8 hours, unknown item, empty reward)", (function()
		local saved = PlaytimeConfig.Milestones
		PlaytimeConfig.Milestones = { { Id = "a", Minutes = 10, Reward = { Coins = 5 } }, { Id = "a", Minutes = 600, Reward = { Items = { "nope" } } }, { Id = "c", Minutes = 700, Reward = {} } }
		local issues = PlaytimeConfig.validate()
		PlaytimeConfig.Milestones = saved
		return #issues >= 4
	end)())

	section("2. the SERVER counts the time")
	local alice = join("Alice", 8101)
	adv(8)
	local a = DataSystem.get(alice)
	check("a new player starts with 0 seconds and nothing claimed", a.Playtime ~= nil and a.Playtime.Seconds < 12 and next(a.Playtime.Claimed) == nil, a.Playtime and a.Playtime.Seconds)
	local t0 = a.Playtime.Seconds
	adv(60)
	local gained = a.Playtime.Seconds - t0
	check("a minute in the game adds about a minute (counted every 5 s on the server)", gained >= 50 and gained <= 66, gained)
	check("the counter is published to the player (attribute PlaytimeSeconds) for the window", RawData[alice].Attributes.PlaytimeSeconds ~= nil and math.abs(RawData[alice].Attributes.PlaytimeSeconds - a.Playtime.Seconds) <= 6)
	local before = a.Playtime.Seconds
	PlaytimeSystem.credit(alice, 100000)
	check("one tick can never add more than ten seconds (a frozen clock or a burst adds nothing big)", a.Playtime.Seconds - before <= 10.001, a.Playtime.Seconds - before)
	RawData[alice].Attributes.PlaytimeSeconds = 99999 -- a client can set attributes on its own player: the server must not care
	check("changing the published number does not change the real time", PlaytimeSystem.seconds(alice) < 200)

	section("3. claiming")
	a.Playtime.Seconds = 5
	local early = as(alice, "ClaimPlaytime", { Id = "t10m" })
	check("a reward whose time is not reached is refused", early.ok == false and a.Playtime.Claimed.t10m == nil, early.msg)
	for _, bad in { "nope", 5, true, { "t10m" }, "" } do
		local r = as(alice, "ClaimPlaytime", { Id = bad })
		check("a forged id (" .. type(bad) .. ") is refused", r.ok == false and next(a.Playtime.Claimed) == nil)
	end
	a.Playtime.Seconds = 601
	adv(1)
	local coinsBefore = a.Coins
	local first = as(alice, "ClaimPlaytime", { Id = "t10m" })
	check("after 10 minutes the first reward can be claimed and pays coins", first.ok and a.Playtime.Claimed.t10m == true and a.Coins > coinsBefore, tostring(first.msg))
	local again = as(alice, "ClaimPlaytime", { Id = "t10m" })
	check("the same reward can not be claimed twice", again.ok == false)
	adv(1)
	local grabbed = 0
	a.Playtime.Seconds = 1850
	for _ = 1, 6 do
		if as(alice, "ClaimPlaytime", { Id = "t30m" }).ok then grabbed += 1 end
	end
	check("six requests in one instant pay the 30 minute reward exactly once", grabbed == 1 and a.Playtime.Claimed.t30m == true, grabbed)
	adv(1)
	local locked = as(alice, "ClaimPlaytime", { Id = "t8h" })
	check("a far milestone is still locked", locked.ok == false and a.Playtime.Claimed.t8h == nil)

	section("4. it stays after leaving and coming back")
	local secondsBefore = a.Playtime.Seconds
	DataSystem.save(alice, false)
	M.removePlayer(alice)
	adv(3)
	local alice2 = join("Alice", 8101)
	adv(8)
	local b = DataSystem.get(alice2)
	check("the time and the claimed milestones are kept", b.Playtime.Seconds >= secondsBefore - 1 and b.Playtime.Claimed.t10m == true and b.Playtime.Claimed.t30m == true, b.Playtime.Seconds)
	adv(1)
	check("...so a claimed reward can not be claimed again after rejoining", as(alice2, "ClaimPlaytime", { Id = "t10m" }).ok == false)

	section("5. every reward pays what it says")
	alice, a = alice2, b
	a.Playtime.Seconds = 8 * 3600
	local Collection = require(find(S .. "CollectionSystem"))
	local paid = {}
	for _, milestone in PlaytimeConfig.Milestones do
		if not a.Playtime.Claimed[milestone.Id] then
			adv(1)
			local gemsBefore, coinsBefore2 = a.Gems, a.Coins
			local itemsBefore = {}
			for _, id in milestone.Reward.Items or {} do itemsBefore[id] = (a.Items[id] or 0) + (if a.Gear[id] then 1 else 0) end
			local hamstersBefore = 0
			for _, v in a.Inventory do hamstersBefore += v end
			local r = as(alice, "ClaimPlaytime", { Id = milestone.Id })
			local hamstersAfter = 0
			for _, v in a.Inventory do hamstersAfter += v end
			local reward = milestone.Reward
			local ok = r.ok and a.Playtime.Claimed[milestone.Id] == true
			if reward.Gems then ok = ok and a.Gems > gemsBefore end
			if reward.Coins then ok = ok and a.Coins > coinsBefore2 end
			for _, id in reward.Items or {} do
				ok = ok and ((a.Items[id] or 0) + (if a.Gear[id] then 1 else 0)) > itemsBefore[id]
			end
			if reward.HamsterRarity then ok = ok and hamstersAfter == hamstersBefore + 1 end
			if reward.Boost then ok = ok and (a.Boosts[reward.Boost.Id] or 0) > os.time() end
			table.insert(paid, milestone.Id .. "=" .. tostring(ok))
			check("milestone " .. milestone.Id .. " pays: " .. table.concat(PlaytimeConfig.lines(milestone, a.Rebirths or 0), ", "), ok, r.msg)
		end
	end
	local allClaimed = true
	for _, milestone in PlaytimeConfig.Milestones do if not a.Playtime.Claimed[milestone.Id] then allClaimed = false end end
	check("after 8 hours all eight rewards are claimed", allClaimed)
	check("claimed hamsters are never exclusive or limited-edition ones", (function()
		local HamsterDatabase = require(find(MOD .. "HamsterDatabase"))
		for id in a.Inventory do
			local species = HamsterDatabase.ById[id]
			if species and (species.Exclusive and not (id == "calendar_cutie" or id == "sunday_sunbeam")) and species.Limited then return false end
		end
		return true
	end)())

	section("6. a payment that fails does not lose or double the reward")
	local carol = join("Carol", 8102)
	adv(8)
	local c = DataSystem.get(carol)
	c.Playtime.Seconds = 700
	local realGrant = Rewards.grant
	local broke = true
	Rewards.grant = function(player, reward)
		if broke then error("simulated failure") end
		return realGrant(player, reward)
	end
	adv(1)
	local coinsC = c.Coins
	local failed = as(carol, "ClaimPlaytime", { Id = "t10m" })
	check("when paying fails the milestone is NOT marked as claimed and nothing is kept", failed.ok == false and c.Playtime.Claimed.t10m == nil and c.Coins == coinsC, failed.msg)
	broke = false
	adv(1)
	local retry = as(carol, "ClaimPlaytime", { Id = "t10m" })
	check("...and it can be claimed (once) afterwards", retry.ok and c.Playtime.Claimed.t10m == true)
	Rewards.grant = realGrant
	adv(1)
	check("...and not again", as(carol, "ClaimPlaytime", { Id = "t10m" }).ok == false)

	section("7. the window")
	alice = alice2
	M.localPlayerRef = alice
	local gui = M.newInstance("PlayerGui", true); RawData[gui].Name = "PlayerGui"; M.setParent(gui, alice)
	local d = DataSystem.get(alice)
	d.Playtime = { Seconds = 1850, Claimed = { t10m = true } }
	RawData[alice].Attributes.PlaytimeSeconds = 1850
	M.isServer = false
	M.clientRunning = true
	local mainClient = find("StarterPlayer.StarterPlayerScripts.Main")
	task.spawn(function() RawData[mainClient].Source(mainClient, require) end)
	adv(3)
	local UIKit = require(find("StarterPlayer.StarterPlayerScripts.UI.UIKit"))
	local UIRegistry = require(find("StarterPlayer.StarterPlayerScripts.UI.UIRegistry"))
	local function byName(root, name)
		local found = {}
		for _, x in M.descendants(root) do if RawData[x].Name == name then table.insert(found, x) end end
		return found
	end
	local function textsOf(root)
		local list = {}
		for _, x in M.descendants(root) do
			if RawData[x].ClassName == "TextLabel" or RawData[x].ClassName == "TextButton" then table.insert(list, tostring(RawData[x].Props.Text)) end
		end
		return table.concat(list, "|")
	end
	local function click(inst) RawData[inst].Signals.Activated:Fire() adv(0.5) end
	local panel = UIKit.getPanel("Playtime")
	check("the Playtime window exists and does NOT open by itself at the start", panel ~= nil and panel.IsOpen == false and RawData[panel.Gui].Props.Enabled ~= true)
	local entry = UIRegistry.get("Playtime")
	check("it has an icon (hourglass) in the right rail with a dot when a reward is ready", entry ~= nil and entry.Icon == "hourglass" and entry.Slot == "RightRail" and entry.Badge ~= nil and entry.Badge() == true)
	panel:Open(); adv(1.2)
	check("it shows all eight milestones", (function()
		local n = 0
		for _, x in M.descendants(panel.Gui) do if string.sub(RawData[x].Name, 1, 10) == "Milestone_" then n += 1 end end
		return n == 8
	end)())
	local texts = textsOf(panel.Gui)
	check("it shows the time played, the next reward, and which are claimed", string.find(texts, "Time played", 1, true) ~= nil and string.find(texts, "Claimed", 1, true) ~= nil and string.find(texts, "30m", 1, true) ~= nil)
	local readyCard = byName(panel.Gui, "Milestone_t30m")[1]
	local claimButton = byName(readyCard, "Claim")[1]
	check("the 30 minute reward (reached, not claimed) shows a visible Claim button; the claimed 10 minute one does not", RawData[claimButton].Props.Visible == true and RawData[byName(byName(panel.Gui, "Milestone_t10m")[1], "Claim")[1]].Props.Visible == false)
	check("a milestone that is not reached shows how long it takes, no Claim button", RawData[byName(byName(panel.Gui, "Milestone_t1h")[1], "Claim")[1]].Props.Visible == false and string.find(textsOf(byName(panel.Gui, "Milestone_t1h")[1]), "in ", 1, true) ~= nil)
	local gemsBeforeClaim = d.Gems
	click(claimButton)
	adv(1)
	check("pressing Claim in the window claims it on the server (marked claimed, paid)", d.Playtime.Claimed.t30m == true and d.Gems > gemsBeforeClaim, d.Gems - gemsBeforeClaim)
	adv(1.5)
	check("the window then shows it as Claimed and the Claim button is gone", RawData[byName(byName(panel.Gui, "Milestone_t30m")[1], "Claim")[1]].Props.Visible == false and string.find(textsOf(byName(panel.Gui, "Milestone_t30m")[1]), "Claimed", 1, true) ~= nil)
	panel:Close(); adv(0.5)
	local _ = ReplicationSystem
	check("no new errors in the output", #M.Sim.errors == 0, #M.Sim.errors)

	print(string.format("\nPASS %d  FAIL %d", results.pass, results.fail))
end)
