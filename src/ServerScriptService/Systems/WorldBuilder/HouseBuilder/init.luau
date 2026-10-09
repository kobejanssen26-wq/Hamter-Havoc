--[[
	Hamster apartments. A lot (68 x 86) with a security portal, a calm yard and a tower that grows with the owner's
	rebirths: floor 1 is the Hamster Hall, floors 2-5 are unlocked by FloorConfig (see Tower.luau).

	Local frame: origin = middle of the GATE LINE on the ground, +Z = into the lot, -Z = the street.

	Dynamic things (names, stars, floors, wheels, upgrade props, security lights) are refreshed through the functions
	at the bottom of this file by HouseSystem / SecuritySystem.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Build)
local Palette = require(script.Parent.Palette)
local Props = require(script.Props)
local Tower = require(script.Tower)
local Wheels = require(script.Wheels)
local Yard = require(script.Yard)

local UpgradeConfig = require(ReplicatedStorage.Modules.UpgradeConfig)
local WorldLayout = require(ReplicatedStorage.Modules.WorldLayout)

local HouseBuilder = {}

local NEON = Enum.Material.Neon
local PLASTIC = Enum.Material.SmoothPlastic

export type Slot = {
	Index: number,
	Floor: number,
	Center: CFrame,
	RunCFrame: CFrame,
	Ring: BasePart,
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
	Accent: Color3,
	DefaultRoof: Color3,
	AccentParts: { BasePart },
	TrimParts: { BasePart },
	Trim: string,
	Stars: { BasePart },
	Labels: { [string]: TextLabel },
	Prompts: { [string]: ProximityPrompt },
	Slots: { [number]: Slot },
	Stations: { [string]: any },
	Tower: Model,
	Roof: Model?,
	RoofLabelAnchor: BasePart,
	RoofAnchorY: number,
	WheelsFolder: Folder,
	FloorCount: number,
	FloorModels: { [number]: Model },
	Elevator: { [number]: { [string]: ProximityPrompt } },
	Landing: { [number]: CFrame },
	DisplayFolder: Folder,
	DisplayModels: { [number]: { SpeciesId: string, Model: Model } },
	Security: {
		Beams: { BasePart },
		Field: BasePart,
		Lamps: { BasePart },
		PylonLamp: BasePart,
		Prompt: ProximityPrompt,
		Anchor: BasePart,
		Screen: TextLabel,
	},
	Owner: Player?,
}

function HouseBuilder.build(parent: Instance, index: number, cframe: CFrame, rng: Random): House
	local model = Build.model(parent, "House" .. index)
	model:SetAttribute("HouseId", index)
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("OwnerName", "")
	model:SetAttribute("SecState", "Off")
	model:SetAttribute("SecUntil", 0)
	model:SetAttribute("SecReady", 0)

	local accent = Palette.RoofColors[(index - 1) % #Palette.RoofColors + 1]
	local towerModel = Build.model(model, "Tower")

	local house: House = {
		Index = index,
		Model = model,
		CFrame = cframe,
		SpawnCFrame = cframe * CFrame.new(0, 3, 9),
		GatePosition = cframe.Position,
		PadCFrame = cframe * CFrame.new(WorldLayout.PadLocal),
		Accent = accent,
		DefaultRoof = accent,
		AccentParts = {},
		TrimParts = {},
		Trim = "Wood",
		Stars = {},
		Labels = {},
		Prompts = {},
		Slots = {},
		Stations = {},
		Tower = towerModel,
		Roof = nil,
		RoofLabelAnchor = nil :: any,
		RoofAnchorY = 0,
		WheelsFolder = Build.folder(model, "Wheels"),
		FloorCount = 0,
		FloorModels = {},
		Elevator = {},
		Landing = {},
		DisplayFolder = Build.folder(model, "Display"),
		DisplayModels = {},
		Security = nil :: any,
		Owner = nil,
	}

	Yard.build(house, rng)

	-- roof name banner readable from far away (find your house)
	local roofAnchor = Build.deco(model, "RoofAnchor", Vector3.one * 0.3, cframe * CFrame.new(0, 20, (WorldLayout.TowerFront + WorldLayout.TowerBack) / 2), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1 })
	house.RoofLabelAnchor = roofAnchor
	house.Labels.Roof = Build.billboard(roofAnchor, "", Vector2.new(280, 46), Vector3.zero, { MaxDistance = 260, Name = "RoofName" })

	Tower.setFloors(house, 1, rng)
	Tower.setTrim(house, "Wood")
	return house
end

---------------------------------------------------------------------------
-- dynamic refresh helpers (called by HouseSystem / SecuritySystem)
---------------------------------------------------------------------------

HouseBuilder.setFloors = Tower.setFloors
HouseBuilder.setTrim = Tower.setTrim
HouseBuilder.setWheel = Wheels.set
HouseBuilder.setWheelSpeed = Wheels.setSpeed

function HouseBuilder.setRoofColor(house: House, color: Color3)
	Tower.setAccent(house, color)
end

-- Rebuilds the prop and label of one upgrade pedestal.
function HouseBuilder.setStation(house: House, upgradeId: string, level: number, rebirths: number?)
	local station = house.Stations[upgradeId]
	local definition = UpgradeConfig.Definitions[upgradeId]
	if not station or not definition then
		return
	end
	station.PropFolder:ClearAllChildren()
	local maxLevel = UpgradeConfig.maxLevel(upgradeId, rebirths or 0)
	local fraction = math.clamp(level / maxLevel, 0, 1)
	local ghost = if level <= 0 then 0.6 else 0
	Props.Upgrade[upgradeId](station.PropFolder, station.Top, math.max(fraction, 0.05), ghost)
	local levelText = if level >= maxLevel then "MAX" else string.format("Lv %d/%d", level, maxLevel)
	station.Label.Text = string.format("%s\n<font color=\"#FFE08A\">%s</font>", definition.Name, levelText)
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
	local texts = { Active = "SECURE", Recharging = "RECHARGING", Ready = "PRESS F/E", None = "NO OWNER" }
	security.Screen.Text = texts[state] or "OFF"
	security.Screen.TextColor3 = lampColor
end

return HouseBuilder
