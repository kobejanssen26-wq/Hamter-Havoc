--[[
	MobilityController: moves YOUR character when the server allows a gadget (Sky Glider / Rocket Booster).

	The client owns its character's physics in Roblox, so the server cannot push it directly. Instead the server decides
	("Mobility" event: Glide / GlideEnd / Boost with numbers from the item file) and this script applies exactly that:
	  Glide    each frame: forward speed in the direction you steer (move keys, or where you face) and a falling speed that is
	           never faster than `Fall` studs/s, until the server says GlideEnd, the time is up, or you touch the ground
	  Boost    one launch: `Up` studs/s upwards and `Forward` studs/s ahead
	Nothing here can start a glide or a boost by itself.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local MobilityController = {}

local player = Players.LocalPlayer
local glide: { Until: number, Speed: number, Fall: number } = nil :: any

local function parts(): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid, if root and root:IsA("BasePart") then root else nil
end

local function flat(vector: Vector3): Vector3
	local horizontal = Vector3.new(vector.X, 0, vector.Z)
	return if horizontal.Magnitude > 0.01 then horizontal.Unit else Vector3.zero
end

function MobilityController.isGliding(): boolean
	return glide ~= nil
end

local function step()
	if not glide then
		return
	end
	local humanoid, root = parts()
	if not humanoid or not root or humanoid.Health <= 0 or os.clock() > glide.Until then
		glide = nil :: any
		return
	end
	local direction = flat(humanoid.MoveDirection)
	if direction == Vector3.zero then
		direction = flat(root.CFrame.LookVector)
	end
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(direction.X * glide.Speed, math.max(velocity.Y, -glide.Fall), direction.Z * glide.Speed)
end

function MobilityController.start()
	Remotes.event("Mobility").OnClientEvent:Connect(function(kind: any, data: any)
		if kind == "Glide" and type(data) == "table" and type(data.Seconds) == "number" then
			glide = { Until = os.clock() + data.Seconds + 0.4, Speed = data.Speed, Fall = data.Fall }
		elseif kind == "GlideEnd" then
			glide = nil :: any
		elseif kind == "Boost" and type(data) == "table" then
			local humanoid, root = parts()
			if humanoid and root then
				local direction = flat(root.CFrame.LookVector)
				root.AssemblyLinearVelocity = Vector3.new(direction.X * data.Forward, data.Up, direction.Z * data.Forward)
				humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
			end
		end
	end)
	RunService.Heartbeat:Connect(step)
	player.CharacterRemoving:Connect(function()
		glide = nil :: any
	end)
end

return MobilityController
