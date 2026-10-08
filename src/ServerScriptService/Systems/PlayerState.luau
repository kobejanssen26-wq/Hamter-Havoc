--[[
	PlayerState: short-lived per-player combat/carry state that changes how a player moves.
	  - stun:   knocked down by a slap or a security zap (no walking for a moment)
	  - carry:  holding a hamster ball slows you down a little (rarer = heavier)
	WalkSpeed is always recomputed from the profile (upgrades, boosts) times these factors.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyMath = require(ReplicatedStorage.Modules.EconomyMath)

local DataSystem = require(script.Parent.DataSystem)

local PlayerState = {}

local stunnedUntil: { [Player]: number } = {}
local immuneUntil: { [Player]: number } = {}
local carryFactor: { [Player]: number? } = {}

-- Humanoid + root of a living character, or nil.
function PlayerState.character(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

function PlayerState.isStunned(player: Player): boolean
	return (stunnedUntil[player] or 0) > os.clock()
end

function PlayerState.isImmune(player: Player): boolean
	return (immuneUntil[player] or 0) > os.clock()
end

-- Sets WalkSpeed from the profile, stun and carry state.
function PlayerState.apply(player: Player)
	local humanoid = PlayerState.character(player)
	if not humanoid then
		return
	end
	local data = DataSystem.get(player)
	local speed = if data then EconomyMath.walkSpeed(data, os.time()) else EconomyMath.BaseWalkSpeed
	if PlayerState.isStunned(player) then
		humanoid.WalkSpeed = 0
		humanoid.PlatformStand = true
		return
	end
	humanoid.PlatformStand = false
	humanoid.WalkSpeed = speed * (carryFactor[player] or 1)
end

function PlayerState.stun(player: Player, seconds: number, immunity: number?)
	local until_ = os.clock() + seconds
	stunnedUntil[player] = math.max(stunnedUntil[player] or 0, until_)
	immuneUntil[player] = os.clock() + seconds + (immunity or 0)
	PlayerState.apply(player)
	task.delay(seconds + 0.05, function()
		if player.Parent == Players and not PlayerState.isStunned(player) then
			PlayerState.apply(player)
		end
	end)
end

function PlayerState.setCarry(player: Player, factor: number?)
	carryFactor[player] = factor
	PlayerState.apply(player)
end

function PlayerState.forget(player: Player)
	stunnedUntil[player] = nil
	immuneUntil[player] = nil
	carryFactor[player] = nil
end

return PlayerState
