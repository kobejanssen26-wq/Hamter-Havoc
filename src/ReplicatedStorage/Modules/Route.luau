--[[
	Route: a smooth polyline. Corners are rounded with quadratic curves so rolling hamster balls
	turn smoothly instead of snapping. Pure math, no Roblox state: used by the server simulation.

	local route = Route.new({ a, b, c, d }, 5)
	local position, tangent = route:pointAt(distance)
]]

local Route = {}
Route.__index = Route

export type Route = typeof(setmetatable({} :: {
	Points: { Vector3 },
	Cumulative: { number },
	Length: number,
}, Route))

local CORNER_STEPS = 6

function Route.new(source: { Vector3 }, cornerRadius: number?): Route
	local radius = cornerRadius or 4
	local smooth: { Vector3 } = {}

	local function push(point: Vector3)
		local last = smooth[#smooth]
		if not last or (point - last).Magnitude > 0.01 then
			table.insert(smooth, point)
		end
	end

	push(source[1])
	for i = 2, #source - 1 do
		local a, b, c = source[i - 1], source[i], source[i + 1]
		local toA = a - b
		local toC = c - b
		if toA.Magnitude < 0.01 or toC.Magnitude < 0.01 then
			push(b)
		else
			local r = math.min(radius, toA.Magnitude / 2, toC.Magnitude / 2)
			local p1 = b + toA.Unit * r
			local p2 = b + toC.Unit * r
			for k = 0, CORNER_STEPS do
				local t = k / CORNER_STEPS
				local u = 1 - t
				push(p1 * (u * u) + b * (2 * u * t) + p2 * (t * t))
			end
		end
	end
	push(source[#source])

	local cumulative = { 0 }
	local total = 0
	for i = 2, #smooth do
		total += (smooth[i] - smooth[i - 1]).Magnitude
		cumulative[i] = total
	end

	return setmetatable({ Points = smooth, Cumulative = cumulative, Length = total }, Route)
end

-- Position (with Y interpolated) and unit tangent at `distance` along the route.
function Route.pointAt(self: Route, distance: number): (Vector3, Vector3)
	local points, cumulative = self.Points, self.Cumulative
	local count = #points
	if count == 1 then
		return points[1], Vector3.xAxis
	end
	local d = math.clamp(distance, 0, self.Length)
	local low, high = 1, count
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
		tangent = Vector3.xAxis
	end
	return a:Lerp(b, alpha), tangent.Unit
end

-- Closest distance along the route to `position` (XZ only). Used to re-attach after a push.
function Route.project(self: Route, position: Vector3, near: number?, window: number?): number
	local points, cumulative = self.Points, self.Cumulative
	local best, bestDistance = 0, math.huge
	local from = if near and window then math.max(1, self:indexAt(near - window)) else 1
	local to = if near and window then math.min(#points - 1, self:indexAt(near + window) + 1) else #points - 1
	for i = from, to do
		local a, b = points[i], points[i + 1]
		local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local length2 = ab.X * ab.X + ab.Z * ab.Z
		local t = 0
		if length2 > 1e-6 then
			t = math.clamp(((position.X - a.X) * ab.X + (position.Z - a.Z) * ab.Z) / length2, 0, 1)
		end
		local px, pz = a.X + ab.X * t, a.Z + ab.Z * t
		local dx, dz = position.X - px, position.Z - pz
		local d2 = dx * dx + dz * dz
		if d2 < bestDistance then
			bestDistance = d2
			best = cumulative[i] + t * (cumulative[i + 1] - cumulative[i])
		end
	end
	return best
end

function Route.indexAt(self: Route, distance: number): number
	local cumulative = self.Cumulative
	local low, high = 1, #cumulative
	while high - low > 1 do
		local mid = (low + high) // 2
		if cumulative[mid] <= distance then
			low = mid
		else
			high = mid
		end
	end
	return low
end

return Route
