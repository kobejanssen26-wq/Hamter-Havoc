--[[
	WorldBuilder: creates the whole map at server start.

	Workspace
	├── HamsterPlaza   arch, shop, hamster library
	├── LeaderboardHall three leaderboard boards + kiosk (behind the library, away from the road and the houses)
	├── HamsterPath    the physical road + spawn burrow + exit tunnel
	├── PlayerHouses   8 houses (4 north row, 4 south row), see WorldLayout
	├── Environment    ground, promenades, gate paths, lamps, forest, mountains, lakes, clouds, boundary (STUDIO-OWNED, see EnvironmentConfig)
	└── SpawnLocations guest spawn
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Build = require(script.Build)
local EnvironmentBuilder = require(script.EnvironmentBuilder)
local HouseBuilder = require(script.HouseBuilder)
local LeaderboardBuilder = require(script.LeaderboardBuilder)
local PathBuilder = require(script.PathBuilder)
local PlazaBuilder = require(script.PlazaBuilder)

local HamsterBuilder = require(ReplicatedStorage.Modules.HamsterBuilder)
local HamsterDatabase = require(ReplicatedStorage.Modules.HamsterDatabase)
local EnvironmentConfig = require(ReplicatedStorage.Modules.EnvironmentConfig)
local WorldLayout = require(ReplicatedStorage.Modules.WorldLayout)

local WorldBuilder = {}

export type World = {
	Houses: { HouseBuilder.House },
	Boards: { LeaderboardBuilder.Board },
	StatueCFrame: CFrame,
	PlazaFolder: Folder,
}

-- Lighting normally lives in the place (Lighting service + Atmosphere / Bloom / ColorCorrection / SunRays objects, all
-- editable in Studio). Only when the Lighting service does NOT carry StudioOwned = true the numbers of
-- EnvironmentConfig.Lighting are applied (first run of a fresh place).
local function setupLighting()
	if Lighting:GetAttribute("StudioOwned") == true then
		return
	end
	local config = EnvironmentConfig.Lighting
	for _, name in { "ClockTime", "Brightness", "Ambient", "OutdoorAmbient", "ColorShift_Top", "EnvironmentDiffuseScale", "EnvironmentSpecularScale", "ShadowSoftness" } do
		(Lighting :: any)[name] = (config :: any)[name]
	end
	Lighting.GlobalShadows = true
	for _, effect in { "Atmosphere", "BloomEffect", "ColorCorrectionEffect", "SunRaysEffect" } do
		local old = Lighting:FindFirstChildOfClass(effect)
		if old then
			old:Destroy()
		end
	end
	local function make(className: string, props: { [string]: any })
		local instance = Instance.new(className)
		for key, value in props do
			(instance :: any)[key] = value
		end
		instance.Parent = Lighting
	end
	make("Atmosphere", config.Atmosphere)
	make("BloomEffect", config.Bloom)
	make("ColorCorrectionEffect", config.ColorCorrection)
	make("SunRaysEffect", config.SunRays)
end

function WorldBuilder.build(): World
	-- (the editor copies in world/*.model.json and HamsterShowcase are only a preview: the real world is built below)
	-- The scenery folder is Studio-owned (see EnvironmentConfig): when it carries StudioOwned = true it is kept exactly
	-- as you left it in Studio. Everything else is rebuilt from code because gameplay is wired to it.
	local environment = Workspace:FindFirstChild("Environment")
	local keepEnvironment = environment ~= nil and environment:GetAttribute("StudioOwned") == true
	for _, name in { "HamsterPlaza", "LeaderboardHall", "HamsterPath", "PlayerHouses", "Environment", "SpawnLocations", "HamsterShowcase", "Baseplate" } do
		local old = Workspace:FindFirstChild(name)
		if old and not (name == "Environment" and keepEnvironment) then
			old:Destroy()
		end
	end

	setupLighting()
	local rng = Random.new(EnvironmentConfig.Seed)

	if keepEnvironment and environment then
		EnvironmentBuilder.adopt(environment)
	else
		EnvironmentBuilder.build(Workspace, rng)
	end
	PathBuilder.build(Workspace, rng)
	local plaza = PlazaBuilder.build(Workspace, rng)
	local hall = LeaderboardBuilder.build(Workspace, rng)

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
		Boards = hall.Boards,
		StatueCFrame = plaza.StatueCFrame,
		PlazaFolder = plaza.Folder,
	}
end

return WorldBuilder
