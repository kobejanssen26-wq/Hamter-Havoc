--[[
	Local-only animation: spins tagged wheels and makes wheel hamsters bob while "running".
	The server only sets attributes (HomeCFrame, SpinSpeed); no per-frame replication needed.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local WheelAnimator = {}

local wheels = {} -- [Model] = { Angle = number }
local hamsters = {} -- [Model] = true

local function trackSet(tag: string, onAdded: (Model) -> (), onRemoved: (Model) -> ())
	for _, instance in CollectionService:GetTagged(tag) do
		onAdded(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(onAdded)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(onRemoved)
end

function WheelAnimator.start()
	trackSet("SpinningWheel", function(model)
		wheels[model] = { Angle = 0 }
	end, function(model)
		wheels[model] = nil
	end)
	trackSet("RunningHamster", function(model)
		hamsters[model] = true
	end, function(model)
		hamsters[model] = nil
	end)

	local clock = 0
	RunService.RenderStepped:Connect(function(deltaTime)
		clock += deltaTime

		for model, state in wheels do
			local home = model:GetAttribute("HomeCFrame")
			local speed = model:GetAttribute("SpinSpeed") or 0
			if home and speed ~= 0 and model.PrimaryPart then
				state.Angle -= speed * deltaTime
				model:PivotTo(home * CFrame.Angles(state.Angle, 0, 0))
			end
		end

		for model in hamsters do
			local home = model:GetAttribute("HomeCFrame")
			if home and model.PrimaryPart then
				local phase = clock * 9
				model:PivotTo(home * CFrame.new(0, math.abs(math.sin(phase)) * 0.3, 0) * CFrame.Angles(math.sin(phase) * 0.06, 0, 0))
			end
		end
	end)
end

return WheelAnimator
