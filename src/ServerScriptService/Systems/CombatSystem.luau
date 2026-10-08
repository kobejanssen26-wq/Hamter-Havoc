--[[
	CombatSystem: one simple verb - the SLAP. Short range, short cooldown, small knockback and a brief stun.
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
local HamsterSystem = require(script.Parent.HamsterSystem)
local Notifier = require(script.Parent.Notifier)
local PlayerState = require(script.Parent.PlayerState)
local ReplicationSystem = require(script.Parent.ReplicationSystem)

local CombatSystem = {}

local Config = HamsterStates.Config
local CONTEXT_RADIUS = 34

local lastSlap: { [Player]: number } = {}
local random = Random.new()

local function findTarget(attacker: Player, root: BasePart): (Player?, BasePart?)
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	if look.Magnitude < 0.01 then
		return nil, nil
	end
	look = look.Unit
	local best: Player? = nil
	local bestRoot: BasePart? = nil
	local bestDistance = Config.SlapRange
	for _, other in Players:GetPlayers() do
		if other ~= attacker then
			local _, otherRoot = PlayerState.character(other)
			if otherRoot then
				local delta = Vector3.new(otherRoot.Position.X - root.Position.X, 0, otherRoot.Position.Z - root.Position.Z)
				local distance = delta.Magnitude
				if distance <= bestDistance and (distance < 1.5 or delta.Unit:Dot(look) >= Config.SlapArc) then
					best, bestRoot, bestDistance = other, otherRoot, distance
				end
			end
		end
	end
	return best, bestRoot
end

function CombatSystem.slap(attacker: Player)
	local clock = os.clock()
	if (lastSlap[attacker] or 0) + Config.SlapCooldown > clock then
		return
	end
	local _, root = PlayerState.character(attacker)
	if not root or PlayerState.isStunned(attacker) then
		return
	end
	lastSlap[attacker] = clock
	Remotes.event("Fx"):FireAllClients("Slap", "", root.Position, attacker.UserId)

	local target, targetRoot = findTarget(attacker, root)
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
		Notifier.send(attacker, "Slaps only work near a hamster that's rolling home, carried or dropped.", "info")
		return
	end
	if PlayerState.isImmune(target) then
		return
	end

	local direction = Vector3.new(targetRoot.Position.X - root.Position.X, 0, targetRoot.Position.Z - root.Position.Z)
	direction = if direction.Magnitude > 0.1 then direction.Unit else Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit

	PlayerState.stun(target, Config.StunSeconds, Config.StunImmunitySeconds)
	HamsterSystem.interrupt(target)
	Remotes.event("Knockback"):FireClient(target, direction * Config.KnockbackPower + Vector3.new(0, 18, 0))
	Remotes.event("Fx"):FireAllClients("Hit", "", targetRoot.Position, target.UserId)

	local data = DataSystem.get(attacker)
	if data then
		data.Stats.Slaps = (data.Stats.Slaps or 0) + 1
		ReplicationSystem.mark(attacker, "Stats")
	end
	if carried and random:NextNumber() < Config.DropChance then
		HamsterSystem.dropCarried(target, "Slap", Config.DropBanSeconds)
		Notifier.send(attacker, "You knocked the hamster loose!", "success")
	end
	Notifier.send(target, string.format("%s slapped you!", attacker.DisplayName), "error")
end

function CombatSystem.start()
	Remotes.event("Attack").OnServerEvent:Connect(function(player)
		CombatSystem.slap(player)
	end)
end

function CombatSystem.forget(player: Player)
	lastSlap[player] = nil
end

return CombatSystem
