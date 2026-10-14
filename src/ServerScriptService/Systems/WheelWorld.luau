--[[
	WheelWorld: the server side of the PHYSICAL Lucky Wheel (built by WorldBuilder/LuckyWheelBuilder, tag "LuckyWheel").

	The draw is made by SpinSystem; this module only tells every client where the physical wheel has to stop, as attributes on
	the wheel model (SpinId, SpinFrom, SpinTo, SpinStart, SpinDuration). Clients animate it (WheelWorldController) and the
	server snaps the rotor to the final angle when the spin is over, so a player who joins later sees where it stopped.
	One physical wheel = one spin at a time: SpinSystem refuses a second spin while the wheel is turning (WheelWorld.busy()).
]]

local CollectionService = game:GetService("CollectionService")
local Workspace = game:GetService("Workspace")

local WheelWorld = {}

WheelWorld.Duration = 4 -- seconds the wheel turns (the window animation uses the same number)
local TURNS = 5
local busyUntil = 0

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

-- Degrees (clockwise seen from the road) at which slice `index` has to be under the pointer, from the current angle.
function WheelWorld.targetAngle(current: number, index: number, slices: number): number
	local slice = (index - 1) * 360 / slices
	return current + 360 * TURNS + ((360 - slice - current % 360) % 360)
end

local function rotor(model: Model): Model?
	local found = model:FindFirstChild("Rotor")
	return if found and found:IsA("Model") then found else nil
end

local function setAngle(model: Model, degrees: number)
	local part = rotor(model)
	local base = model:GetAttribute("BaseCFrame")
	if part and typeof(base) == "CFrame" then
		part:PivotTo(base * CFrame.Angles(0, 0, math.rad(degrees)))
	end
end

-- Starts the physical spin for the prize at `index`. Returns false when there is no wheel or it is busy.
function WheelWorld.spin(index: number): boolean
	local model = WheelWorld.model()
	if not model or os.clock() < busyUntil then
		return false
	end
	local slices = (model:GetAttribute("Slices") :: number?) or 0
	if slices < 1 or index < 1 or index > slices then
		return false
	end
	local from = (model:GetAttribute("Angle") :: number?) or 0
	local to = WheelWorld.targetAngle(from, index, slices)
	busyUntil = os.clock() + WheelWorld.Duration + 0.4
	model:SetAttribute("SpinFrom", from)
	model:SetAttribute("SpinTo", to)
	model:SetAttribute("SpinIndex", index)
	model:SetAttribute("SpinStart", Workspace:GetServerTimeNow())
	model:SetAttribute("SpinDuration", WheelWorld.Duration)
	model:SetAttribute("SpinId", ((model:GetAttribute("SpinId") :: number?) or 0) + 1)
	task.delay(WheelWorld.Duration + 0.15, function()
		if model.Parent then
			setAngle(model, to)
			model:SetAttribute("Angle", to % 360)
		end
	end)
	return true
end

return WheelWorld
