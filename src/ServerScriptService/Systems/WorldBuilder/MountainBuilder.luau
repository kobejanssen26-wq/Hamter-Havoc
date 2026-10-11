--[[
	MountainBuilder: angular, layered mountain ranges (no balloons).

	A mountain ("massif") is a crest of 3-5 PEAKS. Every peak is two crossing A-frame ridges: steep, flat rock slopes
	leaning against each other, cut into bands that get shorter towards the top, so the peak ends in a point. Bands are
	coloured: green treeline, dark rock, light rock and snow on tall ones. Low spurs run down the flanks and broad green
	foothills sit under everything. Peak heights, ridge directions and widths are random but
	seeded, so the silhouette is jagged and asymmetric. Distant ranges are bigger, hazier and use fewer colour bands. Every part is anchored, non
	colliding, non shadow casting scenery, so a whole backdrop costs a few hundred cheap parts.

	Ranges are placed in a rounded ring around the playable ground and never inside it; lakes can veto positions.
	Settings: ReplicatedStorage/Modules/EnvironmentConfig.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Build)
local Config = require(ReplicatedStorage.Modules.EnvironmentConfig)

local MountainBuilder = {}

local SCENERY = { CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }

local function between(rng: Random, range: { number }): number
	return range[1] + (range[2] - range[1]) * rng:NextNumber()
end

local function fadeTo(color: Color3, fade: number): Color3
	return color:Lerp(Config.HazeColor, fade)
end

-- A "frame" is a ridge: two steep rock slopes leaning against each other like an A (a triangle seen from the end).
-- Each slope is cut into `count` bands; band i is shorter than the one below it (`taper`), so the ridge ends in a point
-- like a hip roof instead of a flat crest. `colorAt(f)` gives the colour + material at fraction f (0 foot .. 1 crest).
-- Local coordinates: ridge along X, y up, the two slopes at z = +-halfBase.
type ColorAt = (number) -> (Color3, Enum.Material)
local function frame(model: Model, origin: CFrame, length: number, halfBase: number, height: number, count: number, taper: number, colorAt: ColorAt, shadow: number, sink: number)
	for _, side in { -1, 1 } do
		local bottom = Vector3.new(0, -sink, side * halfBase)
		local direction = Vector3.new(0, height + sink, -side * halfBase)
		local slope = direction.Magnitude
		local unit = direction / slope
		local normal = unit:Cross(Vector3.xAxis).Unit
		local darker = if side < 0 then 0 else shadow -- one slope is in shadow (blend towards black)
		for band = 1, count do
			local from, to = (band - 1) / count, band / count
			local middle = bottom + direction * ((from + to) / 2)
			local cf = origin * CFrame.fromMatrix(middle, Vector3.xAxis, normal)
			local color, material = colorAt((from + to) / 2)
			local thickness = math.max(3, slope * 0.05)
			local bandLength = length * (1 - taper * to)
			Build.part(model, "Slope", Vector3.new(bandLength, thickness, (to - from) * slope + 2), cf, color:Lerp(Color3.new(0, 0, 0), darker), material, SCENERY)
		end
	end
end

-- One mountain. `spec`: Position (base centre, y = ground), Width (length of the crest), Height, Fade, Detail (1-3), Peaks.
function MountainBuilder.massif(parent: Instance, spec: { [string]: any }, rng: Random): Model
	local model = Build.model(parent, "Mountain")
	local width, height, fade, detail = spec.Width, spec.Height, spec.Fade, spec.Detail
	local yaw = rng:NextNumber() * math.pi * 2
	local origin = CFrame.new(spec.Position) * CFrame.Angles(0, yaw, 0)
	local rock = fadeTo(Config.RockColors[rng:NextInteger(1, #Config.RockColors)], fade)
	local rockDark = rock:Lerp(Color3.fromRGB(64, 66, 88), 0.3)
	local treeline = fadeTo(Config.TreelineColor, fade)
	local snow = fadeTo(Config.SnowColor, fade * 0.5)
	local snowy = height >= Config.SnowAbove
	local SINK = 8 -- slopes start below the ground so nothing floats
	local bands = detail + 1

	local function colorsFor(peakHeight: number): ColorAt
		local snowLine = if snowy and peakHeight > height * 0.55 then 0.68 else 2
		return function(f: number)
			if f >= snowLine then
				return snow, Enum.Material.Snow
			elseif f < 0.2 and detail >= 2 then
				return treeline, Enum.Material.Grass
			elseif f < 0.45 and detail >= 3 then
				return rockDark, Enum.Material.Slate
			end
			return rock, Enum.Material.Slate
		end
	end
	local foothills: ColorAt = function()
		return treeline, Enum.Material.Grass
	end

	-- foothills: broad, low, green, flat-crested
	frame(model, origin * CFrame.Angles(0, (rng:NextNumber() - 0.5) * 0.3, 0), width * 1.15, height * (0.8 + rng:NextNumber() * 0.2), height * 0.3, 1, 0, foothills, 0.18, SINK)

	-- the crest: a chain of pyramids of different height; the tallest one in the middle third
	local peaks = rng:NextInteger(spec.Peaks[1], spec.Peaks[2])
	local summitIndex = rng:NextInteger(math.ceil(peaks / 3), math.max(1, math.floor(peaks * 2 / 3)))
	local summitX = 0
	for index = 1, peaks do
		local x = -width / 2 + (index - 0.5) * (width / peaks) + (rng:NextNumber() - 0.5) * width * 0.06
		local isSummit = index == summitIndex
		local peakHeight = height * (if isSummit then 1 else 0.48 + rng:NextNumber() * 0.38)
		local halfBase = peakHeight * (0.6 + rng:NextNumber() * 0.25) -- steep faces (about 50-60 degrees)
		local place = origin * CFrame.new(x, 0, (rng:NextNumber() - 0.5) * width * 0.07) * CFrame.Angles(0, (rng:NextNumber() - 0.5) * 0.7, 0)
		local colors = colorsFor(peakHeight)
		frame(model, place, halfBase * (1.8 + rng:NextNumber() * 0.5), halfBase, peakHeight, bands, 0.88, colors, 0.2, SINK)
		-- a second ridge across it turns the roof into a pointed pyramid and closes the open end of the first A-frame
		frame(model, place * CFrame.Angles(0, math.pi / 2, 0), halfBase * (1.5 + rng:NextNumber() * 0.4), halfBase * 0.92, peakHeight * 0.96, bands, 0.88, colors, 0.2, SINK)
		if isSummit then
			summitX = x
		end
	end

	-- a few low spurs running down the flanks
	if detail >= 2 then
		for _ = 1, 2 do
			local x = summitX + (rng:NextNumber() - 0.5) * width * 0.6
			local spurHeight = height * (0.28 + rng:NextNumber() * 0.2)
			local flank = (if rng:NextNumber() > 0.5 then 1 else -1) * height * 0.5
			frame(model, origin * CFrame.new(x, 0, flank) * CFrame.Angles(0, math.pi / 2 + (rng:NextNumber() - 0.5) * 0.5, 0), height * 0.7, spurHeight * 0.8, spurHeight, bands - 1, 0.8, colorsFor(0), 0.2, SINK)
		end
	end
	model:SetAttribute("Height", height)
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
				MountainBuilder.massif(rangeFolder, { Position = Vector3.new(position.X, -2, position.Z), Width = width, Height = height, Fade = range.Fade, Detail = range.Detail, Peaks = range.Peaks }, rng)
			end
			s += width * range.Spacing
		end
	end
	return folder
end

return MountainBuilder
