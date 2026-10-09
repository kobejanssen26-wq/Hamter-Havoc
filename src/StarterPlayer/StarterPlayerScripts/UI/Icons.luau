--[[
	Icons: every icon in the interface is drawn from rounded frames, gradients and strokes - never from Unicode emoji,
	which render as empty squares on many devices. Each icon is a square frame; its parts are positioned in scale
	(0..1), so an icon looks the same at 16 px and at 120 px.

	  Icons.create(parent, "coin", { Size = UDim2.fromOffset(28, 28) })
	  Icons.has("coin")            -- is there such an icon?
	  Icons.names()                -- all icon ids

	Add an icon by adding one entry to `draw` (see the existing ones as examples).
]]

local Icons = {}

type Props = {
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?, -- tint of the main part (optional)
	ZIndex: number?,
	LayoutOrder: number?,
	Name: string?,
}

type Ctx = { Root: Frame, Px: number, Tint: Color3? }

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local DARK = rgb(74, 52, 44)
local WHITE = rgb(255, 255, 255)

-- One rounded rectangle / circle, positioned in scale units.
local function shape(ctx: Ctx, x: number, y: number, w: number, h: number, color: Color3, options: { Circle: boolean?, Radius: number?, Rot: number?, Top: Color3?, Stroke: Color3?, StrokeScale: number?, Alpha: number?, Z: number?, Center: boolean?, Hollow: boolean? }?): Frame
	local opts = options or {}
	local frame = Instance.new("Frame")
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = if opts.Hollow then 1 else (opts.Alpha or 0)
	if opts.Center then
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
	end
	frame.Position = UDim2.fromScale(x, y)
	frame.Size = UDim2.fromScale(w, h)
	frame.Rotation = opts.Rot or 0
	frame.ZIndex = opts.Z or 1
	if opts.Circle or opts.Radius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(if opts.Circle then 0.5 else opts.Radius :: number, 0)
		corner.Parent = frame
	end
	if opts.Top then
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(opts.Top, color)
		gradient.Rotation = 90
		gradient.Parent = frame
	end
	if opts.Stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = opts.Stroke
		stroke.Thickness = math.max(1, ctx.Px * (opts.StrokeScale or 0.06))
		stroke.Parent = frame
	end
	frame.Parent = ctx.Root
	return frame
end

local function tint(ctx: Ctx, default: Color3): Color3
	return ctx.Tint or default
end

local draw: { [string]: (Ctx) -> () } = {}

draw.coin = function(c)
	local gold = tint(c, rgb(255, 205, 70))
	shape(c, 0.05, 0.05, 0.9, 0.9, gold, { Circle = true, Top = rgb(255, 238, 150), Stroke = rgb(196, 134, 24) })
	shape(c, 0.22, 0.22, 0.56, 0.56, gold, { Circle = true, Hollow = true, Stroke = rgb(214, 152, 36), StrokeScale = 0.05, Z = 2 })
	shape(c, 0.38, 0.3, 0.12, 0.3, rgb(255, 250, 220), { Radius = 0.5, Rot = 25, Z = 3, Alpha = 0.35 })
end

draw.gem = function(c)
	local blue = tint(c, rgb(90, 190, 255))
	shape(c, 0.5, 0.5, 0.62, 0.62, blue, { Rot = 45, Radius = 0.14, Center = true, Top = rgb(190, 238, 255), Stroke = rgb(40, 120, 210) })
	shape(c, 0.5, 0.36, 0.22, 0.22, WHITE, { Rot = 45, Radius = 0.2, Center = true, Alpha = 0.55, Z = 2 })
end

draw.flame = function(c)
	local orange = tint(c, rgb(255, 130, 50))
	shape(c, 0.5, 0.62, 0.62, 0.62, orange, { Circle = true, Center = true, Top = rgb(255, 176, 70) })
	shape(c, 0.5, 0.36, 0.42, 0.42, orange, { Rot = 45, Radius = 0.12, Center = true, Top = rgb(255, 176, 70) })
	shape(c, 0.5, 0.66, 0.32, 0.32, rgb(255, 224, 110), { Circle = true, Center = true, Z = 2 })
	shape(c, 0.5, 0.52, 0.18, 0.2, rgb(255, 240, 170), { Rot = 45, Radius = 0.2, Center = true, Z = 2 })
