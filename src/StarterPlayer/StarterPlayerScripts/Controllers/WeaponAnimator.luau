--[[
	WeaponAnimator: plays the attack animation of any weapon on any player's character, in step with the server's phases
	(CombatTiming: WindUp -> Active -> Recovery). One framework for every weapon:

	  1. The item's Weapon.Animation (a Name from Content/Animations) has an AssetId  -> that published animation is played
	     (Action priority, so it does not fight running / jumping; speed is scaled so it ends with the cooldown).
	  2. No animation yet (or it failed to load - AnimationController warns once)     -> a built-in procedural swing moves the
	     Tool's grip through wind-up, strike and recovery, so a new weapon is never frozen in the hand.

	Purely cosmetic: whether anything is hit is decided by the server (CombatSystem). Every client runs this for every swing the
	server announces (Fx "Swing"), so other players see the animation too.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local AnimationRegistry = require(Modules:WaitForChild("AnimationRegistry"))
local CombatTiming = require(Modules:WaitForChild("CombatTiming"))
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local ItemRegistry = require(Modules:WaitForChild("ItemRegistry"))

local AnimationController = require(script.Parent.AnimationController)
local AudioController = require(script.Parent.AudioController)

local WeaponAnimator = {}

local running: { [Instance]: { Tweens: { Tween }, Reset: () -> () } } = {}

-- Swing shapes (Weapon.Look.Swing): how the grip travels. Angles in degrees, relative to the resting grip.
local SHAPES = {
	Overhead = { Back = CFrame.Angles(math.rad(-75), 0, 0) * CFrame.new(0, 0.2, 0.3), Strike = CFrame.Angles(math.rad(85), 0, 0) * CFrame.new(0, -0.1, -0.6) },
	Side = { Back = CFrame.Angles(0, math.rad(70), math.rad(-20)) * CFrame.new(0.4, 0, 0.2), Strike = CFrame.Angles(0, math.rad(-80), math.rad(10)) * CFrame.new(-0.5, 0, -0.5) },
	Thrust = { Back = CFrame.new(0, 0, 1.1), Strike = CFrame.new(0, 0, -1.4) },
	Punch = { Back = CFrame.new(0, 0.1, 1.6) * CFrame.Angles(math.rad(-15), 0, 0), Strike = CFrame.new(0, 0, -2.2) },
	Recoil = { Back = CFrame.new(0, 0, 0.2), Strike = CFrame.new(0, 0.05, 0.7) },
	Raise = { Back = CFrame.Angles(math.rad(-30), 0, 0), Strike = CFrame.Angles(math.rad(-65), 0, 0) * CFrame.new(0, 0.3, 0) },
}

local DEFAULT_SHAPE = { Melee = "Overhead", Ranged = "Recoil", Freeze = "Thrust", Cloak = "Raise", Decoy = "Raise", Guard = "Raise" }

local function pawStats(): any
	return {
		Type = "Melee",
		Cooldown = GameConfig.get("Combat", "PawCooldown"),
	}
end

local function tween(instance: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local t = TweenService:Create(instance, TweenInfo.new(math.max(seconds, 0.01), style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function stopRunning(key: Instance)
	local entry = running[key]
	if entry then
		running[key] = nil
		for _, t in entry.Tweens do
			t:Cancel()
		end
		entry.Reset()
	end
end

-- Procedural swing of a Tool's grip.
local function swingTool(tool: Tool, shapeName: string, windUp: number, active: number, recovery: number)
	local shape = SHAPES[shapeName] or SHAPES.Overhead
	local rest = tool.Grip
	stopRunning(tool)
	local entry = { Tweens = {} :: { Tween }, Reset = function()
		if tool.Parent then
			tool.Grip = rest
		end
	end }
	running[tool] = entry
	table.insert(entry.Tweens, tween(tool, windUp, { Grip = rest * shape.Back }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	task.delay(windUp, function()
		if running[tool] ~= entry then
			return
		end
		table.insert(entry.Tweens, tween(tool, math.max(active, 0.08), { Grip = rest * shape.Strike }, Enum.EasingStyle.Quint, Enum.EasingDirection.In))
	end)
	task.delay(windUp + math.max(active, 0.08), function()
		if running[tool] ~= entry then
			return
		end
		table.insert(entry.Tweens, tween(tool, math.min(recovery, 0.35), { Grip = rest }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	end)
	task.delay(windUp + math.max(active, 0.08) + math.min(recovery, 0.35) + 0.05, function()
		if running[tool] == entry then
			running[tool] = nil
			entry.Reset()
		end
	end)
end

-- Procedural punch of the bare paws: the right arm's shoulder joint is pushed forward and restored (R15 or R6).
local function swingPaw(character: Model, windUp: number, active: number, recovery: number)
	local shoulder: Motor6D? = nil
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") and (descendant.Name == "RightShoulder") then
			shoulder = descendant
			break
		end
	end
	if not shoulder or running[shoulder] then
		return
	end
	local motor = shoulder :: Motor6D
	local rest = motor.C0
	local entry = { Tweens = {} :: { Tween }, Reset = function()
		if motor.Parent then
			motor.C0 = rest
		end
	end }
	running[motor] = entry
	table.insert(entry.Tweens, tween(motor, windUp, { C0 = rest * CFrame.Angles(math.rad(-50), 0, math.rad(15)) }))
	task.delay(windUp, function()
		if running[motor] == entry then
			table.insert(entry.Tweens, tween(motor, math.max(active, 0.08), { C0 = rest * CFrame.Angles(math.rad(95), 0, 0) }, Enum.EasingStyle.Quint, Enum.EasingDirection.In))
		end
	end)
	task.delay(windUp + math.max(active, 0.08), function()
		if running[motor] == entry then
			table.insert(entry.Tweens, tween(motor, math.min(recovery, 0.3), { C0 = rest }))
		end
	end)
	task.delay(windUp + math.max(active, 0.08) + math.min(recovery, 0.3) + 0.05, function()
		if running[motor] == entry then
			running[motor] = nil
			entry.Reset()
		end
	end)
end

-- Plays the swing of `itemId` ("" = bare paws) for `player`. Safe to call for any player at any time.
function WeaponAnimator.play(player: Player, itemId: string, position: Vector3?)
	local character = player.Character
	if not character then
		return
	end
	local def = if itemId ~= "" then ItemRegistry.get(itemId) else nil
	local stats = if def and def.Equip.Kind == "Tool" then def.Equip.Weapon else pawStats()
	local windUp, active, recovery = CombatTiming.of(stats)

	-- sound exactly when the weapon becomes dangerous
	task.delay(windUp, function()
		AudioController.play("Slap", { Position = position or (character.PrimaryPart and character.PrimaryPart.Position), Pitch = if stats.Type == "Ranged" then 1.5 else 0.8 + math.random() * 0.25 })
	end)

	local animationName = stats.Animation
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if animationName and humanoid and AnimationRegistry.playable(animationName) then
		local track = AnimationController.play(humanoid, animationName, { Priority = Enum.AnimationPriority.Action2, Looped = false })
		if track then
			-- scale so the animation ends when the cooldown does, never slower than its authored speed
			local total = windUp + active + math.min(recovery, 0.4)
			if track.Length > 0 and track.Length > total then
				track:AdjustSpeed(track.Length / total)
			end
			return
		end
	end

	-- built-in procedural fallback
	local tool: Tool? = nil
	if def then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("ItemId") == itemId then
				tool = child
			end
		end
	end
	if tool then
		local look = stats.Look or {}
		swingTool(tool, look.Swing or DEFAULT_SHAPE[stats.Type] or "Overhead", windUp, active, recovery)
	elseif not def then
		swingPaw(character, windUp, active, recovery)
	end
end

function WeaponAnimator.playForUserId(userId: any, itemId: string, position: Vector3?)
	local player = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	if player then
		WeaponAnimator.play(player, itemId, position)
	end
end

return WeaponAnimator
