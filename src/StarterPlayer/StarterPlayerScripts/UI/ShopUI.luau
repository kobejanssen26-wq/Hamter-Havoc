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

local SECTION_COLORS = {
	Pets = C.Pink,
	Boosts = C.Mint,
	Currency = C.Sky,
	Gamepasses = C.Gold,
	Cosmetics = C.Purple,
}

function ShopUI.start()
	local panel = UIKit.panel({ Name = "Shop", Title = "Shop", Icon = "🛍️", Design = Vector2.new(980, 660), Accent = C.Pink })
	local body = panel.Body

	local gemsLabel = UIKit.label(body, {
		Size = UDim2.fromOffset(200, 40),
		Position = UDim2.new(1, 0, 0, 0),
		AnchorPoint = Vector2.new(1, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Font = UIKit.Fonts.Title,
		TextSize = 24,
		TextColor3 = Color3.fromRGB(70, 140, 220),
		Text = "💎 0",
	})

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
		gemsLabel.Text = "💎 " .. Format.short(DataController.gems())
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
				UIKit.corner(card, 18)
				UIKit.stroke(card, accent, 3)

				local iconBox = UIKit.frame(card, { Size = UDim2.new(1, -16, 0, 84), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = C.CreamDark })
				UIKit.corner(iconBox, 14)
				if item.Color then
					iconBox.BackgroundColor3 = item.Color
				end
				UIKit.label(iconBox, { Size = UDim2.fromScale(1, 1), Text = item.Icon, TextSize = 52, TextXAlignment = Enum.TextXAlignment.Center })

				UIKit.label(card, {
					Size = UDim2.new(1, -12, 0, 24),
					Position = UDim2.fromOffset(6, 98),
					Text = item.Name,
					Font = UIKit.Fonts.Title,
					TextSize = 18,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextTruncate = Enum.TextTruncate.AtEnd,
				})
				UIKit.label(card, {
					Size = UDim2.new(1, -16, 0, 40),
					Position = UDim2.fromOffset(8, 124),
					Text = item.Desc,
					TextSize = 12,
					TextColor3 = C.Muted,
					TextWrapped = true,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Top,
				})

				local text
				local enabled = true
				local color = C.Green
				if item.Kind == "Pass" then
					if data.Passes[item.PassKey] then
						text, enabled = "Owned ✓", false
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
						text, enabled = "Equipped ✓", false
					elseif data.Cosmetics and data.Cosmetics.Owned[item.RoofKey] then
						text, color = "Equip", C.Sky
					else
						text, color = "💎 " .. Format.short(item.Gems), C.Pink
					end
				elseif item.Kind == "Boost" then
					local remaining = (data.Boosts and data.Boosts[item.BoostId] or 0) - now
					text = "💎 " .. Format.short(item.Gems)
					color = C.Mint
					if remaining > 0 then
						UIKit.chip(card, "Active " .. Format.clock(remaining), C.Green, UDim2.fromOffset(110, 20)).Position = UDim2.new(0.5, -55, 0, 12)
					end
				else
					text = "💎 " .. Format.short(item.Gems)
					color = C.Pink
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
				UIKit.setEnabled(button, enabled)
				if not enabled then
					button.BackgroundColor3 = Color3.fromRGB(200, 188, 176)
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
			gemsLabel.Text = "💎 " .. Format.short(DataController.gems())
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
