--[[
	InputController: [E] / gamepad X / the on-screen button interacts with the hamster ball you are closest to:
	Claim (pay for it), Steal, Carry your own, or Pick up a dropped one - the server decides what it means.
	The button only exists while a ball is in reach and its title follows the action.
	(World menus - shops, upgrades - use [F] so the two never fight over the same key.)
	Clicking or tapping a ball's name tag works too (see WorldController).
]]

local ContextActionService = game:GetService("ContextActionService")

local WorldController = require(script.Parent.WorldController)

local InputController = {}

local ACTION = "HamsterInteract"
local bound = false

local function handle(_name: string, state: Enum.UserInputState)
	if state == Enum.UserInputState.Begin then
		WorldController.interact()
	end
	return Enum.ContextActionResult.Pass
end

local function bind(title: string)
	if not bound then
		bound = true
		ContextActionService:BindAction(ACTION, handle, true, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
		ContextActionService:SetPosition(ACTION, UDim2.new(1, -150, 1, -190))
	end
	ContextActionService:SetTitle(ACTION, title)
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
			bind(info.Action .. "!")
		else
			unbind()
		end
	end)
end

return InputController
