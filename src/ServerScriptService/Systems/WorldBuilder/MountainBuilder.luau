--[[
	MountainBuilder: faceted low-poly mountain ranges built from TRIANGLES (every triangle = two WedgeParts, see Build.triangle).

	A mountain is a height field over an oval footprint: a polar grid (rings x segments) whose corner heights come from a main
	peak plus a few satellite peaks along a ridge, with a little noise. Neighbouring triangles share corners, so the surface is
	closed: no gaps, no slabs, no floating pieces. The outer ring sits below the ground (SINK) so the foot always disappears
	into the terrain. Colour follows height: green treeline at the bottom, rock in the middle, snow on tall peaks. Distant
	ranges are bigger, hazier and use fewer triangles. Every part is anchored, non colliding, non shadow casting scenery.

	Ranges are placed in a rounded ring around the playable ground and never inside it; lakes can veto positions.
	Settings (heights, distances, colours, snow line): ReplicatedStorage/Modules/EnvironmentConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Build)
local Config = require(ReplicatedStorage.Modules.EnvironmentConfig)

local MountainBuilder = {}

local SCENERY = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }
local SINK = 10 -- the outer ring lies this far below the ground

local function between(rng: Random, range: { number }): number
	return range[1] + (range[2] - range[1]) * rng:NextNumber()
end

local function fadeTo(color: Color3, fade: number): Color3
	return color:Lerp(Config.HazeColor, fade)
end

-- Detail 1..3 -> (rings, segments)
local GRID = { { 3, 8 }, { 4, 10 }, { 5, 12 } }

