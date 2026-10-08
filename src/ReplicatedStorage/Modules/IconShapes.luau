--[[
	Every UI icon of Hamster Plaza as plain shape data (no emoji, no fonts, no uploads needed).

	UI/Icons builds these out of Frames (UICorner + UIGradient + UIStroke + Rotation), and
	tools/export_icons.py renders the exact same data to PNG files in Models/UI/Icons, so you can
	upload them as images later (paste the asset ids in IconShapes.Images and Icons uses an
	ImageLabel instead of the vector version).

	Canvas: 100 x 100. Each shape: { x, y, w, h, ... } = centre and size in canvas units.
	  r    rotation in degrees            c   fill colour (hex)        g   gradient bottom colour (hex)
	  rad  corner radius (0..0.5, 0.5 = circle / pill)
	  s    stroke colour (hex)            sw  stroke width (canvas units)
	  t    fill transparency (0..1)       txt text (ASCII only)  tc text colour  font "title"|"body"
	Shapes are drawn in order (later on top).
]]

local IconShapes = {}

-- Uploaded image ids (optional). Example: IconShapes.Images.Coin = "rbxassetid://1234567890"
IconShapes.Images = {} :: { [string]: string }

local function circle(x: number, y: number, d: number, props: { [string]: any }?): { [string]: any }
	local shape = { x = x, y = y, w = d, h = d, rad = 0.5 }
	local given: { [string]: any } = props or {}
	for key, value in given do
		shape[key] = value
	end
	return shape
end

local function rect(x: number, y: number, w: number, h: number, props: { [string]: any }?): { [string]: any }
	local shape = { x = x, y = y, w = w, h = h }
	local given: { [string]: any } = props or {}
	for key, value in given do
		shape[key] = value
	end
	return shape
end

local SHINE = { c = "FFFFFF", t = 0.45, r = -35 }

