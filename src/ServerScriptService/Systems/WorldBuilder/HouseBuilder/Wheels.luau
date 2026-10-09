--[[
	Hamster wheels. A wheel is built on demand when a slot is unlocked (see HouseSystem) and is turned on the
	client by the HamsterWheel tag (AmbientController): about its axle, so the floor under the running hamster
	moves BACKWARDS - the `RunDirection` attribute tells the client which way the hamster runs.
]]

local Build = require(script.Parent.Parent.Build)
local Palette = require(script.Parent.Parent.Palette)

local Wheels = {}

local WOOD = Enum.Material.WoodPlanks

Wheels.Radius = 2.3
Wheels.CenterAboveFloor = 2.7

function Wheels.build(house: any, slot: any)
	local frame: Folder = slot.Frame
	frame:ClearAllChildren()
	local center: CFrame = slot.Center
	local function C(x: number, y: number, z: number): CFrame
		return center * CFrame.new(x, y, z)
	end
	local alongZ = CFrame.Angles(0, math.rad(90), 0)

	-- stand: base plate, two A-frames, axle
	local baseY = 0.175 - Wheels.CenterAboveFloor
	Build.part(frame, "WheelBase", Vector3.new(5.6, 0.35, 3.4), C(0, baseY, 0), Palette.WoodDark, WOOD)
	local legRise = Wheels.CenterAboveFloor - 0.35
	local legOffset = 1.5
	local legLength = math.sqrt(legRise * legRise + legOffset * legOffset)
	local legTilt = math.atan2(legOffset, legRise)
	for _, z in { -1.5, 1.5 } do
		for _, side in { -1, 1 } do
			Build.part(frame, "WheelLeg", Vector3.new(0.35, legLength, 0.35), C(side * legOffset / 2, -legRise / 2, z) * CFrame.Angles(0, 0, side * legTilt), Palette.Wood, WOOD, { CanCollide = false })
		end
	end
	Build.deco(frame, "Axle", Vector3.new(3.8, 0.4, 0.4), C(0, 0, 0) * alongZ, Palette.Stone, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })

	-- the turning part: hub, two glass sides, six rungs
	local wheel = Build.model(frame, "Wheel")
	local hub = Build.deco(wheel, "Hub", Vector3.new(2.6, 0.9, 0.9), C(0, 0, 0) * alongZ, Palette.WoodLight, WOOD, { Shape = Enum.PartType.Cylinder })
	for _, z in { -1.1, 1.1 } do
		Build.deco(wheel, "Side", Vector3.new(0.12, Wheels.Radius * 2, Wheels.Radius * 2), C(0, 0, z) * alongZ, Palette.Glass, Enum.Material.Glass, { Shape = Enum.PartType.Cylinder, Transparency = 0.62 })
	end
	for rung = 0, 5 do
		local angle = rung * math.pi / 3
		Build.deco(wheel, "Rung", Vector3.new(2.3, 0.2, 0.2), C(math.cos(angle) * (Wheels.Radius - 0.1), math.sin(angle) * (Wheels.Radius - 0.1), 0) * alongZ, Palette.Gold, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	end
	wheel.PrimaryPart = hub
	-- The hamster runs along the floor's local +X (see RunCFrame). A real wheel's inner floor moves BACKWARDS
	-- under the runner, so the client turns it around  (up x runDirection)  by `Speed` radians per second.
	Build.animate(wheel, "HamsterWheel", { Speed = 0, RunDirection = house.CFrame:VectorToWorldSpace(Vector3.xAxis) })
	slot.Wheel = wheel
end

-- Creates (unlocked) or removes (locked) the wheel in a slot.
function Wheels.set(house: any, slotIndex: number, unlocked: boolean)
	local slot = house.Slots[slotIndex]
	if not slot then
		return
	end
	if unlocked and not slot.Wheel then
		Wheels.build(house, slot)
	elseif not unlocked and slot.Wheel then
		slot.Frame:ClearAllChildren()
		slot.Wheel = nil
	end
end

function Wheels.setSpeed(slot: any, speed: number)
	if slot.Wheel then
		slot.Wheel:SetAttribute("Speed", speed)
	end
end

return Wheels
