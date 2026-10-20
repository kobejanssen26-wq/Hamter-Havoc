--[[
	ActionAnimator: draws the character actions of Modules/ActionCatalog (pick up / place a hamster, buy, open or claim a reward,
	equip an item, celebrate ...) for any player, when the server announces them (Fx "Action").

	  1. The entry names a published animation (Animation = a name in Modules/Content/Animations) that has an AssetId
	     -> AnimationController plays it (Action priority, never fighting walking / jumping).
	  2. Otherwise the built-in procedural Pose moves the R15 shoulder / neck joints and puts them back (restoring the
	     exact original joint offsets, even when two actions overlap). R6 characters only get the sound.

	Purely cosmetic and safe: unknown ids, missing joints or a character that left are silently ignored.
	Weapon swings (Slap) are WeaponAnimator's job; the catalog lists them so the documentation is complete.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local ActionCatalog = require(Modules:WaitForChild("ActionCatalog"))
local AnimationRegistry = require(Modules:WaitForChild("AnimationRegistry"))

local AnimationController = require(script.Parent.AnimationController)
local AudioController = require(script.Parent.AudioController)

local ActionAnimator = {}

local function deg(x: number): CFrame
	return CFrame.Angles(math.rad(x), 0, 0)
end

-- Keyframes: { At = fraction of the Duration, Joints = { RightShoulder = offset, LeftShoulder = offset, Neck = offset } } (offsets are added to the resting joint,
-- +X on a shoulder lifts the arm forward / up, -X on the neck nods). The pose always returns to rest after the last key.
ActionAnimator.Poses = {
	ReachDown = { { At = 0.4, Joints = { RightShoulder = deg(55), LeftShoulder = deg(55), Neck = deg(-18) } }, { At = 0.7, Joints = { RightShoulder = deg(55), LeftShoulder = deg(55), Neck = deg(-18) } } },
	PresentForward = { { At = 0.35, Joints = { RightShoulder = deg(85), LeftShoulder = deg(85), Neck = deg(-8) } }, { At = 0.7, Joints = { RightShoulder = deg(85), LeftShoulder = deg(85), Neck = deg(-8) } } },
	Nod = { { At = 0.35, Joints = { Neck = deg(-24) } }, { At = 0.65, Joints = { Neck = deg(6) } } },
	ArmsUp = { { At = 0.4, Joints = { RightShoulder = deg(165), LeftShoulder = deg(165), Neck = deg(10) } }, { At = 0.75, Joints = { RightShoulder = deg(165), LeftShoulder = deg(165), Neck = deg(10) } } },
	Raise = { { At = 0.4, Joints = { RightShoulder = deg(150), Neck = deg(8) } }, { At = 0.7, Joints = { RightShoulder = deg(150), Neck = deg(8) } } },
	Swing = { { At = 0.35, Joints = { RightShoulder = deg(-50) } }, { At = 0.65, Joints = { RightShoulder = deg(95) } } },
}

local active: { [Motor6D]: { Tweens: { Tween }, Token: number } } = {}
local tokenCounter = 0

local function findJoint(character: Model, name: string): Motor6D?
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") and string.gsub(descendant.Name, " ", "") == name then
			return descendant
		end
	end
	return nil
end

-- The resting offset of a joint is remembered once (as an attribute), so overlapping actions never take a half-moved pose as "rest".
local function restOf(motor: Motor6D): CFrame
	local stored = motor:GetAttribute("ActionRestC0")
	if typeof(stored) == "CFrame" then
		return stored
	end
	motor:SetAttribute("ActionRestC0", motor.C0)
	return motor.C0
end

local function release(motor: Motor6D, token: number)
	local entry = active[motor]
	if entry and entry.Token == token then
		active[motor] = nil
		if motor.Parent then
			motor.C0 = restOf(motor)
		end
	end
end

local function playPose(character: Model, poseName: string, duration: number): boolean
	local keys = ActionAnimator.Poses[poseName]
	if not keys then
		return false
	end
	if character:FindFirstChild("UpperTorso") == nil then
		return false -- R6 or something else: no procedural pose
	end
	local moved = false
	tokenCounter += 1
	local token = tokenCounter
	local joints: { [string]: Motor6D } = {}
	for _, key in keys do
		for jointName in key.Joints do
			if not joints[jointName] then
				local motor = findJoint(character, jointName)
				if motor then
					joints[jointName] = motor
				end
			end
		end
	end
	for _, motor in joints do
		local previous = active[motor]
		if previous then
			for _, t in previous.Tweens do
				t:Cancel()
			end
			motor.C0 = restOf(motor)
		end
		active[motor] = { Tweens = {}, Token = token }
		moved = true
	end
	if not moved then
		return false
	end
	local previousAt = 0
	for _, key in keys do
		local startAt, length = previousAt * duration, math.max((key.At - previousAt) * duration, 0.05)
		previousAt = key.At
		task.delay(startAt, function()
			for jointName, offset in key.Joints do
				local motor = joints[jointName]
				local entry = motor and active[motor]
				if motor and entry and entry.Token == token and motor.Parent then
					local t = TweenService:Create(motor, TweenInfo.new(length, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = restOf(motor) * offset })
					table.insert(entry.Tweens, t)
					t:Play()
				end
			end
		end)
	end
	-- back to rest
	task.delay(previousAt * duration, function()
		for _, motor in joints do
			local entry = active[motor]
			if entry and entry.Token == token and motor.Parent then
				local t = TweenService:Create(motor, TweenInfo.new(math.max(duration * 0.3, 0.1), Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = restOf(motor) })
				table.insert(entry.Tweens, t)
				t:Play()
			end
		end
	end)
	task.delay(previousAt * duration + duration * 0.3 + 0.1, function()
		for _, motor in joints do
			release(motor, token)
		end
	end)
	return true
end

-- Plays catalog action `actionId` on `player`'s character. Returns true when something visible was started.
function ActionAnimator.play(player: Player, actionId: string, position: Vector3?): boolean
	local entry = ActionCatalog.ById[actionId]
	local character = player.Character
	if not entry or not character then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if entry.Sound then
		-- (a sound problem must never stop the movement)
		pcall(AudioController.play, entry.Sound, { Position = position or (root and (root :: BasePart).Position), Volume = 0.7 })
	end
	if actionId == "Slap" then
		return false -- (WeaponAnimator draws weapon swings)
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if entry.Animation and humanoid and AnimationRegistry.playable(entry.Animation) then
		local track = AnimationController.play(humanoid, entry.Animation, { Priority = Enum.AnimationPriority[entry.Priority] or Enum.AnimationPriority.Action, Looped = false })
		if track then
			return true
		end
	end
	return playPose(character, entry.Pose, entry.Duration)
end

function ActionAnimator.playForUserId(userId: any, actionId: any, position: Vector3?)
	local player = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	if player and type(actionId) == "string" then
		ActionAnimator.play(player, actionId, position)
	end
end

return ActionAnimator
