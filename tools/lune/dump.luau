--[[ Shared helper: turn every visible BasePart under an instance into plain data (for render.py / export). ]]
local roblox = require("@lune/roblox")
local Enum = roblox.Enum
local Vector3 = roblox.Vector3

local Dump = {}

local function shapeOf(part): string
	local mesh = part:FindFirstChildOfClass("SpecialMesh")
	if mesh then
		if mesh.MeshType == Enum.MeshType.Sphere then
			return "sphere"
		elseif mesh.MeshType == Enum.MeshType.Cylinder then
			return "cylinder"
		elseif mesh.MeshType == Enum.MeshType.Wedge then
			return "wedge"
		end
	end
	if part:IsA("WedgePart") then
		return "wedge"
	elseif part:IsA("CornerWedgePart") then
		return "cornerwedge"
	elseif part:IsA("Part") then
		local shape = part.Shape
		if shape == Enum.PartType.Ball then
			return "ball"
		elseif shape == Enum.PartType.Cylinder then
			return "cylinder"
		end
	end
	return "box"
end

function Dump.part(part, root)
	local mesh = part:FindFirstChildOfClass("SpecialMesh")
	local size = part.Size
	if mesh and mesh.MeshType ~= Enum.MeshType.FileMesh then
		size = Vector3.new(size.X * mesh.Scale.X, size.Y * mesh.Scale.Y, size.Z * mesh.Scale.Z)
	end
	local cf = part.CFrame
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	local c = part.Color
	return {
		n = part.Name,
		p = if root then string.sub(part:GetFullName(), #root:GetFullName() + 2) else part:GetFullName(),
		s = shapeOf(part),
		cf = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 },
		sz = { size.X, size.Y, size.Z },
		c = { c.R, c.G, c.B },
		t = part.Transparency,
		m = part.Material.Name,
	}
end

function Dump.collect(root, list)
	list = list or {}
	local all = root:GetDescendants()
	if root:IsA("BasePart") then
		table.insert(all, 1, root)
	end
	for _, d in all do
		if d:IsA("BasePart") and d.Transparency < 0.98 then
			table.insert(list, Dump.part(d, root))
		end
	end
	return list
end

return Dump
