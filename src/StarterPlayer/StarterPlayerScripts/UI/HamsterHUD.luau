--[[
	HamsterHUD: everything about hamsters that are on their way home.
	  - transport tracker (left): every ball you paid for or carry, with its status
	      "LEGENDARY HAMSTER  Transporting to: Kobe" / "STOLEN by Alex!" / "Dropped - grab it!"
	  - progress bar while you steal / pick up
	  (your gate timer is a chip in the HUD status row, see MainUI)
	Clear but small: nothing here is shown when it does not apply.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local HamsterStates = require(Modules:WaitForChild("HamsterStates"))
local RarityConfig = require(Modules:WaitForChild("RarityConfig"))

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local WorldController = require(script.Parent.Parent.Controllers.WorldController)
local UIKit = require(script.Parent.UIKit)

local HamsterHUD = {}

local C = UIKit.Colors
local S = HamsterStates
local player = Players.LocalPlayer

local MAX_ROWS = 3

local function ballStatus(ball: WorldController.Ball): (string, Color3)
	local me = player.UserId
	if ball.HolderUserId == me then
		return "You carry it - run to your house!", C.Gold
	elseif ball.State == S.InTransit then
		return "Transporting to: " .. player.DisplayName, C.Mint
	elseif ball.State == S.Carried then
		return string.format("STOLEN by %s!", ball.HolderName), C.Red
	elseif ball.State == S.Dropped or ball.State == S.Recoverable then
		return "Dropped - grab it!", Color3.fromRGB(255, 168, 96)
	end
	return "", C.White
end

function HamsterHUD.start()
	local MainUI = require(script.Parent.MainUI)
	local leftColumn = MainUI.region("LeftColumn")
	local bottomColumn = MainUI.region("BottomColumn")
	if not leftColumn or not bottomColumn then
		warn("[HamsterHUD] HUD regions missing (MainUI must start first)")
		return
	end

	-----------------------------------------------------------------------
	-- transport tracker (top-left region)
	-----------------------------------------------------------------------
	local tracker = UIKit.frame(leftColumn, {
		Name = "Tracker",
		Size = UDim2.fromOffset(300, MAX_ROWS * 52 + (MAX_ROWS - 1) * 6),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
	})
	UIKit.list(tracker, Enum.FillDirection.Vertical, 6)

	local rows: { { Frame: Frame, Rarity: TextLabel, Status: TextLabel, Stroke: UIStroke } } = {}
	for index = 1, MAX_ROWS do
		local row = UIKit.frame(tracker, {
			Size = UDim2.fromOffset(300, 52),
			BackgroundColor3 = C.Cream,
			BackgroundTransparency = 0.1,
			LayoutOrder = index,
			Visible = false,
		})
		UIKit.corner(row, 8)
		local stroke = UIKit.stroke(row, C.Gold, 1.5)
		local rarity = UIKit.label(row, {
			Position = UDim2.fromOffset(12, 5),
			Size = UDim2.new(1, -20, 0, 22),
			TextSize = 16,
			Font = UIKit.Fonts.Title,
			TextColor3 = C.White,
			Text = "",
		})
		local status = UIKit.label(row, {
			Position = UDim2.fromOffset(12, 27),
			Size = UDim2.new(1, -20, 0, 20),
			TextSize = 14,
			Font = UIKit.Fonts.Body,
			TextColor3 = C.White,
			Text = "",
		})
		table.insert(rows, { Frame = row, Rarity = rarity, Status = status, Stroke = stroke })
	end

	local function refreshTracker()
		local list = WorldController.myBalls()
		for index, row in rows do
			local ball = list[index]
			if not ball then
				row.Frame.Visible = false
			else
				row.Frame.Visible = true
				local definition = RarityConfig.ById[ball.Species.Rarity]
				local color = UIKit.rarityColor(definition)
				local text, statusColor = ballStatus(ball)
				row.Rarity.Text = string.format('<font color="#%s">%s HAMSTER</font>  %s', color:ToHex(), string.upper(definition.Name), ball.Species.Name)
				row.Status.Text = text
				row.Status.TextColor3 = statusColor
				row.Stroke.Color = statusColor
			end
		end
	end
	WorldController.onBallsChanged(refreshTracker)
	task.spawn(function()
		while true do
			refreshTracker()
			task.wait(0.5)
		end
	end)

	-----------------------------------------------------------------------
	-- steal / pick-up progress bar
	-----------------------------------------------------------------------
	local barFrame = UIKit.frame(bottomColumn, {
		Name = "ChannelBar",
		Size = UDim2.fromOffset(320, 46),
		LayoutOrder = 5,
		BackgroundColor3 = C.Cream,
		BackgroundTransparency = 0.08,
		Visible = false,
	})
	UIKit.corner(barFrame, 10)
	UIKit.stroke(barFrame, C.Red, 2)
	local barText = UIKit.label(barFrame, {
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 3),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 16,
		Font = UIKit.Fonts.Title,
		TextColor3 = C.White,
		Text = "Stealing...",
	})
	local barBack = UIKit.frame(barFrame, {
		Size = UDim2.new(1, -28, 0, 10),
		Position = UDim2.fromOffset(14, 28),
		BackgroundColor3 = C.CreamDark,
	})
	UIKit.corner(barBack, 5)
	local barFill = UIKit.frame(barBack, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.Gold })
	UIKit.corner(barFill, 5)

	local channel: WorldController.ChannelInfo? = nil
	WorldController.onChannel(function(info)
		channel = info
		barFrame.Visible = info ~= nil
		if info then
			barText.Text = if info.Kind == "steal" then "Stealing..." elseif info.Kind == "pickup" then "Picking up..." else "Grabbing..."
			AudioController.play("Channel")
		end
	end)

	RunService.RenderStepped:Connect(function()
		if channel then
			local fraction = math.clamp((os.clock() - channel.Start) / math.max(channel.Duration, 0.05), 0, 1)
			barFill.Size = UDim2.fromScale(fraction, 1)
		end
	end)
	-- first minutes: explain the loop in four short messages
	DataController.onReady(function()
		local stats = DataController.get("Stats") or {}
		if (stats.Claimed or 0) > 0 or (stats.Secured or 0) > 0 then
			return
		end
		local hints = {
			"Hamster balls roll down the road in the middle. Walk close and press [E] to CLAIM one.",
			"It rolls to YOUR house and lands on the glowing pad. Only then is it really yours!",
			"Other players can steal it on the way - and you can steal theirs. Slap thieves with [Q].",
			"Your gate protects the house for a while. Press [E] at the gate panel when it switches off.",
		}
		task.spawn(function()
			task.wait(4)
			for _, text in hints do
				require(script.Parent.MainUI).toast(text, "info")
				task.wait(5.5)
			end
		end)
	end)

end

return HamsterHUD
