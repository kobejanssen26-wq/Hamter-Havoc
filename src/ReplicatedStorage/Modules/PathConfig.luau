--[[
	The physical hamster road. Spawn burrow (west) -> winding road -> arch around Hamster Plaza
	-> exit tunnel (east). Shared by the world builder (to lay the road) and by server/client
	(to compute where a hamster is at any moment: position = f(spawnTime, speed)).

	Control points are (x, z); the curve is a Catmull-Rom spline sampled densely and
	re-parameterised by arc length.
]]

local PathConfig = {}

PathConfig.Width = 10 -- road width in studs
PathConfig.RoadHeight = 0.28 -- top surface of the road

local CONTROL_POINTS = {
	Vector2.new(-150, -16),
	Vector2.new(-118, -16),
	Vector2.new(-86, -8),
	Vector2.new(-56, 4),
	Vector2.new(-30, 16),
	Vector2.new(-12, 24),
	Vector2.new(12, 24),
	Vector2.new(30, 16),
	Vector2.new(56, 4),
	Vector2.new(86, -8),
	Vector2.new(118, -16),
	Vector2.new(150, -16),
}

local SUBSTEPS = 24

local function catmullRom(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: number): Vector2
	local t2 = t * t
	local t3 = t2 * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end

local points: { Vector3 } = {}
local cumulative: { number } = {}

do
	local count = #CONTROL_POINTS
	for i = 1, count - 1 do
		local p0 = CONTROL_POINTS[math.max(i - 1, 1)]
		local p1 = CONTROL_POINTS[i]
		local p2 = CONTROL_POINTS[i + 1]
		local p3 = CONTROL_POINTS[math.min(i + 2, count)]
		for step = 0, SUBSTEPS - 1 do
			local point = catmullRom(p0, p1, p2, p3, step / SUBSTEPS)
			table.insert(points, Vector3.new(point.X, 0, point.Y))
		end
	end
	local last = CONTROL_POINTS[count]
	table.insert(points, Vector3.new(last.X, 0, last.Y))

	local total = 0
	cumulative[1] = 0
	for i = 2, #points do
		total += (points[i] - points[i - 1]).Magnitude
		cumulative[i] = total
	end
end

PathConfig.Points = points
PathConfig.Length = cumulative[#cumulative]
PathConfig.SpawnPoint = points[1]
PathConfig.ExitPoint = points[#points]

-- Position and unit tangent (Y = 0) at `distance` studs from the spawn burrow.
function PathConfig.pointAt(distance: number): (Vector3, Vector3)
	local length = PathConfig.Length
	local d = math.clamp(distance, 0, length)

	local low, high = 1, #cumulative
	while high - low > 1 do
		local mid = (low + high) // 2
		if cumulative[mid] <= d then
			low = mid
		else
			high = mid
		end
	end

	local a, b = points[low], points[high]
	local segment = cumulative[high] - cumulative[low]
	local alpha = if segment > 1e-6 then (d - cumulative[low]) / segment else 0
	local tangent = b - a
	if tangent.Magnitude < 1e-6 then
		tangent = Vector3.new(1, 0, 0)
	end
	return a:Lerp(b, alpha), tangent.Unit
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
