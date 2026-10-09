--[[
	The apartment tower. Floors are built (and removed) on demand by `Tower.setFloors(house, count)`; the tower grows
	with the player's rebirths (FloorConfig). Each floor has its own look and purpose:

	  1 Hamster Hall    lobby, arrival pad, upgrade pedestals, 8 wheels      (cozy gabled roof while it is the only floor)
	  2 Wheel Gallery   lounge, storage, 8 wheels, balcony
	  3 Upgrade Lab     upgrade console, lab screens, 8 wheels
	  4 Premium Suite   golden decor, 8 wheels, setback facade, roof garden
	  5 Penthouse       marble + gold, 8 wheels, crown with light beam

	Local frame: origin = middle of the gate line, +Z into the lot (see WorldLayout). Every floor is FloorHeight tall.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Parent.Build)
local Palette = require(script.Parent.Parent.Palette)
local Props = require(script.Parent.Props)
local Wheels = require(script.Parent.Wheels)

local FloorConfig = require(ReplicatedStorage.Modules.FloorConfig)
local UpgradeConfig = require(ReplicatedStorage.Modules.UpgradeConfig)
local WorldLayout = require(ReplicatedStorage.Modules.WorldLayout)

local Tower = {}

local WOOD = Enum.Material.WoodPlanks
local PLASTIC = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal

local FRAME = Color3.fromRGB(58, 52, 66)
local CONCRETE = Color3.fromRGB(240, 235, 226)
local WALL_THICKNESS = 0.6

local Z0, Z1 = WorldLayout.TowerFront, WorldLayout.TowerBack
local CZ = (Z0 + Z1) / 2
local DEPTH = Z1 - Z0
local FH = WorldLayout.FloorHeight
local WALL_H = FH - 0.8

-- wheel stations of one floor: two rows of four, centre-out so the first slots sit at the front
local STATION_X = { -4.5, 4.5, -13.5, 13.5 }
local STATION_Z = { 46, 58 }

local TRIM_COLORS: { [string]: Color3 } = {
	Wood = Palette.WoodDark,
	Silver = Color3.fromRGB(200, 206, 218),
	Gold = Color3.fromRGB(255, 205, 86),
	Diamond = Color3.fromRGB(170, 236, 255),
}

local FLOOR_STYLE = {
	{ Material = WOOD, Color = Palette.WoodLight },
	{ Material = WOOD, Color = Palette.Wood },
	{ Material = PLASTIC, Color = Color3.fromRGB(214, 220, 228) },
	{ Material = Enum.Material.Marble, Color = Palette.Pavement },
	{ Material = Enum.Material.Marble, Color = Color3.fromRGB(246, 240, 228) },
}

local function L(house: any, x: number, y: number, z: number): CFrame
	return house.CFrame * CFrame.new(x, y, z)
end

local function glassPart(parent: Instance, size: Vector3, cframe: CFrame)
	return Build.part(parent, "Glass", size, cframe, Palette.Glass, Enum.Material.Glass, { Transparency = 0.55, Reflectance = 0.05 })
end

---------------------------------------------------------------------------
-- walls
---------------------------------------------------------------------------

-- A wall made of a lower band, an upper band, piers between the windows and one glass pane per window.
-- `along` is the length axis in local space: "Z" for side walls, "X" for the back wall. `windows` = list of {a, b}.
local function windowedWall(house: any, parent: Instance, y0: number, fixed: number, along: string, from: number, to: number, windows: { { number } })
	local function place(a: number, b: number, y: number, h: number, name: string, color: Color3, glass: boolean?)
		local length = b - a
		if length < 0.05 then
			return
		end
		local mid = (a + b) / 2
		local cframe = if along == "Z" then L(house, fixed, y, mid) else L(house, mid, y, fixed)
		local size = if along == "Z" then Vector3.new(if glass then 0.25 else WALL_THICKNESS, h, length) else Vector3.new(length, h, if glass then 0.25 else WALL_THICKNESS)
		if glass then
			glassPart(parent, size, cframe)
		else
			Build.part(parent, name, size, cframe, color, PLASTIC)
		end
	end
	place(from, to, y0 + 1.1, 2.2, "WallLower", CONCRETE)
	place(from, to, y0 + WALL_H - 0.8, 1.6, "WallUpper", CONCRETE)
	local cursor = from
	local windowY = y0 + 2.2 + (WALL_H - 3.8) / 2
	local windowH = WALL_H - 3.8
	for _, window in windows do
		place(cursor, window[1], windowY, windowH, "WallPier", CONCRETE)
		place(window[1], window[2], windowY, windowH, "Glass", Palette.Glass, true)
		cursor = window[2]
	end
	place(cursor, to, windowY, windowH, "WallPier", CONCRETE)
end

local function buildShell(house: any, floorModel: Model, f: number)
	local hw = WorldLayout.FloorHalfWidth[f]
	local y0 = WorldLayout.floorY(f)
	local shell = Build.model(floorModel, "Shell")
	local style = FLOOR_STYLE[f]

	-- floor slab
	if f == 1 then
		Build.part(shell, "Foundation", Vector3.new(hw * 2 + 1.6, 0.5, DEPTH + 1.6), L(house, 0, 0.25, CZ), Palette.StoneDark, Enum.Material.Slate)
		Build.part(shell, "Floor", Vector3.new(hw * 2, 0.2, DEPTH), L(house, 0, y0 - 0.1, CZ), style.Color, style.Material)
	else
		Build.part(shell, "Slab", Vector3.new(hw * 2 + 1.2, 0.8, DEPTH + 1.2), L(house, 0, y0 - 0.4, CZ), CONCRETE, PLASTIC)
		Build.part(shell, "FloorSurface", Vector3.new(hw * 2, 0.1, DEPTH), L(house, 0, y0 - 0.05, CZ), style.Color, style.Material, { CanCollide = false })
		local fascia = Build.deco(shell, "Fascia", Vector3.new(hw * 2 + 1.4, 0.8, 0.5), L(house, 0, y0 - 0.4, Z0 - 0.5), house.Accent, PLASTIC)
		table.insert(house.AccentParts, fascia)
	end

	-- front facade
	if f == 1 then
		local span = hw - WorldLayout.DoorHalfWidth
		for _, side in { -1, 1 } do
			local cx = side * (WorldLayout.DoorHalfWidth + span / 2)
			Build.part(shell, "FrontLower", Vector3.new(span, 2.2, WALL_THICKNESS), L(house, cx, y0 + 1.1, Z0), CONCRETE, PLASTIC)
			glassPart(shell, Vector3.new(span - 0.4, WALL_H - 3.8, 0.25), L(house, cx, y0 + 2.2 + (WALL_H - 3.8) / 2, Z0))
			Build.part(shell, "FrontUpper", Vector3.new(span, 1.6, WALL_THICKNESS), L(house, cx, y0 + WALL_H - 0.8, Z0), CONCRETE, PLASTIC)
			Build.part(shell, "DoorPost", Vector3.new(0.8, WALL_H - 1.6, 0.9), L(house, side * (WorldLayout.DoorHalfWidth + 0.2), y0 + (WALL_H - 1.6) / 2, Z0), FRAME, PLASTIC)
		end
		Build.part(shell, "DoorHeader", Vector3.new(WorldLayout.DoorHalfWidth * 2, WALL_H - 9.2, WALL_THICKNESS), L(house, 0, y0 + 9.2 + (WALL_H - 9.2) / 2, Z0), CONCRETE, PLASTIC)
		Build.deco(shell, "DoorLintel", Vector3.new(WorldLayout.DoorHalfWidth * 2 + 1.6, 0.6, 1), L(house, 0, y0 + 9.2, Z0 - 0.1), FRAME, PLASTIC)
	else
		Build.part(shell, "FrontLower", Vector3.new(hw * 2, 2.2, WALL_THICKNESS), L(house, 0, y0 + 1.1, Z0), CONCRETE, PLASTIC)
		glassPart(shell, Vector3.new(hw * 2 - 0.4, WALL_H - 3.8, 0.25), L(house, 0, y0 + 2.2 + (WALL_H - 3.8) / 2, Z0))
		Build.part(shell, "FrontUpper", Vector3.new(hw * 2, 1.6, WALL_THICKNESS), L(house, 0, y0 + WALL_H - 0.8, Z0), CONCRETE, PLASTIC)
	end
	for k = 1, 5 do
		local x = -hw + k * (hw * 2 / 6)
		if f > 1 or math.abs(x) > WorldLayout.DoorHalfWidth + 1 then
			Build.part(shell, "Mullion", Vector3.new(0.4, WALL_H - 3.8, 0.5), L(house, x, y0 + 2.2 + (WALL_H - 3.8) / 2, Z0 - 0.1), FRAME, PLASTIC, { CanCollide = false })
		end
	end

	-- side + back walls (windows 8 wide)
	local sideWindows = { { 31, 39 }, { 44, 52 }, { 57, 65 } }
	for _, side in { -1, 1 } do
		windowedWall(house, shell, y0, side * hw, "Z", Z0, Z1, sideWindows)
	end
	windowedWall(house, shell, y0, Z1, "X", -hw, hw, { { -16, -8 }, { -4, 4 }, { 8, 16 } })

	-- rounded corner columns
	for _, x in { -hw, hw } do
		for _, z in { Z0, Z1 } do
			Build.pillar(shell, "Corner", 1.7, WALL_H, L(house, x, y0 + WALL_H / 2, z), CONCRETE, PLASTIC)
		end
	end
end

---------------------------------------------------------------------------
-- entrance (floor 1)
---------------------------------------------------------------------------

local function buildEntrance(house: any, floorModel: Model)
	local y0 = WorldLayout.floorY(1)
	local entrance = Build.model(floorModel, "Entrance")
	-- canopy with the rebirth stars on its fascia
	Build.part(entrance, "Canopy", Vector3.new(20, 0.8, 8.5), L(house, 0, y0 + 10.2, Z0 - 4.25), CONCRETE, PLASTIC)
	local fascia = Build.part(entrance, "CanopyFascia", Vector3.new(20.2, 1.1, 0.5), L(house, 0, y0 + 10.2, Z0 - 8.5), house.Accent, PLASTIC)
	table.insert(house.AccentParts, fascia)
	Build.part(entrance, "CanopyTrim", Vector3.new(20.4, 0.25, 0.7), L(house, 0, y0 + 10.7, Z0 - 8.5), TRIM_COLORS[house.Trim] or TRIM_COLORS.Wood, METAL)
	table.insert(house.TrimParts, entrance:FindFirstChild("CanopyTrim") :: BasePart)
	for _, side in { -1, 1 } do
		Build.pillar(entrance, "CanopyColumn", 1.3, 10, L(house, side * 8.6, y0 + 5, Z0 - 7.4), CONCRETE, PLASTIC)
	end
	for starIndex = 1, 10 do
		local star = Build.blob(entrance, "RebirthStar", Vector3.new(0.9, 0.9, 0.3), L(house, -4.95 + (starIndex - 1) * 1.1, y0 + 10.2, Z0 - 8.85), Color3.fromRGB(70, 60, 70), PLASTIC, { CanCollide = false })
		table.insert(house.Stars, star)
	end
	-- steps and a welcome mat
	Build.part(entrance, "Step", Vector3.new(16, 0.5, 4), L(house, 0, 0.25, Z0 - 2), Palette.Stone, Enum.Material.Cobblestone)
	Build.deco(entrance, "WelcomeMat", Vector3.new(7, 0.08, 2.2), L(house, 0, 0.54, Z0 - 1.6), Palette.Pink, PLASTIC)
	-- two lanterns on the facade
	for _, side in { -1, 1 } do
		Build.blob(entrance, "Lantern", Vector3.new(1, 1.4, 1), L(house, side * 6.8, y0 + 7.4, Z0 - 0.9), Color3.fromRGB(255, 226, 150), NEON, { CanCollide = false })
	end
end

---------------------------------------------------------------------------
-- stations, lamps, elevator
---------------------------------------------------------------------------

local function buildStations(house: any, floorModel: Model, f: number)
	local interior = floorModel:FindFirstChild("Interior") :: Model
	local y0 = WorldLayout.floorY(f)
	local index = (f - 1) * FloorConfig.StationsPerFloor
	for _, z in STATION_Z do
		for _, x in STATION_X do
			index += 1
			local center = L(house, x, y0 + Wheels.CenterAboveFloor, z)
			local ring = Build.pillar(interior, "SlotRing", 4.4, 0.06, L(house, x, y0 + 0.04, z), Color3.fromRGB(90, 80, 90), NEON, { CanCollide = false, Transparency = 0.7 })
			local labelAnchor = Build.deco(interior, "WheelLabelAnchor", Vector3.one * 0.2, L(house, x, y0 + Wheels.CenterAboveFloor + Wheels.Radius + 1.2, z), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1 })
			house.Slots[index] = {
				Index = index,
				Floor = f,
				Center = center,
				RunCFrame = L(house, x, y0 + Wheels.CenterAboveFloor - Wheels.Radius + 0.1, z) * CFrame.Angles(0, -math.pi / 2, 0),
				Ring = ring,
				LabelAnchor = labelAnchor,
				Label = nil,
				Wheel = nil,
				Frame = Build.folder(house.WheelsFolder, "Wheel" .. index),
			}
		end
	end
