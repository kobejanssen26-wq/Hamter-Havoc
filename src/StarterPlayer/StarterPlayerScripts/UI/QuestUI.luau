--[[
	QuestUI: quests and achievements. Progress comes from server-tracked stats; rewards are claimed
	with a button (claimable ones float to the top and the Quests button on the HUD shows a red dot).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local AchievementConfig = require(Modules:WaitForChild("AchievementConfig"))
local Format = require(Modules:WaitForChild("Format"))
local HamsterDatabase = require(Modules:WaitForChild("HamsterDatabase"))
local QuestConfig = require(Modules:WaitForChild("QuestConfig"))
local ShopConfig = require(Modules:WaitForChild("ShopConfig"))

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local UIKit = require(script.Parent.UIKit)

local QuestUI = {}

local C = UIKit.Colors

-- Rewards as (icon, text) pairs, shown with real icons.
local function rewardParts(reward: any): { { Icon: string, Text: string } }
	local parts = {}
	if reward.Coins then
		table.insert(parts, { Icon = "Coin", Text = Format.coins(reward.Coins) })
	end
	if reward.Gems then
		table.insert(parts, { Icon = "Gem", Text = Format.short(reward.Gems) })
	end
	if reward.Tokens then
		table.insert(parts, { Icon = "Token", Text = tostring(reward.Tokens) })
	end
	if reward.Boost then
		local info = ShopConfig.Boosts[reward.Boost.Id]
		table.insert(parts, { Icon = if info then info.Icon else "Speed", Text = string.format("%dm", math.floor(reward.Boost.Seconds / 60)) })
	end
	if reward.Hamster then
		local species = HamsterDatabase.ById[reward.Hamster]
		table.insert(parts, { Icon = "Hamster", Text = if species then species.Name else "Hamster" })
	end
	return parts
end

function QuestUI.start()
	local panel = UIKit.panel({ Name = "Quests", Title = "Quests & Achievements", Icon = "Quests", Design = Vector2.new(860, 640), Accent = C.Purple })
	local body = panel.Body

	local mode = "Quests"
	local render
	local tabs = UIKit.tabs(body, {
		{ Id = "Quests", Text = "Quests", Icon = "Quests", Color = C.Purple },
		{ Id = "Achievements", Text = "Achievements", Icon = "Trophy", Color = C.GoldDark },
	}, function(id)
		mode = id
		render()
	end, { ButtonSize = UDim2.fromOffset(180, 38) })

	local scroll = UIKit.scroll(body, { Size = UDim2.new(1, 0, 1, -52), Position = UDim2.fromOffset(0, 50) })
	UIKit.list(scroll, Enum.FillDirection.Vertical, 8)
	UIKit.padding(scroll, 4)

	render = function()
		local data = DataController.Data
		if not data.Quests or not data.Stats or not data.Index then
			return
		end

		for _, child in scroll:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end

		local list = {}
		local source = if mode == "Quests" then QuestConfig.Quests else AchievementConfig.List
		local claimedTable = if mode == "Quests" then data.Quests.Claimed else data.Achievements.Claimed
		for _, entry in source do
			local value = QuestConfig.getStat(data, entry.Stat)
			local complete = value >= entry.Target
			local claimed = claimedTable[entry.Id] == true
			local priority = if complete and not claimed then 0 elseif not claimed then 1 else 2
			table.insert(list, { Entry = entry, Value = value, Complete = complete, Claimed = claimed, Priority = priority, Fraction = value / entry.Target })
		end
		table.sort(list, function(a, b)
			if a.Priority ~= b.Priority then
				return a.Priority < b.Priority
			end
			return a.Fraction > b.Fraction
		end)

		for order, item in list do
			local entry = item.Entry
			local row = UIKit.card(scroll, { Size = UDim2.new(1, -8, 0, 84), LayoutOrder = order })
			local rowStroke = row:FindFirstChildOfClass("UIStroke") :: UIStroke
			rowStroke.Color = if item.Complete and not item.Claimed then C.Gold elseif item.Claimed then C.Mint else C.Line
			rowStroke.Thickness = if item.Complete and not item.Claimed then 3 else 1.5

			local icon = UIKit.frame(row, { Size = UDim2.fromOffset(58, 58), Position = UDim2.fromOffset(12, 13), BackgroundColor3 = C.Cream })
			UIKit.corner(icon, 16)
			UIKit.icon(icon, if item.Claimed then "Check" else (entry.Icon or (if item.Complete then "Star" else "Quests")), 42, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
			UIKit.label(row, {
				Position = UDim2.fromOffset(82, 6),
				Size = UDim2.new(1, -290, 0, 24),
				Text = entry.Title,
				Font = UIKit.Fonts.Title,
				TextSize = 19,
			})
			UIKit.label(row, {
				Position = UDim2.fromOffset(82, 30),
				Size = UDim2.new(1, -290, 0, 18),
				Text = entry.Desc,
				TextSize = 13,
				TextColor3 = C.Muted,
			})
			local bar = UIKit.progress(row, {
				Size = UDim2.new(1, -300, 0, 18),
				Position = UDim2.fromOffset(82, 52),
				Color = if item.Claimed then C.Green else C.Purple,
			})
			bar.Set(item.Fraction, string.format("%s / %s", Format.short(math.min(item.Value, entry.Target)), Format.short(entry.Target)))
			local rewardRow = UIKit.frame(row, { Position = UDim2.new(1, -12, 0, 8), AnchorPoint = Vector2.new(1, 0), Size = UDim2.fromOffset(200, 22), BackgroundTransparency = 1 })
			UIKit.list(rewardRow, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right)
			for partIndex, part in rewardParts(entry.Reward) do
				local amountRow, amountLabel = UIKit.amount(rewardRow, part.Icon, part.Text, { Size = UDim2.fromOffset(0, 20), TextSize = 14, Color = C.GoldDark, LayoutOrder = partIndex })
				amountRow.AutomaticSize = Enum.AutomaticSize.X
				amountLabel.AutomaticSize = Enum.AutomaticSize.X
				amountLabel.Size = UDim2.fromOffset(0, 20)
			end
			local button = UIKit.button(row, {
				Text = if item.Claimed then "Claimed" elseif item.Complete then "Claim!" else "Locked",
				Size = UDim2.fromOffset(120, 40),
				Position = UDim2.new(1, -12, 1, -10),
				AnchorPoint = Vector2.new(1, 1),
				Color = if item.Complete and not item.Claimed then C.Green else C.Muted,
				TextSize = 17,
				OnClick = function()
					local action = if mode == "Quests" then "ClaimQuest" else "ClaimAchievement"
					local result = DataController.request(action, { Id = entry.Id })
					if result.ok then
						AudioController.play("Reward")
					else
						require(script.Parent.MainUI).toast(result.msg, "error")
					end
				end,
			})
			UIKit.setEnabled(button, item.Complete and not item.Claimed)
		end
	end

	table.insert(panel.OnOpen, function()
		tabs.Select(mode, true)
		render()
	end)
	tabs.Select("Quests", true)
	DataController.onChanged(function(keys)
		if panel.IsOpen and (keys.Quests or keys.Achievements or keys.Stats or keys.Index or keys.Rebirths) then
			render()
		end
	end)
end

return QuestUI
