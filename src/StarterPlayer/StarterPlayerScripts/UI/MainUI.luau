--[[
	MainUI: the always-visible HUD.
	  top-left     profile chip, Coins (+ income per second), Gems, Rebirth Tokens, active boosts
	  left         navigation: Hamsters, Index, Rebirth, Upgrades, Daily, Quests, Shop, Settings
	  top-centre   tip strip and notifications
	  top-right    promo codes
	  bottom       the "claim / steal this hamster" prompt
	  centre       a small crosshair while you are in first person (mouse locked)
	Every icon is a UI/Icons icon (no emoji).
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
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
local UIKit = require(script.Parent.UIKit)

local MainUI = {}

local C = UIKit.Colors
local player = Players.LocalPlayer

local TOASTS = {
	info = { Icon = "Info", Color = C.Sky },
	success = { Icon = "Check", Color = C.Mint },
	error = { Icon = "Warning", Color = C.Red },
	reward = { Icon = "Star", Color = C.Gold },
}

local TIPS = {
	"Hamster balls roll down the road - get close and press [E] to claim one!",
	"A claimed hamster is NOT yours yet: it must reach the pad in your apartment.",
	"See a hamster rolling to someone else's apartment? Press [E] to steal it and run it home.",
	"Press [Q] to slap a thief - a hit carrier can drop the hamster.",
	"Your security gate switches off after a while - press [E] at the gate panel to turn it on again.",
	"Rarer hamsters roll faster. Upgrade Collection Range to catch them!",
	"Your hamsters run on wheels in your apartment and earn coins for you.",
	"Rebirth for permanent slots, income and new floors for your apartment.",
	"Fill the Hamster Index - every new hamster gives a permanent coin bonus.",
	"Use the lift in your apartment to visit your upper floors.",
}

local openButtons: { [string]: GuiButton } = {}
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

local NAV = {
	{ Panel = "Inventory", Text = "Hamsters", Icon = "Hamster", Color = C.Peach },
	{ Panel = "Index", Text = "Index", Icon = "Index", Color = C.Sky },
	{ Panel = "Rebirth", Text = "Rebirth", Icon = "Rebirth", Color = C.Orange },
	{ Panel = "Upgrades", Text = "Upgrades", Icon = "Upgrade", Color = C.Green },
	{ Panel = "Daily", Text = "Daily", Icon = "Daily", Color = C.Pink },
	{ Panel = "Quests", Text = "Quests", Icon = "Quests", Color = C.BrownLight },
	{ Panel = "Shop", Text = "Shop", Icon = "Shop", Color = C.Purple },
	{ Panel = "Settings", Text = "Settings", Icon = "Settings", Color = Color3.fromRGB(140, 150, 170) },
}

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
		local value = math.clamp(math.min(viewport.X / 1180, viewport.Y / 660), 0.55, 1.1)
		for _, scale in scales do
			scale.Scale = value
		end
	end

	-----------------------------------------------------------------------
	-- top-left: profile chip + currencies
	-----------------------------------------------------------------------
	local wallet = UIKit.frame(gui, {
		Name = "Wallet",
		Size = UDim2.fromOffset(270, 210),
		Position = UDim2.fromOffset(16, 14),
		BackgroundTransparency = 1,
	})
	addScale(wallet)

	local profile = UIKit.frame(wallet, { Size = UDim2.fromOffset(250, 46), BackgroundColor3 = C.White })
	UIKit.corner(profile, 99)
	UIKit.shadow(profile, 22, 3)
	local avatar = UIKit.new("ImageLabel", {
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromOffset(3, 3),
		BackgroundColor3 = C.CreamDark,
		Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", player.UserId),
		ZIndex = 2,
	}, profile)
	UIKit.corner(avatar, 99)
	UIKit.label(profile, {
		Position = UDim2.fromOffset(50, 2),
		Size = UDim2.new(1, -60, 0, 22),
		Font = UIKit.Fonts.Title,
		TextSize = 17,
		TextColor3 = C.Ink,
		Text = player.DisplayName,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 2,
	})
	local rebirthBadge = UIKit.chip(profile, "Rebirth 0", C.Orange, UDim2.fromOffset(84, 18))
	rebirthBadge.Position = UDim2.fromOffset(50, 24)
	rebirthBadge.TextSize = 11
	rebirthBadge.ZIndex = 2
	local multiplierLabel = UIKit.label(profile, {
		Position = UDim2.fromOffset(140, 24),
		Size = UDim2.new(1, -150, 0, 18),
		Font = UIKit.Fonts.Body,
		TextSize = 12,
		TextColor3 = C.Mint,
		Text = "x1 income",
		ZIndex = 2,
	})

	local coinsPill = UIKit.pill(wallet, { Icon = "Coin", Color = C.Gold, Size = UDim2.fromOffset(230, 48) })
	coinsPill.Frame.Position = UDim2.fromOffset(6, 58)
	local incomeRow = UIKit.frame(wallet, { Size = UDim2.fromOffset(200, 22), Position = UDim2.fromOffset(60, 108), BackgroundTransparency = 1 })
	local incomeLabel = UIKit.label(incomeRow, {
		Size = UDim2.fromScale(1, 1),
		Font = UIKit.Fonts.Title,
		TextSize = 16,
		TextColor3 = C.White,
		Text = "+$0/s",
	})
	UIKit.new("UIStroke", { Color = C.Shadow, Thickness = 1.6, Transparency = 0.25 }, incomeLabel)
	local gemsPill = UIKit.pill(wallet, { Icon = "Gem", Color = C.Sky, Size = UDim2.fromOffset(124, 38) })
	gemsPill.Frame.Position = UDim2.fromOffset(6, 136)
	local tokensPill = UIKit.pill(wallet, { Icon = "Token", Color = C.Orange, Size = UDim2.fromOffset(98, 38) })
	tokensPill.Frame.Position = UDim2.fromOffset(140, 136)

	-- active boosts under the wallet
	local boostRow = UIKit.frame(gui, { Name = "Boosts", Size = UDim2.fromOffset(300, 30), Position = UDim2.fromOffset(16, 192), BackgroundTransparency = 1 })
	addScale(boostRow)
	UIKit.list(boostRow, Enum.FillDirection.Horizontal, 6)

	-----------------------------------------------------------------------
	-- left: navigation
	-----------------------------------------------------------------------
	local nav = UIKit.frame(gui, {
		Name = "Navigation",
		Size = UDim2.fromOffset(170, 360),
		Position = UDim2.new(0, 16, 0.5, 40),
		AnchorPoint = Vector2.new(0, 0.5),
		BackgroundTransparency = 1,
	})
	addScale(nav)
	UIKit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(78, 82),
		CellPadding = UDim2.fromOffset(10, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		FillDirectionMaxCells = 2,
	}, nav)
	for order, entry in NAV do
		local button = UIKit.button(nav, {
			Text = "",
			Color = C.White,
			Corner = 20,
			LayoutOrder = order,
			Name = entry.Panel .. "Button",
			OnClick = function()
				openPanel(entry.Panel)
			end,
		})
		local edge = button:FindFirstChild("Edge") :: UIStroke?
		if edge then
			edge.Color = UIKit.lighter(entry.Color, 0.3)
			edge.Thickness = 2.5
		end
		UIKit.shadow(button, 20, 4)
		local tint = UIKit.frame(button, { Size = UDim2.new(1, -10, 0, 50), Position = UDim2.fromOffset(5, 5), BackgroundColor3 = UIKit.lighter(entry.Color, 0.78) })
		UIKit.corner(tint, 16)
		UIKit.icon(button, entry.Icon, 42, { Position = UDim2.new(0.5, 0, 0, 9), AnchorPoint = Vector2.new(0.5, 0) })
		UIKit.label(button, {
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.new(0, 0, 1, -24),
			Text = entry.Text,
			TextSize = 13,
			TextColor3 = C.Ink,
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = UIKit.Fonts.Title,
		})
		dots[entry.Panel] = UIKit.notifyDot(button)
		openButtons[entry.Panel] = button
	end

	-----------------------------------------------------------------------
	-- top-right: promo codes
	-----------------------------------------------------------------------
	local codes = UIKit.button(gui, {
		Text = "Codes",
		Icon = "Ticket",
		IconSize = 26,
		Size = UDim2.fromOffset(112, 42),
		Position = UDim2.new(1, -16, 0, 14),
		AnchorPoint = Vector2.new(1, 0),
		Color = C.Purple,
		Corner = 99,
		TextSize = 17,
		Name = "CodesButton",
		OnClick = function()
			openPanel("Codes")
		end,
	})
	addScale(codes)
	openButtons.Codes = codes

	-----------------------------------------------------------------------
	-- top centre: tip strip + toasts
	-----------------------------------------------------------------------
	local center = UIKit.frame(gui, {
		Name = "Center",
		Size = UDim2.fromOffset(560, 40),
		Position = UDim2.new(0.5, 0, 0, 14),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = C.White,
		BackgroundTransparency = 0.08,
	})
	UIKit.corner(center, 99)
	UIKit.shadow(center, 20, 3)
	addScale(center)
	local stripIcon = UIKit.icon(center, "Info", 26, { Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
	local stripLabel = UIKit.label(center, {
		Size = UDim2.new(1, -52, 1, 0),
		Position = UDim2.fromOffset(42, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 14,
		TextColor3 = C.Ink,
		Font = UIKit.Fonts.Body,
		Text = TIPS[1],
		TextWrapped = true,
	})

	local toastHolder = UIKit.frame(gui, {
		Name = "Toasts",
		Size = UDim2.fromOffset(560, 220),
		Position = UDim2.new(0.5, 0, 0, 62),
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
		local style = TOASTS[kind or "info"] or TOASTS.info
		local frame = UIKit.frame(toastHolder, {
			Size = UDim2.fromOffset(0, 40),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = C.White,
			LayoutOrder = toastCount,
		})
		UIKit.corner(frame, 99)
		UIKit.stroke(frame, UIKit.lighter(style.Color, 0.3), 2)
		UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, 44), PaddingRight = UDim.new(0, 18) }, frame)
		local icon = UIKit.icon(frame, style.Icon, 28, { Position = UDim2.new(0, -38, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
		local label = UIKit.label(frame, {
			Size = UDim2.fromOffset(0, 40),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = text,
			TextSize = 15,
			TextColor3 = C.Ink,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		local scale = UIKit.new("UIScale", { Scale = 0.85 }, frame)
		label.TextTransparency = 1
		UIKit.tween(scale, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
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
				UIKit.tween(label, 0.25, { TextTransparency = 1 })
				UIKit.tween(frame, 0.25, { BackgroundTransparency = 1 })
				UIKit.tween(scale, 0.25, { Scale = 0.9 })
				icon.Visible = false
				task.delay(0.3, function()
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
	-- bottom: claim / steal prompt
	-----------------------------------------------------------------------
	local prompt = UIKit.frame(gui, {
		Name = "GrabPrompt",
		Size = UDim2.fromOffset(400, 58),
		Position = UDim2.new(0.5, 0, 1, -40),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = C.White,
		Visible = false,
	})
	UIKit.corner(prompt, 99)
	UIKit.shadow(prompt, 26, 4)
	local promptStroke = UIKit.stroke(prompt, C.Gold, 3)
	addScale(prompt)
	local keyLabel = UIKit.label(prompt, {
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.fromOffset(7, 7),
		BackgroundTransparency = 0,
		BackgroundColor3 = C.Ink,
		Text = if UIKit.isTouch() then "TAP" else "E",
		TextSize = if UIKit.isTouch() then 15 else 24,
		Font = UIKit.Fonts.Title,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	UIKit.corner(keyLabel, 99)
	local promptText = UIKit.label(prompt, {
		Size = UDim2.new(1, -140, 1, 0),
		Position = UDim2.fromOffset(60, 0),
		TextSize = 17,
		TextColor3 = C.Ink,
		Font = UIKit.Fonts.Title,
		Text = "",
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local priceRow, priceLabel = UIKit.amount(prompt, "Coin", "", { Size = UDim2.fromOffset(90, 26), TextSize = 17, Position = UDim2.new(1, -96, 0.5, -13) })
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
		local colored = string.format('<font color="#%s">%s</font>', color:ToHex(), name)
		priceRow.Visible = info.Action == "Claim"
		if info.Action == "Claim" then
			promptText.Text = string.format("Claim %s", colored)
			priceLabel.Text = Format.coins(info.Price)
			priceLabel.TextColor3 = if info.Affordable then C.Ink else C.Red
		elseif info.Action == "Steal" then
			promptStroke.Color = C.Red
			promptText.Text = string.format("Steal %s from %s", colored, info.OwnerName)
		else
			promptText.Text = string.format("%s %s", info.Action, colored)
		end
		prompt.Visible = true
		local scale = prompt:FindFirstChildOfClass("UIScale")
		if scale then
			updateScales()
		end
		prompt.Size = UDim2.fromOffset(340, 52)
		UIKit.tween(prompt, 0.18, { Size = UDim2.fromOffset(400, 58) }, Enum.EasingStyle.Back)
	end)

	-----------------------------------------------------------------------
	-- first person: a small crosshair while the mouse is locked to the centre
	-----------------------------------------------------------------------
	local crosshair = UIKit.frame(gui, {
		Name = "Crosshair",
		Size = UDim2.fromOffset(8, 8),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.White,
		Visible = false,
	})
	UIKit.corner(crosshair, 99)
	UIKit.stroke(crosshair, C.Shadow, 1.5, 0.3)
	RunService.RenderStepped:Connect(function()
		local locked = UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
		crosshair.Visible = locked and not UIKit.anyWindowOpen()
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
	for name, pill in pills do
		pill.Value.Text = if name == "Coins" then Format.coins(shown[name]) else Format.short(shown[name])
	end
	for _, name in { "Coins", "Gems", "Tokens" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			local before = actual[name]
			actual[name] = player:GetAttribute(name) or 0
			if name ~= "Coins" and actual[name] > before then
				local frame = pills[name].Frame
				local pop = frame:FindFirstChild("Pop") :: UIScale? or UIKit.new("UIScale", { Name = "Pop", Scale = 1 }, frame)
				UIKit.tween(pop, 0.1, { Scale = 1.1 })
				task.delay(0.1, function()
					UIKit.tween(pop, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
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
			pill.Value.Text = if name == "Coins" then Format.coins(shown[name]) else Format.short(shown[name])
		end
	end)

	local function refreshStatic()
		local derived = DataController.derived()
		local rebirths = DataController.get("Rebirths") or 0
		rebirthBadge.Text = "Rebirth " .. rebirths
		multiplierLabel.Text = Format.multiplier(derived.IncomeMultiplier or 1) .. " income"
		incomeLabel.Text = "+" .. Format.coins(derived.IncomePerSecond or 0) .. "/s"
	end

	local function rarityOf(speciesId: string): string?
		local species = HamsterDatabase.ById[speciesId]
		return species and species.Rarity
	end

	-- boosts + strip + notification dots (once per second)
	local tipIndex = 1
	local lastTip = 0
	local function refreshDynamic()
		local now = DataController.now()
		local boosts = DataController.get("Boosts") or {}
		local data = DataController.Data

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
				local chip = UIKit.frame(boostRow, { Size = UDim2.fromOffset(92, 28), BackgroundColor3 = C.White, LayoutOrder = order })
				UIKit.corner(chip, 99)
				UIKit.stroke(chip, C.Mint, 2)
				UIKit.icon(chip, info.Icon, 22, { Position = UDim2.new(0, 4, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
				UIKit.label(chip, {
					Size = UDim2.new(1, -30, 1, 0),
					Position = UDim2.fromOffset(28, 0),
					Text = Format.clock(expires - now),
					TextSize = 13,
					TextColor3 = C.Ink,
				})
				firstBoostText = firstBoostText or string.format("%s active: %s left", info.Name, Format.clock(expires - now))
			end
		end

		-- strip text: boost > rebirth ready > rotating tips
		local rebirths = DataController.get("Rebirths") or 0
		local canRebirth = false
		if data.Inventory and rebirths < RebirthConfig.MaxRebirths then
			local _, ready = RebirthConfig.check({ Rebirths = rebirths, Coins = DataController.coins(), Inventory = data.Inventory }, rarityOf)
			canRebirth = ready
		end
		local text, icon = nil, "Info"
		if firstBoostText then
			text, icon = firstBoostText, "Clock"
		elseif canRebirth then
			text, icon = "You can REBIRTH! Open Rebirth or visit the shrine in your yard.", "Rebirth"
		end
		if not text then
			if os.clock() - lastTip > 9 then
				lastTip = os.clock()
				tipIndex = tipIndex % #TIPS + 1
			end
			text = TIPS[tipIndex]
		end
		stripLabel.Text = text
		if stripIcon.Name ~= "Icon_" .. icon then
			stripIcon:Destroy()
			stripIcon = UIKit.icon(center, icon, 26, { Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
		end

		-- dots
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
		dots.Rebirth.Visible = canRebirth
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
		local floors = (DataController.derived().Floors or 1) :: number
		for _, id in UpgradeConfig.Order do
			local definition = UpgradeConfig.Definitions[id]
			local cost = UpgradeConfig.cost(id, upgrades[id] or 0, rebirths)
			if cost and UpgradeConfig.available(id, floors) then
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

	-- menus opened from world prompts (apartments, plaza buildings)
	Remotes.event("OpenUI").OnClientEvent:Connect(function(name: string, focus: string?)
		MainUI.open(name, focus)
	end)
end

return MainUI
