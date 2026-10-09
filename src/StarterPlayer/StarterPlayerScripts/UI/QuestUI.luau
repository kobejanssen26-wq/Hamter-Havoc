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

-- Reward chips with drawn icons: coin 500  gem 20  flame 2  bolt 15m  hamster Name
local function rewardRow(parent: Instance, reward: any, position: UDim2)
	local row = UIKit.frame(parent, { Size = UDim2.fromOffset(190, 22), Position = position, BackgroundTransparency = 1 })
	UIKit.list(row, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Right, Enum.VerticalAlignment.Center)
	local order = 0
	local function add(icon: string, text: string)
		order += 1
		UIKit.iconText(row, { Icon = icon, Text = text, Size = UDim2.fromOffset(0, 22), TextSize = 13, TextColor = C.GoldDark, Font = UIKit.Fonts.Body, LayoutOrder = order }).Frame.AutomaticSize = Enum.AutomaticSize.X
	end
	if reward.Coins then
		add("coin", Format.short(reward.Coins))
	end
	if reward.Gems then
		add("gem", Format.short(reward.Gems))
	end
	if reward.Tokens then
		add("flame", tostring(reward.Tokens))
	end
	if reward.Boost then
		local info = ShopConfig.Boosts[reward.Boost.Id]
		add(if info then info.Icon else "bolt", string.format("%dm", math.floor(reward.Boost.Seconds / 60)))
	end
	if reward.Hamster then
		local species = HamsterDatabase.ById[reward.Hamster]
		add("hamster", if species then species.Name else "Hamster")
	end
	return row
end

function QuestUI.start()
	local panel = UIKit.panel({ Name = "Quests", Title = "Quests & Achievements", Icon = "scroll", Design = Vector2.new(860, 640), Accent = C.Purple })
	local body = panel.Body

	local mode = "Quests"
	local render
	local tabs = UIKit.tabs(body, {
		{ Id = "Quests", Text = "Quests", Color = C.Purple },
		{ Id = "Achievements", Text = "Achievements", Color = C.Gold },
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
			local row = UIKit.frame(scroll, { Size = UDim2.new(1, -8, 0, 84), LayoutOrder = order })
			UIKit.corner(row, 16)
			UIKit.stroke(row, if item.Complete and not item.Claimed then C.Gold elseif item.Claimed then C.Green else Color3.fromRGB(226, 208, 180), 3)

			local icon = UIKit.frame(row, { Size = UDim2.fromOffset(58, 58), Position = UDim2.fromOffset(12, 13), BackgroundColor3 = C.CreamDark })
			UIKit.corner(icon, 14)
			UIKit.icon(icon, entry.Icon or (if item.Claimed then "check" elseif item.Complete then "gift" else "scroll"), { Size = UDim2.fromOffset(40, 40), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
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
			rewardRow(row, entry.Reward, UDim2.new(1, -202, 0, 8))
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

	panel.OnOpen[1] = function()
		tabs.Select(mode, true)
		render()
	end
	tabs.Select("Quests", true)
	DataController.onChanged(function(keys)
		if panel.IsOpen and (keys.Quests or keys.Achievements or keys.Stats or keys.Index or keys.Rebirths) then
			render()
		end
	end)
end

return QuestUI
