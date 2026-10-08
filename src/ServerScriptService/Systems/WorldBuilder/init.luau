--[[
	WorldBuilder: creates the whole map at server start.

	Workspace
	├── HamsterPlaza   arch, shop, hamster library, recent-finds board
	├── HamsterPath    the physical road + spawn burrow + exit tunnel
	├── PlayerHouses   8 houses (4 north row, 4 south row), see WorldLayout
	├── Environment    ground, promenades, gate paths, lamps, forest, boundary
	└── SpawnLocations guest spawn
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Build = require(script.Build)
local EnvironmentBuilder = require(script.EnvironmentBuilder)
local HouseBuilder = require(script.HouseBuilder)
local PathBuilder = require(script.PathBuilder)
local PlazaBuilder = require(script.PlazaBuilder)

local HamsterBuilder = require(ReplicatedStorage.Modules.HamsterBuilder)
local HamsterDatabase = require(ReplicatedStorage.Modules.HamsterDatabase)
local WorldLayout = require(ReplicatedStorage.Modules.WorldLayout)

local WorldBuilder = {}

export type World = {
	Houses: { HouseBuilder.House },
	RecentLabels: { TextLabel },
	StatueCFrame: CFrame,
	PlazaFolder: Folder,
}

local function setupLighting()
	Lighting.ClockTime = 15.4
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(112, 104, 128)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 140, 160)
	Lighting.EnvironmentDiffuseScale = 0.5
	Lighting.EnvironmentSpecularScale = 0.3
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.3
	Lighting.ColorShift_Top = Color3.fromRGB(255, 230, 200)

	for _, name in { "Atmosphere", "Bloom", "ColorCorrection", "SunRays" } do
		local old = Lighting:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.2
	atmosphere.Color = Color3.fromRGB(255, 226, 205)
	atmosphere.Decay = Color3.fromRGB(255, 188, 168)
	atmosphere.Glare = 0.1
	atmosphere.Haze = 1.1
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 22
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local correction = Instance.new("ColorCorrectionEffect")
	correction.Saturation = 0.14
	correction.Contrast = 0.05
	correction.TintColor = Color3.fromRGB(255, 249, 241)
	correction.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.04
	rays.Spread = 0.6
	rays.Parent = Lighting
end

function WorldBuilder.build(): World
	for _, name in { "HamsterPlaza", "HamsterPath", "PlayerHouses", "Environment", "SpawnLocations", "Baseplate" } do
		local old = Workspace:FindFirstChild(name)
		if old then
			old:Destroy()
		end
	end

	setupLighting()
	local rng = Random.new(20240601)

	EnvironmentBuilder.build(Workspace, rng)
	PathBuilder.build(Workspace, rng)
	local plaza = PlazaBuilder.build(Workspace, rng)

	-- the golden king watches over the road from the top of the arch
	local statue = HamsterBuilder.build(HamsterDatabase.ById.golden_king, { Scale = 2.6, Particles = false })
	statue.Name = "PlazaStatue"
	statue:PivotTo(plaza.StatueCFrame)
	statue:AddTag("IdleHamster")
	statue.Parent = plaza.Folder

	-- guest spawn lives in its own folder
	local spawns = Build.folder(Workspace, "SpawnLocations")
	local guestSpawn = plaza.Folder:FindFirstChild("PlazaSpawn")
	if guestSpawn then
		guestSpawn.Parent = spawns
	end

	local housesFolder = Build.folder(Workspace, "PlayerHouses")
	local houses = {}
	for index = 1, WorldLayout.HouseCount do
		table.insert(houses, HouseBuilder.build(housesFolder, index, WorldLayout.houseCFrame(index), rng))
	end

	return {
		Houses = houses,
		RecentLabels = plaza.RecentLabels,
		StatueCFrame = plaza.StatueCFrame,
		PlazaFolder = plaza.Folder,
	}
end

return WorldBuilder
