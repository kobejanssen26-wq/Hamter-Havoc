--[[
	TutorialUI: the short, skippable first-time guide (7 steps, see TutorialConfig).
	The step lives in the server-owned profile.Tutorial (TutorialSystem). This module shows a SMALL objective card in the
	left column and marks the real object the step is about: a bobbing arrow plus an outline Highlight on it.

	How targets are found (no coordinates anywhere): the world builders mark objects with Build.target(...), which sets the
	tag "TutorialTarget" and the attribute TutorialTarget = "Base" | "Bench" | "Gate" | "Upgrade" | "Altar" | "Leaderboard".
	Objects inside a house belong to that house's Model (attribute OwnerUserId): only YOUR objects are offered. If the map
	is rebuilt or objects move, the guide simply follows the tagged objects. "Hamsters" points at the nearest hamster ball.
	Players whose tutorial is done never see anything; Settings > Replay tutorial starts it again.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local TutorialConfig = require(Modules:WaitForChild("TutorialConfig"))

local DataController = require(script.Parent.Parent.Controllers.DataController)
local WorldController = require(script.Parent.Parent.Controllers.WorldController)
local UIKit = require(script.Parent.UIKit)

local TutorialUI = {}

local C = UIKit.Colors
local player = Players.LocalPlayer

-- The tagged part named `target` that belongs to this player (or to nobody: shared places like the leaderboard).
function TutorialUI.findTarget(target: string): BasePart?
	local best: BasePart? = nil
	local bestDistance = math.huge
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local here = if root and root:IsA("BasePart") then root.Position else Vector3.zero
	for _, instance in CollectionService:GetTagged("TutorialTarget") do
		if instance:IsA("BasePart") and instance:GetAttribute("TutorialTarget") == target then
			local owner: number? = nil
			local node: Instance? = instance.Parent
			while node and node ~= Workspace do
				local value = node:GetAttribute("OwnerUserId")
				if value ~= nil then
					owner = value
					break
				end
				node = node.Parent
			end
			if owner == nil or owner == player.UserId then
				local distance = (instance.Position - here).Magnitude
				if distance < bestDistance then
					best, bestDistance = instance, distance
				end
			end
		end
	end
	return best
end

function TutorialUI.start()
	local left = require(script.Parent.MainUI).region("LeftColumn")
	if not left then
		warn("[TutorialUI] LeftColumn region missing (MainUI must start first)")
		return
	end
	local card = UIKit.frame(left, {
		Name = "TutorialCard",
		Size = UDim2.fromOffset(290, 142),
		LayoutOrder = 5,
		BackgroundColor3 = C.Cream,
		Visible = false,
	})
	UIKit.corner(card, 8)
	UIKit.stroke(card, C.Line, 1)
	local step = UIKit.label(card, { Name = "Step", Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(14, 10), Font = UIKit.Fonts.Title, TextSize = UIKit.Type.Caption, TextColor3 = C.Gold })
	local title = UIKit.label(card, { Name = "Title", Size = UDim2.new(1, -28, 0, 22), Position = UDim2.fromOffset(14, 26), Font = UIKit.Fonts.Title, TextSize = UIKit.Type.Heading + 2, TextColor3 = C.Ink, TextTruncate = Enum.TextTruncate.AtEnd })
	local text = UIKit.label(card, { Name = "Text", Size = UDim2.new(1, -28, 0, 54), Position = UDim2.fromOffset(14, 50), Font = UIKit.Fonts.Soft, TextSize = UIKit.Type.Caption + 1, TextColor3 = C.Muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
	local action = UIKit.button(card, { Text = "Next", Size = UDim2.fromOffset(96, 28), Position = UDim2.new(1, -14, 1, -10), AnchorPoint = Vector2.new(1, 1), Color = C.Green, TextSize = 14, Name = "Next" })
	local skip = UIKit.button(card, { Text = "Skip", Size = UDim2.fromOffset(64, 28), Position = UDim2.new(0, 14, 1, -10), AnchorPoint = Vector2.new(0, 1), Color = C.Card, TextSize = 13, Name = "Skip" })
	local progress = UIKit.frame(card, { Name = "Progress", Size = UDim2.new(0, 0, 0, 2), BackgroundColor3 = C.Gold })

	-- the marker: one arrow billboard + one Highlight, moved between targets (never recreated)
	local arrowPart = Instance.new("Part")
	arrowPart.Name = "TutorialMarker"
	arrowPart.Anchored = true
	arrowPart.CanCollide = false
	arrowPart.CanQuery = false
	arrowPart.CanTouch = false
	arrowPart.Transparency = 1
	arrowPart.Size = Vector3.one * 0.4
	arrowPart.Parent = Workspace
	local arrowGui = Instance.new("BillboardGui")
	arrowGui.Name = "Arrow"
	arrowGui.Size = UDim2.fromOffset(36, 44)
	arrowGui.AlwaysOnTop = true
	arrowGui.LightInfluence = 0
	arrowGui.MaxDistance = 900
	arrowGui.StudsOffsetWorldSpace = Vector3.new(0, 5, 0)
	arrowGui.Adornee = arrowPart
	arrowGui.Enabled = false
	arrowGui.Parent = arrowPart
	local arrow = UIKit.icon(nil, "arrowup", { Size = UDim2.fromOffset(32, 32), Color = C.Gold })
	arrow.Rotation = 180
	arrow.Position = UDim2.fromOffset(2, 4)
	arrow.Parent = arrowGui
	local highlight = Instance.new("Highlight")
	highlight.Name = "TutorialHighlight"
	highlight.FillColor = C.Gold
	highlight.FillTransparency = 0.75
	highlight.OutlineColor = C.Gold
	highlight.OutlineTransparency = 0.1
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Enabled = false
	highlight.Parent = arrowPart

	local currentStep: any = nil
	local targetName: string? = nil
	TutorialUI.CurrentTarget = nil :: Instance? -- exposed for tests

	local function markerPosition(): (Vector3?, BasePart?)
		if targetName == "Hamsters" then
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
				return best, nil
			end
			return nil, nil
		elseif targetName then
			local part = TutorialUI.findTarget(targetName)
			if part then
				return part.Position, part
			end
		end
		return nil, nil
	end

	local function render()
		local tutorial = DataController.get("Tutorial")
		if not tutorial or tutorial.Done then
			card.Visible = false
			currentStep = nil
			targetName = nil
			arrowGui.Enabled = false
			highlight.Enabled = false
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
			UIKit.tween(progress, 0.3, { Size = UDim2.new(tutorial.Step / #TutorialConfig.Steps, 0, 0, 2) })
			action.Visible = def.Kind == "Ack"
			UIKit.setButtonContent(action, nil, def.Button or "Next", C.White)
			card.Visible = true
			targetName = def.Target or def.Pointer
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

	-- the marker follows the tagged object (or the nearest ball); a gentle bob, only while there is a target
	RunService.Heartbeat:Connect(function()
		if not targetName then
			arrowGui.Enabled = false
			highlight.Enabled = false
			TutorialUI.CurrentTarget = nil
			return
		end
		local position, part = markerPosition()
		if position then
			arrowPart.Position = position + Vector3.new(0, math.sin(os.clock() * 3) * 0.6, 0)
			arrowGui.Enabled = true
			highlight.Adornee = part
			highlight.Enabled = part ~= nil
			TutorialUI.CurrentTarget = part
		else
			arrowGui.Enabled = false
			highlight.Enabled = false
			TutorialUI.CurrentTarget = nil
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
