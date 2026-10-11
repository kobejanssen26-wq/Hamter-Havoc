--[[
	EmoteUI: the radial emote wheel.
	  open     the emote key (default B, see EmoteController / InputConfig) or the Emotes button in the HUD rail (mobile)
	  choose   click / tap an emote, or press its number (1-8)
	  close    press the key again, Esc, click outside the wheel, or choose an emote
	Locked emotes stay visible (dimmed, with the rebirth they need) but cannot be played.
	The wheel is only as big as it needs to be; the world stays visible behind a light dimmer.
	The slots come from EmoteConfig (Modules/Content/Emotes), so adding an emote file adds a slot.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local EmoteConfig = require(Modules:WaitForChild("EmoteConfig"))

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local CursorController = require(script.Parent.Parent.Controllers.CursorController)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local EmoteController = require(script.Parent.Parent.Controllers.EmoteController)
local Icons = require(script.Parent.Icons)
local UIKit = require(script.Parent.UIKit)
local UIRegistry = require(script.Parent.UIRegistry)

local EmoteUI = {}

local C = UIKit.Colors
local NUMBER_KEYS = { One = 1, Two = 2, Three = 3, Four = 4, Five = 5, Six = 6, Seven = 7, Eight = 8 }
local RADIUS = 128
local SLOT = 70

function EmoteUI.start()
	local gui = UIKit.screenGui("EmoteWheel", { Layer = "Panels", Insets = "None", Enabled = false })

	local dim = UIKit.new("TextButton", { Name = "Dim", Text = "", AutoButtonColor = false, Modal = true, BackgroundColor3 = C.Dim, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), BorderSizePixel = 0 }, gui)
	local box = UIKit.responsive(gui, { Name = "Wheel", Design = Vector2.new(RADIUS * 2 + SLOT + 20, RADIUS * 2 + SLOT + 20), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Reference = Vector2.new(900, 600), Min = 0.55, Max = 1.2 })
	local group = UIKit.new("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, GroupTransparency = 1 }, box.Content)
	local animScale = UIKit.new("UIScale", { Scale = 0.85 }, group)
	local center = RADIUS + SLOT / 2 + 10

	-- hub in the middle: shows the hovered emote
	local hub = UIKit.frame(group, { Name = "Hub", Size = UDim2.fromOffset(120, 120), Position = UDim2.fromOffset(center, center), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = C.Cream })
	UIKit.corner(hub, 99)
	UIKit.stroke(hub, C.Line, 2)
	local hubIcon = UIKit.frame(hub, { Size = UDim2.fromOffset(40, 40), Position = UDim2.new(0.5, 0, 0, 22), AnchorPoint = Vector2.new(0.5, 0), BackgroundTransparency = 1 })
	local hubName = UIKit.label(hub, { Size = UDim2.new(1, -16, 0, 22), Position = UDim2.fromOffset(8, 66), Font = UIKit.Fonts.Title, TextSize = 15, TextColor3 = C.Ink, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, Text = "Emotes" })
	local hubHint = UIKit.label(hub, { Size = UDim2.new(1, -16, 0, 16), Position = UDim2.fromOffset(8, 88), Font = UIKit.Fonts.Soft, TextSize = 11, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Center, Text = "" })

	local slots: { { Button: TextButton, Def: any, Unlocked: boolean, Lock: TextLabel } } = {}
	local isOpen = false

	local function setHub(def: any?, unlocked: boolean?)
		for _, child in hubIcon:GetChildren() do
			child:Destroy()
		end
		if def then
			UIKit.icon(hubIcon, if Icons.has(def.Icon) then def.Icon else "star", { Size = UDim2.fromOffset(40, 40) })
			hubName.Text = def.DisplayName
			hubHint.Text = if unlocked then "Click to play" else EmoteConfig.lockText(def)
		else
			hubName.Text = "Emotes"
			hubHint.Text = EmoteController.keyName() .. " or Esc to close"
		end
	end

	local function close()
		if not isOpen then
			return
		end
		isOpen = false
		CursorController.hold("EmoteWheel", false)
		UIKit.tween(group, 0.12, { GroupTransparency = 1 })
		UIKit.tween(animScale, 0.12, { Scale = 0.9 })
		UIKit.tween(dim, 0.12, { BackgroundTransparency = 1 })
		AudioController.play("Close")
		task.delay(0.14, function()
			if not isOpen then
				gui.Enabled = false
			end
		end)
	end

	local function choose(index: number)
		local slot = slots[index]
		if not slot then
			return
		end
		if not slot.Unlocked then
			AudioController.play("Error")
			setHub(slot.Def, false)
			return
		end
		close()
		local ok, message = EmoteController.play(slot.Def.Id)
		if not ok then
			AudioController.play("Error")
			require(script.Parent.MainUI).toast(message, "error")
		end
	end

	local function build()
		for _, slot in slots do
			slot.Button:Destroy()
		end
		table.clear(slots)
		local rebirths = DataController.get("Rebirths") or 0
		local count = #EmoteConfig.List
		for index, def in EmoteConfig.List do
			local angle = -math.pi / 2 + (index - 1) * (2 * math.pi / math.max(count, 1))
			local unlocked = EmoteConfig.isUnlocked(def, rebirths)
			local button = UIKit.button(group, {
				Text = "",
				Size = UDim2.fromOffset(SLOT, SLOT),
				Position = UDim2.fromOffset(center + math.cos(angle) * RADIUS, center + math.sin(angle) * RADIUS),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Color = if unlocked then C.Card else C.CreamDark,
				Corner = 99,
				Name = "Emote_" .. def.Id,
				Silent = true,
				OnClick = function()
					choose(index)
				end,
			})
			local icon = UIKit.icon(button, if Icons.has(def.Icon) then def.Icon else "star", { Size = UDim2.fromOffset(34, 34), Position = UDim2.new(0.5, 0, 0.5, -4), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 3 })
			for _, part in icon:GetDescendants() do
				if part:IsA("Frame") and not unlocked then
					part.BackgroundTransparency = math.clamp(part.BackgroundTransparency + 0.6, 0, 0.95)
				end
			end
			UIKit.label(button, { Size = UDim2.fromOffset(16, 14), Position = UDim2.fromOffset(6, 4), Text = tostring(index), Font = UIKit.Fonts.Title, TextSize = 11, TextColor3 = C.Muted, ZIndex = 4 })
			local lock = UIKit.label(button, { Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -17), Text = if unlocked then "" else EmoteConfig.lockText(def), Font = UIKit.Fonts.Title, TextSize = 10, TextColor3 = C.Gold, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4 })
			button.MouseEnter:Connect(function()
				setHub(def, unlocked)
			end)
			button.MouseLeave:Connect(function()
				setHub(nil)
			end)
			slots[index] = { Button = button, Def = def, Unlocked = unlocked, Lock = lock }
		end
		setHub(nil)
	end

	local function open()
		if isOpen then
			return
		end
		UIKit.closeAll()
		isOpen = true
		build()
		CursorController.hold("EmoteWheel", true)
		gui.Enabled = true
		animScale.Scale = 0.85
		group.GroupTransparency = 1
		UIKit.tween(group, 0.16, { GroupTransparency = 0 })
		UIKit.tween(animScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Back)
		UIKit.tween(dim, 0.16, { BackgroundTransparency = 0.7 })
		AudioController.play("Open")
	end

	function EmoteUI.toggle()
		if isOpen then
			close()
		else
			open()
		end
	end
	function EmoteUI.isOpen(): boolean
		return isOpen
	end

	dim.Activated:Connect(close) -- click outside the wheel
	EmoteController.onToggle(EmoteUI.toggle)

	-- number keys choose while the wheel is open; Esc closes
	UserInputService.InputBegan:Connect(function(input, processed)
		if not isOpen or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if input.KeyCode == Enum.KeyCode.Escape then
			close()
			return
		end
		if processed then
			return
		end
		local number = NUMBER_KEYS[input.KeyCode.Name]
		if number then
			choose(number)
		end
	end)

	-- a panel opening elsewhere hides the wheel (never two big menus at once)
	task.spawn(function()
		while true do
			if isOpen then
				for _, panelName in { "Shop", "Inventory", "Quests", "Settings", "Index", "Rebirth", "Upgrades", "Daily", "Leaderboards" } do
					local panel = UIKit.getPanel(panelName)
					if panel and panel.IsOpen then
						close()
						break
					end
				end
			end
			task.wait(0.3)
		end
	end)

	UIRegistry.tryRegister({
		Id = "Emotes",
		Kind = "IconButton",
		Slot = "RightRail",
		Order = 50,
		Icon = "people",
		Tooltip = "Emotes (" .. EmoteController.keyName() .. ")",
		OnActivate = EmoteUI.toggle,
		Core = true,
	})
end

return EmoteUI
