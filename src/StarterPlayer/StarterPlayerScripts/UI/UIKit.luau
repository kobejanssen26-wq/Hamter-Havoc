--[[
	UIKit: the building blocks of the Hamster Plaza interface. Every menu is made from these, so the
	whole game shares one visual language:

	  cute + premium + modern   warm cream windows, white cards, soft shadows, rounded everything,
	                            gentle top-to-bottom gradients, FredokaOne titles, Gotham body text
	  icons                     UI/Icons (drawn from GUI shapes, never emoji)
	  motion                    hover grows 4%, press squashes to 95%, windows scale + slide in (0.22 s)
	  cursor                    while a window is open the mouse is freed, also in first person

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
local Icons = require(script.Parent.Icons)

local UIKit = {}

local player = Players.LocalPlayer

UIKit.Icons = Icons

UIKit.Colors = {
	Cream = Color3.fromRGB(255, 249, 240), -- window background
	CreamDark = Color3.fromRGB(244, 233, 218), -- insets, tracks, inactive tabs
	Card = Color3.fromRGB(255, 255, 255),
	Line = Color3.fromRGB(234, 220, 202), -- hairlines and soft borders
	Brown = Color3.fromRGB(150, 100, 70),
	BrownDark = Color3.fromRGB(96, 64, 50),
	BrownLight = Color3.fromRGB(196, 150, 112),
	Ink = Color3.fromRGB(64, 46, 48), -- main text
	Muted = Color3.fromRGB(146, 128, 124), -- secondary text
	Peach = Color3.fromRGB(255, 159, 92),
	Pink = Color3.fromRGB(255, 120, 168),
	Mint = Color3.fromRGB(52, 199, 154),
	Sky = Color3.fromRGB(77, 163, 255),
	Gold = Color3.fromRGB(255, 196, 60),
	GoldDark = Color3.fromRGB(214, 150, 30),
	Green = Color3.fromRGB(64, 196, 120),
	Red = Color3.fromRGB(255, 92, 108),
	Purple = Color3.fromRGB(155, 107, 255),
	Orange = Color3.fromRGB(255, 122, 46),
	White = Color3.new(1, 1, 1),
	Dim = Color3.fromRGB(34, 24, 32), -- HUD backdrops and the window dim
	Shadow = Color3.fromRGB(58, 36, 48),
}

UIKit.Fonts = {
	Title = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamBold,
	Soft = Enum.Font.GothamMedium,
}

UIKit.Speed = { Hover = 0.12, Press = 0.08, Open = 0.22, Close = 0.14 }

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
	-- Note: a UIGradient MULTIPLIES the background colour. Use white/grey stops to shade a coloured
	-- frame, or a white background when the gradient carries the real colours.
	return UIKit.new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90 }, parent)
end

function UIKit.tween(instance: Instance, duration: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
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
	Icon: string?, -- UI icon name (UI/Icons), drawn left of the text
	IconSize: number?,
}

local function darker(color: Color3, factor: number): Color3
	return Color3.new(color.R * factor, color.G * factor, color.B * factor)
