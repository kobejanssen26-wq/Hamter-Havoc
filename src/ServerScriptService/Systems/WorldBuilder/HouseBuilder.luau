--[[
	A cozy hamster house. Built in a local frame, then placed with `cframe`:
	  origin = centre of the lot on the ground, the FRONT (street / gate side) is -Z.
	  Lot: x in [-20, 20], z in [-22, 22].   Building: x in [-12, 12], z in [2, 18].

	Layout:  gate (front fence) -> cobble path -> porch -> door -> interior
	Interior: hamster display shelves (back wall), 8 upgrade pedestals (side walls), hamster chest.
	Yard:     rebirth altar, mailbox, name sign, trees, flowers, fence on every side, hedge at the back.

	Everything dynamic (names, stars, shelf contents, upgrade props) is refreshed through the
	functions at the bottom of this file by HouseSystem.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Build)
local Decor = require(script.Parent.Decor)
local Palette = require(script.Parent.Palette)

local UpgradeConfig = require(ReplicatedStorage.Modules.UpgradeConfig)

local HouseBuilder = {}

local WOOD = Enum.Material.WoodPlanks
local PLASTIC = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

local WALL_HEIGHT = 9
local FLOOR_TOP = 0.6
local ROOF_PITCH = math.rad(30)
local HALF_SPAN = 12.8

export type House = {
	Index: number,
	Model: Model,
	CFrame: CFrame,
	SpawnCFrame: CFrame,
	RoofParts: { BasePart },
	DefaultRoof: Color3,
	ShutterParts: { BasePart },
	Stars: { BasePart },
	Labels: { [string]: TextLabel },
	Prompts: { [string]: ProximityPrompt },
	DisplaySlots: { { Index: number, CFrame: CFrame, Ring: BasePart, Pedestal: BasePart } },
	Stations: { [string]: any },
	DisplayFolder: Folder,
	DisplayModels: { [number]: { SpeciesId: string, Model: Model } },
	Owner: Player?,
}

---------------------------------------------------------------------------
-- helpers
---------------------------------------------------------------------------

local function wallWithOpenings(
	parent: Instance,
	name: string,
	baseCFrame: CFrame,
	width: number,
	height: number,
	thickness: number,
	openings: { { X0: number, X1: number, Y0: number, Y1: number } },
	color: Color3,
	material: Enum.Material
)
	local xs = { -width / 2, width / 2 }
	local ys = { 0, height }
	for _, opening in openings do
		table.insert(xs, opening.X0)
		table.insert(xs, opening.X1)
		table.insert(ys, opening.Y0)
		table.insert(ys, opening.Y1)
	end
	table.sort(xs)
	table.sort(ys)

	for i = 1, #xs - 1 do
		for j = 1, #ys - 1 do
			local x0, x1, y0, y1 = xs[i], xs[i + 1], ys[j], ys[j + 1]
			if x1 - x0 > 0.01 and y1 - y0 > 0.01 then
				local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
				local inside = false
				for _, opening in openings do
					if cx > opening.X0 and cx < opening.X1 and cy > opening.Y0 and cy < opening.Y1 then
						inside = true
						break
					end
				end
				if not inside then
					Build.part(parent, name, Vector3.new(x1 - x0, y1 - y0, thickness), baseCFrame * CFrame.new(cx, cy, 0), color, material)
				end
			end
		end
	end
end

local function makePrompt(parent: BasePart, objectText: string, actionText: string, opens: string, focus: string?, distance: number?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = objectText
	prompt.ActionText = actionText
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = distance or 10
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt:SetAttribute("OpenUI", opens)
	if focus then
		prompt:SetAttribute("Focus", focus)
	end
	prompt:SetAttribute("OwnerUserId", 0)
	prompt:AddTag("OwnerOnlyPrompt")
	prompt.Parent = parent
	return prompt
end

-- A window facing local -Z, centred on `cframe`.
local function buildWindow(parent: Instance, cframe: CFrame, shutterColor: Color3, shutters: { BasePart }, rng: Random)
	Build.part(parent, "Glass", Vector3.new(4, 4, 0.15), cframe, Palette.Glass, Enum.Material.Glass, { Transparency = 0.5, CanCollide = false })
	local frame = Palette.WoodDark
	Build.deco(parent, "FrameTop", Vector3.new(4.6, 0.3, 0.6), cframe * CFrame.new(0, 2.15, 0), frame, WOOD)
	Build.deco(parent, "FrameBottom", Vector3.new(4.6, 0.3, 0.6), cframe * CFrame.new(0, -2.15, 0), frame, WOOD)
	Build.deco(parent, "FrameLeft", Vector3.new(0.3, 4.6, 0.6), cframe * CFrame.new(-2.15, 0, 0), frame, WOOD)
	Build.deco(parent, "FrameRight", Vector3.new(0.3, 4.6, 0.6), cframe * CFrame.new(2.15, 0, 0), frame, WOOD)
	Build.deco(parent, "MullionV", Vector3.new(0.2, 4, 0.3), cframe, frame, WOOD)
	Build.deco(parent, "MullionH", Vector3.new(4, 0.2, 0.3), cframe, frame, WOOD)
	for _, side in { -1, 1 } do
		table.insert(shutters, Build.deco(parent, "Shutter", Vector3.new(1.3, 4.2, 0.25), cframe * CFrame.new(side * 3, 0, -0.35), shutterColor, WOOD))
	end
	Build.part(parent, "FlowerBox", Vector3.new(4.6, 0.8, 1), cframe * CFrame.new(0, -2.9, -0.7), Palette.Wood, WOOD, { CanCollide = false })
	for index = 1, 4 do
		local color = Palette.FlowerColors[rng:NextInteger(1, #Palette.FlowerColors)]
		Build.deco(parent, "Flower", Vector3.new(0.9, 0.9, 0.9), cframe * CFrame.new(-1.7 + (index - 1) * 1.13, -2.2, -0.7), color, PLASTIC, { Shape = Enum.PartType.Ball })
	end
end

---------------------------------------------------------------------------
-- upgrade pedestal props (re-built whenever the level changes)
---------------------------------------------------------------------------

local propBuilders: { [string]: (Instance, CFrame, number, number) -> () } = {}

propBuilders.HamsterTraining = function(folder, top, fraction, ghost)
	local size = 1.2 + fraction * 0.9
	local wheel = Build.model(folder, "MiniWheel")
	local center = top * CFrame.new(0, size + 0.4, 0)
	local disc = Build.part(wheel, "Disc", Vector3.new(0.4, size * 2, size * 2), center, Palette.Glass, Enum.Material.Glass, { Shape = Enum.PartType.Cylinder, Transparency = 0.6 + ghost, CanCollide = false })
	Build.deco(wheel, "SpokeA", Vector3.new(0.2, size * 2, 0.2), center, Palette.Gold, NEON, { Transparency = ghost })
	Build.deco(wheel, "SpokeB", Vector3.new(0.2, 0.2, size * 2), center, Palette.Gold, NEON, { Transparency = ghost })
	wheel.PrimaryPart = disc
	wheel:SetAttribute("HomeCFrame", center)
	Build.animate(wheel, "SpinModel", { Speed = 0.8 + fraction * 5, Axis = "X" })
end

propBuilders.CollectionRange = function(folder, top, fraction, ghost)
	Build.pillar(folder, "Pole", 0.25, 2.2, top * CFrame.new(0, 1.1, 0), Palette.Ink, Enum.Material.Metal, { CanCollide = false })
	local bulb = Build.blob(folder, "Bulb", Vector3.one * (0.9 + fraction * 0.9), top * CFrame.new(0, 2.5, 0), Color3.fromRGB(120, 230, 255), NEON, { CanCollide = false, Transparency = ghost })
	Build.light(bulb, Color3.fromRGB(120, 230, 255), 0.8 * (1 - ghost), 10)
	Build.pillar(folder, "Ring", 1.8 + fraction * 2.6, 0.08, top * CFrame.new(0, 0.12, 0), Color3.fromRGB(120, 230, 255), NEON, { CanCollide = false, Transparency = 0.45 + ghost / 2 })
end

propBuilders.CoinMultiplier = function(folder, top, fraction, ghost)
	local coins = 2 + math.floor(fraction * 8)
	for index = 1, coins do
		Build.pillar(folder, "Coin", 1.5, 0.28, top * CFrame.new((index % 2) * 0.12, 0.15 + (index - 1) * 0.3, 0) * CFrame.Angles(0, index * 0.5, 0), Palette.Gold, Enum.Material.Metal, { CanCollide = false, Transparency = ghost })
	end
	Build.pillar(folder, "Coin", 1.5, 0.28, top * CFrame.new(1.4, 0.14, 0.3), Palette.Gold, Enum.Material.Metal, { CanCollide = false, Transparency = ghost })
end

propBuilders.SpawnLuck = function(folder, top, fraction, ghost)
	local clovers = 1 + math.floor(fraction * 3)
	for index = 1, clovers do
		local offset = (index - (clovers + 1) / 2) * 1.2
		local scale = 0.8 + fraction * 0.6
		Build.pillar(folder, "Stem", 0.14, 1.4 * scale, top * CFrame.new(offset, 0.7 * scale, 0), Palette.LeafDark, Enum.Material.Grass, { CanCollide = false, Transparency = ghost })
		for leaf = 0, 3 do
			local angle = leaf * math.pi / 2 + math.pi / 4
			Build.blob(folder, "Leaf", Vector3.new(0.75, 0.2, 0.75) * scale, top * CFrame.new(offset + math.cos(angle) * 0.45 * scale, 1.5 * scale, math.sin(angle) * 0.45 * scale), Color3.fromRGB(90, 200, 100), Enum.Material.Grass, { CanCollide = false, Transparency = ghost })
		end
	end
end

propBuilders.WalkSpeed = function(folder, top, fraction, ghost)
	for _, side in { -0.7, 0.7 } do
		Build.part(folder, "Shoe", Vector3.new(0.9, 0.8, 1.7), top * CFrame.new(side, 0.6, 0), Palette.Pink, PLASTIC, { CanCollide = false, Transparency = ghost })
		Build.part(folder, "Sole", Vector3.new(1, 0.25, 1.8), top * CFrame.new(side, 0.15, 0), Color3.new(1, 1, 1), PLASTIC, { CanCollide = false, Transparency = ghost })
		Build.deco(folder, "Wing", Vector3.new(0.12, 0.9 + fraction, 1.2 + fraction), top * CFrame.new(side * 1.5, 1.1, 0.2) * CFrame.Angles(0, 0, side * 0.4), Color3.new(1, 1, 1), PLASTIC, { Transparency = ghost })
	end
	for index = 1, 1 + math.floor(fraction * 4) do
		Build.deco(folder, "Streak", Vector3.new(0.12, 0.12, 1 + index * 0.4), top * CFrame.new(0, 0.5 + index * 0.15, 1.6 + index * 0.4), Color3.fromRGB(120, 230, 255), NEON, { Transparency = 0.3 + ghost })
	end
end

propBuilders.ExtraStorage = function(folder, top, fraction, ghost)
	local boxes = 1 + math.floor(fraction * 5)
	for index = 1, boxes do
		local row = math.ceil(math.sqrt(index))
		Build.part(folder, "Box", Vector3.one * 1.1, top * CFrame.new(((index - 1) % 3 - 1) * 1.15, 0.55 + (row - 1) * 1.1, 0), Palette.WoodLight, WOOD, { CanCollide = false, Transparency = ghost })
	end
end

propBuilders.RebirthBoost = function(folder, top, fraction, ghost)
	local size = 1 + fraction * 1.1
	local flame = Build.blob(folder, "Flame", Vector3.new(size, size * 1.7, size), top * CFrame.new(0, size * 0.9 + 0.2, 0), Color3.fromRGB(255, 120, 50), NEON, { CanCollide = false, Transparency = ghost })
	Build.blob(folder, "Core", Vector3.new(size * 0.5, size, size * 0.5), top * CFrame.new(0, size * 0.7 + 0.2, 0), Color3.fromRGB(255, 220, 110), NEON, { CanCollide = false, Transparency = ghost })
	Build.light(flame, Color3.fromRGB(255, 140, 60), 0.9 * (1 - ghost), 10)
	Build.animate(flame, "Bob", { Amplitude = 0.15, Speed = 3 })
end

propBuilders.GemBoost = function(folder, top, fraction, ghost)
	local gems = 1 + math.floor(fraction * 5)
	local colors = { Color3.fromRGB(120, 230, 255), Color3.fromRGB(255, 130, 220), Color3.fromRGB(150, 255, 190) }
	for index = 1, gems do
		local angle = index * 2.1
		local radius = if index == 1 then 0 else 0.9
		local height = 0.9 + (index % 3) * 0.3 + fraction * 0.4
		Build.part(folder, "Gem", Vector3.new(0.7, height, 0.7), top * CFrame.new(math.cos(angle) * radius, height / 2, math.sin(angle) * radius) * CFrame.Angles(0, angle, math.rad(8 * (index % 3))), colors[(index - 1) % 3 + 1], NEON, { CanCollide = false, Transparency = ghost })
	end
end

---------------------------------------------------------------------------
-- the build
---------------------------------------------------------------------------

function HouseBuilder.build(parent: Instance, index: number, cframe: CFrame, rng: Random): House
	local model = Build.model(parent, "House" .. index)
	model:SetAttribute("HouseId", index)
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("OwnerName", "")

	local function L(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end

	local roofColor = Palette.RoofColors[(index - 1) % #Palette.RoofColors + 1]
	local doorColor = Palette.RoofColors[(index + 3) % #Palette.RoofColors + 1]

	local house: House = {
		Index = index,
		Model = model,
		CFrame = cframe,
		SpawnCFrame = L(0, 3, -16) * CFrame.Angles(0, math.pi, 0),
		RoofParts = {},
		DefaultRoof = roofColor,
		ShutterParts = {},
		Stars = {},
		Labels = {},
		Prompts = {},
		DisplaySlots = {},
		Stations = {},
		DisplayFolder = Build.folder(model, "Display"),
		DisplayModels = {},
		Owner = nil,
	}

	local structure = Build.model(model, "Structure")
	local interior = Build.model(model, "Interior")
	local yard = Build.model(model, "Yard")

	-----------------------------------------------------------------------
	-- lawn, cobble path, boundaries
	-----------------------------------------------------------------------
	Build.part(yard, "Lawn", Vector3.new(40, 0.1, 44), L(0, 0.02, 0), Palette.GrassLight, Enum.Material.Grass, { CanCollide = false })
	for tile = 0, 6 do
		Build.deco(yard, "PathTile", Vector3.new(4.2, 0.14, 3), L(0, 0.08, -21 + tile * 3.4), if tile % 2 == 0 then Palette.Pavement else Palette.PavementDark, Enum.Material.Cobblestone)
	end

	local fenceColor = Palette.Cream
	Decor.fenceRun(yard, (cframe * CFrame.new(-19.5, 0, -21.5)).Position, (cframe * CFrame.new(-4.5, 0, -21.5)).Position, { Color = fenceColor })
	Decor.fenceRun(yard, (cframe * CFrame.new(4.5, 0, -21.5)).Position, (cframe * CFrame.new(19.5, 0, -21.5)).Position, { Color = fenceColor })
	Decor.fenceRun(yard, (cframe * CFrame.new(-19.5, 0, -21.5)).Position, (cframe * CFrame.new(-19.5, 0, 20)).Position, { Color = fenceColor })
	Decor.fenceRun(yard, (cframe * CFrame.new(19.5, 0, -21.5)).Position, (cframe * CFrame.new(19.5, 0, 20)).Position, { Color = fenceColor })
	Decor.hedgeRun(yard, (cframe * CFrame.new(-19.5, 0, 21)).Position, (cframe * CFrame.new(19.5, 0, 21)).Position, rng)

	-- gate posts with lanterns
	for _, side in { -1, 1 } do
		local pos = (cframe * CFrame.new(side * 4.5, 0, -21.5)).Position
		Build.pillar(yard, "GatePost", 0.9, 4.6, CFrame.new(pos + Vector3.new(0, 2.3, 0)), Palette.WoodDark, WOOD)
		local lantern = Build.blob(yard, "GateLantern", Vector3.new(1.1, 1.3, 1.1), CFrame.new(pos + Vector3.new(0, 5.2, 0)), Color3.fromRGB(255, 226, 150), NEON, { CanCollide = false })
		Build.light(lantern, Color3.fromRGB(255, 214, 140), 0.8, 14)
	end
	-- Gate arch sign (a hamster-sized welcome)
	Build.part(yard, "GateArch", Vector3.new(10, 0.5, 0.6), L(0, 5.2, -21.5), Palette.WoodDark, WOOD, { CanCollide = false })
	house.Labels.Arch = Build.billboard(
		Build.deco(yard, "ArchAnchor", Vector3.one * 0.3, L(0, 6.4, -21.5), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1 }),
		"Home Sweet Home",
		Vector2.new(220, 36),
		Vector3.zero,
		{ MaxDistance = 40, TextColor = Palette.Cream }
	)

	-----------------------------------------------------------------------
	-- building shell
	-----------------------------------------------------------------------
	Build.part(structure, "Foundation", Vector3.new(25.2, 0.5, 17.2), L(0, 0.25, 10), Palette.StoneDark, Enum.Material.Slate)
	Build.part(structure, "Floor", Vector3.new(24, 0.2, 16), L(0, FLOOR_TOP - 0.1, 10), Palette.WoodLight, WOOD)

	-- front wall: door + two windows
	wallWithOpenings(structure, "WallFront", L(0, 0, 2.4), 24, WALL_HEIGHT, 0.8, {
		{ X0 = -2.2, X1 = 2.2, Y0 = 0, Y1 = 7 },
		{ X0 = -9.5, X1 = -5.5, Y0 = 3.2, Y1 = 7.2 },
		{ X0 = 5.5, X1 = 9.5, Y0 = 3.2, Y1 = 7.2 },
	}, Palette.Wall, PLASTIC)
	-- back wall
	wallWithOpenings(structure, "WallBack", L(0, 0, 17.6), 24, WALL_HEIGHT, 0.8, {}, Palette.Wall, PLASTIC)
	-- side walls (one window each)
	wallWithOpenings(structure, "WallLeft", L(-11.6, 0, 10) * CFrame.Angles(0, math.rad(90), 0), 16, WALL_HEIGHT, 0.8, {
		{ X0 = -2, X1 = 2, Y0 = 3.2, Y1 = 7.2 },
	}, Palette.Wall, PLASTIC)
	wallWithOpenings(structure, "WallRight", L(11.6, 0, 10) * CFrame.Angles(0, math.rad(-90), 0), 16, WALL_HEIGHT, 0.8, {
		{ X0 = -2, X1 = 2, Y0 = 3.2, Y1 = 7.2 },
	}, Palette.Wall, PLASTIC)

	-- timber corners + beams
	for _, x in { -12, 12 } do
		for _, z in { 2, 18 } do
			Build.part(structure, "Corner", Vector3.new(1, WALL_HEIGHT + 0.4, 1), L(x, (WALL_HEIGHT + 0.4) / 2, z), Palette.WoodDark, WOOD)
		end
	end
	Build.part(structure, "BeamFront", Vector3.new(24.6, 0.6, 1), L(0, WALL_HEIGHT, 2), Palette.WoodDark, WOOD)
	Build.part(structure, "BeamBack", Vector3.new(24.6, 0.6, 1), L(0, WALL_HEIGHT, 18), Palette.WoodDark, WOOD)
	Build.part(structure, "BeamLeft", Vector3.new(1, 0.6, 16.6), L(-12, WALL_HEIGHT, 10), Palette.WoodDark, WOOD)
	Build.part(structure, "BeamRight", Vector3.new(1, 0.6, 16.6), L(12, WALL_HEIGHT, 10), Palette.WoodDark, WOOD)

	-- windows
	buildWindow(structure, L(-7.5, 5.2, 2.4), roofColor, house.ShutterParts, rng)
	buildWindow(structure, L(7.5, 5.2, 2.4), roofColor, house.ShutterParts, rng)
	buildWindow(structure, L(-11.6, 5.2, 10) * CFrame.Angles(0, math.rad(90), 0), roofColor, house.ShutterParts, rng)
	buildWindow(structure, L(11.6, 5.2, 10) * CFrame.Angles(0, math.rad(-90), 0), roofColor, house.ShutterParts, rng)

	-- door (open, swung outwards), frame, porch
	Build.deco(structure, "DoorFrameL", Vector3.new(0.5, 7.4, 1), L(-2.45, 3.7, 2.4), Palette.WoodDark, WOOD)
	Build.deco(structure, "DoorFrameR", Vector3.new(0.5, 7.4, 1), L(2.45, 3.7, 2.4), Palette.WoodDark, WOOD)
	Build.deco(structure, "DoorLintel", Vector3.new(5.4, 0.6, 1), L(0, 7.2, 2.4), Palette.WoodDark, WOOD)
	Build.deco(structure, "DoorArch", Vector3.new(4.6, 0.5, 0.5), L(0, 6.9, 1.9), doorColor, WOOD)
	local leafHinge = L(-2.2, 0, 2.0) * CFrame.Angles(0, math.rad(75), 0)
	Build.deco(structure, "DoorLeaf", Vector3.new(4.2, 6.8, 0.3), leafHinge * CFrame.new(2.1, 3.4, 0), doorColor, WOOD)
	Build.deco(structure, "DoorKnob", Vector3.one * 0.35, leafHinge * CFrame.new(3.6, 3.4, -0.3), Palette.Gold, Enum.Material.Metal, { Shape = Enum.PartType.Ball })
	Build.part(structure, "PorchStep", Vector3.new(7, 0.5, 2.6), L(0, 0.25, 0.8), Palette.Stone, Enum.Material.Cobblestone)
	Build.deco(structure, "WelcomeMat", Vector3.new(3.6, 0.08, 1.6), L(0, 0.54, 0.8), Palette.Pink, PLASTIC)
	for _, side in { -1, 1 } do
		local lamp = Build.blob(structure, "PorchLamp", Vector3.new(0.9, 1.2, 0.9), L(side * 3.7, 6.2, 1.7), Color3.fromRGB(255, 226, 150), NEON, { CanCollide = false })
		Build.light(lamp, Color3.fromRGB(255, 214, 140), 0.7, 12)
	end

	-----------------------------------------------------------------------
	-- roof (front gable)
	-----------------------------------------------------------------------
	local slabLength = HALF_SPAN / math.cos(ROOF_PITCH) + 0.8
	local rise = HALF_SPAN * math.tan(ROOF_PITCH)
	for _, side in { -1, 1 } do
		local slab = Build.part(
			structure,
			"Roof",
			Vector3.new(slabLength, 0.8, 19),
			L(side * HALF_SPAN / 2, WALL_HEIGHT + rise / 2 + 0.45, 10) * CFrame.Angles(0, 0, -side * ROOF_PITCH),
			roofColor,
			Enum.Material.Slate
		)
		table.insert(house.RoofParts, slab)
		Build.deco(structure, "RoofEdge", Vector3.new(slabLength, 0.3, 0.5), slab.CFrame * CFrame.new(0, 0.1, -9.6), Palette.Cream, WOOD)
	end
	table.insert(house.RoofParts, Build.part(structure, "Ridge", Vector3.new(1.2, 0.7, 19), L(0, WALL_HEIGHT + rise + 0.45, 10), roofColor, Enum.Material.Slate))

	-- gable triangles (stacked slices) front and back
	local slices = 9
	for _, z in { 2.2, 17.8 } do
		for slice = 1, slices do
			local sliceHeight = rise / slices
			local width = 24 * (1 - (slice - 0.5) / slices)
			Build.part(structure, "Gable", Vector3.new(width, sliceHeight + 0.02, 0.8), L(0, WALL_HEIGHT + (slice - 0.5) * sliceHeight, z), Palette.Wall, PLASTIC)
		end
	end
	-- rebirth banner + 10 stars under the front gable
	Build.part(structure, "Banner", Vector3.new(11, 1.8, 0.3), L(0, 11.6, 1.8), Palette.WoodDark, WOOD, { CanCollide = false })
	for starIndex = 1, 10 do
		local star = Build.blob(structure, "RebirthStar", Vector3.new(0.8, 0.8, 0.3), L(-4.5 + (starIndex - 1), 11.6, 1.55), Color3.fromRGB(70, 60, 70), PLASTIC, { CanCollide = false })
		table.insert(house.Stars, star)
	end

	-- chimney with smoke
	Build.part(structure, "Chimney", Vector3.new(2.2, 6, 2.2), L(7, 13.6, 6), Palette.Stone, Enum.Material.Brick)
	local chimneyTop = Build.part(structure, "ChimneyTop", Vector3.new(2.8, 0.5, 2.8), L(7, 16.8, 6), Palette.StoneDark, Enum.Material.Slate)
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(235, 235, 240))
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	smoke.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3) })
	smoke.Lifetime = NumberRange.new(2.5, 4)
	smoke.Speed = NumberRange.new(2, 3)
	smoke.Rate = 3
	smoke.SpreadAngle = Vector2.new(12, 12)
	smoke.Parent = chimneyTop
	chimneyTop:AddTag("AmbientParticles")

	-- roof name banner readable from far away
	local roofAnchor = Build.deco(structure, "RoofAnchor", Vector3.one * 0.3, L(0, WALL_HEIGHT + rise + 3.4, 10), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1 })
	house.Labels.Roof = Build.billboard(roofAnchor, "", Vector2.new(260, 44), Vector3.zero, { MaxDistance = 170, Name = "RoofName" })

	-----------------------------------------------------------------------
	-- interior
	-----------------------------------------------------------------------
	-- rafters + hanging lamp
	for _, z in { 5, 10, 15 } do
		Build.deco(interior, "Rafter", Vector3.new(23, 0.5, 0.6), L(0, WALL_HEIGHT + 0.2, z), Palette.WoodDark, WOOD)
	end
	Build.deco(interior, "LampCord", Vector3.new(0.1, 2.5, 0.1), L(0, WALL_HEIGHT - 1.1, 10), Palette.Ink, PLASTIC)
	local ceilingLamp = Build.blob(interior, "CeilingLamp", Vector3.new(2, 1.6, 2), L(0, WALL_HEIGHT - 2.6, 10), Color3.fromRGB(255, 226, 160), NEON, { CanCollide = false })
	Build.light(ceilingLamp, Color3.fromRGB(255, 224, 170), 1.4, 26)

	-- rug
	Build.pillar(interior, "RugOuter", 9, 0.06, L(0, FLOOR_TOP + 0.04, 10), Palette.Pink, PLASTIC, { CanCollide = false })
	Build.pillar(interior, "RugInner", 6.2, 0.08, L(0, FLOOR_TOP + 0.05, 10), Palette.Cream, PLASTIC, { CanCollide = false })
	Build.pillar(interior, "RugCore", 3.2, 0.1, L(0, FLOOR_TOP + 0.06, 10), Palette.Peach, PLASTIC, { CanCollide = false })

	-- display bookcase on the back wall: 2 shelves x 6 slots
	local shelfTops = { 3.2, 6.4 }
	Build.part(interior, "ShelfSideL", Vector3.new(0.6, 8.2, 2), L(-10.8, FLOOR_TOP + 4.1, 16.4), Palette.WoodDark, WOOD)
	Build.part(interior, "ShelfSideR", Vector3.new(0.6, 8.2, 2), L(10.8, FLOOR_TOP + 4.1, 16.4), Palette.WoodDark, WOOD)
	Build.part(interior, "ShelfTop", Vector3.new(22, 0.5, 2), L(0, FLOOR_TOP + 8.3, 16.4), Palette.WoodDark, WOOD)
	for row, shelfTop in shelfTops do
		Build.part(interior, "Shelf" .. row, Vector3.new(21.2, 0.5, 2), L(0, shelfTop - 0.25, 16.4), Palette.WoodLight, WOOD)
		for slot = 1, 6 do
			local slotIndex = (row - 1) * 6 + slot
			local x = -8.25 + (slot - 1) * 3.3
			local pedestal = Build.pillar(interior, "Pedestal", 2.3, 0.2, L(x, shelfTop + 0.1, 16.4), Palette.Cream, PLASTIC, { CanCollide = false })
			local ring = Build.pillar(interior, "SlotRing", 2.6, 0.06, L(x, shelfTop + 0.22, 16.4), Color3.fromRGB(90, 80, 90), NEON, { CanCollide = false, Transparency = 0.6 })
			table.insert(house.DisplaySlots, {
				Index = slotIndex,
				CFrame = L(x, shelfTop + 0.2, 16.4),
				Ring = ring,
				Pedestal = pedestal,
			})
		end
	end

	-- hamster chest (opens the inventory)
	local chestBody = Build.part(interior, "ChestBody", Vector3.new(3.2, 1.6, 2.2), L(-5.2, FLOOR_TOP + 0.8, 4.6), Palette.WoodLight, WOOD)
	Build.part(interior, "ChestLid", Vector3.new(3.4, 0.7, 2.4), L(-5.2, FLOOR_TOP + 1.95, 4.6), Palette.Wood, WOOD, { CanCollide = false })
	Build.deco(interior, "ChestLock", Vector3.new(0.5, 0.7, 0.2), L(-5.2, FLOOR_TOP + 1.6, 3.4), Palette.Gold, Enum.Material.Metal)
	Build.deco(interior, "ChestBand", Vector3.new(3.3, 0.2, 2.3), L(-5.2, FLOOR_TOP + 1.2, 4.6), Palette.WoodDark, WOOD)
	house.Prompts.Chest = makePrompt(chestBody, "Hamster Chest", "Open", "Inventory", nil, 10)

	-- cozy corners: plants
	for _, x in { -10.3, 10.3 } do
		Build.pillar(interior, "Pot", 1.6, 1.3, L(x, FLOOR_TOP + 0.65, 3.6), Palette.Peach, PLASTIC)
		Build.blob(interior, "Plant", Vector3.new(2.2, 2.4, 2.2), L(x, FLOOR_TOP + 2.3, 3.6), Palette.Leaf, Enum.Material.Grass, { CanCollide = false })
	end

	-- upgrade pedestals: 4 on each side wall
	local stationZ = { 5.2, 8, 10.8, 13.6 }
	for stationIndex, upgradeId in UpgradeConfig.Order do
		local side = if stationIndex <= 4 then -1 else 1
		local z = stationZ[(stationIndex - 1) % 4 + 1]
		local x = side * 9.7
		local facing = CFrame.Angles(0, if side < 0 then math.rad(-90) else math.rad(90), 0)
		local base = Build.pillar(interior, "StationBase", 2.4, 1.8, L(x, FLOOR_TOP + 0.9, z), Palette.Cream, PLASTIC)
		Build.pillar(interior, "StationPlate", 2.8, 0.25, L(x, FLOOR_TOP + 1.9, z), Palette.WoodLight, WOOD, { CanCollide = false })
		Build.deco(interior, "StationTrim", Vector3.new(2.6, 0.2, 2.6), L(x, FLOOR_TOP + 0.1, z), Palette.Gold, Enum.Material.Metal)
		local definition = UpgradeConfig.Definitions[upgradeId]
		local anchor = Build.deco(interior, "StationAnchor", Vector3.one * 0.2, L(x, FLOOR_TOP + 5.2, z), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1 })
		local label = Build.billboard(anchor, definition.Icon .. "\n" .. definition.Name, Vector2.new(180, 70), Vector3.zero, { MaxDistance = 38, Name = "StationLabel" })
		local propFolder = Build.folder(interior, "Prop_" .. upgradeId)
		house.Prompts[upgradeId] = makePrompt(base, definition.Name, "Upgrade", "Upgrades", upgradeId, 9)
		house.Stations[upgradeId] = {
			Id = upgradeId,
			Label = label,
			PropFolder = propFolder,
			Top = L(x, FLOOR_TOP + 2.05, z) * facing,
		}
		propBuilders[upgradeId](propFolder, L(x, FLOOR_TOP + 2.05, z) * facing, 0.05, 0.6)
	end

	-----------------------------------------------------------------------
	-- yard details: altar, mailbox, sign, trees, flowers
	-----------------------------------------------------------------------
	-- rebirth altar
	Build.pillar(yard, "AltarBase", 4.4, 0.7, L(11.5, 0.35, -9), Palette.Stone, Enum.Material.Cobblestone)
	local altar = Build.pillar(yard, "AltarPillar", 2.4, 1.8, L(11.5, 1.6, -9), Palette.Cream, PLASTIC)
	Build.pillar(yard, "AltarCap", 3, 0.3, L(11.5, 2.65, -9), Palette.Gold, Enum.Material.Metal, { CanCollide = false })
	local orb = Build.blob(yard, "AltarOrb", Vector3.one * 1.6, L(11.5, 4.1, -9), Color3.fromRGB(255, 130, 60), NEON, { CanCollide = false })
	Build.light(orb, Color3.fromRGB(255, 150, 80), 1, 16)
	Build.animate(orb, "Bob", { Amplitude = 0.35, Speed = 1.6 })
	for crystal = 1, 3 do
		local angle = crystal * math.pi * 2 / 3
		Build.part(yard, "AltarCrystal", Vector3.new(0.6, 1.8, 0.6), L(11.5 + math.cos(angle) * 2.3, 1.2, -9 + math.sin(angle) * 2.3) * CFrame.Angles(0, angle, math.rad(10)), Color3.fromRGB(255, 160, 90), NEON, { CanCollide = false, Transparency = 0.2 })
	end
	house.Prompts.Rebirth = makePrompt(altar, "Rebirth Altar", "Rebirth", "Rebirth", nil, 11)
	house.Labels.Altar = Build.billboard(Build.deco(yard, "AltarAnchor", Vector3.one * 0.2, L(11.5, 6.6, -9), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1 }), "🔥 Rebirth Altar", Vector2.new(190, 34), Vector3.zero, { MaxDistance = 40 })

	-- mailbox (daily gift)
	Build.part(yard, "MailPost", Vector3.new(0.5, 3.4, 0.5), L(6.5, 1.7, -19.6), Palette.WoodDark, WOOD)
	local mailbox = Build.blob(yard, "Mailbox", Vector3.new(2.6, 1.8, 1.8), L(6.5, 3.7, -19.6), Color3.fromRGB(100, 170, 255), PLASTIC)
	Build.deco(yard, "MailFlag", Vector3.new(0.2, 1.1, 0.5), L(7.8, 4.1, -19.6), Color3.fromRGB(255, 90, 90), PLASTIC)
	house.Prompts.Mailbox = makePrompt(mailbox, "Mailbox", "Daily Gift", "Daily", nil, 10)

	-- name sign next to the gate (faces the street)
	Build.part(yard, "SignPostL", Vector3.new(0.6, 5.6, 0.6), L(-13.6, 2.8, -19.6), Palette.WoodDark, WOOD)
	Build.part(yard, "SignPostR", Vector3.new(0.6, 5.6, 0.6), L(-6.4, 2.8, -19.6), Palette.WoodDark, WOOD)
	local board = Build.part(yard, "SignBoard", Vector3.new(8.6, 4.4, 0.5), L(-10, 4.6, -19.6), Palette.WoodLight, WOOD, { CanCollide = false })
	Build.deco(yard, "SignRoof", Vector3.new(9.4, 0.4, 1.2), L(-10, 7, -19.6), Palette.WoodDark, WOOD)
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 60
	signGui.Parent = board
	local function signLine(name: string, y: number, h: number, font: Enum.Font, color: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.04, y)
		label.Size = UDim2.fromScale(0.92, h)
		label.TextScaled = true
		label.RichText = true
		label.Font = font
		label.TextColor3 = color
		label.Text = ""
		label.Parent = signGui
		return label
	end
	house.Labels.Name = signLine("Name", 0.04, 0.38, Enum.Font.FredokaOne, Palette.Ink)
	house.Labels.Stats = signLine("Stats", 0.44, 0.26, Enum.Font.GothamBold, Color3.fromRGB(120, 70, 40))
	house.Labels.Best = signLine("Best", 0.72, 0.24, Enum.Font.GothamMedium, Color3.fromRGB(120, 70, 40))

	-- garden: trees, bushes, flowers, small rocks
	Decor.tree(yard, (cframe * CFrame.new(-15, 0, -14)).Position, if index % 2 == 0 then "cherry" else "round", 1, rng)
	Decor.tree(yard, (cframe * CFrame.new(15.5, 0, 2)).Position, if index % 3 == 0 then "cherry" else "round", 0.9, rng)
	Decor.tree(yard, (cframe * CFrame.new(-16, 0, 14)).Position, "pine", 0.9, rng)
	Decor.tree(yard, (cframe * CFrame.new(16, 0, 14)).Position, "round", 1.1, rng)
	for _, x in { -14, -9, 9, 14 } do
		Decor.bush(yard, (cframe * CFrame.new(x, 0, -2)).Position, 0.9, rng, x % 2 == 0)
	end
	Decor.flowers(yard, (cframe * CFrame.new(-8, 0, -12)).Position, 3.4, 16, rng)
	Decor.flowers(yard, (cframe * CFrame.new(8, 0, -14.5)).Position, 3, 14, rng)
	Decor.flowers(yard, (cframe * CFrame.new(-8.5, 0, -2)).Position, 3, 12, rng)
	Decor.flowers(yard, (cframe * CFrame.new(8.5, 0, -3)).Position, 2.6, 12, rng)
	Decor.rock(yard, (cframe * CFrame.new(16, 0, -16)).Position, 0.8, rng)
	Decor.mushrooms(yard, (cframe * CFrame.new(-17, 0, -3)).Position, rng)
	Decor.bench(yard, cframe * CFrame.new(-12, 0, 7.5) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, math.rad(90), 0))
	Decor.barrel(yard, (cframe * CFrame.new(17, 0, -5)).Position)

	-- roof colour tint on the doormat etc is handled by HouseSystem; start with the default
	return house
