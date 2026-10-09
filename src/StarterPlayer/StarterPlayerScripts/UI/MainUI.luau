--[[
	MainUI: the always-visible HUD.
	  top-left      currency bar: Coins [+], income per second, Gems [+], Tokens
	  left          sidebar with the 8 menus (Hamsters, Upgrades, Rebirth, Index, Daily, Quests, Shop, Settings); the open one lights up
	  top-right     active boosts
	  top-centre    toast messages
	  bottom-centre event bar (boost / rebirth ready; a tip now and then)
	  centre     the "grab this hamster" prompt
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local AchievementConfig = require(Modules:WaitForChild("AchievementConfig"))
local DailyRewardConfig = require(Modules:WaitForChild("DailyRewardConfig"))
local Format = require(Modules:WaitForChild("Format"))
local HamsterDatabase = require(Modules:WaitForChild("HamsterDatabase"))
local QuestConfig = require(Modules:WaitForChild("QuestConfig"))
local RarityConfig = require(Modules:WaitForChild("RarityConfig"))
local RebirthConfig = require(Modules:WaitForChild("RebirthConfig"))
local ShopConfig = require(Modules:WaitForChild("ShopConfig"))
local UpgradeConfig = require(Modules:WaitForChild("UpgradeConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local WorldController = require(script.Parent.Parent.Controllers.WorldController)
local CursorController = require(script.Parent.Parent.Controllers.CursorController)
local UIKit = require(script.Parent.UIKit)

local MainUI = {}

local C = UIKit.Colors
local player = Players.LocalPlayer

local TOAST_COLORS = {
	info = Color3.fromRGB(34, 26, 48),
	success = Color3.fromRGB(24, 150, 60),
	error = Color3.fromRGB(226, 30, 56),
	reward = Color3.fromRGB(205, 120, 0),
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
	"Your hamsters run on wheels in your apartment and earn coins for you.",
	"Every rebirth gives a permanent bonus - and new floors for your tower!",
	"Fill the Hamster Index - every hamster gives a permanent coin bonus!",
	"Spawn Luck makes rare hamsters appear more often.",
	"Use the elevator in your tower to reach upper floors.",
}

local openButtons: { [string]: TextButton } = {}
local dots: { [string]: Frame } = {}

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

	-- active boosts (top-right)
	local boostRow = UIKit.frame(gui, { Name = "Boosts", Size = UDim2.fromOffset(400, 40), Position = UDim2.new(1, -14, 0, 12), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1 })
	addScale(boostRow)
	UIKit.list(boostRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)

	-----------------------------------------------------------------------
	-- top centre: event strip + toasts
	-----------------------------------------------------------------------
	local center = UIKit.frame(gui, {
		Name = "Center",
		Size = UDim2.fromOffset(620, 46),
		Position = UDim2.new(0.5, 0, 1, -14),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.05,
	})
	UIKit.corner(center, 12)
	UIKit.stroke(center, C.BrownDark, 3)
	addScale(center)
	local stripLabel = UIKit.label(center, {
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 16,
		TextColor3 = C.Ink,
		Font = UIKit.Fonts.Title,
		Text = TIPS[1],
		TextWrapped = true,
	})

	local toastHolder = UIKit.frame(gui, {
		Name = "Toasts",
		Size = UDim2.fromOffset(520, 220),
		Position = UDim2.new(0.5, 0, 0, 70),
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
		local frame = UIKit.frame(toastHolder, {
			Size = UDim2.fromOffset(0, 44),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = C.White,
			BackgroundTransparency = 0.02,
			LayoutOrder = order,
		})
		UIKit.corner(frame, 12)
		UIKit.stroke(frame, C.BrownDark, 3)
		UIKit.padding(frame, 14, 0)
		UIKit.list(frame, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
		UIKit.icon(frame, TOAST_ICONS[kind or "info"] or "star", { Size = UDim2.fromOffset(22, 22), LayoutOrder = 1 })
		local label = UIKit.label(frame, {
			LayoutOrder = 2,
			Size = UDim2.fromOffset(0, 44),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = text,
			TextSize = 18,
			TextColor3 = TOAST_COLORS[kind or "info"] or C.White,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		frame.Position = UDim2.fromOffset(0, -10)
		label.TextTransparency = 1
		frame.BackgroundTransparency = 1
		UIKit.tween(frame, 0.2, { BackgroundTransparency = 0.02 })
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
	-- top-left: currency bar (coins / income / gems / tokens)
	-----------------------------------------------------------------------
	local topBar = UIKit.frame(gui, {
		Name = "TopBar",
		Size = UDim2.fromOffset(860, 54),
		Position = UDim2.fromOffset(14, 12),
		BackgroundTransparency = 1,
	})
	addScale(topBar)
	UIKit.list(topBar, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local coinsPill = UIKit.pill(topBar, { Icon = "coin", Color = C.Green, Size = UDim2.fromOffset(230, 52), LayoutOrder = 1, OnPlus = function() openPanel("Shop") end })
	local incomePill = UIKit.pill(topBar, { Icon = "bolt", Color = Color3.fromRGB(255, 170, 0), Size = UDim2.fromOffset(160, 52), LayoutOrder = 2 })
	local gemsPill = UIKit.pill(topBar, { Icon = "gem", Color = C.Purple, Size = UDim2.fromOffset(190, 52), LayoutOrder = 3, OnPlus = function() openPanel("Shop") end })
	local tokensPill = UIKit.pill(topBar, { Icon = "flame", Color = C.Red, Size = UDim2.fromOffset(120, 52), LayoutOrder = 4 })
	local rebirthPill = UIKit.pill(topBar, { Icon = "star", Color = C.Sky, Size = UDim2.fromOffset(120, 52), LayoutOrder = 5 })

	-----------------------------------------------------------------------
	-- left sidebar: the eight main menu buttons
	-----------------------------------------------------------------------
	local sidebar = UIKit.frame(gui, {
		Name = "Sidebar",
		Size = UDim2.fromOffset(176, 8 * 54 + 7 * 8),
		Position = UDim2.new(0, 14, 0.5, 8),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
	})
	UIKit.list(sidebar, Enum.FillDirection.Vertical, 8)
	addScale(sidebar)

	local menuBase: { [string]: Color3 } = {}
	local function menuButton(icon: string, text: string, color: Color3, panelName: string, order: number)
		menuBase[panelName] = color
		local button = UIKit.button(sidebar, {
			Text = "",
			Size = UDim2.new(1, 0, 0, 54),
			Color = color,
			Corner = 12,
			LayoutOrder = order,
			Name = panelName .. "Button",
			OnClick = function()
				openPanel(panelName)
			end,
		})
		UIKit.icon(button, icon, { Size = UDim2.fromOffset(38, 38), Position = UDim2.fromOffset(8, 8), ZIndex = 3 })
		local label = UIKit.label(button, {
			Size = UDim2.new(1, -54, 1, 0),
			Position = UDim2.fromOffset(52, 0),
			Text = string.upper(text),
			TextSize = 23,
			TextColor3 = C.White,
			Font = UIKit.Fonts.Title,
			ZIndex = 3,
		})
		UIKit.cartoon(label, 3)
		dots[panelName] = UIKit.notifyDot(button)
		openButtons[panelName] = button
	end
	menuButton("hamster", "Hamsters", C.Peach, "Inventory", 1)
	menuButton("arrowup", "Upgrades", C.Green, "Upgrades", 2)
	menuButton("flame", "Rebirth", C.Red, "Rebirth", 3)
	menuButton("book", "Index", C.Sky, "Index", 4)
	menuButton("gift", "Daily", C.Pink, "Daily", 5)
	menuButton("scroll", "Quests", C.Purple, "Quests", 6)
	menuButton("bag", "Shop", Color3.fromRGB(255, 190, 0), "Shop", 7)
	menuButton("gear", "Settings", Color3.fromRGB(120, 132, 168), "Settings", 8)

	-- the button of the open menu turns white
	task.spawn(function()
		while true do
			for name, button in openButtons do
				local panel = UIKit.getPanel(name)
				UIKit.setButtonColor(button, if panel and panel.IsOpen then Color3.fromRGB(255, 255, 255) else menuBase[name])
			end
			task.wait(0.25)
		end
	end)

	-- first person: the mouse is locked, so tell the player how to reach the buttons
	local fpHint = UIKit.label(gui, {
		Size = UDim2.fromOffset(300, 20),
		Position = UDim2.new(0.5, 0, 1, -62),
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
		Size = UDim2.fromOffset(440, 60),
		Position = UDim2.new(0.5, 0, 1, -66),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = C.White,
		Visible = false,
	})
	UIKit.corner(prompt, 16)
	local promptStroke = UIKit.stroke(prompt, C.Gold, 5)
	addScale(prompt)
	local keyLabel = UIKit.label(prompt, {
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.fromOffset(8, 7),
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Gold,
		Text = if UIKit.isTouch() then "TAP" else "E",
		TextSize = 28,
		Font = UIKit.Fonts.Big,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	UIKit.corner(keyLabel, 10)
	UIKit.stroke(keyLabel, C.BrownDark, 3)
	UIKit.cartoon(keyLabel, 2.5)
	local priceChip = UIKit.frame(prompt, { Size = UDim2.fromOffset(112, 38), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), BackgroundColor3 = C.Green, Visible = false })
	UIKit.corner(priceChip, 10)
	UIKit.stroke(priceChip, C.BrownDark, 3)
	UIKit.icon(priceChip, "coin", { Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(8, 7) })
	local priceLabel = UIKit.label(priceChip, { Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(36, 0), Font = UIKit.Fonts.Title, TextSize = 22, TextColor3 = C.White, Text = "" })
	UIKit.cartoon(priceLabel, 2.5)
	local promptText = UIKit.label(prompt, {
		Size = UDim2.new(1, -70, 1, 0),
		Position = UDim2.fromOffset(62, 0),
		TextSize = 20,
		TextColor3 = C.Ink,
		Font = UIKit.Fonts.Title,
		Text = "",
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
		promptText.Size = UDim2.new(1, if info.Action == "Claim" then -190 else -70, 1, 0)
		if info.Action == "Claim" then
			promptText.Text = string.format("Claim %s", colored)
			priceLabel.Text = Format.short(info.Price)
			priceLabel.TextColor3 = if info.Affordable then C.White else Color3.fromRGB(255, 190, 190)
		elseif info.Action == "Steal" then
			promptStroke.Color = C.Red
			promptText.Text = string.format("Steal %s  from %s", colored, info.OwnerName)
		else
			promptText.Text = string.format("%s %s", info.Action, colored)
		end
		prompt.Visible = true
		prompt.Size = UDim2.fromOffset(300, 50)
		UIKit.tween(prompt, 0.18, { Size = UDim2.fromOffset(440, 60) }, Enum.EasingStyle.Back)
	end)

	updateScales()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScales)
	end

	-----------------------------------------------------------------------
	-- live updates
	-----------------------------------------------------------------------
	local shown = { Coins = 0, Gems = 0, Tokens = 0 }
	local actual = { Coins = 0, Gems = 0, Tokens = 0 }
	local pills = { Coins = coinsPill, Gems = gemsPill, Tokens = tokensPill }

	local function readAttributes()
		actual.Coins = DataController.coins()
		actual.Gems = DataController.gems()
		actual.Tokens = DataController.tokens()
	end
	readAttributes()
	shown.Coins, shown.Gems, shown.Tokens = actual.Coins, actual.Gems, actual.Tokens
	for _, name in { "Coins", "Gems", "Tokens" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			local before = actual[name]
			actual[name] = player:GetAttribute(name) or 0
			if name ~= "Coins" and actual[name] > before then
				local label = pills[name].Frame
				UIKit.tween(label, 0.1, { Size = label.Size + UDim2.fromOffset(8, 4) })
				task.delay(0.1, function()
					UIKit.tween(label, 0.15, { Size = label.Size - UDim2.fromOffset(8, 4) }, Enum.EasingStyle.Back)
				end)
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
		rebirthPill.Value.Text = "R" .. rebirths
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
				local chip = UIKit.frame(boostRow, { Size = UDim2.fromOffset(112, 38), LayoutOrder = order })
				UIKit.vivid(chip, C.Green, { Corner = 10, Outline = 3 })
				UIKit.icon(chip, info.Icon, { Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(7, 6), ZIndex = 3 })
				UIKit.cartoon(UIKit.label(chip, {
					Size = UDim2.new(1, -38, 1, 0),
					Position = UDim2.fromOffset(36, 0),
					Text = Format.clock(expires - now),
					Font = UIKit.Fonts.Title,
					TextSize = 19,
					TextColor3 = C.White,
					TextXAlignment = Enum.TextXAlignment.Left,
					ZIndex = 3,
				}), 2.5)
				firstBoostText = firstBoostText or string.format("%s active: %s left", info.Name, Format.clock(expires - now))
			end
		end

		-- strip text: boost > rebirth ready > rotating tips
		local rebirths = DataController.get("Rebirths") or 0
		local text = nil
		if firstBoostText then
			text = firstBoostText
		elseif rebirths < RebirthConfig.MaxRebirths and DataController.rebirthCheck(rebirths + 1) then
			text = "You can REBIRTH! Press the Rebirth button or visit your altar."
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

		-- dots
		local data = DataController.Data
		if data.Daily then
			local _, canClaim = DailyRewardConfig.state(data.Daily, now)
			dots.Daily.Visible = canClaim
		end
		if data.Quests and data.Achievements and data.Stats and data.Index then
			local claimable = false
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
			dots.Quests.Visible = claimable
		end
		dots.Rebirth.Visible = rebirths < RebirthConfig.MaxRebirths and DataController.rebirthCheck(rebirths + 1)
		if data.IndexRewards and data.Index then
			local claimableIndex = false
			for _, rarityId in RarityConfig.Order do
				if not data.IndexRewards[rarityId] and #HamsterDatabase.Spawnable[rarityId] > 0 then
					local complete = true
					for _, species in HamsterDatabase.Spawnable[rarityId] do
						if not data.Index[species.Id] then
							complete = false
							break
						end
					end
					if complete then
						claimableIndex = true
						break
					end
				end
			end
			dots.Index.Visible = claimableIndex
		end
		local affordable = false
		local upgrades = data.Upgrades or {}
		for _, id in UpgradeConfig.Order do
			local definition = UpgradeConfig.Definitions[id]
			local cost = UpgradeConfig.cost(id, upgrades[id] or 0, DataController.get("Rebirths") or 0)
			if cost then
				local balance = if definition.Currency == "Tokens" then DataController.tokens() else DataController.coins()
				if balance >= cost then
					affordable = true
					break
				end
			end
		end
		dots.Upgrades.Visible = affordable
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
