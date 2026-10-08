--[[
	InventoryUI ("Hamsters"): everything you own. Put hamsters to work on the wheels in your apartment
	(they earn coins there; the best ones get the floors with the biggest bonus), sell extras, or let the
	game pick your best ones. Paged so only a handful of 3D icons render.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Format = require(Modules:WaitForChild("Format"))
local HamsterDatabase = require(Modules:WaitForChild("HamsterDatabase"))
local RarityConfig = require(Modules:WaitForChild("RarityConfig"))

local DataController = require(script.Parent.Parent.Controllers.DataController)
local UIKit = require(script.Parent.UIKit)

local InventoryUI = {}

local C = UIKit.Colors
local PAGE_SIZE = 8

function InventoryUI.start()
	local panel = UIKit.panel({ Name = "Inventory", Title = "My Hamsters", Icon = "Hamster", Design = Vector2.new(940, 640), Accent = C.Peach })
	local body = panel.Body

	local top = UIKit.card(body, { Size = UDim2.new(1, 0, 0, 52) })
	UIKit.icon(top, "Wheel", 34, { Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
	local slotsLabel = UIKit.label(top, {
		Position = UDim2.fromOffset(54, 0),
		Size = UDim2.fromOffset(330, 52),
		Font = UIKit.Fonts.Title,
		TextSize = 20,
		Text = "Shelf: 0/3",
	})
	local function notify(text: string, kind: string)
		require(script.Parent.MainUI).toast(text, kind)
	end
	UIKit.button(top, {
		Text = "Equip Best",
		Icon = "Star",
		IconSize = 24,
		Size = UDim2.fromOffset(160, 38),
		Position = UDim2.new(1, -208, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = C.Green,
		TextSize = 16,
		OnClick = function()
			local result = DataController.request("EquipBest")
			notify(result.msg, if result.ok then "success" else "error")
		end,
	})
	UIKit.button(top, {
		Text = "Sell Duplicates",
		Icon = "Coins",
		IconSize = 24,
		Size = UDim2.fromOffset(190, 38),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = C.Peach,
		TextSize = 16,
		OnClick = function()
			local result = DataController.request("SellDuplicates", {})
			if result.ok then
				notify(string.format("%s for %s", result.msg, Format.coins(result.extra or 0)), "success")
			else
				notify(result.msg, "error")
			end
		end,
	})

	local grid = UIKit.frame(body, { Size = UDim2.new(1, 0, 1, -112), Position = UDim2.fromOffset(0, 60), BackgroundTransparency = 1 })
	local emptyLabel = UIKit.label(body, {
		Size = UDim2.new(1, 0, 0, 80),
		Position = UDim2.fromOffset(0, 200),
		Text = "No hamsters yet!\nGrab one at the plaza as it runs past.",
		TextSize = 22,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = C.Muted,
		Font = UIKit.Fonts.Title,
		Visible = false,
	})

	local pager = UIKit.frame(body, { Size = UDim2.new(1, 0, 0, 44), Position = UDim2.new(0, 0, 1, -44), BackgroundTransparency = 1 })
	local page = 1
	local pageLabel = UIKit.label(pager, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = UIKit.Fonts.Title,
		TextSize = 18,
		Text = "1 / 1",
	})
	local render
	UIKit.button(pager, {
		Text = "<",
		Size = UDim2.fromOffset(60, 38),
		Position = UDim2.new(0.5, -200, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = C.Peach,
		OnClick = function()
			page = math.max(1, page - 1)
			render()
		end,
	})
	UIKit.button(pager, {
		Text = ">",
		Size = UDim2.fromOffset(60, 38),
		Position = UDim2.new(0.5, 200, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = C.Peach,
		OnClick = function()
			page += 1
			render()
		end,
	})

	render = function()
		local data = DataController.Data
		if not data.Inventory then
			return
		end
		local derived = DataController.derived()
		local slots = derived.Slots or 3
		local equippedCounts: { [string]: number } = {}
		for _, id in data.Equipped do
			equippedCounts[id] = (equippedCounts[id] or 0) + 1
		end
		slotsLabel.Text = string.format("Working: %d / %d wheels", #data.Equipped, math.floor(slots))

		local entries = {}
		for speciesId, count in data.Inventory do
			local species = HamsterDatabase.ById[speciesId]
			if species and count > 0 then
				table.insert(entries, { Species = species, Count = count })
			end
		end
		table.sort(entries, function(a, b)
			local ia, ib = HamsterDatabase.income(a.Species), HamsterDatabase.income(b.Species)
			if ia ~= ib then
				return ia > ib
			end
			return a.Species.Id < b.Species.Id
		end)

		local pages = math.max(1, math.ceil(#entries / PAGE_SIZE))
		page = math.clamp(page, 1, pages)
		pageLabel.Text = string.format("Page %d / %d  -  %d hamsters", page, pages, #entries)
		emptyLabel.Visible = #entries == 0

		grid:ClearAllChildren()
		UIKit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(216, 206),
			CellPadding = UDim2.fromOffset(9, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}, grid)

		local multiplier = derived.IncomeMultiplier or 1
		for index = (page - 1) * PAGE_SIZE + 1, math.min(#entries, page * PAGE_SIZE) do
			local entry = entries[index]
			local species = entry.Species
			local definition = RarityConfig.ById[species.Rarity]
			local color = UIKit.rarityColor(definition)
			local equipped = equippedCounts[species.Id] or 0

			local card = UIKit.card(grid, { LayoutOrder = index })
			local cardStroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
			cardStroke.Color = UIKit.lighter(color, 0.2)
			cardStroke.Thickness = 2.5
			local glow = UIKit.frame(card, { Size = UDim2.new(1, -8, 0, 100), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = UIKit.lighter(color, 0.82) })
			UIKit.corner(glow, 14)
			UIKit.hamsterIcon(card, species, { Size = UDim2.new(1, -8, 0, 100), Position = UDim2.fromOffset(4, 2) })
			UIKit.chip(card, string.upper(definition.Name), color, UDim2.fromOffset(86, 20)).Position = UDim2.fromOffset(8, 6)
			if entry.Count > 1 then
				local count = UIKit.chip(card, "x" .. entry.Count, C.Ink, UDim2.fromOffset(40, 20))
				count.Position = UDim2.new(1, -48, 0, 6)
			end
			UIKit.label(card, {
				Size = UDim2.new(1, -10, 0, 22),
				Position = UDim2.fromOffset(5, 102),
				Text = species.Name,
				TextSize = 17,
				Font = UIKit.Fonts.Title,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			local incomeRow, incomeLabel = UIKit.amount(card, "Coin", string.format("+%s/s each", Format.coins(HamsterDatabase.income(species) * multiplier)), { Size = UDim2.fromOffset(150, 18), TextSize = 14, Color = C.GoldDark })
			incomeRow.Position = UDim2.new(0.5, -60, 0, 125)
			incomeLabel.Font = UIKit.Fonts.Body
			if equipped > 0 then
				UIKit.label(card, {
					Size = UDim2.new(1, -10, 0, 16),
					Position = UDim2.fromOffset(5, 142),
					Text = string.format("%d working on a wheel", equipped),
					TextSize = 12,
					TextColor3 = C.Green,
					TextXAlignment = Enum.TextXAlignment.Center,
				})
			end

			local free = entry.Count - equipped
			local equipButton = UIKit.button(card, {
				Text = "Equip",
				Size = UDim2.fromOffset(98, 32),
				Position = UDim2.fromOffset(8, 166),
				Color = C.Green,
				TextSize = 15,
				OnClick = function()
					local result = DataController.request("Equip", { Id = species.Id })
					if not result.ok then
						notify(result.msg, "error")
					end
				end,
			})
			UIKit.setEnabled(equipButton, free > 0 and #data.Equipped < slots)
			UIKit.button(card, {
				Text = if equipped > 0 then "Remove" else "Sell",
				Size = UDim2.fromOffset(98, 32),
				Position = UDim2.new(1, -106, 0, 166),
				Color = if equipped > 0 then Color3.fromRGB(150, 140, 160) else C.Red,
				TextSize = 15,
				OnClick = function()
					if equipped > 0 then
						DataController.request("Unequip", { Id = species.Id })
					else
						local result = DataController.request("Sell", { Id = species.Id, Count = 1 })
						if result.ok then
							notify(string.format("Sold %s for %s", species.Name, Format.coins(result.extra or 0)), "success")
						else
							notify(result.msg, "error")
						end
					end
				end,
			})
		end
	end

	table.insert(panel.OnOpen, function()
		page = 1
		render()
	end)
	DataController.onChanged(function(keys)
		if panel.IsOpen and (keys.Inventory or keys.Equipped or keys.Derived) then
			render()
		end
	end)
end

return InventoryUI
