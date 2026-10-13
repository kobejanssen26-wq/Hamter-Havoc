--[[
	LeaderboardUI: the leaderboard screen (rail button "Leaderboards" or the kiosk in the Leaderboard Hall).
	  - three rankings (tabs): Most Hamsters / Most Steals / Most Money
	  - four periods (segmented selector): Weekly / Monthly / Yearly / All-time
	  - rows: rank, avatar, display name, score; the top three have their own look; your row is highlighted
	  - states: loading, empty ("no scores yet"), error with Retry (the last known ranking stays visible)
	All data comes from the server (LeaderboardService); nothing is invented here.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Format = require(Modules:WaitForChild("Format"))
local LeaderboardConfig = require(Modules:WaitForChild("LeaderboardConfig"))

local DataController = require(script.Parent.Parent.Controllers.DataController)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)
local UIRegistry = require(script.Parent.UIRegistry)

local LeaderboardUI = {}

local C = UIKit.Colors
local player = Players.LocalPlayer

local RANK_COLORS = { C.Gold, Color3.fromRGB(205, 212, 228), Color3.fromRGB(224, 150, 92) }
local SHOWN_ROWS = 25
local ROW_HEIGHT = 46

function LeaderboardUI.start()
	local panel = UIKit.panel({ Name = "Leaderboards", Title = "Leaderboards", Icon = "trophy", Design = Vector2.new(720, 600), Accent = Theme.Accents.Leaderboards, Subtitle = "See who leads the plaza" })
	local body = panel.Body

	local metric, period = "Money", "Weekly"
	local token = 0 -- answers of outdated requests are ignored
	local lastRequestAt = 0
	local results: { [string]: any } = {}

	-- metric tabs
	local tabDefs = {}
	for _, id in LeaderboardConfig.Metrics do
		table.insert(tabDefs, { Id = id, Text = LeaderboardConfig.MetricInfo[id].Name, Color = C.Gold })
	end
	local load
	local tabs = UIKit.tabs(body, tabDefs, function(id)
		metric = id
		load(false)
	end, { Size = UDim2.new(1, 0, 0, 38), ButtonSize = UDim2.new(1 / 3, -6, 1, 0) })

	-- period selector
	local periodRow = UIKit.frame(body, { Name = "Periods", Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 48), BackgroundTransparency = 1 })
	UIKit.list(periodRow, Enum.FillDirection.Horizontal, 6)
	local periodButtons: { [string]: TextButton } = {}
	local function paintPeriods()
		for id, button in periodButtons do
			UIKit.setButtonColor(button, if id == period then C.Peach else C.Card)
		end
	end
	for index, id in LeaderboardConfig.Periods do
		periodButtons[id] = UIKit.button(periodRow, {
			Text = LeaderboardConfig.PeriodInfo[id].Name,
			Size = UDim2.new(0.25, -5, 1, 0),
			Color = C.Card,
			TextSize = 14,
			LayoutOrder = index,
			Name = "Period_" .. id,
			OnClick = function()
				period = id
				paintPeriods()
				load(false)
			end,
		})
	end

	local description = UIKit.label(body, { Name = "Description", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.fromOffset(2, 90), TextSize = 13, TextColor3 = C.Muted, Font = UIKit.Fonts.Soft, Text = "" })

	local listFrame = UIKit.frame(body, { Name = "List", Size = UDim2.new(1, 0, 1, -158), Position = UDim2.fromOffset(0, 114), BackgroundColor3 = C.CreamDark })
	UIKit.corner(listFrame, 8)
	local scroll = UIKit.scroll(listFrame, { Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4) })
	UIKit.list(scroll, Enum.FillDirection.Vertical, 4)
	UIKit.padding(scroll, 4)

	local stateLabel = UIKit.label(listFrame, { Name = "State", Size = UDim2.new(1, -40, 0, 60), Position = UDim2.fromScale(0.5, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), Font = UIKit.Fonts.Title, TextSize = 18, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Text = "", Visible = false })
	local retry = UIKit.button(listFrame, { Name = "Retry", Text = "Try again", Size = UDim2.fromOffset(140, 38), Position = UDim2.fromScale(0.5, 0.62), AnchorPoint = Vector2.new(0.5, 0.5), Color = C.Green, Visible = false, OnClick = function() load(true) end })

	local footer = UIKit.label(body, { Name = "Footer", Size = UDim2.new(1, 0, 0, 36), Position = UDim2.new(0, 0, 1, -38), Font = UIKit.Fonts.Title, TextSize = 15, TextColor3 = C.Ink, Text = "" })

	local function clearRows()
		for _, child in scroll:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function showState(text: string?, withRetry: boolean?)
		stateLabel.Visible = text ~= nil
		stateLabel.Text = text or ""
		retry.Visible = withRetry == true
	end

	local function render(response: any, stale: boolean)
		clearRows()
		local result = response.Result
		local mode = LeaderboardConfig.MetricInfo[metric]
		description.Text = mode.Description .. "  -  " .. LeaderboardConfig.PeriodInfo[period].Note
		if result.Status == "error" and #result.Rows == 0 then
			showState("The rankings could not be loaded.\nCheck your connection and try again.", true)
		elseif result.Status == "empty" then
			showState("No scores yet - be the first!", false)
		else
			showState(if result.Status == "error" then nil else nil, false)
			for index, row in result.Rows do
				if index > SHOWN_ROWS then
					break
				end
				local mine = row.UserId == player.UserId
				local card = UIKit.frame(scroll, { Size = UDim2.new(1, -8, 0, ROW_HEIGHT), LayoutOrder = index, BackgroundColor3 = if mine then C.CardHover else C.Card })
				UIKit.corner(card, 8)
				if index <= 3 then
					UIKit.stroke(card, RANK_COLORS[index], 1.5, 0.2)
				elseif mine then
					UIKit.stroke(card, C.Gold, 1.5, 0.3)
				end
				local badge = UIKit.frame(card, { Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(8, 7), BackgroundColor3 = RANK_COLORS[index] or C.CreamDark })
				UIKit.corner(badge, 99)
				UIKit.label(badge, { Size = UDim2.fromScale(1, 1), Text = tostring(row.Rank), Font = UIKit.Fonts.Title, TextSize = 16, TextColor3 = if index <= 3 then C.BrownDark else C.Muted, TextXAlignment = Enum.TextXAlignment.Center })
				local avatar = UIKit.new("ImageLabel", { Name = "Avatar", Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(50, 6), BackgroundColor3 = C.CreamDark, Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=100&h=100", row.UserId) }, card)
				UIKit.corner(avatar, 99)
				UIKit.label(card, { Size = UDim2.new(1, -250, 1, 0), Position = UDim2.fromOffset(94, 0), Text = row.Name .. (if mine then "  (you)" else ""), Font = UIKit.Fonts.Title, TextSize = if index <= 3 then 17 else 15, TextColor3 = C.Ink, TextTruncate = Enum.TextTruncate.AtEnd })
				UIKit.label(card, { Size = UDim2.fromOffset(130, ROW_HEIGHT), Position = UDim2.new(1, -140, 0, 0), Text = Format.short(row.Score), Font = UIKit.Fonts.Title, TextSize = 18, TextColor3 = if index <= 3 then RANK_COLORS[index] else C.Cash, TextXAlignment = Enum.TextXAlignment.Right })
			end
		end
		-- footer: my rank / score
		local mineText
		if response.MyRank then
			mineText = string.format("Your rank: #%d   -   %s", response.MyRank, Format.short(response.MyScore or 0))
		elseif response.MyScore and response.MyScore > 0 then
			mineText = string.format("Your score: %s  (outside the top %d)", Format.short(response.MyScore), LeaderboardConfig.PageSize)
		else
			mineText = "You have no score in this ranking yet."
		end
		if stale then
			mineText ..= "   (showing the last loaded ranking)"
		end
		footer.Text = mineText
	end

	-- asks the server (at most once a second, outdated answers are dropped)
	load = function(force: boolean)
		local key = metric .. ":" .. period
		token += 1
		local mine = token
		if results[key] then
			render(results[key], false) -- instant: what we already know
			if not force and os.clock() - results[key].At < 20 then
				return
			end
		else
			clearRows()
			footer.Text = ""
			showState("Loading...", false)
			description.Text = LeaderboardConfig.MetricInfo[metric].Description
		end
		task.spawn(function()
			local wait = lastRequestAt + 1.05 - os.clock()
			if wait > 0 then
				task.wait(wait)
			end
			if mine ~= token then
				return
			end
			lastRequestAt = os.clock()
			local reply = DataController.request("Leaderboard", { Metric = metric, Period = period })
			if mine ~= token then
				return
			end
			if reply.ok and reply.extra then
				reply.extra.At = os.clock()
				if reply.extra.Result.Status ~= "error" then
					results[key] = reply.extra
				end
				render(reply.extra, false)
			elseif results[key] then
				render(results[key], true)
			else
				clearRows()
				footer.Text = ""
				showState(if reply.msg == "Slow down" then "One moment..." else "The rankings could not be loaded.\nCheck your connection and try again.", reply.msg ~= "Slow down")
			end
		end)
	end

	panel.OnOpen[1] = function()
		tabs.Select(metric, true)
		paintPeriods()
		load(true)
	end
	tabs.Select(metric, true)
	paintPeriods()

	-- refresh while open (the server caches for a minute, this never causes more reads than that)
	task.spawn(function()
		while true do
			task.wait(30)
			if panel.IsOpen then
				load(true)
			end
		end
	end)

	UIRegistry.tryRegister({ Id = "Leaderboards", Kind = "IconButton", Slot = "RightRail", Order = 40, Icon = "trophy", Tooltip = "Leaderboards", Panel = "Leaderboards", Core = true })
end

return LeaderboardUI