end

draw.clover = function(c)
	local green = tint(c, rgb(88, 200, 108))
	for _, spot in { { 0.12, 0.1 }, { 0.5, 0.1 }, { 0.12, 0.46 }, { 0.5, 0.46 } } do
		shape(c, spot[1], spot[2], 0.38, 0.38, green, { Circle = true, Top = rgb(150, 232, 150) })
	end
	shape(c, 0.46, 0.55, 0.08, 0.42, rgb(60, 150, 84), { Radius = 0.5, Rot = 20, Z = 0 })
	shape(c, 0.5, 0.48, 0.2, 0.2, rgb(60, 150, 84), { Circle = true, Center = true, Z = 2 })
end

draw.bolt = function(c)
	local yellow = tint(c, rgb(255, 214, 70))
	shape(c, 0.5, 0.3, 0.3, 0.52, yellow, { Rot = 22, Radius = 0.2, Center = true, Top = rgb(255, 240, 150) })
	shape(c, 0.5, 0.68, 0.3, 0.52, yellow, { Rot = 22, Radius = 0.2, Center = true })
	shape(c, 0.5, 0.5, 0.52, 0.16, yellow, { Rot = 22, Radius = 0.4, Center = true, Z = 2 })
end

draw.gear = function(c)
	local grey = tint(c, rgb(190, 176, 168))
	for step = 0, 3 do
		shape(c, 0.5, 0.5, 0.2, 0.94, grey, { Rot = step * 45, Radius = 0.2, Center = true })
	end
	shape(c, 0.5, 0.5, 0.68, 0.68, grey, { Circle = true, Center = true, Top = rgb(230, 220, 214), Z = 2 })
	shape(c, 0.5, 0.5, 0.28, 0.28, DARK, { Circle = true, Center = true, Z = 3 })
end

draw.hamster = function(c)
	local fur = tint(c, rgb(255, 200, 140))
	shape(c, 0.1, 0.06, 0.28, 0.28, fur, { Circle = true })
	shape(c, 0.62, 0.06, 0.28, 0.28, fur, { Circle = true })
	shape(c, 0.16, 0.12, 0.16, 0.16, rgb(255, 160, 180), { Circle = true, Z = 2 })
	shape(c, 0.68, 0.12, 0.16, 0.16, rgb(255, 160, 180), { Circle = true, Z = 2 })
	shape(c, 0.08, 0.2, 0.84, 0.72, fur, { Circle = true, Top = rgb(255, 228, 190), Z = 2 })
	shape(c, 0.3, 0.46, 0.11, 0.13, DARK, { Circle = true, Z = 3 })
	shape(c, 0.59, 0.46, 0.11, 0.13, DARK, { Circle = true, Z = 3 })
	shape(c, 0.5, 0.64, 0.14, 0.1, rgb(240, 120, 150), { Circle = true, Center = true, Z = 3 })
	shape(c, 0.16, 0.62, 0.14, 0.1, rgb(255, 150, 170), { Circle = true, Alpha = 0.5, Z = 3 })
	shape(c, 0.7, 0.62, 0.14, 0.1, rgb(255, 150, 170), { Circle = true, Alpha = 0.5, Z = 3 })
end

draw.book = function(c)
	local cover = tint(c, rgb(110, 170, 240))
	shape(c, 0.1, 0.12, 0.8, 0.76, cover, { Radius = 0.12, Top = rgb(150, 205, 255), Stroke = rgb(60, 110, 190) })
	shape(c, 0.2, 0.2, 0.66, 0.6, rgb(255, 248, 232), { Radius = 0.08, Z = 2 })
	shape(c, 0.47, 0.2, 0.06, 0.6, rgb(214, 190, 150), { Z = 3 })
	for line = 0, 2 do
		shape(c, 0.26, 0.32 + line * 0.15, 0.17, 0.05, rgb(190, 170, 140), { Radius = 0.5, Z = 3 })
		shape(c, 0.58, 0.32 + line * 0.15, 0.17, 0.05, rgb(190, 170, 140), { Radius = 0.5, Z = 3 })
	end
