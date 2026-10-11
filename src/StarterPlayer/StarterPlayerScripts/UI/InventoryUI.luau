--[[
	InventoryUI ("Hamsters"): everything you own. Equip hamsters onto your house shelf (they earn coins
	there), sell extras, or let the game equip your best ones. Every owned hamster is listed in a scroll view.
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

function InventoryUI.start()
	local panel = UIKit.panel({ Name = "Inventory", Title = "My Hamsters", Icon = "hamster", Design = Vector2.new(940, 640), Accent = C.Peach })
	local body = panel.Body

	local top = UIKit.frame(body, { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.Card })
	UIKit.corner(top, 14)
	UIKit.stroke(top, C.Line, 2)
	local slotsLabel = UIKit.label(top, {
		Position = UDim2.fromOffset(16, 0),
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
		Size = UDim2.fromOffset(160, 38),
		Position = UDim2.new(1, -184, 0.5, 0),
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
		Size = UDim2.fromOffset(170, 38),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = C.Peach,
		TextSize = 16,
		OnClick = function()
			local result = DataController.request("SellDuplicates", {})
			if result.ok then
				notify(string.format("%s for %s cash", result.msg, Format.short(result.extra or 0)), "success")
			else
				notify(result.msg, "error")
			end
		end,
	})

	local grid = UIKit.scroll(body, { Size = UDim2.new(1, 0, 1, -64), Position = UDim2.fromOffset(0, 60) })
	local render
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
		slotsLabel.Text = string.format("Working in wheels: %d / %d slots", #data.Equipped, math.floor(slots))

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

		emptyLabel.Visible = #entries == 0

		-- every owned hamster is listed (scroll down); you choose exactly which ones work in the wheels
		grid:ClearAllChildren()
		UIKit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(216, 236),
			CellPadding = UDim2.fromOffset(9, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}, grid)

		local multiplier = derived.IncomeMultiplier or 1
		for index = 1, #entries do
			local entry = entries[index]
			local species = entry.Species
			local definition = RarityConfig.ById[species.Rarity]
			local color = UIKit.rarityColor(definition)
			local equipped = equippedCounts[species.Id] or 0

			local card = UIKit.frame(grid, { LayoutOrder = index })
			UIKit.vivid(card, color, { Corner = 12, Outline = if equipped > 0 then 5 else 3.5 })
			if equipped > 0 then
				card:FindFirstChildOfClass("UIStroke").Color = C.Green
			end
			UIKit.hamsterIcon(card, species, { Size = UDim2.new(1, -8, 0, 100), Position = UDim2.fromOffset(4, 2) })
			UIKit.chip(card, string.upper(definition.Name), Color3.fromRGB(30, 24, 44), UDim2.fromOffset(86, 20)).Position = UDim2.fromOffset(8, 6)
			if entry.Count > 1 then
				local count = UIKit.chip(card, "x" .. entry.Count, Color3.fromRGB(30, 24, 44), UDim2.fromOffset(40, 20))
				count.Position = UDim2.new(1, -48, 0, 6)
			end
			UIKit.cartoon(UIKit.label(card, {
				Size = UDim2.new(1, -10, 0, 22),
				Position = UDim2.fromOffset(5, 102),
				Text = species.Name,
				TextSize = 18,
				Font = UIKit.Fonts.Title,
				TextColor3 = C.White,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}), 2.5)
			local incomeRow = UIKit.iconText(card, {
				Icon = "coin",
				Text = string.format("+%s/s each", Format.short(HamsterDatabase.income(species) * multiplier)),
				Size = UDim2.new(1, -10, 0, 18),
				Position = UDim2.fromOffset(5, 123),
				TextSize = 13,
				TextColor = C.White,
				Font = UIKit.Fonts.Body,
				Align = Enum.HorizontalAlignment.Center,
			})
			UIKit.cartoon(incomeRow.Label, 2)
			if equipped > 0 then
				UIKit.cartoon(UIKit.label(card, {
					Size = UDim2.new(1, -10, 0, 16),
					Position = UDim2.fromOffset(5, 142),
					Text = string.format("%d working in wheels", equipped),
					TextSize = 12,
					TextColor3 = C.White,
					TextXAlignment = Enum.TextXAlignment.Center,
				}), 2)
			end

			local free = entry.Count - equipped
			local work = UIKit.button(card, {
				Text = "Work +",
				Size = UDim2.fromOffset(98, 32),
				Position = UDim2.fromOffset(8, 160),
				Color = C.Green,
				TextSize = 15,
				OnClick = function()
					local result = DataController.request("Equip", { Id = species.Id })
					if not result.ok then
						notify(result.msg, "error")
					end
				end,
			})
			UIKit.setEnabled(work, free > 0 and #data.Equipped < slots)
			local rest = UIKit.button(card, {
				Text = "Rest −",
				Size = UDim2.fromOffset(98, 32),
				Position = UDim2.new(1, -106, 0, 160),
				Color = C.BrownLight,
				TextSize = 15,
				OnClick = function()
					DataController.request("Unequip", { Id = species.Id })
				end,
			})
			UIKit.setEnabled(rest, equipped > 0)
			local sell = UIKit.button(card, {
				Text = "Sell one",
				Size = UDim2.new(1, -16, 0, 28),
				Position = UDim2.fromOffset(8, 198),
				Color = C.Red,
				TextSize = 14,
				OnClick = function()
					local result = DataController.request("Sell", { Id = species.Id, Count = 1 })
					if result.ok then
						notify(string.format("Sold %s for %s cash", species.Name, Format.short(result.extra or 0)), "success")
					else
						notify(result.msg, "error")
					end
				end,
			})
			UIKit.setEnabled(sell, free > 0)
		end
	end

	panel.OnOpen[1] = function()
		render()
	end
	DataController.onChanged(function(keys)
		if panel.IsOpen and (keys.Inventory or keys.Equipped or keys.Derived) then
			render()
		end
	end)
end

return InventoryUI
