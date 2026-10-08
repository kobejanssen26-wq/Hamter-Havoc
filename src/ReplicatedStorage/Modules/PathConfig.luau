--[[
	The physical hamster road: one straight, symmetrical avenue along the X axis (z = 0).
	Spawn burrow in the west, exit tunnel in the east, Hamster Plaza exactly in the middle.
	Both house rows (north and south) are the same distance from the road, so neither side has an advantage.

	Two lanes (z = -5.5 and z = +5.5) let a fast hamster go around a slow one; see HamsterSystem.
	Shared by the world builder (to lay the road) and the server simulation.
]]

local PathConfig = {}

PathConfig.Width = 22 -- road width in studs
PathConfig.HalfWidth = PathConfig.Width / 2
PathConfig.RoadHeight = 0.28 -- top surface of the road
PathConfig.LaneOffsets = { -5.5, 5.5 }

local HALF_LENGTH = 250

local points: { Vector3 } = { Vector3.new(-HALF_LENGTH, 0, 0), Vector3.new(HALF_LENGTH, 0, 0) }

PathConfig.Points = points
PathConfig.Length = HALF_LENGTH * 2
PathConfig.SpawnPoint = points[1]
PathConfig.ExitPoint = points[2]
PathConfig.Direction = Vector3.xAxis

-- Position and unit tangent (Y = 0) at `distance` studs from the spawn burrow.
function PathConfig.pointAt(distance: number): (Vector3, Vector3)
	local d = math.clamp(distance, 0, PathConfig.Length)
	return Vector3.new(-HALF_LENGTH + d, 0, 0), Vector3.xAxis
end

-- Samples the road every `spacing` studs (used by the road builder). Returns {distance, position, tangent}.
function PathConfig.sample(spacing: number): { { Distance: number, Position: Vector3, Tangent: Vector3 } }
	local result = {}
	local distance = 0
	while distance < PathConfig.Length do
		local position, tangent = PathConfig.pointAt(distance)
		table.insert(result, { Distance = distance, Position = position, Tangent = tangent })
		distance += spacing
	end
	local position, tangent = PathConfig.pointAt(PathConfig.Length)
	table.insert(result, { Distance = PathConfig.Length, Position = position, Tangent = tangent })
	return result
end

return PathConfig
