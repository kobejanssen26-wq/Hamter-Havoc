--[[
	MainUI: the always-visible HUD.
	  top-left   profile card (avatar, name, rebirth badge, income) + active boosts
	  top-centre event strip (tips / countdowns) and toast messages
	  top-right  Settings, Codes, Shop
	  bottom     Coins / Gems / Tokens + Rebirth, Index, Hamsters, Upgrades, Quests, Daily
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
local UIKit = require(script.Parent.UIKit)

local MainUI = {}

local C = UIKit.Colors
local player = Players.LocalPlayer

local TOAST_COLORS = {
	info = C.White,
	success = Color3.fromRGB(150, 255, 175),
	error = Color3.fromRGB(255, 140, 140),
	reward = C.Gold,
}

local TIPS = {
	"🐹 Hamsters run past the plaza - get close and press [E] to grab one!",
	"💡 Rarer hamsters run faster. Upgrade Collection Range to catch them!",
	"🏠 Your best hamsters earn coins while they sit on your house shelf.",
	"🔥 Reach the coin goal and visit your Rebirth Altar for permanent boosts.",
	"📖 Fill the Hamster Index - every hamster gives a permanent coin bonus!",
	"🍀 Spawn Luck makes rare hamsters appear more often.",
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

	-----------------------------------------------------------------------
	-- profile card (top-left)
	-----------------------------------------------------------------------
	local profile = UIKit.frame(gui, {
		Name = "Profile",
		Size = UDim2.fromOffset(300, 92),
		Position = UDim2.fromOffset(14, 12),
		BackgroundColor3 = C.Dim,
		BackgroundTransparency = 0.18,
	})
	UIKit.corner(profile, 20)
	UIKit.stroke(profile, C.BrownLight, 3)
	addScale(profile).Scale = 1
	profile.AnchorPoint = Vector2.zero

	local avatar = UIKit.new("ImageLabel", {
		Size = UDim2.fromOffset(72, 72),
		Position = UDim2.fromOffset(10, 10),
		BackgroundColor3 = C.CreamDark,
		Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", player.UserId),
	}, profile)
	UIKit.corner(avatar, 99)
	UIKit.stroke(avatar, C.Gold, 3)

	UIKit.label(profile, {
		Position = UDim2.fromOffset(92, 8),
		Size = UDim2.new(1, -100, 0, 26),
		Font = UIKit.Fonts.Title,
		TextSize = 20,
		TextColor3 = C.White,
		Text = player.DisplayName,
		TextTruncate = Enum.TextTruncate.AtEnd,
	})
	local rebirthBadge = UIKit.chip(profile, "R0", C.Gold, UDim2.fromOffset(64, 24))
	rebirthBadge.Position = UDim2.fromOffset(92, 38)
	rebirthBadge.TextColor3 = C.BrownDark
	rebirthBadge.TextSize = 14
	local multiplierLabel = UIKit.label(profile, {
		Position = UDim2.fromOffset(162, 38),
		Size = UDim2.new(1, -170, 0, 24),
		Font = UIKit.Fonts.Body,
		TextSize = 14,
		TextColor3 = C.Mint,
		Text = "x1.0",
	})
	local incomeLabel = UIKit.label(profile, {
		Position = UDim2.fromOffset(92, 62),
		Size = UDim2.new(1, -100, 0, 22),
		Font = UIKit.Fonts.Body,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(255, 226, 150),
		Text = "🪙 +0/s",
	})

	-- active boosts under the profile
	local boostRow = UIKit.frame(gui, { Name = "Boosts", Size = UDim2.fromOffset(300, 34), Position = UDim2.fromOffset(14, 110), BackgroundTransparency = 1 })
	addScale(boostRow)
	UIKit.list(boostRow, Enum.FillDirection.Horizontal, 6)

	-----------------------------------------------------------------------
	-- top centre: event strip + toasts
	-----------------------------------------------------------------------
	local center = UIKit.frame(gui, {
		Name = "Center",
		Size = UDim2.fromOffset(520, 44),
		Position = UDim2.new(0.5, 0, 0, 12),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = C.Dim,
		BackgroundTransparency = 0.2,
	})
	UIKit.corner(center, 22)
	UIKit.stroke(center, C.Peach, 2.5)
	addScale(center)
	local stripLabel = UIKit.label(center, {
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 15,
		TextColor3 = C.White,
		Font = UIKit.Fonts.Body,
		Text = TIPS[1],
		TextWrapped = true,
	})

	local toastHolder = UIKit.frame(gui, {
		Name = "Toasts",
		Size = UDim2.fromOffset(520, 220),
		Position = UDim2.new(0.5, 0, 0, 64),
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
			Size = UDim2.fromOffset(0, 38),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = C.Dim,
			BackgroundTransparency = 0.12,
			LayoutOrder = order,
		})
		UIKit.corner(frame, 19)
		UIKit.stroke(frame, TOAST_COLORS[kind or "info"] or C.White, 2)
		UIKit.padding(frame, 16, 0)
		local label = UIKit.label(frame, {
			Size = UDim2.fromOffset(0, 38),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = text,
			TextSize = 16,
			TextColor3 = TOAST_COLORS[kind or "info"] or C.White,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		frame.Position = UDim2.fromOffset(0, -10)
		label.TextTransparency = 1
		frame.BackgroundTransparency = 1
		UIKit.tween(frame, 0.2, { BackgroundTransparency = 0.12 })
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
	-- top right: settings / codes / shop
	-----------------------------------------------------------------------
	local topRight = UIKit.frame(gui, {
		Name = "TopRight",
		Size = UDim2.fromOffset(200, 60),
		Position = UDim2.new(1, -14, 0, 12),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
	})
	addScale(topRight)
	topRight.AnchorPoint = Vector2.new(1, 0)
	UIKit.list(topRight, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right)

	local function roundButton(parent: Instance, icon: string, color: Color3, panelName: string, order: number): TextButton
		local button = UIKit.button(parent, {
			Text = icon,
			Size = UDim2.fromOffset(58, 58),
			Color = color,
			TextSize = 28,
			Corner = 29,
			LayoutOrder = order,
			Name = panelName .. "Button",
			OnClick = function()
				openPanel(panelName)
			end,
		})
		openButtons[panelName] = button
		return button
	end
	roundButton(topRight, "⚙️", C.BrownLight, "Settings", 1)
	roundButton(topRight, "🎟️", C.Purple, "Codes", 2)
	roundButton(topRight, "🛍️", C.Pink, "Shop", 3)

	-----------------------------------------------------------------------
	-- bottom: currencies + menu buttons
	-----------------------------------------------------------------------
	local bottom = UIKit.frame(gui, {
		Name = "Bottom",
		Size = UDim2.fromOffset(640, 160),
		Position = UDim2.new(0.5, 0, 1, -10),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
	})
	addScale(bottom)

	local pillRow = UIKit.frame(bottom, { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 0, 0), BackgroundTransparency = 1 })
	UIKit.list(pillRow, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local coinsPill = UIKit.pill(pillRow, { Icon = "🪙", Color = C.Gold, Size = UDim2.fromOffset(210, 42), LayoutOrder = 1 })
	local gemsPill = UIKit.pill(pillRow, { Icon = "💎", Color = C.Sky, Size = UDim2.fromOffset(160, 42), LayoutOrder = 2 })
	local tokensPill = UIKit.pill(pillRow, { Icon = "🔥", Color = C.Peach, Size = UDim2.fromOffset(120, 42), LayoutOrder = 3 })

	local buttonRow = UIKit.frame(bottom, { Size = UDim2.new(1, 0, 0, 92), Position = UDim2.new(0, 0, 0, 56), BackgroundTransparency = 1 })
	UIKit.list(buttonRow, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)

	local function menuButton(icon: string, text: string, color: Color3, panelName: string, order: number)
		local button = UIKit.button(buttonRow, {
			Text = "",
			Size = UDim2.fromOffset(92, 88),
			Color = color,
			Corner = 18,
			LayoutOrder = order,
			Name = panelName .. "Button",
			OnClick = function()
				openPanel(panelName)
			end,
		})
		UIKit.label(button, {
			Size = UDim2.new(1, 0, 0, 48),
			Position = UDim2.fromOffset(0, 6),
			Text = icon,
			TextSize = 36,
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = UIKit.Fonts.Title,
		})
		UIKit.label(button, {
			Size = UDim2.new(1, 0, 0, 24),
			Position = UDim2.new(0, 0, 1, -30),
			Text = text,
			TextSize = 15,
			TextColor3 = C.White,
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = UIKit.Fonts.Title,
		})
		dots[panelName] = UIKit.notifyDot(button)
		openButtons[panelName] = button
	end
	menuButton("🔥", "Rebirth", Color3.fromRGB(240, 120, 70), "Rebirth", 1)
	menuButton("📖", "Index", C.Sky, "Index", 2)
	menuButton("🧺", "Hamsters", C.Peach, "Inventory", 3)
	menuButton("⬆️", "Upgrades", C.Green, "Upgrades", 4)
	menuButton("📜", "Quests", C.Purple, "Quests", 5)
	menuButton("🎁", "Daily", C.Pink, "Daily", 6)

	-----------------------------------------------------------------------
	-- grab prompt
	-----------------------------------------------------------------------
	local prompt = UIKit.frame(gui, {
		Name = "GrabPrompt",
		Size = UDim2.fromOffset(380, 60),
		Position = UDim2.new(0.5, 0, 1, -178),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = C.Dim,
		BackgroundTransparency = 0.1,
		Visible = false,
	})
	UIKit.corner(prompt, 30)
	local promptStroke = UIKit.stroke(prompt, C.Gold, 3)
	addScale(prompt)
	local keyLabel = UIKit.label(prompt, {
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.fromOffset(8, 7),
		BackgroundTransparency = 0,
		BackgroundColor3 = C.White,
		Text = if UIKit.isTouch() then "TAP" else "E",
		TextSize = 24,
		Font = UIKit.Fonts.Title,
		TextColor3 = C.BrownDark,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	UIKit.corner(keyLabel, 12)
	local promptText = UIKit.label(prompt, {
		Size = UDim2.new(1, -70, 1, 0),
		Position = UDim2.fromOffset(62, 0),
		TextSize = 18,
		TextColor3 = C.White,
		Font = UIKit.Fonts.Title,
		Text = "",
	})
	local promptClick = UIKit.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, prompt)
	promptClick.Activated:Connect(function()
		WorldController.collect()
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
		promptText.Text = string.format('Grab <font color="#%s">%s %s</font>  🪙 %s', color:ToHex(), definition.Name, name, Format.short(info.Price))
		prompt.Visible = true
		prompt.Size = UDim2.fromOffset(300, 50)
		UIKit.tween(prompt, 0.18, { Size = UDim2.fromOffset(380, 60) }, Enum.EasingStyle.Back)
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
		rebirthBadge.Text = "R" .. rebirths
		multiplierLabel.Text = "Rebirth " .. Format.multiplier(derived.RebirthMultiplier or 1)
		incomeLabel.Text = "🪙 +" .. Format.short(derived.IncomePerSecond or 0) .. "/s"
	end

	-- boosts + strip + notification dots (once per second)
	local tipIndex = 1
	local lastTip = 0
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
				local chip = UIKit.frame(boostRow, { Size = UDim2.fromOffset(94, 30), BackgroundColor3 = C.Dim, BackgroundTransparency = 0.2, LayoutOrder = order })
				UIKit.corner(chip, 15)
				UIKit.stroke(chip, C.Mint, 2)
				UIKit.label(chip, {
					Size = UDim2.fromScale(1, 1),
					Text = string.format("%s %s", info.Icon, Format.clock(expires - now)),
					TextSize = 14,
					TextColor3 = C.White,
					TextXAlignment = Enum.TextXAlignment.Center,
				})
				firstBoostText = firstBoostText or string.format("%s %s active: %s left", info.Icon, info.Name, Format.clock(expires - now))
			end
		end

		-- strip text: boost > rebirth ready > rotating tips
		local rebirths = DataController.get("Rebirths") or 0
		local text = nil
		if firstBoostText then
			text = firstBoostText
		elseif rebirths < RebirthConfig.MaxRebirths and DataController.coins() >= RebirthConfig.cost(rebirths + 1) then
			text = "🔥 You can REBIRTH! Visit your altar or press the Rebirth button."
		end
		if not text then
			if os.clock() - lastTip > 9 then
				lastTip = os.clock()
				tipIndex = tipIndex % #TIPS + 1
			end
			text = TIPS[tipIndex]
		end
		stripLabel.Text = text

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
		dots.Rebirth.Visible = rebirths < RebirthConfig.MaxRebirths and DataController.coins() >= RebirthConfig.cost(rebirths + 1)
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
			local cost = UpgradeConfig.cost(id, upgrades[id] or 0)
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
