--[[
	Icons: builds the Hamster Plaza UI icons from plain GUI objects (see Modules/IconShapes).
	No emoji (they show up as empty squares in some fonts) and no uploads needed. If an icon has an
	uploaded image id in IconShapes.Images, an ImageLabel is used instead.

	  Icons.create("Coin", 32, parent)              -> Frame (size 32 x 32)
	  Icons.create("Gem", UDim2.fromScale(1, 1), parent, { Position = ..., AnchorPoint = ... })
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local IconShapes = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("IconShapes"))

local Icons = {}

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

local function buildShape(parent: GuiObject, shape: { [string]: any }, pixelSize: number)
	local frame = Instance.new("Frame")
	frame.Name = "Shape"
	frame.BorderSizePixel = 0
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(shape.x / 100, shape.y / 100)
	frame.Size = UDim2.fromScale(shape.w / 100, shape.h / 100)
	frame.Rotation = shape.r or 0
	if shape.c then
		frame.BackgroundColor3 = hex(shape.c)
		frame.BackgroundTransparency = shape.t or 0
	else
		frame.BackgroundTransparency = 1
	end
	if shape.rad and shape.rad > 0 then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(math.min(shape.rad, 0.5), 0)
		corner.Parent = frame
	end
	if shape.g and shape.c then
		local gradient = Instance.new("UIGradient")
		gradient.Color = ColorSequence.new(hex(shape.c), hex(shape.g))
		gradient.Rotation = 90 -- top to bottom in the shape's own frame (matches the PNG export)
		gradient.Parent = frame
	end
	if shape.s and shape.sw then
		local stroke = Instance.new("UIStroke")
		stroke.Color = hex(shape.s)
		stroke.Thickness = math.max(1, shape.sw / 100 * pixelSize)
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = frame
	end
	if shape.txt then
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Text = shape.txt
		label.TextScaled = true
		label.Font = if shape.font == "body" then Enum.Font.GothamBlack else Enum.Font.FredokaOne
		label.TextColor3 = hex(shape.tc or "FFFFFF")
		label.Parent = frame
	end
	frame.Parent = parent
end

export type IconProps = { Position: UDim2?, AnchorPoint: Vector2?, ZIndex: number?, LayoutOrder: number?, Name: string? }

-- `size` is pixels (number) or a UDim2. Pixel size is used to size strokes; pass `pixelSize` in props
-- implicitly by giving a number whenever you can.
function Icons.create(name: string, size: number | UDim2, parent: Instance?, props: IconProps?): GuiObject
	local opts = props or {}
	local pixelSize = if type(size) == "number" then size else 32
	local udim = if type(size) == "number" then UDim2.fromOffset(size, size) else size

	local image = IconShapes.Images[name] or IconShapes.Images[IconShapes.Aliases[name] or ""]
	local holder: GuiObject
	if image then
		local imageLabel = Instance.new("ImageLabel")
		imageLabel.BackgroundTransparency = 1
		imageLabel.Image = image
		imageLabel.ScaleType = Enum.ScaleType.Fit
		holder = imageLabel
	else
		local frame = Instance.new("Frame")
		frame.BackgroundTransparency = 1
		holder = frame
		local shapes = IconShapes.Shapes[name] or IconShapes.Shapes.Info
		for _, shape in shapes do
			buildShape(frame, shape, pixelSize)
		end
	end
	holder.Name = opts.Name or ("Icon_" .. name)
	holder.Size = udim
	holder.Position = opts.Position or UDim2.new()
	holder.AnchorPoint = opts.AnchorPoint or Vector2.zero
	holder.LayoutOrder = opts.LayoutOrder or 0
	holder.BorderSizePixel = 0
	if opts.ZIndex then
		holder.ZIndex = opts.ZIndex
		for _, descendant in holder:GetDescendants() do
			if descendant:IsA("GuiObject") then
				descendant.ZIndex = opts.ZIndex
			end
		end
	end
	if parent then
		holder.Parent = parent
	end
	return holder
end

-- Currency name -> icon name.
Icons.Currency = {
	Coins = "Coin",
	Gems = "Gem",
	Tokens = "Token",
}

return Icons
