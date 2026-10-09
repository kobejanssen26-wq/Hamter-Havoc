--[[
	SettingsUI + CodesUI. Settings are saved on the server (validated against SettingsConfig) and
	applied instantly on the client by AudioController / SettingsController / AmbientController / FxController.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local SettingsConfig = require(Modules:WaitForChild("SettingsConfig"))

local DataController = require(script.Parent.Parent.Controllers.DataController)
local UIKit = require(script.Parent.UIKit)

local SettingsUI = {}

local C = UIKit.Colors

function SettingsUI.start()
	-----------------------------------------------------------------------
	-- settings
	-----------------------------------------------------------------------
	local panel = UIKit.panel({ Name = "Settings", Title = "Settings", Icon = "gear", Design = Vector2.new(620, 580), Accent = C.BrownLight })
	local scroll = UIKit.scroll(panel.Body, { Size = UDim2.fromScale(1, 1) })
	UIKit.list(scroll, Enum.FillDirection.Vertical, 8)
	UIKit.padding(scroll, 4)

	local controls: { [string]: { Set: (any) -> () } } = {}

	for order, entry in SettingsConfig.List do
		local row = UIKit.frame(scroll, { Size = UDim2.new(1, -10, 0, 54), LayoutOrder = order })
		UIKit.corner(row, 14)
		UIKit.stroke(row, C.Line, 2)
		UIKit.icon(row, entry.Icon, { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(12, 10) })
		UIKit.label(row, {
			Position = UDim2.fromOffset(56, 0),
			Size = UDim2.new(0.55, -42, 1, 0),
			Text = entry.Label,
			TextSize = 17,
			Font = UIKit.Fonts.Title,
		})

		local current = DataController.setting(entry.Key)
		if entry.Type == "toggle" then
			local toggle = UIKit.toggle(row, {
				Value = current,
				Position = UDim2.new(1, -16, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				OnChanged = function(value)
					DataController.request("UpdateSetting", { Key = entry.Key, Value = value })
				end,
			})
			controls[entry.Key] = { Set = toggle.Set }
		elseif entry.Type == "slider" then
			local slider = UIKit.slider(row, {
				Min = entry.Min,
				Max = entry.Max,
				Value = current,
				Size = UDim2.fromOffset(190, 14),
				Position = UDim2.new(1, -24, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				OnChanged = function(value)
					DataController.request("UpdateSetting", { Key = entry.Key, Value = value })
				end,
			})
			controls[entry.Key] = { Set = slider.Set }
		elseif entry.Type == "choice" then
			local index = 1
			for position, option in entry.Options do
				if option.Value == current then
					index = position
				end
			end
			local button
			button = UIKit.button(row, {
				Text = entry.Options[index].Text,
				Size = UDim2.fromOffset(170, 38),
				Position = UDim2.new(1, -12, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				Color = C.Sky,
				TextSize = 15,
				OnClick = function()
					index = index % #entry.Options + 1
					button.Text = entry.Options[index].Text
					DataController.request("UpdateSetting", { Key = entry.Key, Value = entry.Options[index].Value })
				end,
			})
			controls[entry.Key] = {
				Set = function(value: any)
					for position, option in entry.Options do
						if option.Value == value then
							index = position
							button.Text = option.Text
						end
					end
				end,
			}
		end
	end

	-- promo codes live here (they used to be a separate HUD button)
	do
		local row = UIKit.frame(scroll, { Size = UDim2.new(1, -10, 0, 54), LayoutOrder = #SettingsConfig.List + 1 })
		UIKit.corner(row, 14)
		UIKit.stroke(row, C.Line, 2)
		UIKit.icon(row, "gift", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(12, 10) })
		UIKit.label(row, { Position = UDim2.fromOffset(56, 0), Size = UDim2.new(0.55, -42, 1, 0), Text = "Promo codes", TextSize = 17, Font = UIKit.Fonts.Title })
		UIKit.button(row, {
			Text = "Enter code",
			Size = UDim2.fromOffset(170, 38),
			Position = UDim2.new(1, -12, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Color = C.Purple,
			TextSize = 15,
			OnClick = function()
				local codesPanel = UIKit.getPanel("Codes")
				if codesPanel then
					codesPanel:Open()
				end
			end,
		})
	end

	local function sync()
		for key, control in controls do
			control.Set(DataController.setting(key))
		end
	end
	panel.OnOpen[1] = sync

	-----------------------------------------------------------------------
	-- codes
	-----------------------------------------------------------------------
	local codes = UIKit.panel({ Name = "Codes", Title = "Promo Codes", Icon = "gift", Design = Vector2.new(560, 330), Accent = C.Purple })
	UIKit.label(codes.Body, {
		Size = UDim2.new(1, 0, 0, 50),
		Text = "Enter a code to get free rewards!\nNew codes appear during updates and events.",
		TextSize = 16,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local box = UIKit.new("TextBox", {
		Size = UDim2.new(1, -40, 0, 56),
		Position = UDim2.fromOffset(20, 66),
		BackgroundColor3 = C.CreamDark,
		Font = UIKit.Fonts.Title,
		TextSize = 26,
		TextColor3 = C.Ink,
		PlaceholderText = "ENTER CODE",
		PlaceholderColor3 = C.Muted,
		Text = "",
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
	}, codes.Body)
	UIKit.corner(box, 14)
	UIKit.stroke(box, C.Purple, 3)
	local status = UIKit.label(codes.Body, {
		Size = UDim2.new(1, 0, 0, 30),
		Position = UDim2.fromOffset(0, 130),
		Text = "",
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local function redeem()
		local text = box.Text
		if #text == 0 then
			return
		end
		local result = DataController.request("RedeemCode", { Code = text })
		if result.ok then
			status.Text = '<font color="#60c47e">' .. result.msg .. "</font>"
			box.Text = ""
		else
			status.Text = '<font color="#f06262">' .. result.msg .. "</font>"
		end
	end
	UIKit.button(codes.Body, {
		Text = "Redeem",
		Size = UDim2.fromOffset(220, 56),
		Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Purple,
		TextSize = 24,
		OnClick = redeem,
	})
	box.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			redeem()
		end
	end)
	codes.OnOpen[1] = function()
		status.Text = ""
	end
end

return SettingsUI
