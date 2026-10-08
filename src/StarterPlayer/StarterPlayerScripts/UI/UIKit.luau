--[[
	UIKit: the building blocks of the Hamster Plaza interface.
	Art direction: cozy cream panels, warm brown headers, rounded everything, playful FredokaOne titles.
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

local UIKit = {}

local player = Players.LocalPlayer

UIKit.Colors = {
	Cream = Color3.fromRGB(255, 247, 233),
	CreamDark = Color3.fromRGB(246, 232, 208),
	Card = Color3.fromRGB(255, 252, 244),
	Brown = Color3.fromRGB(126, 84, 58),
	BrownDark = Color3.fromRGB(92, 60, 42),
	BrownLight = Color3.fromRGB(170, 120, 86),
	Ink = Color3.fromRGB(74, 52, 44),
	Muted = Color3.fromRGB(150, 124, 108),
	Peach = Color3.fromRGB(255, 176, 122),
	Pink = Color3.fromRGB(255, 142, 178),
	Mint = Color3.fromRGB(122, 214, 170),
	Sky = Color3.fromRGB(122, 190, 255),
	Gold = Color3.fromRGB(255, 205, 86),
	GoldDark = Color3.fromRGB(214, 160, 40),
	Green = Color3.fromRGB(96, 196, 126),
	Red = Color3.fromRGB(240, 98, 98),
	Purple = Color3.fromRGB(176, 124, 255),
	White = Color3.new(1, 1, 1),
	Dim = Color3.fromRGB(30, 20, 28),
}

UIKit.Fonts = {
	Title = Enum.Font.FredokaOne,
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
	UIKit.corner(button, props.Corner or 12)
	local stroke = UIKit.stroke(button, darker(color, 0.7), 2)
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
	button.BackgroundColor3 = if enabled then base else Color3.fromRGB(190, 176, 168)
	button.TextTransparency = if enabled then 0 else 0.25
	local edge = button:FindFirstChild("Edge") :: UIStroke?
	if edge then
		edge.Color = if enabled then darker(base, 0.7) else Color3.fromRGB(150, 136, 128)
	end
end

function UIKit.setButtonColor(button: TextButton, color: Color3)
	button:SetAttribute("BaseColor", color)
	if not button:GetAttribute("Disabled") then
		button.BackgroundColor3 = color
		local edge = button:FindFirstChild("Edge") :: UIStroke?
		if edge then
			edge.Color = darker(color, 0.7)
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
	})
	UIKit.corner(frame, 99)
	UIKit.stroke(frame, Color3.fromRGB(214, 194, 164), 1.5)
	local fill = UIKit.frame(frame, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = props.Color or C.Mint })
	UIKit.corner(fill, 99)
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
		Size = UDim2.fromOffset(62, 30),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		BackgroundColor3 = C.Muted,
		BorderSizePixel = 0,
	}, parent)
	UIKit.corner(track, 99)
	UIKit.stroke(track, Color3.fromRGB(110, 90, 76), 2)
	local knob = UIKit.frame(track, { Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = C.White })
	UIKit.corner(knob, 99)
	local function render(animate: boolean)
		local target = if value then UDim2.fromOffset(36, 4) else UDim2.fromOffset(4, 4)
		local color = if value then C.Green else C.Muted
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
		BackgroundColor3 = C.CreamDark,
	})
	UIKit.corner(frame, 99)
	UIKit.stroke(frame, Color3.fromRGB(214, 194, 164), 1.5)
	local fill = UIKit.frame(frame, { BackgroundColor3 = C.Peach, Size = UDim2.fromScale(0, 1) })
	UIKit.corner(fill, 99)
	local knob = UIKit.frame(frame, { Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = C.White, ZIndex = 3 })
	UIKit.corner(knob, 99)
	UIKit.stroke(knob, C.BrownLight, 2)
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
			local base = button:GetAttribute("TabColor") or C.Brown
			if tabId == id then
				UIKit.setButtonColor(button, base)
				button.TextColor3 = C.White
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
		ScrollBarImageColor3 = C.BrownLight,
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

	-- outer frame: design size + fit scale; inner frame: open/close animation scale
	local outer = UIKit.frame(gui, {
		Size = UDim2.fromOffset(design.X, design.Y),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	})
	local fit = UIKit.new("UIScale", { Scale = UIKit.fitScale(design) }, outer)
	local window = UIKit.frame(outer, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Cream })
	local anim = UIKit.new("UIScale", { Scale = 0.85 }, window)
	UIKit.corner(window, 22)
	UIKit.stroke(window, C.BrownDark, 4)

	local header = UIKit.frame(window, { Size = UDim2.new(1, 0, 0, 62), BackgroundColor3 = accent })
	UIKit.corner(header, 22)
	-- square off the bottom corners of the header
	UIKit.frame(header, { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -22), BackgroundColor3 = accent })
	UIKit.gradient(header, UIKit.Colors.BrownLight, accent, 90)
	local title = UIKit.label(header, {
		Size = UDim2.new(1, -100, 1, 0),
		Position = UDim2.fromOffset(24, 0),
		Font = UIKit.Fonts.Title,
		TextSize = 32,
		TextColor3 = C.White,
		Text = (if options.Icon then options.Icon .. "  " else "") .. options.Title,
		ZIndex = 3,
	})
	UIKit.new("UIStroke", { Color = C.BrownDark, Thickness = 2 }, title)

	local body = UIKit.frame(window, {
		Size = UDim2.new(1, -28, 1, -78),
		Position = UDim2.fromOffset(14, 70),
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
		fit.Scale = UIKit.fitScale(design)
		gui.Enabled = true
		anim.Scale = 0.85
		dim.BackgroundTransparency = 1
		UIKit.tween(anim, 0.22, { Scale = 1 }, Enum.EasingStyle.Back)
		UIKit.tween(dim, 0.2, { BackgroundTransparency = 0.55 })
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
		UIKit.tween(anim, 0.14, { Scale = 0.88 })
		UIKit.tween(dim, 0.14, { BackgroundTransparency = 1 })
		AudioController.play("Close")
		task.delay(0.15, function()
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
		Text = "✕",
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(1, -14, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Color = C.Red,
		TextSize = 22,
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

-- A rounded stat pill: "🪙  1.2K"
function UIKit.pill(parent: Instance, props: { Icon: string, Color: Color3?, Size: UDim2?, LayoutOrder: number? }): { Frame: Frame, Value: TextLabel }
	local frame = UIKit.frame(parent, {
		Size = props.Size or UDim2.fromOffset(170, 40),
		BackgroundColor3 = C.Dim,
		BackgroundTransparency = 0.15,
		LayoutOrder = props.LayoutOrder or 0,
	})
	UIKit.corner(frame, 20)
	UIKit.stroke(frame, props.Color or C.Gold, 2.5)
	UIKit.label(frame, {
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromOffset(4, 0),
		Text = props.Icon,
		TextSize = 24,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	local value = UIKit.label(frame, {
		Size = UDim2.new(1, -52, 1, 0),
		Position = UDim2.fromOffset(46, 0),
		Font = UIKit.Fonts.Title,
		TextSize = 22,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
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
