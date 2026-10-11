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

local lastSlap: { [Player]: number } = {}
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

function CombatSystem.attack(attacker: Player, rawAim: any)
	local def, stats = currentAttack(attacker)
	local clock = os.clock()
	if (lastSlap[attacker] or 0) + stats.Cooldown > clock then
		return
	end
	local _, root = PlayerState.character(attacker)
	if not root or PlayerState.isStunned(attacker) then
		return
	end

	-- aim: only ranged weapons use it; it must be a real direction (client data is never trusted)
	local aim: Vector3? = nil
	if stats.Type == "Ranged" then
		if typeof(rawAim) == "Vector3" and rawAim.Magnitude > 0.5 and rawAim.Magnitude < 1.5 and rawAim.X == rawAim.X and rawAim.Y == rawAim.Y and rawAim.Z == rawAim.Z then
			aim = rawAim.Unit
		else
			aim = root.CFrame.LookVector -- missing / bad aim: shoot where the character looks
		end
	end
	lastSlap[attacker] = clock

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
	end
	if not target or not targetRoot then
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
		return
	end
	if PlayerState.isImmune(target) then
		return
	end

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
end

return CombatSystem
