--[[
	ENVIRONMENT SETTINGS - mountains, scenery and lighting in one place.

	HOW THIS WORKS (read this once):
	  * The scenery (Workspace/Environment: ground, promenades, forest, lakes, clouds and the MOUNTAINS in
	    Environment/Backdrop) is already BUILT INTO THE PLACE FILE, so you can open it in Roblox Studio, select any
	    mountain / tree / lake in the Explorer and move, recolour, delete or duplicate it. Nothing re-generates it
	    on Play: Environment carries the attribute  StudioOwned = true.
	  * Want the code to rebuild the scenery from the numbers below instead? Select Workspace/Environment, set the
	    attribute StudioOwned to false (or delete the folder), then press Play: the world is generated from this file.
	    Copy what you like back into the place afterwards (Environment is a normal Folder, you can save it as a model).
	  * Lighting works the same way: Lighting/Atmosphere, Bloom, ColorCorrection, SunRays are normal objects you edit
	    in Studio (the Lighting service carries StudioOwned = true). The table `Lighting` below is only used when you
	    set that attribute to false.

	Mountains are built from steep A-frame ridges with colour bands (see WorldBuilder/MountainBuilder): ranges along the OUTER EDGES
	of the map, the centre stays open.
]]

local EnvironmentConfig = {}

EnvironmentConfig.Seed = 20240601

-- Mountain ranges, nearest first. Distances are measured from the edge of the playable ground to the middle of the
-- mountain. `Height`/`Width` are { min, max } in studs. `Fade` tints the rock towards the haze colour (0 = none, 1 = fully hazy).
-- `Detail` 1-3 = how many colour bands each slope gets (more = prettier but more parts). `Peaks` = { min, max } peaks per mountain.
EnvironmentConfig.Ranges = {
	{ Name = "NearRidge", Distance = 175, Jitter = 30, Height = { 85, 150 }, Width = { 120, 190 }, Fade = 0.12, Detail = 3, Peaks = { 3, 4 }, Spacing = 0.9 },
	{ Name = "MidRidge", Distance = 290, Jitter = 70, Height = { 140, 220 }, Width = { 190, 300 }, Fade = 0.4, Detail = 2, Peaks = { 3, 4 }, Spacing = 0.85 },
	{ Name = "FarRidge", Distance = 520, Jitter = 90, Height = { 240, 360 }, Width = { 300, 460 }, Fade = 0.72, Detail = 1, Peaks = { 3, 4 }, Spacing = 0.9 },
}

-- The short sides (east / west ends of the map) get taller mountains than the long sides (north / south).
EnvironmentConfig.EndsHeightScale = 1.25
EnvironmentConfig.LongSidesHeightScale = 0.9
EnvironmentConfig.SnowAbove = 120 -- mountains taller than this get snow caps

EnvironmentConfig.RockColors = {
	Color3.fromRGB(124, 120, 138),
	Color3.fromRGB(142, 134, 148),
	Color3.fromRGB(108, 108, 128),
	Color3.fromRGB(150, 138, 140),
}
EnvironmentConfig.TreelineColor = Color3.fromRGB(88, 128, 94) -- the green apron at the foot of each mountain
EnvironmentConfig.SnowColor = Color3.fromRGB(246, 248, 255)
EnvironmentConfig.HazeColor = Color3.fromRGB(176, 188, 226) -- distant mountains fade towards this

-- Used only when Lighting does not carry StudioOwned = true (see above). Same numbers as the place file.
EnvironmentConfig.Lighting = {
	ClockTime = 16.2,
	Brightness = 2.6,
	Ambient = Color3.fromRGB(118, 110, 140),
	OutdoorAmbient = Color3.fromRGB(142, 140, 170),
	ColorShift_Top = Color3.fromRGB(255, 220, 180),
	EnvironmentDiffuseScale = 0.5,
	EnvironmentSpecularScale = 0.3,
	ShadowSoftness = 0.3,
	Atmosphere = { Density = 0.34, Offset = 0.25, Color = Color3.fromRGB(222, 206, 232), Decay = Color3.fromRGB(255, 176, 146), Glare = 0.18, Haze = 1.7 },
	Bloom = { Intensity = 0.35, Size = 22, Threshold = 1.6 },
	ColorCorrection = { Saturation = 0.16, Contrast = 0.06, TintColor = Color3.fromRGB(255, 249, 241) },
	SunRays = { Intensity = 0.05, Spread = 0.6 },
}

return EnvironmentConfig
