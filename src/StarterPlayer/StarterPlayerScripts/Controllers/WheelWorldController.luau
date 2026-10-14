--[[
	WheelWorldController: animates the physical Lucky Wheel in the plaza and keeps its status sign up to date.

	  * When the server starts a spin (attribute SpinId changes on the wheel model) the rotor turns from SpinFrom to SpinTo with
	    an ease-out curve. The time comes from the server clock, so everybody sees the same angle at the same moment, also
	    when you walk up in the middle of a spin. The result itself was decided by the server.
	  * The sign above the wheel says FREE SPIN! (green) when YOUR free spin is ready, or a countdown (grey) when it is not.
	    This is a purely local text; the server still decides eligibility.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Format = require(game:GetService("ReplicatedStorage").Modules.Format)
local DataController = require(script.Parent.DataController)

local WheelWorldController = {}

type Wheel = { Model: Model, Active: boolean }
local wheels: { [Model]: Wheel } = {}

local function setAngle(model: Model, degrees: number)
	local rotor = model:FindFirstChild("Rotor")
	local base = model:GetAttribute("BaseCFrame")
	if rotor and rotor:IsA("Model") and typeof(base) == "CFrame" then
		rotor:PivotTo(base * CFrame.Angles(0, 0, math.rad(degrees)))
	end
end

local function easeOut(t: number): number
	return 1 - (1 - t) ^ 4
end

local function onWheel(instance: Instance)
	if not instance:IsA("Model") or wheels[instance] then
		return
	end
	wheels[instance] = { Model = instance, Active = false }
	instance:GetAttributeChangedSignal("SpinId"):Connect(function()
		wheels[instance].Active = true
	end)
	if instance:GetAttribute("SpinId") then
		wheels[instance].Active = true -- joined in the middle of a spin
	end
end

local function step()
	for model, wheel in wheels do
		if wheel.Active and model.Parent then
			local from = model:GetAttribute("SpinFrom") :: number?
			local to = model:GetAttribute("SpinTo") :: number?
			local started = model:GetAttribute("SpinStart") :: number?
			local duration = (model:GetAttribute("SpinDuration") :: number?) or 4
			if from and to and started then
				local t = math.clamp((Workspace:GetServerTimeNow() - started) / duration, 0, 1)
				setAngle(model, from + (to - from) * easeOut(t))
				if t >= 1 then
					wheel.Active = false
				end
			else
				wheel.Active = false
			end
		end
	end
end

local function updateStatus()
	local data = DataController.Data
	for model in wheels do
		local sign = model:FindFirstChild("Sign")
		local label = sign and sign:FindFirstChild("WheelStatus") and sign.WheelStatus:FindFirstChild("Status")
		if label and label:IsA("TextLabel") then
			local nextFree = if data and data.Wheel then data.Wheel.NextFreeAt or 0 else 0
			local now = DataController.now()
			if not DataController.Ready then
				label.Text = "LUCKY WHEEL"
			elseif now >= nextFree then
				label.Text = "FREE SPIN!"
				label.TextColor3 = Color3.fromRGB(110, 255, 140)
			else
				label.Text = "Next spin " .. Format.clock(nextFree - now)
				label.TextColor3 = Color3.fromRGB(230, 220, 255)
			end
		end
	end
end

function WheelWorldController.start()
	for _, instance in CollectionService:GetTagged("LuckyWheel") do
		onWheel(instance)
	end
	CollectionService:GetInstanceAddedSignal("LuckyWheel"):Connect(onWheel)
	CollectionService:GetInstanceRemovedSignal("LuckyWheel"):Connect(function(instance)
		wheels[instance :: Model] = nil
	end)
	RunService.RenderStepped:Connect(step)
	task.spawn(function()
		while true do
			updateStatus()
			task.wait(1)
		end
	end)
end

return WheelWorldController
