--[[
	InputController: [E] / gamepad X / the on-screen button grabs the hamster you are closest to.
	(World menus - shops, upgrades - use [F] so the two never fight over the same key.)
	Clicking or tapping a hamster's name tag works too (see WorldController).
]]

local ContextActionService = game:GetService("ContextActionService")

local WorldController = require(script.Parent.WorldController)

local InputController = {}

local ACTION = "HamsterCollect"
local bound = false

local function handle(_name: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		WorldController.collect()
	end
	return Enum.ContextActionResult.Pass
end

local function bind()
	if bound then
		return
	end
	bound = true
	ContextActionService:BindAction(ACTION, handle, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
	ContextActionService:SetTitle(ACTION, "Grab!")
	ContextActionService:SetPosition(ACTION, UDim2.new(1, -150, 1, -190))
end

local function unbind()
	if not bound then
		return
	end
	bound = false
	ContextActionService:UnbindAction(ACTION)
end

function InputController.start()
	-- the key / touch button only exists while a hamster is actually in reach
	WorldController.onTargetChanged(function(info)
		if info then
			bind()
		else
			unbind()
		end
	end)
end

return InputController