end

draw.arrowup = function(c)
	local green = tint(c, rgb(96, 210, 130))
	for _, offset in { 0, 0.3 } do
		shape(c, 0.34, 0.4 + offset, 0.5, 0.17, green, { Rot = -45, Radius = 0.5, Center = true })
		shape(c, 0.66, 0.4 + offset, 0.5, 0.17, green, { Rot = 45, Radius = 0.5, Center = true })
	end
end

draw.gift = function(c)
	local box = tint(c, rgb(255, 120, 160))
	shape(c, 0.14, 0.44, 0.72, 0.46, box, { Radius = 0.1, Top = rgb(255, 160, 190), Stroke = rgb(210, 80, 120) })
	shape(c, 0.08, 0.3, 0.84, 0.2, box, { Radius = 0.2, Stroke = rgb(210, 80, 120), Z = 2 })
	shape(c, 0.44, 0.3, 0.12, 0.6, rgb(255, 214, 90), { Z = 3 })
	shape(c, 0.26, 0.1, 0.26, 0.22, rgb(255, 214, 90), { Circle = true, Z = 3 })
	shape(c, 0.48, 0.1, 0.26, 0.22, rgb(255, 214, 90), { Circle = true, Z = 3 })
end

draw.scroll = function(c)
	local paper = tint(c, rgb(255, 238, 200))
	shape(c, 0.2, 0.14, 0.6, 0.72, paper, { Radius = 0.1, Stroke = rgb(190, 150, 100) })
	shape(c, 0.12, 0.06, 0.76, 0.16, rgb(214, 160, 100), { Radius = 0.5, Z = 2 })
	shape(c, 0.12, 0.78, 0.76, 0.16, rgb(214, 160, 100), { Radius = 0.5, Z = 2 })
	for line = 0, 2 do
		shape(c, 0.3, 0.32 + line * 0.14, 0.4 - line * 0.05, 0.05, rgb(190, 150, 110), { Radius = 0.5, Z = 3 })
	end
end

draw.bag = function(c)
	local pink = tint(c, rgb(255, 140, 180))
	shape(c, 0.34, 0.08, 0.32, 0.36, DARK, { Circle = true, Hollow = true, Stroke = DARK, StrokeScale = 0.07 })
	shape(c, 0.16, 0.3, 0.68, 0.62, pink, { Radius = 0.18, Top = rgb(255, 184, 208), Stroke = rgb(214, 90, 130), Z = 2 })
	shape(c, 0.5, 0.58, 0.22, 0.2, WHITE, { Circle = true, Center = true, Alpha = 0.4, Z = 3 })
end

draw.crown = function(c)
	local gold = tint(c, rgb(255, 205, 70))
	shape(c, 0.14, 0.58, 0.72, 0.22, gold, { Radius = 0.2, Top = rgb(255, 232, 140), Stroke = rgb(196, 134, 24), Z = 2 })
	for _, x in { 0.26, 0.5, 0.74 } do
		shape(c, x, 0.4, 0.26, 0.26, gold, { Rot = 45, Radius = 0.12, Center = true, Stroke = rgb(196, 134, 24) })
		shape(c, x, 0.2, 0.12, 0.12, rgb(255, 120, 150), { Circle = true, Center = true, Z = 3 })
	end
end

draw.trophy = function(c)
	local gold = tint(c, rgb(255, 205, 70))
	for _, x in { 0.12, 0.68 } do
		shape(c, x, 0.2, 0.2, 0.26, gold, { Circle = true, Hollow = true, Stroke = rgb(214, 152, 36), StrokeScale = 0.07 })
	end
	shape(c, 0.26, 0.1, 0.48, 0.5, gold, { Radius = 0.3, Top = rgb(255, 232, 140), Stroke = rgb(196, 134, 24), Z = 2 })
	shape(c, 0.44, 0.58, 0.12, 0.2, gold, { Z = 1 })
	shape(c, 0.28, 0.76, 0.44, 0.14, rgb(196, 134, 24), { Radius = 0.3, Z = 2 })
