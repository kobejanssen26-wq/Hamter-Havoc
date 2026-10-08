--[[
	IndexUI: the Hamster Index. Every rarity is a tab; every hamster is a card with its 3D icon.
	Uncollected hamsters are silhouettes, Secret/??? hamsters stay completely hidden until found.
	Completing a whole rarity unlocks a gem reward; every unique hamster gives a permanent coin bonus.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local EconomyMath = require(Modules:WaitForChild("EconomyMath"))
local Format = require(Modules:WaitForChild("Format"))
local HamsterDatabase = require(Modules:WaitForChild("HamsterDatabase"))
local RarityConfig = require(Modules:WaitForChild("RarityConfig"))

local DataController = require(script.Parent.Parent.Controllers.DataController)
local UIKit = require(script.Parent.UIKit)

local IndexUI = {}

local C = UIKit.Colors

function IndexUI.start()
	local panel = UIKit.panel({ Name = "Index", Title = "Hamster Index", Icon = "📖", Design = Vector2.new(980, 640), Accent = C.Sky })
	local body = panel.Body

	-- summary row
	local summary = UIKit.frame(body, { Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = C.Card })
	UIKit.corner(summary, 14)
	UIKit.stroke(summary, Color3.fromRGB(226, 208, 180), 2)
	local collectedLabel = UIKit.label(summary, {
		Position = UDim2.fromOffset(16, 4),
		Size = UDim2.fromOffset(320, 26),
		Font = UIKit.Fonts.Title,
		TextSize = 22,
		Text = "Collected: 0 / 0",
	})
	local bonusLabel = UIKit.label(summary, {
		Position = UDim2.fromOffset(16, 30),
		Size = UDim2.fromOffset(400, 22),
		TextSize = 14,
		TextColor3 = C.Muted,
		Text = "",
	})
	local bar = UIKit.progress(summary, {
		Size = UDim2.new(1, -460, 0, 22),
		Position = UDim2.new(1, -14, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = C.Sky,
	})

	-- rarity list (left)
	local list = UIKit.scroll(body, { Size = UDim2.new(0, 200, 1, -70), Position = UDim2.fromOffset(0, 68) })
	UIKit.list(list, Enum.FillDirection.Vertical, 6)
	UIKit.padding(list, 2)

	-- detail area (right)
	local detail = UIKit.frame(body, { Size = UDim2.new(1, -212, 1, -70), Position = UDim2.fromOffset(212, 68), BackgroundTransparency = 1 })
	local rarityHeader = UIKit.frame(detail, { Size = UDim2.new(1, 0, 0, 56), BackgroundColor3 = C.Card })
	UIKit.corner(rarityHeader, 14)
	local headerStroke = UIKit.stroke(rarityHeader, C.Brown, 3)
	local headerTitle = UIKit.label(rarityHeader, {
		Position = UDim2.fromOffset(14, 4),
		Size = UDim2.new(1, -230, 0, 28),
		Font = UIKit.Fonts.Title,
		TextSize = 24,
		Text = "",
	})
	local headerInfo = UIKit.label(rarityHeader, {
		Position = UDim2.fromOffset(14, 30),
		Size = UDim2.new(1, -230, 0, 22),
		TextSize = 13,
		TextColor3 = C.Muted,
		Text = "",
	})
	local claimButton = UIKit.button(rarityHeader, {
		Text = "Claim 💎",
		Size = UDim2.fromOffset(190, 40),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = C.Green,
		TextSize = 17,
		OnClick = function() end,
	})

	local grid = UIKit.scroll(detail, { Size = UDim2.new(1, 0, 1, -64), Position = UDim2.fromOffset(0, 64) })

	local selected = "Basic"
	local tabButtons: { [string]: { Button: TextButton, Count: TextLabel } } = {}
	local claimRarity: string? = nil

	local function rarityProgress(data: any, rarityId: string): (number, number)
		local have, total = 0, 0
		for _, species in HamsterDatabase.ByRarity[rarityId] do
			total += 1
			if data.Index and data.Index[species.Id] then
				have += 1
			end
		end
		return have, total
	end

	local function refreshSummary()
		local data = DataController.Data
		if not data.Index then
			return
		end
		local unique = EconomyMath.uniqueCount(data)
		collectedLabel.Text = string.format("Collected: %d / %d", unique, HamsterDatabase.Total)
		bonusLabel.Text = string.format("Index bonus: +%.1f%% coins for every hamster you ever found", unique * EconomyMath.IndexBonusPerHamster * 100)
		bar.Set(unique / HamsterDatabase.Total, string.format("%d%%", math.floor(unique / HamsterDatabase.Total * 100)))
		for rarityId, entry in tabButtons do
			local have, total = rarityProgress(data, rarityId)
			entry.Count.Text = string.format("%d/%d", have, total)
		end
	end

	local function renderRarity()
		local data = DataController.Data
		if not data.Index then
			return
		end
		local definition = RarityConfig.ById[selected]
		local color = UIKit.rarityColor(definition)
		headerStroke.Color = color
		headerTitle.Text = string.format('<font color="#%s">%s</font>', color:ToHex(), definition.Name)
		headerInfo.Text = string.format("Speed %g studs/s  •  %s  •  Income %s/s%s", definition.Speed, definition.Difficulty, Format.short(definition.Income), if definition.MinRebirth > 0 then "  •  Unlocks at Rebirth " .. definition.MinRebirth else "")

		local spawnableTotal = #HamsterDatabase.Spawnable[selected]
		local spawnableHave = 0
		for _, species in HamsterDatabase.ByRarity[selected] do
			if data.Index[species.Id] then
				if not species.Exclusive then
					spawnableHave += 1
				end
			end
		end
		local complete = spawnableHave >= spawnableTotal and spawnableTotal > 0
		local claimed = data.IndexRewards and data.IndexRewards[selected]
		claimRarity = selected
		local reward = definition.IndexReward
		if claimed then
			claimButton.Text = "Reward claimed ✓"
			UIKit.setEnabled(claimButton, false)
		elseif complete then
			claimButton.Text = string.format("Claim 💎 %s", Format.short(reward.Gems))
			UIKit.setEnabled(claimButton, true)
		else
			claimButton.Text = string.format("Complete: %d/%d  💎 %s", spawnableHave, spawnableTotal, Format.short(reward.Gems))
			UIKit.setEnabled(claimButton, false)
		end

		grid:ClearAllChildren()
		UIKit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(168, 206),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, grid)
		UIKit.padding(grid, 4)

		for order, species in HamsterDatabase.ByRarity[selected] do
			local found = data.Index[species.Id] == true
			local hiddenRarity = definition.Hidden
			local card = UIKit.frame(grid, { LayoutOrder = order, BackgroundColor3 = if found then C.Card else C.CreamDark })
			UIKit.corner(card, 16)
			UIKit.stroke(card, if found then color else Color3.fromRGB(214, 194, 164), if found then 3 else 2)

			if found or not hiddenRarity then
				UIKit.hamsterIcon(card, species, { Size = UDim2.new(1, -8, 0, 116), Position = UDim2.fromOffset(4, 4), Silhouette = not found })
			else
				UIKit.label(card, {
					Size = UDim2.new(1, 0, 0, 116),
					Position = UDim2.fromOffset(0, 4),
					Text = "?",
					TextSize = 70,
					Font = UIKit.Fonts.Title,
					TextColor3 = Color3.fromRGB(190, 170, 150),
					TextXAlignment = Enum.TextXAlignment.Center,
				})
			end

			UIKit.label(card, {
				Size = UDim2.new(1, -10, 0, 24),
				Position = UDim2.fromOffset(5, 122),
				Text = if found then species.Name elseif hiddenRarity then "???" else species.Name,
				TextSize = 17,
				Font = UIKit.Fonts.Title,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = if found then C.Ink else C.Muted,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			UIKit.label(card, {
				Size = UDim2.new(1, -10, 0, 20),
				Position = UDim2.fromOffset(5, 146),
				Text = if found or not hiddenRarity then "🪙 " .. Format.short(HamsterDatabase.income(species)) .. "/s" else "🪙 ???",
				TextSize = 14,
				TextColor3 = C.GoldDark,
				TextXAlignment = Enum.TextXAlignment.Center,
			})
			local chipText = if found then "✓ Collected" else "? Not found"
			local chipColor = if found then C.Green else Color3.fromRGB(176, 156, 140)
			if species.Exclusive then
				chipText = if found then "★ Exclusive ✓" else "★ Exclusive"
				chipColor = if found then C.Purple else Color3.fromRGB(160, 130, 200)
			end
			local chip = UIKit.chip(card, chipText, chipColor, UDim2.fromOffset(118, 22))
			chip.Position = UDim2.new(0.5, -59, 1, -30)
		end
	end

	-- build the rarity list
	for order, rarityId in RarityConfig.Order do
		local definition = RarityConfig.ById[rarityId]
		local color = UIKit.rarityColor(definition)
		local button = UIKit.button(list, {
			Text = "",
			Size = UDim2.new(1, -8, 0, 44),
			Color = C.CreamDark,
			Corner = 12,
			LayoutOrder = order,
			Name = "Rarity_" .. rarityId,
			OnClick = function()
				selected = rarityId
				for id, entry in tabButtons do
					UIKit.setButtonColor(entry.Button, if id == rarityId then C.White else C.CreamDark)
				end
				renderRarity()
			end,
		})
		UIKit.frame(button, { Size = UDim2.fromOffset(10, 28), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = color })
		UIKit.corner(button:FindFirstChildOfClass("Frame") :: Frame, 5)
		UIKit.label(button, {
			Position = UDim2.fromOffset(26, 0),
			Size = UDim2.new(1, -84, 1, 0),
			Text = definition.Name,
			TextSize = 17,
			Font = UIKit.Fonts.Title,
			TextColor3 = C.Ink,
		})
		local count = UIKit.label(button, {
			Position = UDim2.new(1, -62, 0, 0),
			Size = UDim2.fromOffset(54, 44),
			Text = "0/0",
			TextSize = 14,
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		tabButtons[rarityId] = { Button = button, Count = count }
	end
	UIKit.setButtonColor(tabButtons.Basic.Button, C.White)

	claimButton.Activated:Connect(function()
		if claimRarity and not claimButton:GetAttribute("Disabled") then
			local result = DataController.request("ClaimIndexReward", { Rarity = claimRarity })
			if not result.ok then
				-- the server message is shown by the toast system through Notify when it pays out
				require(script.Parent.MainUI).toast(result.msg, "error")
			else
				require(script.Parent.MainUI).toast(result.msg, "reward")
			end
		end
	end)

	panel.OnOpen[1] = function()
		refreshSummary()
		renderRarity()
	end
	DataController.onChanged(function(keys)
		if panel.IsOpen and (keys.Index or keys.IndexRewards or keys.Derived) then
			refreshSummary()
			renderRarity()
		end
	end)
end

return IndexUI
