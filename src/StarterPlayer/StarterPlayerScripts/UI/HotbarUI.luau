--[[
	HotbarUI: the permanent bottom bar (slots come from HotbarConfig).
	  Slot 1  Slap (an ability, never consumed)
	  Others  consumable items you bought in the shop (counts come from the server-owned profile.Items)

	Mouse / touch: tap a slot to select it; tapping the selected slot (or any slot on touch) uses it.
	Keyboard: number keys 1-6 select, pressing again uses.
	Nothing here is trusted: using a consumable is a server request, an empty slot can't be used, and the
	displayed counts always come from the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local HotbarConfig = require(Modules:WaitForChild("HotbarConfig"))

local CombatController = require(script.Parent.Parent.Controllers.CombatController)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local UIKit = require(script.Parent.UIKit)

local HotbarUI = {}

local C = UIKit.Colors
local player = Players.LocalPlayer

local KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
	Enum.KeyCode.Nine,
}

type SlotView = {
	Config: HotbarConfig.Slot,
	Button: TextButton,
	Icon: Frame,
	Count: TextLabel,
	Edge: UIStroke,
	Cooldown: Frame,
	Selected: boolean,
}

local views: { SlotView } = {}
local selected = 0
local tip: Frame
local tipName: TextLabel
local tipDesc: TextLabel
local busy = false

local function countOf(config: HotbarConfig.Slot): number
	if config.Kind == "Ability" then
		return -1
	end
	local items = DataController.get("Items") or {}
	return items[config.Id] or 0
end

local function notify(text: string, kind: string)
	local ok, MainUI = pcall(require, script.Parent.MainUI)
	if ok and MainUI.toast then
		MainUI.toast(text, kind)
	end
end

local function refresh()
	for index, view in views do
		local count = countOf(view.Config)
		local owned = count ~= 0
		view.Count.Visible = count > 0
		view.Count.Text = "x" .. tostring(count)
		-- empty placeholder: dimmed icon
		for _, part in view.Icon:GetDescendants() do
			if part:IsA("Frame") then
				if part:GetAttribute("BaseAlpha") == nil then
					part:SetAttribute("BaseAlpha", part.BackgroundTransparency)
				end
				local base = part:GetAttribute("BaseAlpha") :: number
				part.BackgroundTransparency = if owned then base else math.clamp(base + 0.62, 0, 0.95)
			end
		end
		local isSelected = index == selected
		view.Edge.Color = if isSelected then C.Gold else C.Line
		view.Edge.Thickness = if isSelected then 2.5 else 1.5
		view.Button.BackgroundColor3 = if isSelected then C.CardHover else C.Card
	end
	if selected > 0 and views[selected] then
		local view = views[selected]
		local count = countOf(view.Config)
		tipName.Text = view.Config.Name .. (if count >= 0 then string.format("  <font color=\"#%s\">x%d</font>", C.Muted:ToHex(), count) else "")
		tipDesc.Text = if count == 0 then "You don't own this yet - get it in the Shop." else view.Config.Desc
		tip.Visible = true
	else
		tip.Visible = false
	end
end

local function use(index: number)
	local view = views[index]
	if not view or busy then
		return
	end
	local config = view.Config
	if config.Kind == "Ability" then
		if config.Id == "slap" then
			CombatController.slap()
		end
		return
	end
	if countOf(config) <= 0 then
		AudioController.play("Error")
		notify(string.format("You don't own %s - buy it in the Shop", config.Name), "error")
		return
	end
	busy = true
	local response = DataController.request("UseItem", { Id = config.Id })
	busy = false
	notify(response.msg, if response.ok then "success" else "error")
	if response.ok then
		AudioController.play("Reward")
	end
end

local function pick(index: number)
	local touch = UIKit.isTouch()
	if selected == index and not touch then
		use(index)
		return
	end
	selected = index
	refresh()
	if touch then
		use(index)
	end
end

function HotbarUI.start()
	local gui = UIKit.new("ScreenGui", {
		Name = "HotbarUI",
		ResetOnSpawn = false,
		DisplayOrder = 2,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	local slotSize = if UIKit.isTouch() then 54 else 60
	local gap = 6
	local count = #HotbarConfig.Slots
	local width = count * slotSize + (count - 1) * gap
	local bar = UIKit.frame(gui, {
		Name = "Bar",
		Size = UDim2.fromOffset(width, slotSize),
		Position = UDim2.new(0.5, 0, 1, -12),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundTransparency = 1,
	})
	UIKit.list(bar, Enum.FillDirection.Horizontal, gap, Enum.HorizontalAlignment.Center)
	local scale = UIKit.new("UIScale", { Scale = 1 }, bar)
	local function fit()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		scale.Scale = math.clamp(viewport.X / (width + 40), 0.6, 1.1)
	end
	fit()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	-- tooltip card above the bar (selected slot)
	tip = UIKit.frame(gui, { Name = "Tip", Size = UDim2.fromOffset(260, 52), Position = UDim2.new(0.5, 0, 1, -(slotSize + 22)), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = C.Cream, Visible = false })
	UIKit.corner(tip, 8)
	UIKit.stroke(tip, C.GoldLine, 1.5)
	tipName = UIKit.label(tip, { Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 5), Font = UIKit.Fonts.Title, TextSize = 15, TextColor3 = C.Ink })
	tipDesc = UIKit.label(tip, { Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 27), Font = UIKit.Fonts.Soft, TextSize = 12, TextColor3 = C.Muted, TextTruncate = Enum.TextTruncate.AtEnd })

	for index, config in HotbarConfig.Slots do
		local button = UIKit.new("TextButton", {
			Name = "Slot_" .. config.Id,
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromOffset(slotSize, slotSize),
			BackgroundColor3 = C.Card,
			BackgroundTransparency = 0.04,
			LayoutOrder = index,
		}, bar)
		UIKit.corner(button, 8)
		local edge = UIKit.stroke(button, C.Line, 1.5)
		local icon = UIKit.icon(button, config.Icon, { Size = UDim2.fromOffset(slotSize * 0.56, slotSize * 0.56), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 2 })
		UIKit.label(button, { Text = tostring(index), Size = UDim2.fromOffset(16, 14), Position = UDim2.fromOffset(5, 3), Font = UIKit.Fonts.Title, TextSize = 12, TextColor3 = C.Muted, ZIndex = 4 })
		local countLabel = UIKit.label(button, { Size = UDim2.new(1, -6, 0, 14), Position = UDim2.new(0, 0, 1, -16), TextXAlignment = Enum.TextXAlignment.Right, Font = UIKit.Fonts.Title, TextSize = 12, TextColor3 = C.Gold, ZIndex = 4, Visible = false })
		local cooldown = UIKit.frame(button, { Name = "Cooldown", Size = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BackgroundColor3 = C.Dim, BackgroundTransparency = 0.45, ZIndex = 3, Visible = false })
		UIKit.corner(cooldown, 8)
		button.MouseEnter:Connect(function()
			if not UIKit.isTouch() then
				edge.Color = C.GoldDark
			end
		end)
		button.MouseLeave:Connect(refresh)
		button.Activated:Connect(function()
			pick(index)
		end)
		table.insert(views, { Config = config, Button = button, Icon = icon, Count = countLabel, Edge = edge, Cooldown = cooldown, Selected = false })
	end

	-- number keys (never while typing in a text box)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		for index, key in KEYS do
			if input.KeyCode == key and views[index] then
				pick(index)
				return
			end
		end
	end)

	-- the Slap slot shows its cooldown
	RunService.Heartbeat:Connect(function()
		local view = views[1]
		if view and view.Config.Id == "slap" then
			local ready = CombatController.ready()
			view.Cooldown.Visible = ready < 1
			view.Cooldown.Size = UDim2.fromScale(1, 1 - ready)
		end
	end)

	DataController.onChanged(function(keys)
		if keys.Items then
			refresh()
		end
	end)
	DataController.onReady(refresh)
	refresh()
end

return HotbarUI
