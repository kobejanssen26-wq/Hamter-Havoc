--[[
	MainUI: the always-visible HUD (dark graphite style, see Theme.luau).
	  top-centre     four indicators below the Roblox top bar: Cash, Cash/s, Diamonds, Rebirths
	  top-right      small icon buttons with tooltips: Quests (+ daily reward), Hamsters, Shop, Settings
	  under the bar  active boost chips, then toast messages
	  bottom-centre  the hotbar (HotbarUI), the "grab this hamster" prompt, an occasional event strip
	Everything else (Upgrades, Rebirth, Index, Daily mailbox...) is opened from objects in your own plot.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local AchievementConfig = require(Modules:WaitForChild("AchievementConfig"))
local DailyRewardConfig = require(Modules:WaitForChild("DailyRewardConfig"))
local Format = require(Modules:WaitForChild("Format"))
local QuestConfig = require(Modules:WaitForChild("QuestConfig"))
local RarityConfig = require(Modules:WaitForChild("RarityConfig"))
local RebirthConfig = require(Modules:WaitForChild("RebirthConfig"))
local ShopConfig = require(Modules:WaitForChild("ShopConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local WorldController = require(script.Parent.Parent.Controllers.WorldController)
local CursorController = require(script.Parent.Parent.Controllers.CursorController)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local MainUI = {}

local C = UIKit.Colors
local player = Players.LocalPlayer

local TOAST_COLORS = {
	info = Theme.Colors.Text,
	success = Theme.Colors.Cash,
	error = Color3.fromRGB(236, 120, 116),
	reward = Theme.Colors.Gold,
}

local TOAST_ICONS = {
	info = "star",
	success = "check",
	error = "cross",
	reward = "gift",
}

local TIPS = {
	"Hamster balls roll down the road - get close and press [E] to claim one!",
	"A claimed hamster is NOT yours yet: it must reach the pad in your apartment!",
	"See a hamster rolling to someone else's house? Press [E] to steal it, then run it home.",
	"Press [Q] to slap a thief - a hit carrier can drop the hamster.",
	"Your security gate switches off after a while - press [E] at the gate panel to turn it on again.",
	"Rarer hamsters roll faster. Upgrade Collection Range to catch them!",
	"Your hamsters run on wheels in your apartment and earn cash for you.",
	"Every rebirth gives a permanent bonus - and new floors for your tower!",
	"Fill the Hamster Index - every hamster gives a permanent coin bonus!",
	"Spawn Luck makes rare hamsters appear more often.",
	"Use the elevator in your tower to reach upper floors.",
}

local openButtons: { [string]: TextButton } = {}
local dots: { [string]: Frame } = {}

-- Layout numbers shared with the hotbar so nothing overlaps.
MainUI.HotbarClearance = 88 -- pixels the bottom of the screen reserves for the hotbar

local function openPanel(name: string, focus: string?)
	local panel = UIKit.getPanel(name)
	if panel then
		panel.Focus = focus
		if panel.IsOpen and not focus then
			panel:Close()
		else
			if panel.IsOpen then
				panel:Close()
			end
			panel:Open()
		end
	end
end

function MainUI.open(name: string, focus: string?)
	local panel = UIKit.getPanel(name)
	if panel then
		panel.Focus = focus
		if panel.IsOpen then
			for _, callback in panel.OnOpen do
				task.spawn(callback)
			end
		else
			panel:Open()
		end
	end
end

---------------------------------------------------------------------------

function MainUI.start()
	local gui = UIKit.new("ScreenGui", {
		Name = "MainUI",
		ResetOnSpawn = false,
		DisplayOrder = 1,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	local scales: { UIScale } = {}
	local function addScale(parent: Instance): UIScale
		local scale = UIKit.new("UIScale", { Scale = 1 }, parent)
		table.insert(scales, scale)
		return scale
	end
	local function updateScales()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local value = math.clamp(math.min(viewport.X / 1180, viewport.Y / 660), 0.5, 1.1)
		for _, scale in scales do
			scale.Scale = value
		end
	end

	local inset = UIKit.GuiService:GetGuiInset().Y
	local topY = inset + Theme.Hud.TopMargin
	local touch = UIKit.isTouch()

	-- active boosts: small chips centred under the indicator bar
	local boostRow = UIKit.frame(gui, { Name = "Boosts", Size = UDim2.fromOffset(520, 30), Position = UDim2.new(0.5, 0, 0, topY + 44), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1 })
	addScale(boostRow)
	UIKit.list(boostRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center)

	-----------------------------------------------------------------------
	-- bottom-centre: occasional event strip + toasts
	-----------------------------------------------------------------------
	local center = UIKit.frame(gui, {
		Name = "Center",
		Size = UDim2.fromOffset(560, 36),
		Position = UDim2.new(0.5, 0, 1, -(MainUI.HotbarClearance + 74)),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = C.Cream,
		BackgroundTransparency = 0.1,
	})
	UIKit.corner(center, 8)
	UIKit.stroke(center, C.Line, 1.5)
	addScale(center)
	local stripLabel = UIKit.label(center, {
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 14,
		TextColor3 = C.Ink,
		Font = UIKit.Fonts.Soft,
		Text = TIPS[1],
		TextWrapped = true,
	})

	local toastHolder = UIKit.frame(gui, {
		Name = "Toasts",
		Size = UDim2.fromOffset(520, 200),
		Position = UDim2.new(0.5, 0, 0, topY + 84),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
	})
	addScale(toastHolder)
	UIKit.list(toastHolder, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center)
	local toastCount = 0

	function MainUI.toast(text: string, kind: string?)
		local notificationsOn = DataController.setting("Notifications")
		if notificationsOn ~= true and kind ~= "error" then
			return
		end
		toastCount += 1
		local order = toastCount
		local accent = TOAST_COLORS[kind or "info"] or C.Ink
		local frame = UIKit.frame(toastHolder, {
			Size = UDim2.fromOffset(0, 36),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = C.Cream,
			BackgroundTransparency = 0.04,
			LayoutOrder = order,
		})
		UIKit.corner(frame, 8)
		UIKit.stroke(frame, UIKit.Colors.Line, 1.5)
		UIKit.padding(frame, 12, 0)
		UIKit.list(frame, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
		UIKit.icon(frame, TOAST_ICONS[kind or "info"] or "star", { Size = UDim2.fromOffset(18, 18), LayoutOrder = 1 })
		local label = UIKit.label(frame, {
			LayoutOrder = 2,
			Size = UDim2.fromOffset(0, 36),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = text,
			TextSize = 15,
			TextColor3 = accent,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		frame.Position = UDim2.fromOffset(0, -10)
		label.TextTransparency = 1
		frame.BackgroundTransparency = 1
		UIKit.tween(frame, 0.2, { BackgroundTransparency = 0.04 })
		UIKit.tween(label, 0.2, { TextTransparency = 0 })
		-- keep at most 4 toasts
		local children = {}
		for _, child in toastHolder:GetChildren() do
			if child:IsA("Frame") then
				table.insert(children, child)
			end
		end
		if #children > 4 then
			table.sort(children, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			children[1]:Destroy()
		end
		task.delay(4.2, function()
			if frame.Parent then
				UIKit.tween(label, 0.3, { TextTransparency = 1 })
				UIKit.tween(frame, 0.3, { BackgroundTransparency = 1 })
				task.delay(0.35, function()
					frame:Destroy()
				end)
			end
		end)
	end

	Remotes.event("Notify").OnClientEvent:Connect(function(text: string, kind: string)
		MainUI.toast(text, kind)
		if kind == "error" then
			AudioController.play("Error")
		elseif kind == "reward" then
			AudioController.play("Reward")
		end
	end)

	-----------------------------------------------------------------------
	-- top-centre: the four indicators
	-----------------------------------------------------------------------
	local topBar = UIKit.frame(gui, {
		Name = "TopBar",
		Size = UDim2.fromOffset(500, 36),
		Position = UDim2.new(0.5, 0, 0, topY),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundTransparency = 1,
	})
	addScale(topBar)
	UIKit.list(topBar, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local coinsPill = UIKit.pill(topBar, { Icon = "coin", Color = C.Cash, Size = UDim2.fromOffset(142, 34), LayoutOrder = 1 })
	local incomePill = UIKit.pill(topBar, { Icon = "bolt", Color = C.Gold, Size = UDim2.fromOffset(112, 34), LayoutOrder = 2 })
	local gemsPill = UIKit.pill(topBar, { Icon = "gem", Color = C.Purple, Size = UDim2.fromOffset(124, 34), LayoutOrder = 3, OnPlus = function() MainUI.open("Shop", "Diamonds") end })
	local rebirthPill = UIKit.pill(topBar, { Icon = "rebirth", Color = Color3.fromRGB(236, 168, 70), Size = UDim2.fromOffset(104, 34), LayoutOrder = 4 })
	UIKit.tooltip(coinsPill.Frame, "Cash", "Below")
	UIKit.tooltip(incomePill.Frame, "Cash per second", "Below")
	UIKit.tooltip(gemsPill.Frame, "Diamonds", "Below")
	UIKit.tooltip(rebirthPill.Frame, "Rebirths completed", "Below")

	-----------------------------------------------------------------------
	-- top-right: small icon buttons (Quests, Hamsters, Shop, Settings)
	-----------------------------------------------------------------------
	local buttonSize = if touch then Theme.Hud.IconButtonTouch else Theme.Hud.IconButton
	local cluster = UIKit.frame(gui, {
		Name = "Shortcuts",
		Size = UDim2.fromOffset(buttonSize, 4 * buttonSize + 3 * 8),
		Position = UDim2.new(1, -Theme.Hud.SideMargin, 0, topY),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
	})
	UIKit.list(cluster, Enum.FillDirection.Vertical, 8)
	local clusterScale = addScale(cluster)
	clusterScale.Name = "ClusterScale"

	local function iconButton(icon: string, tip: string, panelName: string, order: number, focus: string?)
		local button = UIKit.button(cluster, {
			Text = "",
			Size = UDim2.fromOffset(buttonSize, buttonSize),
			Color = C.Cream,
			Corner = 99,
			LayoutOrder = order,
			Name = panelName .. "Button",
			OnClick = function()
				openPanel(panelName, focus)
			end,
		})
		button.BackgroundTransparency = 0.06
		UIKit.icon(button, icon, { Size = UDim2.fromOffset(buttonSize * 0.58, buttonSize * 0.58), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3 })
		dots[panelName] = UIKit.notifyDot(button)
		openButtons[panelName] = button
		UIKit.tooltip(button, tip, "Left")
	end
	iconButton("scroll", "Daily Quests", "Quests", 1)
	iconButton("hamster", "Hamsters", "Inventory", 2)
	iconButton("bag", "Shop", "Shop", 3)
	iconButton("gear", "Settings", "Settings", 4)

	-- the button of the open menu is highlighted
	task.spawn(function()
		while true do
			for name, button in openButtons do
				local panel = UIKit.getPanel(name)
				UIKit.setButtonColor(button, if panel and panel.IsOpen then C.Peach else C.Cream)
			end
			task.wait(0.25)
		end
	end)

	-- first person: the mouse is locked, so tell the player how to reach the buttons
	local fpHint = UIKit.label(gui, {
		Size = UDim2.fromOffset(300, 20),
		Position = UDim2.new(0.5, 0, 1, -(MainUI.HotbarClearance + 2)),
		AnchorPoint = Vector2.new(0.5, 1),
		Text = "Hold ALT to use the mouse",
		TextSize = 13,
		TextColor3 = C.White,
		TextTransparency = 0.15,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	})
	UIKit.new("UIStroke", { Color = C.Dim, Thickness = 1.5 }, fpHint)
	task.spawn(function()
		while true do
			fpHint.Visible = not UIKit.isTouch() and CursorController.isFirstPerson() and not CursorController.isHolding()
			task.wait(0.3)
		end
	end)

	-----------------------------------------------------------------------
	-- grab prompt
	-----------------------------------------------------------------------
	local prompt = UIKit.frame(gui, {
		Name = "GrabPrompt",
		Size = UDim2.fromOffset(420, 52),
		Position = UDim2.new(0.5, 0, 1, -(MainUI.HotbarClearance + 22)),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = C.Cream,
		BackgroundTransparency = 0.04,
		Visible = false,
	})
	UIKit.corner(prompt, 10)
	local promptStroke = UIKit.stroke(prompt, C.Gold, 2)
	addScale(prompt)
	local keyLabel = UIKit.label(prompt, {
		Size = UDim2.fromOffset(38, 38),
		Position = UDim2.fromOffset(8, 7),
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Card,
		Text = if UIKit.isTouch() then "TAP" else "E",
		TextSize = if UIKit.isTouch() then 12 else 20,
		Font = UIKit.Fonts.Big,
		TextColor3 = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	UIKit.corner(keyLabel, 8)
	UIKit.stroke(keyLabel, C.GoldLine, 1.5)
	local priceChip = UIKit.frame(prompt, { Size = UDim2.fromOffset(104, 34), Position = UDim2.new(1, -9, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = C.CreamDark, Visible = false })
	UIKit.corner(priceChip, 8)
	UIKit.stroke(priceChip, C.Line, 1.5)
	UIKit.icon(priceChip, "coin", { Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(8, 7) })
	local priceLabel = UIKit.label(priceChip, { Size = UDim2.new(1, -36, 1, 0), Position = UDim2.fromOffset(32, 0), Font = UIKit.Fonts.Title, TextSize = 17, TextColor3 = C.Cash, Text = "" })
	local promptText = UIKit.label(prompt, {
		Size = UDim2.new(1, -70, 1, 0),
		Position = UDim2.fromOffset(56, 0),
		TextSize = 16,
		TextColor3 = C.Ink,
		Font = UIKit.Fonts.Title,
		Text = "",
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local promptClick = UIKit.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, prompt)
	promptClick.Activated:Connect(function()
		WorldController.interact()
	end)

	WorldController.onTargetChanged(function(info)
		if not info then
			prompt.Visible = false
			return
		end
		local definition = RarityConfig.ById[info.Species.Rarity]
		local color = UIKit.rarityColor(definition)
		local index = DataController.get("Index") or {}
		local name = if definition.Hidden and not index[info.Species.Id] then "???" else info.Species.Name
		promptStroke.Color = color
		local colored = string.format('<font color="#%s">%s %s</font>', color:ToHex(), definition.Name, name)
		priceChip.Visible = info.Action == "Claim"
		promptText.Size = UDim2.new(1, if info.Action == "Claim" then -176 else -70, 1, 0)
		if info.Action == "Claim" then
			promptText.Text = string.format("Claim %s", colored)
			priceLabel.Text = Format.short(info.Price)
			priceLabel.TextColor3 = if info.Affordable then C.Cash else Color3.fromRGB(226, 106, 104)
		elseif info.Action == "Steal" then
			promptStroke.Color = C.Red
			promptText.Text = string.format("Steal %s  from %s", colored, info.OwnerName)
		else
			promptText.Text = string.format("%s %s", info.Action, colored)
		end
		prompt.Visible = true
		prompt.Size = UDim2.fromOffset(340, 46)
		UIKit.tween(prompt, 0.16, { Size = UDim2.fromOffset(420, 52) })
	end)

	updateScales()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScales)
	end

	-----------------------------------------------------------------------
	-- live updates
	-----------------------------------------------------------------------
	local shown = { Coins = 0, Gems = 0 }
	local actual = { Coins = 0, Gems = 0 }
	local pills = { Coins = coinsPill, Gems = gemsPill }

	local function readAttributes()
		actual.Coins = DataController.coins()
		actual.Gems = DataController.gems()
	end
	readAttributes()
	shown.Coins, shown.Gems = actual.Coins, actual.Gems
	for _, name in { "Coins", "Gems" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			local before = actual[name]
			actual[name] = player:GetAttribute(name) or 0
			if name ~= "Coins" and actual[name] > before then
				local value = pills[name].Value
				value.TextColor3 = C.White
				UIKit.tween(value, 0.5, { TextColor3 = C.Purple })
			end
		end)
	end

	RunService.RenderStepped:Connect(function(dt)
		for name, pill in pills do
			local target = actual[name]
			local current = shown[name]
			if current ~= target then
				local nextValue = current + (target - current) * math.min(1, dt * 9)
				if math.abs(target - nextValue) < 0.5 then
					nextValue = target
				end
				shown[name] = nextValue
			end
			pill.Value.Text = Format.short(shown[name])
		end
	end)

	local function refreshStatic()
		local derived = DataController.derived()
		local rebirths = DataController.get("Rebirths") or 0
		rebirthPill.Value.Text = "Rebirth " .. rebirths
		incomePill.Value.Text = Format.short(derived.IncomePerSecond or 0) .. "/s"
	end

	-- boosts + strip + notification dots (once per second)
	local tipIndex = 1
	local lastTip = os.clock() - 40
	local function refreshDynamic()
		local now = DataController.now()
		local boosts = DataController.get("Boosts") or {}

		for _, child in boostRow:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local order = 0
		local firstBoostText = nil
		for boostId, info in ShopConfig.Boosts do
			local expires = boosts[boostId]
			if expires and expires > now then
				order += 1
				local chip = UIKit.frame(boostRow, { Size = UDim2.fromOffset(92, 28), LayoutOrder = order })
				UIKit.vivid(chip, C.Green, { Corner = 8, Outline = 1.5 })
				UIKit.icon(chip, info.Icon, { Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(7, 5), ZIndex = 3 })
				UIKit.label(chip, {
					Size = UDim2.new(1, -32, 1, 0),
					Position = UDim2.fromOffset(30, 0),
					Text = Format.clock(expires - now),
					Font = UIKit.Fonts.Title,
					TextSize = 14,
					TextColor3 = C.Ink,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 3,
				})
				firstBoostText = firstBoostText or string.format("%s active: %s left", info.Name, Format.clock(expires - now))
			end
		end

		-- strip text: boost > rebirth ready > rotating tips
		local rebirths = DataController.get("Rebirths") or 0
		local text = nil
		if firstBoostText then
			text = firstBoostText
		elseif rebirths < RebirthConfig.MaxRebirths and DataController.rebirthCheck(rebirths + 1) then
			text = "You can REBIRTH! Visit the Rebirth altar in your plot."
		end
		if not text then
			-- a tip pops up for 8 seconds, then the bar disappears for 40 seconds (less clutter)
			local sinceTip = os.clock() - lastTip
			if sinceTip > 48 then
				lastTip = os.clock()
				tipIndex = tipIndex % #TIPS + 1
				sinceTip = 0
			end
			if sinceTip < 8 then
				text = TIPS[tipIndex]
			end
		end
		center.Visible = text ~= nil
		if text then
			stripLabel.Text = text
		end

		-- notification dots: Quests (daily reward or a quest / achievement ready), Hamsters (nothing), Shop (nothing)
		local data = DataController.Data
		local claimable = false
		if data.Daily then
			local _, canClaim = DailyRewardConfig.state(data.Daily, now)
			claimable = canClaim
		end
		if not claimable and data.Quests and data.Achievements and data.Stats and data.Index then
			for _, quest in QuestConfig.Quests do
				if not data.Quests.Claimed[quest.Id] and QuestConfig.isComplete(data, quest) then
					claimable = true
					break
				end
			end
			if not claimable then
				for _, achievement in AchievementConfig.List do
					if not data.Achievements.Claimed[achievement.Id] and QuestConfig.getStat(data, achievement.Stat) >= achievement.Target then
						claimable = true
						break
					end
				end
			end
		end
		dots.Quests.Visible = claimable
	end

	DataController.onChanged(function()
		refreshStatic()
		refreshDynamic()
	end)
	task.spawn(function()
		while true do
			refreshStatic()
			if DataController.Ready then
				refreshDynamic()
			end
			task.wait(1)
		end
	end)

	-- menus opened from world prompts (houses, plaza stalls)
	Remotes.event("OpenUI").OnClientEvent:Connect(function(name: string, focus: string?)
		MainUI.open(name, focus)
	end)
end

return MainUI
