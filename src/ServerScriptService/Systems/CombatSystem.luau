--[[
	CombatSystem: every attack in the game, decided by the SERVER.

	The client only says "I swing" (plus an aim direction for ranged weapons). Everything else is the server's call:
	which weapon you hold (GearSystem, ownership checked), the cooldown, who is hit and what the hit does.

	A swing has a lifecycle (CombatTiming):
	  request   cooldown / stun / alive checked, the swing is registered, every client is told to play the animation
	  WindUp    nothing can be hit
	  Active    the server samples the hit area EVERY frame (Heartbeat). A target is hit when its position in that frame - or
	            anywhere on the path it moved since the previous frame (a sweep) - is inside the weapon's reach, in front of
	            the attacker, at a similar height, with nothing solid in between. So running targets are hit too.
	  Recovery  nothing can be hit; the next swing needs the weapon's Cooldown (counted from the start of the swing)
	Each swing keeps a list of who it hit, so one swing can never hit the same player twice (and by default hits one player).

	What a hit does (applyHit): stun + knockback (both capped by GameConfig > Combat), a short hit-immunity so nobody can be
	stun-locked or stacked into orbit, and the theft rules: the OWNER of a hamster that is being carried off hits the thief ->
	TheftSystem decides (theftHook); a hit carrier drops the ball with the weapon's DropChance. A hit on a player who carries
	nothing works exactly the same (stun + knockback), anywhere outside safe zones.

	Not hittable: yourself, dead characters, players with spawn protection / hit immunity, anyone inside a part tagged "SafeZone"
	(and you cannot attack from inside one). GameConfig > Combat > PvpNeedsHamsterNearby = true brings back the old rule
	"only near a hamster that is rolling, carried or dropped".
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local CombatTiming = require(ReplicatedStorage.Modules.CombatTiming)
local HamsterStates = require(ReplicatedStorage.Modules.HamsterStates)
local GameConfig = require(ReplicatedStorage.Modules.GameConfig)

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
-- Set by TrapSystem: places a trap for the attacker (ok, message) and counts the traps they have out.
CombatSystem.trapPlacer = nil :: ((Player, any, any) -> (boolean, string?))?
CombatSystem.trapCount = nil :: ((Player) -> number)?

local CONTEXT_RADIUS = 34
local MAX_HEIGHT_DIFFERENCE = 6
local SHOT_RADIUS = 3.2
local DEFAULT_LIFT = 14
local SAFE_TAG = "SafeZone"

local function cfg(key: string): any
	return GameConfig.get("Combat", key)
end

type Swing = {
	Attacker: Player,
	Def: any?, -- the item definition, nil for bare paws
	Stats: any,
	Key: string,
	Aim: Vector3?,
	StartedAt: number,
	ActiveFrom: number,
	ActiveUntil: number,
	Sampled: boolean,
	Hit: { [Player]: boolean },
	HitCount: number,
	LastPosition: { [Player]: Vector3 },
	LastTime: { [Player]: number },
	PoppedDecoy: boolean,
}

-- cooldowns are per tool (the bat does not delay the Frost Wand, but every tool has its own timer)
local lastSwing: { [Player]: { [string]: number } } = {}
local lastNotice: { [Player]: number } = {}
local swings: { [Player]: Swing } = {}
local random = Random.new()

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

---------------------------------------------------------------------------
-- eligibility
---------------------------------------------------------------------------

local function insidePart(part: BasePart, position: Vector3): boolean
	local local_ = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(local_.X) <= half.X and math.abs(local_.Y) <= half.Y + 6 and math.abs(local_.Z) <= half.Z
end

-- Is this position inside a safe zone (a part tagged "SafeZone" in Studio)?
function CombatSystem.inSafeZone(position: Vector3): boolean
	for _, instance in CollectionService:GetTagged(SAFE_TAG) do
		if instance:IsA("BasePart") and insidePart(instance, position) then
			return true
		end
	end
	return false
end

-- Can this player be hit right now? (alive, no spawn protection / hit immunity, not in a safe zone)
function CombatSystem.canBeHit(target: Player): (boolean, BasePart?)
	local _, root = PlayerState.character(target)
	if not root then
		return false, nil
	end
	if PlayerState.isImmune(target) or CombatSystem.inSafeZone(root.Position) then
		return false, root
	end
	return true, root
end

local function hamsterFight(attackerRoot: BasePart, attacker: Player, target: Player, targetRoot: BasePart): boolean
	return HamsterSystem.carriedBy(target) ~= nil
		or HamsterSystem.carriedBy(attacker) ~= nil
		or HamsterSystem.isChanneling(target)
		or HamsterSystem.hamsterNear(targetRoot.Position, CONTEXT_RADIUS)
		or HamsterSystem.hamsterNear(attackerRoot.Position, CONTEXT_RADIUS)
end

local function hamsterFightNeeded(swing: Swing, attackerRoot: BasePart, target: Player, targetRoot: BasePart): boolean
	if not cfg("PvpNeedsHamsterNearby") then
		return true
	end
	return hamsterFight(attackerRoot, swing.Attacker, target, targetRoot)
end

-- Nothing solid between two points? (characters excluded)
local function clearLine(from: Vector3, to: Vector3, ignore: { Instance }): boolean
	if not cfg("WallCheck") then
		return true
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	params.RespectCanCollide = true
	return workspace:Raycast(from, to - from, params) == nil
end

---------------------------------------------------------------------------
-- hit detection
---------------------------------------------------------------------------

-- Closest point to `p` on the segment a-b.
local function closestOnSegment(a: Vector3, b: Vector3, p: Vector3): Vector3
	local ab = b - a
	local lengthSquared = ab:Dot(ab)
	if lengthSquared < 1e-6 then
		return a
	end
	local t = math.clamp((p - a):Dot(ab) / lengthSquared, 0, 1)
	return a + ab * t
end

-- Melee: one sample of the hit area. Players are tested at their current position AND along the path they moved since the
-- last sample, so a fast runner cannot slip through between two frames.
local function sampleMelee(swing: Swing, root: BasePart)
	local stats = swing.Stats
	local look = flat(root.CFrame.LookVector)
	if look.Magnitude < 0.01 then
		return
	end
	look = look.Unit
	local grace = cfg("LatencyGrace")
	local candidates: { { Player: Player, Root: BasePart, Distance: number } } = {}
	for _, other in Players:GetPlayers() do
		if other ~= swing.Attacker and not swing.Hit[other] then
			local ok, otherRoot = CombatSystem.canBeHit(other)
			if ok and otherRoot then
				local current = otherRoot.Position
				local previous = swing.LastPosition[other] or current
				local clock = os.clock()
				local elapsed = clock - (swing.LastTime[other] or clock)
				swing.LastPosition[other] = current
				swing.LastTime[other] = clock
				local nearest = closestOnSegment(previous, current, root.Position)
				local speed = math.max(otherRoot.AssemblyLinearVelocity.Magnitude, if elapsed > 0 then (current - previous).Magnitude / elapsed else 0)
				-- lag forgiveness grows with how fast the target moves: a standing target gets none, a sprinting one the full grace
				local reach = stats.Range + grace * math.clamp(speed / 16, 0, 1)
				local delta = flat(nearest - root.Position)
				local distance = delta.Magnitude
				if
					distance <= reach
					and math.abs(nearest.Y - root.Position.Y) <= MAX_HEIGHT_DIFFERENCE
					and (distance < 1.5 or delta.Unit:Dot(look) >= stats.Arc)
				then
					local character = other.Character
					local attackerCharacter = swing.Attacker.Character
					if character and attackerCharacter and clearLine(root.Position + Vector3.new(0, 1, 0), nearest + Vector3.new(0, 1, 0), { attackerCharacter, character }) then
						table.insert(candidates, { Player = other, Root = otherRoot, Distance = distance })
					end
				end
			end
		end
	end
	table.sort(candidates, function(a, b)
		return a.Distance < b.Distance
	end)
	for _, candidate in candidates do
		if swing.HitCount >= cfg("MaxTargetsPerSwing") then
			break
		end
		swing.Hit[candidate.Player] = true -- decided for this swing, hit or not
		if hamsterFightNeeded(swing, root, candidate.Player, candidate.Root) then
			swing.HitCount += 1
			CombatSystem.applyHit(swing.Attacker, candidate.Player, candidate.Root, swing.Def, swing.Stats)
		end
	end
	if swing.HitCount == 0 and not swing.PoppedDecoy then
		-- the swing may pop somebody's decoy instead
		local centre = root.Position + look * (stats.Range * 0.5)
		if AbilitySystem.popDecoyNear(centre, stats.Range * 0.5 + 2, swing.Attacker) then
			swing.PoppedDecoy = true
		end
	end
end

-- Ranged / Freeze: a straight shot along the (server-validated) aim direction. Hits the first player within `range` whose body
-- is close to the line and not behind a wall. The client only supplies a direction, never a target or a position.
local function findShotTarget(attacker: Player, root: BasePart, aim: Vector3, range: number): (Player?, BasePart?)
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local best: Player? = nil
	local bestRoot: BasePart? = nil
	local bestAlong = math.huge
	for _, other in Players:GetPlayers() do
		if other ~= attacker then
			local ok, otherRoot = CombatSystem.canBeHit(other)
			local character = other.Character
			if ok and otherRoot and character then
				local toTarget = otherRoot.Position - origin
				local along = toTarget:Dot(aim)
				if along > 0 and along <= range and along < bestAlong then
					local off = (toTarget - aim * along).Magnitude
					if off <= SHOT_RADIUS and clearLine(origin, origin + aim * along, { attacker.Character or character, character }) then
						best, bestRoot, bestAlong = other, otherRoot, along
					end
				end
			end
		end
	end
	return best, bestRoot
end

---------------------------------------------------------------------------
-- what a hit does
---------------------------------------------------------------------------

local function countSlap(attacker: Player)
	local data = DataSystem.get(attacker)
	if data then
		data.Stats.Slaps = (data.Stats.Slaps or 0) + 1
		ReplicationSystem.mark(attacker, "Stats")
	end
end

-- The one place a connected hit is resolved. Safe to call from tests / other systems; it re-checks eligibility.
function CombatSystem.applyHit(attacker: Player, target: Player, targetRoot: BasePart, def: any?, stats: any)
	if attacker == target or not CombatSystem.canBeHit(target) then
		return
	end
	local _, root = PlayerState.character(attacker)
	if not root then
		return
	end
	AbilitySystem.reveal(target) -- a hit reveals a cloaked player

	local direction = flat(targetRoot.Position - root.Position)
	direction = if direction.Magnitude > 0.1 then direction.Unit else flat(root.CFrame.LookVector).Unit

	local carried = HamsterSystem.carriedBy(target)
	local guarded = AbilitySystem.isGuarding(target) and GameConfig.get("Abilities", "GuardImmunityFromKnockback")
	local hitImmunity = cfg("HitImmunitySeconds")
	if guarded then
		-- a raised shield soaks the shove: no stun, no knockback (theft and drop rules below still apply)
		PlayerState.grantImmunity(target, hitImmunity)
		Remotes.event("Fx"):FireAllClients("Block", "", targetRoot.Position, target.UserId)
	else
		local stun = math.min(stats.Stun or 0, cfg("MaxStunSeconds"))
		PlayerState.stun(target, stun, hitImmunity)
		local power = math.min(stats.Knockback or 0, cfg("MaxKnockback"))
		local lift = math.min(stats.Lift or DEFAULT_LIFT, cfg("MaxKnockbackLift"))
		Remotes.event("Knockback"):FireClient(target, direction * power + Vector3.new(0, lift, 0))
		Remotes.event("Fx"):FireAllClients("Hit", if def then def.Id else "", targetRoot.Position, target.UserId, direction)
	end
	HamsterSystem.interrupt(target)
	countSlap(attacker)

	-- the OWNER of a hamster that is being carried off hits the thief: the theft fails for sure (server decides)
	local theft = carried and carried.Theft
	if theft and theft.Owner == attacker and CombatSystem.theftHook then
		if CombatSystem.theftHook(attacker, target) then
			Notifier.send(attacker, "You stopped the theft!", "success")
		end
	elseif carried and random:NextNumber() < (stats.DropChance or 0) then
		HamsterSystem.dropCarried(target, "Slap", HamsterStates.Config.DropBanSeconds)
		Notifier.send(attacker, "You knocked the hamster loose!", "success")
	end
	Notifier.send(target, string.format("%s hit you!", attacker.DisplayName), "error")
end

---------------------------------------------------------------------------
-- the swing
---------------------------------------------------------------------------

-- Stats of whatever the player is attacking with right now: an owned, held weapon, or the bare-paw slap.
local function currentAttack(attacker: Player): (any?, any)
	local def = GearSystem.equippedWeapon(attacker)
	if def then
		return def, def.Equip.Weapon
	end
	return nil, {
		Type = "Melee",
		Range = cfg("PawRange"),
		Arc = cfg("PawArc"),
		Cooldown = cfg("PawCooldown"),
		Knockback = cfg("PawKnockback"),
		Stun = cfg("PawStun"),
		DropChance = cfg("PawDropChance"),
	}
end

local function validAim(raw: any): Vector3?
	if typeof(raw) == "Vector3" and raw.Magnitude > 0.5 and raw.Magnitude < 1.5 and raw.X == raw.X and raw.Y == raw.Y and raw.Z == raw.Z then
		return raw.Unit
	end
	return nil
end

local function finish(swing: Swing)
	if swings[swing.Attacker] == swing then
		swings[swing.Attacker] = nil
	end
end

-- Ranged / Freeze at the moment of release.
local function release(swing: Swing, root: BasePart)
	local stats = swing.Stats
	local aim = swing.Aim or root.CFrame.LookVector
	local target, targetRoot = findShotTarget(swing.Attacker, root, aim, stats.Range)
	if not target or not targetRoot then
		if stats.Type == "Freeze" then
			CombatSystem.refund(swing.Attacker, swing.Key, stats.Cooldown, 3) -- a miss only costs 3 s, a hit the full cooldown
		end
		return
	end
	if not hamsterFightNeeded(swing, root, target, targetRoot) then
		return
	end
	swing.Hit[target] = true
	swing.HitCount += 1
	if stats.Type == "Freeze" then
		local seconds = math.min(stats.Duration, GameConfig.get("Abilities", "FreezeMaxSeconds"))
		if AbilitySystem.freeze(swing.Attacker, target, seconds) then
			countSlap(swing.Attacker)
			Notifier.send(swing.Attacker, "Frozen!", "success")
		else
			CombatSystem.refund(swing.Attacker, swing.Key, stats.Cooldown, 3)
		end
		return
	end
	CombatSystem.applyHit(swing.Attacker, target, targetRoot, swing.Def, stats)
end

-- Gives (part of) a cooldown back, e.g. a missed Freeze only costs `keep` seconds.
function CombatSystem.refund(attacker: Player, key: string, cooldown: number, keep: number)
	local timers = lastSwing[attacker]
	if timers then
		timers[key] = os.clock() - cooldown + keep
	end
end

local function step()
	local clock = os.clock()
	for attacker, swing in swings do
		local _, root = PlayerState.character(attacker)
		local def = GearSystem.equippedWeapon(attacker)
		if not root or PlayerState.isStunned(attacker) or (swing.Def ~= nil and def ~= swing.Def) or (swing.Def == nil and def ~= nil) then
			finish(swing) -- died, got stunned or put the weapon away mid-swing: the swing is cancelled
		elseif clock >= swing.ActiveFrom then
			local last = clock >= swing.ActiveUntil
			if swing.Stats.Type == "Melee" then
				sampleMelee(swing, root) -- every frame of the active window, plus one final sample at its end
				swing.Sampled = true
			elseif not swing.Sampled then
				swing.Sampled = true
				release(swing, root)
			end
			if last then
				finish(swing)
			end
		end
	end
end

function CombatSystem.attack(attacker: Player, rawAim: any)
	local def, stats = currentAttack(attacker)
	local clock = os.clock()
	local timers = lastSwing[attacker]
	if not timers then
		timers = {}
		lastSwing[attacker] = timers
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
	if not root or PlayerState.isStunned(attacker) or swings[attacker] then
		return
	end
	if CombatSystem.inSafeZone(root.Position) then
		Notifier.send(attacker, "You can't attack in a safe zone.", "info")
		return
	end

	local aim: Vector3? = nil
	if stats.Type == "Ranged" or stats.Type == "Freeze" then
		aim = validAim(rawAim) or root.CFrame.LookVector -- missing / bad aim: shoot where the character looks
	end
	local previous = timers[key]
	timers[key] = clock
	if stats.Type ~= "Cloak" then
		AbilitySystem.reveal(attacker) -- attacking (or using any other tool) ends your cloak
	end

	-- self abilities: no target needed, they happen right away
	if stats.Type == "Cloak" or stats.Type == "Decoy" or stats.Type == "Guard" or stats.Type == "Trap" then
		local ok, message
		if stats.Type == "Cloak" then
			ok, message = AbilitySystem.cloak(attacker, stats.Duration)
		elseif stats.Type == "Trap" then
			if CombatSystem.trapPlacer then
				ok, message = CombatSystem.trapPlacer(attacker, def, stats)
			else
				ok, message = false, "Traps are not available"
			end
		elseif stats.Type == "Decoy" then
			ok, message = AbilitySystem.decoy(attacker, stats.Duration)
		else
			ok, message = AbilitySystem.guard(attacker, stats.Duration)
		end
		if not ok then
			timers[key] = previous -- nothing happened: no cooldown
			if message then
				Notifier.send(attacker, message, "error")
			end
			return
		end
		Remotes.event("Fx"):FireAllClients("WeaponUse", (def :: any).Id, root.Position, attacker.UserId, root.CFrame.LookVector)
		if stats.Type == "Trap" then
			Notifier.send(attacker, string.format("%s set (%d of %d)", (def :: any).DisplayName, if CombatSystem.trapCount then CombatSystem.trapCount(attacker) else 0, stats.MaxActive), "success")
			return
		end
		local verb = if stats.Type == "Cloak" then "You are cloaked" elseif stats.Type == "Guard" then "Shield up" else "Decoy sent"
		Notifier.send(attacker, string.format("%s for %d s", verb, stats.Duration), "success")
		return
	end

	local windUp, active = CombatTiming.of(stats)
	local swing: Swing = {
		Attacker = attacker,
		Def = def,
		Stats = stats,
		Key = key,
		Aim = aim,
		StartedAt = clock,
		ActiveFrom = clock + windUp,
		ActiveUntil = clock + windUp + active,
		Sampled = false,
		Hit = {},
		HitCount = 0,
		LastPosition = {},
		LastTime = {},
		PoppedDecoy = false,
	}
	swings[attacker] = swing
	-- every client plays the swing animation / sound in sync with the server's phases
	local direction = aim or root.CFrame.LookVector
	Remotes.event("Fx"):FireAllClients("Swing", if def then def.Id else "", root.Position, attacker.UserId, direction)
end

-- kept for callers / tests that mean "bare-paw or held weapon, no aim"
function CombatSystem.slap(attacker: Player)
	CombatSystem.attack(attacker, nil)
end

function CombatSystem.isSwinging(player: Player): boolean
	return swings[player] ~= nil
end

function CombatSystem.start()
	Remotes.event("Attack").OnServerEvent:Connect(function(player, aim)
		CombatSystem.attack(player, aim)
	end)
	RunService.Heartbeat:Connect(step)

	-- a fresh character: no leftover stun / freeze, a few seconds of spawn protection, no half-finished swing
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			swings[player] = nil
			PlayerState.clear(player)
			local seconds = cfg("SpawnProtectionSeconds")
			if seconds > 0 then
				PlayerState.grantImmunity(player, seconds)
			end
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
end

function CombatSystem.forget(player: Player)
	lastSwing[player] = nil
	lastNotice[player] = nil
	swings[player] = nil
end

return CombatSystem
