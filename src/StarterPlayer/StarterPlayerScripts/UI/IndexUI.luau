--[[
	IndexUI: the Hamster Index.
	  - browse by Rarity, Theme, World or Event (left list); every hamster is a card with its 3D icon
	  - click a card to inspect the hamster: spinning 3D model, rarity, value, discovery status, copies owned
	  - "Rewards" tab: collection milestones (permanent % bonuses), titles and the final prestige reward
	Uncollected hamsters are silhouettes, Secret/??? hamsters stay completely hidden until found.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local EconomyMath = require(Modules:WaitForChild("EconomyMath"))
local Format = require(Modules:WaitForChild("Format"))
local HamsterDatabase = require(Modules:WaitForChild("HamsterDatabase"))
local HamsterGroups = require(Modules:WaitForChild("HamsterGroups"))
local IndexRewardConfig = require(Modules:WaitForChild("IndexRewardConfig"))
local RarityConfig = require(Modules:WaitForChild("RarityConfig"))

local DataController = require(script.Parent.Parent.Controllers.DataController)
local UIKit = require(script.Parent.UIKit)

local IndexUI = {}

local C = UIKit.Colors

type Entry = { Id: string, Name: string, Icon: string, Info: string, Color: Color3, Species: { any }, Rarity: string? }

local MODES = { "Rarity", "Theme", "World", "Event", "Rewards" }
local MODE_LABELS = { Rarity = "Rarity", Theme = "Theme", World = "World", Event = "Event", Rewards = "Rewards" }

local function entriesFor(mode: string): { Entry }
	local result: { Entry } = {}
	if mode == "Rarity" then
		for _, rarityId in RarityConfig.Order do
			local definition = RarityConfig.ById[rarityId]
			table.insert(result, {
				Id = rarityId,
				Name = definition.Name,
				Icon = "Star",
				Info = "",
				Color = UIKit.rarityColor(definition),
				Species = HamsterDatabase.ByRarity[rarityId],
				Rarity = rarityId,
			})
		end
	else
		for _, group in HamsterGroups.groups(mode) do
			table.insert(result, { Id = group.Id, Name = group.Name, Icon = group.Icon, Info = group.Info, Color = C.Sky, Species = group.Species })
		end
	end
	return result
end

function IndexUI.start()
	local panel = UIKit.panel({ Name = "Index", Title = "Hamster Index", Icon = "Index", Design = Vector2.new(1000, 660), Accent = C.Sky })
	local body = panel.Body

	-- summary row
	local summary = UIKit.card(body, { Size = UDim2.new(1, 0, 0, 58) })
	local collectedLabel = UIKit.label(summary, {
		Position = UDim2.fromOffset(16, 4),
		Size = UDim2.fromOffset(360, 26),
		Font = UIKit.Fonts.Title,
		TextSize = 22,
		Text = "0 / 0 COLLECTED",
	})
	local bonusLabel = UIKit.label(summary, {
		Position = UDim2.fromOffset(16, 30),
		Size = UDim2.fromOffset(460, 22),
		TextSize = 13,
		TextColor3 = C.Muted,
		Text = "",
	})
	local bar = UIKit.progress(summary, {
		Size = UDim2.new(1, -500, 0, 22),
		Position = UDim2.new(1, -14, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = C.Sky,
	})

	-- browse mode buttons + group list (left)
	local modeRow = UIKit.frame(body, { Size = UDim2.new(0, 214, 0, 62), Position = UDim2.fromOffset(0, 66), BackgroundTransparency = 1 })
	local list = UIKit.scroll(body, { Size = UDim2.new(0, 214, 1, -134), Position = UDim2.fromOffset(0, 132) })
	UIKit.list(list, Enum.FillDirection.Vertical, 6)
	UIKit.padding(list, 2)

	-- detail area (right)
	local detail = UIKit.frame(body, { Size = UDim2.new(1, -226, 1, -66), Position = UDim2.fromOffset(226, 66), BackgroundTransparency = 1 })
	local header = UIKit.card(detail, { Size = UDim2.new(1, 0, 0, 56) })
	local headerStroke = header:FindFirstChildOfClass("UIStroke") :: UIStroke
	headerStroke.Thickness = 2.5
	local headerIcon: GuiObject = UIKit.icon(header, "Index", 40, { Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
	local headerTitle = UIKit.label(header, {
		Position = UDim2.fromOffset(58, 4),
		Size = UDim2.new(1, -230, 0, 28),
		Font = UIKit.Fonts.Title,
		TextSize = 24,
		Text = "",
	})
	local headerInfo = UIKit.label(header, {
		Position = UDim2.fromOffset(58, 30),
		Size = UDim2.new(1, -230, 0, 22),
		TextSize = 13,
		TextColor3 = C.Muted,
		Text = "",
	})
	local claimButton = UIKit.button(header, {
		Text = "Claim",
		Size = UDim2.fromOffset(190, 40),
		Position = UDim2.new(1, -8, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = C.Green,
		TextSize = 17,
		OnClick = function() end,
	})

	local grid = UIKit.scroll(detail, { Size = UDim2.new(1, 0, 1, -64), Position = UDim2.fromOffset(0, 64) })

	-- inspect popup
	local inspect = UIKit.frame(body, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Dim, BackgroundTransparency = 0.45, Visible = false, ZIndex = 20 })
	inspect.Active = true
	local inspectCard = UIKit.frame(inspect, {
		Size = UDim2.fromOffset(440, 460),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.Card,
		ZIndex = 21,
	})
	UIKit.corner(inspectCard, 22)
	local inspectStroke = UIKit.stroke(inspectCard, C.Sky, 4)
	local inspectIconHolder = UIKit.frame(inspectCard, { Size = UDim2.new(1, -40, 0, 250), Position = UDim2.fromOffset(20, 16), BackgroundTransparency = 1, ZIndex = 22 })
	local inspectName = UIKit.label(inspectCard, {
		Position = UDim2.fromOffset(0, 270),
		Size = UDim2.new(1, 0, 0, 34),
		Font = UIKit.Fonts.Title,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		ZIndex = 22,
	})
	local inspectRarity = UIKit.label(inspectCard, {
		Position = UDim2.fromOffset(0, 304),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 16,
		Font = UIKit.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
		ZIndex = 22,
	})
	local inspectFacts = UIKit.label(inspectCard, {
		Position = UDim2.fromOffset(24, 332),
		Size = UDim2.new(1, -48, 0, 88),
		TextSize = 15,
		TextColor3 = C.Ink,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = "",
		ZIndex = 22,
	})
	UIKit.button(inspectCard, {
		Text = "Close",
		Size = UDim2.fromOffset(140, 38),
		Position = UDim2.new(0.5, 0, 1, -12),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Sky,
		TextSize = 17,
		ZIndex = 23,
		OnClick = function()
			inspect.Visible = false
		end,
	})

	local mode = "Rarity"
	local selected: { [string]: string } = { Rarity = "Basic", Theme = "treats", World = "meadow", Event = "event" }
	local tabButtons: { [string]: { Button: TextButton, Count: TextLabel } } = {}
	local modeButtons: { [string]: TextButton } = {}
	local claimTarget: string? = nil

	local function bestRarityFound(data: any): string
		local best, bestRank = "none yet", 0
		for rarityId, count in data.Stats.Found or {} do
			local rank = RarityConfig.rank(rarityId)
			if count > 0 and rank > bestRank then
				best, bestRank = RarityConfig.ById[rarityId].Name, rank
			end
		end
		return best
	end

	local function openInspect(species: any, found: boolean)
		local data = DataController.Data
		local definition = RarityConfig.ById[species.Rarity]
		local color = UIKit.rarityColor(definition)
		local hidden = definition.Hidden and not found
		for _, child in inspectIconHolder:GetChildren() do
			child:Destroy()
		end
		if not hidden then
			UIKit.hamsterIcon(inspectIconHolder, species, { Size = UDim2.fromScale(1, 1), Silhouette = not found, Spin = found })
		else
			UIKit.label(inspectIconHolder, { Size = UDim2.fromScale(1, 1), Text = "?", TextSize = 140, Font = UIKit.Fonts.Title, TextColor3 = Color3.fromRGB(190, 170, 150), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 23 })
		end
		inspectStroke.Color = color
		inspectName.Text = if hidden then "???" else species.Name
		inspectRarity.Text = string.format('<font color="#%s">%s</font>%s', color:ToHex(), definition.Name, if species.Exclusive then "  -  Exclusive" else "")
		local owned = (data.Inventory or {})[species.Id] or 0
		local working = 0
		for _, id in data.Equipped or {} do
			if id == species.Id then
				working += 1
			end
		end
		local stats = HamsterDatabase.stats(species)
		inspectFacts.Text = string.format(
			"Status: <b>%s</b>\nIncome: %s / second   -   Price: %s\nSpawn chance: %s   -   Speed: %g studs/s\nYou own %d, %d working on a wheel\nBest rarity you found so far: %s",
			if owned > 0 then "Owned" elseif found then "Discovered" else "Missing",
			if hidden then "???" else Format.coins(stats.Income),
			if hidden then "???" else Format.coins(stats.Price),
			if species.Exclusive then "reward only" else (if stats.SpawnChance >= 0.001 then string.format("%.2f%%", stats.SpawnChance * 100) else string.format("1 in %s", Format.short(1 / math.max(stats.SpawnChance, 1e-12)))),
			stats.Speed,
			owned,
			working,
			bestRarityFound(data)
		)
		inspect.Visible = true
	end

	local function groupProgress(data: any, entry: Entry): (number, number)
		local have, total = 0, 0
		for _, species in entry.Species do
			if not species.Exclusive or entry.Id == "event" then
				total += 1
				if data.Index[species.Id] then
					have += 1
				end
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
		collectedLabel.Text = string.format("%d / %d COLLECTED", unique, HamsterDatabase.Total)
		local derived = DataController.derived()
		local title = derived.Title
		local ownedKinds, working = 0, #(data.Equipped or {})
		for _, count in data.Inventory or {} do
			if count > 0 then
				ownedKinds += 1
			end
		end
		bonusLabel.Text = string.format(
			"Own %d kinds  -  %d working  -  %d missing  -  Index bonus +%.1f%% coins, milestones +%d%% coins +%d%% luck%s",
			ownedKinds,
			working,
			HamsterDatabase.Total - unique,
			unique * EconomyMath.IndexBonusPerHamster * 100,
			math.floor((derived.IndexCoinBonus or 0) * 100 + 0.5),
			math.floor((derived.IndexLuckBonus or 0) * 100 + 0.5),
			if title and title ~= "" then "  -  " .. title else ""
		)
		bar.Set(unique / HamsterDatabase.Total, string.format("%d%%", math.floor(unique / HamsterDatabase.Total * 100)))
		for id, entry in tabButtons do
			local entryData = nil
			for _, candidate in entriesFor(mode) do
				if candidate.Id == id then
					entryData = candidate
				end
			end
			if entryData then
				local have, total = groupProgress(data, entryData)
				entry.Count.Text = string.format("%d/%d", have, total)
			end
		end
	end

	local function clearGrid()
		grid:ClearAllChildren()
	end

	local function renderRewards()
		local data = DataController.Data
		if not data.Index then
			return
		end
		headerStroke.Color = C.Gold
		headerTitle.Text = "Collection rewards"
		headerIcon:Destroy()
		headerIcon = UIKit.icon(header, "Trophy", 40, { Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
		headerInfo.Text = "Bonuses are permanent and apply automatically as soon as you find enough hamsters."
		local final = IndexRewardConfig.FinalReward
		local complete = IndexRewardConfig.finalComplete(data)
		local claimed = data.IndexRewards and data.IndexRewards[IndexRewardConfig.FinalKey]
		claimTarget = IndexRewardConfig.FinalKey
		if claimed then
			claimButton.Text = "Index reward claimed"
			UIKit.setEnabled(claimButton, false)
		elseif complete then
			claimButton.Text = string.format("Claim %s gems + %d tokens", Format.short(final.Gems), final.Tokens)
			UIKit.setEnabled(claimButton, true)
		else
			claimButton.Text = string.format("Finish the Index: %s gems", Format.short(final.Gems))
			UIKit.setEnabled(claimButton, false)
		end

		clearGrid()
		UIKit.list(grid, Enum.FillDirection.Vertical, 6)
		UIKit.padding(grid, 4)
		local order = 0
		local function row(icon: string, title: string, subtitle: string, fraction: number, done: boolean, color: Color3)
			order += 1
			local frame = UIKit.card(grid, { Size = UDim2.new(1, -12, 0, 54), BackgroundColor3 = if done then C.Card else C.Cream, LayoutOrder = order })
			local frameStroke = frame:FindFirstChildOfClass("UIStroke") :: UIStroke
			frameStroke.Color = if done then color else C.Line
			frameStroke.Thickness = if done then 2.5 else 1.5
			UIKit.icon(frame, icon, 36, { Position = UDim2.new(0, 14, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
			UIKit.label(frame, { Position = UDim2.fromOffset(58, 5), Size = UDim2.new(1, -240, 0, 22), Text = title, TextSize = 17, Font = UIKit.Fonts.Title, TextColor3 = C.Ink })
			UIKit.label(frame, { Position = UDim2.fromOffset(58, 28), Size = UDim2.new(1, -240, 0, 20), Text = subtitle, TextSize = 13, TextColor3 = C.Muted })
			local progress = UIKit.progress(frame, { Size = UDim2.fromOffset(150, 20), Position = UDim2.new(1, -12, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Color = if done then C.Green else color })
			progress.Set(math.clamp(fraction, 0, 1), if done then "Done" else string.format("%d%%", math.floor(fraction * 100)))
		end

		for _, milestone in IndexRewardConfig.Milestones do
			local definition = RarityConfig.ById[milestone.Rarity]
			local have = IndexRewardConfig.found(data, milestone.Rarity)
			local done = have >= milestone.Count
			row(
				if milestone.Stat == "Coins" then "Coins" else "Luck",
				string.format("Find %d %s hamsters", milestone.Count, definition.Name),
				string.format("+%d%% %s forever  (%d/%d)", math.floor(milestone.Percent * 100 + 0.5), milestone.Stat, math.min(have, milestone.Count), milestone.Count),
				have / milestone.Count,
				done,
				UIKit.rarityColor(definition)
			)
		end
		for _, rarityId in RarityConfig.Order do
			if #HamsterDatabase.Spawnable[rarityId] > 0 then
				local definition = RarityConfig.ById[rarityId]
				local have = 0
				for _, species in HamsterDatabase.Spawnable[rarityId] do
					if data.Index[species.Id] then
						have += 1
					end
				end
				local total = #HamsterDatabase.Spawnable[rarityId]
				row("Star", string.format("Title: %s Collector", definition.Name), string.format("Complete the %s set (%d/%d)", definition.Name, have, total), have / total, have >= total, UIKit.rarityColor(definition))
			end
		end
		local unique = EconomyMath.uniqueCount(data)
		row("Trophy", "Title: " .. final.Title, string.format("Complete the Index: +%d%% coins forever, %s gems, %d tokens", math.floor(final.CoinPercent * 100), Format.short(final.Gems), final.Tokens), unique / HamsterDatabase.Total, complete, C.Gold)
	end

	local function renderGroup()
		local data = DataController.Data
		if not data.Index then
			return
		end
		local entries = entriesFor(mode)
		local entry = entries[1]
		for _, candidate in entries do
			if candidate.Id == selected[mode] then
				entry = candidate
			end
		end
		headerStroke.Color = entry.Color
		headerTitle.Text = string.format('<font color="#%s">%s</font>', entry.Color:ToHex(), entry.Name)
		headerIcon:Destroy()
		headerIcon = UIKit.icon(header, if mode == "Rarity" then "Star" else entry.Icon, 40, { Position = UDim2.new(0, 10, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
		claimTarget = nil

		if mode == "Rarity" and entry.Rarity then
			local definition = RarityConfig.ById[entry.Rarity]
			headerInfo.Text = string.format("Speed %g studs/s  -  %s  -  from %s, earns %s/s%s", definition.Speed, definition.Difficulty, Format.coins(definition.Price), Format.coins(definition.Income), if definition.MinRebirth > 0 then "  -  spawns from Rebirth " .. definition.MinRebirth else "")
			local spawnableTotal = #HamsterDatabase.Spawnable[entry.Rarity]
			local spawnableHave = 0
			for _, species in HamsterDatabase.ByRarity[entry.Rarity] do
				if data.Index[species.Id] and not species.Exclusive then
					spawnableHave += 1
				end
			end
			local complete = spawnableHave >= spawnableTotal and spawnableTotal > 0
			local claimed = data.IndexRewards and data.IndexRewards[entry.Rarity]
			claimTarget = entry.Rarity
			local reward = definition.IndexReward
			if claimed then
				claimButton.Text = "Reward claimed"
				UIKit.setEnabled(claimButton, false)
			elseif complete then
				claimButton.Text = string.format("Claim %s gems", Format.short(reward.Gems))
				UIKit.setEnabled(claimButton, true)
			else
				claimButton.Text = string.format("%d/%d  -  %s gems", spawnableHave, spawnableTotal, Format.short(reward.Gems))
				UIKit.setEnabled(claimButton, false)
			end
		else
			local have, total = groupProgress(data, entry)
			headerInfo.Text = string.format("%s  -  %d/%d found", entry.Info, have, total)
			claimButton.Text = string.format("%d / %d", have, total)
			UIKit.setEnabled(claimButton, false)
		end

		clearGrid()
		UIKit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(160, 206),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, grid)
		UIKit.padding(grid, 4)

		for order, species in entry.Species do
			local definition = RarityConfig.ById[species.Rarity]
			local color = UIKit.rarityColor(definition)
			local found = data.Index[species.Id] == true
			local hiddenRarity = definition.Hidden
			local ownedCount = (data.Inventory or {})[species.Id] or 0
			local workingCount = 0
			for _, id in data.Equipped or {} do
				if id == species.Id then
					workingCount += 1
				end
			end
			local card = UIKit.card(grid, { LayoutOrder = order, BackgroundColor3 = if found then C.Card else C.Cream })
			local cardStroke = card:FindFirstChildOfClass("UIStroke") :: UIStroke
			cardStroke.Color = if found then UIKit.lighter(color, 0.15) else C.Line
			cardStroke.Thickness = if workingCount > 0 then 3.5 elseif found then 2.5 else 1.5

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
				Text = if found or not hiddenRarity then species.Name else "???",
				TextSize = 17,
				Font = UIKit.Fonts.Title,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextColor3 = if found then C.Ink else C.Muted,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			local incomeRow = UIKit.amount(card, "Coin", if found or not hiddenRarity then Format.coins(HamsterDatabase.income(species)) .. "/s" else "???", { Size = UDim2.fromOffset(110, 18), TextSize = 14, Color = C.GoldDark })
			incomeRow.Position = UDim2.new(0.5, -46, 0, 148)
			-- collection status: working on a wheel > owned > discovered before > missing
			local chipText, chipColor
			if workingCount > 0 then
				chipText, chipColor = if workingCount > 1 then string.format("Working x%d", workingCount) else "Working", C.Mint
			elseif ownedCount > 0 then
				chipText, chipColor = string.format("Owned x%d", ownedCount), C.Sky
			elseif found then
				chipText, chipColor = "Discovered", C.Purple
			else
				chipText, chipColor = "Missing", Color3.fromRGB(176, 160, 150)
			end
			if species.Exclusive and not found then
				chipText, chipColor = "Exclusive", Color3.fromRGB(160, 130, 200)
			end
			local chip = UIKit.chip(card, chipText, chipColor, UDim2.fromOffset(118, 22))
			chip.Position = UDim2.new(0.5, -59, 1, -30)

			-- click anywhere on the card to inspect it
			local click = UIKit.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 5 }, card)
			click.Activated:Connect(function()
				openInspect(species, found)
			end)
		end
	end

	local function render()
		if mode == "Rewards" then
			renderRewards()
		else
			renderGroup()
		end
	end

	local function buildList()
		for _, child in list:GetChildren() do
			if child:IsA("TextButton") then
				child:Destroy()
			end
		end
		tabButtons = {}
		if mode == "Rewards" then
			return
		end
		for order, entry in entriesFor(mode) do
			local button = UIKit.button(list, {
				Text = "",
				Size = UDim2.new(1, -8, 0, 44),
				Color = if entry.Id == selected[mode] then C.White else C.CreamDark,
				Corner = 12,
				LayoutOrder = order,
				Name = "Group_" .. entry.Id,
				OnClick = function()
					selected[mode] = entry.Id
					for id, tab in tabButtons do
						UIKit.setButtonColor(tab.Button, if id == entry.Id then C.White else C.CreamDark)
					end
					render()
				end,
			})
			local marker = UIKit.frame(button, { Size = UDim2.fromOffset(10, 28), Position = UDim2.fromOffset(8, 8), BackgroundColor3 = entry.Color })
			UIKit.corner(marker, 5)
			UIKit.label(button, {
				Position = UDim2.fromOffset(26, 0),
				Size = UDim2.new(1, -86, 1, 0),
				Text = entry.Name,
				TextSize = 16,
				Font = UIKit.Fonts.Title,
				TextColor3 = C.Ink,
				TextTruncate = Enum.TextTruncate.AtEnd,
			})
			local count = UIKit.label(button, {
				Position = UDim2.new(1, -62, 0, 0),
				Size = UDim2.fromOffset(54, 44),
				Text = "0/0",
				TextSize = 14,
				TextColor3 = C.Muted,
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			tabButtons[entry.Id] = { Button = button, Count = count }
		end
	end

	local function setMode(newMode: string)
		mode = newMode
		for id, button in modeButtons do
			UIKit.setButtonColor(button, if id == newMode then C.Sky else C.CreamDark)
			button.TextColor3 = if id == newMode then C.White else C.Ink
		end
		list.Visible = newMode ~= "Rewards"
		inspect.Visible = false
		buildList()
		refreshSummary()
		render()
	end

	-- mode buttons (two rows)
	UIKit.list(modeRow, Enum.FillDirection.Horizontal, 4)
	local modeLayout = modeRow:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	modeLayout.Wraps = true
	for order, id in MODES do
		modeButtons[id] = UIKit.button(modeRow, {
			Text = MODE_LABELS[id],
			-- 3 per row in the 214px column: Rarity Theme World / Event Rewards
			Size = UDim2.fromOffset(if id == "Rewards" then 142 else 68, 28),
			Color = if id == mode then C.Sky else C.CreamDark,
			TextColor = if id == mode then C.White else C.Ink,
			TextSize = 13,
			Corner = 10,
			LayoutOrder = order,
			Name = "Mode_" .. id,
			OnClick = function()
				setMode(id)
			end,
		})
	end

	claimButton.Activated:Connect(function()
		if claimTarget and not claimButton:GetAttribute("Disabled") then
			local result = DataController.request("ClaimIndexReward", { Rarity = claimTarget })
			require(script.Parent.MainUI).toast(result.msg, if result.ok then "reward" else "error")
		end
	end)

	table.insert(panel.OnOpen, function()
		inspect.Visible = false
		buildList()
		refreshSummary()
		render()
	end)
	DataController.onChanged(function(keys)
		if panel.IsOpen and (keys.Index or keys.IndexRewards or keys.Derived or keys.Inventory or keys.Equipped) then
			refreshSummary()
			render()
		end
	end)

	buildList()
end

return IndexUI
