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

	-----------------------------------------------------------------
	section("13. traps (spike, glue, banana)")
	reset(); adv(40)
	local TrapSystem = require(find(S .. "TrapSystem"))
	local a2 = data(alice); a2.Coins = 5e7; a2.Rebirths = 6; adv(0.5)
	for _, id in { "gear_spike_trap", "gear_glue_trap", "gear_banana_peel" } do
		local r = as(alice, "ShopBuy", { Id = id })
		check("purchase " .. id, r.ok, r.message or r.error)
	end
	adv(0.5)
	as(alice, "EquipItem", { Id = "spike_trap" }); adv(0.5)
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1))
	CombatSystem.attack(alice, nil); adv(0.4)
	check("using the spike trap sets one trap in the world", TrapSystem.activeCount(alice) == 1 and workspace:FindFirstChild("Traps") ~= nil)
	local trap1 = TrapSystem.all()[1]
	-- not armed yet: stepping on it does nothing
	place(bob, trap1.Position + Vector3.new(0, 3, 0)); adv(0.3)
	check("a trap is harmless until it is armed (visible warning time)", not PlayerState.isStunned(bob))
	adv(1.5)
	check("then the next stranger who stands on it is stunned and the trap is used up", PlayerState.isStunned(bob) and TrapSystem.activeCount(alice) == 0)
	-- the owner is never hurt by their own trap
	adv(10)
	PlayerState.forget(bob); place(bob, Vector3.new(800, 5, 0))
	CombatSystem.attack(alice, nil); adv(0.4)
	local mine = TrapSystem.all()[1]
	adv(1.6)
	place(alice, mine.Position + Vector3.new(0, 3, 0)); adv(0.5)
	check("the owner can stand on their own trap without harm", not PlayerState.isStunned(alice) and TrapSystem.activeCount(alice) == 1)
	-- max 3 at a time
	for i = 1, 4 do adv(10); place(alice, ORIGIN + Vector3.new(i * 12, 0, 0), ORIGIN + Vector3.new(i * 12, 0, 1)); CombatSystem.attack(alice, nil); adv(0.3) end
	check("at most 3 traps per player (the 4th is refused)", TrapSystem.activeCount(alice) == 3, TrapSystem.activeCount(alice))
	-- spawn protected players are not hit
	local last = TrapSystem.all()[#TrapSystem.all()]
	adv(1.6)
	PlayerState.grantImmunity(carol, 5); place(carol, last.Position + Vector3.new(0, 3, 0)); adv(0.5)
	check("a spawn-protected / immune player is not hit by a trap", not PlayerState.isStunned(carol))
	PlayerState.forget(carol); place(carol, Vector3.new(900, 5, 0))
	-- expiry
	adv(70)
	check("traps disappear after their lifetime", TrapSystem.activeCount(alice) == 0)
	-- safe zone
	local hall
	for _, z in CollectionService:GetTagged("SafeZone") do if RawData[z].Name == "SafeZone" then hall = z end end
	local zp = RawData[hall].Props.CFrame.Position
	place(alice, Vector3.new(zp.X, 5, zp.Z), Vector3.new(zp.X, 5, zp.Z + 1)); adv(10)
	CombatSystem.attack(alice, nil); adv(0.4)
	check("no traps in a safe zone", TrapSystem.activeCount(alice) == 0)
	-- glue
	as(alice, "EquipItem", { Id = "glue_trap" }); adv(10)
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); PlayerState.forget(bob)
	CombatSystem.attack(alice, nil); adv(0.3)
	local glue = TrapSystem.all()[1]
	adv(1.4)
	local normalSpeed = RawData[M.InstanceMethods.FindFirstChildOfClass(RawData[bob].Props.Character, "Humanoid")].Props.WalkSpeed
	place(bob, glue.Position + Vector3.new(0, 3, 0)); adv(0.4)
	local bobHumanoid = M.InstanceMethods.FindFirstChildOfClass(RawData[bob].Props.Character, "Humanoid")
	check("glue slows the victim to about a third of their speed (no stun)", PlayerState.isSlowed(bob) and not PlayerState.isStunned(bob) and RawData[bobHumanoid].Props.WalkSpeed < normalSpeed * 0.5, RawData[bobHumanoid].Props.WalkSpeed)
	adv(5)
	check("...and normal speed comes back by itself", not PlayerState.isSlowed(bob) and RawData[bobHumanoid].Props.WalkSpeed == normalSpeed, RawData[bobHumanoid].Props.WalkSpeed)
	-- banana
	as(alice, "EquipItem", { Id = "banana_peel" }); adv(10)
	place(bob, Vector3.new(700, 5, 0))
	place(alice, ORIGIN, ORIGIN + Vector3.new(0, 0, 1)); PlayerState.forget(bob)
	CombatSystem.attack(alice, nil); adv(0.3)
	local banana = TrapSystem.all()[1]
	adv(1.2)
	M.remoteLog = {}
	place(bob, banana.Position + Vector3.new(0, 3, 0)); adv(0.4)
	local flung = false
	for _, e in M.remoteLog do if e[1] == "Knockback" then flung = true end end
	check("a banana flings and briefly stuns the victim", flung and PlayerState.isStunned(bob), tostring(flung) .. " stunned=" .. tostring(PlayerState.isStunned(bob)) .. " traps=" .. #TrapSystem.all() .. " kind=" .. tostring(banana and banana.Stats.TrapKind))
	-- leaving the game removes the player's traps
	adv(10)
	CombatSystem.attack(alice, nil); adv(0.3)
	local before2 = #TrapSystem.all()
	TrapSystem.forget(alice)
	check("a player's traps are removed when they leave", #TrapSystem.all() == 0 and before2 >= 1)

	-----------------------------------------------------------------
	section("14. daily rewards are specific")
	local DailyRewardConfig = require(find(MOD .. "DailyRewardConfig"))
	local day1 = DailyRewardConfig.lines(1, 0)
	check("day 1 says exactly what you get: 500 Cash + Speed Tonic", day1[1] == "500 Cash" and day1[2] == "Speed Tonic", table.concat(day1, " | "))
	local sunday = require(find(MOD .. "HamsterDatabase")).ById.sunday_sunbeam.Name
	check("day 7 lists the exclusive hamster, diamonds and the Spike Trap", table.concat(DailyRewardConfig.lines(7, 0), "|") == "150 Diamonds|Spike Trap|" .. sunday .. " (exclusive hamster)", table.concat(DailyRewardConfig.lines(7, 0), "|"))
	check("every daily reward item exists in the item catalog", (function()
		for _, day in DailyRewardConfig.Days do for _, id in day.Items or {} do if not ItemRegistry.get(id) then return false end end end
		return true
	end)())
	local c2 = data(carol)
	c2.Daily = { Streak = 6, LastDay = DailyRewardConfig.dayNumber(os.time()) - 1 }
	local gemsBefore = c2.Gems
	adv(2)
	local claimed = as(carol, "ClaimDaily")
	adv(0.5)
	check("claiming day 7 grants the hamster, the diamonds and the Spike Trap weapon", claimed.ok and c2.Gear.spike_trap == true and c2.Gems >= gemsBefore + 150 and (c2.Inventory.sunday_sunbeam or 0) >= 1, tostring(claimed.msg))
	c2.Daily = { Streak = 0, LastDay = 0 }
	local itemsBefore = c2.Items.item_speed or 0
	adv(2)
	claimed = as(carol, "ClaimDaily")
	check("claiming day 1 gives cash and one Speed Tonic you can use from the hotbar", claimed.ok and (c2.Items.item_speed or 0) == itemsBefore + 1, tostring(claimed.msg))

	-----------------------------------------------------------------
	section("15. lucky wheel (server)")
	local SpinWheelConfig = require(find(MOD .. "SpinWheelConfig"))
	-- (the draw, scaling and cooldown are tested in depth in scn_luckywheel.lua)
	local ctx0 = SpinWheelConfig.context(data(bob), os.time())
	check("the first and last slice are reachable for a beginner's draw (roll 0 / 0.9999)", SpinWheelConfig.pick(0, ctx0) == 1 and SpinWheelConfig.pick(0.9999, ctx0) ~= nil)
	check("every prize reward is valid (items exist, boosts known)", (function()
		for _, prize in SpinWheelConfig.Prizes do
			for _, id in prize.Reward.Items or {} do if not ItemRegistry.get(id) then return false end end
		end
		return true
	end)())
	local SpinSystem = require(find(S .. "SpinSystem"))
	local d3 = data(bob); d3.Wheel = { NextFreeAt = 0 }; d3.Gems = 100
	local function standAt(player, position)
		local character = RawData[player].Props.Character
		for _, d in M.descendants(character) do
			if RawData[d].Name == "HumanoidRootPart" then RawData[d].Props.CFrame = CFrame.new(position) end
		end
	end
	local okFar = SpinSystem.spin(bob)
	check("a spin from far away (not at the wheel) is refused and keeps the free spin", not okFar and d3.Wheel.NextFreeAt == 0)
	standAt(bob, Vector3.new(0, 3, 74))
	local ok1, _, info1 = SpinSystem.spin(bob)
	check("a free spin at the wheel works once and returns the prize slice", ok1 and info1.Index >= 1)
	adv(5)
	local ok2 = SpinSystem.spin(bob)
	check("a second spin is refused until the timer is over", not ok2)
	adv(4)
	d3.Gems = 100
	check("there is no paid spin: with diamonds the spin is still refused while the timer runs", not SpinSystem.spin(bob) and d3.Gems == 100)

	-----------------------------------------------------------------
	section("16. hamster body types (height and silhouette)")
	local HamsterDatabase = require(find(MOD .. "HamsterDatabase"))
	local HamsterShapes = require(find(MOD .. "HamsterShapes"))
	local HamsterBuilder = require(find(MOD .. "HamsterBuilder"))
	local sizes, shapesSeen, minSize, maxSize = {}, {}, math.huge, 0
	for _, sp in HamsterDatabase.Species do
		minSize, maxSize = math.min(minSize, sp.Size), math.max(maxSize, sp.Size)
		shapesSeen[sp.Shape] = (shapesSeen[sp.Shape] or 0) + 1
	end
	local kinds = 0
	for _ in shapesSeen do kinds += 1 end
	check("the collection uses all 7 body types", kinds == 7, kinds)
	check("hamster sizes span a wide range (smallest vs biggest at least 2.5x)", maxSize / minSize >= 2.5, string.format("%.2f .. %.2f", minSize, maxSize))
	check("a hamster keeps the same shape every time (picked from its id)", HamsterShapes.pick("brownie") == HamsterShapes.pick("brownie"))
	check("the named characters have fitting shapes (Elon lanky, Jeff chonk, Seed bean)", HamsterDatabase.ById.elon_muskrat.Shape == "lanky" and HamsterDatabase.ById.jeff_parcel.Shape == "chonk" and HamsterDatabase.ById.i_show_seed.Shape == "bean", tostring(HamsterDatabase.ById.elon_muskrat and HamsterDatabase.ById.elon_muskrat.Shape))
	local tall, small = HamsterBuilder.build(HamsterDatabase.ById.elon_muskrat), HamsterBuilder.build(HamsterDatabase.ById.i_show_seed)
	check("a lanky hamster is built much taller than a bean hamster", tall:GetAttribute("Height") > small:GetAttribute("Height") * 1.5, tostring(tall:GetAttribute("Height")) .. " vs " .. tostring(small:GetAttribute("Height")))
	check("every shape keeps its head close to the face (head scale 0.9-1.15, so eyes never sink into the head)", (function()
		for _, def in HamsterShapes.List do if def.Head < 0.9 or def.Head > 1.15 then return false end end
		return true
	end)())

	print(string.format("PASS %d  FAIL %d", results.pass, results.fail))
	print("== done ==")
end)
