--[[
	UIKit: the building blocks of the Hamster Plaza interface.
	Art direction: dark premium "workshop" look - near-black warm panels, gold borders and highlights, glowing green action buttons,
	red close buttons, condensed bold titles (Oswald), drawn icons. Everything is rounded and has a soft shadow.
	Windows are designed at a fixed pixel size and scaled to fit any screen (phone to 4K).
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local HamsterBuilder = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("HamsterBuilder"))

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local CursorController = require(script.Parent.Parent.Controllers.CursorController)
local Icons = require(script.Parent.Icons)

local UIKit = {}

local player = Players.LocalPlayer

UIKit.Colors = {
	-- surfaces (dark, warm)
	Cream = Color3.fromRGB(26, 20, 17), -- window background
	CreamDark = Color3.fromRGB(44, 34, 28), -- inset / inactive
	Card = Color3.fromRGB(56, 43, 34), -- cards and rows
	Brown = Color3.fromRGB(78, 56, 36), -- header base
	BrownDark = Color3.fromRGB(22, 14, 8), -- outlines, text on gold
	BrownLight = Color3.fromRGB(128, 94, 56),
	-- text
	Ink = Color3.fromRGB(248, 239, 224),
	Muted = Color3.fromRGB(178, 160, 140),
	-- borders
	Line = Color3.fromRGB(112, 82, 46),
	GoldLine = Color3.fromRGB(226, 170, 68),
	-- accents
	Peach = Color3.fromRGB(255, 152, 66),
	Pink = Color3.fromRGB(255, 108, 156),
	Mint = Color3.fromRGB(96, 222, 160),
	Sky = Color3.fromRGB(88, 168, 255),
	Gold = Color3.fromRGB(255, 205, 86),
	GoldDark = Color3.fromRGB(226, 166, 52),
	Green = Color3.fromRGB(74, 202, 96),
	Red = Color3.fromRGB(228, 66, 62),
	Purple = Color3.fromRGB(162, 112, 255),
	White = Color3.new(1, 1, 1),
	Dim = Color3.fromRGB(10, 7, 6),
}

UIKit.Fonts = {
	Title = Enum.Font.Oswald,
	Body = Enum.Font.GothamBold,
	Soft = Enum.Font.GothamMedium,
}

local C = UIKit.Colors

---------------------------------------------------------------------------
-- tiny helpers
---------------------------------------------------------------------------

function UIKit.new(className: string, props: { [string]: any }?, parent: Instance?): any
	local instance = Instance.new(className)
	if props then
		for key, value in props do
			(instance :: any)[key] = value
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UIKit.corner(parent: Instance, radius: number?): UICorner
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, parent)
end

function UIKit.stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?): UIStroke
	return UIKit.new("UIStroke", {
		Color = color,
		Thickness = thickness or 2,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

function UIKit.padding(parent: Instance, all: number, vertical: number?): UIPadding
	return UIKit.new("UIPadding", {
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, all),
		PaddingTop = UDim.new(0, vertical or all),
		PaddingBottom = UDim.new(0, vertical or all),
	}, parent)
end

function UIKit.list(parent: Instance, direction: Enum.FillDirection?, gap: number?, horizontal: Enum.HorizontalAlignment?, vertical: Enum.VerticalAlignment?): UIListLayout
	return UIKit.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 6),
		HorizontalAlignment = horizontal or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vertical or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, parent)
end

function UIKit.gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?): UIGradient
	return UIKit.new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90 }, parent)
end

