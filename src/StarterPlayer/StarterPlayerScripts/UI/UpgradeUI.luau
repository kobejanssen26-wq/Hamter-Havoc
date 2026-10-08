--[[
	UpgradeUI: buy upgrades with coins (reset on rebirth) or rebirth tokens (permanent).
	Advanced upgrades unlock with the Research Lab (Floor 3). Coin upgrade prices grow with rebirths.
	Opening it from a pedestal in your apartment scrolls to and highlights that upgrade.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local FloorConfig = require(Modules:WaitForChild("FloorConfig"))
local Format = require(Modules:WaitForChild("Format"))
local UpgradeConfig = require(Modules:WaitForChild("UpgradeConfig"))

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local UIKit = require(script.Parent.UIKit)

local UpgradeUI = {}

local C = UIKit.Colors

function UpgradeUI.start()
	local panel = UIKit.panel({ Name = "Upgrades", Title = "Upgrades", Icon = "Upgrade", Design = Vector2.new(860, 640), Accent = C.Green })
	local body = panel.Body

	-- stat summary
	local summary = UIKit.card(body, { Size = UDim2.new(1, 0, 0, 52) })
	UIKit.list(summary, Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center)
	local summaryLabels: { [string]: TextLabel } = {}
	for index, entry in { { "Luck", "Luck" }, { "Range", "Magnet" }, { "Speed", "Speed" }, { "Slots", "Hamster" }, { "Income", "Income" } } do
		local _, label = UIKit.amount(summary, entry[2], "", { Size = UDim2.fromOffset(130, 26), TextSize = 16, LayoutOrder = index })
		summaryLabels[entry[1]] = label
	end

	local scroll = UIKit.scroll(body, { Size = UDim2.new(1, 0, 1, -62), Position = UDim2.fromOffset(0, 60) })
	UIKit.list(scroll, Enum.FillDirection.Vertical, 8)
	UIKit.padding(scroll, 4)

	local rows: { [string]: { Frame: Frame, Level: TextLabel, Effect: TextLabel, Button: TextButton, Bar: any, Stroke: UIStroke, Lock: Frame } } = {}

	local function sectionHeader(text: string, order: number)
		UIKit.label(scroll, {
			Size = UDim2.new(1, -8, 0, 26),
			Text = text,
			Font = UIKit.Fonts.Title,
			TextSize = 18,
			TextColor3 = C.Muted,
			LayoutOrder = order,
		})
	end

	local function buildRow(id: string, order: number)
		local definition = UpgradeConfig.Definitions[id]
		local frame = UIKit.card(scroll, { Size = UDim2.new(1, -8, 0, 92), LayoutOrder = order })
		local stroke = frame:FindFirstChildOfClass("UIStroke") :: UIStroke

		local iconBox = UIKit.frame(frame, { Size = UDim2.fromOffset(68, 68), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = C.Cream })
		UIKit.corner(iconBox, 18)
		UIKit.icon(iconBox, definition.Icon, 48, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
		local lock = UIKit.frame(frame, { Name = "Lock", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Cream, BackgroundTransparency = 0.25, Visible = false, ZIndex = 5 })
		UIKit.corner(lock, 16)
		UIKit.icon(lock, "Lock", 34, { Position = UDim2.new(0.5, -110, 0.5, 0), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 6 })
		UIKit.label(lock, { Text = string.format("Unlocks with Floor %d (Research Lab)", definition.RequiresFloor or 1), Position = UDim2.new(0.5, -86, 0, 0), Size = UDim2.new(0.5, 80, 1, 0), Font = UIKit.Fonts.Title, TextSize = 18, ZIndex = 6 })

		UIKit.label(frame, {
			Position = UDim2.fromOffset(92, 8),
			Size = UDim2.new(1, -330, 0, 24),
			Text = definition.Name,
			Font = UIKit.Fonts.Title,
			TextSize = 20,
		})
		local levelLabel = UIKit.label(frame, {
			Position = UDim2.new(1, -176, 0, 2),
			Size = UDim2.fromOffset(140, 16),
			Text = "Lv 0",
			TextSize = 14,
			TextColor3 = C.Muted,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
		UIKit.label(frame, {
			Position = UDim2.fromOffset(92, 32),
			Size = UDim2.new(1, -330, 0, 20),
			Text = definition.Description,
			TextSize = 12,
			TextColor3 = C.Muted,
			TextWrapped = true,
		})
		local effectLabel = UIKit.label(frame, {
			Position = UDim2.fromOffset(92, 54),
			Size = UDim2.new(1, -330, 0, 18),
			Text = "",
			TextSize = 13,
			TextColor3 = C.Green,
		})
		local bar = UIKit.progress(frame, {
			Size = UDim2.new(1, -330, 0, 10),
			Position = UDim2.fromOffset(92, 74),
			Color = if definition.Currency == "Tokens" then C.Orange else C.Mint,
		})
		local button = UIKit.button(frame, {
			Text = "...", -- (non-empty: the icon goes left of the price that refresh() fills in)
			Size = UDim2.fromOffset(150, 52),
			Position = UDim2.new(1, -12, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Color = if definition.Currency == "Tokens" then C.Orange else C.Green,
			Icon = if definition.Currency == "Tokens" then "Token" else "Coin",
			IconSize = 28,
			TextSize = 18,
			Name = "Buy_" .. id,
			OnClick = function()
				local result = DataController.request("BuyUpgrade", { Id = id })
				if result.ok then
					AudioController.play("Upgrade")
					require(script.Parent.MainUI).toast(result.msg, "success")
				else
					require(script.Parent.MainUI).toast(result.msg, "error")
				end
			end,
		})
		rows[id] = { Frame = frame, Level = levelLabel, Effect = effectLabel, Button = button, Bar = bar, Stroke = stroke, Lock = lock }
	end

	local order = 0
	sectionHeader("Coin upgrades  (reset when you rebirth)", order)
	for _, id in UpgradeConfig.Order do
		local definition = UpgradeConfig.Definitions[id]
		if definition.Currency == "Coins" and not definition.RequiresFloor then
			order += 1
			buildRow(id, order)
		end
	end
	order += 1
	sectionHeader("Token upgrades  (permanent)", order)
	for _, id in UpgradeConfig.Order do
		local definition = UpgradeConfig.Definitions[id]
		if definition.Currency == "Tokens" and not definition.RequiresFloor then
			order += 1
			buildRow(id, order)
		end
	end
	order += 1
	sectionHeader("Advanced upgrades  (Research Lab, Floor 3)", order)
	for _, id in UpgradeConfig.Order do
		if UpgradeConfig.Definitions[id].RequiresFloor then
			order += 1
			buildRow(id, order)
		end
	end

	local function refresh()
		local data = DataController.Data
		if not data.Upgrades then
			return
		end
		local derived = DataController.derived()
		summaryLabels.Luck.Text = string.format("x%.2f", derived.Luck or 1)
		summaryLabels.Range.Text = string.format("%.1f", derived.CollectRange or 16)
		summaryLabels.Speed.Text = string.format("%.1f", derived.WalkSpeed or 16)
		summaryLabels.Slots.Text = string.format("%d slots", derived.Slots or 3)
		summaryLabels.Income.Text = Format.multiplier(derived.IncomeMultiplier or 1)
		local rebirths = data.Rebirths or 0
		local floors = FloorConfig.unlocked(rebirths)
		for id, row in rows do
			local definition = UpgradeConfig.Definitions[id]
			local level = data.Upgrades[id] or 0
			local cost = UpgradeConfig.cost(id, level, rebirths)
			row.Lock.Visible = not UpgradeConfig.available(id, floors)
			row.Level.Text = if cost then string.format("Lv %d / %d", level, definition.MaxLevel) else "MAX"
			row.Bar.Set(level / definition.MaxLevel)
			local current = UpgradeConfig.effectText(id, level)
			if cost then
				row.Effect.Text = string.format("%s  ->  %s", if level == 0 then "none" else current, UpgradeConfig.effectText(id, level + 1))
				local balance = if definition.Currency == "Tokens" then DataController.tokens() else DataController.coins()
				row.Button.Text = if definition.Currency == "Tokens" then Format.short(cost) else Format.coins(cost)
				UIKit.setEnabled(row.Button, balance >= cost and not row.Lock.Visible)
			else
				row.Effect.Text = current
				row.Button.Text = "MAXED"
				UIKit.setEnabled(row.Button, false)
			end
		end
	end

	local function focusRow(id: string?)
		for rowId, row in rows do
			row.Stroke.Color = if rowId == id then C.Gold else C.Line
			row.Stroke.Thickness = if rowId == id then 3 else 1.5
		end
		if id and rows[id] then
			task.defer(function()
				scroll.CanvasPosition = Vector2.new(0, math.max(0, rows[id].Frame.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y - 8))
			end)
		end
	end

	table.insert(panel.OnOpen, function()
		refresh()
		focusRow(panel.Focus)
	end)
	DataController.onChanged(function(keys)
		if panel.IsOpen and (keys.Upgrades or keys.Derived or keys.Boosts or keys.Rebirths) then
			refresh()
		end
	end)
	game.Players.LocalPlayer:GetAttributeChangedSignal("Coins"):Connect(function()
		if panel.IsOpen then
			refresh()
		end
	end)
end

return UpgradeUI
