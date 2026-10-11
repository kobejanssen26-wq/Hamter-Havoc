--[[
	Theme: the single place that defines how the interface looks. Mature dark graphite surfaces, warm bronze and
	restrained gold accents, green for positive actions, purple for diamonds, high contrast text.
	UIKit.Colors is built from this table, so changing a value here restyles every panel.
]]

local Theme = {}

Theme.Colors = {
	-- surfaces: deep midnight indigo, lifted by a few vivid accents
	Window = Color3.fromRGB(26, 29, 42),
	Inset = Color3.fromRGB(19, 21, 31),
	Card = Color3.fromRGB(37, 41, 58),
	CardHover = Color3.fromRGB(49, 54, 76),
	Header = Color3.fromRGB(30, 33, 48),
	Line = Color3.fromRGB(62, 68, 94),
	-- text
	Text = Color3.fromRGB(247, 247, 253),
	TextMuted = Color3.fromRGB(165, 171, 205),
	TextDark = Color3.fromRGB(16, 17, 32),
	-- accents (Bronze = the primary action colour, kept under its old key)
	Bronze = Color3.fromRGB(255, 146, 48),
	BronzeDark = Color3.fromRGB(184, 98, 24),
	Gold = Color3.fromRGB(255, 205, 72),
	GoldDark = Color3.fromRGB(190, 142, 40),
	Green = Color3.fromRGB(58, 208, 124),
	Red = Color3.fromRGB(255, 88, 98),
	Blue = Color3.fromRGB(80, 170, 255),
	Teal = Color3.fromRGB(46, 210, 192),
	Purple = Color3.fromRGB(178, 122, 255), -- diamonds
	Rose = Color3.fromRGB(255, 108, 168),
	Cash = Color3.fromRGB(96, 232, 142),
	Scrim = Color3.fromRGB(8, 9, 20),
}

-- Typography: two weights only. Titles/numbers/prices are Bold, every sentence is Medium.
Theme.Fonts = {
	Title = Enum.Font.GothamBold,
	Big = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
	Soft = Enum.Font.GothamMedium,
}
-- Size scale (px at design scale). Use these instead of ad-hoc numbers: Display (big numbers), Title (window titles),
-- Heading (item names, values), Body (descriptions), Caption (hints, tags).
Theme.Type = { Display = 28, Title = 20, Heading = 16, Body = 14, Caption = 12 }

Theme.Radius = { Window = 8, Card = 6, Button = 6, Pill = 99 }
Theme.Motion = { Open = 0.2, Close = 0.14, Hover = 0.1 }

-- Spacing / sizing tokens (pixels at design scale).
Theme.Space = { XS = 4, S = 8, M = 12, L = 16, XL = 24 }
Theme.Size = { Pill = 34, Button = 40, IconButton = 46, IconButtonTouch = 54, Header = 52, Slot = 60, SlotTouch = 54 }

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
