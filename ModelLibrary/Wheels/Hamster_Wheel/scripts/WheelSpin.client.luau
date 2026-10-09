--[[
	WheelSpin - turns the wheel on the CLIENT (Script.RunContext = Client). No other script or service is needed.

	Attributes on the inner `Wheel` model:
	  Speed         radians per second the wheel turns (0 = stand still)                      default 3
	  RunDirection  direction the hamster runs, in the LOCAL space of this assembly (the     default (1, 0, 0)
	                top-level model), so you can rotate or move the whole model freely

	The floor under a running hamster moves BACKWARDS, so the wheel turns around  (up x RunDirection).
	The rotation axis is the hub's axle: it never moves, only the wheel's angle changes.
]]

local RunService = game:GetService("RunService")

local assembly = script.Parent
local wheel = assembly:WaitForChild("Wheel")

-- where the wheel sits relative to the assembly when it is not turning
local home = assembly:GetPivot():ToObjectSpace(wheel:GetPivot())
local angle = 0

local connection
connection = RunService.RenderStepped:Connect(function(dt)
	if not assembly:IsDescendantOf(game) then
		connection:Disconnect()
		return
	end
	local speed = wheel:GetAttribute("Speed") or 0
	if speed == 0 then
		return
	end
	local run = wheel:GetAttribute("RunDirection")
	if typeof(run) ~= "Vector3" or run.Magnitude < 0.01 then
		run = Vector3.xAxis
	end
	local axisInAssembly = Vector3.yAxis:Cross(run.Unit)
	local axis = home:VectorToObjectSpace(axisInAssembly)
	angle += speed * dt
	wheel:PivotTo(assembly:GetPivot() * home * CFrame.fromAxisAngle(axis, angle))
end)