end

draw.shield = function(c)
	local blue = tint(c, rgb(110, 170, 240))
	shape(c, 0.5, 0.64, 0.5, 0.5, blue, { Rot = 45, Radius = 0.1, Center = true, Z = 1 })
	shape(c, 0.17, 0.08, 0.66, 0.5, blue, { Radius = 0.18, Top = rgb(160, 208, 255), Stroke = rgb(60, 110, 190), Z = 2 })
	shape(c, 0.5, 0.42, 0.28, 0.28, WHITE, { Rot = 45, Radius = 0.15, Center = true, Alpha = 0.5, Z = 3 })
end

draw.home = function(c)
	local roof = tint(c, rgb(232, 112, 104))
	shape(c, 0.5, 0.4, 0.5, 0.5, roof, { Rot = 45, Radius = 0.1, Center = true, Z = 1 })
	shape(c, 0.25, 0.44, 0.5, 0.44, rgb(255, 238, 208), { Radius = 0.08, Stroke = rgb(190, 150, 100), Z = 2 })
	shape(c, 0.43, 0.62, 0.14, 0.26, rgb(150, 100, 64), { Radius = 0.3, Z = 3 })
end

draw.star = function(c)
	local gold = tint(c, rgb(255, 205, 70))
	shape(c, 0.5, 0.5, 0.58, 0.58, gold, { Radius = 0.1, Center = true, Top = rgb(255, 232, 140) })
	shape(c, 0.5, 0.5, 0.58, 0.58, gold, { Radius = 0.1, Rot = 45, Center = true, Top = rgb(255, 232, 140) })
end

draw.sparkle = function(c)
	local color = tint(c, rgb(255, 230, 120))
	shape(c, 0.5, 0.5, 0.2, 0.92, color, { Radius = 0.5, Center = true })
	shape(c, 0.5, 0.5, 0.92, 0.2, color, { Radius = 0.5, Center = true })
	shape(c, 0.5, 0.5, 0.14, 0.58, color, { Radius = 0.5, Rot = 45, Center = true, Alpha = 0.6 })
	shape(c, 0.5, 0.5, 0.14, 0.58, color, { Radius = 0.5, Rot = -45, Center = true, Alpha = 0.6 })
end

draw.question = function(c)
	shape(c, 0.06, 0.06, 0.88, 0.88, tint(c, rgb(150, 130, 220)), { Circle = true, Top = rgb(190, 176, 245), Stroke = rgb(100, 80, 180) })
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.Text = "?"
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.ZIndex = 3
	label.Parent = c.Root
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0.14, 0)
	padding.PaddingBottom = UDim.new(0.14, 0)
	padding.Parent = label
end

draw.check = function(c)
	shape(c, 0.06, 0.06, 0.88, 0.88, tint(c, rgb(96, 196, 126)), { Circle = true, Top = rgb(150, 232, 170), Stroke = rgb(50, 140, 80) })
	shape(c, 0.37, 0.6, 0.3, 0.12, WHITE, { Rot = 45, Radius = 0.5, Center = true, Z = 2 })
	shape(c, 0.57, 0.52, 0.5, 0.12, WHITE, { Rot = -50, Radius = 0.5, Center = true, Z = 2 })
end

draw.cross = function(c)
	shape(c, 0.06, 0.06, 0.88, 0.88, tint(c, rgb(240, 98, 98)), { Circle = true, Top = rgb(255, 150, 150), Stroke = rgb(180, 50, 60) })
	shape(c, 0.5, 0.5, 0.56, 0.13, WHITE, { Rot = 45, Radius = 0.5, Center = true, Z = 2 })
	shape(c, 0.5, 0.5, 0.56, 0.13, WHITE, { Rot = -45, Radius = 0.5, Center = true, Z = 2 })
end

draw.plus = function(c)
	shape(c, 0.06, 0.06, 0.88, 0.88, tint(c, rgb(96, 196, 126)), { Circle = true, Top = rgb(150, 232, 170), Stroke = rgb(50, 140, 80) })
	shape(c, 0.5, 0.5, 0.52, 0.13, WHITE, { Radius = 0.5, Center = true, Z = 2 })
	shape(c, 0.5, 0.5, 0.13, 0.52, WHITE, { Radius = 0.5, Center = true, Z = 2 })
