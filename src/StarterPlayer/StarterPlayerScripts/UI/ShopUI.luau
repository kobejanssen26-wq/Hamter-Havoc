--[[
	ShopUI: Pets (capsules), Boosts, Currency, Gamepasses, Cosmetics.
	Gem items are bought instantly; Robux items open Roblox's own purchase prompt.
	Items whose pass/product id is still 0 show "Coming soon" instead of a broken button.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Format = require(Modules:WaitForChild("Format"))
local ShopConfig = require(Modules:WaitForChild("ShopConfig"))

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local UIKit = require(script.Parent.UIKit)

local ShopUI = {}

local C = UIKit.Colors

local TILE_COLORS = { Color3.fromRGB(255, 60, 190), Color3.fromRGB(40, 150, 255), Color3.fromRGB(60, 210, 90), Color3.fromRGB(255, 150, 20), Color3.fromRGB(150, 70, 255), Color3.fromRGB(0, 200, 210) }

local SECTION_COLORS = {
	Pets = C.Pink,
	Boosts = C.Mint,
	Currency = C.Sky,
	Gamepasses = C.Gold,
	Cosmetics = C.Purple,
}

function ShopUI.start()
	local panel = UIKit.panel({ Name = "Shop", Title = "Shop", Icon = "bag", Design = Vector2.new(980, 660), Accent = C.Pink })
	local body = panel.Body

	local gemsRow = UIKit.iconText(body, {
		Icon = "gem",
		Text = "0",
		Size = UDim2.fromOffset(200, 40),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		TextSize = 24,
		TextColor = Color3.fromRGB(70, 140, 220),
		Align = Enum.HorizontalAlignment.Right,
	})
	local gemsLabel = gemsRow.Label

	local defs = {}
	for _, section in ShopConfig.Sections do
		table.insert(defs, { Id = section, Text = section, Color = SECTION_COLORS[section] })
	end
	local selected = "Pets"
	local render
	local tabs = UIKit.tabs(body, defs, function(id)
		selected = id
		render()
	end, { Size = UDim2.new(1, -210, 0, 40), ButtonSize = UDim2.fromOffset(120, 38) })

	local grid = UIKit.scroll(body, { Size = UDim2.new(1, 0, 1, -54), Position = UDim2.fromOffset(0, 52) })

	local function toast(text: string, kind: string)
		require(script.Parent.MainUI).toast(text, kind)
	end

	render = function()
		local data = DataController.Data
		if not data.Passes then
			return
		end
		gemsLabel.Text = Format.short(DataController.gems())
		local now = DataController.now()

		grid:ClearAllChildren()
		UIKit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(218, 236),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, grid)
		UIKit.padding(grid, 4)

		local accent = SECTION_COLORS[selected] or C.Brown
		local order = 0
		for _, item in ShopConfig.Items do
			if item.Section == selected then
				order += 1
				local card = UIKit.frame(grid, { LayoutOrder = order })
				UIKit.vivid(card, item.Color or TILE_COLORS[(order - 1) % #TILE_COLORS + 1] or accent, { Corner = 12, Outline = 3.5 })

				UIKit.icon(card, item.Icon, { Size = UDim2.fromOffset(70, 70), Position = UDim2.new(0.5, 0, 0, 12), AnchorPoint = Vector2.new(0.5, 0), ZIndex = 3 })

				local nameLabel = UIKit.label(card, {
					Size = UDim2.new(1, -12, 0, 26),
					Position = UDim2.fromOffset(6, 90),
					Text = item.Name,
					Font = UIKit.Fonts.Title,
					TextColor3 = C.White,
					TextSize = 20,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextTruncate = Enum.TextTruncate.AtEnd,
					ZIndex = 3,
				})
				UIKit.cartoon(nameLabel, 2.5)
				local descLabel = UIKit.label(card, {
					Size = UDim2.new(1, -16, 0, 40),
					Position = UDim2.fromOffset(8, 118),
					Text = item.Desc,
					TextSize = 12,
					TextColor3 = C.White,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Top,
					ZIndex = 3,
				})
				UIKit.cartoon(descLabel, 1.5)

				local text
				local priceIcon: string? = nil
				local enabled = true
				local color = C.Green
				if item.Kind == "Pass" then
					if data.Passes[item.PassKey] then
						text, enabled = "Owned", false
					elseif item.PassId == 0 then
						text, enabled = "Coming soon", false
					else
						text, color = "R$ " .. item.Robux, C.Gold
					end
				elseif item.Kind == "Product" then
					if item.ProductId == 0 then
						text, enabled = "Coming soon", false
					else
						text, color = "R$ " .. item.Robux, C.Gold
					end
				elseif item.Kind == "Roof" then
					if data.Cosmetics and data.Cosmetics.Roof == item.RoofKey then
						text, enabled = "Equipped", false
					elseif data.Cosmetics and data.Cosmetics.Owned[item.RoofKey] then
						text, color = "Equip", C.Sky
					else
						text, color, priceIcon = Format.short(item.Gems), C.Green, "gem"
					end
				elseif item.Kind == "Boost" then
					local remaining = (data.Boosts and data.Boosts[item.BoostId] or 0) - now
					text = Format.short(item.Gems)
					priceIcon = "gem"
					color = C.Green
					if remaining > 0 then
						UIKit.chip(card, "Active " .. Format.clock(remaining), C.Green, UDim2.fromOffset(110, 20)).Position = UDim2.new(0.5, -55, 0, 12)
					end
				else
					text = Format.short(item.Gems)
					priceIcon = "gem"
					color = C.Green
				end

				local button = UIKit.button(card, {
					Text = text,
					Size = UDim2.new(1, -24, 0, 42),
					Position = UDim2.new(0, 12, 1, -52),
					Color = color,
					TextSize = 18,
					Name = "Buy_" .. item.Id,
					OnClick = function()
						local result = DataController.request("ShopBuy", { Id = item.Id })
						if not result.ok then
							toast(result.msg, "error")
							return
						end
						AudioController.play("Reward")
						toast(result.msg, "success")
						if result.extra and result.extra.SpeciesId then
							require(script.Parent.AnnouncementUI).reveal(result.extra.SpeciesId, result.extra.IsNew == true)
						end
					end,
				})
				if priceIcon then
					UIKit.setButtonContent(button, priceIcon, text, C.White)
				end
				UIKit.setEnabled(button, enabled)
				if not enabled then
					button.BackgroundColor3 = Color3.fromRGB(150, 156, 172)
				end
			end
		end
	end

	panel.OnOpen[1] = function()
		tabs.Select(selected, true)
		render()
	end
	tabs.Select("Pets", true)

	DataController.onChanged(function(keys)
		if panel.IsOpen and (keys.Passes or keys.Cosmetics or keys.Boosts) then
			render()
		end
	end)
	game.Players.LocalPlayer:GetAttributeChangedSignal("Gems"):Connect(function()
		if panel.IsOpen then
			gemsLabel.Text = Format.short(DataController.gems())
		end
	end)
	-- boost countdown labels
	task.spawn(function()
		while true do
			task.wait(1)
			if panel.IsOpen and selected == "Boosts" then
				render()
			end
		end
	end)
end

return ShopUI