end
local function lighter(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end
UIKit.darker = darker
UIKit.lighter = lighter

-- Soft drop shadow behind a frame (a blurred look from two stacked transparent layers).
function UIKit.shadow(target: GuiObject, radius: number?, offset: number?): Frame
	-- With ZIndexBehavior.Sibling a child always draws on top of its parent, so a shadow child would
	-- darken the card itself. The card's background therefore moves to a "Fill" child that sits above
	-- the shadow and below the content; the card itself becomes transparent and its colour,
	-- transparency, corner and gradient keep being mirrored onto the fill.
	local holder = UIKit.frame(target, {
		Name = "Shadow",
		Size = UDim2.new(1, 6, 1, 6),
		Position = UDim2.new(0.5, 0, 0.5, offset or 5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UIKit.Colors.Shadow,
		BackgroundTransparency = 0.82,
		ZIndex = -2,
	})
	UIKit.corner(holder, (radius or 16) + 3)
	local inner = UIKit.frame(holder, {
		Size = UDim2.new(1, -4, 1, -4),
		Position = UDim2.new(0.5, 0, 0.5, -1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = UIKit.Colors.Shadow,
		BackgroundTransparency = 0.8,
		ZIndex = -2,
	})
	UIKit.corner(inner, radius or 16)

	local fill = UIKit.frame(target, {
		Name = "Fill",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = target.BackgroundColor3,
		BackgroundTransparency = target.BackgroundTransparency,
		ZIndex = -1,
	})
	target.BackgroundTransparency = 1
	local syncing = false
	target:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
		if syncing or target.BackgroundTransparency == 1 then
			return
		end
		syncing = true
		fill.BackgroundTransparency = target.BackgroundTransparency
		target.BackgroundTransparency = 1
		syncing = false
	end)
	target:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		fill.BackgroundColor3 = target.BackgroundColor3
	end)
	local function mirror(child: Instance)
		if child:IsA("UICorner") then
			local copy = fill:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
			copy.CornerRadius = child.CornerRadius
			copy.Parent = fill
		elseif child:IsA("UIGradient") then
			-- a gradient on the card would now only tint its (transparent) background: move it to the fill
			child.Parent = fill
		end
	end
	for _, child in target:GetChildren() do
		mirror(child)
	end
	target.ChildAdded:Connect(mirror)
	return holder
end

-- An icon from UI/Icons. `size` in pixels.
function UIKit.icon(parent: Instance?, name: string, size: number, props: Icons.IconProps?): GuiObject
	return Icons.create(name, size, parent, props)
end

-- White rounded card with a hairline border: the standard container inside windows.
function UIKit.card(parent: Instance?, props: { [string]: any }?): Frame
	local defaults: { [string]: any } = { BackgroundColor3 = UIKit.Colors.Card, BorderSizePixel = 0 }
	local given: { [string]: any } = props or {}
	for key, value in given do
		defaults[key] = value
	end
	local card = UIKit.new("Frame", defaults, parent)
	UIKit.corner(card, 16)
	UIKit.stroke(card, UIKit.Colors.Line, 1.5)
	return card
end

-- Rounded button with a soft gradient, hover (grow + brighten) and press (squash) animations.
-- `Icon` puts a UI icon left of the text (or alone when there is no text).
function UIKit.button(parent: Instance?, props: ButtonProps): TextButton
	local color = props.Color or C.Peach
	local hasIcon = props.Icon ~= nil
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
	UIKit.corner(button, props.Corner or 14)
	local stroke = UIKit.stroke(button, darker(color, 0.78), 1.5)
	stroke.Name = "Edge"
	local gradient = UIKit.new("UIGradient", {
		Name = "Sheen",
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(226, 226, 226)),
		Rotation = 90,
	}, button)
	local scale = UIKit.new("UIScale", { Scale = 1 }, button)
	button:SetAttribute("BaseColor", color)
	if hasIcon then
		local iconSize = props.IconSize or math.floor(math.min(button.Size.Y.Offset, 44) * 0.62)
		local text = props.Text or ""
		local icon = Icons.create(props.Icon :: string, iconSize, button, {
			Name = "ButtonIcon",
			-- with text, the UIPadding below (iconSize + 8) also shifts this icon: compensate so it sits 10px in
			Position = if text == "" then UDim2.fromScale(0.5, 0.5) else UDim2.new(0, 2 - iconSize, 0.5, 0),
			AnchorPoint = if text == "" then Vector2.new(0.5, 0.5) else Vector2.new(0, 0.5),
		})
		icon.ZIndex = button.ZIndex
		if text ~= "" then
			UIKit.new("UIPadding", { PaddingLeft = UDim.new(0, iconSize + 8) }, button)
		end
	end
	UIKit.text(button)

	local hovering = false
	button.MouseEnter:Connect(function()
		if button:GetAttribute("Disabled") then
			return
		end
		hovering = true
		UIKit.tween(scale, UIKit.Speed.Hover, { Scale = 1.04 })
		UIKit.tween(button, UIKit.Speed.Hover, { BackgroundColor3 = lighter(button:GetAttribute("BaseColor") or color, 0.12) })
		if not props.Silent then
			AudioController.play("Hover")
		end
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		UIKit.tween(scale, UIKit.Speed.Hover, { Scale = 1 })
		if not button:GetAttribute("Disabled") then
			UIKit.tween(button, UIKit.Speed.Hover, { BackgroundColor3 = button:GetAttribute("BaseColor") or color })
		end
	end)
	button.MouseButton1Down:Connect(function()
		if not button:GetAttribute("Disabled") then
			UIKit.tween(scale, UIKit.Speed.Press, { Scale = 0.95 })
		end
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.tween(scale, 0.16, { Scale = if hovering then 1.04 else 1 }, Enum.EasingStyle.Back)
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
	gradient.Enabled = true
	return button
end

-- Light text stroke so white text on coloured buttons stays readable.
function UIKit.text(target: TextButton | TextLabel)
	if target.TextColor3 == C.White and not target:FindFirstChild("TextEdge") then
		UIKit.new("UIStroke", { Name = "TextEdge", ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, Thickness = 1.2, Color = C.Shadow, Transparency = 0.6 }, target)
	end
end

function UIKit.setEnabled(button: TextButton, enabled: boolean)
	button:SetAttribute("Disabled", not enabled)
	local base = button:GetAttribute("BaseColor") or C.Peach
	button.BackgroundColor3 = if enabled then base else Color3.fromRGB(214, 204, 198)
	button.TextTransparency = if enabled then 0 else 0.3
	local edge = button:FindFirstChild("Edge") :: UIStroke?
	if edge then
		edge.Color = if enabled then darker(base, 0.78) else Color3.fromRGB(190, 178, 172)
	end
	local icon = button:FindFirstChild("ButtonIcon")
	if icon then
		for _, child in icon:GetDescendants() do
			if child:IsA("Frame") and child.BackgroundTransparency < 1 then
				child:SetAttribute("BaseTransparency", child:GetAttribute("BaseTransparency") or child.BackgroundTransparency)
				child.BackgroundTransparency = if enabled then child:GetAttribute("BaseTransparency") else 0.5
			end
		end
	end
end

function UIKit.setButtonColor(button: TextButton, color: Color3)
	button:SetAttribute("BaseColor", color)
	if not button:GetAttribute("Disabled") then
		button.BackgroundColor3 = color
		local edge = button:FindFirstChild("Edge") :: UIStroke?
		if edge then
			edge.Color = darker(color, 0.78)
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
		BackgroundColor3 = props.Back or C.CreamDark,
		LayoutOrder = props.LayoutOrder or 0,
		ClipsDescendants = true,
	})
	UIKit.corner(frame, 99)
	local fill = UIKit.frame(frame, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = props.Color or C.Mint })
	UIKit.corner(fill, 99)
	UIKit.gradient(fill, Color3.new(1, 1, 1), Color3.fromRGB(215, 215, 215), 90)
	local label = UIKit.label(frame, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 12,
		TextColor3 = C.Ink,
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
		Size = UDim2.fromOffset(56, 30),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		BackgroundColor3 = C.CreamDark,
		BorderSizePixel = 0,
	}, parent)
	UIKit.corner(track, 99)
	local knob = UIKit.frame(track, { Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(3, 3), BackgroundColor3 = C.White })
	UIKit.corner(knob, 99)
	UIKit.stroke(knob, C.Line, 1)
	local function render(animate: boolean)
		local target = if value then UDim2.fromOffset(29, 3) else UDim2.fromOffset(3, 3)
		local color = if value then C.Mint else Color3.fromRGB(214, 202, 190)
		if animate then
			UIKit.tween(knob, 0.16, { Position = target }, Enum.EasingStyle.Back)
			UIKit.tween(track, 0.16, { BackgroundColor3 = color })
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
		Size = props.Size or UDim2.fromOffset(180, 10),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		BackgroundColor3 = C.CreamDark,
	})
	UIKit.corner(frame, 99)
	local fill = UIKit.frame(frame, { BackgroundColor3 = C.Peach, Size = UDim2.fromScale(0, 1) })
	UIKit.corner(fill, 99)
	local knob = UIKit.frame(frame, { Size = UDim2.fromOffset(22, 22), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = C.White, ZIndex = 3 })
	UIKit.corner(knob, 99)
	UIKit.stroke(knob, C.Peach, 2)
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

