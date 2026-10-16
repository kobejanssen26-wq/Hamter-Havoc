--[[
	WheelWorld: the server side of the PHYSICAL Lucky Wheel (built by WorldBuilder/LuckyWheelBuilder, tag "LuckyWheel").

	The draw is made by SpinSystem; this module only tells every client where the physical wheel has to stop, as attributes on
	the wheel model (SpinId, SpinFrom, SpinTo, SpinStart, SpinDuration). Clients animate it (WheelWorldController) and the
	server snaps the rotor to the final angle when the spin is over, so a player who joins later sees where it stopped.
	One physical wheel = one spin at a time: SpinSystem refuses a second spin while the wheel is turning (WheelWorld.busy()).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local SpinWheelConfig = require(ReplicatedStorage.Modules.SpinWheelConfig)

local WheelWorld = {}

WheelWorld.USE_DISTANCE = 22 -- a player must stand this close to the wheel (studs) to spin it
local busyUntil = 0

-- how long one spin takes (live setting Wheel.SpinSeconds)
function WheelWorld.duration(): number
	return SpinWheelConfig.spinSeconds()
end

function WheelWorld.model(): Model?
	for _, instance in CollectionService:GetTagged("LuckyWheel") do
		if instance:IsA("Model") and instance:IsDescendantOf(Workspace) then
			return instance
		end
	end
	return nil
end

function WheelWorld.busy(): boolean
	return WheelWorld.model() ~= nil and os.clock() < busyUntil
end

-- Is the player standing at the wheel? (A spin asked from the other end of the map is refused. A player without a body
-- yet counts as not near, except when there is no wheel in the world at all.)
function WheelWorld.isNear(player: Player): boolean
	local model = WheelWorld.model()
	if not model then
		return true
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local pad = model:FindFirstChild("PromptPad")
	local at = if pad and pad:IsA("BasePart") then pad.Position else model:GetPivot().Position
	local flat = Vector3.new(root.Position.X - at.X, 0, root.Position.Z - at.Z)
	return flat.Magnitude <= WheelWorld.USE_DISTANCE
end

-- Degrees at which slice `index` has to be under the pointer, from the current angle (see SpinWheelConfig.targetAngle).
function WheelWorld.targetAngle(current: number, index: number, slices: number): number
	return SpinWheelConfig.targetAngle(current, index, slices, SpinWheelConfig.clockwise(), SpinWheelConfig.Turns)
end

-- Remembers where the rotor rests (its pivot at angle 0) so the wheel can be moved, turned or rebuilt in Studio: nothing is stored in
-- the place file. Published as the attribute BaseCFrame for the clients. Called at server start and before every spin.
function WheelWorld.prepare()
	for _, instance in CollectionService:GetTagged("LuckyWheel") do
		local found = instance:FindFirstChild("Rotor")
		if instance:IsA("Model") and found and found:IsA("Model") and instance:GetAttribute("SpinId") == nil then
			local angle = (instance:GetAttribute("Angle") :: number?) or 0
			instance:SetAttribute("Angle", angle % 360)
			instance:SetAttribute("BaseCFrame", SpinWheelConfig.rotorCFrame(found:GetPivot(), -angle))
			instance:SetAttribute("Slices", #SpinWheelConfig.Prizes)
		end
	end
end

local function rotor(model: Model): Model?
	local found = model:FindFirstChild("Rotor")
	return if found and found:IsA("Model") then found else nil
end

local function setAngle(model: Model, degrees: number)
	local part = rotor(model)
	local base = model:GetAttribute("BaseCFrame")
	if part and typeof(base) == "CFrame" then
		part:PivotTo(SpinWheelConfig.rotorCFrame(base, degrees))
	end
end

-- Starts the physical spin for the prize at `index`. Returns false when there is no wheel or it is busy.
function WheelWorld.spin(index: number): boolean
	local model = WheelWorld.model()
	if not model or os.clock() < busyUntil then
		return false
	end
	if typeof(model:GetAttribute("BaseCFrame")) ~= "CFrame" then
		WheelWorld.prepare()
	end
	local slices = (model:GetAttribute("Slices") :: number?) or 0
	if slices < 1 or index < 1 or index > slices then
		return false
	end
	local duration = WheelWorld.duration()
	local from = (model:GetAttribute("Angle") :: number?) or 0
	local to = WheelWorld.targetAngle(from, index, slices)
	busyUntil = os.clock() + duration + 0.4
	model:SetAttribute("SpinFrom", from)
	model:SetAttribute("SpinTo", to)
	model:SetAttribute("SpinIndex", index)
	model:SetAttribute("SpinStart", Workspace:GetServerTimeNow())
	model:SetAttribute("SpinDuration", duration)
	model:SetAttribute("SpinId", ((model:GetAttribute("SpinId") :: number?) or 0) + 1)
	task.delay(duration + 0.15, function()
		if model.Parent then
			setAngle(model, to)
			model:SetAttribute("Angle", to % 360)
		end
	end)
	return true
end

return WheelWorld
