--[[
	YardConfig: where the garden of every player's house stands (the same layout for all eight houses).

	Coordinates are in studs, local to the lot: X = left (-) / right (+) of the driveway, Z = how far you are from the gate line
	into the lot (the tower stands about Z 30-60, the gate at Z 0). Change a number, press Play, look at the result.
	The house audit (tools/SimTests: scn_houses) tells you when something now touches the tower, a fence or the driveway.

	Tree Kind: "round" | "cherry" | "pine"      EvenKind (optional): another kind for the even-numbered houses (2, 4, 6, 8)
	Scale 1 = normal size. Trees near the tower wall or the fence must stay small (the defaults were measured).
]]

local YardConfig = {}

YardConfig.Trees = {
	{ X = -28.5, Z = 14, Kind = "round", EvenKind = "cherry", Scale = 0.85 },
	{ X = 28.5, Z = 24, Kind = "round", Scale = 0.85 },
	{ X = -28.4, Z = 62, Kind = "pine", Scale = 0.95 }, -- (clear of the tower roof on one side and the fence on the other)
	{ X = 28.2, Z = 62, Kind = "round", Scale = 0.8 },
}

YardConfig.Flowers = {
	{ X = -16, Z = 14, Radius = 3.5, Count = 12 },
}

-- Turn: degrees around the vertical axis (180 = the seat faces the tower)
-- (the rebirth altar stands at X 19, Z 14: its platform and rune stones reach Z 18.6, so the bench sits beside and behind it)
YardConfig.Benches = {
	{ X = 12, Z = 21, Turn = 180 },
}

YardConfig.Lamps = {
	{ X = -7, Z = 10, Height = 7 },
	{ X = 7, Z = 10, Height = 7 },
}

-- the backyard pond behind the tower
YardConfig.Pond = { X = 0, Z = 79, Radius = 4.5 }

return YardConfig