-- One mountain. `spec`: Position (base centre, y = ground), Width, Height, Fade, Detail (1-3), Peaks.
function MountainBuilder.massif(parent: Instance, spec: { [string]: any }, rng: Random): Model
	local model = Build.model(parent, "Mountain")
	local width, height, fade = spec.Width, spec.Height, spec.Fade
	local detail = math.clamp(spec.Detail, 1, 3)
	local rings, segments = GRID[detail][1], GRID[detail][2]
	local yaw = rng:NextNumber() * math.pi * 2
	local origin = CFrame.new(spec.Position) * CFrame.Angles(0, yaw, 0)
	-- footprint: never narrower than the slopes need (a tall mountain on a small base would be a needle)
	local radiusX = math.max(width * 0.55, height * 0.85)
	local radiusZ = math.max(width * 0.4, height * 0.75)

	local rock = fadeTo(Config.RockColors[rng:NextInteger(1, #Config.RockColors)], fade)
	local rockLight = rock:Lerp(Color3.new(1, 1, 1), 0.18)
	local rockDark = rock:Lerp(Color3.fromRGB(58, 60, 84), 0.32)
	local treeline = fadeTo(Config.TreelineColor, fade)
	local treelineDark = treeline:Lerp(Color3.fromRGB(40, 70, 56), 0.35)
	local snow = fadeTo(Config.SnowColor, fade * 0.5)
	local snowy = height >= Config.SnowAbove

	-- peaks sit exactly on grid corners (so none falls between two corners and vanishes): the summit in the middle, the
	-- others on rings 2..rings along a line (a ridge), each with its own height and width of influence
	type Peak = { Ring: number, Segment: number, Height: number, Reach: number }
	local peaks: { Peak } = { { Ring = 0, Segment = 0, Height = height, Reach = 0.9 } }
	local extra = rng:NextInteger(math.max(1, spec.Peaks[1] - 1), math.max(1, spec.Peaks[2] - 1))
	local ridgeSegment = rng:NextInteger(0, segments - 1)
	for index = 1, extra do
		local ring = math.min(rings, 1 + index)
		local side = if index % 2 == 0 then 0 else segments // 2
		table.insert(peaks, { Ring = ring, Segment = (ridgeSegment + side + rng:NextInteger(-1, 1)) % segments, Height = height * (0.42 + rng:NextNumber() * 0.38), Reach = 0.55 + rng:NextNumber() * 0.25 })
	end

	-- grid corners: [ring][segment] (ring 0 = the single centre corner)
	local function cornerUnit(ring: number, segment: number): Vector3
		if ring == 0 then
			return Vector3.zero
		end
		local angle = segment / segments * math.pi * 2 + (rng:NextNumber() - 0.5) * (math.pi / segments) * 0.5
		local reach = ring / rings
		return Vector3.new(math.cos(angle) * reach, 0, math.sin(angle) * reach)
	end
	local units: { { Vector3 } } = {}
	for ring = 0, rings do
		units[ring] = {}
		for segment = 0, if ring == 0 then 0 else segments - 1 do
			units[ring][segment] = cornerUnit(ring, segment)
		end
	end
	local function unitAt(ring: number, segment: number): Vector3
		return units[ring][if ring == 0 then 0 else segment % segments]
	end

	local function heightAt(ring: number, segment: number): number
		if ring == rings then
			return -SINK
		end
		local unit = unitAt(ring, segment)
		local best = 0
		for _, peak in peaks do
			local at = unitAt(peak.Ring, peak.Segment)
			local distance = (unit - at).Magnitude / peak.Reach
			if distance < 1 then
				best = math.max(best, peak.Height * (1 - distance) ^ 1.12)
			end
		end
		-- a little noise on the slopes, none on the summit corner (it stays the highest point)
		local noise = if ring == 0 then 0 else (rng:NextNumber() - 0.5) * 0.14 * height * (1 - ring / (rings + 1))
		return math.max(best + noise, 0.04 * height) - (if ring == rings - 1 then 0.04 * height else 0)
	end

	local corners: { { Vector3 } } = {}
	local heights: { { number } } = {}
	for ring = 0, rings do
		corners[ring], heights[ring] = {}, {}
		for segment = 0, if ring == 0 then 0 else segments - 1 do
			local h = heightAt(ring, segment)
			local unit = units[ring][segment]
			heights[ring][segment] = h
			corners[ring][segment] = origin * Vector3.new(unit.X * radiusX, h, unit.Z * radiusZ)
		end
	end
	local function corner(ring: number, segment: number): Vector3
		return corners[ring][if ring == 0 then 0 else segment % segments]
	end
	local function heightOf(ring: number, segment: number): number
		return heights[ring][if ring == 0 then 0 else segment % segments]
	end

	local triangles = 0
	local function facet(a: Vector3, b: Vector3, c: Vector3, fractionA: number, fractionB: number, fractionC: number)
		local fraction = (fractionA + fractionB + fractionC) / 3
		local color, material
		if snowy and fraction > 0.66 then
			color, material = snow, Enum.Material.Snow
		elseif fraction < 0.17 then
			color, material = (if rng:NextNumber() > 0.5 then treeline else treelineDark), Enum.Material.Grass
		else
			local roll = rng:NextNumber()
			color, material = (if roll < 0.34 then rockLight elseif roll < 0.72 then rock else rockDark), Enum.Material.Slate
		end
		triangles += Build.triangle(model, a, b, c, color, material, SCENERY, 0.6)
	end
	local function fraction(ring: number, segment: number): number
		return math.clamp(heightOf(ring, segment) / height, 0, 1)
	end

	-- centre fan
	for segment = 0, segments - 1 do
		facet(corner(0, 0), corner(1, segment), corner(1, segment + 1), fraction(0, 0), fraction(1, segment), fraction(1, segment + 1))
	end
	-- ring bands (two triangles per cell, the diagonal alternates so the surface does not look like a grid)
	for ring = 1, rings - 1 do
		for segment = 0, segments - 1 do
			local a, b = corner(ring, segment), corner(ring, segment + 1)
			local c, d = corner(ring + 1, segment), corner(ring + 1, segment + 1)
			local fa, fb, fc, fd = fraction(ring, segment), fraction(ring, segment + 1), fraction(ring + 1, segment), fraction(ring + 1, segment + 1)
			if (segment + ring) % 2 == 0 then
				facet(a, b, d, fa, fb, fd)
				facet(a, d, c, fa, fd, fc)
			else
				facet(a, b, c, fa, fb, fc)
				facet(b, d, c, fb, fd, fc)
			end
		end
	end
	model:SetAttribute("Height", height)
	model:SetAttribute("Triangles", triangles)
	return model
end

-- Point on a rounded rectangle around the ground, `distance` studs outside its edge. t in [0, 1).
local function ringPoint(halfX: number, halfZ: number, distance: number, t: number): (Vector3, boolean)
	local hx, hz = halfX + distance, halfZ + distance
	local perimeter = 4 * (hx + hz)
	local s = t * perimeter
	-- walk: north edge (+z) left->right, east edge top->bottom, south edge right->left, west edge bottom->top
	if s < 2 * hx then
		return Vector3.new(-hx + s, 0, hz), false
	end
	s -= 2 * hx
	if s < 2 * hz then
		return Vector3.new(hx, 0, hz - s), true
	end
	s -= 2 * hz
	if s < 2 * hx then
		return Vector3.new(hx - s, 0, -hz), false
	end
	s -= 2 * hx
	return Vector3.new(-hx, 0, -hz + s), true
end

-- Builds every range of EnvironmentConfig.Ranges around the ground. `lakes`: { {Vector3, radius} } to keep clear.
function MountainBuilder.build(parent: Instance, rng: Random, halfX: number, halfZ: number, lakes: { { any } })
	local folder = Build.folder(parent, "Mountains")
	for _, range in Config.Ranges do
		local rangeFolder = Build.folder(folder, range.Name)
		local perimeter = 4 * (halfX + range.Distance + halfZ + range.Distance)
		local s = rng:NextNumber() * 40
		while s < perimeter do
			local width = between(rng, range.Width)
			local position, onEnds = ringPoint(halfX, halfZ, range.Distance + (rng:NextNumber() - 0.5) * range.Jitter * 2, (s / perimeter) % 1)
			local scale = if onEnds then Config.EndsHeightScale else Config.LongSidesHeightScale
			local height = between(rng, range.Height) * scale
			local blocked = false
			for _, lake in lakes do
				blocked = blocked or (position - lake[1]).Magnitude < lake[2] + width * 0.4
			end
			if not blocked then
				MountainBuilder.massif(rangeFolder, { Position = Vector3.new(position.X, 0, position.Z), Width = width, Height = height, Fade = range.Fade, Detail = range.Detail, Peaks = range.Peaks }, rng)
			end
			s += width * range.Spacing
		end
	end
	return folder
end

return MountainBuilder
