--[[
	TutorialUI: the short, skippable first-time guide. The step lives in the server-owned profile.Tutorial
	(see TutorialSystem); this module shows the current objective card, a subtle bobbing arrow over the target
	(your plot or the nearest hamster) and sends "TutorialAck" / "TutorialSkip". Players whose tutorial is done
	(including everyone who existed before it was added) never see anything.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local TutorialConfig = require(Modules:WaitForChild("TutorialConfig"))
local WorldLayout = require(Modules:WaitForChild("WorldLayout"))

local DataController = require(script.Parent.Parent.Controllers.DataController)
local WorldController = require(script.Parent.Parent.Controllers.WorldController)
local UIKit = require(script.Parent.UIKit)

local TutorialUI = {}

local C = UIKit.Colors
local player = Players.LocalPlayer

function TutorialUI.start()
	local gui = UIKit.new("ScreenGui", {
		Name = "TutorialUI",
		ResetOnSpawn = false,
		DisplayOrder = 8,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	local inset = UIKit.GuiService:GetGuiInset().Y
	local card = UIKit.frame(gui, {
		Name = "Card",
		Size = UDim2.fromOffset(330, 150),
		Position = UDim2.new(0, 14, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundColor3 = C.Cream,
		BackgroundTransparency = 0.03,
		Visible = false,
	})
	UIKit.corner(card, 10)
	UIKit.stroke(card, C.GoldLine, 1.5)
	local scale = UIKit.new("UIScale", { Scale = 1 }, card)
	local step = UIKit.label(card, { Size = UDim2.new(1, -20, 0, 16), Position = UDim2.fromOffset(14, 10), Font = UIKit.Fonts.Title, TextSize = 12, TextColor3 = C.Gold })
	local title = UIKit.label(card, { Size = UDim2.new(1, -28, 0, 24), Position = UDim2.fromOffset(14, 28), Font = UIKit.Fonts.Title, TextSize = 18, TextColor3 = C.Ink, TextTruncate = Enum.TextTruncate.AtEnd })
	local text = UIKit.label(card, { Size = UDim2.new(1, -28, 0, 56), Position = UDim2.fromOffset(14, 54), Font = UIKit.Fonts.Soft, TextSize = 13, TextColor3 = C.Muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	local action = UIKit.button(card, { Text = "Next", Size = UDim2.fromOffset(120, 32), Position = UDim2.new(1, -14, 1, -12), AnchorPoint = Vector2.new(1, 1), Color = C.Green, TextSize = 14, Name = "Next" })
	local skip = UIKit.button(card, { Text = "Skip tutorial", Size = UDim2.fromOffset(110, 28), Position = UDim2.new(0, 14, 1, -14), AnchorPoint = Vector2.new(0, 1), Color = C.Card, TextSize = 12, Name = "Skip" })
	local progress = UIKit.frame(card, { Size = UDim2.new(1, 0, 0, 3), Position = UDim2.new(0, 0, 0, 0), BackgroundColor3 = C.Gold })

	local function fit()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		scale.Scale = math.clamp(viewport.X / 900, 0.7, 1.05)
		-- big screens: right side, below the shortcut buttons; small screens: top centre so it never covers the controls
		if viewport.X < 900 or viewport.Y < 600 then
			card.AnchorPoint = Vector2.new(0.5, 0)
			card.Position = UDim2.new(0.5, 0, 0, inset + 96)
		else
			card.AnchorPoint = Vector2.new(1, 0.5)
			card.Position = UDim2.new(1, -14, 0.6, 0)
		end
	end
	fit()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	-- the arrow: one billboard, moved between targets (never recreated)
	local arrowPart = Instance.new("Part")
	arrowPart.Name = "TutorialTarget"
	arrowPart.Anchored = true
	arrowPart.CanCollide = false
	arrowPart.CanQuery = false
	arrowPart.CanTouch = false
	arrowPart.Transparency = 1
	arrowPart.Size = Vector3.one * 0.4
	arrowPart.Parent = Workspace
	local arrowGui = Instance.new("BillboardGui")
	arrowGui.Size = UDim2.fromOffset(36, 44)
	arrowGui.AlwaysOnTop = true
	arrowGui.LightInfluence = 0
	arrowGui.MaxDistance = 900
	arrowGui.StudsOffsetWorldSpace = Vector3.new(0, 6, 0)
	arrowGui.Adornee = arrowPart
	arrowGui.Enabled = false
	arrowGui.Parent = arrowPart
	local arrow = UIKit.icon(nil, "arrowup", { Size = UDim2.fromOffset(32, 32), Color = C.Gold })
	arrow.Rotation = 180
	arrow.Position = UDim2.fromOffset(2, 4)
	arrow.Parent = arrowGui

	local currentStep: any = nil
	local pointer: string? = nil

	local function pointerPosition(): Vector3?
		if pointer == "Plot" then
			local houseId = player:GetAttribute("HouseId")
			if type(houseId) == "number" then
				return WorldLayout.padPosition(WorldLayout.houseCFrame(houseId))
			end
		elseif pointer == "Hamsters" then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				local best, bestDistance = nil, math.huge
				for _, ball in WorldController.getBalls() do
					if not ball.Removing then
						local distance = (ball.Pos - root.Position).Magnitude
						if distance < bestDistance then
							best, bestDistance = ball.Pos, distance
						end
					end
				end
				return best
			end
		end
		return nil
	end

	local function render()
		local tutorial = DataController.get("Tutorial")
		if not tutorial or tutorial.Done then
			card.Visible = false
			currentStep = nil
			pointer = nil
			arrowGui.Enabled = false
			return
		end
		local def = TutorialConfig.Steps[tutorial.Step]
		if not def then
			card.Visible = false
			return
		end
		if currentStep ~= def then
			currentStep = def
			step.Text = string.format("TUTORIAL  %d / %d", tutorial.Step, #TutorialConfig.Steps)
			title.Text = def.Title
			text.Text = def.Text
			UIKit.tween(progress, 0.3, { Size = UDim2.new((tutorial.Step - 1) / #TutorialConfig.Steps + 0.08, 0, 0, 3) })
			action.Visible = def.Kind == "Ack"
			UIKit.setButtonContent(action, nil, def.Button or "Next", C.White)
			if not card.Visible then
				card.Visible = true
				fit()
			end
			pointer = def.Target or def.Pointer
		end
	end

	action.Activated:Connect(function()
		if currentStep and currentStep.Kind == "Ack" then
			DataController.request("TutorialAck", { Step = currentStep.Id })
		end
	end)
	skip.Activated:Connect(function()
		DataController.request("TutorialSkip")
	end)

	-- arrow follows the target; a gentle bob, only while there is a target
	RunService.Heartbeat:Connect(function()
		if not pointer then
			arrowGui.Enabled = false
			return
		end
		local position = pointerPosition()
		if position then
			arrowPart.Position = position + Vector3.new(0, math.sin(os.clock() * 3) * 0.6, 0)
			arrowGui.Enabled = true
		else
			arrowGui.Enabled = false
		end
	end)

	DataController.onChanged(function(keys)
		if keys.Tutorial then
			render()
		end
	end)
	DataController.onReady(render)
	render()
end

return TutorialUI
