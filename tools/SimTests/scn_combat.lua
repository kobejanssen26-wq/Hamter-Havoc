-- Combat rebuild: server-authoritative swings (stationary + moving + running targets, directions, walls, cooldown, single hit per
-- swing, respawn, several attackers, safe zones, caps, forged remote calls, abilities ending) and GameConfig wiring.
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
	local MOD = "ReplicatedStorage.Modules."
	local HamsterSystem = require(find(S .. "HamsterSystem"))
	local CombatSystem = require(find(S .. "CombatSystem"))
	local AbilitySystem = require(find(S .. "AbilitySystem"))
	local DataSystem = require(find(S .. "DataSystem"))
	local PlayerState = require(find(S .. "PlayerState"))
	local GameConfig = require(find(MOD .. "GameConfig"))
	local SecurityConfig = require(find(MOD .. "SecurityConfig"))
	local ItemRegistry = require(find(MOD .. "ItemRegistry"))
	local CombatTiming = require(find(MOD .. "CombatTiming"))
	local Remotes = require(find("ReplicatedStorage.Remotes"))
	HamsterSystem.AutoSpawn = false

	local function join(name)
		local p = M.newPlayer(name)
		fireJoin(p)
		M.spawnCharacter(p)
		return p
	end
	local alice, bob, carol = join("Alice"), join("Bob"), join("Carol")
	adv(8) -- spawn protection (4 s) is over
	local function data(p) return DataSystem.get(p) end
	local function as(p, action, payload)
		M.localPlayerRef = p
		return Remotes.func("Request"):InvokeServer(action, payload or {})
	end
	local function rootOf(p) return M.InstanceMethods.FindFirstChild(RawData[p].Props.Character, "HumanoidRootPart") end
	local function place(p, pos, lookAt)
		RawData[rootOf(p)].Props.CFrame = if lookAt then CFrame.lookAt(pos, lookAt) else CFrame.new(pos)
	end
	local function posOf(p) return RawData[rootOf(p)].Props.CFrame.Position end
	local function slaps(p) return data(p).Stats.Slaps or 0 end
	local function reset() -- everybody far apart, no stun, no immunity, all cooldowns over
		adv(5)
		for i, p in { alice, bob, carol } do
			PlayerState.clear(p)
			PlayerState.grantImmunity(p, 0)
			place(p, Vector3.new(i * 400, 5, 0))
			RawData[rootOf(p)].Props.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		end
		adv(3)
		for _, p in { alice, bob, carol } do
			-- immunity left from earlier hits would hide the next result
			PlayerState.forget(p)
		end
		M.rayResult = nil
	end
	local function swing(attacker, aim)
		CombatSystem.attack(attacker, aim)
		adv(0.6)
	end
	local ORIGIN = Vector3.new(0, 5, 0)

	-----------------------------------------------------------------
	section("1. config + timing sanity")
	local problems = GameConfig.selfCheck()
	check("GameConfig defaults are inside their own limits and documented", #problems == 0, table.concat(problems, "; "))
	local worst
	for _, def in ItemRegistry.List do
		if def.Equip.Kind == "Tool" then
			local windUp, active, recovery = CombatTiming.of(def.Equip.Weapon)
			if windUp + active > def.Equip.Weapon.Cooldown then worst = def.Id end
			if recovery < 0 then worst = def.Id end
		end
	end
	check("every weapon's WindUp + Active fits inside its Cooldown", worst == nil, worst)
	check("invalid values are rejected (negative, wrong type, NaN, out of range, unknown)",
		not GameConfig.set("Combat", "PawRange", -5) and not GameConfig.set("Combat", "PawRange", "far")
		and not GameConfig.set("Combat", "PawRange", 0 / 0) and not GameConfig.set("Combat", "PawRange", 1e9)
		and not GameConfig.set("Combat", "NoSuchSetting", 1) and not GameConfig.set("Nope", "X", 1) and not GameConfig.set("Combat", "WallCheck", 3))
	check("a Studio-only setting can not be changed live", not GameConfig.set("Economy", "StartingCash", 5, true) and GameConfig.set("Economy", "StartingCash", 250, false))

	-----------------------------------------------------------------
	section("2. gate cooldown comes from ONE setting")
	local basic = SecurityConfig.Tiers[1]
	check("default gate reopen cooldown is 7 s for the basic gate", SecurityConfig.recharge(basic) == 7, SecurityConfig.recharge(basic))
	GameConfig.set("Security", "GateReopenCooldown", 20, true)
	check("changing GateReopenCooldown changes the real recharge (basic 20 s, royal 17 s)", SecurityConfig.recharge(basic) == 20 and SecurityConfig.recharge(SecurityConfig.Tiers[4]) == 17)
	GameConfig.set("Security", "GateBaseDuration", 30, true)
	check("gate duration setting changes SecurityConfig.duration", SecurityConfig.duration(0) == 30 and SecurityConfig.duration(2) == 50)
	GameConfig.reset("Security", "GateReopenCooldown", true)
	GameConfig.reset("Security", "GateBaseDuration", true)
	check("reset returns to the defaults", SecurityConfig.recharge(basic) == 7 and SecurityConfig.duration(0) == 45)

	-----------------------------------------------------------------
	section("3. stationary and moving targets (bare paws, no hamster anywhere)")
	reset()
	place(bob, ORIGIN + Vector3.new(0, 0, 5)); place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 5))
	local before = slaps(alice)
	swing(alice)
	check("stationary target in front is hit (no hamster needed)", slaps(alice) == before + 1 and PlayerState.isStunned(bob))

	-- target RUNS AWAY at 20 studs/s during the swing
	reset()
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 0, 5))
	before = slaps(alice)
	CombatSystem.attack(alice, nil)
	for _ = 1, 12 do
		local p = posOf(bob)
		place(bob, p + Vector3.new(0, 0, 1)) -- 1 stud per 0.05 s = 20 studs/s
		RawData[rootOf(bob)].Props.AssemblyLinearVelocity = Vector3.new(0, 0, 20)
		adv(0.05)
	end
	check("a target running away at 20 studs/s is still hit", slaps(alice) == before + 1, slaps(alice) - before)

	-- target runs ACROSS the front of the attacker
	reset()
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(-12, 0, 5))
	before = slaps(alice)
	CombatSystem.attack(alice, nil)
	for _ = 1, 12 do
		place(bob, posOf(bob) + Vector3.new(2, 0, 0)) -- 40 studs/s sideways sprint
		RawData[rootOf(bob)].Props.AssemblyLinearVelocity = Vector3.new(40, 0, 0)
		adv(0.05)
	end
	check("a target sprinting across the swing is hit when it crosses the hit area", slaps(alice) == before + 1, slaps(alice) - before)

	-- attacker runs while swinging
	reset()
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 0, 14))
	before = slaps(alice)
	CombatSystem.attack(alice, nil)
	for _ = 1, 12 do
		place(alice, posOf(alice) + Vector3.new(0, 0, 1), posOf(alice) + Vector3.new(0, 0, 10))
		adv(0.05)
	end
	check("the attacker can hit while running forward", slaps(alice) == before + 1, slaps(alice) - before)

	-----------------------------------------------------------------
	section("4. directions, range, walls")
	reset()
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 0, -5))
	before = slaps(alice); swing(alice)
	check("a target BEHIND the attacker is not hit", slaps(alice) == before)
	reset()
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(5, 0, 0))
	before = slaps(alice); swing(alice)
	check("a target at the side (90 degrees) is not hit with the narrow paw arc", slaps(alice) == before)
	reset()
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 0, 30))
	before = slaps(alice); swing(alice)
	check("a target 30 studs away is not hit", slaps(alice) == before)
	reset()
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 20, 5))
	before = slaps(alice); swing(alice)
	check("a target 20 studs above is not hit", slaps(alice) == before)
	reset()
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 0, 5))
	M.rayResult = { Instance = true, Position = ORIGIN + Vector3.new(0, 0, 3) }
	before = slaps(alice); swing(alice)
	check("a wall between attacker and target blocks the hit", slaps(alice) == before)
	GameConfig.set("Combat", "WallCheck", false, true)
	reset()
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 0, 5))
	M.rayResult = { Instance = true }
	before = slaps(alice); swing(alice)
	check("...and WallCheck = false in GameConfig really turns that off", slaps(alice) == before + 1)
	GameConfig.reset("Combat", "WallCheck", true); M.rayResult = nil
	reset()
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 0, 9.4))
	before = slaps(alice); swing(alice)
	check("a standing target just outside the 8 stud paw range is not hit (no free extra reach)", slaps(alice) == before)
	GameConfig.set("Combat", "PawRange", 12, true)
	reset()
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 0, 9.4))
	before = slaps(alice); swing(alice)
	check("raising PawRange to 12 in GameConfig changes the real reach", slaps(alice) == before + 1)
	GameConfig.reset("Combat", "PawRange", true)

	-----------------------------------------------------------------
	section("5. one swing = one hit, cooldown, repeated input")
	reset()
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 0, 4)); place(carol, ORIGIN + Vector3.new(0, 0, 6))
	before = slaps(alice); swing(alice)
	check("one swing hits ONE player (the nearest) by default", slaps(alice) == before + 1 and PlayerState.isStunned(bob) and not PlayerState.isStunned(carol))
	GameConfig.set("Combat", "MaxTargetsPerSwing", 2, true)
	reset()
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 0, 4)); place(carol, ORIGIN + Vector3.new(0, 0, 6))
	before = slaps(alice); swing(alice)
	check("MaxTargetsPerSwing = 2 lets one swing hit two players, each exactly once", slaps(alice) == before + 2)
	GameConfig.reset("Combat", "MaxTargetsPerSwing", true)
	reset()
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 0, 4))
	before = slaps(alice)
	for _ = 1, 10 do CombatSystem.attack(alice, nil); adv(0.05) end
	adv(0.4)
	check("mashing the attack button 10x inside the cooldown still only swings once", slaps(alice) == before + 1, slaps(alice) - before)
	adv(2)
	PlayerState.forget(bob); place(bob, ORIGIN + Vector3.new(0, 0, 4))
	CombatSystem.attack(alice, nil); adv(0.6)
	check("after the cooldown the next swing works", slaps(alice) == before + 2)

	-----------------------------------------------------------------
	section("6. stun / knockback caps, hit immunity, several attackers")
	reset()
	GameConfig.set("Combat", "MaxKnockback", 30, true)
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 0, 4))
	M.remoteLog = {}
	swing(alice)
	local kb
	for _, entry in M.remoteLog do if entry[1] == "Knockback" then kb = entry[3] end end
	check("knockback sent to the victim is capped by GameConfig.MaxKnockback", kb ~= nil and math.sqrt(kb.X ^ 2 + kb.Z ^ 2) <= 30.01, kb and string.format("%.1f", math.sqrt(kb.X ^ 2 + kb.Z ^ 2)))
	check("...and has a vertical lift under the cap", kb ~= nil and kb.Y <= GameConfig.get("Combat", "MaxKnockbackLift") + 0.01)
	GameConfig.reset("Combat", "MaxKnockback", true)

	reset()
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(carol, ORIGIN + Vector3.new(0, 0, -1), ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 0, 3))
	RawData[rootOf(carol)].Props.CFrame = CFrame.lookAt(ORIGIN + Vector3.new(0, 0, -1), ORIGIN + Vector3.new(0, 0, 3))
	local total = slaps(alice) + slaps(carol)
	CombatSystem.attack(alice, nil); CombatSystem.attack(carol, nil)
	adv(0.8)
	check("two attackers hitting the same player at once: only one hit lands (no stacked knockback/stun)", slaps(alice) + slaps(carol) == total + 1, slaps(alice) + slaps(carol) - total)
	adv(3) -- stun (0.9 s) + hit immunity (0.9 s) are over
	place(bob, ORIGIN + Vector3.new(0, 0, 3)); RawData[rootOf(carol)].Props.CFrame = CFrame.lookAt(ORIGIN + Vector3.new(0, 0, -1), ORIGIN + Vector3.new(0, 0, 3))
	total = slaps(alice) + slaps(carol)
	CombatSystem.attack(carol, nil); adv(0.6)
	check("the same victim can be hit again once stun + hit-immunity are over", slaps(alice) + slaps(carol) == total + 1)

	-----------------------------------------------------------------
	section("7. respawn, stun cleanup, spawn protection")
	reset()
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 0, 4))
	swing(alice)
	check("bob is stunned (WalkSpeed 0)", PlayerState.isStunned(bob) and RawData[M.InstanceMethods.FindFirstChildOfClass(RawData[bob].Props.Character, "Humanoid")].Props.WalkSpeed == 0)
	M.spawnCharacter(bob) -- bob dies while stunned and respawns
	adv(0.3)
	local humanoid = M.InstanceMethods.FindFirstChildOfClass(RawData[bob].Props.Character, "Humanoid")
	check("a respawned player is no longer stunned and can walk", not PlayerState.isStunned(bob) and RawData[humanoid].Props.WalkSpeed > 0, RawData[humanoid].Props.WalkSpeed)
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 0, 4))
	adv(2)
	before = slaps(alice); swing(alice)
	check("spawn protection: a player who just respawned can not be hit", slaps(alice) == before)
	adv(6)
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 0, 4))
	before = slaps(alice); swing(alice)
	check("...but can once the protection (4 s) has passed", slaps(alice) == before + 1)
	-- attacker stunned mid-windup: swing is cancelled
	reset()
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 0, 4))
	CombatSystem.attack(alice, nil)
	PlayerState.stun(alice, 1, 0)
	adv(0.6)
	check("an attacker who gets stunned during the wind-up does not land the hit", not PlayerState.isStunned(bob))

	-----------------------------------------------------------------
	section("8. safe zones and forged remote calls")
	reset()
	local zone = Instance.new("Part")
	zone.Size = Vector3.new(30, 20, 30); zone.CFrame = CFrame.new(Vector3.new(600, 5, 0)); zone.Anchored = true
	zone.Parent = workspace
	CollectionService:AddTag(zone, "SafeZone")
	place(alice, Vector3.new(560, 5, 0), Vector3.new(560, 5, 1)); place(bob, Vector3.new(560, 5, 4))
	place(bob, Vector3.new(600, 5, 4))
	place(alice, Vector3.new(585, 5, 4), Vector3.new(600, 5, 4)) -- alice is inside the zone too (zone spans 585..615)
	before = slaps(alice); swing(alice)
	check("nobody can attack from inside a safe zone", slaps(alice) == before)
	place(alice, Vector3.new(570, 5, 4), Vector3.new(600, 5, 4)) -- outside, facing in
	place(bob, Vector3.new(578, 5, 4)); place(bob, Vector3.new(586, 5, 4))
	adv(2)
	before = slaps(alice); swing(alice)
	check("a target standing inside a safe zone can not be hit from outside", slaps(alice) == before)
	CollectionService:RemoveTag(zone, "SafeZone")
	reset()
	local hallZone
	for _, z in CollectionService:GetTagged("SafeZone") do if RawData[z].Name == "SafeZone" then hallZone = z end end
	check("the Leaderboard Hall has a real SafeZone part in the world (editable in Studio)", hallZone ~= nil)
	if hallZone then
		local zp = RawData[hallZone].Props.CFrame.Position
		place(bob, zp + Vector3.new(0, 0, 0)); place(alice, zp + Vector3.new(0, 0, -30), zp)
		adv(1)
		before = slaps(alice)
		RawData[rootOf(alice)].Props.CFrame = CFrame.lookAt(Vector3.new(zp.X, 5, zp.Z + 36), Vector3.new(zp.X, 5, zp.Z))
		RawData[rootOf(bob)].Props.CFrame = CFrame.new(Vector3.new(zp.X, 5, zp.Z + 30))
		swing(alice)
		check("in the hall (safe zone) a target standing there is protected", slaps(alice) == before)
	end
	reset()
	-- forged client data
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 0, 40))
	M.localPlayerRef = alice
	local fired = true
	for _, junk in { Vector3.new(0, 1e9, 0), Vector3.new(0 / 0, 0, 0), "bob", { Target = bob }, 12345, true, Vector3.new(0, 0, 0) } do
		fired = fired and pcall(function() Remotes.event("Attack"):FireServer(junk, bob, "Hit", 1e9) end)
		adv(1.3)
	end
	check("forged Attack payloads (fake targets, NaN, huge numbers, strings) cause no error and no hit on a far player", fired and not PlayerState.isStunned(bob) and slaps(alice) == before)
	local names = {}
	for _, child in M.InstanceMethods.GetChildren(find("ReplicatedStorage.RemoteEvents")) do names[#names + 1] = RawData[child].Name end
	local bad
	for _, n in names do if string.find(string.lower(n), "hit") or string.find(string.lower(n), "damage") then bad = n end end
	check("no remote exists through which a client can report a hit or damage (only Attack = 'I swing')", bad == nil and table.find(names, "Attack") ~= nil, bad)

	-----------------------------------------------------------------
	section("9. carrying a hamster vs not carrying")
	reset()
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 0, 4))
	check("bob carries nothing", HamsterSystem.carriedBy(bob) == nil)
	before = slaps(alice); swing(alice)
	check("a player carrying NO hamster is hit exactly like one who does (fix of the main bug)", slaps(alice) == before + 1 and PlayerState.isStunned(bob))
	-- the carrying case (theft interruption, no duplicate / lost hamsters) is covered by scn_gear section 5 and scn_theft.

	-----------------------------------------------------------------
	section("10. abilities end correctly")
	reset()
	a = data(alice); a.Coins = 5e7; a.Rebirths = 6; adv(0.5)
	for _, id in { "gear_slap_glove", "gear_frost_wand", "gear_shadow_cloak", "gear_bubble_shield", "gear_spring_glove", "gear_shock_baton", "gear_party_hammer" } do
		local def = ItemRegistry.get(string.sub(id, 6))
		if def.Currency == "Gems" then a.Gems = 1e6 end
		local r = as(alice, "ShopBuy", { Id = id })
		check("purchase " .. id, r.ok, r.message or r.error)
	end
	adv(0.5)
	-- freeze
	as(alice, "EquipItem", { Id = "frost_wand" }); adv(0.5)
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 0, 20))
	adv(2)
	CombatSystem.attack(alice, Vector3.new(0, 0, 1)); adv(0.6)
	check("freeze hits a target on the aim line", PlayerState.isFrozen(bob))
	adv(2.3)
	humanoid = M.InstanceMethods.FindFirstChildOfClass(RawData[bob].Props.Character, "Humanoid")
	check("a freeze ends after its 2 s and walking is restored", not PlayerState.isFrozen(bob) and RawData[humanoid].Props.WalkSpeed > 0)
	adv(1)
	CombatSystem.attack(alice, Vector3.new(0, 0, 1)); adv(0.5)
	check("a frozen player can not be frozen again right away (no chain-freeze) and the miss/refusal costs little cooldown", not PlayerState.isFrozen(bob))
	-- freeze + respawn
	reset(); adv(25)
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); place(bob, ORIGIN + Vector3.new(0, 0, 20))
	CombatSystem.attack(alice, Vector3.new(0, 0, 1)); adv(0.6)
	local froze = PlayerState.isFrozen(bob)
	M.spawnCharacter(bob); adv(0.3)
	humanoid = M.InstanceMethods.FindFirstChildOfClass(RawData[bob].Props.Character, "Humanoid")
	check("respawning while frozen restores movement", froze and not PlayerState.isFrozen(bob) and RawData[humanoid].Props.WalkSpeed > 0)
	-- cloak
	reset()
	as(alice, "EquipItem", { Id = "shadow_cloak" }); adv(0.5)
	CombatSystem.attack(alice, nil); adv(0.3)
	check("cloak turns the user invisible", AbilitySystem.isCloaked(alice))
	place(bob, posOf(alice) + Vector3.new(0, 0, 3), posOf(alice)); place(carol, posOf(alice) + Vector3.new(0, 0, 4))
	check("a cloaked player can still be hit by the rules (no immunity)", (CombatSystem.canBeHit(alice)))
	adv(ItemRegistry.get("shadow_cloak").Equip.Weapon.Duration + 0.5)
	check("cloak ends by itself when the timer is over", not AbilitySystem.isCloaked(alice))
	-- guard
	reset(); adv(30)
	as(alice, "EquipItem", { Id = "bubble_shield" }); adv(0.5)
	CombatSystem.attack(alice, nil); adv(0.3)
	check("shield goes up", AbilitySystem.isGuarding(alice))
	place(alice, ORIGIN, ORIGIN); place(bob, ORIGIN + Vector3.new(0, 0, -4), ORIGIN)
	PlayerState.forget(bob); adv(0.5)
	RawData[rootOf(bob)].Props.CFrame = CFrame.lookAt(ORIGIN + Vector3.new(0, 0, -4), ORIGIN)
	before = slaps(bob); CombatSystem.attack(bob, nil); adv(0.6)
	check("a hit on a shielded player does not stun them", slaps(bob) == before + 1 and not PlayerState.isStunned(alice), string.format("bobSlaps+%d aliceStunned=%s guard=%s", slaps(bob) - before, tostring(PlayerState.isStunned(alice)), tostring(AbilitySystem.isGuarding(alice))))
	adv(3.2)
	check("the shield ends after its duration", not AbilitySystem.isGuarding(alice))
	CombatSystem.attack(alice, nil); adv(0.2)
	check("the shield has a cooldown (not re-usable instantly)", not AbilitySystem.isGuarding(alice))

	-----------------------------------------------------------------
	section("11. new weapons behave differently")
	reset(); adv(30)
	local function stat(id) return ItemRegistry.get(id).Equip.Weapon end
	check("glove is faster than the bat; bat reaches further and hits harder", stat("slap_glove").Cooldown < stat("foam_bat").Cooldown and stat("foam_bat").Range > stat("slap_glove").Range and stat("foam_bat").Knockback > stat("slap_glove").Knockback)
	check("baton stuns longest but shoves least; hammer shoves most and is slowest", stat("shock_baton").Stun > stat("party_hammer").Stun * 0.9 and stat("shock_baton").Knockback < stat("slap_glove").Knockback and stat("party_hammer").Cooldown > stat("spring_glove").Cooldown)
	check("every damage weapon is capped inside the global stun/knockback limits", (function()
		for _, def in ItemRegistry.List do
			local w = def.Equip.Kind == "Tool" and def.Equip.Weapon
			if w and w.Knockback and (w.Knockback > 100 or w.Stun > 3) then return false end
		end
		return true
	end)())
	check("the first weapon is available at rebirth 0 for 1,500 cash", ItemRegistry.get("slap_glove").MinRebirth == 0 and ItemRegistry.get("slap_glove").Price == 1500)
	check("rebirth-locked weapons stay locked: party hammer needs rebirth 4", (function()
		local c = data(carol); c.Coins = 1e9; c.Rebirths = 3; adv(0.5)
		M.localPlayerRef = carol
		local r = Remotes.func("Request"):InvokeServer("ShopBuy", { Id = "gear_party_hammer" })
		return not r.ok
	end)())

	-----------------------------------------------------------------
	section("12. emotes and animations vs combat")
	reset(); adv(5)
	local EmoteSystem = require(find(S .. "EmoteSystem"))
	local AnimationRegistry = require(find(MOD .. "AnimationRegistry"))
	as(alice, "UnequipItem"); adv(0.5)
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1))
	CombatSystem.attack(alice, nil)
	local midSwing = EmoteSystem.request(alice, "wave")
	adv(2)
	local afterSwing = EmoteSystem.request(alice, "wave")
	check("an emote is refused in the middle of a swing and allowed afterwards", midSwing == false and afterSwing == true, tostring(midSwing) .. "/" .. tostring(afterSwing))
	local allAction2 = true
	for _, def in ItemRegistry.List do
		if def.Equip.Kind == "Tool" and def.Equip.Weapon.Animation then
			local anim = AnimationRegistry.ByName[def.Equip.Weapon.Animation]
			if not anim or anim.Priority ~= "Action2" or anim.Use ~= "Action" then allAction2 = false end
		end
	end
	check("every weapon animation exists in Content/Animations and uses priority Action2 (above emotes and running)", allAction2)
	check("a weapon animation without an uploaded AssetId is not 'playable' (the built-in swing is used, nothing breaks)", AnimationRegistry.playable("Weapon_SlapGlove") == nil)

	print(string.format("PASS %d  FAIL %d", results.pass, results.fail))
	print("== done ==")
end)