export type TabDef = { Id: string, Text: string, Color: Color3?, Icon: string? }

-- Segmented tabs: a soft track, the selected tab is a white chip with the accent colour.
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
			local accent = button:GetAttribute("TabColor") or C.Brown
			if tabId == id then
				UIKit.setButtonColor(button, accent)
				button.TextColor3 = C.White
			else
				UIKit.setButtonColor(button, C.CreamDark)
				button.TextColor3 = C.Ink
			end
			local edge = button:FindFirstChild("TextEdge") :: UIStroke?
			if edge then
				edge.Enabled = tabId == id
			end
		end
		if not silent then
			onSelect(id)
		end
	end

	for index, def in defs do
		local button = UIKit.button(frame, {
			Text = def.Text,
			Icon = def.Icon,
			Size = opts.ButtonSize or UDim2.fromOffset(110, 36),
			Color = C.CreamDark,
			TextColor = C.White,
			TextSize = 15,
			LayoutOrder = index,
			Name = "Tab_" .. def.Id,
			OnClick = function()
				select(def.Id)
			end,
		})
		button.TextColor3 = C.Ink
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
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.BrownLight,
		ScrollBarImageTransparency = 0.3,
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
-- cursor: windows free the mouse, also in first person
---------------------------------------------------------------------------

