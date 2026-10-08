--[[
	HamsterHUD: everything about hamsters that are on their way home.
	  - transport tracker (right): every ball you paid for or carry, with its status
	      "LEGENDARY  Golden King - Transporting to: Kobe" / "STOLEN by Alex!" / "Dropped - grab it!"
	  - progress bar while you steal / pick up
	  - security pill (top right): your gate timer "SECURITY 00:47", then "SECURITY OFF" + what to do
	Clear but small: nothing here is shown when it does not apply.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Format = require(Modules:WaitForChild("Format"))
local HamsterStates = require(Modules:WaitForChild("HamsterStates"))
local RarityConfig = require(Modules:WaitForChild("RarityConfig"))

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local SecurityController = require(script.Parent.Parent.Controllers.SecurityController)
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
	local gui = UIKit.new("ScreenGui", {
		Name = "HamsterHUD",
		ResetOnSpawn = false,
		DisplayOrder = 2,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	-- same responsive scaling as the main HUD
	local scales: { UIScale } = {}
	local function addScale(parent: Instance)
		table.insert(scales, UIKit.new("UIScale", { Scale = 1 }, parent))
	end
	local function updateScale()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local value = math.clamp(math.min(viewport.X / 1180, viewport.Y / 660), 0.5, 1.1)
		for _, scale in scales do
			scale.Scale = value
		end
	end

	-----------------------------------------------------------------------
	-- transport tracker
	-----------------------------------------------------------------------
	local tracker = UIKit.frame(gui, {
		Name = "Tracker",
		Size = UDim2.fromOffset(300, 200),
		Position = UDim2.new(1, -16, 0, 116),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundTransparency = 1,
	})
	addScale(tracker)
	UIKit.list(tracker, Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Right)

	local rows: { { Frame: Frame, Rarity: TextLabel, Status: TextLabel, Stroke: UIStroke } } = {}
	for index = 1, MAX_ROWS do
		local row = UIKit.frame(tracker, {
			Size = UDim2.fromOffset(300, 54),
			BackgroundColor3 = C.White,
			LayoutOrder = index,
			Visible = false,
		})
		UIKit.corner(row, 18)
		UIKit.shadow(row, 18, 3)
		local stroke = UIKit.stroke(row, C.Gold, 2.5)
		UIKit.icon(row, "Hamster", 38, { Position = UDim2.new(0, 8, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
		local rarity = UIKit.label(row, {
			Position = UDim2.fromOffset(54, 6),
			Size = UDim2.new(1, -62, 0, 22),
			TextSize = 15,
			Font = UIKit.Fonts.Title,
			TextColor3 = C.Ink,
			Text = "",
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local status = UIKit.label(row, {
			Position = UDim2.fromOffset(54, 28),
			Size = UDim2.new(1, -62, 0, 20),
			TextSize = 13,
			Font = UIKit.Fonts.Body,
			TextColor3 = C.Ink,
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
				row.Rarity.Text = string.format('<font color="#%s">%s</font>  %s', color:ToHex(), string.upper(definition.Name), ball.Species.Name)
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
	local barFrame = UIKit.frame(gui, {
		Name = "ChannelBar",
		Size = UDim2.fromOffset(320, 46),
		Position = UDim2.new(0.5, 0, 1, -250),
		AnchorPoint = Vector2.new(0.5, 1),
		BackgroundColor3 = C.White,
		Visible = false,
	})
	addScale(barFrame)
	UIKit.corner(barFrame, 23)
	UIKit.shadow(barFrame, 23, 3)
	UIKit.stroke(barFrame, C.Red, 3)
	local barText = UIKit.label(barFrame, {
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 3),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 16,
		Font = UIKit.Fonts.Title,
		TextColor3 = C.Ink,
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

	-----------------------------------------------------------------------
	-- security pill (my own gate)
	-----------------------------------------------------------------------
	local pill = UIKit.frame(gui, {
		Name = "Security",
		Size = UDim2.fromOffset(268, 42),
		Position = UDim2.new(1, -16, 0, 64),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = C.White,
		Visible = false,
	})
	addScale(pill)
	UIKit.corner(pill, 21)
	UIKit.shadow(pill, 21, 3)
	local pillStroke = UIKit.stroke(pill, C.Green, 3)
	UIKit.icon(pill, "Shield", 34, { Position = UDim2.new(0, 4, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
	local pillText = UIKit.label(pill, {
		Size = UDim2.new(1, -50, 1, 0),
		Position = UDim2.fromOffset(42, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextSize = 16,
		Font = UIKit.Fonts.Title,
		TextColor3 = C.Ink,
		Text = "",
	})

	local lastBeep = -1
	local function refreshSecurity()
		local houseId = player:GetAttribute("HouseId")
		local houses = Workspace:FindFirstChild("PlayerHouses")
		local house = if type(houseId) == "number" and houses then houses:FindFirstChild("House" .. houseId) else nil
		if not house or not house:IsA("Model") then
			pill.Visible = false
			return
		end
		local status = SecurityController.status(house)
		pill.Visible = status.Owned
		local color = SecurityController.color(status)
		pillStroke.Color = color
		pillText.TextColor3 = UIKit.darker(color, 0.7)
		if status.State == "Active" then
			pillText.Text = "SECURITY  " .. Format.clock(math.ceil(status.Seconds))
			local whole = math.ceil(status.Seconds)
			if whole <= 5 and whole ~= lastBeep then
				lastBeep = whole
				AudioController.play("Alarm", { Pitch = 1 + (5 - whole) * 0.12 })
			end
		elseif status.State == "Recharging" then
			pillText.Text = string.format("SECURITY OFF  (%ds)", math.ceil(status.Seconds))
			lastBeep = -1
		else
			pillText.Text = "OFF - press E at the gate panel"
			lastBeep = -1
		end
	end

	RunService.RenderStepped:Connect(function()
		if channel then
			local fraction = math.clamp((os.clock() - channel.Start) / math.max(channel.Duration, 0.05), 0, 1)
			barFill.Size = UDim2.fromScale(fraction, 1)
		end
	end)
	task.spawn(function()
		while true do
			refreshSecurity()
			task.wait(0.2)
		end
	end)

	updateScale()

	-- first minutes: explain the loop in four short messages
	DataController.onReady(function()
		local stats = DataController.get("Stats") or {}
		if (stats.Claimed or 0) > 0 or (stats.Secured or 0) > 0 then
			return
		end
		local hints = {
			"Hamster balls roll down the road in the middle. Walk close and press [E] to CLAIM one.",
			"It rolls to YOUR apartment and lands on the glowing pad. Only then is it really yours!",
			"Other players can steal it on the way - and you can steal theirs. Slap thieves with [Q].",
			"Your gate protects the apartment for a while. Press [E] at the gate panel when it switches off.",
		}
		task.spawn(function()
			task.wait(4)
			for _, text in hints do
				require(script.Parent.MainUI).toast(text, "info")
				task.wait(5.5)
			end
		end)
	end)

	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
end

return HamsterHUD