end

draw.lock = function(c)
	local grey = tint(c, rgb(170, 160, 170))
	shape(c, 0.3, 0.08, 0.4, 0.5, grey, { Circle = true, Hollow = true, Stroke = rgb(120, 110, 124), StrokeScale = 0.09 })
	shape(c, 0.2, 0.44, 0.6, 0.46, grey, { Radius = 0.18, Top = rgb(210, 202, 210), Stroke = rgb(120, 110, 124), Z = 2 })
	shape(c, 0.5, 0.64, 0.12, 0.14, DARK, { Circle = true, Center = true, Z = 3 })
end

draw.music = function(c)
	local color = tint(c, rgb(150, 110, 240))
	shape(c, 0.18, 0.6, 0.3, 0.24, color, { Circle = true, Rot = -20 })
	shape(c, 0.62, 0.5, 0.3, 0.24, color, { Circle = true, Rot = -20 })
	shape(c, 0.42, 0.18, 0.07, 0.56, color, { Radius = 0.5 })
	shape(c, 0.86, 0.1, 0.07, 0.56, color, { Radius = 0.5 })
	shape(c, 0.42, 0.14, 0.5, 0.14, color, { Radius = 0.4, Rot = -8, Z = 2 })
end

draw.speaker = function(c)
	local color = tint(c, rgb(120, 190, 255))
	shape(c, 0.1, 0.36, 0.22, 0.28, color, { Radius = 0.2 })
	shape(c, 0.26, 0.24, 0.26, 0.52, color, { Rot = 0, Radius = 0.2, Top = rgb(180, 220, 255) })
	shape(c, 0.46, 0.3, 0.3, 0.4, color, { Circle = true, Hollow = true, Stroke = color, StrokeScale = 0.07 })
	shape(c, 0.54, 0.18, 0.4, 0.64, color, { Circle = true, Hollow = true, Stroke = color, StrokeScale = 0.07 })
end

draw.monitor = function(c)
	local color = tint(c, rgb(130, 150, 210))
	shape(c, 0.08, 0.14, 0.84, 0.56, color, { Radius = 0.1, Stroke = rgb(80, 96, 160) })
	shape(c, 0.15, 0.21, 0.7, 0.42, rgb(210, 232, 255), { Radius = 0.06, Z = 2 })
	shape(c, 0.44, 0.7, 0.12, 0.14, color, { Z = 1 })
	shape(c, 0.28, 0.82, 0.44, 0.08, color, { Radius = 0.5, Z = 1 })
end

draw.people = function(c)
	local color = tint(c, rgb(255, 176, 122))
	shape(c, 0.14, 0.14, 0.3, 0.3, color, { Circle = true })
	shape(c, 0.56, 0.14, 0.3, 0.3, color, { Circle = true })
	shape(c, 0.04, 0.5, 0.5, 0.4, color, { Radius = 0.5, Top = rgb(255, 210, 170) })
	shape(c, 0.46, 0.5, 0.5, 0.4, color, { Radius = 0.5, Top = rgb(255, 210, 170) })
end

draw.bell = function(c)
	local gold = tint(c, rgb(255, 205, 70))
	shape(c, 0.2, 0.12, 0.6, 0.6, gold, { Circle = true, Top = rgb(255, 232, 140), Stroke = rgb(196, 134, 24) })
	shape(c, 0.12, 0.58, 0.76, 0.18, gold, { Radius = 0.5, Stroke = rgb(196, 134, 24), Z = 2 })
	shape(c, 0.5, 0.86, 0.2, 0.2, rgb(196, 134, 24), { Circle = true, Center = true })
end

draw.trash = function(c)
	local grey = tint(c, rgb(190, 176, 190))
	shape(c, 0.24, 0.3, 0.52, 0.6, grey, { Radius = 0.15, Top = rgb(224, 214, 224), Stroke = rgb(130, 118, 134) })
	shape(c, 0.16, 0.2, 0.68, 0.12, grey, { Radius = 0.5, Stroke = rgb(130, 118, 134), Z = 2 })
	shape(c, 0.4, 0.1, 0.2, 0.1, grey, { Radius = 0.4 })
	for _, x in { 0.38, 0.5, 0.62 } do
		shape(c, x, 0.6, 0.05, 0.36, rgb(130, 118, 134), { Radius = 0.5, Center = true, Z = 3 })
	end