end

---------------------------------------------------------------------------
-- dynamic refresh helpers (called by HouseSystem)
---------------------------------------------------------------------------

function HouseBuilder.setRoofColor(house: House, color: Color3)
	for _, part in house.RoofParts do
		part.Color = color
	end
	for _, part in house.ShutterParts do
		part.Color = color
	end
end

-- Rebuilds the prop and label of one upgrade pedestal.
function HouseBuilder.setStation(house: House, upgradeId: string, level: number)
	local station = house.Stations[upgradeId]
	local definition = UpgradeConfig.Definitions[upgradeId]
	if not station or not definition then
		return
	end
	station.PropFolder:ClearAllChildren()
	local fraction = math.clamp(level / definition.MaxLevel, 0, 1)
	local ghost = if level <= 0 then 0.6 else 0
	propBuilders[upgradeId](station.PropFolder, station.Top, math.max(fraction, 0.05), ghost)
	local levelText = if level >= definition.MaxLevel then "MAX" else string.format("Lv %d/%d", level, definition.MaxLevel)
	station.Label.Text = string.format("%s\n%s\n<font color=\"#FFE08A\">%s</font>", definition.Icon, definition.Name, levelText)
end

function HouseBuilder.setStars(house: House, count: number)
	for index, star in house.Stars do
		local lit = index <= count
		star.Color = if lit then Palette.Gold else Color3.fromRGB(70, 60, 70)
		star.Material = if lit then NEON else PLASTIC
	end
end

return HouseBuilder