-- In first person Roblox locks the mouse to the centre and hides it, so buttons can't be clicked.
-- A visible GuiButton with Modal = true releases it while any window is open; closing the last
-- window gives the mouse back to the camera. See also InputController (crosshair, cursor icon).
local openCount = 0
local modalButton: TextButton? = nil
local modalListeners: { (boolean) -> () } = {}

local function setModal(open: boolean)
	if not modalButton then
		local gui = UIKit.new("ScreenGui", { Name = "CursorRelease", ResetOnSpawn = false, DisplayOrder = 0, IgnoreGuiInset = true }, player:WaitForChild("PlayerGui"))
		modalButton = UIKit.new("TextButton", {
			Name = "Modal",
			Text = "",
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(0, 0),
			Modal = false,
			Selectable = false,
		}, gui)
	end
	local button = modalButton :: TextButton
	button.Modal = open
	button.Visible = open
	if open then
		UserInputService.MouseIconEnabled = true
	end
	for _, listener in modalListeners do
		task.spawn(listener, open)
	end
end

function UIKit.windowOpened()
	openCount += 1
	if openCount == 1 then
		setModal(true)
	end
end

function UIKit.windowClosed()
	openCount = math.max(0, openCount - 1)
	if openCount == 0 then
		setModal(false)
	end
end

function UIKit.anyWindowOpen(): boolean
	return openCount > 0
end

function UIKit.onWindowsChanged(listener: (boolean) -> ())
	table.insert(modalListeners, listener)
end

---------------------------------------------------------------------------
-- panels (windows)
---------------------------------------------------------------------------