end

local function buildLamps(house: any, floorModel: Model, f: number)
	local interior = floorModel:FindFirstChild("Interior") :: Model
	local y0 = WorldLayout.floorY(f)
	for _, z in { 38, 56 } do
		local lamp = Build.blob(interior, "CeilingLamp", Vector3.new(2.2, 1.2, 2.2), L(house, 0, y0 + WALL_H - 0.7, z), Color3.fromRGB(255, 236, 190), NEON, { CanCollide = false })
		Build.light(lamp, Color3.fromRGB(255, 228, 175), 1.1, 36)
	end
end

local function buildElevator(house: any, floorModel: Model, f: number)
	local interior = floorModel:FindFirstChild("Interior") :: Model
	local y0 = WorldLayout.floorY(f)
	local doorZ = 63.2
	-- shaft glass + doors
	for _, side in { -1, 1 } do
		glassPart(interior, Vector3.new(0.25, WALL_H - 1, 6.2), L(house, side * 3.4, y0 + WALL_H / 2, 66.3))
	end
	Build.part(interior, "ElevatorFrame", Vector3.new(7.2, WALL_H - 0.6, 0.5), L(house, 0, y0 + (WALL_H - 0.6) / 2, doorZ + 0.1), FRAME, PLASTIC)
	for _, side in { -1, 1 } do
		Build.part(interior, "ElevatorDoor", Vector3.new(3, WALL_H - 3.4, 0.35), L(house, side * 1.6, y0 + (WALL_H - 3.4) / 2 + 0.2, doorZ - 0.2), Color3.fromRGB(190, 196, 208), METAL, { CanCollide = false })
	end
	Build.deco(interior, "ElevatorLamp", Vector3.new(1.4, 0.5, 0.2), L(house, 0, y0 + WALL_H - 1.3, doorZ - 0.45), Color3.fromRGB(110, 230, 140), NEON)
	local plate = Build.part(interior, "FloorNumber", Vector3.new(1.8, 1.8, 0.2), L(house, 0, y0 + WALL_H - 3, doorZ - 0.4), Palette.Ink, PLASTIC, { CanCollide = false })
	Build.surfaceText(plate, Enum.NormalId.Front, tostring(f), { TextColor = Palette.Gold, PixelsPerStud = 60 })

	-- call buttons (down on the left, up on the right): the prompt closest to you is the one shown
	local buttons = {}
	for _, entry in { { "Down", -5.6 }, { "Up", 5.6 } } do
		local post = Build.part(interior, "Call" .. entry[1], Vector3.new(0.8, 3.4, 0.8), L(house, entry[2], y0 + 1.7, doorZ - 0.6), FRAME, PLASTIC)
		Build.blob(interior, "CallLamp", Vector3.new(0.7, 0.7, 0.4), L(house, entry[2], y0 + 3.2, doorZ - 1.05), if entry[1] == "Up" then Color3.fromRGB(110, 230, 140) else Color3.fromRGB(255, 190, 90), NEON, { CanCollide = false })
		local prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText = "Elevator"
		prompt.ActionText = if entry[1] == "Up" then "Go up" else "Go down"
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 5
		prompt.RequiresLineOfSight = false
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		prompt.Enabled = false
		prompt:SetAttribute("Elevator", entry[1])
		prompt:SetAttribute("HouseIndex", house.Index)
		prompt:SetAttribute("Floor", f)
		prompt.Parent = post
		buttons[entry[1]] = prompt
	end
	house.Elevator[f] = buttons
	house.Landing[f] = L(house, 0, y0 + 3.2, 58.8) -- faces -Z, i.e. out towards the street
