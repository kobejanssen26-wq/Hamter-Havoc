--[[
	A modern hamster apartment on a large plot. Built in a local frame, then placed with `cframe`:
	  origin = middle of the GATE LINE on the ground, +Z = into the lot, -Z = the street.
	  Lot: x in [-38, 38], z in [0, 96]. Building: x in [-26, 26], z in [32, 74], glass lift on the left.

	The building grows upward with Rebirths (FloorConfig): HouseSystem calls `setFloors`, which builds
	the missing floors, moves the roof up and shows scaffolding for the next floor. Every floor has a
	purpose:
	  1 Workshop       arrival pad, 6 wheels, 8 upgrade stations, hamster chest
	  2 Hamster Lofts  6 wheels (+10%), lounge
	  3 Research Lab   6 advanced wheels (+20%), advanced upgrade stations, lab benches
	  4 Golden Suites  6 golden wheels (+40%), chandelier, display plinths
	  5 Penthouse      6 diamond wheels (+75%), set back behind a rooftop terrace

	Front of the plot: the security gate is part of the architecture: two pillars with light strips,
	a canopy carrying the owner's name plate and rebirth stars, laser barrier between the pillars and
	a security panel with the re-activation button just inside.

	Dynamic things (names, stars, wheels, upgrade props, security lights, floors, prestige trim) are
	refreshed through the functions at the bottom by HouseSystem / SecuritySystem.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Build)
local Decor = require(script.Parent.Decor)
local Palette = require(script.Parent.Palette)

local FloorConfig = require(ReplicatedStorage.Modules.FloorConfig)
local SecurityConfig = require(ReplicatedStorage.Modules.SecurityConfig)
local UpgradeConfig = require(ReplicatedStorage.Modules.UpgradeConfig)
local WorldLayout = require(ReplicatedStorage.Modules.WorldLayout)

local HouseBuilder = {}

local WOOD = Enum.Material.WoodPlanks
local PLASTIC = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local GLASS = Enum.Material.Glass
local METAL = Enum.Material.Metal
local CONCRETE = Enum.Material.Concrete

-- building footprint (local)
local X0, X1 = -26, 26
local Z0, Z1 = WorldLayout.DoorZ, 74
local WIDTH = X1 - X0
local DEPTH = Z1 - Z0
local MID_Z = (Z0 + Z1) / 2
local WALL = 0.8
local FLOOR_TOP = 0.6 -- walking surface above a floor's base
local GROUND_HEIGHT = 12
local STOREY = 11

-- glass lift at the back of the left wall
local LIFT_X0, LIFT_X1 = -33.5, X0
local LIFT_Z0, LIFT_Z1 = 61, 73
local LIFT_DOOR_Z = 67

-- wheels (same grid on every floor)
local WHEEL_RADIUS = 3
local WHEEL_CENTER = FLOOR_TOP + WHEEL_RADIUS + 0.6 -- above a floor's base
local WHEEL_XS = { -14, 0, 14 }
local WHEEL_ZS = { 57, 67 }

export type Slot = {
	Index: number,
	Floor: number,
	Center: CFrame, -- wheel centre (axle along the centre's Z axis)
	RunCFrame: CFrame, -- where the running hamster stands (faces the centre's +X)
	Ring: BasePart, -- locked / empty marker on the floor
	LabelAnchor: BasePart,
	Label: TextLabel?,
	Wheel: Model?,
	Frame: Folder,
	SpinSign: number, -- +1 / -1: makes the wheel turn the right way for the running hamster
	Style: string,
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
	ElevatorPrompts: { [number]: ProximityPrompt },
	Slots: { [number]: Slot },
	Stations: { [string]: any },
	DisplayFolder: Folder,
	DisplayModels: { [number]: { SpeciesId: string, Model: Model } },
	FloorsFolder: Folder,
	FloorModels: { [number]: Model },
	FloorCount: number,
	Prestige: number,
	RoofFolder: Model,
	RoofAnchor: BasePart,
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

local function floorBase(floor: number): number
	if floor <= 1 then
		return 0
	end
	return GROUND_HEIGHT + (floor - 2) * STOREY
end

local function floorHeight(floor: number): number
	return if floor <= 1 then GROUND_HEIGHT else STOREY
end

HouseBuilder.floorBase = floorBase

-- Wall with rectangular openings. `baseCFrame` = bottom centre of the wall, the wall spans local X.
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

-- Glass panes + slim mullions for every opening flagged `Glass`.
local function glaze(parent: Instance, baseCFrame: CFrame, openings: { any }, frameColor: Color3)
	for _, opening in openings do
		if opening.Glass then
			local w, h = opening.X1 - opening.X0, opening.Y1 - opening.Y0
			local center = baseCFrame * CFrame.new((opening.X0 + opening.X1) / 2, (opening.Y0 + opening.Y1) / 2, 0)
			Build.part(parent, "Glass", Vector3.new(w, h, 0.2), center, Palette.Glass, GLASS, { Transparency = 0.55, CastShadow = false })
			local panes = math.max(1, math.floor(w / 5 + 0.5))
			for pane = 1, panes - 1 do
				Build.deco(parent, "Mullion", Vector3.new(0.25, h, 0.4), center * CFrame.new(-w / 2 + pane * w / panes, 0, 0), frameColor, METAL)
			end
			Build.deco(parent, "Sill", Vector3.new(w + 0.4, 0.3, 0.9), center * CFrame.new(0, -h / 2 - 0.1, -0.1), frameColor, METAL)
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

-- Glass railing along local X, centred on `cframe` (ground of the railing).
local function railing(parent: Instance, cframe: CFrame, length: number, color: Color3)
	Build.part(parent, "RailGlass", Vector3.new(length, 2.6, 0.2), cframe * CFrame.new(0, 1.5, 0), Palette.Glass, GLASS, { Transparency = 0.5, CastShadow = false })
	Build.part(parent, "Handrail", Vector3.new(length + 0.2, 0.25, 0.4), cframe * CFrame.new(0, 2.9, 0), color, METAL)
end

local function plant(parent: Instance, pos: CFrame, scale: number?)
	local s = scale or 1
	Build.pillar(parent, "Pot", 1.6 * s, 1.6 * s, pos * CFrame.new(0, 0.8 * s, 0), Palette.Cream, PLASTIC)
	Build.blob(parent, "Leaves", Vector3.new(2.6, 3, 2.6) * s, pos * CFrame.new(0, 2.8 * s, 0), Palette.LeafDark, Enum.Material.Grass, { CanCollide = false })
end

local function sofa(parent: Instance, cframe: CFrame, color: Color3)
	Build.part(parent, "SofaSeat", Vector3.new(7, 1.2, 2.6), cframe * CFrame.new(0, 1, 0), color, Enum.Material.Fabric)
	Build.part(parent, "SofaBack", Vector3.new(7, 2.2, 0.8), cframe * CFrame.new(0, 2.2, 1.1), color, Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		Build.part(parent, "SofaArm", Vector3.new(0.8, 1.8, 2.6), cframe * CFrame.new(side * 3.5, 1.4, 0), color, Enum.Material.Fabric)
	end
	Build.deco(parent, "Cushion", Vector3.new(1.4, 1.2, 0.5), cframe * CFrame.new(-2.2, 2, 0.6) * CFrame.Angles(math.rad(-12), 0, 0), Palette.Cream, Enum.Material.Fabric)
end

local function rug(parent: Instance, cframe: CFrame, size: Vector2, color: Color3, border: Color3)
	Build.deco(parent, "RugBorder", Vector3.new(size.X, 0.06, size.Y), cframe * CFrame.new(0, 0.03, 0), border, Enum.Material.Fabric)
	Build.deco(parent, "Rug", Vector3.new(size.X - 1, 0.08, size.Y - 1), cframe * CFrame.new(0, 0.05, 0), color, Enum.Material.Fabric)
end

local function ceilingLight(parent: Instance, cframe: CFrame, color: Color3?)
	local lamp = Build.deco(parent, "CeilingLight", Vector3.new(4, 0.25, 4), cframe, Color3.fromRGB(255, 236, 200), NEON)
	Build.light(lamp, color or Color3.fromRGB(255, 226, 180), 1.1, 26)
	return lamp
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


propBuilders.TurboWheels = function(folder, top, fraction, ghost)
	local size = 1 + fraction * 0.8
	local center = top * CFrame.new(0, size + 0.5, 0)
	local wheel = Build.model(folder, "TurboWheel")
	local disc = Build.part(wheel, "Disc", Vector3.new(0.5, size * 2, size * 2), center, Color3.fromRGB(150, 230, 170), NEON, { Shape = Enum.PartType.Cylinder, Transparency = 0.35 + ghost / 2, CanCollide = false })
	Build.deco(wheel, "Bar", Vector3.new(0.3, size * 2.1, 0.25), center, Palette.Ink, METAL, { Transparency = ghost })
	wheel.PrimaryPart = disc
	wheel:SetAttribute("HomeCFrame", center)
	Build.animate(wheel, "SpinModel", { Speed = 2 + fraction * 8, Axis = "X" })
end

propBuilders.LuckyCharms = function(folder, top, fraction, ghost)
	local charms = 1 + math.floor(fraction * 4)
	for index = 1, charms do
		local angle = index * 1.25
		local horseshoe = top * CFrame.new(math.cos(angle) * 0.9, 1 + index * 0.35, math.sin(angle) * 0.9) * CFrame.Angles(0, angle, 0)
		Build.deco(folder, "Charm", Vector3.new(0.9, 0.9, 0.25), horseshoe, Color3.fromRGB(120, 230, 140), NEON, { Transparency = ghost })
	end
	local orb = Build.blob(folder, "LuckOrb", Vector3.one * (0.9 + fraction * 0.7), top * CFrame.new(0, 3.2, 0), Color3.fromRGB(150, 255, 170), NEON, { CanCollide = false, Transparency = 0.2 + ghost })
	Build.animate(orb, "Bob", { Amplitude = 0.2, Speed = 2 })
end

---------------------------------------------------------------------------
-- hamster wheels (built on demand when a slot is unlocked)
---------------------------------------------------------------------------

local WHEEL_STYLES = {
	BasicWheel = { Frame = Palette.Wood, FrameDark = Palette.WoodDark, Material = WOOD, Rim = Palette.Glass, Rung = Palette.Gold, RimNeon = false },
	AdvancedWheel = { Frame = Color3.fromRGB(226, 232, 236), FrameDark = Color3.fromRGB(150, 160, 170), Material = METAL, Rim = Color3.fromRGB(150, 230, 170), Rung = Color3.fromRGB(240, 246, 250), RimNeon = true },
	PremiumWheel = { Frame = Color3.fromRGB(250, 246, 236), FrameDark = Palette.Gold, Material = Enum.Material.Marble, Rim = Palette.Gold, Rung = Color3.fromRGB(200, 240, 255), RimNeon = true },
}
HouseBuilder.WheelStyles = WHEEL_STYLES

-- The direction a wheel has to turn so that the floor of the wheel moves BACKWARDS under a hamster
-- that runs forwards (like a treadmill). Spinning is done on the client around the hub's own X axis
-- (the axle, see AmbientController), so we work it out from the real geometry instead of guessing:
--   axle a, contact point r (straight down from the centre), surface velocity for +spin = a x r.
-- If that velocity points the way the hamster faces, the wheel must spin the other way.
function HouseBuilder.spinSign(hubCFrame: CFrame, runForward: Vector3): number
	local axle = hubCFrame.XVector
	local contact = -Vector3.yAxis -- the hamster runs on the bottom of the wheel
	local surface = axle:Cross(contact)
	return if surface:Dot(runForward) > 0 then -1 else 1
end

local function buildWheel(slot: Slot)
	local frame = slot.Frame
	frame:ClearAllChildren()
	local style = WHEEL_STYLES[slot.Style] or WHEEL_STYLES.BasicWheel
	local center = slot.Center
	local function C(x: number, y: number, z: number): CFrame
		return center * CFrame.new(x, y, z)
	end
	local alongZ = CFrame.Angles(0, math.rad(90), 0) -- turns a cylinder's X axis onto the centre's Z (the axle)

	-- stand: base plate, two A-frames, axle (static)
	local floorY = -(WHEEL_RADIUS + 0.6) + 0.175
	Build.part(frame, "WheelBase", Vector3.new(7.4, 0.35, 4.4), C(0, floorY, 0), style.FrameDark, style.Material)
	local legRise = WHEEL_RADIUS + 0.6 - 0.35
	local legOffset = 2
	local legLength = math.sqrt(legRise * legRise + legOffset * legOffset)
	local legTilt = math.atan2(legOffset, legRise)
	for _, z in { -1.9, 1.9 } do
		for _, side in { -1, 1 } do
			Build.part(frame, "WheelLeg", Vector3.new(0.4, legLength, 0.4), C(side * legOffset / 2, -legRise / 2, z) * CFrame.Angles(0, 0, side * legTilt), style.Frame, style.Material, { CanCollide = false })
		end
	end
	Build.deco(frame, "Axle", Vector3.new(4.6, 0.45, 0.45), C(0, 0, 0) * alongZ, Palette.Stone, METAL, { Shape = Enum.PartType.Cylinder })

	-- the turning part: hub, two rims, rungs. The hub's X axis IS the axle.
	local wheel = Build.model(frame, "Wheel")
	local hubCFrame = C(0, 0, 0) * alongZ
	local hub = Build.deco(wheel, "Hub", Vector3.new(3.4, 1.1, 1.1), hubCFrame, style.Frame, style.Material, { Shape = Enum.PartType.Cylinder })
	for _, z in { -1.45, 1.45 } do
		Build.deco(wheel, "Side", Vector3.new(0.14, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2), C(0, 0, z) * alongZ, Palette.Glass, GLASS, { Shape = Enum.PartType.Cylinder, Transparency = 0.68 })
		Build.deco(wheel, "Rim", Vector3.new(0.3, WHEEL_RADIUS * 2 + 0.3, WHEEL_RADIUS * 2 + 0.3), C(0, 0, z * 1.04) * alongZ, style.Rim, if style.RimNeon then NEON else METAL, { Shape = Enum.PartType.Cylinder, Transparency = 0.15 })
	end
	for rung = 0, 9 do
		local angle = rung * math.pi / 5
		local radius = WHEEL_RADIUS - 0.1
		Build.deco(wheel, "Rung", Vector3.new(3, 0.22, 0.22), C(math.cos(angle) * radius, math.sin(angle) * radius, 0) * alongZ, style.Rung, METAL, { Shape = Enum.PartType.Cylinder })
	end
	-- a few spokes so the turning reads clearly
	for spoke = 0, 2 do
		Build.deco(wheel, "Spoke", Vector3.new(0.18, WHEEL_RADIUS * 2 - 0.4, 0.18), C(0, 0, 1.45) * CFrame.Angles(0, 0, spoke * math.pi / 3), style.Rung, METAL)
	end
	wheel.PrimaryPart = hub
	wheel:SetAttribute("HomeCFrame", hubCFrame)
	Build.animate(wheel, "SpinModel", { Speed = 0, Axis = "X" })
	slot.Wheel = wheel
end

-- Creates (unlocked) or removes (locked) the wheel in a slot.
function HouseBuilder.setWheel(house: House, slotIndex: number, unlocked: boolean)
	local slot = house.Slots[slotIndex]
	if not slot then
		return
	end
	if unlocked and not slot.Wheel then
		buildWheel(slot)
	elseif not unlocked and slot.Wheel then
		slot.Frame:ClearAllChildren()
		slot.Wheel = nil
	end
end

-- `speed` in rad/s (>= 0). The sign that makes it turn the right way is applied here.
function HouseBuilder.setWheelSpeed(slot: Slot, speed: number)
	if slot.Wheel then
		slot.Wheel:SetAttribute("Speed", speed * slot.SpinSign)
	end
end

local function makeSlot(house: House, parent: Instance, wheelsFolder: Instance, floor: number, cframe: CFrame)
	local base = floorBase(floor)
	local style = FloorConfig.Floors[floor].WheelStyle
	local function L(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end
	local index = 0
	for row, z in WHEEL_ZS do
		for column, x in WHEEL_XS do
			index = (row - 1) * #WHEEL_XS + column
			local slotIndex = (floor - 1) * FloorConfig.WheelsPerFloor + index
			local center = L(x, base + WHEEL_CENTER, z)
			local runCFrame = L(x, base + WHEEL_CENTER - WHEEL_RADIUS + 0.15, z) * CFrame.Angles(0, -math.pi / 2, 0)
			local ring = Build.pillar(parent, "SlotRing", 5.4, 0.06, L(x, base + FLOOR_TOP + 0.04, z), Color3.fromRGB(90, 80, 90), NEON, { CanCollide = false, Transparency = 0.7 })
			local labelAnchor = Build.deco(parent, "WheelLabelAnchor", Vector3.one * 0.2, L(x, base + WHEEL_CENTER + WHEEL_RADIUS + 1.4, z), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1 })
			local hubCFrame = center * CFrame.Angles(0, math.rad(90), 0)
			house.Slots[slotIndex] = {
				Index = slotIndex,
				Floor = floor,
				Center = center,
				RunCFrame = runCFrame,
				Ring = ring,
				LabelAnchor = labelAnchor,
				Label = nil,
				Wheel = nil,
				Frame = Build.folder(wheelsFolder, "Wheel" .. slotIndex),
				SpinSign = HouseBuilder.spinSign(hubCFrame, runCFrame.LookVector),
				Style = style,
			}
		end
	end
end

---------------------------------------------------------------------------
-- floors
---------------------------------------------------------------------------

type FloorStyle = { Wall: Color3, Trim: Color3, Material: Enum.Material, FloorColor: Color3, FloorMaterial: Enum.Material }

local FLOOR_STYLES: { [number]: FloorStyle } = {
	[1] = { Wall = Palette.Wall, Trim = Palette.StoneDark, Material = PLASTIC, FloorColor = Palette.WoodLight, FloorMaterial = WOOD },
	[2] = { Wall = Color3.fromRGB(252, 240, 222), Trim = Palette.Wood, Material = PLASTIC, FloorColor = Color3.fromRGB(214, 170, 120), FloorMaterial = WOOD },
	[3] = { Wall = Color3.fromRGB(244, 248, 250), Trim = Color3.fromRGB(120, 200, 150), Material = PLASTIC, FloorColor = Color3.fromRGB(226, 232, 236), FloorMaterial = Enum.Material.Marble },
	[4] = { Wall = Color3.fromRGB(62, 58, 72), Trim = Palette.Gold, Material = PLASTIC, FloorColor = Color3.fromRGB(120, 84, 60), FloorMaterial = WOOD },
	[5] = { Wall = Color3.fromRGB(250, 250, 252), Trim = Color3.fromRGB(200, 150, 255), Material = Enum.Material.Marble, FloorColor = Color3.fromRGB(240, 236, 228), FloorMaterial = Enum.Material.Marble },
}

-- Penthouse is set back from the front so the floor below becomes a rooftop terrace.
local function frontZ(floor: number): number
	return if floor >= 5 then Z0 + 8 else Z0
end

local function accent(part: BasePart): BasePart
	part:SetAttribute("Accent", true)
	return part
end

-- Wall plan for one floor. Openings are in each wall's own X (see wallWithOpenings).
local function buildShell(model: Model, house: House, floor: number, L: (number, number, number) -> CFrame)
	local base = floorBase(floor)
	local height = floorHeight(floor)
	local style = FLOOR_STYLES[floor]
	local fz = frontZ(floor)
	local midZ = (fz + Z1) / 2
	local depth = Z1 - fz

	-- slab (floor 1: foundation)
	if floor == 1 then
		Build.part(model, "Foundation", Vector3.new(WIDTH + 1.2, FLOOR_TOP, DEPTH + 1.2), L(0, FLOOR_TOP / 2, MID_Z), Palette.StoneDark, Enum.Material.Slate)
	else
		Build.part(model, "Slab", Vector3.new(WIDTH + 1, 0.9, DEPTH + 1), L(0, base + FLOOR_TOP - 0.45, MID_Z), Palette.StoneDark, CONCRETE)
		accent(Build.deco(model, "SlabBand", Vector3.new(WIDTH + 1.2, 0.5, 0.3), L(0, base + 0.35, Z0 - 0.55), house.DefaultRoof, PLASTIC))
	end
	Build.part(model, "Floor", Vector3.new(WIDTH - 0.4, 0.12, depth - 0.4), L(0, base + FLOOR_TOP + 0.02, midZ), style.FloorColor, style.FloorMaterial, { CanCollide = false })

	-- openings: the front differs per floor, the lift door is on the left wall of every floor
	local liftU0, liftU1 = MID_Z - (LIFT_DOOR_Z + 3), MID_Z - (LIFT_DOOR_Z - 3)
	local front, back, left, right
	if floor == 1 then
		front = {
			{ X0 = -5, X1 = 5, Y0 = 0, Y1 = 9.6 },
			{ X0 = -23, X1 = -8, Y0 = 2.4, Y1 = 10.4, Glass = true },
			{ X0 = 8, X1 = 23, Y0 = 2.4, Y1 = 10.4, Glass = true },
		}
	elseif floor == 5 then
		front = {
			{ X0 = -6, X1 = 6, Y0 = FLOOR_TOP, Y1 = 9, },
			{ X0 = -24, X1 = -8, Y0 = 1.2, Y1 = 10.2, Glass = true },
			{ X0 = 8, X1 = 24, Y0 = 1.2, Y1 = 10.2, Glass = true },
		}
	else
		front = {
			{ X0 = -6, X1 = 6, Y0 = FLOOR_TOP, Y1 = 9, }, -- balcony door
			{ X0 = -23, X1 = -10, Y0 = 2, Y1 = 9.2, Glass = true },
			{ X0 = 10, X1 = 23, Y0 = 2, Y1 = 9.2, Glass = true },
		}
	end
	back = { { X0 = -21, X1 = -7, Y0 = 2.6, Y1 = 9.4, Glass = true }, { X0 = 7, X1 = 21, Y0 = 2.6, Y1 = 9.4, Glass = true } }
	left = {
		{ X0 = liftU0, X1 = liftU1, Y0 = FLOOR_TOP, Y1 = 8.6 },
		{ X0 = MID_Z - 49, X1 = MID_Z - 36, Y0 = 2.6, Y1 = 9.4, Glass = true },
	}
	right = {
		{ X0 = 38 - MID_Z, X1 = 50 - MID_Z, Y0 = 2.6, Y1 = 9.4, Glass = true },
		{ X0 = 57 - MID_Z, X1 = 70 - MID_Z, Y0 = 2.6, Y1 = 9.4, Glass = true },
	}
	if floor == 5 then
		left[2] = { X0 = MID_Z - 52, X1 = MID_Z - 42, Y0 = 2.6, Y1 = 9.4, Glass = true }
		right[1] = { X0 = 43 - MID_Z, X1 = 52 - MID_Z, Y0 = 2.6, Y1 = 9.4, Glass = true }
	end

	local frontBase = L(0, base, fz + WALL / 2)
	local backBase = L(0, base, Z1 - WALL / 2)
	local leftBase = L(X0 + WALL / 2, base, MID_Z) * CFrame.Angles(0, math.rad(90), 0)
	local rightBase = L(X1 - WALL / 2, base, MID_Z) * CFrame.Angles(0, math.rad(-90), 0)
	wallWithOpenings(model, "WallFront", frontBase, WIDTH, height, WALL, front, style.Wall, style.Material)
	wallWithOpenings(model, "WallBack", backBase, WIDTH, height, WALL, back, style.Wall, style.Material)
	if floor == 5 then
		-- penthouse side walls only cover the set-back part (re-centre their openings)
		local sideLength = Z1 - fz
		local sideMid = (fz + Z1) / 2
		local shift = sideMid - MID_Z
		local function shifted(list: { any }, delta: number): { any }
			local out = {}
			for _, o in list do
				table.insert(out, { X0 = o.X0 + delta, X1 = o.X1 + delta, Y0 = o.Y0, Y1 = o.Y1, Glass = o.Glass })
			end
			return out
		end
		left = shifted(left, shift)
		right = shifted(right, -shift)
		leftBase = L(X0 + WALL / 2, base, sideMid) * CFrame.Angles(0, math.rad(90), 0)
		rightBase = L(X1 - WALL / 2, base, sideMid) * CFrame.Angles(0, math.rad(-90), 0)
		wallWithOpenings(model, "WallLeft", leftBase, sideLength, height, WALL, left, style.Wall, style.Material)
		wallWithOpenings(model, "WallRight", rightBase, sideLength, height, WALL, right, style.Wall, style.Material)
	else
		wallWithOpenings(model, "WallLeft", leftBase, DEPTH, height, WALL, left, style.Wall, style.Material)
		wallWithOpenings(model, "WallRight", rightBase, DEPTH, height, WALL, right, style.Wall, style.Material)
	end
	glaze(model, frontBase * CFrame.new(0, 0, -0.1), front, style.Trim)
	glaze(model, backBase * CFrame.new(0, 0, 0.1), back, style.Trim)
	glaze(model, leftBase * CFrame.new(0, 0, -0.1), left, style.Trim)
	glaze(model, rightBase * CFrame.new(0, 0, -0.1), right, style.Trim)

	-- corner pilasters tie the floors together visually
	for _, x in { X0, X1 } do
		for _, z in { fz, Z1 } do
			Build.part(model, "Pilaster", Vector3.new(1.4, height, 1.4), L(x, base + height / 2, z), style.Trim, if floor == 4 then METAL else CONCRETE)
		end
	end

	-- floor 4: gold window frames (the "golden" floor reads from the street)
	if floor == 4 then
		for _, opening in front do
			if opening.Glass then
				local w = opening.X1 - opening.X0
				local cx = (opening.X0 + opening.X1) / 2
				accent(Build.deco(model, "GoldFrame", Vector3.new(w + 0.8, 0.4, 0.5), L(cx, base + opening.Y1 + 0.2, fz - 0.2), Palette.Gold, METAL))
				accent(Build.deco(model, "GoldFrame", Vector3.new(w + 0.8, 0.4, 0.5), L(cx, base + opening.Y0 - 0.2, fz - 0.2), Palette.Gold, METAL))
			end
		end
	end

	-- floor sign inside next to the lift
	local definition = FloorConfig.Floors[floor]
	local sign = Build.part(model, "FloorSign", Vector3.new(0.3, 2.6, 8), L(X0 + WALL + 0.2, base + 7, 57), Palette.Ink, PLASTIC, { CanCollide = false })
	local bonus = if definition.WheelBonus > 0 then string.format("  +%d%% income", math.floor(definition.WheelBonus * 100 + 0.5)) else ""
	Build.surfaceText(sign, Enum.NormalId.Right, string.format('<font color="#%s">FLOOR %d</font>  %s\n<font size="20">%s%s</font>', definition.Accent:ToHex(), floor, string.upper(definition.Name), definition.Purpose, bonus), { TextColor = Palette.Cream, PixelsPerStud = 30 })

	-- lights
	ceilingLight(model, L(0, base + height - 0.3, 44))
	ceilingLight(model, L(0, base + height - 0.3, 63))
end

-- Lift landing: a call panel next to the lift door on every floor.
local function buildLiftPanel(model: Model, house: House, floor: number, L: (number, number, number) -> CFrame)
	local base = floorBase(floor)
	local panel = Build.part(model, "LiftPanel", Vector3.new(0.6, 2.4, 1.6), L(X0 + WALL + 0.35, base + FLOOR_TOP + 3.2, LIFT_DOOR_Z - 4.4), Palette.Ink, METAL, { CanCollide = false })
	Build.deco(model, "LiftButton", Vector3.new(0.2, 0.6, 0.6), L(X0 + WALL + 0.7, base + FLOOR_TOP + 3.4, LIFT_DOOR_Z - 4.4), Color3.fromRGB(255, 214, 120), NEON)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Lift"
	prompt.ActionText = "Ride"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt:SetAttribute("LiftHouse", house.Index)
	prompt:SetAttribute("LiftFloor", floor)
	prompt.Parent = panel
	house.ElevatorPrompts[floor] = prompt
end

-- Where somebody arrives on a floor (inside, in front of the lift, looking into the room).
function HouseBuilder.landingCFrame(house: House, floor: number): CFrame
	return house.CFrame * CFrame.new(X0 + 4.5, floorBase(floor) + FLOOR_TOP + 3, LIFT_DOOR_Z) * CFrame.Angles(0, math.rad(-90), 0)
end

local function buildStation(house: House, parent: Instance, upgradeId: string, cframe: CFrame)
	local base = Build.pillar(parent, "StationBase", 2.6, 1.8, cframe * CFrame.new(0, 0.9, 0), Palette.Cream, PLASTIC)
	Build.pillar(parent, "StationPlate", 3, 0.25, cframe * CFrame.new(0, 1.9, 0), Palette.WoodLight, WOOD, { CanCollide = false })
	local definition = UpgradeConfig.Definitions[upgradeId]
	local anchorPart = Build.deco(parent, "StationAnchor", Vector3.one * 0.2, cframe * CFrame.new(0, 5.4, 0), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1 })
	local label = Build.billboard(anchorPart, definition.Name, Vector2.new(180, 52), Vector3.zero, { MaxDistance = 34, Name = "StationLabel" })
	local propFolder = Build.folder(parent, "Prop_" .. upgradeId)
	local prompt = makePrompt(base, definition.Name, "Upgrade", "Upgrades", upgradeId, 9)
	if house.Owner then
		prompt:SetAttribute("OwnerUserId", house.Owner.UserId)
	end
	house.Prompts[upgradeId] = prompt
	local top = cframe * CFrame.new(0, 2.05, 0)
	house.Stations[upgradeId] = { Id = upgradeId, Label = label, PropFolder = propFolder, Top = top }
	propBuilders[upgradeId](propFolder, top, 0.05, 0.6)
end

-- Furniture and purpose of each floor.
local function furnishFloor(model: Model, house: House, floor: number, L: (number, number, number) -> CFrame)
	local top = floorBase(floor) + FLOOR_TOP
	local definition = FloorConfig.Floors[floor]
	if floor == 1 then
		-- arrival pad: balls rolled home end here and become permanent
		local padLocal = WorldLayout.PadLocal
		Build.pillar(model, "PadOuter", 7.6, 0.08, L(padLocal.X, top + 0.05, padLocal.Z), Palette.Pink, PLASTIC, { CanCollide = false })
		Build.pillar(model, "PadInner", 5.8, 0.1, L(padLocal.X, top + 0.06, padLocal.Z), Palette.Cream, PLASTIC, { CanCollide = false })
		local padGlow = Build.pillar(model, "PadGlow", 3.6, 0.12, L(padLocal.X, top + 0.07, padLocal.Z), Color3.fromRGB(255, 214, 120), NEON, { CanCollide = false, Transparency = 0.35 })
		padGlow:SetAttribute("Ripple", true)
		rug(model, L(0, top, 47), Vector2.new(16, 6), Palette.Peach, Palette.WoodDark)

		-- upgrade stations along both side walls
		local basic = {}
		for _, id in UpgradeConfig.Order do
			if (UpgradeConfig.Definitions[id].RequiresFloor or 1) <= 1 then
				table.insert(basic, id)
			end
		end
		local stationZ = { 37, 43, 49, 55 }
		for stationIndex, upgradeId in basic do
			local side = if stationIndex <= 4 then -1 else 1
			local z = stationZ[(stationIndex - 1) % 4 + 1]
			local facing = CFrame.Angles(0, if side < 0 then math.rad(-90) else math.rad(90), 0)
			buildStation(house, model, upgradeId, L(side * 21.5, top, z) * facing)
		end

		-- hamster chest (opens the inventory)
		local chestBody = Build.part(model, "ChestBody", Vector3.new(3.4, 1.6, 2.2), L(10.5, top + 0.8, 35.6), Palette.WoodLight, WOOD)
		Build.part(model, "ChestLid", Vector3.new(3.6, 0.7, 2.4), L(10.5, top + 1.95, 35.6), Palette.Wood, WOOD, { CanCollide = false })
		Build.deco(model, "ChestLock", Vector3.new(0.5, 0.7, 0.2), L(10.5, top + 1.6, 34.4), Palette.Gold, METAL)
		house.Prompts.Chest = makePrompt(chestBody, "Hamster Chest", "Open", "Inventory", nil, 10)

		plant(model, L(-23.6, top, 34.6))
		plant(model, L(23.6, top, 71.6))
		plant(model, L(-6.5, top, 34.4), 0.8)
		plant(model, L(6.5, top, 34.4), 0.8)
	elseif floor == 2 then
		-- loft lounge
		rug(model, L(-12, top, 42), Vector2.new(14, 10), Color3.fromRGB(240, 196, 150), Palette.WoodDark)
		sofa(model, L(-12, top, 37.2) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(110, 150, 210))
		Build.part(model, "CoffeeTable", Vector3.new(5, 1.2, 2.4), L(-12, top + 0.6, 42), Palette.WoodDark, WOOD)
		Build.part(model, "Bookshelf", Vector3.new(1.4, 7, 9), L(24.4, top + 3.5, 42), Palette.Wood, WOOD)
		for row = 1, 3 do
			for book = 1, 6 do
				local color = Palette.FlowerColors[(book + row) % #Palette.FlowerColors + 1]
				Build.deco(model, "Book", Vector3.new(0.6, 1.2, 0.9), L(23.6, top + row * 2, 38.6 + book * 1.15), color, PLASTIC)
			end
		end
		plant(model, L(-23.6, top, 34.6))
		plant(model, L(4.5, top, 35))
	elseif floor == 3 then
		-- research lab: advanced upgrades + glowing lab benches
		local advanced = {}
		for _, id in UpgradeConfig.Order do
			if (UpgradeConfig.Definitions[id].RequiresFloor or 1) == 3 then
				table.insert(advanced, id)
			end
		end
		for index, upgradeId in advanced do
			local x = (index - (#advanced + 1) / 2) * 12
			buildStation(house, model, upgradeId, L(x, top, 41))
		end
		for _, side in { -1, 1 } do
			Build.part(model, "LabBench", Vector3.new(3, 3, 12), L(side * 22.6, top + 1.5, 42), Color3.fromRGB(236, 240, 244), PLASTIC)
			Build.deco(model, "LabTop", Vector3.new(3.4, 0.3, 12.4), L(side * 22.6, top + 3.1, 42), Palette.Ink, Enum.Material.Slate)
			for flask = 1, 4 do
				local color = ({ Color3.fromRGB(150, 230, 170), Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 150, 210), Color3.fromRGB(255, 214, 120) })[flask]
				Build.deco(model, "Flask", Vector3.new(0.9, 1.4, 0.9), L(side * 22.6, top + 4, 37.5 + flask * 2.2), color, NEON, { Shape = Enum.PartType.Ball, Transparency = 0.15 })
			end
		end
		local tube = Build.pillar(model, "GlowTube", 2.2, 8.4, L(0, top + 4.2, 49), Color3.fromRGB(150, 230, 170), NEON, { Transparency = 0.45, CanCollide = false })
		Build.light(tube, Color3.fromRGB(150, 230, 170), 1, 18)
	elseif floor == 4 then
		-- golden suites: chandelier, rug, two plinths
		rug(model, L(0, top, 43), Vector2.new(22, 12), Color3.fromRGB(150, 40, 60), Palette.Gold)
		local ring = Build.pillar(model, "Chandelier", 6, 0.6, L(0, top + 8.2, 44), Palette.Gold, METAL, { CanCollide = false })
		Build.light(ring, Color3.fromRGB(255, 220, 150), 1.4, 28)
		for crystal = 0, 7 do
			local angle = crystal * math.pi / 4
			Build.deco(model, "Crystal", Vector3.new(0.5, 1.2, 0.5), L(math.cos(angle) * 2.6, top + 7.3, 44 + math.sin(angle) * 2.6), Color3.fromRGB(255, 246, 220), NEON)
		end
		for _, side in { -1, 1 } do
			Build.part(model, "Plinth", Vector3.new(3, 3.2, 3), L(side * 19, top + 1.6, 38), Palette.Cream, Enum.Material.Marble)
			Build.blob(model, "GoldenHamster", Vector3.new(2.2, 2, 2.6), L(side * 19, top + 4.2, 38), Palette.Gold, METAL)
		end
	elseif floor == 5 then
		-- penthouse: lounge inside, terrace with loungers and a small pool outside
		rug(model, L(0, top, 47), Vector2.new(18, 10), Color3.fromRGB(230, 220, 250), Color3.fromRGB(200, 150, 255))
		sofa(model, L(0, top, 52) , Color3.fromRGB(200, 150, 255))
		Build.part(model, "CrownPlinth", Vector3.new(3.4, 2.8, 3.4), L(18, top + 1.4, 46), Palette.Cream, Enum.Material.Marble)
		local crown = Build.part(model, "Crown", Vector3.new(2.4, 1.4, 2.4), L(18, top + 3.5, 46), Palette.Gold, METAL)
		Build.animate(crown, "Bob", { Amplitude = 0.2, Speed = 1.4 })
		local terraceTop = top
		Build.part(model, "Pool", Vector3.new(12, 0.3, 4.6), L(-12, terraceTop + 0.2, 35.6), Color3.fromRGB(96, 190, 235), GLASS, { Transparency = 0.2, Reflectance = 0.2, CanCollide = false })
		Build.part(model, "PoolEdge", Vector3.new(13.2, 0.5, 5.8), L(-12, terraceTop + 0.05, 35.6), Palette.Cream, Enum.Material.Marble)
		for _, x in { 8, 14 } do
			Build.part(model, "Lounger", Vector3.new(2.2, 0.6, 5), L(x, terraceTop + 0.5, 35.6), Palette.Cream, PLASTIC)
			Build.part(model, "LoungerBack", Vector3.new(2.2, 0.4, 2), L(x, terraceTop + 1.2, 37.4) * CFrame.Angles(math.rad(35), 0, 0), Palette.Cream, PLASTIC)
		end
		plant(model, L(-23.5, terraceTop, 34.5), 1.1)
		plant(model, L(23.5, terraceTop, 34.5), 1.1)
	end
	-- every floor except the ground floor gets a front balcony / terrace railing
	if floor >= 2 then
		local railZ = Z0 - (if floor >= 5 then 0.4 else 3.6)
		if floor < 5 then
			Build.part(model, "Balcony", Vector3.new(14, 0.6, 4), L(0, floorBase(floor) + FLOOR_TOP - 0.3, Z0 - 2), Palette.StoneDark, CONCRETE)
			railing(model, L(0, floorBase(floor) + FLOOR_TOP, railZ), 14, FLOOR_STYLES[floor].Trim)
			for _, side in { -1, 1 } do
				Build.part(model, "RailGlass", Vector3.new(0.2, 2.6, 4), L(side * 7, floorBase(floor) + FLOOR_TOP + 1.5, Z0 - 2), Palette.Glass, GLASS, { Transparency = 0.5, CastShadow = false })
			end
		else
			railing(model, L(0, floorBase(floor) + FLOOR_TOP, Z0 + 0.4), WIDTH, FLOOR_STYLES[floor].Trim)
		end
	end
	model:SetAttribute("Purpose", definition.Purpose)
end

local function buildFloor(house: House, floor: number, wheelsFolder: Folder)
	local model = Build.model(house.FloorsFolder, "Floor" .. floor)
	local function L(x: number, y: number, z: number): CFrame
		return house.CFrame * CFrame.new(x, y, z)
	end
	buildShell(model, house, floor, L)
	buildLiftPanel(model, house, floor, L)
	furnishFloor(model, house, floor, L)
	makeSlot(house, model, wheelsFolder, floor, house.CFrame)
	house.FloorModels[floor] = model
end

local function removeFloor(house: House, floor: number)
	local model = house.FloorModels[floor]
	if model then
		model:Destroy()
		house.FloorModels[floor] = nil
	end
	for wheel = 1, FloorConfig.WheelsPerFloor do
		local index = (floor - 1) * FloorConfig.WheelsPerFloor + wheel
		local slot = house.Slots[index]
		if slot then
			if slot.Label then
				slot.Label:Destroy()
			end
			slot.Frame:Destroy()
			house.Slots[index] = nil
		end
	end
	house.ElevatorPrompts[floor] = nil
	for id, definition in UpgradeConfig.Definitions do
		if (definition.RequiresFloor or 1) == floor then
			house.Stations[id] = nil
			house.Prompts[id] = nil
		end
	end
end

---------------------------------------------------------------------------
-- roof, lift tower, scaffolding for the next floor
---------------------------------------------------------------------------

local function buildRoof(house: House)
	local roof = house.RoofFolder
	roof:ClearAllChildren()
	local floors = house.FloorCount
	local top = floorBase(floors + 1)
	local fz = frontZ(floors)
	local depth = Z1 - fz
	local midZ = (fz + Z1) / 2
	local function L(x: number, y: number, z: number): CFrame
		return house.CFrame * CFrame.new(x, y, z)
	end

	Build.part(roof, "RoofSlab", Vector3.new(WIDTH + 1.6, 1, depth + 1.6), L(0, top + 0.5, midZ), Palette.StoneDark, CONCRETE)
	-- parapet with the owner's accent colour on top
	for _, z in { fz - 0.4, Z1 + 0.4 } do
		Build.part(roof, "Parapet", Vector3.new(WIDTH + 1.6, 1.6, 0.8), L(0, top + 1.8, z), FLOOR_STYLES[floors].Wall, PLASTIC)
		table.insert(house.RoofParts, accent(Build.deco(roof, "ParapetCap", Vector3.new(WIDTH + 2, 0.35, 1.2), L(0, top + 2.75, z), house.DefaultRoof, PLASTIC)))
	end
	for _, x in { X0 - 0.4, X1 + 0.4 } do
		Build.part(roof, "Parapet", Vector3.new(0.8, 1.6, depth + 1.6), L(x, top + 1.8, midZ), FLOOR_STYLES[floors].Wall, PLASTIC)
		table.insert(house.RoofParts, accent(Build.deco(roof, "ParapetCap", Vector3.new(1.2, 0.35, depth + 2), L(x, top + 2.75, midZ), house.DefaultRoof, PLASTIC)))
	end
	-- rooftop details: garden box, solar panels, vents, antenna
	Build.part(roof, "RoofGarden", Vector3.new(12, 1.2, 6), L(-12, top + 1.6, Z1 - 6), Palette.WoodDark, WOOD)
	Build.blob(roof, "RoofBushes", Vector3.new(11, 2.4, 5), L(-12, top + 2.6, Z1 - 6), Palette.Leaf, Enum.Material.Grass, { CanCollide = false })
	for panel = 0, 2 do
		Build.part(roof, "SolarPanel", Vector3.new(5, 0.25, 3.4), L(4 + panel * 5.6, top + 2.2, Z1 - 7) * CFrame.Angles(math.rad(-22), 0, 0), Color3.fromRGB(40, 60, 110), Enum.Material.Glass, { CanCollide = false })
	end
	Build.part(roof, "Vent", Vector3.new(4, 2.6, 3), L(16, top + 2.3, fz + 9), Color3.fromRGB(200, 204, 210), METAL)
	Build.pillar(roof, "Antenna", 0.3, 8, L(20, top + 5, Z1 - 3), Palette.Ink, METAL, { CanCollide = false })
	local beacon = Build.blob(roof, "AntennaLight", Vector3.one * 0.8, L(20, top + 9.2, Z1 - 3), Color3.fromRGB(255, 90, 90), NEON, { CanCollide = false })
	Build.animate(beacon, "Bob", { Amplitude = 0.05, Speed = 4 })

	-- big name sign on the front edge (find your apartment from anywhere)
	local frame = Build.part(roof, "RoofSignFrame", Vector3.new(18, 4.4, 0.8), L(0, top + 4.4, fz + 1.2), Palette.Ink, METAL, { CanCollide = false })
	table.insert(house.RoofParts, accent(Build.deco(roof, "RoofSignTrim", Vector3.new(18.6, 0.35, 1), L(0, top + 6.75, fz + 1.2), house.DefaultRoof, NEON)))
	Build.part(roof, "RoofSignLegs", Vector3.new(14, 2.2, 0.5), L(0, top + 1.6, fz + 1.4), Palette.Ink, METAL, { CanCollide = false })
	house.RoofAnchor.CFrame = L(0, top + 4.4, fz + 0.6)
	frame:SetAttribute("Sign", true)
end

local function buildLift(house: House)
	local folder = house.Model:FindFirstChild("Lift") :: Model
	folder:ClearAllChildren()
	local height = floorBase(house.FloorCount + 1) + 2.5
	local function L(x: number, y: number, z: number): CFrame
		return house.CFrame * CFrame.new(x, y, z)
	end
	local cx, cz = (LIFT_X0 + LIFT_X1) / 2, (LIFT_Z0 + LIFT_Z1) / 2
	local w, d = LIFT_X1 - LIFT_X0, LIFT_Z1 - LIFT_Z0
	Build.part(folder, "LiftBase", Vector3.new(w, FLOOR_TOP, d), L(cx, FLOOR_TOP / 2, cz), Palette.StoneDark, Enum.Material.Slate)
	for _, x in { LIFT_X0, LIFT_X1 - 0.6 } do
		for _, z in { LIFT_Z0, LIFT_Z1 } do
			Build.part(folder, "LiftPost", Vector3.new(0.8, height, 0.8), L(x, height / 2, z), Color3.fromRGB(230, 232, 236), METAL)
		end
	end
	Build.part(folder, "LiftGlass", Vector3.new(0.3, height, d), L(LIFT_X0, height / 2, cz), Palette.Glass, GLASS, { Transparency = 0.6, CastShadow = false })
	for _, z in { LIFT_Z0, LIFT_Z1 } do
		Build.part(folder, "LiftGlass", Vector3.new(w, height, 0.3), L(cx, height / 2, z), Palette.Glass, GLASS, { Transparency = 0.6, CastShadow = false })
	end
	Build.part(folder, "LiftCap", Vector3.new(w + 0.8, 1, d + 0.8), L(cx, height + 0.5, cz), Palette.StoneDark, CONCRETE)
	table.insert(house.RoofParts, accent(Build.deco(folder, "LiftCapTrim", Vector3.new(w + 1, 0.3, d + 1), L(cx, height + 1.1, cz), house.DefaultRoof, PLASTIC)))
	local car = Build.part(folder, "LiftCar", Vector3.new(w - 1.6, 8, d - 2), L(cx - 0.4, FLOOR_TOP + 4.2, cz), Color3.fromRGB(240, 236, 228), Enum.Material.Marble, { CanCollide = false, Transparency = 0.15 })
	Build.light(car, Color3.fromRGB(255, 230, 190), 0.8, 12)
	for _, y in { 0.5, height - 0.5 } do
		Build.deco(folder, "LiftStrip", Vector3.new(0.4, 0.4, d), L(LIFT_X0 - 0.2, y, cz), Color3.fromRGB(255, 214, 120), NEON)
	end
end

-- Next floor under construction: scaffolding, a crane jib and a sign with the rebirth it needs.
local function buildScaffold(house: House, show: boolean)
	local folder = house.Model:FindFirstChild("Scaffold") :: Model
	folder:ClearAllChildren()
	local nextFloor = FloorConfig.Floors[house.FloorCount + 1]
	if not show or not nextFloor then
		return
	end
	local base = floorBase(house.FloorCount + 1) + 1
	local height = STOREY - 1
	local function L(x: number, y: number, z: number): CFrame
		return house.CFrame * CFrame.new(x, y, z)
	end
	local fz = frontZ(house.FloorCount + 1)
	local yellow = Color3.fromRGB(255, 196, 60)
	local props = { CanCollide = false, CastShadow = false }
	for _, x in { X0 + 1, 0, X1 - 1 } do
		for _, z in { fz + 1, Z1 - 1 } do
			Build.part(folder, "Pole", Vector3.new(0.4, height, 0.4), L(x, base + height / 2, z), Color3.fromRGB(180, 184, 190), METAL, props)
		end
	end
	for _, y in { base + 0.2, base + height } do
		Build.part(folder, "Rail", Vector3.new(WIDTH - 2, 0.35, 0.35), L(0, y, fz + 1), yellow, METAL, props)
		Build.part(folder, "Rail", Vector3.new(WIDTH - 2, 0.35, 0.35), L(0, y, Z1 - 1), yellow, METAL, props)
	end
	Build.part(folder, "Planned", Vector3.new(WIDTH - 2, height, Z1 - fz - 2), L(0, base + height / 2, (fz + Z1) / 2), Color3.fromRGB(255, 220, 140), PLASTIC, { CanCollide = false, CastShadow = false, Transparency = 0.86 })
	local signPart = Build.deco(folder, "PlannedSign", Vector3.one * 0.3, L(0, base + height + 2.2, fz + 1), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1 })
	Build.billboard(signPart, string.format('<font color="#FFD866">FLOOR %d: %s</font>\nunlocks at Rebirth %d', nextFloor.Index, string.upper(nextFloor.Name), nextFloor.MinRebirth), Vector2.new(260, 54), Vector3.zero, { MaxDistance = 160, Name = "NextFloor" })
end

-- Premium exterior details that grow with rebirths (milestones in RebirthConfig).
function HouseBuilder.setPrestige(house: House, rebirths: number)
	local folder = house.Model:FindFirstChild("Prestige") :: Model
	folder:ClearAllChildren()
	house.Prestige = rebirths
	local function L(x: number, y: number, z: number): CFrame
		return house.CFrame * CFrame.new(x, y, z)
	end
	local top = floorBase(house.FloorCount + 1)
	if rebirths >= 10 then
		-- premium facade: gold bands at every floor line and gold pilaster caps
		for floor = 2, house.FloorCount + 1 do
			Build.deco(folder, "GoldBand", Vector3.new(WIDTH + 1.6, 0.3, 0.3), L(0, floorBase(floor) + 0.1, frontZ(math.min(floor, house.FloorCount)) - 0.75), Palette.Gold, METAL)
		end
		for _, x in { X0, X1 } do
			Build.deco(folder, "GoldCap", Vector3.new(1.8, 0.6, 1.8), L(x, top + 0.3, frontZ(house.FloorCount)), Palette.Gold, METAL)
		end
	end
	if rebirths >= 15 then
		local crownBase = L(0, top + 7.2, frontZ(house.FloorCount) + 1.2)
		Build.deco(folder, "RoofCrown", Vector3.new(6, 1.2, 1.2), crownBase, Palette.Gold, METAL)
		for point = -2, 2 do
			Build.deco(folder, "CrownPoint", Vector3.new(0.9, 1.6 + (2 - math.abs(point)) * 0.5, 0.9), crownBase * CFrame.new(point * 1.3, 1.2 + (2 - math.abs(point)) * 0.25, 0), Palette.Gold, METAL)
		end
	end
	if rebirths >= 20 then
		for _, x in { X0 - 0.75, X1 + 0.75 } do
			Build.deco(folder, "LightStrip", Vector3.new(0.3, top, 0.3), L(x, top / 2, Z0 - 0.75), Color3.fromRGB(255, 214, 120), NEON)
		end
	end
end

-- Builds / removes floors so the building has `count` floors. `showNext` shows the next floor's scaffolding.
function HouseBuilder.setFloors(house: House, count: number, showNext: boolean)
	count = math.clamp(count, 1, FloorConfig.Count)
	local wheelsFolder = house.Model:FindFirstChild("Wheels") :: Folder
	for floor = FloorConfig.Count, count + 1, -1 do
		removeFloor(house, floor)
	end
	for floor = 1, count do
		if not house.FloorModels[floor] then
			buildFloor(house, floor, wheelsFolder)
		end
	end
	house.FloorCount = count
	-- roof accents are rebuilt with the roof; keep only the ones that still exist
	local kept = {}
	for _, part in house.RoofParts do
		if part.Parent then
			table.insert(kept, part)
		end
	end
	house.RoofParts = kept
	buildRoof(house)
	buildLift(house)
	buildScaffold(house, showNext)
	HouseBuilder.setPrestige(house, house.Prestige)
	house.Model:SetAttribute("Floors", count)
end

---------------------------------------------------------------------------
-- the plot: lawn, hedges, driveway, security gate, mailbox, altar, gardens
---------------------------------------------------------------------------

local function buildGate(house: House, yard: Model, L: (number, number, number) -> CFrame)
	local postX = 7.6
	local pillarColor = Color3.fromRGB(244, 240, 232)
	local lamps: { BasePart } = {}
	for _, side in { -1, 1 } do
		Build.part(yard, "GatePost", Vector3.new(2.8, 10.4, 2.8), L(side * postX, 5.2, 0), pillarColor, CONCRETE)
		Build.deco(yard, "GatePostBase", Vector3.new(3.4, 0.8, 3.4), L(side * postX, 0.4, 0), Palette.StoneDark, Enum.Material.Slate)
		-- light strip on the street face: the security status lamp
		table.insert(lamps, Build.deco(yard, "GateLamp", Vector3.new(0.5, 7.4, 0.3), L(side * postX, 5, -1.45), Color3.fromRGB(110, 230, 140), NEON))
	end
	-- canopy carrying the name plate and rebirth stars
	local canopy = Build.part(yard, "GateCanopy", Vector3.new(postX * 2 + 4, 2.6, 4.4), L(0, 11.7, 0), Palette.Ink, METAL, { CanCollide = false })
	table.insert(house.RoofParts, accent(Build.deco(yard, "GateCanopyTrim", Vector3.new(postX * 2 + 4.4, 0.35, 4.8), L(0, 13.15, 0), house.DefaultRoof, PLASTIC)))
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 40
	signGui.LightInfluence = 0
	signGui.Parent = canopy
	local function signLine(name: string, x: number, y: number, w: number, h: number, font: Enum.Font, color: Color3, align: Enum.TextXAlignment): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(x, y)
		label.Size = UDim2.fromScale(w, h)
		label.TextScaled = true
		label.RichText = true
		label.Font = font
		label.TextColor3 = color
		label.TextXAlignment = align
		label.Text = ""
		label.Parent = signGui
		return label
	end
	house.Labels.Name = signLine("Name", 0.04, 0.08, 0.6, 0.5, Enum.Font.FredokaOne, Color3.fromRGB(255, 244, 222), Enum.TextXAlignment.Left)
	house.Labels.Stats = signLine("Stats", 0.04, 0.6, 0.6, 0.3, Enum.Font.GothamBold, Color3.fromRGB(255, 214, 140), Enum.TextXAlignment.Left)
	house.Labels.Best = signLine("Best", 0.62, 0.6, 0.35, 0.3, Enum.Font.GothamMedium, Color3.fromRGB(220, 214, 230), Enum.TextXAlignment.Right)
	for starIndex = 1, 10 do
		local star = Build.blob(yard, "RebirthStar", Vector3.new(0.7, 0.7, 0.3), L(5.3 + ((starIndex - 1) % 5) * 1, 12.55 - math.floor((starIndex - 1) / 5) * 0.95, -2.3), Color3.fromRGB(70, 60, 70), PLASTIC, { CanCollide = false })
		table.insert(house.Stars, star)
	end

	-- laser barrier between the posts
	local beams: { BasePart } = {}
	local span = postX * 2 - 2.8
	for beam = 1, SecurityConfig.MaxBeams do
		table.insert(beams, Build.deco(yard, "LaserBeam", Vector3.new(span, 0.22, 0.22), L(0, 0.9 + beam * 1.5, 0), Color3.fromRGB(255, 96, 96), NEON, { Shape = Enum.PartType.Cylinder, Transparency = 1 }))
	end
	local field = Build.deco(yard, "SecurityField", Vector3.new(span, 9.4, 0.12), L(0, 4.9, 0), Color3.fromRGB(255, 96, 96), NEON, { Transparency = 1 })
	local anchor = Build.deco(yard, "SecurityAnchor", Vector3.one * 0.3, L(0, 15.4, 0), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1, CanQuery = false })

	-- security panel just inside the gate (press E to switch the gate back on)
	Build.part(yard, "PylonBase", Vector3.new(2.4, 0.4, 1.8), L(11, 0.2, 4), Palette.StoneDark, Enum.Material.Slate)
	local pylon = Build.part(yard, "PylonColumn", Vector3.new(1.6, 4, 1.2), L(11, 2.4, 4), pillarColor, CONCRETE)
	Build.part(yard, "PanelScreen", Vector3.new(1.4, 1.4, 0.2), L(11, 3.6, 3.35) * CFrame.Angles(math.rad(-12), 0, 0), Palette.Ink, Enum.Material.Glass, { CanCollide = false })
	local pylonLamp = Build.deco(yard, "PylonLamp", Vector3.new(1.1, 0.3, 0.15), L(11, 3.2, 3.22) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(110, 230, 140), NEON)
	local securityPrompt = Instance.new("ProximityPrompt")
	securityPrompt.ObjectText = "Security Panel"
	securityPrompt.ActionText = "Reactivate Security"
	securityPrompt.KeyboardKeyCode = Enum.KeyCode.E
	securityPrompt.HoldDuration = 0
	securityPrompt.MaxActivationDistance = 9
	securityPrompt.RequiresLineOfSight = false
	securityPrompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	securityPrompt.Enabled = false
	securityPrompt:SetAttribute("SecurityHouse", house.Index)
	securityPrompt.Parent = pylon
	house.Security = { Beams = beams, Field = field, Lamps = lamps, PylonLamp = pylonLamp, Prompt = securityPrompt, Anchor = anchor }
end

local function buildYard(house: House, yard: Model, L: (number, number, number) -> CFrame, rng: Random)
	local halfWidth = WorldLayout.LotHalfWidth
	local depth = WorldLayout.LotDepth
	Build.part(yard, "Lawn", Vector3.new(halfWidth * 2, 0.1, depth), L(0, 0.02, depth / 2), Palette.GrassLight, Enum.Material.Grass, { CanCollide = false })
	Build.part(yard, "Driveway", Vector3.new(10, 0.16, Z0), L(0, 0.08, Z0 / 2), Palette.Pavement, Enum.Material.Cobblestone, { CanCollide = false })
	for _, side in { -1, 1 } do
		Build.deco(yard, "DrivewayEdge", Vector3.new(0.6, 0.2, Z0), L(side * 5.3, 0.1, Z0 / 2), Palette.PavementDark, Enum.Material.Cobblestone)
		-- low garden lights along the driveway
		for _, z in { 10, 20 } do
			local light = Build.deco(yard, "PathLight", Vector3.new(0.5, 1.2, 0.5), L(side * 6.4, 0.6, z), Color3.fromRGB(255, 226, 170), NEON)
			light.CastShadow = false
		end
	end
	Build.part(yard, "GateApron", Vector3.new(18, 0.16, 5), L(0, 0.08, 0), Palette.PavementDark, Enum.Material.Cobblestone, { CanCollide = false })

	-- hedges around the plot (they keep people out of the lot except through the gate)
	local function hedge(x0: number, z0: number, x1: number, z1: number)
		Decor.hedgeRun(yard, (house.CFrame * CFrame.new(x0, 0, z0)).Position, (house.CFrame * CFrame.new(x1, 0, z1)).Position, rng)
	end
	hedge(-halfWidth + 1, 0.6, -9.4, 0.6)
	hedge(9.4, 0.6, halfWidth - 1, 0.6)
	hedge(-halfWidth + 1, 0.6, -halfWidth + 1, depth - 1)
	hedge(halfWidth - 1, 0.6, halfWidth - 1, depth - 1)
	hedge(-halfWidth + 1, depth - 1, halfWidth - 1, depth - 1)

	-- entrance canopy over the doors and two wall lights
	table.insert(house.RoofParts, accent(Build.part(yard, "EntranceCanopy", Vector3.new(16, 0.6, 5.5), L(0, 10.6, Z0 - 2.4), house.DefaultRoof, PLASTIC, { CanCollide = false })))
	for _, side in { -1, 1 } do
		local wallLight = Build.deco(yard, "WallLight", Vector3.new(0.8, 1.6, 0.5), L(side * 6.6, 6.4, Z0 - 0.5), Color3.fromRGB(255, 226, 170), NEON)
		Build.light(wallLight, Color3.fromRGB(255, 220, 160), 0.8, 14)
	end
	Build.part(yard, "EntranceStep", Vector3.new(12, 0.5, 3), L(0, 0.25, Z0 - 1.4), Palette.Stone, Enum.Material.Slate)

	-- mailbox (daily gift)
	Build.part(yard, "MailPost", Vector3.new(0.5, 3.4, 0.5), L(-12, 1.7, 5.5), Palette.Ink, METAL)
	local mailbox = Build.part(yard, "Mailbox", Vector3.new(2.6, 1.8, 1.6), L(-12, 3.9, 5.5), Color3.fromRGB(100, 170, 255), PLASTIC)
	Build.deco(yard, "MailFlag", Vector3.new(0.2, 1.1, 0.5), L(-13.4, 4.4, 5.5), Color3.fromRGB(255, 90, 90), PLASTIC)
	house.Prompts.Mailbox = makePrompt(mailbox, "Mailbox", "Daily Gift", "Daily", nil, 10)

	-- rebirth shrine on the right lawn
	Build.pillar(yard, "AltarBase", 5.4, 0.7, L(20, 0.35, 16), Palette.Stone, Enum.Material.Slate)
	local altar = Build.pillar(yard, "AltarPillar", 2.8, 2.2, L(20, 1.8, 16), Palette.Cream, Enum.Material.Marble)
	Build.pillar(yard, "AltarCap", 3.4, 0.35, L(20, 3.05, 16), Palette.Gold, METAL, { CanCollide = false })
	local orb = Build.blob(yard, "AltarOrb", Vector3.one * 1.9, L(20, 4.7, 16), Color3.fromRGB(255, 130, 60), NEON, { CanCollide = false })
	Build.light(orb, Color3.fromRGB(255, 150, 80), 1, 16)
	Build.animate(orb, "Bob", { Amplitude = 0.35, Speed = 1.6 })
	house.Prompts.Rebirth = makePrompt(altar, "Rebirth Shrine", "Rebirth", "Rebirth", nil, 11)

	-- one flower bed and one tree in the front garden, a patio with a bench and a tree at the back
	Decor.flowerBed(yard, L(-22, 0, 17), Vector2.new(12, 5), { Palette.Pink, Palette.Cream }, rng)
	Decor.largeTree(yard, (house.CFrame * CFrame.new(-28, 0, 26)).Position, 0.72, rng, if house.Index % 2 == 0 then Palette.Cherry else nil)
	Decor.largeTree(yard, (house.CFrame * CFrame.new(29, 0, 6.5)).Position, 0.6, rng)
	Build.part(yard, "Patio", Vector3.new(22, 0.2, 12), L(4, 0.1, 85), Palette.Pavement, Enum.Material.Cobblestone, { CanCollide = false })
	Decor.bench(yard, L(4, 0, 88) * CFrame.Angles(0, math.pi, 0))
	Decor.largeTree(yard, (house.CFrame * CFrame.new(-24, 0, 86)).Position, 0.8, rng)
	Decor.flowerBed(yard, L(24, 0, 86), Vector2.new(6, 6), { Palette.Lavender, Palette.Cream }, rng)
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

	local accentColor = Palette.RoofColors[(index - 1) % #Palette.RoofColors + 1]
	local yard = Build.model(model, "Yard")
	local floorsFolder = Build.folder(model, "Floors")
	Build.folder(model, "Wheels")
	local roofFolder = Build.model(model, "Roof")
	Build.model(model, "Lift")
	Build.model(model, "Scaffold")
	Build.model(model, "Prestige")
	local roofAnchor = Build.deco(model, "RoofAnchor", Vector3.one * 0.3, L(0, 20, Z0), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1 })

	local house: House = {
		Index = index,
		Model = model,
		CFrame = cframe,
		SpawnCFrame = L(0, 3, 12),
		GatePosition = cframe.Position,
		PadCFrame = L(WorldLayout.PadLocal.X, WorldLayout.PadLocal.Y, WorldLayout.PadLocal.Z),
		RoofParts = {},
		DefaultRoof = accentColor,
		ShutterParts = {},
		Stars = {},
		Labels = {},
		Prompts = {},
		ElevatorPrompts = {},
		Slots = {},
		Stations = {},
		DisplayFolder = Build.folder(model, "Display"),
		DisplayModels = {},
		FloorsFolder = floorsFolder,
		FloorModels = {},
		FloorCount = 0,
		Prestige = 0,
		RoofFolder = roofFolder,
		RoofAnchor = roofAnchor,
		Security = nil :: any,
		Owner = nil,
	}

	buildYard(house, yard, L, rng)
	buildGate(house, yard, L)
	house.Labels.Roof = Build.billboard(roofAnchor, "", Vector2.new(280, 48), Vector3.zero, { MaxDistance = 260, Name = "RoofName" })
	HouseBuilder.setFloors(house, 1, false)
	return house
end

---------------------------------------------------------------------------
-- dynamic refresh helpers (called by HouseSystem / SecuritySystem)
---------------------------------------------------------------------------

-- Accent colour (cosmetic "roof" colour): parapet caps, canopies, slab bands.
function HouseBuilder.setRoofColor(house: House, color: Color3)
	for _, descendant in house.Model:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("Accent") and descendant.Name ~= "GoldFrame" then
			descendant.Color = color
		end
	end
	house.DefaultRoof = color
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
	station.Label.Text = string.format('<b>%s</b>\n<font color="#FFE08A">%s</font>', definition.Name, levelText)
end

function HouseBuilder.setStars(house: House, count: number)
	for index, star in house.Stars do
		local lit = index <= count
		star.Color = if lit then Palette.Gold else Color3.fromRGB(70, 60, 70)
		star.Material = if lit then NEON else PLASTIC
	end
end

-- state: "Active" (gate on) | "Recharging" (off, can't be switched on yet) | "Ready" (off, press E at the panel)
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
