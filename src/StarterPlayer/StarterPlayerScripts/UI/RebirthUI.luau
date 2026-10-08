--[[
	RebirthUI: the most important progression screen, so everything is spelled out:

	  left    current -> next rebirth, income multiplier, your apartment's floors (which one the next
	          rebirth builds), hamster slots, and exactly what resets and what stays
	  right   REQUIREMENTS (coins, secured hamsters, a hamster of a certain rarity) with progress bars,
	          REWARDS of the next rebirth (slot, income, luck, floor, rarities, security, keep hamsters)
	          and the REBIRTH button (tap twice to confirm)

	All numbers come from RebirthConfig / FloorConfig; the server re-checks everything.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local EconomyMath = require(Modules:WaitForChild("EconomyMath"))
local FloorConfig = require(Modules:WaitForChild("FloorConfig"))
local Format = require(Modules:WaitForChild("Format"))
local HamsterDatabase = require(Modules:WaitForChild("HamsterDatabase"))
local RarityConfig = require(Modules:WaitForChild("RarityConfig"))
local RebirthConfig = require(Modules:WaitForChild("RebirthConfig"))

local DataController = require(script.Parent.Parent.Controllers.DataController)
local UIKit = require(script.Parent.UIKit)

local RebirthUI = {}

local C = UIKit.Colors
local ACCENT = C.Orange

local REWARD_ICONS = {
	Slot = "Hamster",
	Income = "Income",
	Luck = "Luck",
	Floor = "Floor",
	Rarity = "Sparkle",
	Security = "Shield",
	Keep = "Heart",
	Milestone = "Trophy",
	Gems = "Gem",
}

local function rarityOf(speciesId: string): string?
	local species = HamsterDatabase.ById[speciesId]
	return species and species.Rarity
end

local function sectionTitle(parent: Instance, text: string, y: number, x: number?): TextLabel
	return UIKit.label(parent, {
		Text = text,
		Position = UDim2.fromOffset(x or 16, y),
		Size = UDim2.new(1, -32, 0, 22),
		Font = UIKit.Fonts.Title,
		TextSize = 17,
		TextColor3 = C.Muted,
	})
end

function RebirthUI.start()
	local panel = UIKit.panel({ Name = "Rebirth", Title = "Rebirth", Icon = "Rebirth", Design = Vector2.new(900, 690), Accent = ACCENT })
	local body = panel.Body

	local left = UIKit.frame(body, { Size = UDim2.new(0, 352, 1, 0), BackgroundTransparency = 1 })
	local right = UIKit.frame(body, { Size = UDim2.new(1, -368, 1, 0), Position = UDim2.fromOffset(368, 0), BackgroundTransparency = 1 })

	-----------------------------------------------------------------------
	-- left: current -> next
	-----------------------------------------------------------------------
	local hero = UIKit.card(left, { Size = UDim2.new(1, 0, 0, 104) })
	local function stat(x: number, title: string): TextLabel
		UIKit.label(hero, { Text = title, Position = UDim2.new(x, -60, 0, 12), Size = UDim2.fromOffset(120, 18), TextSize = 12, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Center })
		return UIKit.label(hero, { Text = "0", Position = UDim2.new(x, -60, 0, 32), Size = UDim2.fromOffset(120, 56), Font = UIKit.Fonts.Title, TextSize = 50, TextXAlignment = Enum.TextXAlignment.Center })
	end
	local currentLabel = stat(0.22, "CURRENT REBIRTH")
	local nextLabel = stat(0.78, "NEXT REBIRTH")
	nextLabel.TextColor3 = ACCENT
	UIKit.icon(hero, "Rebirth", 54, { Position = UDim2.fromScale(0.5, 0.55), AnchorPoint = Vector2.new(0.5, 0.5) })

	local multiplier = UIKit.card(left, { Size = UDim2.new(1, 0, 0, 62), Position = UDim2.fromOffset(0, 114) })
	UIKit.icon(multiplier, "Income", 38, { Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
	UIKit.label(multiplier, { Text = "Income multiplier", Position = UDim2.fromOffset(58, 8), Size = UDim2.fromOffset(200, 18), TextSize = 13, TextColor3 = C.Muted })
	local multiplierLabel = UIKit.label(multiplier, { Text = "x1", Position = UDim2.fromOffset(58, 26), Size = UDim2.new(1, -70, 0, 28), Font = UIKit.Fonts.Title, TextSize = 24 })

	-- your apartment: one bar per floor, the floor the next rebirth unlocks is highlighted
	local building = UIKit.card(left, { Size = UDim2.new(1, 0, 0, 236), Position = UDim2.fromOffset(0, 186) })
	sectionTitle(building, "YOUR APARTMENT", 10)
	local floorRows: { [number]: { Frame: Frame, Label: TextLabel, Detail: TextLabel } } = {}
	for index = FloorConfig.Count, 1, -1 do
		local floor = FloorConfig.Floors[index]
		local y = 38 + (FloorConfig.Count - index) * 30
		local row = UIKit.frame(building, { Size = UDim2.new(1, -32, 0, 26), Position = UDim2.fromOffset(16, y), BackgroundColor3 = C.CreamDark })
		UIKit.corner(row, 8)
		local label = UIKit.label(row, { Text = string.format("%d  %s", floor.Index, floor.Name), Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.6, 0, 1, 0), TextSize = 13 })
		local detail = UIKit.label(row, { Text = "", Position = UDim2.new(0.55, 0, 0, 0), Size = UDim2.new(0.45, -10, 1, 0), TextSize = 12, TextXAlignment = Enum.TextXAlignment.Right })
		floorRows[index] = { Frame = row, Label = label, Detail = detail }
	end
	local slotsTitle = UIKit.label(building, { Text = "", Position = UDim2.fromOffset(16, 194), Size = UDim2.new(1, -32, 0, 18), TextSize = 13 })
	local slotDots = UIKit.frame(building, { Size = UDim2.new(1, -32, 0, 12), Position = UDim2.fromOffset(16, 214), BackgroundTransparency = 1 })
	UIKit.list(slotDots, Enum.FillDirection.Horizontal, 3)

	-- what resets / what stays
	local resets = UIKit.card(left, { Size = UDim2.new(1, 0, 0, 168), Position = UDim2.fromOffset(0, 432) })
	sectionTitle(resets, "RESETS", 10)
	sectionTitle(resets, "YOU KEEP", 10, 160)
	for index, text in RebirthConfig.Resets do
		local y = 36 + (index - 1) * 24
		local dot = UIKit.frame(resets, { Size = UDim2.fromOffset(10, 10), Position = UDim2.fromOffset(16, y + 6), BackgroundColor3 = C.Red })
		UIKit.corner(dot, 99)
		UIKit.label(resets, { Text = text, Position = UDim2.fromOffset(32, y), Size = UDim2.fromOffset(124, 22), TextSize = 12, TextWrapped = true })
	end
	local keepText = UIKit.label(resets, { Text = "", Position = UDim2.fromOffset(16, 40 + #RebirthConfig.Resets * 24), Size = UDim2.fromOffset(136, 44), TextSize = 12, TextColor3 = C.Mint, TextWrapped = true, Font = UIKit.Fonts.Title })
	for index, text in RebirthConfig.Keeps do
		local y = 36 + (index - 1) * 20
		UIKit.icon(resets, "Check", 15, { Position = UDim2.fromOffset(160, y + 2) })
		UIKit.label(resets, { Text = text, Position = UDim2.fromOffset(180, y), Size = UDim2.fromOffset(160, 20), TextSize = 12 })
	end

	-----------------------------------------------------------------------
	-- right: requirements
	-----------------------------------------------------------------------
	local requirements = UIKit.card(right, { Size = UDim2.new(1, 0, 0, 186) })
	sectionTitle(requirements, "REQUIREMENTS", 10)
	type RequirementRow = { Label: TextLabel, Bar: any, Done: GuiObject }
	local requirementRows: { [string]: RequirementRow } = {}
	for index, kind in { "Coins", "Hamsters", "Rarity" } do
		local y = 40 + (index - 1) * 48
		UIKit.icon(requirements, if kind == "Coins" then "Coin" elseif kind == "Hamsters" then "Hamster" else "Star", 34, { Position = UDim2.fromOffset(16, y) })
		local label = UIKit.label(requirements, { Text = "", Position = UDim2.fromOffset(60, y - 2), Size = UDim2.new(1, -110, 0, 20), TextSize = 14 })
		local bar = UIKit.progress(requirements, { Size = UDim2.new(1, -116, 0, 14), Position = UDim2.fromOffset(60, y + 21), Color = ACCENT })
		local done = UIKit.icon(requirements, "Check", 28, { Position = UDim2.new(1, -44, 0, y + 3) })
		requirementRows[kind] = { Label = label, Bar = bar, Done = done }
	end

	-- rewards
	local rewards = UIKit.card(right, { Size = UDim2.new(1, 0, 0, 316), Position = UDim2.fromOffset(0, 196) })
	sectionTitle(rewards, "REWARDS", 10)
	local rewardList = UIKit.scroll(rewards, { Size = UDim2.new(1, -24, 1, -44), Position = UDim2.fromOffset(12, 38) })
	UIKit.list(rewardList, Enum.FillDirection.Vertical, 6)

	-- the button
	local confirming = false
	local button: TextButton
	button = UIKit.button(right, {
		Text = "REBIRTH",
		Icon = "Rebirth",
		IconSize = 34,
		Size = UDim2.new(1, 0, 0, 64),
		Position = UDim2.new(0, 0, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		Color = ACCENT,
		TextSize = 28,
		Corner = 20,
		OnClick = function()
			if not confirming then
				confirming = true
				button.Text = "Tap again to confirm"
				task.delay(3, function()
					if confirming then
						confirming = false
						button.Text = "REBIRTH"
					end
				end)
				return
			end
			confirming = false
			button.Text = "REBIRTH"
			local result = DataController.request("Rebirth")
			if result.ok then
				panel:Close()
			else
				require(script.Parent.MainUI).toast(result.msg, "error")
			end
		end,
	})

	-----------------------------------------------------------------------
	-- refresh
	-----------------------------------------------------------------------
	local function refresh()
		local data = DataController.Data
		if data.Rebirths == nil or not data.Upgrades or not data.Inventory then
			return
		end
		local rebirths = data.Rebirths
		local nextRebirth = rebirths + 1
		local maxed = rebirths >= RebirthConfig.MaxRebirths
		local boostLevel = data.Upgrades.RebirthBoost or 0
		currentLabel.Text = tostring(rebirths)
		nextLabel.Text = if maxed then "MAX" else tostring(nextRebirth)
		local current = RebirthConfig.multiplier(rebirths, boostLevel)
		multiplierLabel.Text = if maxed
			then Format.multiplier(current)
			else string.format('%s  <font color="#%s">->  %s</font>', Format.multiplier(current), ACCENT:ToHex(), Format.multiplier(RebirthConfig.multiplier(nextRebirth, boostLevel)))

		-- floors
		local floorsNow = FloorConfig.unlocked(rebirths)
		local floorsNext = FloorConfig.unlocked(nextRebirth)
		for index, row in floorRows do
			local floor = FloorConfig.Floors[index]
			local unlocked = index <= floorsNow
			local isNext = not unlocked and index <= floorsNext
			row.Frame.BackgroundColor3 = if unlocked then UIKit.lighter(floor.Accent, 0.55) elseif isNext then UIKit.lighter(ACCENT, 0.6) else C.CreamDark
			row.Label.TextColor3 = if unlocked or isNext then C.Ink else C.Muted
			if unlocked then
				row.Detail.Text = if floor.WheelBonus > 0 then string.format("+%d%% wheels", math.floor(floor.WheelBonus * 100 + 0.5)) else "unlocked"
				row.Detail.TextColor3 = C.Ink
			elseif isNext then
				row.Detail.Text = "NEXT REBIRTH!"
				row.Detail.TextColor3 = ACCENT
			else
				row.Detail.Text = "Rebirth " .. floor.MinRebirth
				row.Detail.TextColor3 = C.Muted
			end
		end

		-- slots (Extra Storage resets on rebirth, passes stay)
		local slotsNow = EconomyMath.slots(data)
		local slotsNext = EconomyMath.slots({ Rebirths = nextRebirth, Upgrades = {}, Passes = data.Passes or {} })
		slotsTitle.Text = if maxed
			then string.format("Hamster slots: %d", slotsNow)
			else string.format('Hamster slots: %d  <font color="#%s">->  %d after rebirth</font>', slotsNow, ACCENT:ToHex(), slotsNext)
		for _, child in slotDots:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		local capacity = FloorConfig.capacity(if maxed then rebirths else nextRebirth)
		for index = 1, capacity do
			local filled = index <= math.min(slotsNow, slotsNext)
			local added = not filled and index <= slotsNext
			local dot = UIKit.frame(slotDots, {
				Size = UDim2.fromOffset(8, 12),
				BackgroundColor3 = if filled then C.Mint elseif added then ACCENT else C.CreamDark,
				LayoutOrder = index,
			})
			UIKit.corner(dot, 3)
		end

		-- requirements
		local checks, ready = RebirthConfig.check({ Rebirths = rebirths, Coins = DataController.coins(), Inventory = data.Inventory }, rarityOf)
		for _, check in checks do
			local row = requirementRows[check.Kind]
			if row then
				local fraction = if check.Need > 0 then check.Have / check.Need else 1
				if check.Kind == "Coins" then
					row.Label.Text = string.format('<b>%s</b> coins  <font color="#%s">(you have %s)</font>', Format.coins(check.Need), C.Muted:ToHex(), Format.coins(check.Have))
					row.Bar.Set(fraction, string.format("%d%%", math.min(100, math.floor(fraction * 100))))
				elseif check.Kind == "Hamsters" then
					row.Label.Text = string.format("<b>%d</b> secured hamsters", check.Need)
					row.Bar.Set(fraction, string.format("%d / %d", math.min(check.Have, check.Need), check.Need))
				else
					local rarity = RarityConfig.ById[RarityConfig.Order[check.Need]]
					row.Label.Text = string.format('Own a <font color="#%s"><b>%s</b></font> hamster (or rarer)', UIKit.rarityColor(rarity):ToHex(), rarity.Name)
					row.Bar.Set(if check.Met then 1 else 0, if check.Met then "Done" else "Not yet")
				end
				row.Done.Visible = check.Met
			end
		end
		UIKit.setEnabled(button, ready and not maxed)

		-- rewards
		for _, child in rewardList:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		if maxed then
			local holder = UIKit.frame(rewardList, { Size = UDim2.new(1, 0, 0, 40), BackgroundTransparency = 1 })
			UIKit.label(holder, { Text = "You reached the highest rebirth. A true Hamster Tycoon!", Size = UDim2.fromScale(1, 1), TextSize = 15 })
		else
			for index, reward in RebirthConfig.rewards(nextRebirth) do
				local row = UIKit.frame(rewardList, {
					Size = UDim2.new(1, -8, 0, 34),
					BackgroundColor3 = if reward.Major then UIKit.lighter(ACCENT, 0.82) else C.Cream,
					LayoutOrder = index,
				})
				UIKit.corner(row, 10)
				UIKit.icon(row, REWARD_ICONS[reward.Kind] or "Star", 26, { Position = UDim2.new(0, 6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5) })
				UIKit.label(row, {
					Text = if reward.Major then "<b>" .. reward.Text .. "</b>" else reward.Text,
					Position = UDim2.fromOffset(40, 0),
					Size = UDim2.new(1, -46, 1, 0),
					TextSize = 14,
				})
			end
		end
		local keep = RebirthConfig.keepBest(nextRebirth)
		keepText.Text = if keep > 0 then string.format("+ your best %d hamster%s", keep, if keep > 1 then "s" else "") else "From Rebirth 4 you keep your best hamster"
	end

	table.insert(panel.OnOpen, refresh)
	DataController.onChanged(function(keys)
		if panel.IsOpen and (keys.Rebirths or keys.Upgrades or keys.Derived or keys.Inventory) then
			refresh()
		end
	end)
	game.Players.LocalPlayer:GetAttributeChangedSignal("Coins"):Connect(function()
		if panel.IsOpen then
			refresh()
		end
	end)
end

return RebirthUI