function UIKit.tween(instance: Instance, duration: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

-- Drawn icon (no emoji): UIKit.icon(parent, "coin", { Size = UDim2.fromOffset(28, 28) })
function UIKit.icon(parent: Instance?, id: string, props: { Size: UDim2?, Position: UDim2?, AnchorPoint: Vector2?, Color: Color3?, ZIndex: number?, LayoutOrder: number?, Name: string? }?): Frame
	return Icons.create(parent, id, props)
end

-- A drawn icon followed by text on one line (replaces "coin 12K" emoji strings).
export type IconText = { Frame: Frame, Label: TextLabel, Icon: Frame?, Set: (text: string, iconId: string?) -> () }

function UIKit.iconText(parent: Instance?, props: { Icon: string?, Text: string?, Size: UDim2?, Position: UDim2?, AnchorPoint: Vector2?, TextSize: number?, TextColor: Color3?, Font: Enum.Font?, Align: Enum.HorizontalAlignment?, LayoutOrder: number?, ZIndex: number? }): IconText
	local textSize = props.TextSize or 16
	local frame = UIKit.frame(parent, {
		Size = props.Size or UDim2.fromOffset(120, textSize + 8),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
	})
	UIKit.list(frame, Enum.FillDirection.Horizontal, 5, props.Align or Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local label = UIKit.label(frame, {
		Size = UDim2.fromOffset(0, textSize + 6),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = props.Text or "",
		TextSize = textSize,
		TextColor3 = props.TextColor or C.Ink,
		Font = props.Font or UIKit.Fonts.Title,
		LayoutOrder = 2,
		ZIndex = props.ZIndex or 1,
	})
	local result: IconText = { Frame = frame, Label = label, Icon = nil, Set = nil :: any }
	local function setIcon(id: string?)
		if result.Icon then
			result.Icon:Destroy()
			result.Icon = nil
		end
		if id then
			result.Icon = UIKit.icon(frame, id, { Size = UDim2.fromOffset(textSize + 6, textSize + 6), LayoutOrder = 1, ZIndex = props.ZIndex })
		end
	end
	setIcon(props.Icon)
	result.Set = function(text: string, iconId: string?)
		label.Text = text
		if iconId then
			setIcon(iconId)
		end
	end
	return result
end

-- Puts "icon + text" in the middle of a button (the button's own Text stays empty).
function UIKit.setButtonContent(button: TextButton, iconId: string?, text: string, textColor: Color3?)
	button.Text = ""
	local content = button:FindFirstChild("Content") :: Frame?
	if content then
		content:Destroy()
	end
	local row = UIKit.iconText(button, { Icon = iconId, Text = text, Size = UDim2.fromScale(1, 1), TextSize = (button.TextSize or 18), TextColor = textColor or button.TextColor3, Align = Enum.HorizontalAlignment.Center, ZIndex = 3 })
	row.Frame.Name = "Content"
end

function UIKit.frame(parent: Instance?, props: { [string]: any }?): Frame
	local defaults: { [string]: any } = { BackgroundColor3 = C.Card, BorderSizePixel = 0 }
	if props then
		for key, value in props do
			defaults[key] = value
		end
	end
	return UIKit.new("Frame", defaults, parent)
end

function UIKit.label(parent: Instance?, props: { [string]: any }?): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = UIKit.Fonts.Body,
		TextColor3 = C.Ink,
		TextSize = 16,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
		BorderSizePixel = 0,
	}
	if props then
		for key, value in props do
			defaults[key] = value
		end
	end
	return UIKit.new("TextLabel", defaults, parent)
end

function UIKit.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Scale factor that fits a fixed design size into the current screen.
function UIKit.fitScale(designSize: Vector2, margin: number?): number
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local available = viewport * (margin or 0.94)
	return math.clamp(math.min(available.X / designSize.X, available.Y / designSize.Y), 0.35, 1.25)
end

---------------------------------------------------------------------------
-- buttons
---------------------------------------------------------------------------

export type ButtonProps = {
	Text: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	TextColor: Color3?,
	Font: Enum.Font?,
	TextSize: number?,
	OnClick: (() -> ())?,
	LayoutOrder: number?,
	Name: string?,
	Corner: number?,
	Silent: boolean?,
}

local function darker(color: Color3, factor: number): Color3
	return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end

-- Rounded button with hover (grow) and press (squash) animations and sounds.
function UIKit.button(parent: Instance?, props: ButtonProps): TextButton
	local color = props.Color or C.Peach
	local button = UIKit.new("TextButton", {
		Name = props.Name or "Button",
		AutoButtonColor = false,
		Text = props.Text or "",
		RichText = true,
		Font = props.Font or UIKit.Fonts.Title,
		TextSize = props.TextSize or 18,
		TextColor3 = props.TextColor or C.White,
		BackgroundColor3 = color,
		Size = props.Size or UDim2.fromOffset(120, 44),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		BorderSizePixel = 0,
	}, parent)
	UIKit.corner(button, props.Corner or 10)
	local stroke = UIKit.stroke(button, darker(color, 0.45), 2.5)
	-- soft top light: the gradient multiplies the button colour
	UIKit.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(176, 176, 176)), Rotation = 90 }, button)
	local scale = UIKit.new("UIScale", { Scale = 1 }, button)
	button:SetAttribute("BaseColor", color)

	local hovering = false
	button.MouseEnter:Connect(function()
		if button:GetAttribute("Disabled") then
			return
		end
		hovering = true
		UIKit.tween(scale, 0.12, { Scale = 1.06 })
		if not props.Silent then
			AudioController.play("Hover")
		end
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		UIKit.tween(scale, 0.12, { Scale = 1 })
	end)
	button.MouseButton1Down:Connect(function()
		if not button:GetAttribute("Disabled") then
			UIKit.tween(scale, 0.07, { Scale = 0.93 })
		end
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.tween(scale, 0.1, { Scale = if hovering then 1.06 else 1 }, Enum.EasingStyle.Back)
	end)
	button.Activated:Connect(function()
		if button:GetAttribute("Disabled") then
			AudioController.play("Error")
			return
		end
		if not props.Silent then
			AudioController.play("Click")
		end
		if props.OnClick then
			props.OnClick()
		end
	end)
	stroke.Name = "Edge"
	return button