end

---------------------------------------------------------------------------
-- furnishing (every floor gets its own purpose, none of them empty)
---------------------------------------------------------------------------

local function makePrompt(parent: BasePart, objectText: string, actionText: string, opens: string, focus: string?): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = objectText
	prompt.ActionText = actionText
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
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

local function furnishHall(house: any, interior: Model, rng: Random)
	local y0 = WorldLayout.floorY(1)
	-- arrival pad
	local pad = WorldLayout.PadLocal
	Build.pillar(interior, "PadOuter", 8.4, 0.08, L(house, pad.X, y0 + 0.05, pad.Z), Palette.Pink, PLASTIC, { CanCollide = false })
	Build.pillar(interior, "PadInner", 6.4, 0.1, L(house, pad.X, y0 + 0.06, pad.Z), Palette.Cream, PLASTIC, { CanCollide = false })
	local glow = Build.pillar(interior, "PadGlow", 4, 0.12, L(house, pad.X, y0 + 0.07, pad.Z), Color3.fromRGB(255, 214, 120), NEON, { CanCollide = false, Transparency = 0.35 })
	glow:SetAttribute("Ripple", true)

	-- hamster chest (opens the inventory)
	local chest = Build.part(interior, "ChestBody", Vector3.new(3.6, 1.7, 2.3), L(house, -12.5, y0 + 0.85, 30.4), Palette.WoodLight, WOOD)
	Build.part(interior, "ChestLid", Vector3.new(3.8, 0.7, 2.5), L(house, -12.5, y0 + 2.05, 30.4), Palette.Wood, WOOD, { CanCollide = false })
	Build.deco(interior, "ChestLock", Vector3.new(0.5, 0.7, 0.2), L(house, -12.5, y0 + 1.7, 29.2), Palette.Gold, METAL)
	house.Prompts.Chest = makePrompt(chest, "Hamster Chest", "Open", "Inventory", nil)

	-- lobby seating and plants
	Props.sofa(interior, L(house, 13, y0, 30.8) * CFrame.Angles(0, math.pi, 0), Palette.RoofColors[(house.Index % #Palette.RoofColors) + 1], 7)
	Props.rug(interior, L(house, 13, y0, 33), 9, Palette.Pink, Palette.Cream)
	Props.plant(interior, L(house, -19.5, y0, 29.5), 1.1)
	Props.plant(interior, L(house, 19.5, y0, 29.5), 1.1)

	-- tower progress board (what floors the tower has and what comes next)
	local board = Build.part(interior, "ProgressBoard", Vector3.new(0.5, 5.6, 11), L(house, 21.4, y0 + 5.2, 41), FRAME, PLASTIC, { CanCollide = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Left
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.RichText = true
	label.TextColor3 = Palette.Cream
	label.Text = ""
	label.Parent = gui
	house.Labels.Progress = label

	-- 8 upgrade pedestals along the two long walls
	local zs = { 34, 40.5, 47, 53.5 }
	local upgradeIndex = 0
	for _, side in { -1, 1 } do
		for _, z in zs do
			upgradeIndex += 1
			local upgradeId = UpgradeConfig.Order[upgradeIndex]
			local x = side * 19.2
			local facing = CFrame.Angles(0, if side < 0 then math.rad(-90) else math.rad(90), 0)
			local base = Build.pillar(interior, "StationBase", 2.6, 1.8, L(house, x, y0 + 0.9, z), Palette.Cream, PLASTIC)
			Build.pillar(interior, "StationPlate", 3, 0.25, L(house, x, y0 + 1.9, z), Palette.WoodLight, WOOD, { CanCollide = false })
			local definition = UpgradeConfig.Definitions[upgradeId]
			local anchor = Build.deco(interior, "StationAnchor", Vector3.one * 0.2, L(house, x, y0 + 5.4, z), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1 })
			local stationLabel = Build.billboard(anchor, definition.Name, Vector2.new(190, 64), Vector3.zero, { MaxDistance = 34, Name = "StationLabel" })
			local propFolder = Build.folder(interior, "Prop_" .. upgradeId)
			house.Prompts[upgradeId] = makePrompt(base, definition.Name, "Upgrade", "Upgrades", upgradeId)
			house.Stations[upgradeId] = { Id = upgradeId, Label = stationLabel, PropFolder = propFolder, Top = L(house, x, y0 + 2.05, z) * facing }
			Props.Upgrade[upgradeId](propFolder, house.Stations[upgradeId].Top, 0.05, 0.6)
		end
	end
end

local function furnishGallery(house: any, interior: Model, rng: Random)
	local y0 = WorldLayout.floorY(2)
	Props.rug(interior, L(house, -11, y0, 33), 11, Palette.Mint, Palette.Cream)
	Props.sofa(interior, L(house, -11, y0, 30.6) * CFrame.Angles(0, math.pi, 0), Palette.RoofColors[3], 7.5)
	Build.part(interior, "CoffeeTable", Vector3.new(3.6, 1.2, 2.2), L(house, -11, y0 + 0.6, 34.6), Palette.WoodDark, WOOD)
	Props.shelf(interior, L(house, -21, y0, 40) * CFrame.Angles(0, math.rad(90), 0), 9, rng)
	Props.shelf(interior, L(house, 21, y0, 40) * CFrame.Angles(0, math.rad(-90), 0), 9, rng)
	Props.plant(interior, L(house, 19.5, y0, 29.5), 1.2)
	-- storage lounge: crates + a second chest
	Props.crates(interior, L(house, 14, y0, 30.5))
	local chest = Build.part(interior, "StorageChest", Vector3.new(3.6, 1.7, 2.3), L(house, 9.6, y0 + 0.85, 29.8), Palette.WoodLight, WOOD)
	Build.part(interior, "StorageLid", Vector3.new(3.8, 0.7, 2.5), L(house, 9.6, y0 + 2.05, 29.8), Palette.Wood, WOOD, { CanCollide = false })
	house.Prompts.StorageChest = makePrompt(chest, "Storage", "Open hamsters", "Inventory", nil)
end

local function furnishLab(house: any, interior: Model, rng: Random)
	local y0 = WorldLayout.floorY(3)
	-- lab desks with glowing screens along the left wall
	for _, z in { 32, 38 } do
		Props.desk(interior, L(house, -19.2, y0, z) * CFrame.Angles(0, math.rad(90), 0), 4.6, Color3.fromRGB(220, 224, 232))
		Props.screen(interior, L(house, -20.6, y0 + 4.4, z) * CFrame.Angles(0, math.rad(90), 0), Vector2.new(3.4, 2.2), Color3.fromRGB(120, 230, 255))
	end
	-- upgrade console: a big glowing desk that opens the Upgrades menu
	local console = Build.part(interior, "UpgradeConsole", Vector3.new(7, 2.8, 2.6), L(house, 13, y0 + 1.4, 31.5), Color3.fromRGB(70, 76, 96), PLASTIC)
	Props.screen(interior, L(house, 13, y0 + 5.2, 32.8), Vector2.new(6.4, 3), Color3.fromRGB(255, 214, 110))
	Build.deco(interior, "ConsoleGlow", Vector3.new(6.6, 0.2, 2.2), L(house, 13, y0 + 2.9, 31.5), Color3.fromRGB(255, 214, 110), NEON)
	house.Prompts.Console = makePrompt(console, "Upgrade Console", "Open upgrades", "Upgrades", nil)
	-- glowing test tubes
	for index = 1, 3 do
		Build.pillar(interior, "Tube", 1.2, 5, L(house, 19 - (index - 1) * 2, y0 + 2.6, 62), Color3.fromRGB(150, 240, 200), Enum.Material.Glass, { Transparency = 0.35, CanCollide = false })
		Build.pillar(interior, "TubeGlow", 0.8, 3, L(house, 19 - (index - 1) * 2, y0 + 2, 62), Color3.fromRGB(120, 255, 190), NEON, { CanCollide = false })
	end
	Props.plant(interior, L(house, 19.5, y0, 35.5), 1)
	Props.rug(interior, L(house, 0, y0, 33), 8, FRAME, Color3.fromRGB(120, 230, 255))
end

local function buildHamsterStatue(parent: Instance, cframe: CFrame, scale: number)
	Build.blob(parent, "StatueBody", Vector3.new(2.6, 2.4, 2.8) * scale, cframe * CFrame.new(0, 1.4 * scale, 0), Palette.Gold, METAL)
	Build.blob(parent, "StatueHead", Vector3.new(2.2, 2, 2) * scale, cframe * CFrame.new(0, 3.2 * scale, -0.9 * scale), Palette.Gold, METAL)
	for _, side in { -1, 1 } do
		Build.blob(parent, "StatueEar", Vector3.new(0.9, 1.1, 0.4) * scale, cframe * CFrame.new(side * 0.9 * scale, 4.2 * scale, -0.9 * scale), Palette.Gold, METAL)
	end
	Build.part(parent, "StatuePlinth", Vector3.new(3.6, 0.6, 3.6) * scale, cframe * CFrame.new(0, 0.3 * scale, 0), Palette.Ink, Enum.Material.Marble)
end

local function furnishSuite(house: any, interior: Model, rng: Random)
	local y0 = WorldLayout.floorY(4)
	Props.rug(interior, L(house, 0, y0, 33), 12, Color3.fromRGB(120, 60, 90), Palette.Gold)
	Props.sofa(interior, L(house, -9, y0, 30.6) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(150, 90, 130), 8)
	Props.sofa(interior, L(house, 9, y0, 30.6) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(150, 90, 130), 8)
	buildHamsterStatue(interior, L(house, 0, y0, 29.5), 1.1)
	-- bar counter along the right wall
	Props.desk(interior, L(house, 18, y0, 38) * CFrame.Angles(0, math.rad(-90), 0), 9, Palette.Ink)
	for _, z in { 35.5, 38, 40.5 } do
		Build.pillar(interior, "BarStool", 1.4, 2.2, L(house, 15.6, y0 + 1.1, z), Palette.Gold, METAL)
	end
	Props.plant(interior, L(house, -17.5, y0, 29.5), 1.4)
	Props.shelf(interior, L(house, -19.4, y0, 40) * CFrame.Angles(0, math.rad(90), 0), 9, rng)
	for _, z in { 36, 56 } do
		Build.deco(interior, "CeilingStrip", Vector3.new(30, 0.2, 0.5), L(house, 0, y0 + WALL_H - 0.3, z + 3), Palette.Gold, NEON)
	end
end

local function furnishPenthouse(house: any, interior: Model, rng: Random)
	local y0 = WorldLayout.floorY(5)
	Props.rug(interior, L(house, 0, y0, 33), 13, Color3.fromRGB(40, 36, 52), Palette.Gold)
	buildHamsterStatue(interior, L(house, 0, y0, 33), 1.7)
	Props.sofa(interior, L(house, -11, y0, 31) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(240, 235, 226), 8)
	Props.sofa(interior, L(house, 11, y0, 31) * CFrame.Angles(0, math.rad(180), 0), Color3.fromRGB(240, 235, 226), 8)
	-- chandelier: three glowing rings
	for index = 1, 3 do
		Build.pillar(interior, "Chandelier", 3 + index * 2.2, 0.2, L(house, 0, y0 + WALL_H - 1.2 - index * 0.5, 40), Palette.Gold, NEON, { CanCollide = false, Transparency = 0.15 })
	end
	Props.plant(interior, L(house, -16.5, y0, 30), 1.5)
	Props.plant(interior, L(house, 16.5, y0, 30), 1.5)
	Props.shelf(interior, L(house, -17.4, y0, 40) * CFrame.Angles(0, math.rad(90), 0), 9, rng)
	Props.shelf(interior, L(house, 17.4, y0, 40) * CFrame.Angles(0, math.rad(-90), 0), 9, rng)
end

local FURNISH = { furnishHall, furnishGallery, furnishLab, furnishSuite, furnishPenthouse }

---------------------------------------------------------------------------
-- one floor
---------------------------------------------------------------------------

local function buildFloor(house: any, f: number, rng: Random)
	local info = FloorConfig.Floors[f]
	local floorModel = Build.model(house.Tower, "Floor" .. f .. "_" .. (string.gsub(info.Name, " ", "")))
	floorModel:SetAttribute("Floor", f)
	buildShell(house, floorModel, f)
	local interior = Build.model(floorModel, "Interior")
	buildStations(house, floorModel, f)
	buildLamps(house, floorModel, f)
	buildElevator(house, floorModel, f)
	FURNISH[f](house, interior, rng)
	if f == 1 then
		buildEntrance(house, floorModel)
	else
		-- balcony on the front with glass railing and planters
		local y0 = WorldLayout.floorY(f)
		local hw = WorldLayout.FloorHalfWidth[f]
		local balcony = Build.model(floorModel, "Balcony")
		Build.part(balcony, "BalconySlab", Vector3.new(hw * 2 - 6, 0.6, 5), L(house, 0, y0 - 0.3, Z0 - 2.5), CONCRETE, PLASTIC)
		glassPart(balcony, Vector3.new(hw * 2 - 6, 2.4, 0.2), L(house, 0, y0 + 1.2, Z0 - 5))
		local rail = Build.deco(balcony, "Rail", Vector3.new(hw * 2 - 5.8, 0.3, 0.5), L(house, 0, y0 + 2.5, Z0 - 5), house.Accent, PLASTIC)
		table.insert(house.AccentParts, rail)
		for _, side in { -1, 1 } do
			Build.part(balcony, "Planter", Vector3.new(5, 1.2, 1.6), L(house, side * (hw - 8), y0 + 0.6, Z0 - 4), Palette.WoodDark, WOOD)
			Build.blob(balcony, "PlanterBush", Vector3.new(4.6, 2, 1.8), L(house, side * (hw - 8), y0 + 1.9, Z0 - 4), Palette.Leaf, Enum.Material.Grass, { CanCollide = false })
		end
	end
	return floorModel
end

---------------------------------------------------------------------------
-- roof
---------------------------------------------------------------------------

-- A hamster wheel emblem (ring with spokes) standing on `cframe`; faces local -Z.
local function emblem(parent: Instance, cframe: CFrame, diameter: number, color: Color3)
	Build.deco(parent, "EmblemRing", Vector3.new(0.5, diameter, diameter), cframe * CFrame.Angles(0, math.rad(90), 0), color, NEON, { Shape = Enum.PartType.Cylinder, Transparency = 0.1 })
	Build.deco(parent, "EmblemGlass", Vector3.new(0.2, diameter - 0.8, diameter - 0.8), cframe * CFrame.Angles(0, math.rad(90), 0), Palette.Glass, Enum.Material.Glass, { Shape = Enum.PartType.Cylinder, Transparency = 0.6 })
	for spoke = 0, 3 do
		Build.deco(parent, "EmblemSpoke", Vector3.new(0.3, 0.3, diameter - 0.4), cframe * CFrame.Angles(0, 0, spoke * math.pi / 4), color, NEON)
	end
end

local function buildGableRoof(house: any, roof: Model)
	local hw = WorldLayout.FloorHalfWidth[1]
	local y0 = WorldLayout.floorY(1)
	local top = y0 + WALL_H
	local pitch = math.rad(24)
	local halfSpan = hw + 1.6
	local slabLength = halfSpan / math.cos(pitch) + 1
	local rise = halfSpan * math.tan(pitch)
	for _, side in { -1, 1 } do
		local slab = Build.part(roof, "Roof", Vector3.new(slabLength, 0.8, DEPTH + 3), L(house, side * halfSpan / 2, top + rise / 2 + 0.45, CZ) * CFrame.Angles(0, 0, -side * pitch), house.Accent, Enum.Material.Slate)
		table.insert(house.AccentParts, slab)
	end
	table.insert(house.AccentParts, Build.part(roof, "Ridge", Vector3.new(1.4, 0.8, DEPTH + 3), L(house, 0, top + rise + 0.5, CZ), house.Accent, Enum.Material.Slate))
	local slices = 7
	for _, z in { Z0 + 0.2, Z1 - 0.2 } do
		for slice = 1, slices do
			local sliceHeight = rise / slices
			local width = hw * 2 * (1 - (slice - 0.5) / slices)
			Build.part(roof, "Gable", Vector3.new(width, sliceHeight + 0.02, 0.8), L(house, 0, top + (slice - 0.5) * sliceHeight, z), CONCRETE, PLASTIC)
		end
	end
	-- chimney with smoke and a little wheel weathervane on the ridge
	Build.part(roof, "Chimney", Vector3.new(2.6, 10, 2.6), L(house, 13, top + 5.5, 60), Palette.Stone, Enum.Material.Brick)
	local chimneyTop = Build.part(roof, "ChimneyTop", Vector3.new(3.2, 0.5, 3.2), L(house, 13, top + 10.7, 60), Palette.StoneDark, Enum.Material.Slate)
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
	emblem(roof, L(house, 0, top + rise + 3.4, Z0 + 0.5), 4, TRIM_COLORS[house.Trim] or TRIM_COLORS.Wood)
	house.RoofAnchorY = top + rise + 8
end

local function buildFlatRoof(house: any, roof: Model, count: number, rng: Random)
	local hw = WorldLayout.FloorHalfWidth[count]
	local y = WorldLayout.floorY(count) + WALL_H -- underside level of the roof slab
	Build.part(roof, "RoofSlab", Vector3.new(hw * 2 + 1.6, 0.8, DEPTH + 1.6), L(house, 0, y + 0.4, CZ), CONCRETE, PLASTIC)
	local fascia = Build.deco(roof, "RoofFascia", Vector3.new(hw * 2 + 1.8, 0.9, 0.5), L(house, 0, y + 0.4, Z0 - 0.5), house.Accent, PLASTIC)
	table.insert(house.AccentParts, fascia)
	-- parapet
	local parapetY = y + 1.5
	Build.part(roof, "ParapetFront", Vector3.new(hw * 2 + 1.6, 1.4, 0.5), L(house, 0, parapetY, Z0 - 0.4), CONCRETE, PLASTIC)
	Build.part(roof, "ParapetBack", Vector3.new(hw * 2 + 1.6, 1.4, 0.5), L(house, 0, parapetY, Z1 + 0.4), CONCRETE, PLASTIC)
	for _, side in { -1, 1 } do
		Build.part(roof, "ParapetSide", Vector3.new(0.5, 1.4, DEPTH + 1.6), L(house, side * (hw + 0.4), parapetY, CZ), CONCRETE, PLASTIC)
	end
	local trim = Build.part(roof, "ParapetTrim", Vector3.new(hw * 2 + 2, 0.3, 0.8), L(house, 0, parapetY + 0.8, Z0 - 0.4), TRIM_COLORS[house.Trim] or TRIM_COLORS.Wood, METAL)
	table.insert(house.TrimParts, trim)

	-- rooftop equipment: solar panels, water tank, air units
	for index = 0, 3 do
		Build.part(roof, "SolarPanel", Vector3.new(5, 0.3, 3), L(house, -hw + 6 + index * 6, y + 2.1, 60) * CFrame.Angles(math.rad(-22), 0, 0), Color3.fromRGB(40, 60, 120), PLASTIC)
	end
	Build.pillar(roof, "WaterTank", 4.4, 4.4, L(house, hw - 5, y + 3, 40), Palette.Stone, METAL)
	Build.part(roof, "AirUnit", Vector3.new(3.4, 2, 2.4), L(house, hw - 5, y + 1.8, 52), Color3.fromRGB(200, 204, 212), METAL)
	-- rooftop garden from floor 4 on
	if count >= 4 then
		for _, x in { -hw + 6, -hw + 11 } do
			Build.part(roof, "GardenBed", Vector3.new(4, 1, 6), L(house, x, y + 1.3, 36), Palette.WoodDark, WOOD)
			Build.blob(roof, "GardenBush", Vector3.new(3.6, 2.4, 5.4), L(house, x, y + 2.6, 36), Palette.Leaf, Enum.Material.Grass, { CanCollide = false })
		end
	end
	-- the wheel emblem on the front parapet
	local emblemBase = L(house, 0, y + 5.4, Z0 - 0.2)
	Build.part(roof, "EmblemStand", Vector3.new(1, 3, 1), L(house, 0, y + 2.5, Z0 + 0.5), FRAME, PLASTIC)
	emblem(roof, emblemBase, 5.4, TRIM_COLORS[house.Trim] or TRIM_COLORS.Wood)
	-- penthouse crown: a beacon you can see from across the map
	if count >= 5 then
		Build.pillar(roof, "BeaconPost", 0.8, 10, L(house, 0, y + 6, CZ), FRAME, METAL)
		local beacon = Build.blob(roof, "Beacon", Vector3.new(2, 2, 2), L(house, 0, y + 11.4, CZ), Color3.fromRGB(255, 226, 150), NEON, { CanCollide = false })
		Build.light(beacon, Color3.fromRGB(255, 226, 150), 1.6, 40)
		Build.pillar(roof, "BeaconBeam", 1.2, 46, L(house, 0, y + 34, CZ), Color3.fromRGB(255, 236, 170), NEON, { CanCollide = false, Transparency = 0.82, CastShadow = false })
	end
	house.RoofAnchorY = y + 12
end

local function rebuildRoof(house: any, count: number, rng: Random)
	if house.Roof then
		house.Roof:Destroy()
	end
	-- accent / trim lists point at parts that may be gone now
	local keepAccent, keepTrim = {}, {}
	for _, part in house.AccentParts do
		if part.Parent then
			table.insert(keepAccent, part)
		end
	end
	for _, part in house.TrimParts do
		if part.Parent then
			table.insert(keepTrim, part)
		end
	end
	house.AccentParts, house.TrimParts = keepAccent, keepTrim
	local roof = Build.model(house.Tower, "Roof")
	house.Roof = roof
	if count <= 1 then
		buildGableRoof(house, roof)
	else
		buildFlatRoof(house, roof, count, rng)
	end
	if house.RoofLabelAnchor then
		house.RoofLabelAnchor.CFrame = L(house, 0, house.RoofAnchorY + 3, CZ)
	end
end

---------------------------------------------------------------------------
-- public
---------------------------------------------------------------------------

-- Builds floors 1..count (and removes floors above it). Cheap when nothing changed.
function Tower.setFloors(house: any, count: number, rng: Random)
	count = math.clamp(count, 1, FloorConfig.MaxFloors)
	if house.FloorCount == count then
		return
	end
	-- remove floors above `count`
	for f = house.FloorCount, count + 1, -1 do
		local model = house.FloorModels[f]
		if model then
			model:Destroy()
			house.FloorModels[f] = nil
		end
		for index = f * FloorConfig.StationsPerFloor, (f - 1) * FloorConfig.StationsPerFloor + 1, -1 do
			local slot = house.Slots[index]
			if slot then
				slot.Frame:Destroy()
				house.Slots[index] = nil
				for slotIndex, entry in house.DisplayModels do
					if slotIndex == index then
						entry.Model:Destroy()
						house.DisplayModels[slotIndex] = nil
					end
				end
			end
		end
		house.Elevator[f] = nil
		house.Landing[f] = nil
	end
	-- add missing floors
	for f = 1, count do
		if not house.FloorModels[f] then
			house.FloorModels[f] = buildFloor(house, f, rng)
		end
	end
	house.FloorCount = count
	rebuildRoof(house, count, rng)
	-- elevator buttons: up everywhere but the top floor, down everywhere but the first
	for f, buttons in house.Elevator do
		buttons.Up.Enabled = f < count
		buttons.Down.Enabled = f > 1
		buttons.Up.ActionText = if f < count then "Go up: " .. FloorConfig.Floors[f + 1].Name else "Go up"
		buttons.Down.ActionText = if f > 1 then "Go down: " .. FloorConfig.Floors[f - 1].Name else "Go down"
	end
	local owner = house.Model:GetAttribute("OwnerUserId")
	for _, prompt in house.Prompts do
		prompt:SetAttribute("OwnerUserId", owner)
	end
end

function Tower.setTrim(house: any, name: string)
	house.Trim = name
	local color = TRIM_COLORS[name] or TRIM_COLORS.Wood
	for _, part in house.TrimParts do
		if part.Parent then
			part.Color = color
			part.Material = if name == "Wood" then WOOD else (if name == "Diamond" then Enum.Material.Glass else METAL)
		end
	end
end

function Tower.setAccent(house: any, color: Color3)
	house.Accent = color
	for _, part in house.AccentParts do
		if part.Parent then
			part.Color = color
		end
	end
end

Tower.StationX = STATION_X
Tower.StationZ = STATION_Z

return Tower
