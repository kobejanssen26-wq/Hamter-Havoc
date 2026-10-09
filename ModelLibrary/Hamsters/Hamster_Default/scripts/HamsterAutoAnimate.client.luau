--[[
	HamsterAutoAnimate - drives the hamster's Motor6D animation on the CLIENT (Script.RunContext = Client).

	  model:SetAttribute("MoveSpeed", 0)   -- idle: breathing, tail wag, ear twitch and random behaviours
	  model:SetAttribute("MoveSpeed", 8)   -- running / walking cycle (about studs per second)
	  ModelScale (attribute, set by the exporter) = size factor of this hamster, used to scale joint movement

	Needs only the sibling ModuleScript "HamsterAnimator" (bundled). Safe to delete if you animate the hamster yourself.
]]

local RunService = game:GetService("RunService")

local model = script.Parent
local HamsterAnimator = require(model:WaitForChild("HamsterAnimator"))
local animator = HamsterAnimator.new(model)
-- joint offsets are in studs and scale with the hamster; a saved file does not remember Model:ScaleTo(), so it is stored in this attribute
animator.Scale = model:GetAttribute("ModelScale") or animator.Scale

local connection
connection = RunService.RenderStepped:Connect(function(dt)
	if not model:IsDescendantOf(game) then
		connection:Disconnect()
		return
	end
	animator:Update(dt, model:GetAttribute("MoveSpeed") or 0)
end)
