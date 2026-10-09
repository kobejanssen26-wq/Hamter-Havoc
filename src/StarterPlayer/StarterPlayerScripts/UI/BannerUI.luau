--[[
	BannerUI: big centred banners for real base-security transitions. The SERVER sends "BaseOpen" / "BaseLocked"
	only when the gate genuinely switches (never on join / claim), so this module just animates what it is told.
	A new banner replaces the one on screen; the old one never lingers or stacks.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local UIKit = require(script.Parent.UIKit)

local BannerUI = {}

local C = UIKit.Colors
local player = Players.LocalPlayer

local BANNERS = {
	BaseOpen = { Text = "YOUR BASE IS NOW OPEN!", Sub = "Thieves can walk in - switch the gate back on at the panel.", Color = Color3.fromRGB(226, 98, 90), Icon = "lock" },
	BaseLocked = { Text = "YOUR BASE IS NOW LOCKED!", Sub = "Your hamsters are protected.", Color = Color3.fromRGB(92, 200, 128), Icon = "shield" },
}

local HOLD_SECONDS = 2.6

function BannerUI.start()
	local gui = UIKit.new("ScreenGui", {
		Name = "BannerUI",
		ResetOnSpawn = false,
		DisplayOrder = 20,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))

	local holder = UIKit.frame(gui, { Name = "Holder", Size = UDim2.fromOffset(760, 120), Position = UDim2.fromScale(0.5, 0.3), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false })
	local scale = UIKit.new("UIScale", { Scale = 1 }, holder)
	local panel = UIKit.new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Cream, BorderSizePixel = 0, GroupTransparency = 1 }, holder)
	UIKit.corner(panel, 12)
	local edge = UIKit.stroke(panel, C.Gold, 2)
	local accentBar = UIKit.frame(panel, { Size = UDim2.new(0, 8, 1, 0), BackgroundColor3 = C.Gold })
	local title = UIKit.label(panel, { Size = UDim2.new(1, -120, 0, 52), Position = UDim2.fromOffset(104, 14), Font = UIKit.Fonts.Big, TextSize = 38, TextColor3 = C.White, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false })
	local sub = UIKit.label(panel, { Size = UDim2.new(1, -120, 0, 24), Position = UDim2.fromOffset(106, 70), Font = UIKit.Fonts.Soft, TextSize = 15, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd })

	local function fitted(): number
		local camera = workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		return math.clamp(viewport.X * 0.9 / 760, 0.5, 1.15)
	end

	local generation = 0
	local function show(kind: string)
		local def = BANNERS[kind]
		if not def then
			return
		end
		generation += 1
		local mine = generation
		title.Text = def.Text
		title.TextColor3 = def.Color
		sub.Text = def.Sub
		edge.Color = def.Color
		accentBar.BackgroundColor3 = def.Color
		for _, child in panel:GetChildren() do
			if child.Name:sub(1, 5) == "Icon_" then
				child:Destroy()
			end
		end
		UIKit.icon(panel, def.Icon, { Size = UDim2.fromOffset(54, 54), Position = UDim2.fromOffset(34, 33) })
		-- enter: slide down + scale up + fade in
		holder.Visible = true
		holder.Position = UDim2.fromScale(0.5, 0.24)
		scale.Scale = fitted() * 0.8
		panel.GroupTransparency = 1
		UIKit.tween(holder, 0.35, { Position = UDim2.fromScale(0.5, 0.3) }, Enum.EasingStyle.Back)
		UIKit.tween(scale, 0.35, { Scale = fitted() }, Enum.EasingStyle.Back)
		UIKit.tween(panel, 0.25, { GroupTransparency = 0 })
		AudioController.play(if kind == "BaseOpen" then "Error" else "Reward")
		task.delay(HOLD_SECONDS, function()
			if mine ~= generation then
				return
			end
			-- exit: drift up + fade out
			UIKit.tween(holder, 0.4, { Position = UDim2.fromScale(0.5, 0.26) })
			UIKit.tween(panel, 0.4, { GroupTransparency = 1 })
			task.delay(0.45, function()
				if mine == generation then
					holder.Visible = false
				end
			end)
		end)
	end

	Remotes.event("Banner").OnClientEvent:Connect(show)
	BannerUI.show = show
end

return BannerUI