end

function UIKit.setEnabled(button: TextButton, enabled: boolean)
	button:SetAttribute("Disabled", not enabled)
	local base = button:GetAttribute("BaseColor") or C.Peach
	button.BackgroundColor3 = if enabled then base else Color3.fromRGB(78, 68, 62)
	button.TextTransparency = if enabled then 0 else 0.35
	local edge = button:FindFirstChild("Edge") :: UIStroke?
	if edge then
		edge.Color = if enabled then darker(base, 0.45) else Color3.fromRGB(44, 36, 32)
	end
end

function UIKit.setButtonColor(button: TextButton, color: Color3)
	button:SetAttribute("BaseColor", color)
	if not button:GetAttribute("Disabled") then
		button.BackgroundColor3 = color
		local edge = button:FindFirstChild("Edge") :: UIStroke?
		if edge then
			edge.Color = darker(color, 0.45)
		end
	end
end

---------------------------------------------------------------------------
-- progress bar, toggle, slider, tabs, scroll
---------------------------------------------------------------------------

function UIKit.progress(parent: Instance, props: { Size: UDim2?, Position: UDim2?, Color: Color3?, Back: Color3?, AnchorPoint: Vector2?, LayoutOrder: number? }): { Frame: Frame, Fill: Frame, Label: TextLabel, Set: (fraction: number, text: string?) -> () }
	local frame = UIKit.frame(parent, {
		Size = props.Size or UDim2.new(1, 0, 0, 16),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = props.Back or Color3.fromRGB(20, 15, 12),
		LayoutOrder = props.LayoutOrder or 0,
	})
	UIKit.corner(frame, 99)
	UIKit.stroke(frame, C.Line, 1.5)
	local fill = UIKit.frame(frame, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = props.Color or C.Mint })
	UIKit.corner(fill, 99)
	UIKit.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 170, 170)), Rotation = 90 }, fill)
	local label = UIKit.label(frame, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 12,
		TextColor3 = C.White,
		Font = UIKit.Fonts.Body,
		ZIndex = 3,
	})
	local function set(fraction: number, text: string?)
		UIKit.tween(fill, 0.25, { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1) })
		label.Text = text or ""
	end
	return { Frame = frame, Fill = fill, Label = label, Set = set }
