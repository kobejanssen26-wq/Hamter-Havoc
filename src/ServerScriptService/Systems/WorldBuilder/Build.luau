--[[
	Tiny part-construction toolkit for the world builder. Everything is anchored static scenery.
]]

local Build = {}

local PLASTIC = Enum.Material.SmoothPlastic

function Build.folder(parent: Instance, name: string): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function Build.model(parent: Instance, name: string): Model
	local model = Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

function Build.part(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	props: { [string]: any }?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material or PLASTIC
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in props do
			(part :: any)[key] = value
		end
	end
	part.Parent = parent
	return part
end

-- Decoration that never needs collisions (flowers, trims, signs' details...).
function Build.deco(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	props: { [string]: any }?
): Part
	local merged = { CanCollide = false, CanTouch = false, CastShadow = false }
	if props then
		for key, value in props do
			merged[key] = value
		end
	end
	return Build.part(parent, name, size, cframe, color, material, merged)
end

-- Rounded ellipsoid (block part rendered with a sphere mesh). Great for bushes, canopies, cushions.
function Build.blob(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	props: { [string]: any }?
): Part
	local part = Build.part(parent, name, size, cframe, color, material, props)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Upright cylinder. `center` is the middle of the cylinder.
function Build.pillar(
	parent: Instance,
	name: string,
	diameter: number,
	height: number,
	center: CFrame,
	color: Color3,
	material: Enum.Material?,
	props: { [string]: any }?
): Part
	local merged = { Shape = Enum.PartType.Cylinder }
	if props then
		for key, value in props do
			merged[key] = value
		end
	end
	return Build.part(parent, name, Vector3.new(height, diameter, diameter), center * CFrame.Angles(0, 0, math.rad(90)), color, material, merged)
end

function Build.wedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material?,
	props: { [string]: any }?
): WedgePart
	local wedge = Instance.new("WedgePart")
	wedge.Name = name
	wedge.Anchored = true
	wedge.Size = size
	wedge.CFrame = cframe
	wedge.Color = color
	wedge.Material = material or PLASTIC
	if props then
		for key, value in props do
			(wedge :: any)[key] = value
		end
	end
	wedge.Parent = parent
	return wedge
end

-- One right-angled wedge whose right angle sits at `right`, with the legs going to `far` (the long leg, along the ground
-- of the wedge) and `top` (the short leg, "up"). The two legs must be perpendicular.
local function rightWedge(parent: Instance, right: Vector3, far: Vector3, top: Vector3, thickness: number, color: Color3, material: Enum.Material?, props: { [string]: any }?): WedgePart?
	local legZ = far - right
	local up = top - right
	local length, height = legZ.Magnitude, up.Magnitude
	if length < 0.05 or height < 0.05 then
		return nil
	end
	local yAxis = up / height
	local zAxis = -legZ / length -- a WedgePart's right angle is at its back-bottom; the long leg runs towards the front (-Z)
	local xAxis = yAxis:Cross(zAxis)
	return Build.wedge(parent, "Facet", Vector3.new(thickness, height, length), CFrame.fromMatrix(right + up / 2 + legZ / 2, xAxis, yAxis, zAxis), color, material, props)
end

-- A flat triangle a-b-c made of two wedges (the classic Roblox technique). Used for faceted scenery such as mountains:
-- neighbouring triangles that share vertices meet without gaps.
function Build.triangle(parent: Instance, a: Vector3, b: Vector3, c: Vector3, color: Color3, material: Enum.Material?, props: { [string]: any }?, thickness: number?): number
	local lengths = { (b - a).Magnitude, (c - b).Magnitude, (a - c).Magnitude }
	local p, q, r = a, b, c -- p-q becomes the longest edge, r the opposite corner
	if lengths[2] >= lengths[1] and lengths[2] >= lengths[3] then
		p, q, r = b, c, a
	elseif lengths[3] >= lengths[1] and lengths[3] >= lengths[2] then
		p, q, r = c, a, b
	end
	local edge = q - p
	local longest = edge.Magnitude
	if longest < 0.1 then
		return 0
	end
	local direction = edge / longest
	local foot = p + direction * (r - p):Dot(direction)
	local count = 0
	local t = thickness or 0.4
	if rightWedge(parent, foot, p, r, t, color, material, props) then
		count += 1
	end
	if rightWedge(parent, foot, q, r, t, color, material, props) then
		count += 1
	end
	return count
end

-- Text printed on one face of a part.
function Build.surfaceText(
	part: BasePart,
	face: Enum.NormalId,
	text: string,
	options: { TextColor: Color3?, Font: Enum.Font?, PixelsPerStud: number?, Background: Color3?, BackgroundTransparency: number? }?
): TextLabel
	local opts = options or {}
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = opts.PixelsPerStud or 40
	gui.LightInfluence = 0.2
	gui.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = opts.BackgroundTransparency or 1
	if opts.Background then
		label.BackgroundColor3 = opts.Background
	end
	label.TextColor3 = opts.TextColor or Color3.new(1, 1, 1)
	label.Font = opts.Font or Enum.Font.FredokaOne
	label.RichText = true
	label.TextScaled = true
	label.Text = text
	label.Parent = gui
	return label
end

-- Floating billboard label that always faces the camera.
function Build.billboard(
	parent: BasePart,
	text: string,
	size: Vector2,
	offset: Vector3,
	options: { MaxDistance: number?, TextColor: Color3?, Font: Enum.Font?, Name: string? }?
): TextLabel
	local opts = options or {}
	local gui = Instance.new("BillboardGui")
	gui.Name = opts.Name or "Billboard"
	gui.Size = UDim2.fromOffset(size.X, size.Y)
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = opts.MaxDistance or 90
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = opts.TextColor or Color3.new(1, 1, 1)
	label.Font = opts.Font or Enum.Font.FredokaOne
	label.RichText = true
	label.TextScaled = true
	label.TextStrokeTransparency = 0.45
	label.Text = text
	label.Parent = gui
	return label
end

function Build.light(parent: Instance, color: Color3, brightness: number, range: number): PointLight
	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = parent
	return light
end

-- Marks an object as something the tutorial can point at ("Base", "Bench", "Gate", "Upgrade", "Altar", "Leaderboard").
-- The client finds it by tag + attribute (never by coordinates), so moving or rebuilding the object cannot break the guide.
-- Objects inside a house are only offered to the house's owner (the house Model's OwnerUserId attribute).
function Build.target(instance: Instance, name: string)
	instance:SetAttribute("TutorialTarget", name)
	instance:AddTag("TutorialTarget")
end

-- Client animates anything carrying these tags (see DecorAnimator).
function Build.animate(instance: Instance, tag: string, attributes: { [string]: any }?)
	-- attributes first: the client reads them the moment the tag appears
	instance:SetAttribute("AnimTag", tag) -- (Restore re-adds the tag when a saved copy of the world lost it)
	if attributes then
		for key, value in attributes do
			instance:SetAttribute(key, value)
		end
	end
	instance:AddTag(tag)
end

return Build
