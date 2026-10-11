--[[
	CombatController: attacking. Bare paws = the slap ([Q] / gamepad B / on-screen button); with a weapon Tool in hand a
	click / tap (Tool.Activated) or the same keys swing it. The client only says "attack" (plus an aim direction for
	ranged weapons); the server owns the equipped-weapon check, target, range, cooldown and what the hit does.
	Knockback arrives as a velocity because the client owns its own character physics.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local HamsterStates = require(Modules:WaitForChild("HamsterStates"))
local ItemRegistry = require(Modules:WaitForChild("ItemRegistry"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local AudioController = require(script.Parent.AudioController)

local CombatController = {}

local ACTION = "HamsterSlap"
local lastAttack = 0
local lastCooldown = HamsterStates.Config.SlapCooldown

-- The weapon Tool the character holds right now: (definition, tool) or nil. (Ownership is the server's call.)
function CombatController.held(): (any?, Tool?)
	local character = Players.LocalPlayer.Character
	if character then
		for _, child in character:GetChildren() do
			if child:IsA("Tool") then
				local def = ItemRegistry.get(child:GetAttribute("ItemId"))
				if def and def.Equip.Kind == "Tool" then
					return def, child
				end
			end
		end
	end
	return nil, nil
end

local function cooldown(): number
	local def = CombatController.held()
	return if def then def.Equip.Weapon.Cooldown else HamsterStates.Config.SlapCooldown
end

-- Where a ranged weapon aims: from the character towards what the cursor / screen centre points at.
local function aimDirection(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local camera = workspace.CurrentCamera
	if not (root and root:IsA("BasePart") and camera) then
		return nil
	end
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local screen = if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter or UserInputService.TouchEnabled
		then camera.ViewportSize / 2
		else UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
	local point = if hit then hit.Position else ray.Origin + ray.Direction * 200
	local direction = point - origin
	if direction.Magnitude < 1 then
		return root.CFrame.LookVector
	end
	return direction.Unit
end

-- Attack with whatever is in hand. The server still decides target, range and cooldown.
function CombatController.attack(): boolean
	local now = os.clock()
	local wait = cooldown()
	if now - lastAttack >= wait * 0.9 then
		lastAttack = now
		lastCooldown = wait
		local def = CombatController.held()
		local aim = if def and def.Equip.Weapon.Type == "Ranged" then aimDirection() else nil
		Remotes.event("Attack"):FireServer(aim)
		if not def then
			AudioController.play("Slap")
		end
		return true
	end
	return false
end

-- Kept for the hotbar's paws slot.
function CombatController.slap(): boolean
	return CombatController.attack()
end

-- 0..1: how far the cooldown has recovered (for the hotbar).
function CombatController.ready(): number
	return math.clamp((os.clock() - lastAttack) / (lastCooldown * 0.9), 0, 1)
end

local function handle(_name: string, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	CombatController.attack()
	return Enum.ContextActionResult.Sink
end

local function watchCharacter(character: Model)
	local function watch(child: Instance)
		if child:IsA("Tool") and ItemRegistry.get(child:GetAttribute("ItemId")) then
			child.Activated:Connect(CombatController.attack)
		end
	end
	character.ChildAdded:Connect(watch)
	for _, child in character:GetChildren() do
		watch(child)
	end
end

function CombatController.start()
	ContextActionService:BindAction(ACTION, handle, true, Enum.KeyCode.Q, Enum.KeyCode.ButtonB)
	ContextActionService:SetTitle(ACTION, "Slap")
	ContextActionService:SetPosition(ACTION, UDim2.new(1, -150, 1, -280))

	Remotes.event("Knockback").OnClientEvent:Connect(function(velocity: Vector3)
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and typeof(velocity) == "Vector3" then
			root.AssemblyLinearVelocity = velocity
		end
	end)

	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		watchCharacter(player.Character)
	end
end

return CombatController