end

function UIKit.toggle(parent: Instance, props: { Value: boolean, OnChanged: (boolean) -> (), Position: UDim2?, AnchorPoint: Vector2?, LayoutOrder: number? }): { Button: TextButton, Set: (boolean) -> () }
	local value = props.Value
	local track = UIKit.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(62, 30),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		BackgroundColor3 = Color3.fromRGB(72, 62, 54),
		BorderSizePixel = 0,
	}, parent)
	UIKit.corner(track, 99)
	UIKit.stroke(track, C.Line, 2)
	local knob = UIKit.frame(track, { Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = C.White })
	UIKit.corner(knob, 99)
	local function render(animate: boolean)
		local target = if value then UDim2.fromOffset(36, 4) else UDim2.fromOffset(4, 4)
		local color = if value then C.Green else Color3.fromRGB(72, 62, 54)
		if animate then
			UIKit.tween(knob, 0.14, { Position = target }, Enum.EasingStyle.Back)
			UIKit.tween(track, 0.14, { BackgroundColor3 = color })
		else
			knob.Position = target
			track.BackgroundColor3 = color
		end
	end
	render(false)
	track.Activated:Connect(function()
		value = not value
		AudioController.play("Click")
		render(true)
		props.OnChanged(value)
	end)
	return {
		Button = track,
		Set = function(newValue: boolean)
			value = newValue
			render(true)
		end,
	}
end

function UIKit.slider(parent: Instance, props: { Min: number, Max: number, Value: number, OnChanged: (number) -> (), Size: UDim2?, Position: UDim2?, AnchorPoint: Vector2?, LayoutOrder: number? }): { Frame: Frame, Set: (number) -> () }
	local frame = UIKit.frame(parent, {
		Size = props.Size or UDim2.fromOffset(180, 14),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		BackgroundColor3 = Color3.fromRGB(20, 15, 12),
	})
	UIKit.corner(frame, 99)
	UIKit.stroke(frame, C.Line, 1.5)
	local fill = UIKit.frame(frame, { BackgroundColor3 = C.Gold, Size = UDim2.fromScale(0, 1) })
	UIKit.corner(fill, 99)
	local knob = UIKit.frame(frame, { Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = C.White, ZIndex = 3 })
	UIKit.corner(knob, 99)
	UIKit.stroke(knob, C.GoldDark, 2.5)
	local hit = UIKit.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 20, 0, 40), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) }, frame)

	local value = props.Value
	local function render()
		local fraction = (value - props.Min) / (props.Max - props.Min)
		fill.Size = UDim2.fromScale(fraction, 1)
		knob.Position = UDim2.fromScale(fraction, 0.5)
	end
	render()

	local dragging = false
	local function update(x: number)
		local fraction = math.clamp((x - frame.AbsolutePosition.X) / math.max(frame.AbsoluteSize.X, 1), 0, 1)
		value = props.Min + (props.Max - props.Min) * fraction
		render()
	end
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			update(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			update(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			AudioController.play("Click")
			props.OnChanged(value)
		end
	end)
	return {
		Frame = frame,
		Set = function(newValue: number)
			value = newValue
			render()
		end,
	}
end

export type TabDef = { Id: string, Text: string, Color: Color3? }

function UIKit.tabs(parent: Instance, defs: { TabDef }, onSelect: (string) -> (), options: { Size: UDim2?, Position: UDim2?, ButtonSize: UDim2?, Vertical: boolean? }?): { Frame: Frame, Select: (string) -> (), Buttons: { [string]: TextButton }, SetText: (string, string) -> () }
	local opts = options or {}
	local frame = UIKit.frame(parent, {
		Size = opts.Size or UDim2.new(1, 0, 0, 40),
		Position = opts.Position or UDim2.new(),
		BackgroundTransparency = 1,
	})
	UIKit.list(frame, if opts.Vertical then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal, 6)
	local buttons: { [string]: TextButton } = {}
	local function select(id: string, silent: boolean?)
		for tabId, button in buttons do
			if tabId == id then
				UIKit.setButtonColor(button, C.Gold)
				button.TextColor3 = C.BrownDark
			else
				UIKit.setButtonColor(button, C.CreamDark)
				button.TextColor3 = C.Ink
			end
		end
		if not silent then
			onSelect(id)
		end
	end

	for index, def in defs do
		local button = UIKit.button(frame, {
			Text = def.Text,
			Size = opts.ButtonSize or UDim2.fromOffset(110, 36),
			Color = C.CreamDark,
			TextColor = C.Ink,
			TextSize = 15,
			LayoutOrder = index,
			Name = "Tab_" .. def.Id,
			OnClick = function()
				select(def.Id)
			end,
		})
		button:SetAttribute("TabColor", def.Color or C.Brown)
		buttons[def.Id] = button
	end
	return {
		Frame = frame,
		Select = select,
		Buttons = buttons,
		SetText = function(id: string, text: string)
			if buttons[id] then
				buttons[id].Text = text
			end
		end,
	}
end

function UIKit.scroll(parent: Instance, props: { Size: UDim2?, Position: UDim2?, Direction: Enum.FillDirection?, Gap: number? }?): ScrollingFrame
	local opts = props or {}
	local scroll = UIKit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = opts.Size or UDim2.fromScale(1, 1),
		Position = opts.Position or UDim2.new(),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = C.GoldDark,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, parent)
	return scroll
