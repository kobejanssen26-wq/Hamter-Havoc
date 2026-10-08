--[[
	RebirthUI: shows the current and next multiplier, what it costs, what you get and what you lose.
	The button needs two taps (confirm) so nobody rebirths by accident.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local EconomyMath = require(Modules:WaitForChild("EconomyMath"))
local Format = require(Modules:WaitForChild("Format"))
local RebirthConfig = require(Modules:WaitForChild("RebirthConfig"))

local DataController = require(script.Parent.Parent.Controllers.DataController)
local UIKit = require(script.Parent.UIKit)

local RebirthUI = {}

local C = UIKit.Colors

function RebirthUI.start()
	local panel = UIKit.panel({ Name = "Rebirth", Title = "Rebirth", Icon = "🔥", Design = Vector2.new(820, 600), Accent = Color3.fromRGB(226, 110, 60) })
	local body = panel.Body

	local heading = UIKit.label(body, {
		Size = UDim2.new(1, 0, 0, 48),
		Font = UIKit.Fonts.Title,
		TextSize = 36,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "REBIRTH 1",
		TextColor3 = Color3.fromRGB(226, 110, 60),
	})

	-- multiplier cards
	local function multiplierCard(title: string, x: number): TextLabel
		local card = UIKit.frame(body, { Size = UDim2.fromOffset(240, 92), Position = UDim2.new(x, 0, 0, 56), BackgroundColor3 = C.Card })
		UIKit.corner(card, 18)
		UIKit.stroke(card, Color3.fromRGB(226, 208, 180), 3)
		UIKit.label(card, { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 8), Text = title, TextSize = 14, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Center })
		return UIKit.label(card, {
			Size = UDim2.new(1, 0, 0, 52),
			Position = UDim2.fromOffset(0, 30),
			Font = UIKit.Fonts.Title,
			TextSize = 42,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = "x1",
			TextColor3 = C.Ink,
		})
	end
	local currentLabel = multiplierCard("CURRENT MULTIPLIER", 0.5)
	currentLabel.Parent.Position = UDim2.new(0.5, -270, 0, 56)
	local nextLabel = multiplierCard("NEXT MULTIPLIER", 0.5)
	nextLabel.Parent.Position = UDim2.new(0.5, 30, 0, 56)
	nextLabel.TextColor3 = C.Green
	UIKit.label(body, { Size = UDim2.fromOffset(40, 92), Position = UDim2.new(0.5, -20, 0, 56), Text = "➜", TextSize = 36, TextXAlignment = Enum.TextXAlignment.Center, TextColor3 = C.Muted })

	-- requirement
	local requirement = UIKit.frame(body, { Size = UDim2.new(1, 0, 0, 74), Position = UDim2.fromOffset(0, 160), BackgroundColor3 = C.Card })
	UIKit.corner(requirement, 18)
	UIKit.stroke(requirement, Color3.fromRGB(226, 208, 180), 3)
	local requirementLabel = UIKit.label(requirement, {
		Size = UDim2.new(1, -20, 0, 26),
		Position = UDim2.fromOffset(10, 6),
		TextSize = 18,
		Font = UIKit.Fonts.Title,
		TextXAlignment = Enum.TextXAlignment.Center,
		Text = "",
	})
	local requirementBar = UIKit.progress(requirement, { Size = UDim2.new(1, -40, 0, 22), Position = UDim2.fromOffset(20, 40), Color = C.Gold })

	-- rewards / losses
	local rewardsCard = UIKit.frame(body, { Size = UDim2.new(0.5, -8, 0, 168), Position = UDim2.fromOffset(0, 246), BackgroundColor3 = Color3.fromRGB(238, 250, 240) })
	UIKit.corner(rewardsCard, 18)
	UIKit.stroke(rewardsCard, C.Green, 3)
	local rewardsLabel = UIKit.label(rewardsCard, {
		Size = UDim2.new(1, -24, 1, -16),
		Position = UDim2.fromOffset(14, 8),
		TextSize = 15,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = "",
	})
	local lossCard = UIKit.frame(body, { Size = UDim2.new(0.5, -8, 0, 168), Position = UDim2.new(0.5, 8, 0, 246), BackgroundColor3 = Color3.fromRGB(253, 240, 236) })
	UIKit.corner(lossCard, 18)
	UIKit.stroke(lossCard, C.Red, 3)
	UIKit.label(lossCard, {
		Size = UDim2.new(1, -24, 1, -16),
		Position = UDim2.fromOffset(14, 8),
		TextSize = 15,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
		Text = "<b>You will lose</b>\n• all coins (you restart with a few)\n• coin upgrades\n• hamsters in your chest and on the shelf\n\n<b>You keep</b>\n• the Hamster Index + its bonus\n• gems, tokens, token upgrades\n• quests, achievements, cosmetics",
	})

	local confirming = false
	local button
	button = UIKit.button(body, {
		Text = "REBIRTH",
		Size = UDim2.fromOffset(320, 64),
		Position = UDim2.new(0.5, 0, 1, -8),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = Color3.fromRGB(226, 110, 60),
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

	local function refresh()
		local data = DataController.Data
		if data.Rebirths == nil or not data.Upgrades then
			return
		end
		local rebirths = data.Rebirths
		local nextRebirth = rebirths + 1
		local boostLevel = data.Upgrades.RebirthBoost or 0
		heading.Text = if rebirths >= RebirthConfig.MaxRebirths then "MAX REBIRTH!" else "REBIRTH " .. nextRebirth
		currentLabel.Text = Format.multiplier(RebirthConfig.multiplier(rebirths, boostLevel))

		if rebirths >= RebirthConfig.MaxRebirths then
			nextLabel.Text = "MAX"
			requirementLabel.Text = "You are a true Hamster Legend!"
			requirementBar.Set(1, "")
			UIKit.setEnabled(button, false)
			rewardsLabel.Text = ""
			return
		end

		nextLabel.Text = Format.multiplier(RebirthConfig.multiplier(nextRebirth, boostLevel))
		local cost = RebirthConfig.cost(nextRebirth)
		local coins = DataController.coins()
		requirementLabel.Text = string.format("Required: 🪙 %s    (you have %s)", Format.short(cost), Format.short(coins))
		requirementBar.Set(coins / cost, string.format("%d%%", math.min(100, math.floor(coins / cost * 100))))
		UIKit.setEnabled(button, coins >= cost)

		local gemMultiplier = EconomyMath.gemMultiplier(data)
		local lines = {
			"<b>Rewards</b>",
			string.format("• +%s 💎 gems", Format.short(RebirthConfig.gemReward(nextRebirth) * gemMultiplier)),
			string.format("• +%d 🔥 rebirth token%s", RebirthConfig.tokenReward(nextRebirth), if RebirthConfig.tokenReward(nextRebirth) > 1 then "s" else ""),
		}
		for _, line in RebirthConfig.unlocks(nextRebirth) do
			table.insert(lines, "• " .. line)
		end
		rewardsLabel.Text = table.concat(lines, "\n")
	end

	panel.OnOpen[1] = refresh
	DataController.onChanged(function(keys)
		if panel.IsOpen and (keys.Rebirths or keys.Upgrades or keys.Derived) then
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
