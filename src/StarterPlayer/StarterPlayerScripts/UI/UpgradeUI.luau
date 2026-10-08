--[[
	UpgradeUI: buy upgrades with coins (reset on rebirth) or rebirth tokens (permanent).
	Opening it from a pedestal in your house scrolls to and highlights that upgrade.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Format = require(Modules:WaitForChild("Format"))
local UpgradeConfig = require(Modules:WaitForChild("UpgradeConfig"))

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local UIKit = require(script.Parent.UIKit)

local UpgradeUI = {}

local C = UIKit.Colors

function UpgradeUI.start()
	local panel = UIKit.panel({ Name = "Upgrades", Title = "Upgrades", Icon = "⬆️", Design = Vector2.new(860, 640), Accent = C.Green })
	local body = panel.Body

	-- stat summary
	local summary = UIKit.frame(body, { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = C.Card })
	UIKit.corner(summary, 14)
	UIKit.stroke(summary, Color3.fromRGB(226, 208, 180), 2)
	local summaryLabel = UIKit.label(summary, {
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
	})

	local scroll = UIKit.scroll(body, { Size = UDim2.new(1, 0, 1, -62), Position = UDim2.fromOffset(0, 60) })
	UIKit.list(scroll, Enum.FillDirection.Vertical, 8)
	UIKit.padding(scroll, 4)

	local rows: { [string]: { Frame: Frame, Level: TextLabel, Effect: TextLabel, Button: TextButton, Bar: any, Stroke: UIStroke } } = {}

	local function sectionHeader(text: string, order: number)
		UIKit.label(scroll, {
			Size = UDim2.new(1, -8, 0, 26),
			Text = text,
			Font = UIKit.Fonts.Title,
			TextSize = 18,
			TextColor3 = C.BrownLight,
			LayoutOrder = order,
		})
	end

	local function buildRow(id: string, order: number)
		local definition = UpgradeConfig.Definitions[id]
		local frame = UIKit.frame(scroll, { Size = UDim2.new(1, -8, 0, 92), LayoutOrder = order })
		UIKit.corner(frame, 16)
		local stroke = UIKit.stroke(frame, Color3.fromRGB(226, 208, 180), 3)

		local iconBox = UIKit.frame(frame, { Size = UDim2.fromOffset(68, 68), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = C.CreamDark })
		UIKit.corner(iconBox, 16)
		UIKit.label(iconBox, { Size = UDim2.fromScale(1, 1), Text = definition.Icon, TextSize = 38, TextXAlignment = Enum.TextXAlignment.Center })

		UIKit.label(frame, {
			Position = UDim2.fromOffset(92, 8),
			Size = UDim2.new(1, -330, 0, 24),
			Text = definition.Name,
			Font = UIKit.Fonts.Title,
			TextSize = 20,
		})
		local levelLabel = UIKit.label(frame, {
			Position = UDim2.new(1, -230, 0, 8),
			Size = UDim2.fromOffset(100, 24),
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
			Color = if definition.Currency == "Tokens" then C.Peach else C.Mint,
		})
		local button = UIKit.button(frame, {
			Text = "",
			Size = UDim2.fromOffset(150, 52),
			Position = UDim2.new(1, -12, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Color = if definition.Currency == "Tokens" then C.Peach else C.Green,
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
		rows[id] = { Frame = frame, Level = levelLabel, Effect = effectLabel, Button = button, Bar = bar, Stroke = stroke }
	end

	local order = 0
	sectionHeader("🪙 Coin upgrades  (reset when you rebirth)", order)
	for _, id in UpgradeConfig.Order do
		if UpgradeConfig.Definitions[id].Currency == "Coins" then
			order += 1
			buildRow(id, order)
		end
	end
	order += 1
	sectionHeader("🔥 Token upgrades  (permanent)", order)
	for _, id in UpgradeConfig.Order do
		if UpgradeConfig.Definitions[id].Currency == "Tokens" then
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
		summaryLabel.Text = string.format(
			"🍀 Luck x%.2f   🧲 Range %.1f   👟 Speed %.1f   🏠 Shelf %d   🪙 Income x%.2f",
			derived.Luck or 1,
			derived.CollectRange or 16,
			derived.WalkSpeed or 16,
			derived.Slots or 3,
			derived.IncomeMultiplier or 1
		)
		for id, row in rows do
			local definition = UpgradeConfig.Definitions[id]
			local level = data.Upgrades[id] or 0
			local cost = UpgradeConfig.cost(id, level)
			row.Level.Text = if cost then string.format("Lv %d / %d", level, definition.MaxLevel) else "MAX"
			row.Bar.Set(level / definition.MaxLevel)
			local current = UpgradeConfig.effectText(id, level)
			if cost then
				row.Effect.Text = string.format("%s  →  %s", if level == 0 then "none" else current, UpgradeConfig.effectText(id, level + 1))
				local balance = if definition.Currency == "Tokens" then DataController.tokens() else DataController.coins()
				local icon = if definition.Currency == "Tokens" then "🔥" else "🪙"
				row.Button.Text = string.format("%s %s", icon, Format.short(cost))
				UIKit.setEnabled(row.Button, balance >= cost)
			else
				row.Effect.Text = current
				row.Button.Text = "MAXED ✓"
				UIKit.setEnabled(row.Button, false)
			end
		end
	end

	local function focusRow(id: string?)
		for rowId, row in rows do
			row.Stroke.Color = if rowId == id then C.Gold else Color3.fromRGB(226, 208, 180)
		end
		if id and rows[id] then
			task.defer(function()
				scroll.CanvasPosition = Vector2.new(0, math.max(0, rows[id].Frame.AbsolutePosition.Y - scroll.AbsolutePosition.Y + scroll.CanvasPosition.Y - 8))
			end)
		end
	end

	panel.OnOpen[1] = function()
		refresh()
		focusRow(panel.Focus)
	end
	DataController.onChanged(function(keys)
		if panel.IsOpen and (keys.Upgrades or keys.Derived or keys.Boosts) then
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
