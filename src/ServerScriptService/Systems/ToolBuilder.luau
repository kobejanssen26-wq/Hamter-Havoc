--[[
	ToolBuilder: turns an ItemRegistry weapon into a real Roblox Tool.
	  - a Tool named after the item with attributes ItemId / WeaponType, RequiresHandle = true, cannot be dropped
	  - built-in geometry per Look.Style ("bat", "ladle", "slingshot"): a Handle plus welded parts, all massless and
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

return ToolBuilder
