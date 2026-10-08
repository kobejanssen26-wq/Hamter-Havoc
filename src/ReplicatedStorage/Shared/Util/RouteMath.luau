--[[
	Route geometry. The route is an arc; swap this module to change the route shape.
	Positions are returned at Y = 0 - callers add their own height.
]]

local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local RouteMath = {}

local routeConfig = GameConfig.Route
local startAngle = math.rad(routeConfig.StartAngleDegrees)
local sweep = math.rad(routeConfig.SweepDegrees)

function RouteMath.totalLength(): number
	return routeConfig.Radius * sweep
end

-- Returns position and unit tangent at `distance` studs along the route.
function RouteMath.pointAt(distance: number): (Vector3, Vector3)
	local alpha = math.clamp(distance / RouteMath.totalLength(), 0, 1)
	local angle = startAngle + sweep * alpha
	local radius = routeConfig.Radius
	local position = routeConfig.Center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
	local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
	return position, tangent
end

return RouteMath
