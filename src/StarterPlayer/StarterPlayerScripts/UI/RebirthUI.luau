--[[
	RebirthUI: the prestige screen.
	  left   what you need (coins, hamsters, a rarity) with live progress, your hamster slots and your tower floors
	  right  everything this rebirth gives you, what resets and what you keep
	The button needs two taps (confirm) so nobody rebirths by accident.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local EconomyMath = require(Modules:WaitForChild("EconomyMath"))
local FloorConfig = require(Modules:WaitForChild("FloorConfig"))
local Format = require(Modules:WaitForChild("Format"))
local RarityConfig = require(Modules:WaitForChild("RarityConfig"))
local RebirthConfig = require(Modules:WaitForChild("RebirthConfig"))

local DataController = require(script.Parent.Parent.Controllers.DataController)
local UIKit = require(script.Parent.UIKit)

local RebirthUI = {}

local C = UIKit.Colors
local ORANGE = Color3.fromRGB(226, 110, 60)
local LINE = Color3.fromRGB(226, 208, 180)

local function card(parent: Instance, props: { Size: UDim2, Position: UDim2?, Color: Color3?, Stroke: Color3?, LayoutOrder: number? }): Frame
	local frame = UIKit.frame(parent, { Size = props.Size, Position = props.Position or UDim2.new(), BackgroundColor3 = props.Color or C.Card, LayoutOrder = props.LayoutOrder or 0 })
	UIKit.corner(frame, 18)
	UIKit.stroke(frame, props.Stroke or LINE, 2.5)
	return frame
end

local function heading(parent: Instance, text: string, y: number?): TextLabel
	return UIKit.label(parent, { Size = UDim2.new(1, -24, 0, 24), Position = UDim2.fromOffset(14, y or 8), Font = UIKit.Fonts.Title, TextSize = 17, TextColor3 = C.BrownDark, Text = text })
end

function RebirthUI.start()
	local panel = UIKit.panel({ Name = "Rebirth", Title = "Rebirth", Icon = "flame", Design = Vector2.new(920, 640), Accent = ORANGE })
	local body = panel.Body

	-----------------------------------------------------------------------
	-- left column
	-----------------------------------------------------------------------
	local left = UIKit.frame(body, { Size = UDim2.new(0, 440, 1, 0), BackgroundTransparency = 1 })

	local title = UIKit.label(left, { Size = UDim2.new(1, 0, 0, 40), Font = UIKit.Fonts.Title, TextSize = 34, TextColor3 = ORANGE, Text = "REBIRTH 1" })
	local multiplierLabel = UIKit.label(left, { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 40), TextSize = 16, TextColor3 = C.Muted, Text = "" })

	-- requirements
	local requirementsCard = card(left, { Size = UDim2.new(1, 0, 0, 196), Position = UDim2.fromOffset(0, 70) })
	heading(requirementsCard, "Requirements")
	local rows: { { Frame: Frame, Icon: Frame?, Label: TextLabel, Value: TextLabel, Bar: any } } = {}
	for index = 1, 3 do
		local row = UIKit.frame(requirementsCard, { Size = UDim2.new(1, -24, 0, 48), Position = UDim2.fromOffset(12, 36 + (index - 1) * 52), BackgroundColor3 = C.CreamDark, BackgroundTransparency = 0.35 })
		UIKit.corner(row, 12)
		local slot = UIKit.frame(row, { Size = UDim2.fromOffset(28, 28), Position = UDim2.fromOffset(8, 10), BackgroundTransparency = 1 })
		local label = UIKit.label(row, { Size = UDim2.new(1, -150, 0, 22), Position = UDim2.fromOffset(44, 4), TextSize = 15, Text = "" })
		local value = UIKit.label(row, { Size = UDim2.fromOffset(120, 22), Position = UDim2.new(1, -128, 0, 4), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Right, Font = UIKit.Fonts.Title, Text = "" })
		local bar = UIKit.progress(row, { Size = UDim2.new(1, -56, 0, 10), Position = UDim2.fromOffset(44, 31), Color = C.Gold })
		rows[index] = { Frame = row, Icon = slot, Label = label, Value = value, Bar = bar }
	end

	-- hamster slots
	local slotsCard = card(left, { Size = UDim2.new(1, 0, 0, 108), Position = UDim2.fromOffset(0, 276) })
	heading(slotsCard, "Hamster slots")
	local slotsText = UIKit.label(slotsCard, { Size = UDim2.new(1, -24, 0, 22), Position = UDim2.new(0, 14, 0, 8), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 15, Font = UIKit.Fonts.Title, TextColor3 = C.Green, Text = "" })
	local slotRow = UIKit.frame(slotsCard, { Size = UDim2.new(1, -24, 0, 54), Position = UDim2.fromOffset(12, 40), BackgroundTransparency = 1 })
	UIKit.list(slotRow, Enum.FillDirection.Horizontal, 4)
	local slotChips: { Frame } = {}

	-- tower floors
	local floorsCard = card(left, { Size = UDim2.new(1, 0, 0, 160), Position = UDim2.fromOffset(0, 394) })
	heading(floorsCard, "Your tower")
	local floorsHint = UIKit.label(floorsCard, { Size = UDim2.new(1, -24, 0, 22), Position = UDim2.new(0, 14, 0, 8), TextXAlignment = Enum.TextXAlignment.Right, TextSize = 14, TextColor3 = C.Muted, Text = "" })
	local floorCells: { { Frame: Frame, Stroke: UIStroke, Name: TextLabel, Sub: TextLabel, Icon: Frame } } = {}
	for index, floor in FloorConfig.Floors do
		local cell = UIKit.frame(floorsCard, { Size = UDim2.new(0.2, -6, 0, 100), Position = UDim2.new((index - 1) * 0.2, 4, 0, 40), BackgroundColor3 = C.CreamDark })
		UIKit.corner(cell, 14)
		local stroke = UIKit.stroke(cell, LINE, 2)
		local icon = UIKit.frame(cell, { Size = UDim2.fromOffset(34, 34), Position = UDim2.new(0.5, 0, 0, 8), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1 })
		local name = UIKit.label(cell, { Size = UDim2.new(1, -4, 0, 30), Position = UDim2.fromOffset(2, 46), Text = floor.Name, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, Font = UIKit.Fonts.Title })
		local sub = UIKit.label(cell, { Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -20), Text = "", TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Muted })
		floorCells[index] = { Frame = cell, Stroke = stroke, Name = name, Sub = sub, Icon = icon }
	end

	-----------------------------------------------------------------------
	-- right column
	-----------------------------------------------------------------------
	local right = UIKit.frame(body, { Size = UDim2.new(1, -456, 1, 0), Position = UDim2.new(0, 456, 0, 0), BackgroundTransparency = 1 })

	local rewardsCard = card(right, { Size = UDim2.new(1, 0, 0, 290), Color = Color3.fromRGB(240, 250, 242), Stroke = C.Green })
	heading(rewardsCard, "You get (permanent)")
	local rewardsScroll = UIKit.scroll(rewardsCard, { Size = UDim2.new(1, -16, 1, -42), Position = UDim2.fromOffset(8, 36) })
	UIKit.list(rewardsScroll, Enum.FillDirection.Vertical, 6)

	local lossCard = card(right, { Size = UDim2.new(1, 0, 0, 178), Position = UDim2.fromOffset(0, 300), Color = Color3.fromRGB(254, 244, 240), Stroke = C.Red })
	local lossLabel = UIKit.label(lossCard, { Size = UDim2.new(1, -24, 1, -16), Position = UDim2.fromOffset(12, 8), TextSize = 13, TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, Text = "" })
	do
		local lines = { "<b>Resets</b>" }
		for _, item in RebirthConfig.ResetList do
			table.insert(lines, "- " .. item)
		end
		table.insert(lines, "<b>You keep</b>")
		for _, item in RebirthConfig.KeepList do
			table.insert(lines, "- " .. item)
		end
		lossLabel.Text = table.concat(lines, "\n")
	end

	local confirming = false
	local button
	button = UIKit.button(right, {
		Text = "REBIRTH",
		Size = UDim2.new(1, 0, 0, 62),
		Position = UDim2.new(0, 0, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		Color = ORANGE,
		TextSize = 28,
		OnClick = function()
			if not confirming then
				confirming = true
				button.Text = "Tap again to confirm!"
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
	local function setRowIcon(slot: Frame, met: boolean)
		for _, child in slot:GetChildren() do
			child:Destroy()
		end
		UIKit.icon(slot, if met then "check" else "cross", { Size = UDim2.fromOffset(26, 26) })
	end

	local function refreshSlots(data: any, nextRebirth: number)
		local current = EconomyMath.slots(data)
		local earned = EconomyMath.slotsEarned(data)
		local capacity = FloorConfig.capacity(data.Rebirths)
		local shown = math.min(current + 2, 16)
		for _, chip in slotChips do
			chip:Destroy()
		end
		table.clear(slotChips)
		for index = 1, shown do
			local chip = UIKit.frame(slotRow, { Size = UDim2.fromOffset(24, 54), LayoutOrder = index, BackgroundTransparency = 1 })
			local owned = index <= current
			local isNext = index == current + 1
			local box = UIKit.frame(chip, { Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(0, 14), BackgroundColor3 = if owned then C.Gold else (if isNext then Color3.fromRGB(190, 240, 205) else C.CreamDark) })
			UIKit.corner(box, 8)
			UIKit.stroke(box, if owned then C.GoldDark else (if isNext then C.Green else LINE), 2)
			if owned then
				UIKit.icon(box, "hamster", { Size = UDim2.fromOffset(20, 20), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
			elseif isNext then
				UIKit.icon(box, "plus", { Size = UDim2.fromOffset(18, 18), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
			end
			table.insert(slotChips, chip)
		end
		slotsText.Text = string.format("%d  >  %d after rebirth", current, math.min(earned + 1, FloorConfig.capacity(nextRebirth)))
		if earned > capacity then
			slotsText.Text ..= string.format("  (floors hold %d)", capacity)
		end
	end

	local function refresh()
		local data = DataController.Data
		if data.Rebirths == nil or not data.Upgrades then
			return
		end
		data = table.clone(data)
		data.Coins = DataController.coins()
		local rebirths = data.Rebirths
		local nextRebirth = rebirths + 1
		local boostLevel = data.Upgrades.RebirthBoost or 0
		local maxed = rebirths >= RebirthConfig.MaxRebirths

		title.Text = if maxed then "MAX REBIRTH!" else "REBIRTH " .. nextRebirth
		multiplierLabel.Text = if maxed
			then string.format("Income %s - you are a true Hamster Legend!", Format.multiplier(RebirthConfig.multiplier(rebirths, boostLevel)))
			else string.format("Income %s  >  %s    Luck x%.2f  >  x%.2f", Format.multiplier(RebirthConfig.multiplier(rebirths, boostLevel)), Format.multiplier(RebirthConfig.multiplier(nextRebirth, boostLevel)), RebirthConfig.luckMultiplier(rebirths), RebirthConfig.luckMultiplier(nextRebirth))

		-- requirements
		if maxed then
			for _, row in rows do
				row.Frame.Visible = false
			end
			UIKit.setEnabled(button, false)
		else
			local allMet, list = RebirthConfig.check(data, nextRebirth)
			for index, row in rows do
				local entry = list[index]
				row.Frame.Visible = entry ~= nil
				if entry then
					setRowIcon(row.Icon :: Frame, entry.Met)
					local needText = if entry.Kind == "Coins" then Format.short(entry.Need) else tostring(entry.Need)
					local haveText = if entry.Kind == "Coins" then Format.short(entry.Have) else tostring(entry.Have)
					if entry.Kind == "Rarity" and entry.Rarity then
						local definition = RarityConfig.ById[entry.Rarity]
						local color = UIKit.rarityColor(definition)
						row.Label.Text = string.format('Own a <font color="#%s"><b>%s</b></font> hamster or better', color:ToHex(), if definition.Hidden then "???" else definition.Name)
						row.Value.Text = if entry.Met then "Done" else "Missing"
					elseif entry.Kind == "Hamsters" then
						row.Label.Text = "Hamsters in your collection"
						row.Value.Text = string.format("%s / %s", haveText, needText)
					else
						row.Label.Text = "Coins"
						row.Value.Text = string.format("%s / %s", haveText, needText)
					end
					row.Value.TextColor3 = if entry.Met then C.Green else C.Red
					row.Bar.Set(math.min(1, entry.Have / math.max(entry.Need, 1)), "")
				end
			end
			UIKit.setEnabled(button, allMet)
		end

		refreshSlots(data, nextRebirth)

		-- floors
		local built = FloorConfig.count(rebirths)
		local following = FloorConfig.nextFloor(rebirths)
		floorsHint.Text = if following then string.format("Next floor at rebirth %d", following.MinRebirth) else "Tower complete!"
		for index, floor in FloorConfig.Floors do
			local cell = floorCells[index]
			local isBuilt = index <= built
			local isNext = following ~= nil and following.Index == index
			cell.Frame.BackgroundColor3 = if isBuilt then Color3.fromRGB(255, 240, 200) else C.CreamDark
			cell.Stroke.Color = if isBuilt then C.Gold else (if isNext then C.Green else LINE)
			for _, child in cell.Icon:GetChildren() do
				child:Destroy()
			end
			UIKit.icon(cell.Icon, if isBuilt then "home" else "lock", { Size = UDim2.fromOffset(34, 34) })
			cell.Sub.Text = if isBuilt then "Built" else string.format("Rebirth %d", floor.MinRebirth)
			cell.Sub.TextColor3 = if isBuilt then C.GoldDark else (if isNext then C.Green else C.Muted)
		end

		-- rewards
		for _, child in rewardsScroll:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		if not maxed then
			local gemMultiplier = EconomyMath.gemMultiplier(data)
			local rewards = RebirthConfig.rewards(nextRebirth, boostLevel)
			for index, reward in rewards do
				local row = UIKit.frame(rewardsScroll, { Size = UDim2.new(1, -8, 0, 32), BackgroundTransparency = 1, LayoutOrder = index })
				UIKit.icon(row, reward.Icon, { Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(2, 3) })
				local text = reward.Text
				if reward.Icon == "gems" then
					text = string.format("+%s gems, +%d rebirth token%s", Format.short(RebirthConfig.gemReward(nextRebirth) * gemMultiplier), RebirthConfig.tokenReward(nextRebirth), if RebirthConfig.tokenReward(nextRebirth) > 1 then "s" else "")
				end
				UIKit.label(row, { Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(36, 0), TextSize = 14, TextWrapped = true, Text = text })
			end
		end
	end

	panel.OnOpen[1] = refresh
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
