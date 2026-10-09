--[[
	DailyRewardUI: the 7-day streak calendar. Today's gift glows; claimed days are ticked off.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local DailyRewardConfig = require(Modules:WaitForChild("DailyRewardConfig"))
local Format = require(Modules:WaitForChild("Format"))

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local UIKit = require(script.Parent.UIKit)

local DailyRewardUI = {}

local C = UIKit.Colors

function DailyRewardUI.start()
	local panel = UIKit.panel({ Name = "Daily", Title = "Daily Rewards", Icon = "gift", Design = Vector2.new(960, 470), Accent = C.Pink })
	local body = panel.Body

	UIKit.label(body, {
		Size = UDim2.new(1, 0, 0, 30),
		Text = "Come back every day to keep your streak! Day 5 and Day 7 give exclusive hamsters.",
		TextSize = 15,
		TextColor3 = C.Muted,
		TextXAlignment = Enum.TextXAlignment.Center,
	})

	local row = UIKit.frame(body, { Size = UDim2.new(1, 0, 0, 240), Position = UDim2.fromOffset(0, 40), BackgroundTransparency = 1 })
	UIKit.list(row, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)

	local cards: { { Frame: Frame, Stroke: UIStroke, State: TextLabel, Icon: Frame } } = {}
	for index, day in DailyRewardConfig.Days do
		local card = UIKit.frame(row, { Size = UDim2.fromOffset(120, 236), LayoutOrder = index })
		UIKit.corner(card, 18)
		local stroke = UIKit.stroke(card, Color3.fromRGB(226, 208, 180), 3)
		UIKit.label(card, {
			Size = UDim2.new(1, 0, 0, 34),
			Text = "Day " .. day.Day,
			Font = UIKit.Fonts.Title,
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		local icon = UIKit.icon(card, day.Icon, { Size = UDim2.fromOffset(72, 72), Position = UDim2.new(0.5, 0, 0, 42), AnchorPoint = Vector2.new(0.5, 0) })
		UIKit.label(card, {
			Size = UDim2.new(1, -10, 0, 40),
			Position = UDim2.fromOffset(5, 120),
			Text = day.Label,
			TextSize = 14,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = C.Ink,
		})
		if day.Hamster then
			UIKit.chip(card, "EXCLUSIVE", C.Purple, UDim2.fromOffset(100, 20)).Position = UDim2.fromOffset(10, 164)
		end
		local state = UIKit.label(card, {
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.new(0, 0, 1, -36),
			Text = "",
			TextSize = 15,
			Font = UIKit.Fonts.Title,
			TextXAlignment = Enum.TextXAlignment.Center,
		})
		cards[index] = { Frame = card, Stroke = stroke, State = state, Icon = icon }
	end

	local info = UIKit.label(body, {
		Size = UDim2.new(1, 0, 0, 28),
		Position = UDim2.fromOffset(0, 292),
		Text = "",
		TextSize = 17,
		Font = UIKit.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local claim = UIKit.button(body, {
		Text = "Claim Reward!",
		Size = UDim2.fromOffset(300, 60),
		Position = UDim2.new(0.5, 0, 1, -4),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Pink,
		TextSize = 26,
		OnClick = function()
			local result = DataController.request("ClaimDaily")
			if result.ok then
				AudioController.play("Reward")
			else
				require(script.Parent.MainUI).toast(result.msg, "error")
			end
		end,
	})

	local function refresh()
		local data = DataController.Data
		if not data.Daily then
			return
		end
		local now = DataController.now()
		local nextDay, canClaim, untilNext = DailyRewardConfig.state(data.Daily, now)
		local today = DailyRewardConfig.dayNumber(now)
		local brokenStreak = data.Daily.LastDay > 0 and today - data.Daily.LastDay > 1
		local streak = if brokenStreak then 0 else data.Daily.Streak

		-- how many cards of the current 7-day cycle are already ticked off
		local claimedInCycle = if streak >= 7 and canClaim then 0 else streak
		for index, card in cards do
			if canClaim and index == nextDay then
				card.State.Text = "TODAY!"
				card.State.TextColor3 = C.Green
				card.Stroke.Color = C.Gold
				card.Stroke.Thickness = 5
			elseif index <= claimedInCycle then
				card.State.Text = "Claimed"
				card.State.TextColor3 = C.Green
				card.Stroke.Color = C.Green
				card.Stroke.Thickness = 3
			else
				card.State.Text = "Locked"
				card.State.TextColor3 = C.Muted
				card.Stroke.Color = Color3.fromRGB(226, 208, 180)
				card.Stroke.Thickness = 3
			end
		end
		UIKit.setEnabled(claim, canClaim)
		if canClaim then
			info.Text = string.format('<font color="#60c47e">Day %d is ready!</font>', nextDay)
			claim.Text = "Claim Reward!"
		else
			info.Text = "Next gift in " .. Format.clock(untilNext)
			claim.Text = "Come back tomorrow"
		end
	end

	panel.OnOpen[1] = refresh
	DataController.onChanged(function(keys)
		if panel.IsOpen and keys.Daily then
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

return DailyRewardUI