end

draw.magnet = function(c)
	local red = tint(c, rgb(240, 98, 98))
	shape(c, 0.16, 0.14, 0.68, 0.34, red, { Radius = 0.5, Top = rgb(255, 150, 150) })
	shape(c, 0.16, 0.3, 0.24, 0.56, red, { Radius = 0.15 })
	shape(c, 0.6, 0.3, 0.24, 0.56, red, { Radius = 0.15 })
	shape(c, 0.16, 0.74, 0.24, 0.14, rgb(240, 240, 250), { Radius = 0.15, Z = 2 })
	shape(c, 0.6, 0.74, 0.24, 0.14, rgb(240, 240, 250), { Radius = 0.15, Z = 2 })
end

draw.shoe = function(c)
	local color = tint(c, rgb(110, 170, 240))
	shape(c, 0.1, 0.3, 0.44, 0.44, color, { Radius = 0.3, Top = rgb(160, 208, 255) })
	shape(c, 0.1, 0.5, 0.82, 0.28, color, { Radius = 0.45, Top = rgb(160, 208, 255), Z = 2 })
	shape(c, 0.08, 0.72, 0.86, 0.14, rgb(250, 246, 240), { Radius = 0.5, Stroke = rgb(190, 180, 170), StrokeScale = 0.03, Z = 3 })
end

draw.egg = function(c)
	shape(c, 0.2, 0.08, 0.6, 0.84, tint(c, rgb(255, 244, 220)), { Circle = true, Top = rgb(255, 252, 240), Stroke = rgb(214, 190, 150) })
	for _, spot in { { 0.34, 0.34, 0.12 }, { 0.54, 0.5, 0.14 }, { 0.36, 0.62, 0.1 } } do
		shape(c, spot[1], spot[2], spot[3], spot[3], rgb(150, 220, 190), { Circle = true, Z = 2 })
	end
end

draw.cookie = function(c)
	shape(c, 0.06, 0.06, 0.88, 0.88, tint(c, rgb(222, 164, 100)), { Circle = true, Top = rgb(244, 196, 130), Stroke = rgb(166, 110, 60) })
	for _, spot in { { 0.3, 0.3 }, { 0.6, 0.34 }, { 0.42, 0.58 }, { 0.68, 0.62 }, { 0.26, 0.64 } } do
		shape(c, spot[1], spot[2], 0.1, 0.1, rgb(100, 64, 44), { Circle = true, Z = 2 })
	end
end

draw.heart = function(c)
	local pink = tint(c, rgb(255, 120, 160))
	shape(c, 0.1, 0.14, 0.42, 0.42, pink, { Circle = true, Top = rgb(255, 170, 196) })
	shape(c, 0.48, 0.14, 0.42, 0.42, pink, { Circle = true, Top = rgb(255, 170, 196) })
	shape(c, 0.5, 0.52, 0.5, 0.5, pink, { Rot = 45, Radius = 0.08, Center = true })
end

draw.moon = function(c)
	shape(c, 0.1, 0.1, 0.8, 0.8, tint(c, rgb(255, 232, 150)), { Circle = true, Top = rgb(255, 248, 200), Stroke = rgb(214, 180, 90) })
	for _, spot in { { 0.34, 0.3, 0.16 }, { 0.54, 0.54, 0.2 }, { 0.3, 0.62, 0.1 } } do
		shape(c, spot[1], spot[2], spot[3], spot[3], rgb(232, 206, 120), { Circle = true, Z = 2 })
	end
end

