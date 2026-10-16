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
local Restore = require(script.Restore)

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

-- Which parts of the world belong to Studio and which are generated at every start:
--   Studio-owned (kept exactly as saved in the place when the folder carries StudioOwned = true, otherwise built from code):
--       Environment, HamsterPlaza (shops, wheel, arch, fountain), LeaderboardHall, HamsterPath, SpawnLocations
--   Always generated (they are per player / alive): PlayerHouses, the golden statue on the arch, HamsterShowcase (removed).
-- Delete a Studio-owned folder (or set its attribute StudioOwned to false) and the next Play rebuilds it from the code.
local STUDIO_OWNED = { "Environment", "HamsterPlaza", "LeaderboardHall", "HamsterPath", "SpawnLocations" }

local function keeps(name: string): Instance?
	local folder = Workspace:FindFirstChild(name)
	if folder and folder:GetAttribute("StudioOwned") == true then
		return folder
	end
	return nil
end

local function markOwned(folder: Instance)
	folder:SetAttribute("StudioOwned", true)
end

function WorldBuilder.build(): World
	-- (the editor copies in world/*.model.json are the place's starting point: the real systems are wired below)
	local kept: { [string]: Instance } = {}
	for _, name in STUDIO_OWNED do
		local folder = keeps(name)
		if folder then
			kept[name] = folder
		end
	end
	for _, name in { "HamsterPlaza", "LeaderboardHall", "HamsterPath", "PlayerHouses", "Environment", "SpawnLocations", "HamsterShowcase", "Baseplate" } do
		local old = Workspace:FindFirstChild(name)
		if old and kept[name] ~= old then
			old:Destroy()
		end
	end

	setupLighting()
	local rng = Random.new(EnvironmentConfig.Seed)

	-- the generators always run with the same random numbers, so a rebuilt folder looks the same as before
	local environment = kept.Environment
	if environment then
		EnvironmentBuilder.adopt(environment)
	else
		environment = EnvironmentBuilder.build(Workspace, rng)
	end
	local path = kept.HamsterPath
	local pathRng = Random.new(EnvironmentConfig.Seed + 1)
	if not path then
		path = PathBuilder.build(Workspace, pathRng)
		markOwned(path)
	end
	local plazaFolder = kept.HamsterPlaza
	local plazaRng = Random.new(EnvironmentConfig.Seed + 2)
	local plaza: PlazaBuilder.PlazaInfo
	if plazaFolder then
		plaza = { Folder = plazaFolder :: Folder, StatueCFrame = PlazaBuilder.STATUE_CFRAME }
	else
		plaza = PlazaBuilder.build(Workspace, plazaRng)
		markOwned(plaza.Folder)
	end
	local hallFolder = kept.LeaderboardHall
	local hallRng = Random.new(EnvironmentConfig.Seed + 3)
	local boards = if hallFolder then LeaderboardBuilder.adopt(hallFolder) else nil
	if not boards then
		if hallFolder then
			warn("[World] LeaderboardHall is missing board labels (Title / Period / Row1-10 / Footer): it was rebuilt from the code")
			hallFolder:Destroy()
		end
		local hall = LeaderboardBuilder.build(Workspace, hallRng)
		markOwned(hall.Folder)
		boards = hall.Boards
	end

	-- the golden king watches over the road from the top of the arch (alive: built every start, never saved)
	local oldStatue = plaza.Folder:FindFirstChild("PlazaStatue")
	if oldStatue then
		oldStatue:Destroy()
	end
	local statue = HamsterBuilder.build(HamsterDatabase.ById.golden_king, { Scale = 2.6, Particles = false })
	statue.Name = "PlazaStatue"
	statue:PivotTo(plaza.StatueCFrame)
	statue:AddTag("IdleHamster")
	statue.Parent = plaza.Folder

	-- guest spawn lives in its own folder
	local spawns = kept.SpawnLocations
	if not spawns then
		spawns = Build.folder(Workspace, "SpawnLocations")
		markOwned(spawns)
		local guestSpawn = plaza.Folder:FindFirstChild("PlazaSpawn")
		if guestSpawn then
			guestSpawn.Parent = spawns
		else
			PlazaBuilder.makeSpawn(spawns)
		end
	end

	-- a saved copy of the world may have lost tags / emitters: add what is missing (never removes or moves anything)
	for _, name in STUDIO_OWNED do
		local folder = Workspace:FindFirstChild(name)
		if folder then
			Restore.apply(folder)
		end
	end

	local housesFolder = Build.folder(Workspace, "PlayerHouses")
	local houseRng = Random.new(EnvironmentConfig.Seed + 4)
	local houses = {}
	for index = 1, WorldLayout.HouseCount do
		table.insert(houses, HouseBuilder.build(housesFolder, index, WorldLayout.houseCFrame(index), houseRng))
	end

	return {
		Houses = houses,
		Boards = boards,
		StatueCFrame = plaza.StatueCFrame,
		PlazaFolder = plaza.Folder,
	}
end

return WorldBuilder
