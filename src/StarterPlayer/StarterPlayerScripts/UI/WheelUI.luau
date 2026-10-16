--[[
	WheelUI: a SMALL info panel for the Lucky Wheel, docked on the right edge of the screen. The wheel itself is the physical object
	behind the shops: you walk there, press [F] and watch it turn in the world. This panel only shows what can be won (picture,
	name, chance), when your next free spin is ready, and what you won last. It has no spin button and never covers the wheel.
	The prizes come from SpinWheelConfig; the draw is made by the server (SpinSystem).
	Open it with the wheel icon in the right rail.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Format = require(Modules:WaitForChild("Format"))
local SpinWheelConfig = require(Modules:WaitForChild("SpinWheelConfig"))

local DataController = require(script.Parent.Parent.Controllers.DataController)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local WheelUI = {}

local C = UIKit.Colors

-- Texts of the panel (edit here).
WheelUI.Texts = {
	Title = "Lucky Wheel",
	Subtitle = "One free spin every few hours",
	Ready = "Your free spin is ready!",
	Where = "Walk to the wheel behind the shops and press F.",
	Next = "Next free spin in",
	Prizes = "WHAT YOU CAN WIN",
}

function WheelUI.start()
	local texts = WheelUI.Texts
	local panel = UIKit.panel({ Name = "Wheel", Title = texts.Title, Icon = "wheel", Design = Vector2.new(340, 600), Accent = Theme.Accents.Rebirth, Subtitle = texts.Subtitle, Dock = "Right" })
	local body = panel.Body
	local prizes = SpinWheelConfig.Prizes

	local status = UIKit.label(body, { Name = "Status", Size = UDim2.new(1, 0, 0, 26), Text = "", Font = UIKit.Fonts.Title, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center })
	local hint = UIKit.label(body, { Name = "Where", Size = UDim2.new(1, 0, 0, 36), Position = UDim2.fromOffset(0, 28), Text = texts.Where, TextSize = 13, TextColor3 = C.Muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center })
	UIKit.label(body, { Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(0, 72), Text = texts.Prizes, Font = UIKit.Fonts.Title, TextSize = UIKit.Type.Caption, TextColor3 = C.Muted })

	local list = UIKit.scroll(body, { Size = UDim2.new(1, 0, 1, -100), Position = UDim2.fromOffset(0, 94) })
	list.Name = "PrizeList"
	UIKit.list(list, Enum.FillDirection.Vertical, 4)
	local rows: { { Frame: Frame, Label: TextLabel, Chance: TextLabel, Icon: Frame } } = {}
	for index, prize in prizes do
		local row = UIKit.frame(list, { Name = "Row_" .. prize.Id, Size = UDim2.new(1, -8, 0, 44), LayoutOrder = index, BackgroundColor3 = C.Card })
		UIKit.corner(row, 8)
		UIKit.frame(row, { Size = UDim2.fromOffset(6, 44), BackgroundColor3 = prize.Color, ZIndex = 2 })
		local icon = UIKit.icon(row, prize.Icon, { Size = UDim2.fromOffset(30, 30), Position = UDim2.fromOffset(16, 7), ZIndex = 3 })
		local label = UIKit.label(row, { Size = UDim2.new(1, -118, 1, 0), Position = UDim2.fromOffset(54, 0), Text = prize.Label, Font = UIKit.Fonts.Title, TextSize = 13, TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd })
		local chance = UIKit.label(row, { Size = UDim2.fromOffset(56, 44), Position = UDim2.new(1, -60, 0, 0), Text = "", TextSize = 12, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Right })
		rows[index] = { Frame = row, Label = label, Chance = chance, Icon = icon }
	end

	-- what each prize is worth to THIS player (cash scales with progress) and whether it is unlocked yet
	local function refresh()
		local data = DataController.Data
		if not data or not data.Rebirths or not data.Wheel then
			return
		end
		local now = DataController.now()
		local ctx = SpinWheelConfig.context(data, now)
		local total = SpinWheelConfig.totalWeight(ctx)
		for index, prize in prizes do
			local row = rows[index]
			local open = SpinWheelConfig.eligible(prize, ctx)
			row.Label.Text = SpinWheelConfig.preview(prize, ctx)
			row.Label.TextColor3 = if open then C.Ink else C.Muted
			row.Chance.Text = if open and total > 0 then string.format("%.1f%%", prize.Weight / total * 100) else "locked"
			row.Frame.BackgroundTransparency = if open then 0 else 0.5
		end
		local nextFree = data.Wheel.NextFreeAt or 0
		if now >= nextFree then
			status.Text = string.format('<font color="#60c47e">%s</font>', texts.Ready)
			hint.Visible = true
		else
			status.Text = string.format("%s %s", texts.Next, Format.clock(nextFree - now))
			hint.Visible = true
		end
	end

	panel.OnOpen[1] = refresh
	DataController.onChanged(function(keys)
		if panel.IsOpen and (keys.Wheel or keys.Rebirths) then
			refresh()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			if panel.IsOpen then
				refresh()
			end
		end
	end)
end

return WheelUI