draw.rocket = function(c)
	local body = tint(c, rgb(240, 244, 255))
	shape(c, 0.5, 0.2, 0.3, 0.3, rgb(240, 98, 98), { Rot = 45, Radius = 0.1, Center = true, Z = 1 })
	shape(c, 0.34, 0.2, 0.32, 0.6, body, { Radius = 0.4, Top = WHITE, Stroke = rgb(150, 160, 190), Z = 2 })
	shape(c, 0.5, 0.42, 0.16, 0.16, rgb(122, 190, 255), { Circle = true, Center = true, Z = 3 })
	shape(c, 0.2, 0.56, 0.16, 0.28, rgb(240, 98, 98), { Radius = 0.4, Z = 1 })
	shape(c, 0.64, 0.56, 0.16, 0.28, rgb(240, 98, 98), { Radius = 0.4, Z = 1 })
	shape(c, 0.5, 0.88, 0.16, 0.2, rgb(255, 180, 60), { Circle = true, Center = true, Z = 1 })
end

draw.mountain = function(c)
	local grey = tint(c, rgb(150, 160, 190))
	shape(c, 0.34, 0.56, 0.5, 0.5, grey, { Rot = 45, Radius = 0.06, Center = true })
	shape(c, 0.66, 0.64, 0.38, 0.38, rgb(180, 190, 215), { Rot = 45, Radius = 0.06, Center = true, Z = 2 })
	shape(c, 0.34, 0.34, 0.2, 0.2, WHITE, { Rot = 45, Radius = 0.1, Center = true, Z = 3 })
end

draw.stone = function(c)
	shape(c, 0.1, 0.24, 0.8, 0.62, tint(c, rgb(170, 166, 178)), { Circle = true, Top = rgb(210, 206, 216), Stroke = rgb(110, 106, 120) })
	shape(c, 0.3, 0.36, 0.2, 0.1, rgb(130, 126, 140), { Radius = 0.5, Z = 2 })
end

draw.flower = function(c)
	local petal = tint(c, rgb(255, 150, 190))
	for step = 0, 4 do
		local angle = math.rad(step * 72 - 90)
		shape(c, 0.5 + math.cos(angle) * 0.24, 0.5 + math.sin(angle) * 0.24, 0.34, 0.34, petal, { Circle = true, Center = true })
	end
	shape(c, 0.5, 0.5, 0.26, 0.26, rgb(255, 214, 90), { Circle = true, Center = true, Z = 2 })
end

draw.cloud = function(c)
	local white = tint(c, rgb(250, 252, 255))
	shape(c, 0.1, 0.4, 0.4, 0.4, white, { Circle = true, Stroke = rgb(190, 210, 235), StrokeScale = 0.04 })
	shape(c, 0.3, 0.2, 0.46, 0.46, white, { Circle = true, Stroke = rgb(190, 210, 235), StrokeScale = 0.04 })
	shape(c, 0.52, 0.38, 0.38, 0.42, white, { Circle = true, Stroke = rgb(190, 210, 235), StrokeScale = 0.04 })
	shape(c, 0.2, 0.5, 0.6, 0.3, white, { Radius = 0.5, Z = 2 })
end

draw.sun = function(c)
	local yellow = tint(c, rgb(255, 214, 70))
	for step = 0, 3 do
		shape(c, 0.5, 0.5, 0.12, 0.96, yellow, { Rot = step * 45, Radius = 0.5, Center = true })
	end
	shape(c, 0.5, 0.5, 0.56, 0.56, yellow, { Circle = true, Center = true, Top = rgb(255, 238, 150), Z = 2 })
end

draw.hole = function(c)
	shape(c, 0.08, 0.2, 0.84, 0.64, rgb(70, 54, 66), { Circle = true, Top = rgb(40, 30, 42), Stroke = rgb(120, 96, 80) })
end

draw.roof = function(c)
	draw.home(c)
end

draw.leaf = function(c)
	local green = tint(c, rgb(110, 200, 120))
	shape(c, 0.5, 0.5, 0.6, 0.6, green, { Rot = 45, Radius = 0.5, Center = true, Top = rgb(170, 236, 160) })
	shape(c, 0.5, 0.5, 0.06, 0.62, rgb(64, 150, 84), { Rot = 45, Radius = 0.5, Center = true, Z = 2 })
end