IconShapes.Shapes = {
	Coin = {
		circle(50, 52, 88, { c = "C98A12" }),
		circle(50, 48, 88, { c = "FFE27A", g = "F5B21C", s = "C98A12", sw = 5 }),
		circle(50, 48, 62, { c = "F7C33A", g = "FFE27A", s = "E3A21A", sw = 3 }),
		rect(50, 48, 40, 50, { txt = "$", tc = "B9780C", font = "title" }),
		rect(30, 26, 22, 9, { c = "FFFFFF", t = 0.35, r = -40, rad = 0.5 }),
	},
	Gem = {
		rect(50, 54, 62, 62, { c = "1F8FD6", r = 45, rad = 0.08 }),
		rect(50, 50, 62, 62, { c = "8FE8FF", g = "33B5F0", r = 45, rad = 0.08, s = "1F7FC4", sw = 4 }),
		rect(50, 50, 30, 30, { c = "D9F8FF", t = 0.2, r = 45, rad = 0.06 }),
		rect(36, 36, 16, 6, SHINE),
	},
	Rebirth = {
		circle(50, 64, 58, { c = "FF7A2E", g = "E8461B", s = "C23A14", sw = 4 }),
		rect(50, 40, 42, 42, { c = "FF9B3D", g = "FF7A2E", r = 45, rad = 0.18, s = "C23A14", sw = 4 }),
		circle(50, 68, 30, { c = "FFE27A", g = "FFC13D" }),
		rect(50, 54, 20, 20, { c = "FFE27A", r = 45, rad = 0.2 }),
	},
	Token = {
		circle(50, 52, 86, { c = "B8401A" }),
		circle(50, 48, 86, { c = "FF8A4A", g = "E8501F", s = "B8401A", sw = 5 }),
		circle(50, 58, 34, { c = "FFE27A", g = "FFC13D" }),
		rect(50, 44, 24, 24, { c = "FFE27A", r = 45, rad = 0.2 }),
		rect(31, 27, 20, 8, SHINE),
	},
	Luck = {
		rect(56, 76, 8, 30, { c = "2F9E58", r = -25, rad = 0.5 }),
		circle(36, 36, 36, { c = "6FE08A", g = "34B862", s = "248A4B", sw = 3 }),
		circle(64, 36, 36, { c = "6FE08A", g = "34B862", s = "248A4B", sw = 3 }),
		circle(36, 62, 36, { c = "6FE08A", g = "34B862", s = "248A4B", sw = 3 }),
		circle(64, 62, 36, { c = "6FE08A", g = "34B862", s = "248A4B", sw = 3 }),
		circle(50, 49, 14, { c = "248A4B" }),
	},
	Hamster = {
		circle(24, 26, 26, { c = "D68B4E", s = "9A5A2C", sw = 3 }),
		circle(76, 26, 26, { c = "D68B4E", s = "9A5A2C", sw = 3 }),
		circle(24, 26, 13, { c = "FFB3C1" }),
		circle(76, 26, 13, { c = "FFB3C1" }),
		circle(50, 54, 80, { c = "F2B377", g = "D68B4E", s = "9A5A2C", sw = 4 }),
		rect(50, 68, 50, 34, { c = "FFF1DE", rad = 0.5 }),
		circle(35, 50, 10, { c = "3A2A2E" }),
		circle(65, 50, 10, { c = "3A2A2E" }),
		circle(37, 48, 4, { c = "FFFFFF" }),
		circle(67, 48, 4, { c = "FFFFFF" }),
		circle(50, 60, 9, { c = "FF7FA0" }),
		circle(26, 64, 12, { c = "FF9FB4", t = 0.35 }),
		circle(74, 64, 12, { c = "FF9FB4", t = 0.35 }),
	},
	Index = {
		rect(52, 54, 70, 80, { c = "2E6FCF", rad = 0.12 }),
		rect(50, 50, 70, 80, { c = "6FB2FF", g = "3D86E8", rad = 0.12, s = "2E6FCF", sw = 4 }),
		rect(80, 50, 8, 70, { c = "FFF6E6", rad = 0.3 }),
		rect(44, 40, 34, 34, { c = "FFFFFF", t = 0.15, rad = 0.5 }),
		circle(44, 40, 14, { c = "D68B4E" }),
		rect(66, 22, 10, 26, { c = "FF5C6C", rad = 0.15 }),
	},
	Upgrade = {
		circle(50, 52, 86, { c = "1F9E6A" }),
		circle(50, 48, 86, { c = "6FE6A8", g = "2DBE7E", s = "1F9E6A", sw = 5 }),
		rect(50, 58, 14, 40, { c = "FFFFFF", rad = 0.5 }),
		rect(40, 37, 14, 34, { c = "FFFFFF", r = 45, rad = 0.5 }),
		rect(60, 37, 14, 34, { c = "FFFFFF", r = -45, rad = 0.5 }),
	},
	Daily = {
		rect(50, 62, 72, 52, { c = "FF7FAF", g = "F0508A", rad = 0.12, s = "C93C70", sw = 4 }),
		rect(50, 38, 82, 18, { c = "FF9FC4", g = "FF7FAF", rad = 0.2, s = "C93C70", sw = 4 }),
		rect(50, 60, 14, 56, { c = "FFD54A", g = "F5B21C" }),
		rect(50, 38, 14, 18, { c = "FFD54A" }),
		circle(38, 22, 22, { c = "FFD54A", s = "E0A21A", sw = 3 }),
		circle(62, 22, 22, { c = "FFD54A", s = "E0A21A", sw = 3 }),
		circle(50, 26, 12, { c = "F5B21C" }),
	},
	Quests = {
		rect(50, 54, 70, 84, { c = "A86A3E", rad = 0.12 }),
		rect(50, 56, 56, 68, { c = "FFF6E6", rad = 0.08 }),
		rect(50, 16, 30, 14, { c = "D9D9E0", rad = 0.3, s = "8E8E9A", sw = 3 }),
		rect(58, 38, 30, 6, { c = "C9B8A6", rad = 0.5 }),
		rect(58, 56, 30, 6, { c = "C9B8A6", rad = 0.5 }),
		rect(58, 74, 30, 6, { c = "C9B8A6", rad = 0.5 }),
		circle(34, 38, 10, { c = "34B862" }),
		circle(34, 56, 10, { c = "34B862" }),
		circle(34, 74, 10, { c = "E6DCCD" }),
	},
	Shop = {
		circle(50, 30, 44, { t = 1, s = "8A4FD9", sw = 7 }),
		rect(50, 62, 76, 60, { c = "B98BFF", g = "8A4FD9", rad = 0.16, s = "6E36BF", sw = 4 }),
		rect(50, 40, 76, 12, { c = "6E36BF", t = 0.4, rad = 0.3 }),
		circle(50, 64, 20, { c = "FFD54A", s = "E0A21A", sw = 3 }),
	},
	Settings = {
		rect(50, 50, 22, 92, { c = "8C93A6", rad = 0.25 }),
		rect(50, 50, 22, 92, { c = "8C93A6", rad = 0.25, r = 45 }),
		rect(50, 50, 22, 92, { c = "8C93A6", rad = 0.25, r = 90 }),
		rect(50, 50, 22, 92, { c = "8C93A6", rad = 0.25, r = 135 }),
		circle(50, 50, 70, { c = "C5CBD9", g = "8C93A6", s = "6A7084", sw = 4 }),
		circle(50, 50, 30, { c = "4A5064", s = "6A7084", sw = 3 }),
	},
	Close = {
		rect(50, 50, 16, 76, { c = "FFFFFF", r = 45, rad = 0.5 }),
		rect(50, 50, 16, 76, { c = "FFFFFF", r = -45, rad = 0.5 }),
	},
	Star = {
		rect(50, 52, 20, 84, { c = "FFD54A", g = "F5A623", rad = 0.5 }),
		rect(50, 52, 20, 84, { c = "FFD54A", g = "F5A623", rad = 0.5, r = 72 }),
		rect(50, 52, 20, 84, { c = "FFD54A", g = "F5A623", rad = 0.5, r = 144 }),
		rect(50, 52, 20, 84, { c = "FFD54A", g = "F5A623", rad = 0.5, r = 216 }),
		rect(50, 52, 20, 84, { c = "FFD54A", g = "F5A623", rad = 0.5, r = 288 }),
		circle(50, 52, 42, { c = "FFE27A", g = "FFC93C" }),
	},
	Sparkle = {
		rect(50, 50, 18, 86, { c = "FFF3B0", rad = 0.5 }),
		rect(50, 50, 18, 86, { c = "FFF3B0", rad = 0.5, r = 90 }),
		rect(50, 50, 30, 30, { c = "FFFFFF", r = 45 }),
	},
	Wheel = {
		circle(50, 50, 88, { t = 1, s = "B57A44", sw = 9 }),
		rect(50, 50, 6, 80, { c = "D9A066" }),
		rect(50, 50, 6, 80, { c = "D9A066", r = 60 }),
		rect(50, 50, 6, 80, { c = "D9A066", r = -60 }),
		circle(50, 50, 20, { c = "FFD54A", s = "B57A44", sw = 3 }),
	},
	Magnet = {
		rect(26, 44, 20, 64, { c = "FF6B5E", g = "E8463C", rad = 0.2, s = "B83228", sw = 3 }),
		rect(74, 44, 20, 64, { c = "FF6B5E", g = "E8463C", rad = 0.2, s = "B83228", sw = 3 }),
		rect(50, 72, 68, 20, { c = "E8463C", rad = 0.45, s = "B83228", sw = 3 }),
		rect(26, 18, 20, 14, { c = "E9EDF5", s = "8C93A6", sw = 3, rad = 0.15 }),
		rect(74, 18, 20, 14, { c = "E9EDF5", s = "8C93A6", sw = 3, rad = 0.15 }),
	},
	Speed = {
		circle(50, 50, 86, { c = "8FD3FF", g = "3DA0F0", s = "2A7FC4", sw = 5 }),
		rect(40, 38, 12, 30, { c = "FFFFFF", r = -45, rad = 0.5 }),
		rect(40, 62, 12, 30, { c = "FFFFFF", r = 45, rad = 0.5 }),
		rect(62, 38, 12, 30, { c = "FFFFFF", r = -45, rad = 0.5 }),
		rect(62, 62, 12, 30, { c = "FFFFFF", r = 45, rad = 0.5 }),
	},
	Storage = {
		rect(50, 56, 78, 62, { c = "D9A066", g = "B57A44", rad = 0.1, s = "8A5A2E", sw = 4 }),
		rect(50, 30, 84, 16, { c = "E6B57E", rad = 0.15, s = "8A5A2E", sw = 4 }),
		rect(50, 56, 14, 62, { c = "F5E1C2" }),
	},
	Turbo = {
		circle(50, 50, 86, { c = "A8F0C0", g = "34C79A", s = "1F9E6A", sw = 5 }),
		rect(38, 58, 12, 30, { c = "FFFFFF", r = 45, rad = 0.5 }),
		rect(62, 58, 12, 30, { c = "FFFFFF", r = -45, rad = 0.5 }),
		rect(38, 38, 12, 30, { c = "FFFFFF", r = 45, rad = 0.5 }),
		rect(62, 38, 12, 30, { c = "FFFFFF", r = -45, rad = 0.5 }),
	},
	Lock = {
		circle(50, 36, 46, { t = 1, s = "8C93A6", sw = 9 }),
		rect(50, 66, 66, 52, { c = "FFD54A", g = "F5A623", rad = 0.15, s = "C98A12", sw = 4 }),
		circle(50, 62, 12, { c = "8A5A12" }),
		rect(50, 72, 6, 14, { c = "8A5A12", rad = 0.5 }),
	},
	Check = {
		circle(50, 50, 88, { c = "6FE6A8", g = "2DBE7E", s = "1F9E6A", sw = 5 }),
		rect(38, 56, 12, 30, { c = "FFFFFF", r = -45, rad = 0.5 }),
		rect(58, 48, 12, 50, { c = "FFFFFF", r = 40, rad = 0.5 }),
	},
	Shield = {
		rect(50, 40, 70, 52, { c = "6FB2FF", g = "3D86E8", rad = 0.2, s = "2E6FCF", sw = 4 }),
		rect(50, 62, 48, 48, { c = "3D86E8", r = 45, rad = 0.12, s = "2E6FCF", sw = 4 }),
		rect(50, 46, 46, 30, { c = "6FB2FF", g = "3D86E8", rad = 0.2 }),
		rect(50, 52, 10, 30, { c = "FFFFFF", rad = 0.5 }),
		rect(50, 48, 30, 10, { c = "FFFFFF", rad = 0.5 }),
	},
	Floor = {
		rect(50, 54, 60, 88, { c = "FFF1DE", g = "E8D2B6", rad = 0.08, s = "8A6A4E", sw = 4 }),
		rect(50, 12, 66, 8, { c = "FF9F43", rad = 0.4 }),
		rect(38, 30, 12, 12, { c = "6FB2FF", rad = 0.15 }),
		rect(62, 30, 12, 12, { c = "6FB2FF", rad = 0.15 }),
		rect(38, 52, 12, 12, { c = "6FB2FF", rad = 0.15 }),
		rect(62, 52, 12, 12, { c = "6FB2FF", rad = 0.15 }),
		rect(50, 82, 16, 20, { c = "B57A44", rad = 0.15 }),
	},
	Trophy = {
		circle(28, 36, 26, { t = 1, s = "E0A21A", sw = 6 }),
		circle(72, 36, 26, { t = 1, s = "E0A21A", sw = 6 }),
		rect(50, 36, 50, 46, { c = "FFE27A", g = "F5B21C", rad = 0.3, s = "C98A12", sw = 4 }),
		rect(50, 66, 12, 18, { c = "E0A21A" }),
		rect(50, 82, 44, 12, { c = "A86A3E", rad = 0.2 }),
	},
	Clock = {
		circle(50, 50, 86, { c = "FFFFFF", s = "4A5064", sw = 6 }),
		rect(50, 36, 6, 30, { c = "4A5064", rad = 0.5 }),
		rect(60, 54, 6, 26, { c = "FF5C6C", r = 120, rad = 0.5 }),
		circle(50, 50, 10, { c = "4A5064" }),
	},
	Ticket = {
		rect(50, 50, 88, 56, { c = "FFB36B", g = "FF8A3D", rad = 0.14, s = "D9661F", sw = 4, r = -12 }),
		rect(50, 50, 4, 44, { c = "FFFFFF", t = 0.3, r = -12 }),
		rect(32, 52, 22, 8, { c = "FFFFFF", t = 0.2, r = -12, rad = 0.5 }),
	},
	Heart = {
		circle(36, 40, 44, { c = "FF7FA0", g = "F0507A" }),
		circle(64, 40, 44, { c = "FF7FA0", g = "F0507A" }),
		rect(50, 58, 44, 44, { c = "F0507A", r = 45, rad = 0.08 }),
	},
	Info = {
		circle(50, 50, 86, { c = "6FB2FF", g = "3D86E8", s = "2E6FCF", sw = 5 }),
		circle(50, 30, 12, { c = "FFFFFF" }),
		rect(50, 60, 12, 32, { c = "FFFFFF", rad = 0.4 }),
	},
	Warning = {
		circle(50, 50, 86, { c = "FFC93C", g = "F5A623", s = "C98A12", sw = 5 }),
		rect(50, 42, 12, 34, { c = "4A3A2E", rad = 0.4 }),
		circle(50, 70, 12, { c = "4A3A2E" }),
	},
	Coins = {
		circle(36, 64, 60, { c = "C98A12" }),
		circle(36, 60, 60, { c = "FFE27A", g = "F5B21C", s = "C98A12", sw = 4 }),
		circle(62, 42, 60, { c = "C98A12" }),
		circle(62, 38, 60, { c = "FFE27A", g = "F5B21C", s = "C98A12", sw = 4 }),
		rect(62, 38, 30, 34, { txt = "$", tc = "B9780C", font = "title" }),
	},
	Income = {
		circle(50, 50, 86, { c = "FFE27A", g = "F5B21C", s = "C98A12", sw = 5 }),
		rect(50, 60, 14, 40, { c = "FFFFFF", rad = 0.5 }),
		rect(40, 39, 14, 34, { c = "FFFFFF", r = 45, rad = 0.5 }),
		rect(60, 39, 14, 34, { c = "FFFFFF", r = -45, rad = 0.5 }),
	},
}

-- aliases (same drawing, different meaning)
IconShapes.Aliases = {
	Clover = "Luck",
	Bolt = "Speed",
	Gems = "Gem",
	Tokens = "Token",
	Hamsters = "Hamster",
	Inventory = "Hamster",
	Upgrades = "Upgrade",
	Codes = "Ticket",
}
for alias, target in IconShapes.Aliases do
	IconShapes.Shapes[alias] = IconShapes.Shapes[target]
end

-- Icons that are actually drawn (aliases excluded), for exporting.
IconShapes.Unique = {}
do
	for name, shapes in IconShapes.Shapes do
		if not IconShapes.Aliases[name] and #shapes > 0 then
			table.insert(IconShapes.Unique, name)
		end
	end
	table.sort(IconShapes.Unique)
end

function IconShapes.has(name: string): boolean
	return IconShapes.Shapes[name] ~= nil and #IconShapes.Shapes[name] > 0
end

return IconShapes
