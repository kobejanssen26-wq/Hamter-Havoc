--[[
	WheelUI: the Lucky Wheel window. The prizes come from SpinWheelConfig (edit the numbers there); the draw is made by the
	server (SpinSystem) - this window only asks, then spins the wheel so that the prize the server chose ends up under the pointer.
	Open it from the Quests window (Lucky Wheel button).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Format = require(Modules:WaitForChild("Format"))
local SpinWheelConfig = require(Modules:WaitForChild("SpinWheelConfig"))

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local WheelUI = {}

local C = UIKit.Colors
local RADIUS = 138
local BUBBLE = 66
local SPIN_SECONDS = 4

function WheelUI.start()
	local panel = UIKit.panel({ Name = "Wheel", Title = "Lucky Wheel", Icon = "gift", Design = Vector2.new(820, 600), Accent = Theme.Accents.Rebirth, Subtitle = "Spin for cash, diamonds, boosts and items" })
	local body = panel.Body
	local prizes = SpinWheelConfig.Prizes
	local count = #prizes

	-- the wheel: a disc with one bubble per prize, rotated as a group
	local stage = UIKit.frame(body, { Name = "Stage", Size = UDim2.fromOffset(RADIUS * 2 + BUBBLE + 16, RADIUS * 2 + BUBBLE + 16), Position = UDim2.fromOffset(0, 14), BackgroundTransparency = 1 })
	local centerX = (RADIUS * 2 + BUBBLE + 16) / 2
	local disc = UIKit.frame(stage, { Name = "Disc", Size = UDim2.fromOffset(RADIUS * 2 + 20, RADIUS * 2 + 20), Position = UDim2.fromOffset(centerX, centerX), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.CreamDark })
	UIKit.corner(disc, 99)
	UIKit.stroke(disc, Theme.Accents.Rebirth, Theme.Outline.Thick)
	local ring = UIKit.frame(stage, { Name = "Ring", Size = UDim2.fromOffset(RADIUS * 2 + BUBBLE, RADIUS * 2 + BUBBLE), Position = UDim2.fromOffset(centerX, centerX), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1 })
	local bubbles: { Frame } = {}
	for index, prize in prizes do
		local angle = math.rad((index - 1) * 360 / count)
		local bubble = UIKit.frame(ring, {
			Name = "Prize_" .. prize.Id,
			Size = UDim2.fromOffset(BUBBLE, BUBBLE),
			Position = UDim2.fromOffset((RADIUS * 2 + BUBBLE) / 2 + math.sin(angle) * RADIUS, (RADIUS * 2 + BUBBLE) / 2 - math.cos(angle) * RADIUS),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundColor3 = prize.Color,
		})
		UIKit.corner(bubble, 99)
		UIKit.stroke(bubble, C.Line, Theme.Outline.Thick)
		UIKit.icon(bubble, prize.Icon, { Size = UDim2.fromOffset(38, 38), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3 })
		bubbles[index] = bubble
	end
	-- pointer at the top
	local pointer = UIKit.frame(stage, { Name = "Pointer", Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(centerX, 6), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45, BackgroundColor3 = C.Red, ZIndex = 8 })
	UIKit.corner(pointer, 6)
	UIKit.stroke(pointer, C.Line, Theme.Outline.Thick)

	local spinButton = UIKit.button(stage, {
		Name = "Spin",
		Text = "SPIN",
		Size = UDim2.fromOffset(112, 112),
		Position = UDim2.fromOffset(centerX, centerX),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = C.Green,
		Corner = 99,
		TextSize = 24,
		OnClick = function() end,
	})
	spinButton.ZIndex = 6

	-- right column: what is on the wheel and how likely it is
	local listTitle = UIKit.label(body, { Position = UDim2.fromOffset(RADIUS * 2 + BUBBLE + 40, 14), Size = UDim2.new(1, -(RADIUS * 2 + BUBBLE + 40), 0, 26), Text = "PRIZES", Font = UIKit.Fonts.Title, TextSize = UIKit.Type.Caption, TextColor3 = C.Muted })
	local list = UIKit.frame(body, { Name = "PrizeList", Position = UDim2.fromOffset(RADIUS * 2 + BUBBLE + 40, 42), Size = UDim2.new(1, -(RADIUS * 2 + BUBBLE + 40), 0, 330), BackgroundTransparency = 1 })
	UIKit.list(list, Enum.FillDirection.Vertical, 4)
	local total = SpinWheelConfig.totalWeight()
	local rows: { { Frame: Frame, Label: TextLabel } } = {}
	for index, prize in prizes do
		local row = UIKit.frame(list, { Name = "Row_" .. prize.Id, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = index, BackgroundColor3 = C.Card })
		UIKit.corner(row, 8)
		UIKit.frame(row, { Size = UDim2.fromOffset(8, 32), BackgroundColor3 = prize.Color, ZIndex = 2 })
		local label = UIKit.label(row, { Size = UDim2.new(1, -80, 1, 0), Position = UDim2.fromOffset(16, 0), Text = prize.Label, Font = UIKit.Fonts.Title, TextSize = 13, TextTruncate = Enum.TextTruncate.AtEnd })
		UIKit.label(row, { Size = UDim2.fromOffset(60, 32), Position = UDim2.new(1, -64, 0, 0), Text = string.format("%.1f%%", prize.Weight / total * 100), TextSize = 12, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Right })
		rows[index] = { Frame = row, Label = label }
	end

	local info = UIKit.label(body, { Name = "Info", Size = UDim2.new(1, 0, 0, 30), Position = UDim2.new(0, 0, 1, -34), Text = "", Font = UIKit.Fonts.Title, TextSize = 17, TextXAlignment = Enum.TextXAlignment.Center })

	local spinning = false
	local rotation = 0
	-- keep every bubble upright while the ring turns
	RunService.RenderStepped:Connect(function()
		if panel.IsOpen then
			for _, bubble in bubbles do
				bubble.Rotation = -ring.Rotation
			end
		end
	end)

	local function state(): (boolean, number)
		local data = DataController.Data
		local nextFree = if data.Wheel then data.Wheel.NextFreeAt else 0
		local now = DataController.now()
		return now >= nextFree, math.max(0, nextFree - now)
	end

	local function refresh()
		local free, wait = state()
		if spinning then
			return
		end
		if free then
			spinButton.Text = "SPIN\nFREE!"
			UIKit.setButtonColor(spinButton, C.Green)
			info.Text = '<font color="#60e070">Your free spin is ready!</font>'
		elseif SpinWheelConfig.ExtraSpinGems > 0 then
			spinButton.Text = string.format("SPIN\n%d gems", SpinWheelConfig.ExtraSpinGems)
			UIKit.setButtonColor(spinButton, C.Purple)
			info.Text = "Next free spin in " .. Format.clock(wait)
		else
			spinButton.Text = "WAIT"
			UIKit.setButtonColor(spinButton, C.CardHover)
			info.Text = "Next free spin in " .. Format.clock(wait)
		end
	end

	local function spin()
		if spinning then
			return
		end
		local free = state()
		local result = DataController.request("SpinWheel", { Pay = not free })
		if not result.ok then
			require(script.Parent.MainUI).toast(result.msg, "error")
			AudioController.play("Error")
			return
		end
		spinning = true
		spinButton.Text = "..."
		local index = result.extra.Index
		-- bring prize `index` (at angle (index-1)*360/count from the top) under the pointer after 5 full turns
		local target = rotation + 360 * 5 + (360 - ((index - 1) * 360 / count) - (rotation % 360))
		rotation = target
		AudioController.play("Open")
		UIKit.tween(ring, SPIN_SECONDS, { Rotation = target }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		task.delay(SPIN_SECONDS + 0.1, function()
			spinning = false
			AudioController.play("Reward")
			for rowIndex, row in rows do
				row.Frame.BackgroundColor3 = if rowIndex == index then prizes[index].Color else C.Card
			end
			info.Text = string.format('<font color="#ffe060">You won: %s!</font>', prizes[index].Label)
		end)
	end
	spinButton.Activated:Connect(spin)

	panel.OnOpen[1] = refresh
	DataController.onChanged(function(keys)
		if panel.IsOpen and keys.Wheel then
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
	local _ = listTitle
end

return WheelUI