end

---------------------------------------------------------------------------
-- hamster icons (ViewportFrame snapshots of the real 3D models)
---------------------------------------------------------------------------

function UIKit.hamsterIcon(parent: Instance, species: any, props: { Size: UDim2?, Position: UDim2?, Silhouette: boolean?, AnchorPoint: Vector2?, ZIndex: number?, Spin: boolean? }?): ViewportFrame
	local opts = props or {}
	local viewport = UIKit.new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = opts.Size or UDim2.fromOffset(110, 110),
		Position = opts.Position or UDim2.new(),
		AnchorPoint = opts.AnchorPoint or Vector2.zero,
		LightColor = Color3.fromRGB(255, 244, 224),
		Ambient = Color3.fromRGB(165, 155, 170),
		LightDirection = Vector3.new(-0.5, -1, 0.6),
		ImageColor3 = if opts.Silhouette then Color3.new(0, 0, 0) else Color3.new(1, 1, 1),
		ZIndex = opts.ZIndex or 1,
	}, parent)

	local model = HamsterBuilder.build(species, { LowDetail = true, Particles = false })
	model:PivotTo(CFrame.new(0, 0, 0))
	model.Parent = viewport
	local camera = Instance.new("Camera")
	local cameraCFrame, fieldOfView = HamsterBuilder.frameCamera(model, 32)
	camera.CFrame = cameraCFrame
	camera.FieldOfView = fieldOfView
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	if opts.Spin then
		local connection
		local angle = 0
		connection = RunService.RenderStepped:Connect(function(dt)
			if not viewport.Parent then
				connection:Disconnect()
				return
			end
			angle += dt * 0.9
			model:PivotTo(CFrame.Angles(0, math.sin(angle) * 0.7, 0))
		end)
	end
	return viewport
end

---------------------------------------------------------------------------
-- panels (windows)
---------------------------------------------------------------------------

export type Panel = {
	Name: string,
	Gui: ScreenGui,
	Window: GuiObject,
	Body: Frame,
	Title: TextLabel,
	IsOpen: boolean,
	Open: (self: Panel) -> (),
	Close: (self: Panel) -> (),
	Toggle: (self: Panel) -> (),
	OnOpen: { () -> () },
	OnClose: { () -> () },
	Focus: string?,
}

local panels: { [string]: Panel } = {}

local OPEN_SECONDS = 0.22
local CLOSE_SECONDS = 0.16

