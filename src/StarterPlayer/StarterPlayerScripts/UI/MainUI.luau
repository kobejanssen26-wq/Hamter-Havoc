--[[
	MainUI: the always-visible HUD, built from four REGIONS so nothing can overlap by construction.
	Each region is one responsive box (UIKit.responsive: positioned wrapper + scaled content) whose children are
	laid out by UIListLayouts, never by hand-picked offsets:

	  TopColumn     top centre, below the Roblox top bar: [Cash | Cash/s | Diamonds | Rebirths], status row
	                (gate state + active boosts), toasts
	  Rail          top right: small icon buttons built from UIRegistry (Quests, Hamsters, Shop, ...)
	  LeftColumn    top left: hamster transport tracker, tutorial card (other modules parent into it)
	  BottomColumn  bottom centre: hint strip, grab prompt, steal progress, hotbar

	Other modules get a region with MainUI.region("LeftColumn") etc. Everything is in ONE ScreenGui
	(Insets = Topbar, so the origin is already below the Roblox top bar and phone notches).
	Adding a button = UIRegistry.register(...), see UIRegistry.luau.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local AchievementConfig = require(Modules:WaitForChild("AchievementConfig"))
local DailyRewardConfig = require(Modules:WaitForChild("DailyRewardConfig"))
local Format = require(Modules:WaitForChild("Format"))
local QuestConfig = require(Modules:WaitForChild("QuestConfig"))
local RarityConfig = require(Modules:WaitForChild("RarityConfig"))
local RebirthConfig = require(Modules:WaitForChild("RebirthConfig"))
local SecurityConfig = require(Modules:WaitForChild("SecurityConfig"))
local ShopConfig = require(Modules:WaitForChild("ShopConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local CursorController = require(script.Parent.Parent.Controllers.CursorController)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local SecurityController = require(script.Parent.Parent.Controllers.SecurityController)
local WorldController = require(script.Parent.Parent.Controllers.WorldController)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)
local UIRegistry = require(script.Parent.UIRegistry)

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


local regions: { [string]: UIKit.Responsive } = {}

-- Region content frames for other HUD modules ("TopColumn", "Rail", "LeftColumn", "BottomColumn").
function MainUI.region(name: string): Frame?
	local region = regions[name]
	return if region then region.Content else nil
end

-- All region wrappers (used by the layout tests).
function MainUI.regionWrappers(): { [string]: Frame }
	local result = {}
	for name, region in regions do
		result[name] = region.Wrapper
	end
	return result
end

-- Panels that live inside another one now (the old "My Hamsters" window is the Backpack's Hamsters tab).
local PANEL_ALIAS = { Inventory = { "Backpack", "Hamsters" } }

local function openPanel(name: string, focus: string?)
	local alias = PANEL_ALIAS[name]
	if alias then
		name, focus = alias[1], alias[2]
	end
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
	local alias = PANEL_ALIAS[name]
	if alias then
		name, focus = alias[1], alias[2]
	end
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

-- Toast placeholder until MainUI.start has built the holder.
function MainUI.toast(_text: string, _kind: string?) end

local function questsBadge(): boolean
	local data = DataController.Data
	local now = DataController.now()
	if data.Daily then
		local _, canClaim = DailyRewardConfig.state(data.Daily, now)
		if canClaim then
			return true
		end
	end
	if data.Wheel and now >= (data.Wheel.NextFreeAt or 0) then
		return true -- the free Lucky Wheel spin is ready
	end
	if data.Quests and data.Achievements and data.Stats and data.Index then
		for _, quest in QuestConfig.Quests do
			if not data.Quests.Claimed[quest.Id] and QuestConfig.isComplete(data, quest) then
				return true
			end
		end
		for _, achievement in AchievementConfig.List do
			if not data.Achievements.Claimed[achievement.Id] and QuestConfig.getStat(data, achievement.Stat) >= achievement.Target then
				return true
			end
		end
	end
	return false
end

local function registerCore()
	local core = {
		{ Id = "Quests", Order = 10, Icon = "scroll", Tooltip = "Daily Quests", Panel = "Quests", Badge = questsBadge },
		{ Id = "Backpack", Order = 20, Icon = "bag", Tooltip = "Backpack (I): items, hamsters, index, emotes", Panel = "Backpack" },
		{ Id = "Shop", Order = 30, Icon = "gift", Tooltip = "Shop", Panel = "Shop" },
		{ Id = "Settings", Order = 90, Icon = "gear", Tooltip = "Settings", Panel = "Settings" },
	}
	for _, entry in core do
		if not UIRegistry.get(entry.Id) then
			entry.Kind = "IconButton"
			entry.Slot = "RightRail"
			entry.Core = true
			UIRegistry.register(entry)
		end
	end
end

---------------------------------------------------------------------------

function MainUI.start()
	registerCore()
	local gui = UIKit.screenGui("MainUI", { Layer = "Hud", Insets = "Topbar" })
	local touch = UIKit.isTouch()
	local margin = Theme.Hud.SideMargin

	-----------------------------------------------------------------------
	-- regions
	-----------------------------------------------------------------------
	local TOP_DESIGN = Vector2.new(500, 200)
	local top = UIKit.responsive(gui, { Name = "TopColumn", Design = TOP_DESIGN, Position = UDim2.new(0.5, 0, 0, Theme.Hud.TopMargin), AnchorPoint = Vector2.new(0.5, 0) })
	regions.TopColumn = top
	UIKit.list(top.Content, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)

	local railButton = if touch then Theme.Hud.IconButtonTouch else Theme.Hud.IconButton
	local railSlots = UIRegistry.Slots.RightRail.Capacity
	local rail = UIKit.responsive(gui, {
		Name = "Rail",
		Design = Vector2.new(railButton, railSlots * railButton + (railSlots - 1) * 8),
		Position = UDim2.new(1, -margin, 0, Theme.Hud.TopMargin),
		AnchorPoint = Vector2.new(1, 0),
	})
	regions.Rail = rail
	UIKit.list(rail.Content, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Right)

	local left = UIKit.responsive(gui, { Name = "LeftColumn", Design = Vector2.new(300, 420), Position = UDim2.new(0, margin, 0, Theme.Hud.TopMargin) })
	regions.LeftColumn = left
	UIKit.list(left.Content, Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Top)

	local bottom = UIKit.responsive(gui, { Name = "BottomColumn", Design = Vector2.new(460, 180), Position = UDim2.new(0.5, 0, 1, -92), AnchorPoint = Vector2.new(0.5, 1) })
	regions.BottomColumn = bottom
	UIKit.list(bottom.Content, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom)

	-----------------------------------------------------------------------
	-- top column: indicators
	-----------------------------------------------------------------------
	local topBar = UIKit.frame(top.Content, { Name = "TopBar", Size = UDim2.fromOffset(TOP_DESIGN.X, Theme.Size.Pill), BackgroundTransparency = 1, LayoutOrder = 1 })
	UIKit.list(topBar, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local coinsPill = UIKit.pill(topBar, { Icon = "coin", Color = C.Cash, Size = UDim2.fromOffset(140, Theme.Size.Pill), LayoutOrder = 1, Big = true })
	local incomePill = UIKit.pill(topBar, { Icon = "cash", Color = C.Cash, Size = UDim2.fromOffset(116, Theme.Size.Pill), LayoutOrder = 2 })
	local gemsPill = UIKit.pill(topBar, { Icon = "gem", Color = C.Purple, Size = UDim2.fromOffset(112, Theme.Size.Pill), LayoutOrder = 3, OnPlus = function() MainUI.open("Shop", "Diamonds") end })
	local rebirthPill = UIKit.pill(topBar, { Icon = "rebirth", Color = C.Bronze, Size = UDim2.fromOffset(104, Theme.Size.Pill), LayoutOrder = 4 })
	UIKit.tooltip(coinsPill.Frame, "Cash", "Below")
	UIKit.tooltip(incomePill.Frame, "Money per second (all hamsters working on your bench)", "Below")
	UIKit.tooltip(gemsPill.Frame, "Diamonds", "Below")
	UIKit.tooltip(rebirthPill.Frame, "Rebirths completed", "Below")

	-- status row: gate state + active boosts
	local statusRow = UIKit.frame(top.Content, { Name = "StatusRow", Size = UDim2.fromOffset(TOP_DESIGN.X, 30), BackgroundTransparency = 1, LayoutOrder = 2 })
	UIKit.list(statusRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)

	local gateChip = UIKit.frame(statusRow, { Name = "GateChip", Size = UDim2.fromOffset(150, 28), LayoutOrder = 0, Visible = false })
	UIKit.vivid(gateChip, C.Green, { Corner = 8, Outline = 1.5 })
	UIKit.icon(gateChip, "shield", { Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(7, 5), ZIndex = 3 })
	local gateText = UIKit.label(gateChip, { Size = UDim2.new(1, -32, 1, 0), Position = UDim2.fromOffset(30, 0), Font = UIKit.Fonts.Title, TextSize = 13, TextColor3 = C.Ink, ZIndex = 3, TextTruncate = Enum.TextTruncate.AtEnd })
	UIKit.tooltip(gateChip, function()
		local rebirths = DataController.get("Rebirths") or 0
		return string.format("Your base gate stays on %d s (+%d s per rebirth)", SecurityConfig.duration(rebirths), SecurityConfig.PerRebirthSeconds)
	end, "Below")

	local toastHolder = UIKit.frame(top.Content, { Name = "Toasts", Size = UDim2.fromOffset(TOP_DESIGN.X, 108), BackgroundTransparency = 1, LayoutOrder = 3 })
	UIKit.list(toastHolder, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Top)
	local toastCount = 0

	function MainUI.toast(text: string, kind: string?)
		local notificationsOn = DataController.setting("Notifications")
		if notificationsOn ~= true and kind ~= "error" then
			return
		end
		toastCount += 1
		local accent = TOAST_COLORS[kind or "info"] or C.Ink
		local frame = UIKit.frame(toastHolder, {
			Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			BackgroundColor3 = C.Cream,
			BackgroundTransparency = 0.04,
			LayoutOrder = toastCount,
		})
		UIKit.corner(frame, 8)
		UIKit.stroke(frame, accent, 1.5, 0.35)
		UIKit.padding(frame, 12, 0)
		UIKit.list(frame, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
		UIKit.icon(frame, TOAST_ICONS[kind or "info"] or "star", { Size = UDim2.fromOffset(18, 18), LayoutOrder = 1 })
		local label = UIKit.label(frame, {
			LayoutOrder = 2,
			Size = UDim2.fromOffset(0, 34),
			AutomaticSize = Enum.AutomaticSize.X,
			Text = text,
			TextSize = 14,
			TextColor3 = accent,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		label.TextTransparency = 1
		frame.BackgroundTransparency = 1
		UIKit.tween(frame, 0.2, { BackgroundTransparency = 0.04 })
		UIKit.tween(label, 0.2, { TextTransparency = 0 })
		-- at most 4 toasts: the oldest goes
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
	-- rail: icon buttons from the registry
	-----------------------------------------------------------------------
	local railViews: { [string]: { Button: TextButton, Dot: Frame, Def: UIRegistry.Definition, Base: Color3 } } = {}
	local function rebuildRail()
		-- incremental: buttons that stay keep their instance (so a Studio-edited button keeps its look), others come and go
		local wanted: { [string]: boolean } = {}
		for _, def in UIRegistry.list("RightRail") do
			wanted[def.Id] = true
		end
		for id, view in railViews do
			if not wanted[id] then
				view.Button:Destroy()
				railViews[id] = nil
			end
		end
		for _, def in UIRegistry.list("RightRail") do
			local existing = railViews[def.Id]
			if existing then
				existing.Def = def
				existing.Button.LayoutOrder = def.Order
				continue
			end
			local button = UIKit.button(rail.Content, {
				Text = "",
				Size = UDim2.fromOffset(railButton, railButton),
				Color = C.Cream,
				Corner = 99,
				LayoutOrder = def.Order,
				Name = def.Id .. "Button",
				OnClick = function()
					if def.OnActivate then
						def.OnActivate()
					elseif def.Panel then
						openPanel(def.Panel, def.Focus)
					end
				end,
			})
			button.BackgroundTransparency = 0.06
			UIKit.icon(button, def.Icon :: string, { Size = UDim2.fromOffset(railButton * 0.58, railButton * 0.58), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3 })
			local dot = UIKit.notifyDot(button)
			UIKit.tooltip(button, def.Tooltip or def.Id, "Left")
			railViews[def.Id] = { Button = button, Dot = dot, Def = def, Base = button.BackgroundColor3 } -- (Base = the colour you gave it in Studio, if any)
		end
	end
	rebuildRail()
	UIRegistry.onChanged(rebuildRail)

	-- selected state + badges + visibility (twice a second is plenty)
	task.spawn(function()
		while true do
			for id, view in railViews do
				local def = view.Def
				local panel = if def.Panel then UIKit.getPanel(def.Panel) else nil
				UIKit.setButtonColor(view.Button, if panel and panel.IsOpen then C.Peach else view.Base)
				view.Button.Visible = def.Visible == nil or def.Visible()
				view.Dot.Visible = def.Badge ~= nil and DataController.Ready and def.Badge()
				railViews[id] = view
			end
			task.wait(0.5)
		end
	end)

	-----------------------------------------------------------------------
	-- bottom column: hint strip, grab prompt (the hotbar and steal bar join later)
	-----------------------------------------------------------------------
	local fpHint = UIKit.label(bottom.Content, {
		Name = "FirstPersonHint",
		Size = UDim2.fromOffset(300, 18),
		LayoutOrder = 0,
		Text = "Hold ALT to use the mouse",
		TextSize = 12,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
		Visible = false,
	})
	task.spawn(function()
		while true do
			fpHint.Visible = not UIKit.isTouch() and CursorController.isFirstPerson() and not CursorController.isHolding()
			task.wait(0.3)
		end
	end)

	local strip = UIKit.frame(bottom.Content, { Name = "Strip", Size = UDim2.fromOffset(440, 34), LayoutOrder = 1, BackgroundColor3 = C.Cream, BackgroundTransparency = 0.1, Visible = false })
	UIKit.corner(strip, 8)
	UIKit.stroke(strip, C.Line, 1.5)
	local stripLabel = UIKit.label(strip, {
		Size = UDim2.new(1, -20, 1, 0),
		Position = UDim2.fromOffset(10, 0),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 13,
		TextColor3 = C.Ink,
		Font = UIKit.Fonts.Soft,
		Text = TIPS[1],
		TextWrapped = true,
	})

	local prompt = UIKit.frame(bottom.Content, { Name = "GrabPrompt", Size = UDim2.fromOffset(420, 52), LayoutOrder = 2, BackgroundColor3 = C.Cream, BackgroundTransparency = 0.04, Visible = false })
	UIKit.corner(prompt, 10)
	local promptStroke = UIKit.stroke(prompt, C.Gold, 2)
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
	UIKit.stroke(keyLabel, C.Line, 1.5)
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
			priceLabel.TextColor3 = if info.Affordable then C.Cash else C.Red
		elseif info.Action == "Steal" then
			promptStroke.Color = C.Red
			promptText.Text = string.format("Steal %s  from %s", colored, info.OwnerName)
		else
			promptText.Text = string.format("%s %s", info.Action, colored)
		end
		prompt.Visible = true
	end)

	-----------------------------------------------------------------------
	-- live numbers
	-----------------------------------------------------------------------
	local shown = { Coins = 0, Gems = 0 }
	local actual = { Coins = 0, Gems = 0 }
	local pills = { Coins = coinsPill, Gems = gemsPill }
	actual.Coins, actual.Gems = DataController.coins(), DataController.gems()
	shown.Coins, shown.Gems = actual.Coins, actual.Gems
	for _, name in { "Coins", "Gems" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			local before = actual[name]
			actual[name] = player:GetAttribute(name) or 0
			if name ~= "Coins" and actual[name] > before then
				pills[name].Value.TextColor3 = C.White
				UIKit.tween(pills[name].Value, 0.5, { TextColor3 = C.Purple })
			end
		end)
	end

	-- the numbers glide to their target; the connection lives for the whole session (created once)
	RunService.RenderStepped:Connect(function(dt)
		for name, pill in pills do
			local target, current = actual[name], shown[name]
			if current ~= target then
				local nextValue = current + (target - current) * math.min(1, dt * 9)
				if math.abs(target - nextValue) < 0.5 then
					nextValue = target
				end
				shown[name] = nextValue
				pill.Value.Text = Format.short(nextValue)
			end
		end
	end)

	local function refreshStatic()
		local derived = DataController.derived()
		coinsPill.Value.Text = Format.short(shown.Coins)
		gemsPill.Value.Text = Format.short(shown.Gems)
		rebirthPill.Value.Text = tostring(DataController.get("Rebirths") or 0) -- (the icon + tooltip say what it is; "Rebirth 12" did not fit)
		incomePill.Value.Text = Format.rate(derived.IncomePerSecond or 0)
	end

	-- gate chip + boost chips + hint strip (once per second)
	local tipIndex, lastTip = 1, os.clock() - 40
	local boostChips: { Frame } = {}
	local lastTick = -1
	local function refreshGate()
		local houseId = player:GetAttribute("HouseId")
		local houses = workspace:FindFirstChild("PlayerHouses")
		local house = if type(houseId) == "number" and houses then houses:FindFirstChild("House" .. houseId) else nil
		if not house or not house:IsA("Model") then
			gateChip.Visible = false
			return
		end
		local status = SecurityController.status(house)
		gateChip.Visible = status.Owned
		local color = SecurityController.color(status)
		local edge = gateChip:FindFirstChild("AccentEdge") :: UIStroke?
		if edge then
			edge.Color = color
		end
		gateText.TextColor3 = color
		if status.State == "Active" then
			gateText.Text = "LOCKED  " .. Format.clock(math.ceil(status.Seconds))
			local whole = math.ceil(status.Seconds)
			if whole <= 3 and whole ~= lastTick then
				lastTick = whole
				AudioController.play("GateTick")
			end
		elseif status.State == "Recharging" then
			gateText.Text = string.format("OPEN  %ds", math.ceil(status.Seconds))
			lastTick = -1
		else
			gateText.Text = "OPEN - use the panel"
			lastTick = -1
		end
	end
	local function refreshDynamic()
		local now = DataController.now()
		local boosts = DataController.get("Boosts") or {}
		for _, chip in boostChips do
			chip:Destroy()
		end
		table.clear(boostChips)
		local order, firstBoostText = 0, nil
		for boostId, info in ShopConfig.Boosts do
			local expires = boosts[boostId]
			if expires and expires > now then
				order += 1
				local chip = UIKit.frame(statusRow, { Size = UDim2.fromOffset(92, 28), LayoutOrder = order })
				UIKit.vivid(chip, C.Green, { Corner = 8, Outline = 1.5 })
				UIKit.icon(chip, info.Icon, { Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(7, 5), ZIndex = 3 })
				UIKit.label(chip, { Size = UDim2.new(1, -32, 1, 0), Position = UDim2.fromOffset(30, 0), Text = Format.clock(expires - now), Font = UIKit.Fonts.Title, TextSize = 14, TextColor3 = C.Ink, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = 3 })
				table.insert(boostChips, chip)
				firstBoostText = firstBoostText or string.format("%s active: %s left", info.Name, Format.clock(expires - now))
			end
		end
		local rebirths = DataController.get("Rebirths") or 0
		local text = nil
		if firstBoostText then
			text = firstBoostText
		elseif rebirths < RebirthConfig.MaxRebirths and DataController.rebirthCheck(rebirths + 1) then
			text = "You can REBIRTH! Visit the Rebirth altar in your yard."
		end
		if not text then
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
		strip.Visible = text ~= nil
		if text then
			stripLabel.Text = text
		end
	end

	DataController.onChanged(function()
		refreshStatic()
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
	task.spawn(function()
		while true do
			refreshGate()
			task.wait(0.25)
		end
	end)

	-- menus opened from world prompts (houses, plaza stalls)
	Remotes.event("OpenUI").OnClientEvent:Connect(function(name: string, focus: string?)
		MainUI.open(name, focus)
	end)
end

return MainUI