export type Panel = {
	Name: string,
	Gui: ScreenGui,
	Window: Frame,
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

-- A window: cream body, coloured header with an icon bubble, white close button, soft shadow.
-- `Icon` is a UI icon name (UI/Icons).
function UIKit.panel(options: { Name: string, Title: string, Icon: string?, Design: Vector2?, Accent: Color3? }): Panel
	local design = options.Design or Vector2.new(860, 560)
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

	local dim = UIKit.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = C.Dim,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
	}, gui)

	-- outer frame: design size + fit scale; window: open/close animation (scale + slide)
	local outer = UIKit.frame(gui, {
		Size = UDim2.fromOffset(design.X, design.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	})
	local fit = UIKit.new("UIScale", { Scale = UIKit.fitScale(design) }, outer)
	local window = UIKit.frame(outer, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Cream, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
	UIKit.shadow(window, 26, 10)
	local anim = UIKit.new("UIScale", { Scale = 0.92 }, window)
	UIKit.corner(window, 26)
	UIKit.stroke(window, lighter(accent, 0.55), 3)

	local header = UIKit.frame(window, { Size = UDim2.new(1, 0, 0, 68), BackgroundColor3 = accent })
	UIKit.corner(header, 26)
	-- square off the bottom corners of the header
	UIKit.frame(header, { Size = UDim2.new(1, 0, 0, 26), Position = UDim2.new(0, 0, 1, -26), BackgroundColor3 = accent })
	-- the gradients carry the colours, so the frames themselves go white (a gradient multiplies)
	header.BackgroundColor3 = C.White
	UIKit.gradient(header, lighter(accent, 0.25), accent, 90)
	for _, child in header:GetChildren() do
		if child:IsA("Frame") then
			child.BackgroundColor3 = C.White
			UIKit.gradient(child, accent, darker(accent, 0.96), 90)
		end
	end

	local titleX = 22
	if options.Icon and UIKit.Icons.create then
		local bubble = UIKit.frame(header, { Size = UDim2.fromOffset(48, 48), Position = UDim2.new(0, 14, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), BackgroundColor3 = C.White, ZIndex = 3 })
		UIKit.corner(bubble, 99)
		UIKit.stroke(bubble, darker(accent, 0.85), 2)
		Icons.create(options.Icon, 34, bubble, { Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 4 })
		titleX = 74
	end
	local title = UIKit.label(header, {
		Size = UDim2.new(1, -titleX - 70, 1, 0),
		Position = UDim2.fromOffset(titleX, 0),
		Font = UIKit.Fonts.Title,
		TextSize = 30,
		TextColor3 = C.White,
		Text = options.Title,
		ZIndex = 3,
	})
	UIKit.new("UIStroke", { Color = darker(accent, 0.6), Thickness = 1.6, Transparency = 0.3 }, title)

	local body = UIKit.frame(window, {
		Size = UDim2.new(1, -32, 1, -88),
		Position = UDim2.fromOffset(16, 78),
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
		UIKit.windowOpened()
		fit.Scale = UIKit.fitScale(design)
		gui.Enabled = true
		anim.Scale = 0.92
		window.Position = UDim2.new(0.5, 0, 0.5, 18)
		dim.BackgroundTransparency = 1
		UIKit.tween(anim, UIKit.Speed.Open, { Scale = 1 }, Enum.EasingStyle.Back)
		UIKit.tween(window, UIKit.Speed.Open, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quint)
		UIKit.tween(dim, UIKit.Speed.Open, { BackgroundTransparency = 0.6 })
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
		UIKit.windowClosed()
		UIKit.tween(anim, UIKit.Speed.Close, { Scale = 0.95 })
		UIKit.tween(window, UIKit.Speed.Close, { Position = UDim2.new(0.5, 0, 0.5, 12) })
		UIKit.tween(dim, UIKit.Speed.Close, { BackgroundTransparency = 1 })
		AudioController.play("Close")
		task.delay(UIKit.Speed.Close + 0.01, function()
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
		Icon = "Close",
		IconSize = 20,
		Size = UDim2.fromOffset(42, 42),
		Position = UDim2.new(1, -14, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = C.Red,
		Corner = 99,
		Name = "Close",
		Silent = true,
		OnClick = function()
			panel:Close()
		end,
	})
	closeButton.ZIndex = 4
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

-- Currency capsule: icon bubble + value. `Icon` is a UI icon name.
function UIKit.pill(parent: Instance, props: { Icon: string, Color: Color3?, Size: UDim2?, LayoutOrder: number? }): { Frame: Frame, Value: TextLabel }
	local frame = UIKit.frame(parent, {
		Size = props.Size or UDim2.fromOffset(170, 40),
		BackgroundColor3 = C.White,
		LayoutOrder = props.LayoutOrder or 0,
	})
	UIKit.corner(frame, 99)
	UIKit.stroke(frame, lighter(props.Color or C.Gold, 0.35), 2)
	UIKit.shadow(frame, 20, 3)
	local height = (props.Size or UDim2.fromOffset(170, 40)).Y.Offset
	Icons.create(props.Icon, height + 6, frame, { Position = UDim2.new(0, -6, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 })
	local value = UIKit.label(frame, {
		Size = UDim2.new(1, -height - 10, 1, 0),
		Position = UDim2.fromOffset(height + 4, 0),
		Font = UIKit.Fonts.Title,
		TextSize = math.floor(height * 0.55),
		TextColor3 = C.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
	})
	return { Frame = frame, Value = value }
end

-- Small red dot used to show "something to claim".
function UIKit.notifyDot(parent: GuiObject): Frame
	local dot = UIKit.frame(parent, {
		Name = "NotifyDot",
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.new(1, 2, 0, -2),
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
	UIKit.new("UIStroke", { Color = C.Dim, Thickness = 2, Transparency = 0.3 }, label)
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

-- Text on a coloured chip, readable on any background.
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
	UIKit.text(label)
	return label
end

-- Icon + value row, e.g. coin icon "$1.2M" (used in cards and requirement lists).
function UIKit.amount(parent: Instance, iconName: string, text: string, props: { Size: UDim2?, TextSize: number?, Color: Color3?, LayoutOrder: number?, Position: UDim2? }?): (Frame, TextLabel)
	local opts = props or {}
	local size = opts.Size or UDim2.fromOffset(140, 24)
	local row = UIKit.frame(parent, { Size = size, BackgroundTransparency = 1, LayoutOrder = opts.LayoutOrder or 0, Position = opts.Position or UDim2.new() })
	local height = size.Y.Offset
	Icons.create(iconName, height, row, { Position = UDim2.fromOffset(0, 0) })
	local label = UIKit.label(row, {
		Text = text,
		Position = UDim2.fromOffset(height + 6, 0),
		Size = UDim2.new(1, -height - 6, 1, 0),
		Font = UIKit.Fonts.Title,
		TextSize = opts.TextSize or math.floor(height * 0.8),
		TextColor3 = opts.Color or C.Ink,
	})
	return row, label
end

UIKit.GuiService = GuiService

return UIKit