function UIKit.getPanel(name: string): Panel?
	return panels[name]
end

function UIKit.closeAll(except: string?)
	for name, panel in panels do
		if name ~= except and panel.IsOpen then
			panel:Close()
		end
	end
end

-- `Icon` is an Icons id ("book", "gear", ...), never an emoji.
local SUBTITLES = {
	Inventory = "Collect, equip and sell your hamsters",
	Index = "Discover every hamster and earn permanent bonuses",
	Rebirth = "Start over stronger - and grow your tower",
	Upgrades = "Make your hamsters and production stronger",
	Daily = "Come back every day for bigger rewards",
	Quests = "Complete goals to earn rewards",
	Shop = "Boosts, hamsters and exclusive items",
	Settings = "Sound, graphics and gameplay options",
	Codes = "Redeem a code for free rewards",
}

function UIKit.panel(options: { Name: string, Title: string, Subtitle: string?, Icon: string?, Design: Vector2?, Accent: Color3? }): Panel
	local requested = options.Design or Vector2.new(860, 560)
	local design = Vector2.new(requested.X, requested.Y + 14) -- the taller header needs a little more room
	local accent = options.Accent or C.Brown
	local playerGui = player:WaitForChild("PlayerGui")

	local gui = UIKit.new("ScreenGui", {
		Name = options.Name .. "UI",
		ResetOnSpawn = false,
		DisplayOrder = 10,
		Enabled = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)

	-- Modal = true frees the mouse in first person so the buttons can be clicked
	local dim = UIKit.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Modal = true,
		BackgroundColor3 = C.Dim,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
	}, gui)

	-- outer frame: design size + fit scale; inner parts: shadow + window (open/close animation)
	local outer = UIKit.frame(gui, {
		Size = UDim2.fromOffset(design.X, design.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	})
	local fit = UIKit.new("UIScale", { Scale = UIKit.fitScale(design) }, outer)
	local motion = UIKit.frame(outer, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local anim = UIKit.new("UIScale", { Scale = 0.9 }, motion)

	local shadow = UIKit.frame(motion, { Size = UDim2.new(1, 10, 1, 10), Position = UDim2.fromOffset(-5, 7), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.72 })
	UIKit.corner(shadow, 28)
	local window = UIKit.new("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Cream,
		BorderSizePixel = 0,
		GroupTransparency = 1,
	}, motion)
	UIKit.corner(window, 16)
	UIKit.gradient(window, Color3.fromRGB(38, 29, 24), Color3.fromRGB(18, 13, 11), 90)
	-- warm glow in the top corner (like light from a lamp)
	local glow = UIKit.frame(window, { Size = UDim2.fromOffset(520, 260), Position = UDim2.fromOffset(-120, -140), BackgroundColor3 = accent, BackgroundTransparency = 0.88 })
	UIKit.corner(glow, 260)
	-- gold frame
	local outline = UIKit.frame(motion, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20 })
	UIKit.corner(outline, 16)
	local outlineStroke = UIKit.stroke(outline, C.GoldLine, 3)
	UIKit.new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 214, 120)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 104, 48)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 190, 90)) }), Rotation = 60 }, outlineStroke)

	local header = UIKit.frame(window, { Size = UDim2.new(1, 0, 0, 78), BackgroundColor3 = C.Brown })
	UIKit.gradient(header, Color3.fromRGB(62, 46, 34), Color3.fromRGB(34, 25, 20), 90)
	UIKit.frame(header, { Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2), BackgroundColor3 = accent })
	local titleOffset = 24
	if options.Icon then
		local badge = UIKit.frame(header, { Size = UDim2.fromOffset(54, 54), Position = UDim2.fromOffset(14, 12), BackgroundColor3 = Color3.fromRGB(24, 18, 14) })
		UIKit.corner(badge, 12)
		UIKit.stroke(badge, C.GoldLine, 2)
		UIKit.icon(badge, options.Icon, { Size = UDim2.fromOffset(36, 36), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
		titleOffset = 80
	end
	local title = UIKit.label(header, {
		Size = UDim2.new(1, -titleOffset - 80, 0, 42),
		Position = UDim2.fromOffset(titleOffset, 8),
		Font = UIKit.Fonts.Title,
		TextSize = 36,
		TextColor3 = Color3.fromRGB(255, 244, 222),
		Text = string.upper(options.Title),
		ZIndex = 3,
	})
	UIKit.new("UIStroke", { Color = C.BrownDark, Thickness = 1.5 }, title)
	UIKit.label(header, {
		Size = UDim2.new(1, -titleOffset - 80, 0, 22),
		Position = UDim2.fromOffset(titleOffset, 48),
		Font = UIKit.Fonts.Soft,
		TextSize = 15,
		TextColor3 = C.Muted,
		Text = options.Subtitle or SUBTITLES[options.Name] or "",
		ZIndex = 3,
	})

	local body = UIKit.frame(window, {
		Size = UDim2.new(1, -28, 1, -94),
		Position = UDim2.fromOffset(14, 86),
		BackgroundTransparency = 1,
	})

	local panel: Panel = {
		Name = options.Name,
		Gui = gui,
		Window = window,
		Body = body,
		Title = title,
		IsOpen = false,
		Open = nil :: any,
		Close = nil :: any,
		Toggle = nil :: any,
		OnOpen = {},
		OnClose = {},
		Focus = nil,
	}

	local closing = false
	panel.Open = function(self)
		if self.IsOpen then
			return
		end
		UIKit.closeAll(self.Name)
		self.IsOpen = true
		closing = false
		CursorController.hold("Panel_" .. self.Name, true)
		fit.Scale = UIKit.fitScale(design)
		gui.Enabled = true
		-- slide up + fade + grow
		anim.Scale = 0.9
		motion.Position = UDim2.fromOffset(0, 22)
		window.GroupTransparency = 1
		dim.BackgroundTransparency = 1
		UIKit.tween(anim, OPEN_SECONDS, { Scale = 1 }, Enum.EasingStyle.Back)
		UIKit.tween(motion, OPEN_SECONDS, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quad)
		UIKit.tween(window, OPEN_SECONDS * 0.8, { GroupTransparency = 0 })
		UIKit.tween(dim, OPEN_SECONDS, { BackgroundTransparency = 0.55 })
		AudioController.play("Open")
		for _, callback in self.OnOpen do
			task.spawn(callback)
		end
	end
	panel.Close = function(self)
		if not self.IsOpen then
			return
		end
		self.IsOpen = false
		closing = true
		CursorController.hold("Panel_" .. self.Name, false)
		UIKit.tween(anim, CLOSE_SECONDS, { Scale = 0.92 })
		UIKit.tween(motion, CLOSE_SECONDS, { Position = UDim2.fromOffset(0, 14) })
		UIKit.tween(window, CLOSE_SECONDS, { GroupTransparency = 1 })
		UIKit.tween(dim, CLOSE_SECONDS, { BackgroundTransparency = 1 })
		AudioController.play("Close")
		task.delay(CLOSE_SECONDS + 0.02, function()
			if closing and not self.IsOpen then
				gui.Enabled = false
			end
		end)
		for _, callback in self.OnClose do
			task.spawn(callback)
		end
	end
	panel.Toggle = function(self)
		if self.IsOpen then
			self:Close()
		else
			self:Open()
		end
	end

	local closeButton = UIKit.button(header, {
		Text = "",
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(1, -16, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = C.Red,
		Name = "Close",
		Silent = true,
		Corner = 10,
		OnClick = function()
			panel:Close()
		end,
	})
	closeButton.ZIndex = 4
	for _, sign in { -1, 1 } do
		local bar = UIKit.frame(closeButton, { Size = UDim2.fromOffset(22, 5), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = 45 * sign, BackgroundColor3 = C.White, ZIndex = 5 })
		UIKit.corner(bar, 3)
	end
	dim.Activated:Connect(function()
		panel:Close()
	end)

	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			fit.Scale = UIKit.fitScale(design)
		end)
	end

	panels[options.Name] = panel
	return panel
end

---------------------------------------------------------------------------
-- misc widgets
---------------------------------------------------------------------------

-- A rounded stat pill with a drawn icon: coin / gem / flame ...
function UIKit.pill(parent: Instance, props: { Icon: string, Color: Color3?, Size: UDim2?, LayoutOrder: number?, OnPlus: (() -> ())? }): { Frame: Frame, Value: TextLabel }
	local accent = props.Color or C.Gold
	local frame = UIKit.frame(parent, {
		Size = props.Size or UDim2.fromOffset(170, 40),
		BackgroundColor3 = C.Dim,
		BackgroundTransparency = 0.1,
		LayoutOrder = props.LayoutOrder or 0,
	})
	UIKit.corner(frame, 21)
	UIKit.stroke(frame, C.GoldLine, 2)
	UIKit.gradient(frame, Color3.fromRGB(66, 50, 38), Color3.fromRGB(24, 18, 14), 90)
	local badge = UIKit.frame(frame, { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = accent, BackgroundTransparency = 0.78 })
	UIKit.corner(badge, 99)
	UIKit.icon(badge, props.Icon, { Size = UDim2.fromOffset(26, 26), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
	local value = UIKit.label(frame, {
		Size = UDim2.new(1, if props.OnPlus then -88 else -52, 1, 0),
		Position = UDim2.fromOffset(46, 0),
		Font = UIKit.Fonts.Title,
		TextSize = 24,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	if props.OnPlus then
		local plus = UIKit.button(frame, {
			Text = "",
			Size = UDim2.fromOffset(30, 30),
			Position = UDim2.new(1, -7, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Color = C.Green,
			Corner = 8,
			Name = "Plus",
			OnClick = props.OnPlus,
		})
		for _, rotation in { 0, 90 } do
			local bar = UIKit.frame(plus, { Size = UDim2.fromOffset(16, 4), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = rotation, BackgroundColor3 = C.White, ZIndex = 4 })
			UIKit.corner(bar, 2)
		end
	end
	return { Frame = frame, Value = value }
end

-- Small red dot used to show "something to claim".
function UIKit.notifyDot(parent: GuiObject): Frame
	local dot = UIKit.frame(parent, {
		Name = "NotifyDot",
		Size = UDim2.fromOffset(18, 18),
		Position = UDim2.new(1, -2, 0, 2),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = C.Red,
		Visible = false,
		ZIndex = 10,
	})
	UIKit.corner(dot, 99)
	UIKit.stroke(dot, C.White, 2)
	return dot
end

-- Floating text that rises and fades (e.g. "+$50").
function UIKit.floatText(parent: Instance, text: string, color: Color3, position: UDim2)
	local label = UIKit.label(parent, {
		Text = text,
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(200, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = UIKit.Fonts.Title,
		TextSize = 24,
		TextColor3 = color,
		ZIndex = 20,
	})
	UIKit.new("UIStroke", { Color = C.Dim, Thickness = 2 }, label)
	UIKit.tween(label, 1, { Position = position - UDim2.fromOffset(0, 40), TextTransparency = 1 })
	task.delay(1.05, function()
		label:Destroy()
	end)
end

function UIKit.rarityColor(definition: any): Color3
	if definition.Hidden then
		return definition.Accent
	end
	return definition.Color
end

-- Text on a dark chip, readable on any background.
function UIKit.chip(parent: Instance, text: string, color: Color3, size: UDim2?): TextLabel
	local label = UIKit.label(parent, {
		Text = text,
		Size = size or UDim2.fromOffset(90, 22),
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = UIKit.Fonts.Body,
		TextSize = 12,
	})
	UIKit.corner(label, 99)
	return label
end

UIKit.GuiService = GuiService

return UIKit
