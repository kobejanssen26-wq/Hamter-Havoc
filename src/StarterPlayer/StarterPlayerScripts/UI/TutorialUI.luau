--[[
	TutorialUI: the short, skippable first-time guide (11 steps, see TutorialConfig).
	The step lives in the server-owned profile.Tutorial (TutorialSystem). This module shows a SMALL objective card in the
	left column and marks the real object the step is about: a bobbing arrow plus an outline Highlight on it.

	How targets are found (no coordinates anywhere): the world builders mark objects with Build.target(...), which sets the
	tag "TutorialTarget" and the attribute TutorialTarget = "Base" | "Bench" | "Gate" | "Upgrade" | "Altar" | "Leaderboard".
	Objects inside a house belong to that house's Model (attribute OwnerUserId): only YOUR objects are offered. If the map
	is rebuilt or objects move, the guide simply follows the tagged objects. "Hamsters" points at the nearest hamster ball YOU CAN
	AFFORD (and says its real price). A step can also point at a BUTTON (UiTarget: gold outline + arrow on the real button) and its
	text can carry live numbers (Dynamic: the real ball and price, laser duration, cheapest upgrade, rebirth requirements).
	Players whose tutorial is done never see anything; Settings > Replay tutorial starts it again.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Format = require(Modules:WaitForChild("Format"))
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local HamsterStates = require(Modules:WaitForChild("HamsterStates"))
local RebirthConfig = require(Modules:WaitForChild("RebirthConfig"))
local TutorialConfig = require(Modules:WaitForChild("TutorialConfig"))
local UpgradeConfig = require(Modules:WaitForChild("UpgradeConfig"))

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

-- The hamster ball the first step sends you to: the nearest one for sale that you can pay, else the cheapest one for sale.
-- Returns (ball, affordable).
function TutorialUI.pickBall(): (any?, boolean)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local here = if root and root:IsA("BasePart") then root.Position else Vector3.zero
	local coins = DataController.coins()
	local nearestAffordable, nearestDistance = nil, math.huge
	local cheapest = nil
	for _, ball in WorldController.getBalls() do
		if ball.State == HamsterStates.Travelling and not ball.Removing then
			if ball.Price <= coins then
				local distance = (ball.Pos - here).Magnitude
				if distance < nearestDistance then
					nearestAffordable, nearestDistance = ball, distance
				end
			end
			if not cheapest or ball.Price < cheapest.Price then
				cheapest = ball
			end
		end
	end
	if nearestAffordable then
		return nearestAffordable, true
	end
	return cheapest, false
end

local function money(value: number): string
	return "$" .. Format.short(value)
end

-- Live texts for steps with Dynamic = "<name>". Each returns the text of the card.
TutorialUI.Dynamic = {
	hamster = function(): string
		local ball, affordable = TutorialUI.pickBall()
		if not ball then
			return "A hamster ball will roll out of the burrow in a moment. Watch the road in the middle of the map."
		end
		if affordable then
			return string.format("Buy the %s (%s) for %s. You have %s. Stand next to the ball and press E.", ball.Species.Name, ball.Species.Rarity, money(ball.Price), money(DataController.coins()))
		end
		return string.format("You have %s, the cheapest ball on the road costs %s. A cheaper hamster will roll by soon: wait near the road.", money(DataController.coins()), money(ball.Price))
	end,
	gate = function(): string
		local rebirths = DataController.Data.Rebirths or 0
		local seconds = GameConfig.get("Security", "GateBaseDuration") + GameConfig.get("Security", "GateSecondsPerRebirth") * rebirths
		local cooldown = GameConfig.get("Security", "GateReopenCooldown")
		return string.format("Other players can steal from an open base. Press E at your security panel: the lasers protect it for %d seconds, then they need about %d seconds before you can switch them on again.", seconds, cooldown)
	end,
	upgrade = function(): string
		local data = DataController.Data
		local rebirths = data.Rebirths or 0
		local best, bestCost = nil, math.huge
		for id, definition in UpgradeConfig.Definitions do
			if definition.Currency == "Coins" then
				local cost = UpgradeConfig.cost(id, (data.Upgrades and data.Upgrades[id]) or 0, rebirths)
				if cost and cost < bestCost then
					best, bestCost = definition, cost
				end
			end
		end
		if not best then
			return "Press F at the Upgrade Terminal to spend cash on more income, luck and speed."
		end
		return string.format("Press F at the Upgrade Terminal. The cheapest upgrade is %s (%s) for %s. You have %s.", best.Name, string.lower(best.Description or ""), money(bestCost), money(DataController.coins()))
	end,
	altar = function(): string
		local data = DataController.Data
		local number = (data.Rebirths or 0) + 1
		local allMet, list = DataController.rebirthCheck(number)
		local lines = { string.format("<b>Rebirth %d needs:</b>", number) }
		for _, requirement in list do
			local have = if requirement.Kind == "Coins" then money(requirement.Have) else tostring(math.floor(requirement.Have))
			local need = if requirement.Kind == "Coins" then money(requirement.Need) else tostring(requirement.Need)
			table.insert(lines, string.format("- %s: %s / %s %s", requirement.Label, have, need, if requirement.Met then '<font color="#60c47e">OK</font>' else '<font color="#e0705a">missing</font>'))
		end
		table.insert(lines, if allMet then "<b>You can rebirth now.</b> It resets only your coins and coin upgrades." else "Not ready yet: keep earning. A rebirth resets only your coins and coin upgrades; you keep all hamsters.")
		local rewards = RebirthConfig.rewards(number, 0)
		local gain = {}
		for index = 1, math.min(3, #rewards) do
			table.insert(gain, rewards[index].Text)
		end
		table.insert(lines, "You gain: " .. table.concat(gain, "; "))
		return table.concat(lines, "\n")
	end,
}

-- A button on the screen: rail buttons are named "<Id>Button", HUD pieces by their own name.
function TutorialUI.findUiTarget(name: string): GuiObject?
	local gui = player:FindFirstChildOfClass("PlayerGui")
	if not gui then
		return nil
	end
	local fallback: GuiObject? = nil
	for _, descendant in gui:GetDescendants() do
		if descendant:IsA("GuiObject") then
			if descendant.Name == name .. "Button" then
				return descendant
			elseif descendant.Name == name then
				fallback = descendant
			end
		end
	end
	return fallback
end

function TutorialUI.start()
	local left = require(script.Parent.MainUI).region("LeftColumn")
	if not left then
		warn("[TutorialUI] LeftColumn region missing (MainUI must start first)")
		return
	end
	local card = UIKit.frame(left, {
		Name = "TutorialCard",
		Size = UDim2.fromOffset(298, 168),
		LayoutOrder = 5,
		BackgroundColor3 = C.Cream,
		Visible = false,
	})
	UIKit.corner(card, 8)
	UIKit.stroke(card, C.Line, 1)
	local step = UIKit.label(card, { Name = "Step", Size = UDim2.new(1, -20, 0, 14), Position = UDim2.fromOffset(14, 10), Font = UIKit.Fonts.Title, TextSize = UIKit.Type.Caption, TextColor3 = C.Gold })
	local title = UIKit.label(card, { Name = "Title", Size = UDim2.new(1, -28, 0, 22), Position = UDim2.fromOffset(14, 26), Font = UIKit.Fonts.Title, TextSize = UIKit.Type.Heading + 2, TextColor3 = C.Ink, TextTruncate = Enum.TextTruncate.AtEnd })
	local text = UIKit.label(card, { Name = "Text", Size = UDim2.new(1, -28, 1, -96), Position = UDim2.fromOffset(14, 50), Font = UIKit.Fonts.Soft, TextSize = UIKit.Type.Caption + 1, TextColor3 = C.Muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, RichText = true })
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
	local uiTargetName: string? = nil
	local outline: UIStroke? = nil
	local uiArrow: Frame? = nil
	local uiTargetObject: GuiObject? = nil
	TutorialUI.CurrentTarget = nil :: Instance? -- exposed for tests

	local function markerPosition(): (Vector3?, BasePart?)
		if targetName == "Hamsters" then
			local ball = TutorialUI.pickBall()
			return if ball then ball.Pos else nil, nil
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
			uiTargetName = nil
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
			card.Size = UDim2.fromOffset(298, if def.Id == "altar" then 252 else 168)
			UIKit.tween(progress, 0.3, { Size = UDim2.new(tutorial.Step / #TutorialConfig.Steps, 0, 0, 2) })
			action.Visible = def.Kind == "Ack"
			UIKit.setButtonContent(action, nil, def.Button or "Next", C.White)
			card.Visible = true
			targetName = def.Target or def.Pointer
			TutorialUI.TargetName = targetName
			TutorialUI.UiTargetName = def.UiTarget
			uiTargetName = def.UiTarget
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

	local function clearUiMarker()
		if outline then
			outline:Destroy()
			outline = nil
		end
		if uiArrow then
			uiArrow:Destroy()
			uiArrow = nil
		end
		uiTargetObject = nil
		TutorialUI.UiTargetObject = nil
	end

	-- a gold outline and an arrow on the real button (never a copy of it)
	local function updateUiMarker()
		if not uiTargetName then
			if uiTargetObject then
				clearUiMarker()
			end
			return
		end
		local target = TutorialUI.findUiTarget(uiTargetName)
		if target ~= uiTargetObject then
			clearUiMarker()
			uiTargetObject = target
			TutorialUI.UiTargetObject = target
			if target then
				local stroke = Instance.new("UIStroke")
				stroke.Name = "TutorialOutline"
				stroke.Color = C.Gold
				stroke.Thickness = 4
				stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
				stroke.Parent = target
				outline = stroke
				local holder = Instance.new("Frame")
				holder.Name = "TutorialArrow"
				holder.BackgroundTransparency = 1
				holder.Size = UDim2.fromOffset(34, 34)
				holder.ZIndex = 50
				local onRight = target.AbsolutePosition.X > (Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize.X * 0.6 or 0)
				holder.AnchorPoint = if onRight then Vector2.new(1, 0.5) else Vector2.new(0.5, 0)
				holder.Position = if onRight then UDim2.new(0, -6, 0.5, 0) else UDim2.new(0.5, 0, 1, 6)
				holder.Rotation = if onRight then 90 else 0
				local icon = UIKit.icon(holder, "arrowup", { Size = UDim2.fromOffset(32, 32), Color = C.Gold, ZIndex = 51 })
				icon.Position = UDim2.fromOffset(1, 1)
				holder.Parent = target
				uiArrow = holder
			end
		end
		if outline then
			outline.Thickness = 3.5 + math.sin(os.clock() * 5) * 1.2
		end
	end

	local lastDynamic = 0

	-- the marker follows the tagged object (or the nearest ball); a gentle bob, only while there is a target
	RunService.Heartbeat:Connect(function()
		updateUiMarker()
		if currentStep and currentStep.Dynamic and os.clock() - lastDynamic > 0.4 then
			lastDynamic = os.clock()
			local build = TutorialUI.Dynamic[currentStep.Dynamic]
			if build then
				local ok, result = pcall(build)
				if ok and type(result) == "string" then
					text.Text = result
				end
			end
		end
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
