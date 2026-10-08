--[[
	A cozy hamster house on a big lot. Built in a local frame, then placed with `cframe`:
	  origin = middle of the GATE LINE on the ground, +Z = into the lot, -Z = the street.
	  Lot: x in [-24, 24], z in [0, 58]. Building: x in [-16, 16], z in [17, 47].

	Front   security gate (laser beams), driveway, front lawn, mailbox, name sign, rebirth altar
	Inside  the arrival pad (secured hamsters land here), 12 hamster-wheel stations, 8 upgrade pedestals, chest
	Back    small garden

	Dynamic things (names, stars, wheels, upgrade props, security lights) are refreshed through the
	functions at the bottom of this file by HouseSystem / SecuritySystem.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Build)
local Decor = require(script.Parent.Decor)
local Palette = require(script.Parent.Palette)

local SecurityConfig = require(ReplicatedStorage.Modules.SecurityConfig)
local UpgradeConfig = require(ReplicatedStorage.Modules.UpgradeConfig)
local WorldLayout = require(ReplicatedStorage.Modules.WorldLayout)

local HouseBuilder = {}

local WOOD = Enum.Material.WoodPlanks
local PLASTIC = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

local WALL_HEIGHT = 9
local FLOOR_TOP = 0.6
local ROOF_PITCH = math.rad(24)
local HALF_SPAN = 16.8
local FRONT_Z, BACK_Z = 17, 47 -- building footprint (local z)
local MID_Z = (FRONT_Z + BACK_Z) / 2

local WHEEL_RADIUS = 2.3
local WHEEL_CENTER_Y = 3.3
local WHEEL_ROWS = { 43.2, 35.5 }
local WHEEL_XS = { -2.5, 2.5, -7.5, 7.5, -12.5, 12.5 }

export type Slot = {
	Index: number,
	Center: CFrame, -- wheel centre (local frame applied)
	RunCFrame: CFrame, -- where the running hamster stands
	Ring: BasePart, -- locked / empty marker on the floor
	LabelAnchor: BasePart,
	Label: TextLabel?,
	Wheel: Model?,
	Frame: Folder,
}

export type House = {
	Index: number,
	Model: Model,
	CFrame: CFrame,
	SpawnCFrame: CFrame,
	GatePosition: Vector3,
	PadCFrame: CFrame,
	RoofParts: { BasePart },
	DefaultRoof: Color3,
	ShutterParts: { BasePart },
	Stars: { BasePart },
	Labels: { [string]: TextLabel },
	Prompts: { [string]: ProximityPrompt },
	Slots: { Slot },
	Stations: { [string]: any },
	DisplayFolder: Folder,
	DisplayModels: { [number]: { SpeciesId: string, Model: Model } },
	Security: {
		Beams: { BasePart },
		Field: BasePart,
		Lamps: { BasePart },
		PylonLamp: BasePart,
		Prompt: ProximityPrompt,
		Anchor: BasePart,
	},
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

-- A window facing local -Z, centred on `cframe` (glass, frame and shutters).
local function buildWindow(parent: Instance, cframe: CFrame, shutterColor: Color3, shutters: { BasePart })
	Build.part(parent, "Glass", Vector3.new(5, 4, 0.15), cframe, Palette.Glass, Enum.Material.Glass, { Transparency = 0.5, CanCollide = false })
	local frame = Palette.WoodDark
	Build.deco(parent, "FrameTop", Vector3.new(5.6, 0.3, 0.6), cframe * CFrame.new(0, 2.15, 0), frame, WOOD)
	Build.deco(parent, "FrameBottom", Vector3.new(5.6, 0.4, 0.8), cframe * CFrame.new(0, -2.15, -0.1), frame, WOOD)
	Build.deco(parent, "FrameSide", Vector3.new(0.3, 4.6, 0.6), cframe * CFrame.new(-2.65, 0, 0), frame, WOOD)
	Build.deco(parent, "FrameSide", Vector3.new(0.3, 4.6, 0.6), cframe * CFrame.new(2.65, 0, 0), frame, WOOD)
	for _, side in { -1, 1 } do
		table.insert(shutters, Build.deco(parent, "Shutter", Vector3.new(1.4, 4.2, 0.25), cframe * CFrame.new(side * 3.6, 0, -0.35), shutterColor, WOOD))
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
-- hamster wheel (built on demand when a slot is unlocked)
---------------------------------------------------------------------------

local function buildWheel(house: House, slot: Slot)
	local frame = slot.Frame
	frame:ClearAllChildren()
	local center = slot.Center
	local function C(x: number, y: number, z: number): CFrame
		return center * CFrame.new(x, y, z)
	end
	local alongZ = CFrame.Angles(0, math.rad(90), 0)

	-- stand: base plate, two A-frames, axle
	local baseY = FLOOR_TOP + 0.175 - WHEEL_CENTER_Y
	Build.part(frame, "WheelBase", Vector3.new(5.6, 0.35, 3.4), C(0, baseY, 0), Palette.WoodDark, WOOD)
	local legRise = WHEEL_CENTER_Y - (FLOOR_TOP + 0.35)
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
		Build.deco(wheel, "Side", Vector3.new(0.12, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2), C(0, 0, z) * alongZ, Palette.Glass, Enum.Material.Glass, { Shape = Enum.PartType.Cylinder, Transparency = 0.62 })
	end
	for rung = 0, 5 do
		local angle = rung * math.pi / 3
		Build.deco(wheel, "Rung", Vector3.new(2.3, 0.2, 0.2), C(math.cos(angle) * (WHEEL_RADIUS - 0.1), math.sin(angle) * (WHEEL_RADIUS - 0.1), 0) * alongZ, Palette.Gold, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	end
	wheel.PrimaryPart = hub
	Build.animate(wheel, "SpinModel", { Speed = 0, Axis = "Z" })
	slot.Wheel = wheel
end

-- Creates (unlocked) or removes (locked) the wheel in a slot.
function HouseBuilder.setWheel(house: House, slotIndex: number, unlocked: boolean)
	local slot = house.Slots[slotIndex]
	if not slot then
		return
	end
	if unlocked and not slot.Wheel then
		buildWheel(house, slot)
	elseif not unlocked and slot.Wheel then
		slot.Frame:ClearAllChildren()
		slot.Wheel = nil
	end
end

function HouseBuilder.setWheelSpeed(slot: Slot, speed: number)
	if slot.Wheel then
		slot.Wheel:SetAttribute("Speed", speed)
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
	model:SetAttribute("SecState", "Off")
	model:SetAttribute("SecUntil", 0)
	model:SetAttribute("SecReady", 0)

	local function L(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end

	local roofColor = Palette.RoofColors[(index - 1) % #Palette.RoofColors + 1]
	local doorColor = Palette.RoofColors[(index + 3) % #Palette.RoofColors + 1]

	local structure = Build.model(model, "Structure")
	local interior = Build.model(model, "Interior")
	local yard = Build.model(model, "Yard")
	local wheelsFolder = Build.folder(model, "Wheels")

	local house: House = {
		Index = index,
		Model = model,
		CFrame = cframe,
		SpawnCFrame = L(0, 3, 9),
		GatePosition = cframe.Position,
		PadCFrame = L(WorldLayout.PadLocal.X, WorldLayout.PadLocal.Y, WorldLayout.PadLocal.Z),
		RoofParts = {},
		DefaultRoof = roofColor,
		ShutterParts = {},
		Stars = {},
		Labels = {},
		Prompts = {},
		Slots = {},
		Stations = {},
		DisplayFolder = Build.folder(model, "Display"),
		DisplayModels = {},
		Security = nil :: any,
		Owner = nil,
	}

	-----------------------------------------------------------------------
	-- lawn, driveway, boundaries
	-----------------------------------------------------------------------
	Build.part(yard, "Lawn", Vector3.new(48, 0.1, 58), L(0, 0.02, 29), Palette.GrassLight, Enum.Material.Grass, { CanCollide = false })
	Build.part(yard, "Driveway", Vector3.new(7, 0.14, 16.5), L(0, 0.07, 8.4), Palette.Pavement, Enum.Material.Cobblestone, { CanCollide = false })
	for _, side in { -1, 1 } do
		Build.deco(yard, "DrivewayEdge", Vector3.new(0.5, 0.18, 16.5), L(side * 3.75, 0.09, 8.4), Palette.PavementDark, Enum.Material.Cobblestone)
	end
	Build.part(yard, "GateApron", Vector3.new(14, 0.14, 4), L(0, 0.07, 0), Palette.PavementDark, Enum.Material.Cobblestone, { CanCollide = false })

	local fenceColor = Palette.Cream
	local function fence(x0: number, z0: number, x1: number, z1: number)
		Decor.fenceRun(yard, (cframe * CFrame.new(x0, 0, z0)).Position, (cframe * CFrame.new(x1, 0, z1)).Position, { Color = fenceColor })
	end
	fence(-23.5, 0, -6, 0)
	fence(6, 0, 23.5, 0)
	fence(-23.5, 0, -23.5, 57)
	fence(23.5, 0, 23.5, 57)
	Decor.hedgeRun(yard, (cframe * CFrame.new(-23.5, 0, 57.5)).Position, (cframe * CFrame.new(23.5, 0, 57.5)).Position, rng)

	-----------------------------------------------------------------------
	-- security gate: posts, arch, laser beams, force field, status lamps, control pylon
	-----------------------------------------------------------------------
	local lamps: { BasePart } = {}
	for _, side in { -1, 1 } do
		Build.pillar(yard, "GatePost", 1.1, 7.2, L(side * 5.6, 3.6, 0), Palette.WoodDark, WOOD)
		Build.deco(yard, "GateCap", Vector3.new(1.5, 0.35, 1.5), L(side * 5.6, 7.35, 0), Palette.Stone, Enum.Material.Slate)
		table.insert(lamps, Build.blob(yard, "GateLamp", Vector3.new(1.1, 1.3, 1.1), L(side * 5.6, 8.2, 0), Color3.fromRGB(110, 230, 140), NEON, { CanCollide = false }))
	end
	Build.deco(yard, "GateBeam", Vector3.new(12.2, 0.7, 0.9), L(0, 7.35, 0), Palette.WoodDark, WOOD)
	local beams: { BasePart } = {}
	for beam = 1, SecurityConfig.MaxBeams do
		table.insert(
			beams,
			Build.deco(yard, "LaserBeam", Vector3.new(10.2, 0.2, 0.2), L(0, 0.7 + beam * 1.15, 0), Color3.fromRGB(255, 96, 96), NEON, { Shape = Enum.PartType.Cylinder, Transparency = 1 })
		)
	end
	local field = Build.deco(yard, "SecurityField", Vector3.new(10.2, 6.6, 0.12), L(0, 3.9, 0), Color3.fromRGB(255, 96, 96), NEON, { Transparency = 1 })
	local anchor = Build.deco(yard, "SecurityAnchor", Vector3.one * 0.3, L(0, 10.2, 0), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1, CanQuery = false })

	-- control pylon just inside the gate (press E there to switch the gate back on)
	Build.pillar(yard, "PylonBase", 1.9, 0.6, L(8, 0.3, 4), Palette.StoneDark, Enum.Material.Slate)
	local pylon = Build.pillar(yard, "PylonColumn", 1.1, 2.6, L(8, 1.9, 4), Palette.Cream, PLASTIC)
	local pylonLamp = Build.blob(yard, "PylonLamp", Vector3.new(1.3, 1.1, 1.3), L(8, 3.7, 4), Color3.fromRGB(110, 230, 140), NEON, { CanCollide = false })
	local securityPrompt = Instance.new("ProximityPrompt")
	securityPrompt.ObjectText = "Security Panel"
	securityPrompt.ActionText = "Reactivate Security"
	securityPrompt.KeyboardKeyCode = Enum.KeyCode.E
	securityPrompt.HoldDuration = 0
	securityPrompt.MaxActivationDistance = 9
	securityPrompt.RequiresLineOfSight = false
	securityPrompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	securityPrompt.Enabled = false
	securityPrompt:SetAttribute("SecurityHouse", index)
	securityPrompt.Parent = pylon
	house.Security = { Beams = beams, Field = field, Lamps = lamps, PylonLamp = pylonLamp, Prompt = securityPrompt, Anchor = anchor }

	-----------------------------------------------------------------------
	-- building shell
	-----------------------------------------------------------------------
	local frontWallZ = FRONT_Z + 0.4
	local backWallZ = BACK_Z - 0.4
	Build.part(structure, "Foundation", Vector3.new(32.8, 0.5, 30.8), L(0, 0.25, MID_Z), Palette.StoneDark, Enum.Material.Slate)
	Build.part(structure, "Floor", Vector3.new(32, 0.2, 30), L(0, FLOOR_TOP - 0.1, MID_Z), Palette.WoodLight, WOOD)

	-- front wall: wide double door + two windows
	wallWithOpenings(structure, "WallFront", L(0, 0, frontWallZ), 32, WALL_HEIGHT, 0.8, {
		{ X0 = -4.2, X1 = 4.2, Y0 = 0, Y1 = 8 },
		{ X0 = -13.5, X1 = -8.5, Y0 = 3.2, Y1 = 7.2 },
		{ X0 = 8.5, X1 = 13.5, Y0 = 3.2, Y1 = 7.2 },
	}, Palette.Wall, PLASTIC)
	wallWithOpenings(structure, "WallBack", L(0, 0, backWallZ), 32, WALL_HEIGHT, 0.8, {}, Palette.Wall, PLASTIC)
	wallWithOpenings(structure, "WallLeft", L(-15.6, 0, MID_Z) * CFrame.Angles(0, math.rad(90), 0), 29.2, WALL_HEIGHT, 0.8, {
		{ X0 = -9, X1 = -4, Y0 = 3.2, Y1 = 7.2 },
		{ X0 = 4, X1 = 9, Y0 = 3.2, Y1 = 7.2 },
	}, Palette.Wall, PLASTIC)
	wallWithOpenings(structure, "WallRight", L(15.6, 0, MID_Z) * CFrame.Angles(0, math.rad(-90), 0), 29.2, WALL_HEIGHT, 0.8, {
		{ X0 = -9, X1 = -4, Y0 = 3.2, Y1 = 7.2 },
		{ X0 = 4, X1 = 9, Y0 = 3.2, Y1 = 7.2 },
	}, Palette.Wall, PLASTIC)

	-- timber corners + beams
	for _, x in { -16, 16 } do
		for _, z in { FRONT_Z, BACK_Z } do
			Build.part(structure, "Corner", Vector3.new(1, WALL_HEIGHT + 0.4, 1), L(x, (WALL_HEIGHT + 0.4) / 2, z), Palette.WoodDark, WOOD)
		end
	end
	Build.part(structure, "BeamFront", Vector3.new(32.6, 0.6, 1), L(0, WALL_HEIGHT, FRONT_Z), Palette.WoodDark, WOOD)
	Build.part(structure, "BeamBack", Vector3.new(32.6, 0.6, 1), L(0, WALL_HEIGHT, BACK_Z), Palette.WoodDark, WOOD)
	Build.part(structure, "BeamSide", Vector3.new(1, 0.6, 30.6), L(-16, WALL_HEIGHT, MID_Z), Palette.WoodDark, WOOD)
	Build.part(structure, "BeamSide", Vector3.new(1, 0.6, 30.6), L(16, WALL_HEIGHT, MID_Z), Palette.WoodDark, WOOD)

	-- windows (front pair + two on each side)
	buildWindow(structure, L(-11, 5.2, frontWallZ), roofColor, house.ShutterParts)
	buildWindow(structure, L(11, 5.2, frontWallZ), roofColor, house.ShutterParts)
	for _, z in { -6.5, 6.5 } do
		buildWindow(structure, L(-15.6, 5.2, MID_Z + z) * CFrame.Angles(0, math.rad(90), 0), roofColor, house.ShutterParts)
		buildWindow(structure, L(15.6, 5.2, MID_Z + z) * CFrame.Angles(0, math.rad(-90), 0), roofColor, house.ShutterParts)
	end

	-- double door: frame, lintel and two leaves swung open against the front wall
	for _, side in { -1, 1 } do
		Build.deco(structure, "DoorFrame", Vector3.new(0.6, 8.2, 1.1), L(side * 4.5, 4.1, frontWallZ), Palette.WoodDark, WOOD)
		local hinge = L(side * 4.2, 0, FRONT_Z - 0.4) * CFrame.Angles(0, side * math.rad(80), 0)
		Build.deco(structure, "DoorLeaf", Vector3.new(4.2, 7.8, 0.3), hinge * CFrame.new(-side * 2.1, 3.9, 0), doorColor, WOOD)
	end
	Build.deco(structure, "DoorLintel", Vector3.new(9.6, 0.7, 1.1), L(0, 8.35, frontWallZ), doorColor, WOOD)
	Build.part(structure, "PorchStep", Vector3.new(12, 0.5, 3), L(0, 0.25, FRONT_Z - 1.2), Palette.Stone, Enum.Material.Cobblestone)
	Build.deco(structure, "WelcomeMat", Vector3.new(6, 0.08, 1.8), L(0, 0.54, FRONT_Z - 1.2), Palette.Pink, PLASTIC)

	-----------------------------------------------------------------------
	-- roof (gable facing the street)
	-----------------------------------------------------------------------
	local slabLength = HALF_SPAN / math.cos(ROOF_PITCH) + 0.8
	local rise = HALF_SPAN * math.tan(ROOF_PITCH)
	for _, side in { -1, 1 } do
		local slab = Build.part(
			structure,
			"Roof",
			Vector3.new(slabLength, 0.8, 31.6),
			L(side * HALF_SPAN / 2, WALL_HEIGHT + rise / 2 + 0.45, MID_Z) * CFrame.Angles(0, 0, -side * ROOF_PITCH),
			roofColor,
			Enum.Material.Slate
		)
		table.insert(house.RoofParts, slab)
	end
	table.insert(house.RoofParts, Build.part(structure, "Ridge", Vector3.new(1.2, 0.7, 31.6), L(0, WALL_HEIGHT + rise + 0.45, MID_Z), roofColor, Enum.Material.Slate))

	local slices = 7
	for _, z in { FRONT_Z + 0.2, BACK_Z - 0.2 } do
		for slice = 1, slices do
			local sliceHeight = rise / slices
			local width = 32 * (1 - (slice - 0.5) / slices)
			Build.part(structure, "Gable", Vector3.new(width, sliceHeight + 0.02, 0.8), L(0, WALL_HEIGHT + (slice - 0.5) * sliceHeight, z), Palette.Wall, PLASTIC)
		end
	end
	-- rebirth banner + 10 stars under the front gable
	Build.part(structure, "Banner", Vector3.new(12, 1.8, 0.3), L(0, 12.2, FRONT_Z - 0.5), Palette.WoodDark, WOOD, { CanCollide = false })
	for starIndex = 1, 10 do
		local star = Build.blob(structure, "RebirthStar", Vector3.new(0.8, 0.8, 0.3), L(-4.95 + (starIndex - 1) * 1.1, 12.2, FRONT_Z - 0.78), Color3.fromRGB(70, 60, 70), PLASTIC, { CanCollide = false })
		table.insert(house.Stars, star)
	end

	-- chimney with smoke
	Build.part(structure, "Chimney", Vector3.new(2.4, 10, 2.4), L(10, 14.5, 38), Palette.Stone, Enum.Material.Brick)
	local chimneyTop = Build.part(structure, "ChimneyTop", Vector3.new(3, 0.5, 3), L(10, 19.75, 38), Palette.StoneDark, Enum.Material.Slate)
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

	-- roof name banner readable from far away (find your house)
	local roofAnchor = Build.deco(structure, "RoofAnchor", Vector3.one * 0.3, L(0, WALL_HEIGHT + rise + 4.2, MID_Z), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1 })
	house.Labels.Roof = Build.billboard(roofAnchor, "", Vector2.new(260, 44), Vector3.zero, { MaxDistance = 220, Name = "RoofName" })

	-----------------------------------------------------------------------
	-- interior: arrival pad, wheels, chest, upgrade pedestals
	-----------------------------------------------------------------------
	for _, z in { 24, 32, 40 } do
		Build.deco(interior, "Rafter", Vector3.new(31, 0.5, 0.6), L(0, WALL_HEIGHT + 0.2, z), Palette.WoodDark, WOOD)
	end
	for _, z in { 24, 40 } do
		local lamp = Build.blob(interior, "CeilingLamp", Vector3.new(1.8, 1.4, 1.8), L(0, WALL_HEIGHT - 1.4, z), Color3.fromRGB(255, 226, 160), NEON, { CanCollide = false })
		Build.light(lamp, Color3.fromRGB(255, 224, 170), 1.2, 30)
	end

	-- arrival pad: balls rolled home end here and become permanent
	local padLocal = WorldLayout.PadLocal
	Build.pillar(interior, "PadOuter", 7.6, 0.08, L(padLocal.X, FLOOR_TOP + 0.05, padLocal.Z), Palette.Pink, PLASTIC, { CanCollide = false })
	Build.pillar(interior, "PadInner", 5.8, 0.1, L(padLocal.X, FLOOR_TOP + 0.06, padLocal.Z), Palette.Cream, PLASTIC, { CanCollide = false })
	local padGlow = Build.pillar(interior, "PadGlow", 3.6, 0.12, L(padLocal.X, FLOOR_TOP + 0.07, padLocal.Z), Color3.fromRGB(255, 214, 120), NEON, { CanCollide = false, Transparency = 0.35 })
	padGlow:SetAttribute("Ripple", true)

	-- 12 wheel stations; the wheel itself appears when the slot is unlocked (see HouseSystem)
	local slotIndex = 0
	for _, z in WHEEL_ROWS do
		for _, x in WHEEL_XS do
			slotIndex += 1
			local center = L(x, WHEEL_CENTER_Y, z)
			local ring = Build.pillar(interior, "SlotRing", 4.2, 0.06, L(x, FLOOR_TOP + 0.04, z), Color3.fromRGB(90, 80, 90), NEON, { CanCollide = false, Transparency = 0.7 })
			local labelAnchor = Build.deco(interior, "WheelLabelAnchor", Vector3.one * 0.2, L(x, WHEEL_CENTER_Y + WHEEL_RADIUS + 1.2, z), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1 })
			table.insert(house.Slots, {
				Index = slotIndex,
				Center = center,
				RunCFrame = L(x, WHEEL_CENTER_Y - WHEEL_RADIUS + 0.1, z) * CFrame.Angles(0, -math.pi / 2, 0),
				Ring = ring,
				LabelAnchor = labelAnchor,
				Label = nil,
				Wheel = nil,
				Frame = Build.folder(wheelsFolder, "Wheel" .. slotIndex),
			})
		end
	end

	-- hamster chest (opens the inventory)
	local chestBody = Build.part(interior, "ChestBody", Vector3.new(3.4, 1.6, 2.2), L(9.5, FLOOR_TOP + 0.8, 19.6), Palette.WoodLight, WOOD)
	Build.part(interior, "ChestLid", Vector3.new(3.6, 0.7, 2.4), L(9.5, FLOOR_TOP + 1.95, 19.6), Palette.Wood, WOOD, { CanCollide = false })
	Build.deco(interior, "ChestLock", Vector3.new(0.5, 0.7, 0.2), L(9.5, FLOOR_TOP + 1.6, 18.4), Palette.Gold, Enum.Material.Metal)
	house.Prompts.Chest = makePrompt(chestBody, "Hamster Chest", "Open", "Inventory", nil, 10)

	-- upgrade pedestals: 4 on each side wall (props grow with every level)
	local stationZ = { 21, 25, 29, 33 }
	for stationIndex, upgradeId in UpgradeConfig.Order do
		local side = if stationIndex <= 4 then -1 else 1
		local z = stationZ[(stationIndex - 1) % 4 + 1]
		local x = side * 13.4
		local facing = CFrame.Angles(0, if side < 0 then math.rad(-90) else math.rad(90), 0)
		local base = Build.pillar(interior, "StationBase", 2.4, 1.8, L(x, FLOOR_TOP + 0.9, z), Palette.Cream, PLASTIC)
		Build.pillar(interior, "StationPlate", 2.8, 0.25, L(x, FLOOR_TOP + 1.9, z), Palette.WoodLight, WOOD, { CanCollide = false })
		local definition = UpgradeConfig.Definitions[upgradeId]
		local anchorPart = Build.deco(interior, "StationAnchor", Vector3.one * 0.2, L(x, FLOOR_TOP + 5.2, z), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1 })
		local label = Build.billboard(anchorPart, definition.Icon .. "\n" .. definition.Name, Vector2.new(180, 70), Vector3.zero, { MaxDistance = 34, Name = "StationLabel" })
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
	-- yard: altar, mailbox, name sign, a few trees and flower beds
	-----------------------------------------------------------------------
	-- rebirth altar
	Build.pillar(yard, "AltarBase", 4.4, 0.7, L(16.5, 0.35, 8), Palette.Stone, Enum.Material.Cobblestone)
	local altar = Build.pillar(yard, "AltarPillar", 2.4, 1.8, L(16.5, 1.6, 8), Palette.Cream, PLASTIC)
	Build.pillar(yard, "AltarCap", 3, 0.3, L(16.5, 2.65, 8), Palette.Gold, Enum.Material.Metal, { CanCollide = false })
	local orb = Build.blob(yard, "AltarOrb", Vector3.one * 1.6, L(16.5, 4.1, 8), Color3.fromRGB(255, 130, 60), NEON, { CanCollide = false })
	Build.light(orb, Color3.fromRGB(255, 150, 80), 1, 16)
	Build.animate(orb, "Bob", { Amplitude = 0.35, Speed = 1.6 })
	house.Prompts.Rebirth = makePrompt(altar, "Rebirth Altar", "Rebirth", "Rebirth", nil, 11)

	-- mailbox (daily gift)
	Build.part(yard, "MailPost", Vector3.new(0.5, 3.4, 0.5), L(-9, 1.7, 3.2), Palette.WoodDark, WOOD)
	local mailbox = Build.blob(yard, "Mailbox", Vector3.new(2.6, 1.8, 1.8), L(-9, 3.7, 3.2), Color3.fromRGB(100, 170, 255), PLASTIC)
	Build.deco(yard, "MailFlag", Vector3.new(0.2, 1.1, 0.5), L(-10.3, 4.1, 3.2), Color3.fromRGB(255, 90, 90), PLASTIC)
	house.Prompts.Mailbox = makePrompt(mailbox, "Mailbox", "Daily Gift", "Daily", nil, 10)

	-- name sign next to the gate (faces the street)
	Build.part(yard, "SignPost", Vector3.new(0.6, 5.2, 0.6), L(-21, 2.6, 2.4), Palette.WoodDark, WOOD)
	Build.part(yard, "SignPost", Vector3.new(0.6, 5.2, 0.6), L(-13, 2.6, 2.4), Palette.WoodDark, WOOD)
	local board = Build.part(yard, "SignBoard", Vector3.new(9.2, 4.2, 0.5), L(-17, 4, 2.4), Palette.WoodLight, WOOD, { CanCollide = false })
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

	-- garden: a few trees, bushes and flower beds (kept calm on purpose)
	Decor.tree(yard, (cframe * CFrame.new(-18, 0, 12)).Position, if index % 2 == 0 then "cherry" else "round", 1, rng)
	Decor.tree(yard, (cframe * CFrame.new(18, 0, 20)).Position, if index % 3 == 0 then "cherry" else "round", 1, rng)
	Decor.tree(yard, (cframe * CFrame.new(-20, 0, 52)).Position, "pine", 1, rng)
	Decor.tree(yard, (cframe * CFrame.new(20, 0, 52)).Position, "round", 1.1, rng)
	for _, x in { -8.5, 8.5 } do
		Decor.bush(yard, (cframe * CFrame.new(x, 0, 14.5)).Position, 0.9, rng, x < 0)
	end
	Decor.flowers(yard, (cframe * CFrame.new(-12, 0, 9)).Position, 3, 10, rng)
	Decor.flowers(yard, (cframe * CFrame.new(12, 0, 13)).Position, 3, 10, rng)
	Decor.bench(yard, cframe * CFrame.new(0, 0, 54) * CFrame.Angles(0, math.pi, 0))

	return house
end

---------------------------------------------------------------------------
-- dynamic refresh helpers (called by HouseSystem / SecuritySystem)
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

-- state: "Active" (gate on) | "Recharging" (off, can't be switched on yet) | "Ready" (off, press E at the pylon)
-- | "None" (nobody lives here). `tier` is a SecurityConfig tier.
function HouseBuilder.setSecurity(house: House, state: string, tier: any)
	local security = house.Security
	local active = state == "Active"
	for index, beam in security.Beams do
		beam.Transparency = if active and index <= tier.Beams then 0.05 else 1
		beam.Color = tier.Color
	end
	security.Field.Transparency = if active then 0.86 else 1
	security.Field.Color = tier.Color

	local lampColors = {
		Active = Color3.fromRGB(110, 230, 140),
		Recharging = Color3.fromRGB(255, 200, 80),
		Ready = Color3.fromRGB(255, 90, 90),
		None = Color3.fromRGB(170, 170, 180),
	}
	local lampColor = lampColors[state] or lampColors.None
	for _, lamp in security.Lamps do
		lamp.Color = lampColor
	end
	security.PylonLamp.Color = if state == "Ready" then Color3.fromRGB(110, 230, 140) else lampColor
	security.Prompt.Enabled = state == "Ready"
end

return HouseBuilder
