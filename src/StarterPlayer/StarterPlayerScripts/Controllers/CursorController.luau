--[[
	CursorController: keeps the mouse usable while menus are open.

	Roblox locks and hides the mouse in first person (camera zoomed all the way in), so buttons can't be clicked.
	While any menu is open (UIKit panels call `hold`) - or while you hold ALT - this controller sets the mouse back to
	free movement after the camera scripts have run each frame. The moment nothing holds the cursor any more, the
	override stops and the camera scripts take the mouse back (first person locks it again by itself).

	Tested sequence: third person -> zoom into first person -> open Settings -> close -> open Index -> close.
]]

local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local CursorController = {}

local BIND_NAME = "HamsterPlazaCursor"

local holders: { [string]: boolean } = {}
local wasFree = false

local function holding(): boolean
	return next(holders) ~= nil
end

-- A menu (or anything else) needs the free mouse / releases it.
function CursorController.hold(reason: string, active: boolean)
	if active then
		holders[reason] = true
	else
		holders[reason] = nil
	end
end

function CursorController.isHolding(): boolean
	return holding()
end

function CursorController.isFirstPerson(): boolean
	local camera = Workspace.CurrentCamera
	if not camera then
		return false
	end
	return (camera.Focus.Position - camera.CFrame.Position).Magnitude < 1.2
end

local function wantsFreeMouse(): boolean
	return holding() or UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
end

function CursorController.start()
	-- runs right after the default camera scripts (which set LockCenter in first person every frame)
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		if wantsFreeMouse() then
			wasFree = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
			UserInputService.MouseIconEnabled = true
		elseif wasFree then
			wasFree = false
			UserInputService.MouseIconEnabled = true
			-- the camera script restores LockCenter on its own in first person; third person never needs it
		end
	end)
end

return CursorController
