--[[
	Where everything is. Shared by the world builder, the hamster simulation and the client.

	Top view (x to the right, z up). Everything is mirror-symmetric around both axes:

	      [house][house]      plaza gap       [house][house]        north row
	   ------- promenade (transit hamsters roll home here) -------
	   ===== road: burrow ->  ARCH / Hamster Plaza  -> exit tunnel =====
	   ------- promenade -------
	      [house][house]      plaza gap       [house][house]        south row

	House frame (local): origin = the middle of the gate line, +Z = into the lot, +X = to the right of
	someone standing at the gate looking in. South-row houses are the north row rotated 180 degrees.
]]

local Route = require(script.Parent.Route)

local WorldLayout = {}

WorldLayout.HouseColumns = { -108, -44, 44, 108 }
WorldLayout.HouseCount = #WorldLayout.HouseColumns * 2

WorldLayout.GateDistance = 27 -- |z| of the gate line
WorldLayout.LotHalfWidth = 24
WorldLayout.LotDepth = 58

WorldLayout.RoadHalfWidth = 8
WorldLayout.PromenadeZ = 18 -- |z| of the promenade centre line
WorldLayout.PromenadeHalfWidth = 7

WorldLayout.GroundHalfX = 185
WorldLayout.GroundHalfZ = 112

-- inside the house (local)
WorldLayout.DoorZ = 17
WorldLayout.PadLocal = Vector3.new(0, 0.6, 24) -- arrival pad: hamsters are secured here
WorldLayout.SecureRadius = 7 -- a carrier this close to the pad secures

function WorldLayout.houseCFrame(index: number): CFrame
	local columns = WorldLayout.HouseColumns
	if index <= #columns then
		return CFrame.new(columns[index], 0, WorldLayout.GateDistance)
	end
	return CFrame.new(columns[index - #columns], 0, -WorldLayout.GateDistance) * CFrame.Angles(0, math.pi, 0)
end

-- +1 for the north row (z > 0), -1 for the south row.
function WorldLayout.side(index: number): number
	return if index <= #WorldLayout.HouseColumns then 1 else -1
end

function WorldLayout.padPosition(houseCFrame: CFrame): Vector3
	return houseCFrame:PointToWorldSpace(WorldLayout.PadLocal)
end

-- Is this world position inside the house lot (fence line to back hedge)? `margin` grows the box.
function WorldLayout.inLot(houseCFrame: CFrame, position: Vector3, margin: number?): boolean
	local m = margin or 0
	local localPosition = houseCFrame:PointToObjectSpace(position)
	return math.abs(localPosition.X) <= WorldLayout.LotHalfWidth + m
		and localPosition.Z >= -m
		and localPosition.Z <= WorldLayout.LotDepth + m
end

-- How wide the rollable corridor is at this spot (half width). Balls stay inside it.
function WorldLayout.corridorHalfWidth(position: Vector3): number
	local z = math.abs(position.Z)
	if z < 9.5 then
		return WorldLayout.RoadHalfWidth
	elseif z < WorldLayout.GateDistance - 0.5 then
		return WorldLayout.PromenadeHalfWidth
	end
	return 4.2 -- driveway and doorway (the double door is 8.4 wide)
end

-- Waypoints that roll a ball from `from` (road or promenade) to the pad of a house.
function WorldLayout.transitPoints(houseCFrame: CFrame, from: Vector3): { Vector3 }
	local side = if houseCFrame.LookVector.Z > 0 then 1 else -1
	local houseX = houseCFrame.Position.X
	local points: { Vector3 } = { Vector3.new(from.X, from.Y, from.Z) }

	-- leave the road / promenade and join the promenade centre line on the way
	local dx = houseX - from.X
	local direction = if math.abs(dx) < 1 then 0 else (if dx > 0 then 1 else -1)
	local onPromenade = math.abs(from.Z - side * WorldLayout.PromenadeZ) < 3
	if not onPromenade then
		local lead = if direction == 0 then 0 else math.min(16, math.abs(dx) * 0.5)
		table.insert(points, Vector3.new(from.X + direction * lead, 0.1, side * (WorldLayout.PromenadeZ - 4)))
	end
	table.insert(points, Vector3.new(houseX, 0.1, side * WorldLayout.PromenadeZ))
	for _, localPoint in { Vector3.new(0, 0.1, 0), Vector3.new(0, 0.1, 12), Vector3.new(0, 0.6, WorldLayout.DoorZ + 1.5), WorldLayout.PadLocal } do
		table.insert(points, houseCFrame:PointToWorldSpace(localPoint))
	end
	return points
end

function WorldLayout.transitRoute(houseCFrame: CFrame, from: Vector3): Route.Route
	return Route.new(WorldLayout.transitPoints(houseCFrame, from), 5)
end

return WorldLayout
