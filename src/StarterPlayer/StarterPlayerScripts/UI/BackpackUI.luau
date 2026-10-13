--[[
	BackpackUI: your gear. Everything you OWN that is not a hamster: weapons, equipment, consumables (the hamster
	collection stays in "My Hamsters"). Open with the rail button or [I].

	  top strip   the 8 hotbar slots (slot 1 = paws); pick an item, then click a slot to put it there
	  grid        owned items with ownership badges (slot number, EQUIPPED, xN, ACTIVE)
	  detail      description, real stats, Equip / Unequip, move on the hotbar, discard (consumables only)
	Nothing is shown that you do not own, equipping an unowned item is refused by the server, and weapons / equipment
	can never be discarded (you paid for them) - consumables can, after a confirm.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local HotbarConfig = require(Modules:WaitForChild("HotbarConfig"))
local InputConfig = require(Modules:WaitForChild("InputConfig"))
local ItemRegistry = require(Modules:WaitForChild("ItemRegistry"))

local DataController = require(script.Parent.Parent.Controllers.DataController)
local ItemView = require(script.Parent.ItemView)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local BackpackUI = {}

local C = UIKit.Colors

local CATEGORY_ORDER = { Weapon = 1, Equipment = 2, Consumable = 3 }

function BackpackUI.ownedItems(): { any }
	local list = {}
	for _, def in ItemRegistry.List do
		if ItemView.count(def) > 0 then
			table.insert(list, def)
		end
	end
	table.sort(list, function(a, b)
		if a.Category ~= b.Category then
			return (CATEGORY_ORDER[a.Category] or 9) < (CATEGORY_ORDER[b.Category] or 9)
		end
		return a.DisplayName < b.DisplayName
	end)
	return list
end

function BackpackUI.start()
	local panel = UIKit.panel({ Name = "Backpack", Title = "Backpack", Icon = "bat", Design = Vector2.new(920, 620), Accent = Theme.Accents.Backpack, Subtitle = "Your items, hamsters, index and emotes" })

	-- two tabs: Items (weapons, equipment, consumables) and Hamsters (the collection + working bench). The tab bar also
	-- holds the shortcuts to the Hamster Index and the Emote wheel, so those need no buttons of their own on the HUD.
	local tabBar = UIKit.frame(panel.Body, { Name = "Tabs", Size = UDim2.new(1, 0, 0, 38), BackgroundTransparency = 1 })
	UIKit.list(tabBar, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local body = UIKit.frame(panel.Body, { Name = "ItemsTab", Size = UDim2.new(1, 0, 1, -46), Position = UDim2.fromOffset(0, 46), BackgroundTransparency = 1 })
	local hamstersBody = UIKit.frame(panel.Body, { Name = "HamstersTab", Size = UDim2.new(1, 0, 1, -46), Position = UDim2.fromOffset(0, 46), BackgroundTransparency = 1, Visible = false })
	local activeTab = "Items"
	local renderHamsters = require(script.Parent.InventoryUI).mount(hamstersBody, function()
		return panel.IsOpen and activeTab == "Hamsters"
	end)
	local tabButtons: { [string]: TextButton } = {}
	local setTab
	local function addTab(id: string, text: string)
		tabButtons[id] = UIKit.button(tabBar, {
			Name = "Tab_" .. id,
			Text = text,
			Size = UDim2.fromOffset(120, 34),
			Color = C.Card,
			TextSize = 15,
			LayoutOrder = if id == "Items" then 1 else 2,
			OnClick = function()
				setTab(id)
			end,
		})
	end
	addTab("Items", "Items")
	addTab("Hamsters", "Hamsters")
	UIKit.button(tabBar, {
		Name = "OpenIndex",
		Text = "Hamster Index",
		Size = UDim2.fromOffset(140, 34),
		Color = C.Card,
		TextSize = 15,
		LayoutOrder = 3,
		OnClick = function()
			local index = UIKit.getPanel("Index")
			if index then
				index:Open()
			end
		end,
	})
	UIKit.button(tabBar, {
		Name = "OpenEmotes",
		Text = "Emotes",
		Size = UDim2.fromOffset(110, 34),
		Color = C.Card,
		TextSize = 15,
		LayoutOrder = 4,
		OnClick = function()
			panel:Close()
			require(script.Parent.EmoteUI).toggle()
		end,
	})
	local selectedId: string? = nil
	local confirmDiscard = false
	local render

	setTab = function(id: string)
		activeTab = id
		body.Visible = id == "Items"
		hamstersBody.Visible = id == "Hamsters"
		for tabId, button in tabButtons do
			UIKit.setButtonColor(button, if tabId == id then C.Blue else C.Card)
		end
		if id == "Hamsters" then
			renderHamsters()
		else
			render()
		end
	end

	local function toast(text: string, kind: string)
		require(script.Parent.MainUI).toast(text, kind)
	end

	local function call(action: string, payload: { [string]: any }?)
		local response = DataController.request(action, payload)
		if not response.ok then
			toast(response.msg, "error")
		end
		return response.ok
	end

	-- hotbar strip
	local strip = UIKit.frame(body, { Name = "HotbarStrip", Size = UDim2.new(1, 0, 0, 78), BackgroundColor3 = C.CreamDark })
	UIKit.corner(strip, 10)
	UIKit.stroke(strip, C.Line, 1.5)
	local capacity = UIKit.label(strip, { Name = "Capacity", Size = UDim2.new(1, -20, 0, 18), Position = UDim2.fromOffset(12, 4), Font = UIKit.Fonts.Title, TextSize = 13, TextColor3 = C.Muted })
	local slotRow = UIKit.frame(strip, { Name = "Slots", Size = UDim2.new(1, -20, 0, 50), Position = UDim2.fromOffset(10, 24), BackgroundTransparency = 1 })
	UIKit.list(slotRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

	local grid = UIKit.scroll(body, { Name = "Items", Size = UDim2.new(1, -330, 1, -90), Position = UDim2.fromOffset(0, 86) })
	local empty = UIKit.label(body, { Name = "Empty", Size = UDim2.new(1, -330, 0, 120), Position = UDim2.fromOffset(0, 200), Text = "Your backpack is empty.\nWeapons, equipment and boosts you buy in the Shop show up here.", TextWrapped = true, TextSize = 17, TextColor3 = C.Muted, Font = UIKit.Fonts.Title, TextXAlignment = Enum.TextXAlignment.Center, Visible = false })
	local detail = UIKit.frame(body, { Name = "Detail", Size = UDim2.new(0, 314, 1, -90), Position = UDim2.new(1, 0, 0, 86), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = C.CreamDark })
	UIKit.corner(detail, 10)
	UIKit.stroke(detail, C.Line, 1.5)

	local function buildStrip()
		for _, child in slotRow:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local used = 0
		for slot = 1, HotbarConfig.SlotCount do
			local item = if slot == 1 then nil else ItemView.hotbarItem(slot)
			if item then
				used += 1
			end
			local cell = UIKit.button(slotRow, {
				Name = "Slot_" .. slot,
				Text = "",
				Size = UDim2.fromOffset(52, 50),
				Color = C.Card,
				LayoutOrder = slot,
				Silent = true,
				OnClick = function()
					local picked = selectedId and ItemRegistry.get(selectedId)
					if slot == 1 or not picked or not ItemRegistry.hotbarCapable(picked) then
						if item then
							selectedId = item.Id
							confirmDiscard = false
							render()
						end
						return
					end
					if call("HotbarMove", { Id = picked.Id, Slot = slot }) then
						render()
					end
				end,
			})
			UIKit.label(cell, { Text = tostring(slot), Size = UDim2.fromOffset(14, 12), Position = UDim2.fromOffset(4, 2), TextSize = 11, TextColor3 = C.Muted, Font = UIKit.Fonts.Title, ZIndex = 4 })
			local iconId = if slot == 1 then HotbarConfig.Ability.Icon elseif item then item.Icon else nil
			if iconId then
				UIKit.icon(cell, iconId, { Size = UDim2.fromOffset(28, 28), Position = UDim2.new(0.5, 0, 0, 15), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3 })
			end
			local edge = cell:FindFirstChild("Edge") :: UIStroke
			if item and item.Id == selectedId then
				edge.Color = C.Gold
				edge.Thickness = 3
			end
		end
		capacity.Text = string.format("Hotbar  %d / %d slots used  -  slot 1 is always your paws", used, HotbarConfig.SlotCount - 1)
	end

	local function buildDetail(def: any?)
		for _, child in detail:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		if not def then
			UIKit.label(detail, { Size = UDim2.new(1, -24, 0, 60), Position = UDim2.fromOffset(12, 40), Text = "Select an item to see its details.", TextWrapped = true, TextColor3 = C.Muted, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center })
			return
		end
		local accent = ItemView.rarityColor(def)
		UIKit.frame(detail, { Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = accent })
		UIKit.icon(detail, def.Icon, { Name = "DetailIcon", Size = UDim2.fromOffset(80, 80), Position = UDim2.new(0.5, 0, 0, 14), AnchorPoint = Vector2.new(0.5, 0) })
		UIKit.label(detail, { Name = "DetailName", Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromOffset(12, 98), Text = def.DisplayName, Font = UIKit.Fonts.Title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd })
		UIKit.chip(detail, string.upper(def.Category) .. (if def.Rarity then "  -  " .. string.upper(def.Rarity) else ""), accent, UDim2.fromOffset(190, 20)).Position = UDim2.new(0.5, -95, 0, 126)
		UIKit.label(detail, { Name = "DetailDesc", Size = UDim2.new(1, -28, 0, 50), Position = UDim2.fromOffset(14, 152), Text = def.Description or "", Font = UIKit.Fonts.Soft, TextSize = 14, TextColor3 = C.Muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextXAlignment = Enum.TextXAlignment.Center })
		local y = 208
		for _, row in ItemView.stats(def) do
			UIKit.label(detail, { Size = UDim2.fromOffset(130, 18), Position = UDim2.fromOffset(18, y), Text = row[1], TextSize = 13, TextColor3 = C.Muted, Font = UIKit.Fonts.Soft })
			UIKit.label(detail, { Size = UDim2.new(1, -170, 0, 18), Position = UDim2.fromOffset(148, y), Text = row[2], TextSize = 13, Font = UIKit.Fonts.Title, TextXAlignment = Enum.TextXAlignment.Right })
			y += 19
		end

		local kind = def.Equip.Kind
		local slot = ItemView.slotOf(def)
		local bottom = 1
		local function addButton(name: string, text: string, color: Color3, onClick: () -> ())
			UIKit.button(detail, { Name = name, Text = text, Size = UDim2.new(1, -28, 0, 38), Position = UDim2.new(0, 14, 1, -(bottom * 46) - 4), Color = color, TextSize = 16, OnClick = onClick })
			bottom += 1
		end
		if kind == "Consume" then
			confirmDiscard = confirmDiscard and selectedId == def.Id
			addButton("Discard", if confirmDiscard then "Tap again to discard 1" else "Discard 1", C.Red, function()
				if not confirmDiscard then
					confirmDiscard = true
					render()
					return
				end
				confirmDiscard = false
				call("DiscardItem", { Id = def.Id, Amount = 1 })
			end)
		end
		if kind == "Tool" or kind == "Consume" then
			if slot then
				addButton("MoveLeft", string.format("Hotbar slot %d  -  move left", slot), C.Card, function()
					if slot > 2 then
						call("HotbarMove", { Id = def.Id, Slot = slot - 1 })
					end
				end)
				addButton("MoveRight", "Move right", C.Card, function()
					if slot < HotbarConfig.SlotCount then
						call("HotbarMove", { Id = def.Id, Slot = slot + 1 })
					end
				end)
			end
		end
		if kind == "Tool" then
			if ItemView.heldId() == def.Id then
				addButton("Unequip", "Unequip", C.Blue, function()
					call("UnequipItem")
				end)
			else
				addButton("Equip", "Equip", C.Green, function()
					call("EquipItem", { Id = def.Id })
				end)
			end
		elseif kind == "Passive" then
			UIKit.label(detail, { Name = "Active", Size = UDim2.new(1, -28, 0, 30), Position = UDim2.new(0, 14, 1, -50), Text = "ACTIVE - works while you own it", TextSize = 14, TextColor3 = C.Green, Font = UIKit.Fonts.Title, TextXAlignment = Enum.TextXAlignment.Center })
		else
			addButton("Use", "Use now", C.Green, function()
				call("UseItem", { Id = def.Id })
			end)
		end
	end

	render = function()
		if not DataController.Data.Items then
			return
		end
		local items = BackpackUI.ownedItems()
		local chosen
		for _, def in items do
			if def.Id == selectedId then
				chosen = def
			end
		end
		if not chosen then
			chosen = items[1]
			selectedId = if chosen then chosen.Id else nil
		end
		buildStrip()
		grid:ClearAllChildren()
		UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(128, 128), CellPadding = UDim2.fromOffset(10, 10), SortOrder = Enum.SortOrder.LayoutOrder }, grid)
		UIKit.padding(grid, 4)
		for order, def in items do
			local card = UIKit.button(grid, {
				Name = "Item_" .. def.Id,
				Text = "",
				Color = C.Card,
				LayoutOrder = order,
				Silent = true,
				OnClick = function()
					selectedId = def.Id
					confirmDiscard = false
					render()
				end,
			})
			local edge = card:FindFirstChild("Edge") :: UIStroke
			edge.Color = if def.Id == selectedId then C.Gold else ItemView.rarityColor(def)
			edge.Thickness = if def.Id == selectedId then 3 else 1.5
			UIKit.icon(card, def.Icon, { Size = UDim2.fromOffset(52, 52), Position = UDim2.new(0.5, 0, 0, 14), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3 })
			UIKit.label(card, { Size = UDim2.new(1, -10, 0, 20), Position = UDim2.fromOffset(5, 72), Text = def.DisplayName, Font = UIKit.Fonts.Title, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3 })
			local badge
			if def.Equip.Kind == "Consume" then
				badge = "x" .. ItemView.count(def)
			elseif def.Equip.Kind == "Passive" then
				badge = "ACTIVE"
			elseif ItemView.heldId() == def.Id then
				badge = "EQUIPPED"
			else
				local slot = ItemView.slotOf(def)
				badge = if slot then "SLOT " .. slot else "OWNED"
			end
			UIKit.chip(card, badge, if badge == "EQUIPPED" or badge == "ACTIVE" then C.Green else C.Blue, UDim2.new(1, -20, 0, 20)).Position = UDim2.new(0, 10, 1, -28)
		end
		empty.Visible = #items == 0
		buildDetail(chosen)
	end

	panel.OnOpen[1] = function()
		confirmDiscard = false
		local focus = panel.Focus
		panel.Focus = nil
		setTab(if focus == "Hamsters" then "Hamsters" else activeTab)
	end
	DataController.onChanged(function(keys)
		if panel.IsOpen and (keys.Items or keys.Gear or keys.Hotbar) then
			render()
		end
	end)
	-- the held weapon changes without a data update
	local character = game:GetService("Players").LocalPlayer
	local function watch(char: Model)
		char.ChildAdded:Connect(function()
			if panel.IsOpen then
				render()
			end
		end)
		char.ChildRemoved:Connect(function()
			if panel.IsOpen then
				render()
			end
		end)
	end
	character.CharacterAdded:Connect(watch)
	if character.Character then
		watch(character.Character)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if input.KeyCode.Name == InputConfig.Bindings.Backpack then
			panel:Toggle()
		end
	end)
end

return BackpackUI
