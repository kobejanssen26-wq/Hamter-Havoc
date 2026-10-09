--[[
	Theme: the single place that defines how the interface looks. Mature dark graphite surfaces, warm bronze and
	restrained gold accents, green for positive actions, purple for diamonds, high contrast text.
	UIKit.Colors is built from this table, so changing a value here restyles every panel.
]]

local Theme = {}

Theme.Colors = {
	-- surfaces
	Window = Color3.fromRGB(27, 29, 35),
	Inset = Color3.fromRGB(19, 20, 25),
	Card = Color3.fromRGB(40, 43, 52),
	CardHover = Color3.fromRGB(52, 56, 67),
	Header = Color3.fromRGB(34, 36, 43),
	Line = Color3.fromRGB(66, 70, 82),
	-- text
	Text = Color3.fromRGB(240, 241, 245),
	TextMuted = Color3.fromRGB(150, 155, 170),
	TextDark = Color3.fromRGB(14, 15, 18),
	-- accents
	Bronze = Color3.fromRGB(176, 120, 62),
	BronzeDark = Color3.fromRGB(116, 76, 38),
	Gold = Color3.fromRGB(226, 184, 84),
	GoldDark = Color3.fromRGB(150, 112, 40),
	Green = Color3.fromRGB(70, 178, 108),
	Red = Color3.fromRGB(204, 74, 72),
	Blue = Color3.fromRGB(86, 140, 208),
	Teal = Color3.fromRGB(70, 168, 150),
	Purple = Color3.fromRGB(152, 104, 232), -- diamonds
	Rose = Color3.fromRGB(196, 96, 134),
	Cash = Color3.fromRGB(104, 206, 126),
	Scrim = Color3.fromRGB(6, 7, 10),
}

Theme.Fonts = {
	Title = Enum.Font.GothamBold,
	Big = Enum.Font.GothamBlack,
	Body = Enum.Font.GothamBold,
	Soft = Enum.Font.GothamMedium,
}

Theme.Radius = { Window = 10, Card = 8, Button = 8, Pill = 99 }
Theme.Motion = { Open = 0.2, Close = 0.14, Hover = 0.1 }

-- Where the always-visible controls live.
Theme.Hud = {
	TopMargin = 8, -- below the Roblox top bar
	SideMargin = 12,
	IconButton = 46, -- round shortcut buttons
	IconButtonTouch = 54,
}

return Theme
