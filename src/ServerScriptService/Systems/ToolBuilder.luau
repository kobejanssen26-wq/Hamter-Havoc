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

STYLES.slingshot = function(tool: Tool, look: any)
	local wood = color(look.Color, Color3.fromRGB(138, 90, 58))
	local band = color(look.Accent, Color3.fromRGB(242, 193, 78))
	handle(tool, Vector3.new(0.5, 0.5, 1.6), wood, Enum.Material.Wood)
	part(tool, "ForkL", Vector3.new(0.3, 0.3, 1.5), CFrame.new(-0.55, 0, -1.4) * CFrame.Angles(0, math.rad(-22), 0), wood, Enum.Material.Wood)
	part(tool, "ForkR", Vector3.new(0.3, 0.3, 1.5), CFrame.new(0.55, 0, -1.4) * CFrame.Angles(0, math.rad(22), 0), wood, Enum.Material.Wood)
	part(tool, "BandL", Vector3.new(0.1, 0.1, 1.2), CFrame.new(-0.4, 0, -0.55) * CFrame.Angles(0, math.rad(28), 0), band, Enum.Material.SmoothPlastic)
	part(tool, "BandR", Vector3.new(0.1, 0.1, 1.2), CFrame.new(0.4, 0, -0.55) * CFrame.Angles(0, math.rad(-28), 0), band, Enum.Material.SmoothPlastic)
	part(tool, "Pouch", Vector3.new(0.4, 0.4, 0.4), CFrame.new(0, 0, -0.15), wood, Enum.Material.Leather, Enum.PartType.Ball)
	tool.Grip = CFrame.new(0, 0, 0.6)
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

-- Shadow Cloak: a small violet gadget (a lantern-like orb in a bracket) that is held in front of the body.
STYLES.cloak = function(tool: Tool, look: any)
	local cloth = color(look.Color, Color3.fromRGB(59, 47, 102))
	local glow = color(look.Accent, Color3.fromRGB(176, 112, 255))
	handle(tool, Vector3.new(0.4, 0.4, 1.4), Color3.fromRGB(70, 74, 92), Enum.Material.Metal)
	part(tool, "Bracket", Vector3.new(1.3, 0.25, 0.25), CFrame.new(0, 0, -0.9), Color3.fromRGB(122, 130, 150), Enum.Material.Metal)
	part(tool, "OrbL", Vector3.new(0.25, 0.9, 0.25), CFrame.new(-0.6, 0.35, -0.9), Color3.fromRGB(122, 130, 150), Enum.Material.Metal)
	part(tool, "OrbR", Vector3.new(0.25, 0.9, 0.25), CFrame.new(0.6, 0.35, -0.9), Color3.fromRGB(122, 130, 150), Enum.Material.Metal)
	local orb = part(tool, "Orb", Vector3.new(1.1, 1.1, 1.1), CFrame.new(0, 0.45, -0.9), glow, Enum.Material.Neon, Enum.PartType.Ball)
	orb.Transparency = 0.25
	part(tool, "Veil", Vector3.new(1.5, 1.2, 0.08), CFrame.new(0, -0.2, -0.9), cloth, Enum.Material.Fabric).Transparency = 0.15
	tool.Grip = CFrame.new(0, 0, 0.6)
end

-- Mirror Clone: a hand mirror with a gold frame.
STYLES.mirror = function(tool: Tool, look: any)
	local glass = color(look.Color, Color3.fromRGB(205, 239, 255))
	local gold = color(look.Accent, Color3.fromRGB(255, 211, 90))
	handle(tool, Vector3.new(0.4, 0.4, 1.8), gold, Enum.Material.Metal)
	part(tool, "Frame", Vector3.new(0.25, 1.9, 1.9), CFrame.new(0, 0, -1.55) * CFrame.Angles(0, math.rad(90), 0), gold, Enum.Material.Metal, Enum.PartType.Cylinder)
	local face = part(tool, "Glass", Vector3.new(0.18, 1.55, 1.55), CFrame.new(0, 0, -1.55) * CFrame.Angles(0, math.rad(90), 0), glass, Enum.Material.Glass, Enum.PartType.Cylinder)
	face.Reflectance = 0.45
	part(tool, "Gem", Vector3.new(0.4, 0.4, 0.3), CFrame.new(0, 1.05, -1.55), Color3.fromRGB(255, 100, 140), Enum.Material.Neon, Enum.PartType.Ball)
	tool.Grip = CFrame.new(0, 0, 0.8)
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

-- Banana Peel (held): a curved banana.
STYLES.banana = function(tool: Tool, look: any)
	local peel = color(look.Color, Color3.fromRGB(255, 226, 60))
	local brown = color(look.Accent, Color3.fromRGB(150, 98, 40))
	handle(tool, Vector3.new(0.9, 0.9, 2.6), peel, Enum.Material.SmoothPlastic)
	part(tool, "CurveA", Vector3.new(0.9, 0.9, 1.6), CFrame.new(0, 0.5, -1.5) * CFrame.Angles(math.rad(28), 0, 0), peel, Enum.Material.SmoothPlastic)
	part(tool, "CurveB", Vector3.new(0.8, 0.8, 1.2), CFrame.new(0, 1.2, -2.4) * CFrame.Angles(math.rad(55), 0, 0), peel, Enum.Material.SmoothPlastic)
	part(tool, "Stem", Vector3.new(0.4, 0.4, 0.7), CFrame.new(0, 0, 1.6), brown, Enum.Material.Wood)
	tool.Grip = CFrame.new(0, 0, 0.6)
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
