--[[
	CombatController: the slap ([Q] / gamepad B / on-screen button) and knockback.
	The client only says "slap"; the server picks the target, checks cooldown and range and decides what happens.
	Knockback arrives as a velocity because the client owns its own character physics.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HamsterStates = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("HamsterStates"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local AudioController = require(script.Parent.AudioController)

local CombatController = {}

local ACTION = "HamsterSlap"
local lastSlap = 0

local function handle(_name: string, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local now = os.clock()
	if now - lastSlap >= HamsterStates.Config.SlapCooldown * 0.9 then
		lastSlap = now
		Remotes.event("Attack"):FireServer()
		AudioController.play("Slap")
	end
	return Enum.ContextActionResult.Sink
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
end

return CombatController
