--[[
	CombatSystem: one simple verb - the hit. Bare paws = the SLAP; a held, owned weapon (Content/Items) swaps in its own
	range / arc / cooldown / knockback / stun / drop chance, and a Ranged weapon fires along a validated aim direction.
	The SLAP: Short range, short cooldown, small knockback and a brief stun.
	It exists to protect / steal / recover hamsters, not to be a fighting game:
	  - the server picks the target (nearest player in front of you), the client only says "slap"
	  - it only lands when a fight-able hamster (rolling home, carried, dropped) is near
	  - a hit carrier drops the ball with DropChance; a hit thief loses their steal channel
	  - after being hit you are briefly immune, so nobody can be stun-locked
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HamsterStates = require(ReplicatedStorage.Modules.HamsterStates)

local Remotes = require(ReplicatedStorage.Remotes)

local DataSystem = require(script.Parent.DataSystem)
local AbilitySystem = require(script.Parent.AbilitySystem)
local GearSystem = require(script.Parent.GearSystem)
local HamsterSystem = require(script.Parent.HamsterSystem)
local Notifier = require(script.Parent.Notifier)
local PlayerState = require(script.Parent.PlayerState)
local ReplicationSystem = require(script.Parent.ReplicationSystem)

local CombatSystem = {}

-- Set by TheftSystem (ownerHit): returns true when a rack theft was ended by this hit.
CombatSystem.theftHook = nil :: ((Player, Player) -> boolean)?

local Config = HamsterStates.Config
local CONTEXT_RADIUS = 34

-- cooldowns are per tool (the bat does not delay the Frost Wand, but every tool has its own timer)
local lastSlap: { [Player]: { [string]: number } } = {}
local random = Random.new()

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Melee: the nearest other player inside `range` and in front of you (dot(look, toTarget) >= arc).
local function findTarget(attacker: Player, root: BasePart, range: number, arc: number): (Player?, BasePart?)
	local look = flat(root.CFrame.LookVector)
	if look.Magnitude < 0.01 then
		return nil, nil
	end
	look = look.Unit
	local best: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = range
	for _, other in Players:GetPlayers() do
		if other ~= attacker then
			local _, otherRoot = PlayerState.character(other)
			if otherRoot then
				local delta = flat(otherRoot.Position - root.Position)
				local distance = delta.Magnitude
				if distance <= bestDistance and (distance < 1.5 or delta.Unit:Dot(look) >= arc) then
					best, bestRoot, bestDistance = other, otherRoot, distance
				end
			end
		end
	end
	return best, bestRoot
end

-- Ranged: a straight shot along the (server-validated) aim direction. Hits the first player within `range` whose body
-- is close to the line and not behind a wall. The client only supplies a direction, never a target or a position.
local HIT_RADIUS = 3.2
local function findShotTarget(attacker: Player, root: BasePart, aim: Vector3, range: number): (Player?, BasePart?)
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local best: Player? = nil
	local bestRoot: BasePart? = nil
	local bestAlong = math.huge
	for _, other in Players:GetPlayers() do
		if other ~= attacker then
			local character, otherRoot = nil, nil
			local _, r = PlayerState.character(other)
			otherRoot = r
			character = other.Character
			if otherRoot and character then
				local toTarget = otherRoot.Position - origin
				local along = toTarget:Dot(aim)
				if along > 0 and along <= range and along < bestAlong then
					local off = (toTarget - aim * along).Magnitude
					if off <= HIT_RADIUS then
						local params = RaycastParams.new()
						params.FilterType = Enum.RaycastFilterType.Exclude
						params.FilterDescendantsInstances = { attacker.Character, character }
						params.IgnoreWater = true
						local blocked = workspace:Raycast(origin, aim * along, params)
						if not blocked then
							best, bestRoot, bestAlong = other, otherRoot, along
						end
					end
				end
			end
		end
	end
	return best, bestRoot
end

-- Stats of whatever the player is attacking with right now: an owned, held weapon, or the bare-paw slap.
local function currentAttack(attacker: Player): (any?, any)
	local def = GearSystem.equippedWeapon(attacker)
	if def then
		return def, def.Equip.Weapon
	end
	return nil, {
		Type = "Melee",
		Range = Config.SlapRange,
		Arc = Config.SlapArc,
		Cooldown = Config.SlapCooldown,
		Knockback = Config.KnockbackPower,
		Stun = Config.StunSeconds,
		DropChance = Config.DropChance,
	}
end

local lastNotice: { [Player]: number } = {}

function CombatSystem.attack(attacker: Player, rawAim: any)
	local def, stats = currentAttack(attacker)
	local clock = os.clock()
	local timers = lastSlap[attacker]
	if not timers then
		timers = {}
		lastSlap[attacker] = timers
	end
	local key = if def then def.Id else "paws"
	local remaining = (timers[key] or 0) + stats.Cooldown - clock
	if remaining > 0 then
		-- long cooldowns (abilities) tell the player how long is left, at most once a second
		if stats.Cooldown >= 8 and (lastNotice[attacker] or 0) + 1 < clock then
			lastNotice[attacker] = clock
			Notifier.send(attacker, string.format("%s recharging: %d s", if def then def.DisplayName else "Paws", math.ceil(remaining)), "info")
		end
		return
	end
	local _, root = PlayerState.character(attacker)
	if not root or PlayerState.isStunned(attacker) then
		return
	end

	-- aim: only ranged weapons use it; it must be a real direction (client data is never trusted)
	local aim: Vector3? = nil
	local isAbility = stats.Type == "Freeze" or stats.Type == "Cloak" or stats.Type == "Decoy"
	if stats.Type == "Ranged" or stats.Type == "Freeze" then
		if typeof(rawAim) == "Vector3" and rawAim.Magnitude > 0.5 and rawAim.Magnitude < 1.5 and rawAim.X == rawAim.X and rawAim.Y == rawAim.Y and rawAim.Z == rawAim.Z then
			aim = rawAim.Unit
		else
			aim = root.CFrame.LookVector -- missing / bad aim: shoot where the character looks
		end
	end
	local previousSlap = timers[key]
	timers[key] = clock
	if stats.Type ~= "Cloak" then
		AbilitySystem.reveal(attacker) -- attacking (or using any other tool) ends your cloak
	end

	-- self abilities: no target needed
	if stats.Type == "Cloak" or stats.Type == "Decoy" then
		local ok, message
		if stats.Type == "Cloak" then
			ok, message = AbilitySystem.cloak(attacker, stats.Duration)
		else
			ok, message = AbilitySystem.decoy(attacker, stats.Duration)
		end
		if not ok then
			timers[key] = previousSlap -- nothing happened: no cooldown
			if message then
				Notifier.send(attacker, message, "error")
			end
			return
		end
		Remotes.event("Fx"):FireAllClients("WeaponUse", (def :: any).Id, root.Position, attacker.UserId, root.CFrame.LookVector)
		Notifier.send(attacker, string.format("%s for %d s", if stats.Type == "Cloak" then "You are cloaked" else "Decoy sent", stats.Duration), "success")
		return
	end

	if def then
		local direction = aim or root.CFrame.LookVector
		Remotes.event("Fx"):FireAllClients("WeaponUse", def.Id, root.Position, attacker.UserId, direction)
	else
		Remotes.event("Fx"):FireAllClients("Slap", "", root.Position, attacker.UserId)
	end

	local target, targetRoot
	if aim then
		target, targetRoot = findShotTarget(attacker, root, aim, stats.Range)
	else
		target, targetRoot = findTarget(attacker, root, stats.Range, stats.Arc)
		if not target and AbilitySystem.popDecoyNear(root.Position + flat(root.CFrame.LookVector).Unit * (stats.Range * 0.5), stats.Range * 0.5 + 2, attacker) then
			return -- the swing popped somebody's decoy
		end
	end
	if not target or not targetRoot then
		if stats.Type == "Freeze" then
			timers[key] = clock - stats.Cooldown + 3 -- a miss only costs 3 s, a hit the full cooldown
		end
		return
	end
	local carried = HamsterSystem.carriedBy(target)
	local fight = carried ~= nil
		or HamsterSystem.carriedBy(attacker) ~= nil
		or HamsterSystem.isChanneling(target)
		or HamsterSystem.hamsterNear(targetRoot.Position, CONTEXT_RADIUS)
		or HamsterSystem.hamsterNear(root.Position, CONTEXT_RADIUS)
	if not fight then
		Notifier.send(attacker, "Attacks only work near a hamster that's rolling home, carried or dropped.", "info")
		if isAbility then
			timers[key] = previousSlap
		end
		return
	end
	if PlayerState.isImmune(target) then
		return
	end

	if stats.Type == "Freeze" then
		if AbilitySystem.freeze(attacker, target, stats.Duration) then
			local data = DataSystem.get(attacker)
			if data then
				data.Stats.Slaps = (data.Stats.Slaps or 0) + 1
				ReplicationSystem.mark(attacker, "Stats")
			end
			-- the OWNER freezing a thief carrying their hamster: the thief is stuck, the owner can finish it with a hit
			Notifier.send(attacker, "Frozen!", "success")
		else
			timers[key] = clock - stats.Cooldown + 3
		end
		return
	end
	AbilitySystem.reveal(target) -- a hit reveals a cloaked player

	local direction = flat(targetRoot.Position - root.Position)
	direction = if direction.Magnitude > 0.1 then direction.Unit else flat(root.CFrame.LookVector).Unit

	PlayerState.stun(target, stats.Stun, Config.StunImmunitySeconds)
	HamsterSystem.interrupt(target)
	Remotes.event("Knockback"):FireClient(target, direction * stats.Knockback + Vector3.new(0, 18, 0))
	Remotes.event("Fx"):FireAllClients("Hit", "", targetRoot.Position, target.UserId)

	local data = DataSystem.get(attacker)
	if data then
		data.Stats.Slaps = (data.Stats.Slaps or 0) + 1
		ReplicationSystem.mark(attacker, "Stats")
	end
	-- the OWNER of a hamster that is being carried off hits the thief: the theft fails for sure (server decides)
	local theft = carried and carried.Theft
	if theft and theft.Owner == attacker and CombatSystem.theftHook then
		if CombatSystem.theftHook(attacker, target) then
			Notifier.send(attacker, "You stopped the theft!", "success")
		end
	elseif carried and random:NextNumber() < stats.DropChance then
		HamsterSystem.dropCarried(target, "Slap", Config.DropBanSeconds)
		Notifier.send(attacker, "You knocked the hamster loose!", "success")
	end
	Notifier.send(target, string.format("%s hit you!", attacker.DisplayName), "error")
end

-- kept for callers / tests that mean "bare-paw or held weapon, no aim"
function CombatSystem.slap(attacker: Player)
	CombatSystem.attack(attacker, nil)
end

function CombatSystem.start()
	Remotes.event("Attack").OnServerEvent:Connect(function(player, aim)
		CombatSystem.attack(player, aim)
	end)
end

function CombatSystem.forget(player: Player)
	lastSlap[player] = nil
	lastNotice[player] = nil
end

return CombatSystem
