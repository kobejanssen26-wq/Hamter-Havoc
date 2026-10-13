--[[
	HotbarUI: THE bottom hotbar (there is no second one; Roblox's own backpack bar is switched off).
	  Slot 1     Paws (slap) - always there; selected when no weapon is held
	  Slots 2-8  owned weapons / consumables, placed by the server (profile.Hotbar) and re-ordered in the Backpack
	Empty slots are dim placeholders. Nothing can be selected that is not owned.

	Input: keys 1-8 or tap/click a slot.
	  weapon     first press equips (real Tool), pressing it again unequips
	  consumable first press selects (tooltip), pressing it again uses it (a tap uses it immediately on touch)
	  paws       with nothing held, pressing 1 again slaps
	Every slot is built from HotbarConfig.layout(size): number top-left, icon centred, count bottom-right - three areas
	that cannot overlap. Using or equipping is a server request; this file only shows what the server says you own.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local HotbarConfig = require(Modules:WaitForChild("HotbarConfig"))

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local CombatController = require(script.Parent.Parent.Controllers.CombatController)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local ItemView = require(script.Parent.ItemView)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local HotbarUI = {}

local C = UIKit.Colors
local GAP = 6

local KEYS = {
	Enum.KeyCode.One,
	Enum.KeyCode.Two,
	Enum.KeyCode.Three,
	Enum.KeyCode.Four,
	Enum.KeyCode.Five,
	Enum.KeyCode.Six,
	Enum.KeyCode.Seven,
	Enum.KeyCode.Eight,
}

type SlotView = {
	Button: TextButton,
	Icon: Frame,
	IconHolder: Frame,
	Number: TextLabel,
	Count: TextLabel,
	Edge: UIStroke,
	Cooldown: Frame,
	IconId: string?,
}

local views: { SlotView } = {}
local selectedConsumable = 0
local tip: Frame
local tipName: TextLabel
local tipDesc: TextLabel
local busy = false
local bar: Frame

-- Exposed for tests / layout checks.
HotbarUI.Views = views

local function notify(text: string, kind: string)
	local ok, MainUI = pcall(require, script.Parent.MainUI)
	if ok and MainUI.toast then
		MainUI.toast(text, kind)
	end
end

local function itemAt(index: number): any?
	if index == 1 then
		return nil
	end
	return ItemView.hotbarItem(index)
end

-- The slot that is "selected": the held weapon's slot, else the chosen consumable, else the paws.
function HotbarUI.selectedSlot(): number
	local held = ItemView.heldId()
	if held then
		for index = 2, HotbarConfig.SlotCount do
			local item = itemAt(index)
			if item and item.Id == held then
				return index
			end
		end
	end
	if selectedConsumable > 1 and itemAt(selectedConsumable) then
		return selectedConsumable
	end
	return 1
end

local function setIcon(view: SlotView, iconId: string?, dim: boolean, size: number)
	if view.IconId ~= iconId then
		view.IconHolder:ClearAllChildren()
		view.IconId = iconId
		if iconId then
			UIKit.icon(view.IconHolder, iconId, { Size = UDim2.fromScale(1, 1) })
		end
	end
	for _, part in view.IconHolder:GetDescendants() do
		if part:IsA("Frame") then
			if part:GetAttribute("BaseAlpha") == nil then
				part:SetAttribute("BaseAlpha", part.BackgroundTransparency)
			end
			local base = part:GetAttribute("BaseAlpha") :: number
			part.BackgroundTransparency = if dim then math.clamp(base + 0.7, 0, 0.95) else base
		end
	end
end

function HotbarUI.refresh()
	if not bar then
		return
	end
	local selected = HotbarUI.selectedSlot()
	for index, view in views do
		local item = itemAt(index)
		local isPaws = index == 1
		local owned = isPaws or item ~= nil
		setIcon(view, if isPaws then HotbarConfig.Ability.Icon elseif item then item.Icon else nil, not owned, 0)
		view.Icon.Visible = owned
		local count = if item then ItemView.count(item) else 0
		view.Count.Visible = item ~= nil and item.Equip.Kind == "Consume" and count > 0
		view.Count.Text = "x" .. tostring(count)
		local isSelected = index == selected
		view.Edge.Color = if isSelected then C.Gold elseif owned then C.Line else C.Line
		view.Edge.Thickness = if isSelected then 3 else 1.5
		view.Edge.Transparency = if owned or isSelected then 0 else 0.55
		view.Button.BackgroundColor3 = if isSelected then C.CardHover else C.Card
		view.Button.BackgroundTransparency = if owned then 0.04 else 0.4
		view.Number.TextColor3 = if isSelected then C.Gold else C.Muted
	end
	local view = views[selected]
	if selected > 1 or selectedConsumable > 1 then
		local item = itemAt(selected)
		if item then
			local count = ItemView.count(item)
			tipName.Text = item.DisplayName .. (if item.Equip.Kind == "Consume" then string.format("  <font color=\"#%s\">x%d</font>", C.Muted:ToHex(), count) else "")
			tipDesc.Text = if item.Equip.Kind == "Consume" then "Press again to use. " .. item.Description else item.Description
			tip.Visible = true
			return
		end
	end
	tip.Visible = false
	if not view then
		return
	end
end

local function request(action: string, payload: { [string]: any }?): boolean
	if busy then
		return false
	end
	busy = true
	local response = DataController.request(action, payload)
	busy = false
	if not response.ok then
		AudioController.play("Error")
		notify(response.msg, "error")
	end
	return response.ok
end

-- Press / click / tap on slot `index` (also what the number keys call).
function HotbarUI.activate(index: number)
	if index == 1 then
		selectedConsumable = 0
		if ItemView.heldId() then
			request("UnequipItem")
		else
			CombatController.attack()
		end
		HotbarUI.refresh()
		return
	end
	local item = itemAt(index)
	if not item then
		AudioController.play("Error")
		notify("Empty slot - get weapons and items in the Shop", "info")
		return
	end
	if item.Equip.Kind == "Tool" then
		selectedConsumable = 0
		if ItemView.heldId() == item.Id then
			request("UnequipItem")
		else
			request("EquipItem", { Id = item.Id })
		end
	else
		if ItemView.heldId() then
			request("UnequipItem") -- selecting a consumable puts the weapon away
		end
		if selectedConsumable == index or UIKit.isTouch() then
			selectedConsumable = index
			if request("UseItem", { Id = item.Id }) then
				AudioController.play("Reward")
			end
		else
			selectedConsumable = index
		end
	end
	HotbarUI.refresh()
end

local function fit()
	local camera = workspace.CurrentCamera
	if not camera or not bar then
		return
	end
	local holder = bar.Parent :: Instance
	local scale = holder:FindFirstChildOfClass("UIScale")
	local width = holder:GetAttribute("DesignWidth") :: number
	if scale and width then
		scale.Scale = math.clamp((camera.ViewportSize.X - 24) / width, 0.5, 1)
	end
end

function HotbarUI.start()
	-- The hotbar is its OWN ScreenGui, pinned to the bottom centre of the screen: no shared layout, so no other HUD part
	-- can push it around (it used to live in a HUD column and could end up at the top of the screen).
	local gui = UIKit.screenGui("HotbarUI", { Layer = "Hotbar", Insets = "Device" })
	-- Roblox's own backpack bar would be a second hotbar: it is switched off (retry, CoreGui may not be ready yet)
	task.spawn(function()
		for _ = 1, 10 do
			if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then
				break
			end
			task.wait(0.5)
		end
	end)

	local slotSize = if UIKit.isTouch() then Theme.Size.SlotTouch else Theme.Size.Slot
	local count = HotbarConfig.SlotCount
	local width = count * slotSize + (count - 1) * GAP
	local layout = HotbarConfig.layout(slotSize)

	local holder = UIKit.frame(gui, { Name = "Hotbar", Size = UDim2.fromOffset(width, slotSize), Position = UDim2.new(0.5, 0, 1, -14), AnchorPoint = Vector2.new(0.5, 1), BackgroundTransparency = 1 })
	holder:SetAttribute("DesignWidth", width)
	UIKit.new("UIScale", { Scale = 1 }, holder)

	-- tooltip card of the selected slot, floating just above the bar
	tip = UIKit.frame(holder, { Name = "Tip", Size = UDim2.fromOffset(300, 54), Position = UDim2.new(0.5, 0, 0, -8), AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = C.Cream, Visible = false })
	UIKit.corner(tip, 8)
	UIKit.stroke(tip, C.Line, 1)
	tipName = UIKit.label(tip, { Size = UDim2.new(1, -20, 0, 22), Position = UDim2.fromOffset(10, 5), Font = UIKit.Fonts.Title, TextSize = 15, TextColor3 = C.Ink, RichText = true })
	tipDesc = UIKit.label(tip, { Size = UDim2.new(1, -20, 0, 20), Position = UDim2.fromOffset(10, 28), Font = UIKit.Fonts.Soft, TextSize = 12, TextColor3 = C.Muted, TextTruncate = Enum.TextTruncate.AtEnd })

	bar = UIKit.frame(holder, { Name = "Bar", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	UIKit.list(bar, Enum.FillDirection.Horizontal, GAP, Enum.HorizontalAlignment.Center)

	for index = 1, count do
		local button = UIKit.new("TextButton", {
			Name = "Slot_" .. index,
			Text = "",
			AutoButtonColor = false,
			Size = UDim2.fromOffset(slotSize, slotSize),
			BackgroundColor3 = C.Card,
			BackgroundTransparency = 0.04,
			LayoutOrder = index,
		}, bar)
		UIKit.corner(button, 8)
		local edge = UIKit.stroke(button, C.Line, 1.5)

		local n, i, c = layout.Number, layout.Icon, layout.Count
		local number = UIKit.label(button, { Name = "Number", Text = tostring(index), Size = UDim2.fromOffset(n[3], n[4]), Position = UDim2.fromOffset(n[1], n[2]), Font = UIKit.Fonts.Title, TextSize = 12, TextColor3 = C.Muted, ZIndex = 4 })
		local iconHolder = UIKit.frame(button, { Name = "IconArea", Size = UDim2.fromOffset(i[3], i[4]), Position = UDim2.fromOffset(i[1], i[2]), BackgroundTransparency = 1, ZIndex = 2 })
		local countLabel = UIKit.label(button, { Name = "Count", Size = UDim2.fromOffset(c[3], c[4]), Position = UDim2.fromOffset(c[1], c[2]), TextXAlignment = Enum.TextXAlignment.Right, Font = UIKit.Fonts.Title, TextSize = 12, TextColor3 = C.Gold, ZIndex = 4, Visible = false })
		local cooldown = UIKit.frame(button, { Name = "Cooldown", Size = UDim2.fromScale(1, 0), AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), BackgroundColor3 = C.Dim, BackgroundTransparency = 0.45, ZIndex = 3, Visible = false })
		UIKit.corner(cooldown, 8)
		button.Activated:Connect(function()
			HotbarUI.activate(index)
		end)
		table.insert(views, { Button = button, Icon = iconHolder, IconHolder = iconHolder, Number = number, Count = countLabel, Edge = edge, Cooldown = cooldown })
	end

	-- number keys (never while typing in a text box)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		for index, key in KEYS do
			if input.KeyCode == key and views[index] then
				HotbarUI.activate(index)
				return
			end
		end
	end)

	-- cooldown sweep on the selected slot (only touches the UI while a cooldown is running or just ended)
	local lastReady = 1
	local lastSlot = 1
	RunService.Heartbeat:Connect(function()
		local ready = CombatController.ready()
		if ready >= 1 and lastReady >= 1 then
			return
		end
		lastReady = ready
		local slot = HotbarUI.selectedSlot()
		if slot ~= lastSlot and views[lastSlot] then
			views[lastSlot].Cooldown.Visible = false
		end
		lastSlot = slot
		local view = views[slot]
		if view then
			view.Cooldown.Visible = ready < 1
			view.Cooldown.Size = UDim2.fromScale(1, 1 - ready)
		end
	end)

	local function watchCharacter(character: Model)
		character.ChildAdded:Connect(HotbarUI.refresh)
		character.ChildRemoved:Connect(HotbarUI.refresh)
		HotbarUI.refresh()
	end
	Players.LocalPlayer.CharacterAdded:Connect(watchCharacter)
	if Players.LocalPlayer.Character then
		watchCharacter(Players.LocalPlayer.Character)
	end

	DataController.onChanged(function(keys)
		if keys.Items or keys.Gear or keys.Hotbar then
			HotbarUI.refresh()
		end
	end)
	DataController.onReady(HotbarUI.refresh)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	fit()
	HotbarUI.refresh()
end

return HotbarUI
