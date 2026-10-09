--[[
	ShopUI: the large central shop (opened at the shop stall in the plaza, or from the small HUD shortcut).
	Everything shown comes from ShopConfig: categories only appear when they hold items that can really be bought,
	and every item names its currency (Cash / Diamonds / Robux) and price. The client only sends the item id;
	the server validates, charges and grants atomically (ShopSystem.buy).
	States: Available, Not enough <currency>, Locked (rebirth), Owned, Equipped, Limited (timer).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Format = require(Modules:WaitForChild("Format"))
local ShopConfig = require(Modules:WaitForChild("ShopConfig"))

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local UIKit = require(script.Parent.UIKit)

local ShopUI = {}

local C = UIKit.Colors
local player = Players.LocalPlayer

local CURRENCY = {
	Coins = { Icon = "coin", Name = "Cash", Color = C.Cash },
	Gems = { Icon = "gem", Name = "Diamonds", Color = C.Purple },
	Robux = { Icon = "gift", Name = "Robux", Color = C.Gold },
}

local function balanceOf(currency: string): number
	if currency == "Coins" then
		return DataController.coins()
	elseif currency == "Gems" then
		return DataController.gems()
	end
	return math.huge
end

function ShopUI.start()
	local panel = UIKit.panel({ Name = "Shop", Title = "Shop", Icon = "bag", Design = Vector2.new(1000, 640), Accent = C.Gold, Subtitle = "Boosts, hamsters and cosmetics" })
	local body = panel.Body

	-- balances (top right of the body)
	local balances = UIKit.frame(body, { Size = UDim2.fromOffset(420, 34), Position = UDim2.new(1, 0, 0, 0), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1 })
	UIKit.list(balances, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	local cashPill = UIKit.pill(balances, { Icon = "coin", Color = C.Cash, Size = UDim2.fromOffset(190, 32), LayoutOrder = 1 })
	local gemPill = UIKit.pill(balances, { Icon = "gem", Color = C.Purple, Size = UDim2.fromOffset(150, 32), LayoutOrder = 2 })

	-- category list (left)
	local categoryColumn = UIKit.frame(body, { Name = "Categories", Size = UDim2.new(0, 190, 1, -48), Position = UDim2.fromOffset(0, 46), BackgroundColor3 = C.CreamDark })
	UIKit.corner(categoryColumn, 8)
	UIKit.padding(categoryColumn, 8)
	UIKit.list(categoryColumn, Enum.FillDirection.Vertical, 6)

	local grid = UIKit.scroll(body, { Size = UDim2.new(1, -204, 1, -48), Position = UDim2.fromOffset(204, 46) })

	local selected = "Boosts"
	local inFlight: { [string]: boolean } = {}
	local render

	local function toast(text: string, kind: string)
		require(script.Parent.MainUI).toast(text, kind)
	end

	local function buy(item: any, card: GuiObject)
		if inFlight[item.Id] then
			return
		end
		inFlight[item.Id] = true
		local result = DataController.request("ShopBuy", { Id = item.Id })
		task.delay(0.5, function()
			inFlight[item.Id] = nil
		end)
		if not result.ok then
			toast(result.msg, "error")
			AudioController.play("Error")
			-- small shake: the purchase did not happen
			local origin = card.Position
			for _, offset in { 6, -6, 4, 0 } do
				UIKit.tween(card, 0.04, { Position = origin + UDim2.fromOffset(offset, 0) })
				task.wait(0.04)
			end
			return
		end
		AudioController.play("Reward")
		toast(result.msg, "success")
		if item.Currency ~= "Robux" and not (result.extra and result.extra.Equipped) then
			UIKit.floatText(body, string.format("-%s %s", Format.short(item.Price), string.lower(CURRENCY[item.Currency].Name)), CURRENCY[item.Currency].Color, UDim2.fromScale(0.6, 0.5))
		end
		-- purchase animation: the card pops
		local pop = UIKit.new("UIScale", { Scale = 1 }, card)
		UIKit.tween(pop, 0.1, { Scale = 1.06 })
		task.delay(0.1, function()
			UIKit.tween(pop, 0.2, { Scale = 1 }, Enum.EasingStyle.Back)
			task.delay(0.25, function()
				pop:Destroy()
			end)
		end)
		if result.extra and result.extra.SpeciesId then
			require(script.Parent.AnnouncementUI).reveal(result.extra.SpeciesId, result.extra.IsNew == true)
		end
	end

	-- state of one item for this player: text on the button, colour, and whether it can be pressed
	local function stateOf(item: any, data: any)
		local currency = CURRENCY[item.Currency] or CURRENCY.Gems
		if item.Kind == "Pass" and data.Passes and data.Passes[item.PassKey] then
			return "Owned", false, C.Card, nil
		end
		if item.Kind == "Roof" and data.Cosmetics then
			if data.Cosmetics.Roof == item.RoofKey then
				return "Equipped", false, C.Card, nil
			elseif data.Cosmetics.Owned[item.RoofKey] then
				return "Equip", true, C.Blue, nil
			end
		end
		if item.MinRebirth and (data.Rebirths or 0) < item.MinRebirth then
			return string.format("Locked - rebirth %d", item.MinRebirth), false, C.Card, "lock"
		end
		if item.Currency == "Robux" then
			return "R$ " .. Format.short(item.Price), true, C.Gold, nil
		end
		if balanceOf(item.Currency) < item.Price then
			return Format.short(item.Price), false, Color3.fromRGB(110, 62, 62), currency.Icon
		end
		return Format.short(item.Price), true, C.Green, currency.Icon
	end

	local function buildCard(item: any, order: number, data: any)
		local card = UIKit.frame(grid, { LayoutOrder = order })
		UIKit.vivid(card, (CURRENCY[item.Currency] or CURRENCY.Gems).Color, { Corner = 8, Outline = 1.5 })
		UIKit.icon(card, item.Icon, { Size = UDim2.fromOffset(60, 60), Position = UDim2.new(0.5, 0, 0, 14), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3 })
		UIKit.label(card, {
			Size = UDim2.new(1, -16, 0, 22),
			Position = UDim2.fromOffset(8, 80),
			Text = item.Name,
			Font = UIKit.Fonts.Title,
			TextColor3 = C.Ink,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			ZIndex = 3,
		})
		UIKit.label(card, {
			Size = UDim2.new(1, -20, 0, 44),
			Position = UDim2.fromOffset(10, 104),
			Text = item.Desc,
			Font = UIKit.Fonts.Soft,
			TextSize = 12,
			TextColor3 = C.Muted,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Top,
			ZIndex = 3,
		})
		-- how many of this consumable you already hold
		if item.Kind == "Item" then
			local owned = (data.Items and data.Items[item.ItemId]) or 0
			if owned > 0 then
				UIKit.chip(card, "Owned x" .. owned, C.Blue, UDim2.fromOffset(78, 18)).Position = UDim2.fromOffset(8, 8)
			end
		end
		-- active boost countdown / limited offer timer
		if item.Limited and item.Limited.EndsAt then
			UIKit.chip(card, "Ends " .. Format.clock(math.max(0, item.Limited.EndsAt - os.time())), C.Red, UDim2.fromOffset(96, 18)).Position = UDim2.new(1, -104, 0, 8)
		end

		local text, enabled, color, priceIcon = stateOf(item, data)
		local button = UIKit.button(card, {
			Text = text,
			Size = UDim2.new(1, -20, 0, 36),
			Position = UDim2.new(0, 10, 1, -46),
			Color = color,
			TextSize = 15,
			Name = "Buy_" .. item.Id,
			OnClick = function()
				buy(item, card)
			end,
		})
		if priceIcon then
			UIKit.setButtonContent(button, priceIcon, text, if enabled then C.White else Color3.fromRGB(236, 150, 146))
		end
		UIKit.setEnabled(button, enabled)
		if not enabled then
			button.BackgroundColor3 = color
		end
	end

	local categoryButtons: { [string]: TextButton } = {}
	local function buildCategories(categories: { any })
		for _, child in categoryColumn:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		categoryButtons = {}
		for index, category in categories do
			local button = UIKit.button(categoryColumn, {
				Text = "",
				Size = UDim2.new(1, 0, 0, 44),
				Color = if category.Id == selected then C.Peach else C.Card,
				LayoutOrder = index,
				Name = "Category_" .. category.Id,
				OnClick = function()
					selected = category.Id
					render()
				end,
			})
			UIKit.icon(button, category.Icon, { Size = UDim2.fromOffset(24, 24), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 })
			UIKit.label(button, { Size = UDim2.new(1, -46, 1, 0), Position = UDim2.fromOffset(42, 0), Text = category.Name, Font = UIKit.Fonts.Title, TextSize = 15, TextColor3 = C.White, ZIndex = 3 })
			categoryButtons[category.Id] = button
		end
	end

	render = function()
		local data = DataController.Data
		if not data.Passes then
			return
		end
		cashPill.Value.Text = Format.short(DataController.coins())
		gemPill.Value.Text = Format.short(DataController.gems())

		local categories = ShopConfig.categories()
		local found = false
		for _, category in categories do
			found = found or category.Id == selected
		end
		if not found and categories[1] then
			selected = categories[1].Id
		end
		buildCategories(categories)

		grid:ClearAllChildren()
		UIKit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(176, 232),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, grid)
		UIKit.padding(grid, 4)
		for _, category in categories do
			if category.Id == selected then
				for order, item in category.Items do
					buildCard(item, order, data)
				end
			end
		end
	end

	panel.OnOpen[1] = function()
		if panel.Focus then
			selected = panel.Focus
			panel.Focus = nil
		end
		render()
	end

	DataController.onChanged(function(keys)
		if panel.IsOpen and (keys.Passes or keys.Cosmetics or keys.Items or keys.Rebirths) then
			render()
		end
	end)
	for _, name in { "Coins", "Gems" } do
		player:GetAttributeChangedSignal(name):Connect(function()
			if panel.IsOpen then
				render()
			end
		end)
	end
end

return ShopUI
