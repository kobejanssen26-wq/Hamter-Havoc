local Players = game:GetService("Players")

local PartUtil = {}

-- Creates an anchored, smooth part. `props` overrides anything.
function PartUtil.create(name: string, size: Vector3, cframe: CFrame, props: { [string]: any }?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in props do
			(part :: any)[key] = value
		end
	end
	return part
end

-- Welds `part` to `anchor` at their current relative position and un-anchors `part`.
function PartUtil.weld(part: BasePart, anchor: BasePart)
	part.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = part
	weld.Parent = part
end

-- Walks up from any part (e.g. an accessory or a carried hamster) to the owning player.
function PartUtil.getPlayerFromPart(part: Instance): Player?
	local current: Instance? = part
	while current and current ~= workspace do
		local player = Players:GetPlayerFromCharacter(current)
		if player then
			return player
		end
		current = current.Parent
	end
	return nil
end

return PartUtil
