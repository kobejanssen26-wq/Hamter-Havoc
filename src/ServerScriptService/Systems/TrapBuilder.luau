--[[
	TrapBuilder: the 3D look of the placed traps (anchored, harmless to physics: no collision, no queries) and a small
	version for the Tool the player holds. Kinds: Spike, Glue, Banana. Pure geometry; the rules are in TrapSystem.
]]

local TrapBuilder = {}

local function color(hex: string?, fallback: Color3): Color3
	if type(hex) == "string" and #hex == 6 then
		return Color3.fromHex(hex)
	end
	return fallback
end

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, c: Color3, material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = c
	p.Material = material or Enum.Material.SmoothPlastic
	p.Shape = shape or Enum.PartType.Block
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A placed trap standing on the ground at `cframe` (its origin = a point ON the ground). Returns a Model.
function TrapBuilder.placed(kind: string, cframe: CFrame, look: any?): Model
	local look_ = look or {}
	local model = Instance.new("Model")
	model.Name = "Trap_" .. kind
	if kind == "Spike" then
		local steel = color(look_.Color, Color3.fromRGB(150, 158, 176))
		local tip = color(look_.Accent, Color3.fromRGB(255, 72, 88))
		part(model, "Plate", Vector3.new(4.4, 0.35, 4.4), cframe * CFrame.new(0, 0.18, 0), Color3.fromRGB(70, 74, 92), Enum.Material.Metal)
		for ix = -1, 1 do
			for iz = -1, 1 do
				local at = cframe * CFrame.new(ix * 1.2, 0, iz * 1.2)
				part(model, "SpikeBase", Vector3.new(0.7, 0.9, 0.7), at * CFrame.new(0, 0.8, 0), steel, Enum.Material.Metal, Enum.PartType.Cylinder).CFrame = at * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90))
				part(model, "SpikeTip", Vector3.new(0.45, 0.9, 0.45), at * CFrame.new(0, 1.55, 0), tip, Enum.Material.Neon, Enum.PartType.Ball)
			end
		end
	elseif kind == "Glue" then
		local glue = color(look_.Color, Color3.fromRGB(120, 255, 90))
		local puddle = part(model, "Puddle", Vector3.new(0.3, 6, 6), cframe * CFrame.new(0, 0.16, 0) * CFrame.Angles(0, 0, math.rad(90)), glue, Enum.Material.Glass, Enum.PartType.Cylinder)
		puddle.Transparency = 0.15
		puddle.Reflectance = 0.25
		part(model, "Blob", Vector3.new(1.6, 1.0, 1.6), cframe * CFrame.new(0.8, 0.5, -0.4), glue, Enum.Material.Glass, Enum.PartType.Ball).Transparency = 0.1
		part(model, "Bubble", Vector3.new(0.7, 0.7, 0.7), cframe * CFrame.new(-1.4, 0.5, 1.0), Color3.fromRGB(220, 255, 210), Enum.Material.Glass, Enum.PartType.Ball).Transparency = 0.3
	else -- Banana
		local peel = color(look_.Color, Color3.fromRGB(255, 226, 60))
		local brown = color(look_.Accent, Color3.fromRGB(150, 98, 40))
		part(model, "PeelA", Vector3.new(3.4, 0.35, 1.2), cframe * CFrame.new(0, 0.2, 0) * CFrame.Angles(0, 0, math.rad(8)), peel, Enum.Material.SmoothPlastic)
		for _, side in { -1, 1 } do
			part(model, "Skin", Vector3.new(2.2, 0.3, 0.9), cframe * CFrame.new(side * 0.5, 0.45, side * 0.9) * CFrame.Angles(math.rad(-25 * side), math.rad(40 * side), 0), peel, Enum.Material.SmoothPlastic)
		end
		part(model, "Stem", Vector3.new(0.45, 0.45, 0.8), cframe * CFrame.new(1.9, 0.3, 0), brown, Enum.Material.Wood)
	end
	local primary = model:FindFirstChildWhichIsA("BasePart")
	if primary then
		model.PrimaryPart = primary
	end
	return model
end

return TrapBuilder
