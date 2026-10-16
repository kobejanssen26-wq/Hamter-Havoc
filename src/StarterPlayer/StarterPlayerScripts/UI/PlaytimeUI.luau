--[[
	PlaytimeUI: the Playtime Rewards window (hourglass in the right rail; it never opens by itself).
	Milestones and rewards come from Modules/PlaytimeConfig. The SERVER counts the time and pays; this window shows the counter,
	the progress to the next milestone and a Claim button on every milestone that is reached and not claimed yet.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local PlaytimeConfig = require(Modules:WaitForChild("PlaytimeConfig"))

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local PlaytimeUI = {}

local C = UIKit.Colors

-- Texts of the window (edit here).
PlaytimeUI.Texts = {
	Title = "Playtime Rewards",
	Subtitle = "Stay in the game: every milestone gives a reward (up to 8 hours)",
	Played = "Time played",
	Next = "Next reward in",
	AllDone = "All rewards claimed!",
	Rule = "Only time in this game counts. Every reward can be claimed once.",
}

local function duration(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours, minutes = seconds // 3600, seconds % 3600 // 60
	if hours > 0 then
		return string.format("%dh %02dm", hours, minutes)
	end
	return string.format("%dm %02ds", minutes, seconds % 60)
end

function PlaytimeUI.start()
	local texts = PlaytimeUI.Texts
	local panel = UIKit.panel({ Name = "Playtime", Title = texts.Title, Icon = "hourglass", Design = Vector2.new(920, 560), Accent = Theme.Accents.Rebirth, Subtitle = texts.Subtitle })
	local body = panel.Body

	-- summary: time played + progress to the next milestone
	local played = UIKit.label(body, { Name = "Played", Size = UDim2.new(1, 0, 0, 34), Text = "", Font = UIKit.Fonts.Title, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Center })
	local bar = UIKit.progress(body, { Size = UDim2.new(1, -80, 0, 22), Position = UDim2.fromOffset(40, 42), Color = C.Green })
	bar.Frame.Name = "Progress"
	local nextLabel = UIKit.label(body, { Name = "NextReward", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 70), Text = "", TextSize = 16, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Center })

	local grid = UIKit.frame(body, { Name = "Milestones", Size = UDim2.new(1, 0, 1, -142), Position = UDim2.fromOffset(0, 102), BackgroundTransparency = 1 })
	UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(200, 190), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, grid)

	local cards: { { Frame: Frame, Edge: UIStroke, State: TextLabel, Button: TextButton, Lines: TextLabel, Time: TextLabel } } = {}
	local claiming: { [string]: boolean } = {}
	for index, milestone in PlaytimeConfig.Milestones do
		local card = UIKit.frame(grid, { Name = "Milestone_" .. milestone.Id, LayoutOrder = index, BackgroundColor3 = C.Card })
		UIKit.corner(card, 12)
		local edge = UIKit.stroke(card, C.Line, 2)
		local timeLabel = UIKit.label(card, { Name = "Time", Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 6), Text = duration(PlaytimeConfig.seconds(milestone)), Font = UIKit.Fonts.Title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center })
		UIKit.icon(card, milestone.Icon, { Name = "RewardIcon", Size = UDim2.fromOffset(48, 48), Position = UDim2.new(0.5, 0, 0, 38), AnchorPoint = Vector2.new(0.5, 0) })
		local lines = UIKit.label(card, { Name = "RewardLines", Size = UDim2.new(1, -12, 0, 52), Position = UDim2.fromOffset(6, 90), Text = "", TextSize = 13, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, Font = UIKit.Fonts.Title })
		local state = UIKit.label(card, { Name = "State", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -64), Text = "", TextSize = 14, Font = UIKit.Fonts.Title, TextXAlignment = Enum.TextXAlignment.Center })
		local button = UIKit.button(card, {
			Name = "Claim",
			Text = "Claim",
			Size = UDim2.new(1, -24, 0, 34),
			Position = UDim2.new(0, 12, 1, -42),
			Color = C.Green,
			TextSize = 16,
			OnClick = function()
				if claiming[milestone.Id] then
					return
				end
				claiming[milestone.Id] = true
				local result = DataController.request("ClaimPlaytime", { Id = milestone.Id })
				task.delay(0.6, function()
					claiming[milestone.Id] = nil
				end)
				if result.ok then
					AudioController.play("Reward")
				else
					require(script.Parent.MainUI).toast(result.msg, "error")
					AudioController.play("Error")
				end
			end,
		})
		cards[index] = { Frame = card, Edge = edge, State = state, Button = button, Lines = lines, Time = timeLabel }
	end

	UIKit.label(body, { Name = "Rule", Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -26), Text = texts.Rule, TextSize = 13, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Center })

	local function refresh()
		local data = DataController.Data
		if not data.Playtime then
			return
		end
		local seconds = DataController.playtimeSeconds()
		local list, nextIndex = PlaytimeConfig.state(data.Playtime, seconds)
		played.Text = string.format("%s: %s", texts.Played, duration(seconds))
		local previous = 0
		if nextIndex then
			local milestone = PlaytimeConfig.Milestones[nextIndex]
			if nextIndex > 1 then
				previous = PlaytimeConfig.seconds(PlaytimeConfig.Milestones[nextIndex - 1])
			end
			local needed = PlaytimeConfig.seconds(milestone)
			local fraction = if seconds >= needed then 1 else (seconds - previous) / math.max(1, needed - previous)
			bar.Set(fraction, duration(math.max(0, needed - seconds)))
			nextLabel.Text = if seconds >= needed then "A reward is ready to claim!" else string.format("%s %s", texts.Next, duration(needed - seconds))
		else
			bar.Set(1, "")
			nextLabel.Text = texts.AllDone
		end
		for index, entry in list do
			local card = cards[index]
			card.Lines.Text = table.concat(PlaytimeConfig.lines(entry.Milestone, data.Rebirths or 0), "\n")
			card.Button.Visible = entry.Status == "ready"
			card.State.Visible = entry.Status ~= "ready"
			if entry.Status == "claimed" then
				card.State.Text = "Claimed"
				card.State.TextColor3 = C.Green
				card.Edge.Color = C.Green
				card.Frame.BackgroundTransparency = 0.35
			elseif entry.Status == "ready" then
				card.Edge.Color = C.Gold
				card.Frame.BackgroundTransparency = 0
			else
				card.State.Text = "in " .. duration(entry.Remaining)
				card.State.TextColor3 = C.Muted
				card.Edge.Color = C.Line
				card.Frame.BackgroundTransparency = 0
			end
			card.Edge.Thickness = if entry.Status == "ready" or index == nextIndex then 4 else 2
			if index == nextIndex and entry.Status == "locked" then
				card.Edge.Color = C.Blue -- the next milestone
			end
		end
	end

	panel.OnOpen[1] = refresh
	DataController.onChanged(function(keys)
		if panel.IsOpen and (keys.Playtime or keys.Rebirths) then
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

return PlaytimeUI
