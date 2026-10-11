--[[
	Theme: the single place that defines how the interface looks. Mature dark graphite surfaces, warm bronze and
	restrained gold accents, green for positive actions, purple for diamonds, high contrast text.
	UIKit.Colors is built from this table, so changing a value here restyles every panel.
]]

local Theme = {}

Theme.Colors = {
	-- surfaces: deep midnight indigo, lifted by a few vivid accents
	Window = Color3.fromRGB(28, 31, 54),
	Inset = Color3.fromRGB(20, 22, 40),
	Card = Color3.fromRGB(43, 47, 78),
	CardHover = Color3.fromRGB(58, 63, 102),
	Header = Color3.fromRGB(36, 39, 68),
	Line = Color3.fromRGB(78, 84, 132),
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

Theme.Fonts = {
	Title = Enum.Font.GothamBold,
	Big = Enum.Font.GothamBlack,
	Body = Enum.Font.GothamBold,
	Soft = Enum.Font.GothamMedium,
}

Theme.Radius = { Window = 10, Card = 8, Button = 8, Pill = 99 }
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