draw.pouch = function(c)
	local color = tint(c, rgb(214, 160, 100))
	shape(c, 0.18, 0.3, 0.64, 0.62, color, { Circle = true, Top = rgb(240, 196, 140), Stroke = rgb(150, 104, 60) })
	shape(c, 0.32, 0.2, 0.36, 0.14, rgb(150, 104, 60), { Radius = 0.5, Z = 2 })
	shape(c, 0.5, 0.62, 0.2, 0.2, rgb(255, 214, 90), { Circle = true, Center = true, Z = 3 })
end

draw.bot = function(c)
	local color = tint(c, rgb(170, 190, 220))
	shape(c, 0.16, 0.26, 0.68, 0.56, color, { Radius = 0.25, Top = rgb(220, 232, 250), Stroke = rgb(100, 120, 160) })
	shape(c, 0.3, 0.42, 0.14, 0.14, rgb(80, 160, 255), { Circle = true, Z = 2 })
	shape(c, 0.56, 0.42, 0.14, 0.14, rgb(80, 160, 255), { Circle = true, Z = 2 })
	shape(c, 0.46, 0.08, 0.08, 0.2, rgb(100, 120, 160))
	shape(c, 0.5, 0.08, 0.14, 0.14, rgb(255, 120, 120), { Circle = true, Center = true })
end

draw.hourglass = function(c)
	local color = tint(c, rgb(255, 214, 120))
	shape(c, 0.2, 0.08, 0.6, 0.1, rgb(150, 104, 60), { Radius = 0.5 })
	shape(c, 0.2, 0.82, 0.6, 0.1, rgb(150, 104, 60), { Radius = 0.5 })
	shape(c, 0.5, 0.3, 0.46, 0.46, color, { Rot = 45, Radius = 0.1, Center = true, Alpha = 0.2, Stroke = rgb(150, 104, 60) })
	shape(c, 0.5, 0.7, 0.46, 0.46, color, { Rot = 45, Radius = 0.1, Center = true, Z = 2 })
end

-- Fallback for ids that don't have an icon (and the old emoji ids): a neutral rounded badge.
draw.dot = function(c)
	shape(c, 0.2, 0.2, 0.6, 0.6, tint(c, rgb(190, 176, 168)), { Circle = true, Top = rgb(224, 214, 208) })
end

-- Names used by the game's data and menus that map to a drawn icon.
local alias: { [string]: string } = {
	slot = "hamster",
	hamsters = "hamster",
	income = "coin",
	coins = "coin",
	luck = "clover",
	floor = "home",
	upgrade = "arrowup",
	upgrades = "arrowup",
	keep = "heart",
	security = "shield",
	trim = "crown",
	gems = "gem",
	rebirth = "flame",
	tokens = "flame",
	settings = "gear",
	codes = "gift",
	shop = "bag",
	daily = "gift",
	quests = "scroll",
	index = "book",
	check = "check",
	done = "check",
	locked = "lock",
}

function Icons.has(id: string): boolean
	return draw[id] ~= nil or alias[id] ~= nil
end

function Icons.names(): { string }
	local names = {}
	for id in draw do
		table.insert(names, id)
	end
	table.sort(names)
	return names
end

function Icons.create(parent: Instance?, id: string, props: Props?): Frame
	local opts = props or {}
	local size = opts.Size or UDim2.fromOffset(28, 28)
	local root = Instance.new("Frame")
	root.Name = opts.Name or ("Icon_" .. id)
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = size
	root.Position = opts.Position or UDim2.new()
	root.AnchorPoint = opts.AnchorPoint or Vector2.zero
	root.LayoutOrder = opts.LayoutOrder or 0
	root.ZIndex = opts.ZIndex or 1
	root.ClipsDescendants = false
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.Parent = root
	local drawer = draw[id] or draw[alias[id] or ""] or draw.dot
	drawer({ Root = root, Px = if size.X.Offset > 0 then size.X.Offset else 28, Tint = opts.Color })
	if opts.ZIndex then
		for _, descendant in root:GetDescendants() do
			if descendant:IsA("GuiObject") then
				descendant.ZIndex += opts.ZIndex - 1
			end
		end
	end
	if parent then
		root.Parent = parent
	end
	return root
end

return Icons
