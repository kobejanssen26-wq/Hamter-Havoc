--[[
	ShopUI: the centered shop window. Top row = category tabs (Weapons, Equipment, Boosts, Hamsters, Diamonds, Game
	Passes, Cosmetics, Limited), below it a grid of item cards on the left and a detail panel on the right
	(icon, name, description, real stats, price, state button).

	Everything shown comes from ShopConfig / ItemRegistry / GamepassConfig; a category only appears when it holds items
	that can really be bought (Game Passes always has its tab and shows an empty state when none is configured).
	Currencies are shown honestly: Cash, Diamonds, or Robux (game passes only - bought through Roblox's own prompt,
	the price comes from Roblox, ownership is confirmed by the server, there is no in-game Robux balance).
	The client only sends item ids; ShopSystem validates, charges and grants.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Format = require(Modules:WaitForChild("Format"))
local ItemRegistry = require(Modules:WaitForChild("ItemRegistry"))
local ShopConfig = require(Modules:WaitForChild("ShopConfig"))

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local ItemView = require(script.Parent.ItemView)
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
	local panel = UIKit.panel({ Name = "Shop", Title = "Shop", Icon = "bag", Design = Vector2.new(1000, 640), Accent = C.Gold, Subtitle = "Weapons, equipment, boosts and game passes" })
	local body = panel.Body

	-- category tabs (scroll sideways on narrow screens)
	local tabs = UIKit.new("ScrollingFrame", {
		Name = "Tabs",
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.X,
	}, body)
	UIKit.list(tabs, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)

	-- sub header: category title (left) and balances (right)
	local subtitle = UIKit.label(body, { Name = "CategoryTitle", Size = UDim2.fromOffset(360, 30), Position = UDim2.fromOffset(2, 50), Font = UIKit.Fonts.Title, TextSize = 20 })
	local balances = UIKit.frame(body, { Size = UDim2.fromOffset(420, 34), Position = UDim2.new(1, 0, 0, 48), AnchorPoint = Vector2.new(1, 0), BackgroundTransparency = 1 })
	UIKit.list(balances, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	local cashPill = UIKit.pill(balances, { Icon = "coin", Color = C.Cash, Size = UDim2.fromOffset(190, 32), LayoutOrder = 1 })
	local gemPill = UIKit.pill(balances, { Icon = "gem", Color = C.Purple, Size = UDim2.fromOffset(150, 32), LayoutOrder = 2 })

	local grid = UIKit.scroll(body, { Name = "Items", Size = UDim2.new(1, -330, 1, -92), Position = UDim2.fromOffset(0, 88) })
	local empty = UIKit.label(body, { Name = "Empty", Size = UDim2.new(1, -330, 0, 120), Position = UDim2.fromOffset(0, 180), Text = "", TextWrapped = true, TextSize = 18, TextColor3 = C.Muted, Font = UIKit.Fonts.Title, TextXAlignment = Enum.TextXAlignment.Center, Visible = false })

	local detail = UIKit.frame(body, { Name = "Detail", Size = UDim2.new(0, 314, 1, -92), Position = UDim2.new(1, 0, 0, 88), AnchorPoint = Vector2.new(1, 0), BackgroundColor3 = C.CreamDark })
	UIKit.corner(detail, 10)
	UIKit.stroke(detail, C.Line, 1.5)

	local selected = "Weapons"
	local selectedItem: string? = nil
	local inFlight: { [string]: boolean } = {}
	local passPrices: { [string]: any } = {}
	local pricesAt = 0
	local render

	local function toast(text: string, kind: string)
		require(script.Parent.MainUI).toast(text, kind)
	end

	local function loadPrices()
		if os.clock() - pricesAt < 120 then
			return
		end
		pricesAt = os.clock()
		task.spawn(function()
			local response = DataController.request("PassPrices")
			if response.ok and type(response.extra) == "table" then
				passPrices = response.extra
				if panel.IsOpen then
					render()
				end
			end
		end)
	end

	-- the item the shop entry sells (weapons / equipment / consumables) or nil (hamster capsules, roofs, passes ...)
	local function registryItem(item: any): any?
		return if item.ItemId then ItemRegistry.get(item.ItemId) else nil
	end

	-- state of one item for this player: text on the button, colour, whether it can be pressed, action
	local function stateOf(item: any, data: any)
		local currency = CURRENCY[item.Currency] or CURRENCY.Gems
		if item.Kind == "Pass" then
			if item.Unconfigured then
				return "Not configured", false, C.Card, nil, "none"
			end
			if data.Passes and data.Passes[item.PassKey] then
				return "Owned", false, C.Card, nil, "none"
			end
			local robux = passPrices[item.PassKey]
			return if type(robux) == "number" then ("R$ " .. Format.commas(robux)) else "Buy with Robux", true, C.Gold, nil, "buy"
		end
		if item.Kind == "Gear" then
			local def = registryItem(item)
			if def and ItemView.count(def) > 0 then
				if def.Equip.Kind == "Tool" then
					if ItemView.heldId() == def.Id then
						return "Unequip", true, C.Blue, nil, "unequip"
					end
					return "Equip", true, C.Blue, nil, "equip"
				end
				return "Owned", false, C.Card, nil, "none"
			end
		end
		if item.Kind == "Roof" and data.Cosmetics then
			if data.Cosmetics.Roof == item.RoofKey then
				return "Equipped", false, C.Card, nil, "none"
			elseif data.Cosmetics.Owned[item.RoofKey] then
				return "Equip", true, C.Blue, nil, "buy"
			end
		end
		if item.MinRebirth and (data.Rebirths or 0) < item.MinRebirth then
			return string.format("Locked - rebirth %d", item.MinRebirth), false, C.Card, "lock", "none"
		end
		if balanceOf(item.Currency) < item.Price then
			return Format.short(item.Price), false, Color3.fromRGB(110, 62, 62), currency.Icon, "buy"
		end
		return Format.short(item.Price), true, C.Green, currency.Icon, "buy"
	end

	local function buy(item: any)
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
			return
		end
		AudioController.play("Reward")
		toast(result.msg, "success")
		if item.Currency ~= "Robux" and not (result.extra and result.extra.Equipped) then
			UIKit.floatText(body, string.format("-%s %s", Format.short(item.Price), string.lower(CURRENCY[item.Currency].Name)), CURRENCY[item.Currency].Color, UDim2.fromScale(0.6, 0.5))
		end
		if result.extra and result.extra.SpeciesId then
			require(script.Parent.AnnouncementUI).reveal(result.extra.SpeciesId, result.extra.IsNew == true)
		end
	end

	local function act(item: any, action: string)
		if action == "buy" then
			buy(item)
		elseif action == "equip" and item.ItemId then
			local response = DataController.request("EquipItem", { Id = item.ItemId })
			if not response.ok then
				toast(response.msg, "error")
			end
		elseif action == "unequip" then
			DataController.request("UnequipItem")
		end
	end

	local function buildCard(item: any, order: number, data: any)
		local text, enabled, _color, priceIcon = stateOf(item, data)
		local currency = CURRENCY[item.Currency] or CURRENCY.Gems
		local def = registryItem(item)
		local accent = if def then ItemView.rarityColor(def) else currency.Color
		local card = UIKit.button(grid, {
			Name = "Item_" .. item.Id,
			Text = "",
			Color = C.Card,
			LayoutOrder = order,
			Silent = true,
			OnClick = function()
				selectedItem = item.Id
				render()
			end,
		})
		local stroke = card:FindFirstChild("Edge") :: UIStroke
		stroke.Color = if selectedItem == item.Id then C.Gold else accent
		stroke.Thickness = if selectedItem == item.Id then 3 else 1.5
		UIKit.icon(card, item.Icon, { Size = UDim2.fromOffset(56, 56), Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3 })
		UIKit.label(card, { Size = UDim2.new(1, -12, 0, 20), Position = UDim2.fromOffset(6, 74), Text = item.Name, Font = UIKit.Fonts.Title, TextColor3 = C.Ink, TextSize = 14, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3 })
		-- price line / state
		local priceRow = UIKit.iconText(card, {
			Icon = priceIcon or (if item.Kind == "Pass" then "gift" else nil),
			Text = if item.Kind == "Pass" and not item.Unconfigured and text == "Buy with Robux" then "Robux" else text,
			Size = UDim2.new(1, -12, 0, 22),
			Position = UDim2.fromOffset(6, 100),
			TextSize = 14,
			TextColor = if enabled or text == "Owned" or text == "Equipped" or text == "Unequip" then C.White else C.Muted,
			Font = UIKit.Fonts.Title,
			Align = Enum.HorizontalAlignment.Center,
			ZIndex = 3,
		})
		priceRow.Frame.Name = "PriceRow"
		-- ownership badge
		local owned = false
		if item.Kind == "Gear" and def then
			owned = ItemView.count(def) > 0
		elseif item.Kind == "Item" and def then
			local count = ItemView.count(def)
			if count > 0 then
				UIKit.chip(card, "x" .. count, C.Blue, UDim2.fromOffset(40, 18)).Position = UDim2.fromOffset(6, 6)
			end
		elseif item.Kind == "Pass" then
			owned = data.Passes ~= nil and data.Passes[item.PassKey] == true
		end
		if owned then
			UIKit.chip(card, "OWNED", C.Green, UDim2.fromOffset(60, 18)).Position = UDim2.fromOffset(6, 6)
		end
		if item.Unconfigured then
			card.BackgroundTransparency = 0.45
		end
		if item.Limited and item.Limited.EndsAt then
			UIKit.chip(card, "Ends " .. Format.clock(math.max(0, item.Limited.EndsAt - os.time())), C.Red, UDim2.fromOffset(96, 18)).Position = UDim2.new(1, -102, 0, 6)
		end
	end

	local function buildDetail(item: any?, data: any)
		for _, child in detail:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		if not item then
			UIKit.label(detail, { Size = UDim2.new(1, -24, 0, 60), Position = UDim2.fromOffset(12, 40), Text = "Select an item to see its details.", TextWrapped = true, TextColor3 = C.Muted, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Center })
			return
		end
		local def = registryItem(item)
		local currency = CURRENCY[item.Currency] or CURRENCY.Gems
		local accent = if def then ItemView.rarityColor(def) else currency.Color
		UIKit.frame(detail, { Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = accent })
		UIKit.icon(detail, item.Icon, { Name = "DetailIcon", Size = UDim2.fromOffset(84, 84), Position = UDim2.new(0.5, 0, 0, 16), AnchorPoint = Vector2.new(0.5, 0) })
		UIKit.label(detail, { Name = "DetailName", Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromOffset(12, 106), Text = item.Name, Font = UIKit.Fonts.Title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd })
		local tagText = if item.Kind == "Pass" then "GAME PASS" elseif def then string.upper(def.Category) .. (if def.Rarity then "  -  " .. string.upper(def.Rarity) else "") else string.upper(item.Category)
		UIKit.chip(detail, tagText, accent, UDim2.fromOffset(170, 20)).Position = UDim2.new(0.5, -85, 0, 134)
		UIKit.label(detail, { Name = "DetailDesc", Size = UDim2.new(1, -28, 0, 54), Position = UDim2.fromOffset(14, 160), Text = item.Desc, Font = UIKit.Fonts.Soft, TextSize = 14, TextColor3 = C.Muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top, TextXAlignment = Enum.TextXAlignment.Center })

		-- stats rows
		local rows = {}
		if def then
			rows = ItemView.stats(def)
		elseif item.Kind == "Pass" then
			local entry = require(Modules:WaitForChild("GamepassConfig")).ByKey[item.PassKey]
			if entry then
				for stat, value in entry.Benefit do
					table.insert(rows, { stat, tostring(value) })
				end
			end
		end
		local y = 218
		for _, row in rows do
			if y > 300 then
				break
			end
			UIKit.label(detail, { Size = UDim2.fromOffset(130, 18), Position = UDim2.fromOffset(18, y), Text = row[1], TextSize = 13, TextColor3 = C.Muted, Font = UIKit.Fonts.Soft })
			UIKit.label(detail, { Size = UDim2.new(1, -170, 0, 18), Position = UDim2.fromOffset(148, y), Text = row[2], TextSize = 13, Font = UIKit.Fonts.Title, TextXAlignment = Enum.TextXAlignment.Right })
			y += 20
		end

		local text, enabled, color, priceIcon, action = stateOf(item, data)
		local button = UIKit.button(detail, {
			Name = "Action",
			Text = text,
			Size = UDim2.new(1, -28, 0, 44),
			Position = UDim2.new(0, 14, 1, -102),
			Color = color,
			TextSize = 18,
			OnClick = function()
				act(item, action)
			end,
		})
		if priceIcon then
			UIKit.setButtonContent(button, priceIcon, text, if enabled then C.White else Color3.fromRGB(236, 150, 146))
		end
		UIKit.setEnabled(button, enabled)
		if not enabled then
			button.BackgroundColor3 = color
		end

		local hint = ""
		if item.Kind == "Pass" then
			if item.Unconfigured then
				hint = "Not configured yet (no PassId). Add it to GamepassConfig. Never purchasable until then."
			else
				hint = "Paid with Robux through Roblox. The benefit is granted after the server confirms you own it."
				UIKit.button(detail, {
					Name = "Refresh",
					Text = "Refresh purchases",
					Size = UDim2.new(1, -28, 0, 30),
					Position = UDim2.new(0, 14, 1, -52),
					Color = C.Card,
					TextSize = 14,
					OnClick = function()
						local response = DataController.request("PassRefresh")
						toast(response.msg, if response.ok then "success" else "error")
					end,
				})
			end
		elseif def and def.Equip.Kind == "Tool" then
			hint = "Equip it from the hotbar (number keys) or the Backpack."
		elseif def and def.Equip.Kind == "Passive" then
			hint = "Works automatically while you own it."
		end
		if hint ~= "" then
			UIKit.label(detail, { Name = "Hint", Size = UDim2.new(1, -28, 0, 36), Position = UDim2.new(0, 14, 1, -142), Text = hint, TextSize = 12, TextColor3 = C.Muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center })
		end
	end

	local function buildTabs(categories: { any })
		for _, child in tabs:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for index, category in categories do
			local tab = UIKit.button(tabs, {
				Name = "Tab_" .. category.Id,
				Text = "",
				Size = UDim2.fromOffset(136, 38),
				Color = if category.Id == selected then C.Bronze else C.Card,
				LayoutOrder = index,
				OnClick = function()
					selected = category.Id
					selectedItem = nil
					render()
				end,
			})
			UIKit.icon(tab, category.Icon, { Size = UDim2.fromOffset(22, 22), Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 })
			UIKit.label(tab, { Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(38, 0), Text = category.Name, Font = UIKit.Fonts.Title, TextSize = 14, TextColor3 = C.White, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 3 })
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
		local current
		for _, category in categories do
			if category.Id == selected then
				current = category
			end
		end
		if not current and categories[1] then
			current = categories[1]
			selected = current.Id
		end
		buildTabs(categories)
		subtitle.Text = if current then current.Name else "Shop"

		grid:ClearAllChildren()
		UIKit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(150, 132),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, grid)
		UIKit.padding(grid, 4)

		local items = if current then current.Items else {}
		local chosen
		for order, item in items do
			if item.Id == selectedItem then
				chosen = item
			end
			buildCard(item, order, data)
		end
		if not chosen and items[1] then
			chosen = items[1]
			selectedItem = chosen.Id
			for _, child in grid:GetChildren() do
				local edge = child:FindFirstChild("Edge")
				if child.Name == "Item_" .. chosen.Id and edge then
					edge.Color = C.Gold
					edge.Thickness = 3
				end
			end
		end
		empty.Visible = #items == 0
		if #items == 0 then
			empty.Text = if selected == "Gamepasses" then "No game passes are available yet.\nThey appear here as soon as a PassId is configured." else "Nothing to buy here right now."
		end
		buildDetail(chosen, data)
		if selected == "Gamepasses" then
			loadPrices()
		end
	end

	panel.OnOpen[1] = function()
		if panel.Focus then
			selected = panel.Focus
			selectedItem = nil
			panel.Focus = nil
		end
		render()
	end

	DataController.onChanged(function(keys)
		if panel.IsOpen and (keys.Passes or keys.Cosmetics or keys.Items or keys.Gear or keys.Hotbar or keys.Rebirths) then
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
