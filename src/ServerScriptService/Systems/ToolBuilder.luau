--[[
	ToolBuilder: turns an ItemRegistry weapon into a real Roblox Tool.
	  - a Tool named after the item with attributes ItemId / WeaponType, RequiresHandle = true, cannot be dropped
	  - built-in geometry per Look.Style ("bat", "glove", "spring", "baton", "hammer", "shield", "wand", "slingshot", "cloak", "mirror"): a Handle plus welded parts, all massless and
	    non-colliding (a weapon can never trip or push anybody)
	  - or your own Tool from Studio: item.ModelName -> ReplicatedStorage/Assets/Tools/<ModelName> (needs a part named Handle)
	The tool itself does nothing: attacks are requests the server validates (CombatSystem). It only has to look right.
	Orientation: every weapon is built long along its Z axis with the business end at -Z; Grip puts the hand near the +Z end.
	(Check the look in Studio once: docs/SYSTEMS.md.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ToolBuilder = {}

local function color(hex: string?, fallback: Color3): Color3
	if type(hex) == "string" and #hex == 6 then
		return Color3.fromHex(hex)
	end
	return fallback
end

local function part(tool: Tool, name: string, size: Vector3, offset: CFrame, c: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = c
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Massless = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if handle then
		p.CFrame = handle.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = p
		weld.Parent = p
	end
	p.Parent = tool
	return p
end

local function handle(tool: Tool, size: Vector3, c: Color3, material: Enum.Material?)
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Size = size
	h.Color = c
	h.Material = material or Enum.Material.Wood
	h.Massless = true
	h.CanCollide = false
	h.CanTouch = false
	h.CanQuery = false
	h.TopSurface = Enum.SurfaceType.Smooth
	h.BottomSurface = Enum.SurfaceType.Smooth
	h.Parent = tool
	return h
end

-- a flat disc facing the front (-Z): diameter x thickness
local function disc(tool: Tool, name: string, diameter: number, thickness: number, offset: CFrame, c: Color3, material: Enum.Material?): Part
	return part(tool, name, Vector3.new(thickness, diameter, diameter), offset * CFrame.Angles(0, math.rad(90), 0), c, material, Enum.PartType.Cylinder)
end

-- a cylinder lying along Z (a rod): diameter x length
local function rod(tool: Tool, name: string, diameter: number, length: number, offset: CFrame, c: Color3, material: Enum.Material?): Part
	return part(tool, name, Vector3.new(length, diameter, diameter), offset * CFrame.Angles(0, math.rad(90), 0), c, material, Enum.PartType.Cylinder)
end

-- a thin triangular panel (WedgePart) lying flat: width (X) x length (Z)
-- (side -1: the tip points to -X, side 1: to +X; the right angle is at the back, so the triangle widens towards the back)
local function flatWedge(tool: Tool, name: string, width: number, length: number, offset: CFrame, c: Color3, material: Enum.Material?, side: number?): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = Vector3.new(0.14, width, length)
	w.Color = c
	w.Material = material or Enum.Material.Fabric
	w.Massless = true
	w.CanCollide = false
	w.CanTouch = false
	w.CanQuery = false
	local handleRef = tool:FindFirstChild("Handle") :: BasePart?
	if handleRef then
		w.CFrame = handleRef.CFrame * offset * CFrame.Angles(0, 0, math.rad(if side == 1 then -90 else 90))
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handleRef
		weld.Part1 = w
		weld.Parent = w
	end
	w.Parent = tool
	return w
end

local STYLES = {}

STYLES.bat = function(tool: Tool, look: any)
	local body = color(look.Color, Color3.fromRGB(232, 176, 112))
	local accent = color(look.Accent, Color3.fromRGB(255, 107, 107))
	handle(tool, Vector3.new(0.45, 0.45, 2.4), accent, Enum.Material.SmoothPlastic)
	part(tool, "Barrel", Vector3.new(0.9, 0.9, 2.2), CFrame.new(0, 0, -2.0), body, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(tool, "Tip", Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 0, -3.1), body, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(tool, "Knob", Vector3.new(0.75, 0.75, 0.3), CFrame.new(0, 0, 1.25), accent, Enum.Material.SmoothPlastic)
	tool.Grip = CFrame.new(0, 0, 0.9)
end

STYLES.ladle = function(tool: Tool, look: any)
	local metal = color(look.Color, Color3.fromRGB(154, 163, 181))
	local dark = color(look.Accent, Color3.fromRGB(91, 100, 117))
	handle(tool, Vector3.new(0.4, 0.4, 3.0), dark, Enum.Material.Wood)
	part(tool, "Neck", Vector3.new(0.3, 0.3, 1.2), CFrame.new(0, 0, -2.0), metal, Enum.Material.Metal)
	part(tool, "Bowl", Vector3.new(1.8, 1.8, 1.0), CFrame.new(0, 0, -3.0), metal, Enum.Material.Metal, Enum.PartType.Ball)
	part(tool, "Rim", Vector3.new(1.9, 1.9, 0.2), CFrame.new(0, 0, -3.3), dark, Enum.Material.Metal, Enum.PartType.Cylinder)
	tool.Grip = CFrame.new(0, 0, 1.2)
end

-- Seed Slingshot: a chunky wooden Y, a red rubber band, a leather pouch with a green seed in it.
STYLES.slingshot = function(tool: Tool, look: any)
	local wood = color(look.Color, Color3.fromRGB(150, 98, 60))
	local band = color(look.Accent, Color3.fromRGB(236, 72, 72))
	handle(tool, Vector3.new(0.7, 0.7, 2.0), wood, Enum.Material.Wood)
	part(tool, "GripWrap", Vector3.new(0.85, 0.85, 0.8), CFrame.new(0, 0, 0.5), Color3.fromRGB(70, 52, 44), Enum.Material.Leather, Enum.PartType.Cylinder)
	part(tool, "Fork", Vector3.new(0.8, 0.8, 0.8), CFrame.new(0, 0, -1.1), wood, Enum.Material.Wood, Enum.PartType.Ball)
	for _, side in { -1, 1 } do
		part(tool, "Arm", Vector3.new(0.5, 0.5, 1.9), CFrame.new(side * 0.62, 0, -2.0) * CFrame.Angles(0, math.rad(-side * 24), 0), wood, Enum.Material.Wood)
		part(tool, "ArmTip", Vector3.new(0.62, 0.62, 0.62), CFrame.new(side * 1.0, 0, -2.85), wood, Enum.Material.Wood, Enum.PartType.Ball)
		part(tool, "Band", Vector3.new(0.14, 0.14, 2.3), CFrame.new(side * 0.55, 0, -1.7) * CFrame.Angles(0, math.rad(side * 24), 0), band, Enum.Material.SmoothPlastic)
	end
	part(tool, "Pouch", Vector3.new(0.9, 0.5, 0.7), CFrame.new(0, 0, -0.6), Color3.fromRGB(110, 72, 48), Enum.Material.Leather)
	part(tool, "Seed", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 0.3, -0.62), Color3.fromRGB(110, 210, 90), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	tool.Grip = CFrame.new(0, 0, 0.7)
end

-- Frost Wand: a slim silver shaft, a faceted ice crystal on top, tiny snow-flake fins.
STYLES.wand = function(tool: Tool, look: any)
	local ice = color(look.Color, Color3.fromRGB(154, 216, 255))
	local frost = color(look.Accent, Color3.fromRGB(232, 247, 255))
	handle(tool, Vector3.new(0.35, 0.35, 2.6), Color3.fromRGB(122, 130, 150), Enum.Material.Metal)
	part(tool, "Grip", Vector3.new(0.5, 0.5, 0.8), CFrame.new(0, 0, 0.7), Color3.fromRGB(70, 78, 100), Enum.Material.Leather)
	part(tool, "Collar", Vector3.new(0.7, 0.7, 0.25), CFrame.new(0, 0, -1.35), frost, Enum.Material.Metal)
	local crystal = part(tool, "Crystal", Vector3.new(0.9, 0.9, 1.5), CFrame.new(0, 0, -2.25) * CFrame.Angles(0, 0, math.rad(45)), ice, Enum.Material.Ice)
	crystal.Transparency = 0.15
	part(tool, "CrystalCore", Vector3.new(0.5, 0.5, 1.1), CFrame.new(0, 0, -2.25) * CFrame.Angles(0, 0, 0), frost, Enum.Material.Neon).Transparency = 0.2
	part(tool, "FinL", Vector3.new(0.12, 0.7, 0.6), CFrame.new(-0.55, 0, -1.75) * CFrame.Angles(0, 0, math.rad(25)), ice, Enum.Material.Ice)
	part(tool, "FinR", Vector3.new(0.12, 0.7, 0.6), CFrame.new(0.55, 0, -1.75) * CFrame.Angles(0, 0, math.rad(-25)), ice, Enum.Material.Ice)
	tool.Grip = CFrame.new(0, 0, 0.8)
end

-- Shadow Cloak: a dark violet cloak hanging from a golden clasp, with a glowing moon on it and soft folds.
STYLES.cloak = function(tool: Tool, look: any)
	local cloth = color(look.Color, Color3.fromRGB(59, 47, 102))
	local glow = color(look.Accent, Color3.fromRGB(176, 112, 255))
	local gold = Color3.fromRGB(255, 206, 90)
	handle(tool, Vector3.new(0.4, 0.4, 1.6), Color3.fromRGB(70, 74, 92), Enum.Material.Metal)
	rod(tool, "ClaspBar", 0.28, 2.6, CFrame.new(0, 0.1, -1.2) * CFrame.Angles(0, math.rad(90), 0), gold, Enum.Material.Metal)
	for index, x in { -0.95, -0.32, 0.32, 0.95 } do
		local fold = if index % 2 == 0 then 6 else -6
		part(tool, "Fold" .. index, Vector3.new(0.7, 2.9, 0.16), CFrame.new(x, -1.35, -1.2) * CFrame.Angles(0, math.rad(fold), 0), if index % 2 == 0 then cloth else cloth:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Fabric)
	end
	part(tool, "Hem", Vector3.new(2.7, 0.2, 0.22), CFrame.new(0, -2.8, -1.2), glow, Enum.Material.Neon).Transparency = 0.2
	part(tool, "Clasp", Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 0.1, -1.55), gold, Enum.Material.Metal, Enum.PartType.Ball)
	part(tool, "ClaspGem", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 0.1, -1.85), glow, Enum.Material.Neon, Enum.PartType.Ball)
	local moon = part(tool, "Moon", Vector3.new(1.0, 1.0, 0.1), CFrame.new(0, -1.1, -1.36), glow, Enum.Material.Neon, Enum.PartType.Cylinder)
	moon.CFrame = moon.CFrame * CFrame.Angles(0, math.rad(90), 0)
	local bite = part(tool, "MoonShade", Vector3.new(0.9, 0.9, 0.1), CFrame.new(0.28, -1.0, -1.4), cloth, Enum.Material.Fabric, Enum.PartType.Cylinder)
	bite.CFrame = bite.CFrame * CFrame.Angles(0, math.rad(90), 0)
	tool.Grip = CFrame.new(0, 0.6, 0.9)
end

-- Mirror Clone: an ornate hand mirror - gold handle, jewelled gold ring, a bright reflective glass.
STYLES.mirror = function(tool: Tool, look: any)
	local glass = color(look.Color, Color3.fromRGB(205, 239, 255))
	local gold = color(look.Accent, Color3.fromRGB(255, 211, 90))
	handle(tool, Vector3.new(0.4, 0.4, 2.0), gold, Enum.Material.Metal)
	part(tool, "Pommel", Vector3.new(0.7, 0.7, 0.7), CFrame.new(0, 0, 1.05), gold, Enum.Material.Metal, Enum.PartType.Ball)
	part(tool, "Neck", Vector3.new(0.6, 0.6, 0.35), CFrame.new(0, 0, -1.1), Color3.fromRGB(214, 162, 52), Enum.Material.Metal, Enum.PartType.Cylinder)
	disc(tool, "FrameBack", 2.7, 0.22, CFrame.new(0, 0, -2.3), gold, Enum.Material.Metal)
	disc(tool, "FrameRing", 2.5, 0.34, CFrame.new(0, 0, -2.4), Color3.fromRGB(240, 190, 70), Enum.Material.Metal)
	local face = disc(tool, "Glass", 2.0, 0.2, CFrame.new(0, 0, -2.56), glass, Enum.Material.Glass)
	face.Reflectance = 0.5
	disc(tool, "Shine", 1.0, 0.05, CFrame.new(0.25, 0.3, -2.7), Color3.new(1, 1, 1), Enum.Material.Neon).Transparency = 0.55
	for index = 0, 7 do
		local angle = index * math.pi / 4
		part(tool, "Stud" .. index, Vector3.new(0.34, 0.34, 0.34), CFrame.new(math.sin(angle) * 1.28, math.cos(angle) * 1.28, -2.6), if index % 2 == 0 then Color3.fromRGB(255, 100, 140) else Color3.fromRGB(110, 220, 255), Enum.Material.Neon, Enum.PartType.Ball)
	end
	for _, spec in { { 0, 1.65, 0 }, { -0.62, 1.55, 18 }, { 0.62, 1.55, -18 } } do
		part(tool, "Crown", Vector3.new(0.22, 0.6, 0.22), CFrame.new(spec[1], spec[2], -2.4) * CFrame.Angles(0, 0, math.rad(spec[3])), gold, Enum.Material.Metal)
	end
	tool.Grip = CFrame.new(0, 0, 0.9)
end

-- Mega Slap Glove: a huge cartoon glove on a short cuff - cuff, round palm, four fat fingers and a thumb.
STYLES.glove = function(tool: Tool, look: any)
	local skin = color(look.Color, Color3.fromRGB(255, 214, 92))
	local cuffColor = color(look.Accent, Color3.fromRGB(255, 74, 120))
	local shade = Color3.fromRGB(214, 164, 40)
	handle(tool, Vector3.new(0.7, 0.7, 1.6), cuffColor, Enum.Material.SmoothPlastic)
	part(tool, "CuffBand", Vector3.new(1.5, 1.5, 0.5), CFrame.new(0, 0, -0.9), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(tool, "CuffRim", Vector3.new(1.7, 1.7, 0.35), CFrame.new(0, 0, -1.25), cuffColor, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(tool, "Palm", Vector3.new(2.7, 2.3, 2.1), CFrame.new(0, 0, -2.5), skin, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	for index = 0, 3 do
		local x = -0.9 + index * 0.6
		local lift = if index == 1 or index == 2 then 0.25 else 0
		part(tool, "Finger" .. index, Vector3.new(0.62, 0.62, 1.5), CFrame.new(x, 0.35 + lift, -3.75), skin, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		part(tool, "Knuckle" .. index, Vector3.new(0.45, 0.2, 0.2), CFrame.new(x, 0.9 + lift, -3.1), shade, Enum.Material.SmoothPlastic)
	end
	part(tool, "Thumb", Vector3.new(0.75, 0.75, 1.3), CFrame.new(-1.45, -0.1, -3.0) * CFrame.Angles(0, math.rad(35), 0), skin, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	tool.Grip = CFrame.new(0, 0, 0.5)
end

-- Spring Boxing Glove: a handle, a visible coil spring and a red boxing glove that punches out on the swing.
STYLES.spring = function(tool: Tool, look: any)
	local red = color(look.Color, Color3.fromRGB(235, 52, 62))
	local steel = color(look.Accent, Color3.fromRGB(190, 198, 214))
	handle(tool, Vector3.new(0.5, 0.5, 2.0), Color3.fromRGB(60, 64, 80), Enum.Material.SmoothPlastic)
	part(tool, "Plate", Vector3.new(1.4, 1.4, 0.25), CFrame.new(0, 0, -1.1), steel, Enum.Material.Metal, Enum.PartType.Cylinder)
	for coil = 0, 4 do
		part(tool, "Coil" .. coil, Vector3.new(1.05, 1.05, 0.16), CFrame.new(0, 0, -1.5 - coil * 0.34), if coil % 2 == 0 then steel else Color3.fromRGB(128, 136, 156), Enum.Material.Metal, Enum.PartType.Cylinder)
	end
	part(tool, "Rod", Vector3.new(0.3, 0.3, 1.8), CFrame.new(0, 0, -2.3), Color3.fromRGB(128, 136, 156), Enum.Material.Metal)
	part(tool, "Fist", Vector3.new(2.7, 2.5, 2.6), CFrame.new(0, 0.1, -4.0), red, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(tool, "FistThumb", Vector3.new(0.9, 0.9, 1.4), CFrame.new(-1.2, 0.2, -3.5) * CFrame.Angles(0, math.rad(25), 0), red, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	part(tool, "FistCuff", Vector3.new(1.7, 1.7, 0.45), CFrame.new(0, 0, -2.95), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(tool, "FistStripe", Vector3.new(1.2, 0.3, 0.9), CFrame.new(0, 1.15, -4.2), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
	tool.Grip = CFrame.new(0, 0, 0.8)
end

-- Shock Baton: black grip, silver shaft, three glowing coils and a spark ball on the tip.
STYLES.baton = function(tool: Tool, look: any)
	local glow = color(look.Color, Color3.fromRGB(70, 220, 255))
	local metal = color(look.Accent, Color3.fromRGB(170, 178, 196))
	handle(tool, Vector3.new(0.5, 0.5, 1.9), Color3.fromRGB(32, 34, 44), Enum.Material.SmoothPlastic)
	for ring = 0, 2 do
		part(tool, "GripRing" .. ring, Vector3.new(0.68, 0.68, 0.14), CFrame.new(0, 0, 0.5 - ring * 0.45), Color3.fromRGB(60, 64, 80), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	end
	part(tool, "Shaft", Vector3.new(0.36, 0.36, 3.0), CFrame.new(0, 0, -2.4), metal, Enum.Material.Metal)
	for coil = 0, 2 do
		part(tool, "Coil" .. coil, Vector3.new(0.78, 0.78, 0.2), CFrame.new(0, 0, -2.0 - coil * 0.75), glow, Enum.Material.Neon, Enum.PartType.Cylinder)
	end
	part(tool, "TipCap", Vector3.new(0.6, 0.6, 0.35), CFrame.new(0, 0, -4.05), metal, Enum.Material.Metal, Enum.PartType.Cylinder)
	local spark = part(tool, "Spark", Vector3.new(0.85, 0.85, 0.85), CFrame.new(0, 0, -4.5), glow, Enum.Material.Neon, Enum.PartType.Ball)
	spark.Transparency = 0.1
	tool.Grip = CFrame.new(0, 0, 0.8)
end

-- Party Hammer: a stout handle and a big striped energy head.
STYLES.hammer = function(tool: Tool, look: any)
	local head = color(look.Color, Color3.fromRGB(255, 90, 200))
	local accent = color(look.Accent, Color3.fromRGB(255, 226, 80))
	handle(tool, Vector3.new(0.55, 0.55, 3.4), Color3.fromRGB(110, 70, 140), Enum.Material.SmoothPlastic)
	part(tool, "GripWrap", Vector3.new(0.7, 0.7, 1.2), CFrame.new(0, 0, 1.0), accent, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(tool, "Pommel", Vector3.new(0.9, 0.9, 0.5), CFrame.new(0, 0, 1.9), accent, Enum.Material.Neon, Enum.PartType.Ball)
	part(tool, "HeadCore", Vector3.new(3.4, 1.7, 1.9), CFrame.new(0, 0, -2.2), head, Enum.Material.Neon)
	part(tool, "HeadBandA", Vector3.new(3.5, 1.8, 0.4), CFrame.new(0, 0, -1.5), accent, Enum.Material.SmoothPlastic)
	part(tool, "HeadBandB", Vector3.new(3.5, 1.8, 0.4), CFrame.new(0, 0, -2.9), accent, Enum.Material.SmoothPlastic)
	part(tool, "CapL", Vector3.new(0.5, 2.1, 2.1), CFrame.new(-1.9, 0, -2.2), Color3.fromRGB(70, 220, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
	part(tool, "CapR", Vector3.new(0.5, 2.1, 2.1), CFrame.new(1.9, 0, -2.2), Color3.fromRGB(70, 220, 255), Enum.Material.Neon, Enum.PartType.Cylinder)
	tool.Grip = CFrame.new(0, 0, 1.1)
end

-- Bubble Shield: a round shield held in front of the body, with a glowing centre and a rim.
STYLES.shield = function(tool: Tool, look: any)
	local face = color(look.Color, Color3.fromRGB(76, 168, 255))
	local rim = color(look.Accent, Color3.fromRGB(255, 226, 80))
	handle(tool, Vector3.new(0.45, 0.45, 1.0), Color3.fromRGB(60, 64, 80), Enum.Material.SmoothPlastic)
	local disc = part(tool, "Disc", Vector3.new(0.35, 3.8, 3.8), CFrame.new(0, 0, -1.0) * CFrame.Angles(0, math.rad(90), 0), face, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	disc.Reflectance = 0.1
	part(tool, "Rim", Vector3.new(0.5, 4.2, 4.2), CFrame.new(0, 0, -0.9) * CFrame.Angles(0, math.rad(90), 0), rim, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(tool, "Boss", Vector3.new(0.7, 1.3, 1.3), CFrame.new(0, 0, -1.35) * CFrame.Angles(0, math.rad(90), 0), rim, Enum.Material.Neon, Enum.PartType.Cylinder)
	part(tool, "BarH", Vector3.new(3.0, 0.35, 0.2), CFrame.new(0, 0, -1.25), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
	part(tool, "BarV", Vector3.new(0.35, 3.0, 0.2), CFrame.new(0, 0, -1.25), Color3.fromRGB(255, 255, 255), Enum.Material.SmoothPlastic)
	tool.Grip = CFrame.new(0, 0, 0.3)
end

-- Spike Trap (held): a steel plate with a ring of red-tipped spikes, carried flat in front of you.
STYLES.spiketrap = function(tool: Tool, look: any)
	local steel = color(look.Color, Color3.fromRGB(150, 158, 176))
	local tip = color(look.Accent, Color3.fromRGB(255, 72, 88))
	handle(tool, Vector3.new(2.6, 0.4, 2.6), Color3.fromRGB(70, 74, 92), Enum.Material.Metal)
	for ix = -1, 1 do
		for iz = -1, 1 do
			part(tool, "Spike", Vector3.new(0.35, 0.9, 0.35), CFrame.new(ix * 0.8, 0.6, iz * 0.8), steel, Enum.Material.Metal, Enum.PartType.Cylinder)
			part(tool, "SpikeTip", Vector3.new(0.4, 0.5, 0.4), CFrame.new(ix * 0.8, 1.1, iz * 0.8), tip, Enum.Material.Neon, Enum.PartType.Ball)
		end
	end
	tool.Grip = CFrame.new(0, -0.2, 0) * CFrame.Angles(math.rad(-90), 0, 0)
end

-- Glue Puddle (held): a jar of glowing green goo with a drip.
STYLES.gluetrap = function(tool: Tool, look: any)
	local glue = color(look.Color, Color3.fromRGB(120, 255, 90))
	handle(tool, Vector3.new(1.8, 2.0, 1.8), Color3.fromRGB(210, 235, 255), Enum.Material.Glass).Transparency = 0.5
	part(tool, "Goo", Vector3.new(1.5, 1.4, 1.5), CFrame.new(0, -0.2, 0), glue, Enum.Material.Neon, Enum.PartType.Ball)
	part(tool, "Lid", Vector3.new(1.4, 0.4, 1.4), CFrame.new(0, 1.1, 0), Color3.fromRGB(255, 84, 170), Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	part(tool, "Drip", Vector3.new(0.5, 0.8, 0.5), CFrame.new(0.8, -1.0, 0.2), glue, Enum.Material.Neon, Enum.PartType.Ball)
	tool.Grip = CFrame.new(0, -0.4, 0)
end

-- Banana Peel (held): a smooth curved banana made of overlapping segments, with a brown stem and tip.
STYLES.banana = function(tool: Tool, look: any)
	local peel = color(look.Color, Color3.fromRGB(255, 226, 60))
	local brown = color(look.Accent, Color3.fromRGB(150, 98, 40))
	handle(tool, Vector3.new(0.5, 0.5, 0.5), peel, Enum.Material.SmoothPlastic).Transparency = 1 -- (the grip point, hidden inside the banana)
	local radius = 2.6
	local function at(t: number): CFrame
		-- an arc in the Y-Z plane that bends up at both ends
		return CFrame.new(0, radius * (1 - math.cos(t)), radius * math.sin(t)) * CFrame.Angles(-t, 0, 0)
	end
	for index = -5, 5 do
		local size = 1.0 - math.abs(index) * 0.045
		part(tool, "Segment" .. index, Vector3.new(size, size, 0.95), at(index * 0.15) * CFrame.new(0, -0.4, 0), peel, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	end
	part(tool, "Stem", Vector3.new(0.4, 0.4, 0.8), at(0.78) * CFrame.new(0, -0.3, 0.55), brown, Enum.Material.Wood, Enum.PartType.Cylinder)
	part(tool, "Tip", Vector3.new(0.46, 0.46, 0.46), at(-0.78) * CFrame.new(0, -0.35, -0.55), brown, Enum.Material.Wood, Enum.PartType.Ball)
	part(tool, "Spot", Vector3.new(0.3, 0.3, 0.3), at(0.2) * CFrame.new(0.4, -0.1, 0), brown, Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	tool.Grip = CFrame.new(0, 0.1, 0)
end

-- Sky Glider (held): a small hang glider - a golden keel, two bright sail panels with stripes, struts down to a control bar.
STYLES.glider = function(tool: Tool, look: any)
	local sail = color(look.Color, Color3.fromRGB(255, 92, 168))
	local trim = color(look.Accent, Color3.fromRGB(255, 214, 92))
	local steel = Color3.fromRGB(70, 74, 92)
	handle(tool, Vector3.new(0.4, 0.4, 1.4), steel, Enum.Material.Metal)
	rod(tool, "Keel", 0.3, 4.4, CFrame.new(0, 1.3, -1.7), trim, Enum.Material.Metal)
	part(tool, "Nose", Vector3.new(0.5, 0.5, 0.5), CFrame.new(0, 1.3, -3.95), trim, Enum.Material.Metal, Enum.PartType.Ball)
	for _, side in { -1, 1 } do
		flatWedge(tool, "Sail", 2.9, 4.0, CFrame.new(side * 1.45, 1.34, -1.85), sail, Enum.Material.Fabric, side)
		flatWedge(tool, "Stripe", 1.15, 4.0, CFrame.new(side * 0.58, 1.43, -1.85), trim, Enum.Material.Fabric, side)
		rod(tool, "Spar", 0.16, 3.3, CFrame.new(side * 1.5, 1.45, -1.2) * CFrame.Angles(0, math.rad(side * 36), 0), steel, Enum.Material.Metal)
		part(tool, "Strut", Vector3.new(0.14, 0.14, 1.5), CFrame.new(side * 0.42, 0.62, -0.1) * CFrame.Angles(math.rad(-35), 0, math.rad(side * 22)), steel, Enum.Material.Metal)
	end
	part(tool, "ControlBar", Vector3.new(1.0, 0.14, 0.14), CFrame.new(0, 0.05, 0.4), steel, Enum.Material.Metal)
	tool.Grip = CFrame.new(0, -0.1, 0.4)
end

-- Rocket Booster (held): a cartoon rocket with a nose cone, window, fins and an exhaust that lights up when it fires.
STYLES.rocket = function(tool: Tool, look: any)
	local body = color(look.Color, Color3.fromRGB(255, 74, 88))
	local trim = color(look.Accent, Color3.fromRGB(255, 224, 102))
	handle(tool, Vector3.new(0.5, 0.5, 1.4), Color3.fromRGB(70, 74, 92), Enum.Material.Metal)
	rod(tool, "Body", 1.35, 2.7, CFrame.new(0, 0, -1.9), body, Enum.Material.SmoothPlastic)
	part(tool, "Nose", Vector3.new(1.3, 1.3, 1.9), CFrame.new(0, 0, -3.75), Color3.fromRGB(250, 250, 255), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
	rod(tool, "BandA", 1.45, 0.25, CFrame.new(0, 0, -2.9), trim, Enum.Material.SmoothPlastic)
	rod(tool, "BandB", 1.45, 0.25, CFrame.new(0, 0, -1.0), trim, Enum.Material.SmoothPlastic)
	local window = part(tool, "Window", Vector3.new(0.7, 0.7, 0.35), CFrame.new(0, 0.62, -2.0), Color3.fromRGB(140, 220, 255), Enum.Material.Glass, Enum.PartType.Ball)
	window.Reflectance = 0.3
	for index = 0, 2 do
		local angle = math.rad(index * 120)
		part(tool, "Fin" .. index, Vector3.new(0.14, 1.0, 1.1), CFrame.new(math.sin(angle) * 0.85, math.cos(angle) * 0.85, -0.6) * CFrame.Angles(0, 0, -angle), trim, Enum.Material.SmoothPlastic)
	end
	rod(tool, "Nozzle", 0.9, 0.5, CFrame.new(0, 0, -0.45), Color3.fromRGB(110, 116, 140), Enum.Material.Metal)
	local exhaust = part(tool, "Exhaust", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 0, 0.1), Color3.fromRGB(255, 160, 60), Enum.Material.Neon, Enum.PartType.Ball)
	exhaust.Transparency = 1
	local flame = Instance.new("ParticleEmitter")
	flame.Name = "Flame"
	flame.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 80, 40))
	flame.LightEmission = 0.8
	flame.Lifetime = NumberRange.new(0.3, 0.6)
	flame.Rate = 60
	flame.Speed = NumberRange.new(6, 10)
	flame.SpreadAngle = Vector2.new(14, 14)
	flame.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	flame.EmissionDirection = Enum.NormalId.Back
	flame.Enabled = false -- MobilitySystem switches it on while the rocket fires
	flame.Parent = exhaust
	tool.Grip = CFrame.new(0, 0, 0.5)
end

function ToolBuilder.build(def: any): Tool
	local tool: Tool
	local custom = nil
	if def.ModelName then
		local assets = ReplicatedStorage:FindFirstChild("Assets")
		local folder = assets and assets:FindFirstChild("Tools")
		custom = folder and folder:FindFirstChild(def.ModelName)
	end
	if custom and custom:IsA("Tool") and custom:FindFirstChild("Handle") then
		tool = custom:Clone()
		for _, descendant in tool:GetDescendants() do
			if descendant:IsA("Script") or descendant:IsA("LocalScript") then
				descendant:Destroy() -- a weapon is configuration + server validation, never scripts of its own
			end
		end
	else
		tool = Instance.new("Tool")
		local look = def.Equip.Weapon.Look or {}
		local style = STYLES[look.Style] or STYLES.bat
		style(tool, look)
	end
	tool.Name = def.DisplayName
	tool.ToolTip = def.DisplayName
	tool.RequiresHandle = true
	tool.CanBeDropped = false
	tool.ManualActivationOnly = false
	tool:SetAttribute("ItemId", def.Id)
	tool:SetAttribute("WeaponType", def.Equip.Weapon.Type)
	return tool
end

-- Publishes a non-interactive MODEL of every weapon to ReplicatedStorage/Assets/WeaponPreviews/<ItemId>, so the shop and the
-- backpack can show the REAL model in a ViewportFrame (what you see is exactly what you hold). Parts only, anchored, no scripts.
function ToolBuilder.publishPreviews()
	local ItemRegistry = require(ReplicatedStorage.Modules.ItemRegistry)
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = ReplicatedStorage
	end
	local old = assets:FindFirstChild("WeaponPreviews")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "WeaponPreviews"
	for _, def in ItemRegistry.List do
		if def.Equip.Kind == "Tool" then
			local tool = ToolBuilder.build(def)
			local model = Instance.new("Model")
			model.Name = def.Id
			for _, child in tool:GetChildren() do
				if child:IsA("BasePart") then
					child.Anchored = true
					child.Parent = model
				end
			end
			local handle = model:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				model.PrimaryPart = handle
			end
			tool:Destroy()
			model.Parent = folder
		end
	end
	folder.Parent = assets
end

return ToolBuilder
