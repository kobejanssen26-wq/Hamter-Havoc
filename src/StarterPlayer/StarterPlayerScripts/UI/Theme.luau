--[[
	Theme: the single place that defines how the interface looks. Playful simulator style: rich violet surfaces, saturated
	accents (green = go / cash, orange = primary, blue, pink, yellow, red), thick dark outlines, heavy rounded type, white text.
	UIKit.Colors is built from this table, so changing a value here restyles every panel.
]]

local Theme = {}

Theme.Colors = {
	-- surfaces: rich violet (not grey): windows, darker insets, lighter cards. Strong dark-violet OUTLINES do the separating.
	Window = Color3.fromRGB(58, 38, 118),
	Inset = Color3.fromRGB(36, 22, 84),
	Card = Color3.fromRGB(84, 58, 154),
	CardHover = Color3.fromRGB(104, 76, 182),
	Header = Color3.fromRGB(120, 70, 230),
	Line = Color3.fromRGB(26, 12, 62), -- the outline colour (also used as the dark text outline)
	-- text
	Text = Color3.fromRGB(255, 255, 255),
	TextMuted = Color3.fromRGB(214, 202, 245),
	TextDark = Color3.fromRGB(34, 16, 70),
	-- saturated accents (Bronze = the primary action colour, kept under its old key)
	Bronze = Color3.fromRGB(255, 148, 28),
	BronzeDark = Color3.fromRGB(196, 98, 10),
	Gold = Color3.fromRGB(255, 214, 40),
	GoldDark = Color3.fromRGB(200, 150, 10),
	Green = Color3.fromRGB(58, 214, 84),
	Red = Color3.fromRGB(255, 72, 88),
	Blue = Color3.fromRGB(56, 160, 255),
	Teal = Color3.fromRGB(26, 214, 190),
	Purple = Color3.fromRGB(176, 98, 255), -- diamonds
	Rose = Color3.fromRGB(255, 84, 170),
	Cash = Color3.fromRGB(92, 236, 112),
	Scrim = Color3.fromRGB(14, 6, 40),
}

-- One accent colour per window / category, so every screen is recognisable at a glance.
Theme.Accents = {
	Shop = Color3.fromRGB(58, 214, 84),
	Robux = Color3.fromRGB(255, 214, 40),
	Backpack = Color3.fromRGB(56, 160, 255),
	Quests = Color3.fromRGB(255, 148, 28),
	Leaderboards = Color3.fromRGB(176, 98, 255),
	Settings = Color3.fromRGB(26, 214, 190),
	Rebirth = Color3.fromRGB(255, 84, 170),
	Upgrades = Color3.fromRGB(255, 72, 88),
	Admin = Color3.fromRGB(255, 72, 88),
}

-- Typography: two weights only. Titles/numbers/prices are Bold, every sentence is Medium.
Theme.Fonts = {
	Title = Enum.Font.GothamBlack,
	Big = Enum.Font.GothamBlack,
	Body = Enum.Font.GothamMedium,
	Soft = Enum.Font.GothamMedium,
}
-- Size scale (px at design scale). Use these instead of ad-hoc numbers: Display (big numbers), Title (window titles),
-- Heading (item names, values), Body (descriptions), Caption (hints, tags).
Theme.Type = { Display = 28, Title = 20, Heading = 16, Body = 14, Caption = 12 }

Theme.Radius = { Window = 16, Card = 10, Button = 10, Pill = 99 }
Theme.Outline = { Thin = 2, Thick = 3 } -- stroke widths (px at design scale)
Theme.Motion = { Open = 0.2, Close = 0.14, Hover = 0.1 }

-- Spacing / sizing tokens (pixels at design scale).
Theme.Space = { XS = 4, S = 8, M = 12, L = 16, XL = 24 }
Theme.Size = { Pill = 44, Button = 40, IconButton = 46, IconButtonTouch = 54, Header = 52, Slot = 60, SlotTouch = 54 }

-- ScreenGui DisplayOrder: one explicit rule for who is in front of whom.
Theme.Layers = {
	World = 0, -- billboards are not ScreenGuis, listed for completeness
	Hud = 1,
	Hotbar = 2,
	Tutorial = 8,
	Panels = 10, -- every full screen menu (only one is open at a time)
	Reveal = 15, -- new hamster fanfare
	Toast = 30,
	Tooltip = 60,
	Modal = 80,
}

-- Where the always-visible controls live.
Theme.Hud = {
	TopMargin = 8, -- below the Roblox top bar
	SideMargin = 12,
	IconButton = 46, -- round shortcut buttons
	IconButtonTouch = 54,
}

return Theme
