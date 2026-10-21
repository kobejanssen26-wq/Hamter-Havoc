--[[
	Hamster Plaza: the calm centre of the map. The hamster road runs straight through a paved circle and
	under a big golden-hamster arch; two short annex paths lead to the two places that matter
	(the two shops in the north - Coins Shop on the left, Robux Shop on the right, with the Lucky Wheel on its own platform behind them -
	and a fountain in the south that leads on to the Leaderboard Hall). The Hamster Index
	has no building: it is a tab in the Backpack. Everything is mirror-symmetric, nothing else is placed on purpose.
]]

local FavoritesConfig = require(game:GetService("ReplicatedStorage").Modules.FavoritesConfig)
local Build = require(script.Parent.Build)
local Decor = require(script.Parent.Decor)
local LuckyWheelBuilder = require(script.Parent.LuckyWheelBuilder)
local Palette = require(script.Parent.Palette)

local PlazaBuilder = {}

-- Both boards stand on grass, clear of every path (scn_plazapaths measures this). Board 1 lies along the road in the lawn strip between the road curb
-- (z = -13.8) and the south promenade (z = -25), its front towards the promenade; board 2 stands on the lawn across the promenade, straight ahead of
-- the guest spawn, its front towards the promenade and the spawn. Every board reads from both sides.
PlazaBuilder.FAVORITES_BOARD = CFrame.new(-34, 0, -19.6)
PlazaBuilder.FAVORITES_BOARD_2 = CFrame.new(-28, 0, -48) * CFrame.Angles(0, math.rad(180), 0)

-- where the golden statue stands (on top of the arch): the statue itself is created at every start
PlazaBuilder.STATUE_CFRAME = CFrame.new(0, 19.2, 0) * CFrame.Angles(0, math.rad(90), 0)

local WOOD = Enum.Material.WoodPlanks
local PLASTIC = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local PAVING_HEIGHT = 0.1 -- top of the outer paving disc, the annex paths, the shop approach and the wheel path (the promenades and the hall paving are as high)

export type PlazaInfo = {
	Folder: Folder,
	StatueCFrame: CFrame,
}

local function publicPrompt(parent: BasePart, objectText: string, actionText: string, opens: string, distance: number?)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = objectText
	prompt.ActionText = actionText
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = distance or 12
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt:SetAttribute("OpenUI", opens)
	prompt.Parent = parent
	return prompt
end

-- The Shop: a proper little building (walls, door, windows, gable roof, awning, counter with shelves and goods inside).
-- `cframe` is the ground point in front of the door; the door faces -Z (towards the plaza), the room extends to +Z.
local function darker(color: Color3): Color3
	return color:Lerp(Color3.new(0, 0, 0), 0.25)
end

export type ShopStyle = {
	Name: string, -- model name in Workspace/HamsterPlaza
	Title: string, -- text on the sign
	Wall: Color3,
	Roof: Color3,
	Accent: Color3, -- emblem and lantern glow
	Emblem: "coin" | "gem",
	ObjectText: string,
	Menu: string, -- which window the door opens: "Shop" (Coins Shop) or "RobuxShop"
	Focus: string, -- the category that window opens on
}

-- Edit these two tables to restyle the shops (colours, names, which shop the door opens).
PlazaBuilder.CoinsShop = {
	Name = "CoinsShop",
	Title = "COINS SHOP",
	Wall = Palette.Wall,
	Roof = Color3.fromRGB(222, 142, 44),
	Accent = Color3.fromRGB(255, 205, 70),
	Emblem = "coin",
	ObjectText = "Coins Shop",
	Menu = "Shop",
	Focus = "Weapons",
} :: ShopStyle
PlazaBuilder.RobuxShop = {
	Name = "RobuxShop",
	Title = "ROBUX SHOP",
	Wall = Color3.fromRGB(222, 236, 250),
	Roof = Color3.fromRGB(52, 104, 196),
	Accent = Color3.fromRGB(80, 200, 255),
	Emblem = "gem",
	ObjectText = "Robux Shop",
	Menu = "RobuxShop",
	Focus = "Gamepasses",
} :: ShopStyle
PlazaBuilder.ShopX = 15 -- the shops stand at x = -ShopX (Coins) and +ShopX (Robux), z = ShopZ
PlazaBuilder.ShopZ = 52

local function buildShop(parent: Instance, cframe: CFrame, style: ShopStyle)
	local model = Build.model(parent, style.Name)
	local wall = style.Wall
	local roofColor = style.Roof
	-- everything is built from a few modular pieces: foundation, 4 walls (a door gap in front, a window opening in each side wall), two roof slopes, gable ends.
	-- Parts of a different colour never share a face plane (they would flicker): slabs end inside the walls, trims sit proud of them.
	Build.part(model, "Foundation", Vector3.new(16, 0.6, 11.4), cframe * CFrame.new(0, 0.3, 5), Palette.StoneDark, Enum.Material.Cobblestone)
	Build.part(model, "Floor", Vector3.new(13.8, 0.2, 9.8), cframe * CFrame.new(0, 0.65, 4.9), Palette.WoodLight, WOOD, { CanCollide = false })
	Build.part(model, "WallBack", Vector3.new(14, 8, 0.7), cframe * CFrame.new(0, 4.6, 9.65), wall, PLASTIC)
	for _, side in { -1, 1 } do
		-- the side wall is four slabs around the window opening (z 3.0 .. 6.6, y 3.7 .. 6.7); the two piers reach 0.05 into the slabs above and below it
		local wallX = side * 6.65
		Build.part(model, "WallSide", Vector3.new(0.7, 3.1, 9.6), cframe * CFrame.new(wallX, 2.15, 4.85), wall, PLASTIC) -- under the window
		Build.part(model, "WallSide", Vector3.new(0.7, 1.9, 9.6), cframe * CFrame.new(wallX, 7.65, 4.85), wall, PLASTIC) -- over the window
		Build.part(model, "WallSide", Vector3.new(0.7, 3.1, 2.95), cframe * CFrame.new(wallX, 5.2, 1.525), wall, PLASTIC) -- pier at the door end
		Build.part(model, "WallSide", Vector3.new(0.7, 3.1, 3.05), cframe * CFrame.new(wallX, 5.2, 8.125), wall, PLASTIC) -- pier at the back
		Build.part(model, "WallFront", Vector3.new(4.4, 8, 0.7), cframe * CFrame.new(side * 4.8, 4.6, 0.2), wall, PLASTIC)
		Build.part(model, "CornerPost", Vector3.new(1, 8.6, 1), cframe * CFrame.new(side * 7, 4.9, 0.2), Palette.WoodDark, WOOD)
		Build.part(model, "CornerPostBack", Vector3.new(1, 8.6, 1), cframe * CFrame.new(side * 7, 4.9, 9.7), Palette.WoodDark, WOOD)
		-- the glass fills the opening (a little larger, so it ends inside the wall); the frame is four boards on the outer face of the wall
		Build.part(model, "WindowGlass", Vector3.new(0.2, 3.1, 3.7), cframe * CFrame.new(wallX, 5.2, 4.8), Palette.Sky, Enum.Material.Glass, { Transparency = 0.45, CanCollide = false })
		local frameX = side * 7.06
		Build.deco(model, "WindowFrame", Vector3.new(0.12, 0.2, 4), cframe * CFrame.new(frameX, 6.8, 4.8), Palette.WoodDark, WOOD)
		Build.deco(model, "WindowFrame", Vector3.new(0.12, 0.2, 4), cframe * CFrame.new(frameX, 3.6, 4.8), Palette.WoodDark, WOOD)
		for _, z in { 2.9, 6.7 } do
			Build.deco(model, "WindowFrame", Vector3.new(0.12, 3, 0.2), cframe * CFrame.new(frameX, 5.2, z), Palette.WoodDark, WOOD)
		end
		-- a flower box under the window
		Build.deco(model, "FlowerBox", Vector3.new(0.9, 0.7, 4.2), cframe * CFrame.new(side * 7.2, 3.2, 4.8), Palette.Wood, WOOD)
		for index = 1, 3 do
			Build.blob(model, "Blossom", Vector3.new(0.8, 0.8, 0.8), cframe * CFrame.new(side * 7.2, 3.8, 3.2 + index * 1.2), Palette.FlowerColors[(index + (side + 1)) % #Palette.FlowerColors + 1], Enum.Material.Grass, { CanCollide = false })
		end
	end
	Build.part(model, "Lintel", Vector3.new(5.2, 2.6, 0.7), cframe * CFrame.new(0, 7.3, 0.2), wall, PLASTIC)
	Build.deco(model, "DoorFrameTop", Vector3.new(5.4, 0.4, 0.9), cframe * CFrame.new(0, 6.1, 0.05), Palette.WoodDark, WOOD)
	-- two solid steps up to the door: the lower one stands on the approach, the upper one ends at the floor (same height, no ledge at the threshold)
	Build.part(model, "Step2", Vector3.new(7.4, 0.42, 1.6), cframe * CFrame.new(0, 0.21, -2.2), Palette.StoneDark, Enum.Material.Slate)
	Build.part(model, "Step1", Vector3.new(6.6, 0.75, 1.7), cframe * CFrame.new(0, 0.375, -0.85), Palette.Stone, Enum.Material.Slate)

	-- gable roof (ridge along X), overhanging the walls. The slabs lie on the wall tops: their underside meets y = 8.6 at the outer face of the front / back wall.
	local slope = math.tan(math.rad(28))
	local rise = 6 * slope
	local roofY = 8.6 + rise / 2 - 0.15 -- height of the middle of a slab (z = 2 front, z = 8 back)
	local underside = 0.35 / math.cos(math.rad(28)) -- the underside of a slab lies this far under its middle
	for _, side in { -1, 1 } do
		-- (the back slab is 0.1 longer: where the two slabs cross at the ridge their end faces would otherwise lie in one plane)
		Build.part(model, "Roof", Vector3.new(if side > 0 then 16.1 else 16, 0.7, 7.2), cframe * CFrame.new(0, roofY, 5 + side * 3) * CFrame.Angles(math.rad(side * 28), 0, 0), roofColor, Enum.Material.Slate, { CanCollide = false })
	end
	Build.deco(model, "Ridge", Vector3.new(16.4, 0.6, 1), cframe * CFrame.new(0, 8.6 + rise - 0.05, 5), darker(roofColor), Enum.Material.Slate)
	-- The gable ends are stacked slices as deep as the roof underside at the BOTTOM of the slice, so every slice reaches into the roof slab and no notch is left.
	local sliceHeight = (roofY + 3 * slope - underside - 8.6) / 5 -- from the wall top to the underside of the roof at the ridge, in five steps
	for _, x in { -6.95, 6.95 } do
		for slice = 1, 5 do
			local bottom = 8.6 + (slice - 1) * sliceHeight
			local depth = 2 * (5 - (2 + (bottom - roofY + underside) / slope)) -- the roof underside is this deep (z) at y = bottom
			Build.part(model, "Gable", Vector3.new(0.7, sliceHeight + 0.02, depth), cframe * CFrame.new(x, bottom + sliceHeight / 2, 5), wall, PLASTIC)
		end
	end

	-- striped awning over the door (six stripes side by side, no overlap)
	local stripe = 5.2 / 6
	for index = 1, 6 do
		local color = if index % 2 == 0 then Palette.Cream else roofColor
		Build.deco(model, "Awning", Vector3.new(stripe, 0.25, 4.2), cframe * CFrame.new(-2.6 + (index - 0.5) * stripe, 7.2, -1.5) * CFrame.Angles(math.rad(-16), 0, 0), color, PLASTIC)
	end

	-- inside: back shelves with goods, a counter, a rug and a hanging lamp
	Build.part(model, "Shelf", Vector3.new(11, 5.2, 1), cframe * CFrame.new(0, 3.3, 9), Palette.WoodDark, WOOD)
	for row = 1, 3 do
		Build.deco(model, "ShelfBoard", Vector3.new(10.6, 0.25, 1.3), cframe * CFrame.new(0, 1.2 + row * 1.25, 8.6), Palette.WoodLight, WOOD)
		for slot = 1, 7 do
			local color = Palette.FlowerColors[(slot + row) % #Palette.FlowerColors + 1]
			local y = 1.2 + row * 1.25 + 0.65
			if (slot + row) % 3 == 0 then
				Build.blob(model, "Jar", Vector3.new(0.8, 1.0, 0.8), cframe * CFrame.new(-4.2 + (slot - 1) * 1.4, y, 8.5), color, Enum.Material.Glass, { CanCollide = false, Transparency = 0.15 })
			elseif (slot + row) % 3 == 1 then
				Build.deco(model, "Crate", Vector3.new(0.95, 0.9, 0.95), cframe * CFrame.new(-4.2 + (slot - 1) * 1.4, y - 0.05, 8.5), color, PLASTIC)
			else
				Build.blob(model, "Plush", Vector3.new(0.9, 0.9, 0.9), cframe * CFrame.new(-4.2 + (slot - 1) * 1.4, y, 8.5), color, PLASTIC, { CanCollide = false })
			end
		end
	end
	Build.deco(model, "Rug", Vector3.new(7, 0.06, 4.4), cframe * CFrame.new(0, 0.78, 4.6), roofColor, Enum.Material.Fabric)
	local counter = Build.part(model, "Counter", Vector3.new(7.2, 2.6, 1.8), cframe * CFrame.new(0, 2, 6.4), Palette.WoodLight, WOOD)
	Build.part(model, "CounterTop", Vector3.new(7.8, 0.35, 2.4), cframe * CFrame.new(0, 3.45, 6.4), Palette.WoodDark, WOOD, { CanCollide = false })
	Build.deco(model, "Till", Vector3.new(1.6, 1.0, 1.1), cframe * CFrame.new(2.2, 4.1, 6.4), Palette.Gold, Enum.Material.Metal)
	Build.deco(model, "Scale", Vector3.new(1.2, 0.2, 1.2), cframe * CFrame.new(-2.2, 3.7, 6.4), Palette.Stone, Enum.Material.Metal)
	local lamp = Build.blob(model, "ShopLamp", Vector3.new(1.5, 1.3, 1.5), cframe * CFrame.new(0, 8, 4.5), Color3.fromRGB(255, 226, 160), NEON, { CanCollide = false })
	Build.light(lamp, Color3.fromRGB(255, 224, 170), 1.3, 20)

	-- hanging blade sign + painted fascia
	local sign = Build.part(model, "Sign", Vector3.new(9.5, 2.4, 0.5), cframe * CFrame.new(0, 10.4, -0.7), Palette.WoodDark, WOOD, { CanCollide = false })
	Build.surfaceText(sign, Enum.NormalId.Front, style.Title, { TextColor = Palette.Cream, PixelsPerStud = 50 })
	-- emblem above the sign so the two shops are told apart from a distance (it stands on a small block on the sign)
	local emblemAt = cframe * CFrame.new(0, 13.4, -0.7)
	Build.deco(model, "EmblemMount", Vector3.new(0.5, 0.7, 0.4), cframe * CFrame.new(0, 11.95, -0.7), Palette.WoodDark, WOOD)
	if style.Emblem == "coin" then
		Build.pillar(model, "Emblem", 3, 0.5, emblemAt * CFrame.Angles(math.rad(90), 0, 0), style.Accent, Enum.Material.Metal, { CanCollide = false })
		Build.pillar(model, "EmblemFace", 2.2, 0.56, emblemAt * CFrame.Angles(math.rad(90), 0, 0), darker(style.Accent), Enum.Material.Metal, { CanCollide = false })
	else
		Build.deco(model, "Emblem", Vector3.new(2.2, 2.2, 0.6), emblemAt * CFrame.Angles(0, 0, math.rad(45)), style.Accent, NEON, { CanCollide = false })
	end
	for _, side in { -1, 1 } do
		Build.deco(model, "SignPost", Vector3.new(0.4, 1.6, 0.4), cframe * CFrame.new(side * 4.2, 9.5, -0.5), Palette.WoodDark, WOOD)
	end

	-- outside props: barrels and crates beside the steps (they stand on the ground / the approach), lanterns on the posts
	for _, side in { -1, 1 } do
		Build.pillar(model, "Barrel", 1.7, 2, cframe * CFrame.new(side * 5.4, 1, -1.5), Palette.Wood, WOOD)
		Build.deco(model, "BarrelBand", Vector3.new(1.85, 0.15, 1.85), cframe * CFrame.new(side * 5.4, 1.3, -1.5), Palette.StoneDark, Enum.Material.Metal)
		Build.blob(model, "Lantern", Vector3.new(0.8, 1.0, 0.8), cframe * CFrame.new(side * 7.2, 4, -0.5), style.Accent:Lerp(Color3.new(1, 1, 1), 0.5), NEON, { CanCollide = false })
	end
	Build.deco(model, "CrateStack", Vector3.new(1.6, 1.6, 1.6), cframe * CFrame.new(-8.6, 0.8, -0.4), Palette.WoodLight, WOOD)
	Build.deco(model, "CrateSmall", Vector3.new(1.1, 1.1, 1.1), cframe * CFrame.new(-8.4, 2.15, -0.5) * CFrame.Angles(0, math.rad(18), 0), Palette.Wood, WOOD)

	local prompt = publicPrompt(counter, style.ObjectText, "Browse", style.Menu, 14)
	prompt:SetAttribute("Focus", style.Focus)
	if style.Menu == "Shop" then
		Build.target(counter, "Shop") -- the tutorial points at the Coins Shop
	end
	return model
end

-- The plaza fountain at the south end of the plaza (where a second building used to be), now beside the walking route: a round stone basin,
-- a column and two bowls, rippling water, benches and flowers. Everything is concentric, so nothing can clip.
local function buildFountain(parent: Instance, cframe: CFrame, rng: Random)
	local model = Build.model(parent, "PlazaFountain")
	local center = cframe.Position
	Build.pillar(model, "Basin", 15, 1.6, CFrame.new(center.X, 0.8, center.Z), Palette.Stone, Enum.Material.Slate)
	Build.pillar(model, "BasinRim", 15.8, 0.4, CFrame.new(center.X, 1.6, center.Z), Palette.StoneDark, Enum.Material.Slate)
	-- (the water stands 0.06 above the rim, so the basin reads as full to the brim and the water is not hidden inside the stone)
	local water = Build.pillar(model, "Water", 13, 0.3, CFrame.new(center.X, 1.71, center.Z), Palette.Water, Enum.Material.Glass, { CanCollide = false, Transparency = 0.25, Reflectance = 0.2, CastShadow = false })
	water:SetAttribute("Ripple", true)
	Build.pillar(model, "Column", 2, 4.5, CFrame.new(center.X, 3.6, center.Z), Palette.Cream, Enum.Material.Marble)
	Build.pillar(model, "BowlLower", 6, 0.7, CFrame.new(center.X, 3.1, center.Z), Palette.Cream, Enum.Material.Marble)
	Build.pillar(model, "BowlUpper", 3.6, 0.6, CFrame.new(center.X, 5.5, center.Z), Palette.Cream, Enum.Material.Marble)
	Build.blob(model, "Finial", Vector3.new(1.4, 1.8, 1.4), CFrame.new(center.X, 6.6, center.Z), Palette.Gold, Enum.Material.Metal, { CanCollide = false })
	for index = 0, 5 do
		local angle = index * math.pi / 3
		Build.blob(model, "Spout", Vector3.new(0.5, 1.4, 0.5), CFrame.new(center.X + math.cos(angle) * 2.6, 3.9, center.Z + math.sin(angle) * 2.6), Palette.Water, Enum.Material.Glass, { CanCollide = false, Transparency = 0.35 })
	end
	-- one bench on the side that faces the walking route (the other side is the neighbouring house lot)
	local towardRoute = if center.X < 0 then 1 else -1
	Decor.bench(model, CFrame.new(center.X + towardRoute * 13, 0, center.Z) * CFrame.Angles(0, math.rad(90 * towardRoute), 0))
	for _, side in { -1, 1 } do
		Decor.flowers(model, Vector3.new(center.X + side * 9, 0, center.Z + 9.5), 2.5, 8, rng)
		Decor.flowers(model, Vector3.new(center.X + side * 9, 0, center.Z - 9.5), 2.5, 8, rng)
	end
	return model
end

-- A Like & Favorite board (see Modules/FavoritesConfig and SocialConfig for what it can and can not do): two posts, a wooden board that is
-- readable from BOTH sides (the same picture rows on the front and on the back), and one prompt on each side that opens the Community window.
-- The pictures are drawn by the client (frames named IconHost with the attribute IconName); the texts come from FavoritesConfig.
-- `cframe`: the ground point under the middle of the board; the front of the board looks along -Z of this frame.
local BOARD_WIDTH, BOARD_HEIGHT = 8.6, 7.6

local function boardFace(board: BasePart, face: Enum.NormalId)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui_" .. face.Name
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.LightInfluence = 0.1
	gui.MaxDistance = 70
	gui.Parent = board
	local function text(parent: Instance, name: string, content: string, size: UDim2, position: UDim2, textSize: number, color: Color3, font: Enum.Font, alignment: Enum.TextXAlignment): TextLabel
		local textLabel = Instance.new("TextLabel")
		textLabel.Name = name
		textLabel.BackgroundTransparency = 1
		textLabel.Size = size
		textLabel.Position = position
		textLabel.Text = content
		textLabel.TextSize = textSize
		textLabel.TextColor3 = color
		textLabel.Font = font
		textLabel.TextXAlignment = alignment
		textLabel.TextTruncate = Enum.TextTruncate.AtEnd
		textLabel.Parent = parent
		return textLabel
	end
	text(gui, "Title", FavoritesConfig.Title, UDim2.new(1, 0, 0, 56), UDim2.fromOffset(0, 8), 38, Palette.Gold, Enum.Font.FredokaOne, Enum.TextXAlignment.Center)
	for index, row in FavoritesConfig.rows() do
		local holder = Instance.new("Frame")
		holder.Name = "Row_" .. row.Id
		holder.BackgroundColor3 = Color3.fromRGB(52, 56, 92)
		holder.BorderSizePixel = 0
		holder.Size = UDim2.new(1, -28, 0, 58)
		holder.Position = UDim2.fromOffset(14, 68 + (index - 1) * 64)
		holder.Parent = gui
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 12)
		corner.Parent = holder
		local host = Instance.new("Frame")
		host.Name = "IconHost"
		host.BackgroundTransparency = 1
		host.Size = UDim2.fromOffset(46, 46)
		host.Position = UDim2.fromOffset(10, 6)
		host:SetAttribute("IconName", row.Icon)
		host.Parent = holder
		text(holder, "RowTitle", row.Title, UDim2.new(1, -80, 0, 28), UDim2.fromOffset(66, 3), 25, Color3.new(1, 1, 1), Enum.Font.FredokaOne, Enum.TextXAlignment.Left)
		text(holder, "RowText", row.Text, UDim2.new(1, -80, 0, 22), UDim2.fromOffset(66, 31), 17, Color3.fromRGB(190, 198, 235), Enum.Font.GothamMedium, Enum.TextXAlignment.Left)
	end
	text(gui, "Footer", FavoritesConfig.Footer, UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 1, -30), 16, Color3.fromRGB(150, 158, 200), Enum.Font.GothamMedium, Enum.TextXAlignment.Center)
end

local function buildFavoritesBoard(parent: Instance, cframe: CFrame, name: string)
	local model = Build.model(parent, name)
	model:AddTag("FavoritesBoard")
	local width, height = BOARD_WIDTH, BOARD_HEIGHT
	local center = height / 2 + 0.8
	for _, side in { -1, 1 } do
		Build.part(model, "Post", Vector3.new(0.7, height + 0.4, 0.7), cframe * CFrame.new(side * 3.7, (height + 0.4) / 2, 0.25), Palette.WoodDark, WOOD)
		Build.deco(model, "PostCap", Vector3.new(1.0, 0.35, 1.0), cframe * CFrame.new(side * 3.7, height + 0.55, 0.25), Palette.Gold, Enum.Material.Metal)
	end
	-- the frame is a thin wooden border behind and around the board (it never covers either face)
	Build.deco(model, "Frame", Vector3.new(width + 0.6, height + 0.6, 0.3), cframe * CFrame.new(0, center, 0.25), Palette.Wood, WOOD)
	local board = Build.part(model, "Board", Vector3.new(width, height, 0.4), cframe * CFrame.new(0, center, 0.25), Color3.fromRGB(34, 36, 60), PLASTIC, { CanCollide = false })
	Build.light(board, Color3.fromRGB(200, 210, 255), 0.5, 18)
	Build.deco(model, "Glow", Vector3.new(width + 0.2, 0.25, 0.5), cframe * CFrame.new(0, center + height / 2 + 0.4, 0.25), Palette.Gold, NEON) -- (rests on the frame, its top 0.2 above the frame top)
	Build.deco(model, "Base", Vector3.new(8.8, 0.3, 2.2), cframe * CFrame.new(0, 0.15, 0.25), Palette.Stone, Enum.Material.Slate)
	boardFace(board, Enum.NormalId.Front)
	boardFace(board, Enum.NormalId.Back)

	-- the interaction: one prompt per side opens the Community window (Invite / Like / Favorite / Group, see Controllers/FavoritesController)
	for side, offset in { Front = -2.6, Back = 3.1 } do
		local pad = Build.deco(model, "PromptPad_" .. side, Vector3.new(6, 1, 3), cframe * CFrame.new(0, 1.2, offset), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1, CanQuery = false })
		local prompt = Instance.new("ProximityPrompt")
		prompt.ObjectText = FavoritesConfig.PromptObject
		prompt.ActionText = FavoritesConfig.PromptAction
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		prompt:SetAttribute("InviteFriends", true) -- answered by the client: opens the Community window (Controllers/FavoritesController)
		prompt.Parent = pad
	end
	return model
end

-- The arch over the road: two pillars, a beam with the plaza name and the golden king on top.
local function buildArch(parent: Instance): CFrame
	local model = Build.model(parent, "PlazaArch")
	for _, side in { -1, 1 } do
		Build.part(model, "Pillar", Vector3.new(3.8, 15, 3.8), CFrame.new(0, 7.5, side * 17.5), Palette.Stone, Enum.Material.Slate)
		Build.part(model, "PillarBase", Vector3.new(4.6, 1.2, 4.6), CFrame.new(0, 0.6, side * 17.5), Palette.StoneDark, Enum.Material.Slate)
		Build.part(model, "PillarCap", Vector3.new(4.4, 0.8, 4.4), CFrame.new(0, 15.4, side * 17.5), Palette.Gold, Enum.Material.Metal, { CanCollide = false })
	end
	local beam = Build.part(model, "ArchBeam", Vector3.new(3.8, 3, 40), CFrame.new(0, 16.8, 0), Palette.Cream, Enum.Material.Marble)
	Build.deco(model, "ArchTrim", Vector3.new(4.4, 0.5, 40.6), CFrame.new(0, 18.6, 0), Palette.Gold, Enum.Material.Metal)
	Build.deco(model, "ArchTrim", Vector3.new(4.4, 0.5, 40.6), CFrame.new(0, 15.2, 0), Palette.Gold, Enum.Material.Metal)
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
		Build.surfaceText(beam, face, "HAMSTER PLAZA", { TextColor = Palette.WoodDark, PixelsPerStud = 40 })
	end
	Build.part(model, "StatuePlinth", Vector3.new(6, 1, 6), CFrame.new(0, 18.7, 0), Palette.Gold, Enum.Material.Metal)
	return PlazaBuilder.STATUE_CFRAME
end

-- The guest spawn on the plaza (players without a house).
function PlazaBuilder.makeSpawn(parent: Instance): SpawnLocation
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Size = Vector3.new(5, 1, 8) -- (x -28 .. -23: the plaza-edge lamp at (-22, -22) stands outside it, a guest can not land in its base)
	spawn.Position = Vector3.new(-25.5, 0.7, -21)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = parent
	return spawn
end

function PlazaBuilder.build(parent: Instance, rng: Random): PlazaInfo
	local folder = Build.folder(parent, "HamsterPlaza")

	-- paving: three discs on top of each other and the road (top 0.28) on top of them. Every layer is 0.06 above the one under it, so no two surfaces of a
	-- different colour lie close enough to flicker; the light paths and the promenade lie at the height of the outer disc (PAVING_HEIGHT), all walkable.
	Build.pillar(folder, "PavingOuter", 62, PAVING_HEIGHT, CFrame.new(0, PAVING_HEIGHT / 2, 0), Palette.Pavement, Enum.Material.Cobblestone)
	Build.pillar(folder, "PavingRing", 54, PAVING_HEIGHT + 0.06, CFrame.new(0, (PAVING_HEIGHT + 0.06) / 2, 0), Palette.PavementDark, Enum.Material.Cobblestone)
	Build.pillar(folder, "PavingInner", 51.6, PAVING_HEIGHT + 0.12, CFrame.new(0, (PAVING_HEIGHT + 0.12) / 2, 0), Palette.Pavement, Enum.Material.Cobblestone)

	local statueCFrame = buildArch(folder)

	-- annex paths to the two buildings, mirrored north / south
	for _, sign in { 1, -1 } do
		Build.part(folder, "AnnexPath", Vector3.new(10, PAVING_HEIGHT, 30), CFrame.new(0, PAVING_HEIGHT / 2, sign * 40), Palette.Pavement, Enum.Material.Cobblestone, { CanCollide = false })
	end
	-- two shops side by side with a gap between them: Coins (left) and Robux (right). The annex path leads to a wide
	-- approach in front of both doors, and a path continues between them to the Lucky Wheel platform behind.
	local shopX, shopZ = PlazaBuilder.ShopX, PlazaBuilder.ShopZ
	buildShop(folder, CFrame.new(-shopX, 0, shopZ), PlazaBuilder.CoinsShop)
	buildShop(folder, CFrame.new(shopX, 0, shopZ), PlazaBuilder.RobuxShop)
	Build.part(folder, "ShopApproach", Vector3.new(shopX * 2 + 4, PAVING_HEIGHT, 6), CFrame.new(0, PAVING_HEIGHT / 2, shopZ - 4.5), Palette.Pavement, Enum.Material.Cobblestone, { CanCollide = false })
	local wheelZ = LuckyWheelBuilder.CENTER.Z
	local wheelPathStart = shopZ + 3
	Build.part(folder, "WheelPath", Vector3.new(8, PAVING_HEIGHT, wheelZ - 6.5 - wheelPathStart), CFrame.new(0, PAVING_HEIGHT / 2, (wheelPathStart + wheelZ - 6.5) / 2), Palette.Pavement, Enum.Material.Cobblestone, { CanCollide = false })
	for _, side in { -1, 1 } do
		Decor.flowers(folder, Vector3.new(side * 7, 0, wheelZ - 14), 2.4, 8, rng)
		Decor.lamp(folder, Vector3.new(side * 5.4, 0, wheelZ - 9), 7)
	end
	-- The walking route to the Leaderboard Hall runs straight down x = 0 (see PlazaBuilder.ROUTE_HALF_WIDTH). The fountain
	-- sits BESIDE it, in a small garden; a reading nook with trees balances the other side. Nothing solid stands in the route.
	buildFountain(folder, CFrame.new(-20, 0, -64), rng)
	local nook = Build.model(folder, "ReadingNook")
	Decor.tree(nook, Vector3.new(21, 0, -58), "cherry", 1.2, rng)
	Decor.tree(nook, Vector3.new(21, 0, -72), "cherry", 1.1, rng)
	Decor.bench(nook, CFrame.new(7.5, 0, -65) * CFrame.Angles(0, math.rad(-90), 0))
	Decor.flowers(nook, Vector3.new(14, 0, -65), 3, 12, rng)
	-- signpost beside the route (not in it, and not on the promenade it crosses), facing the people who walk south out of the plaza
	Decor.signpost(folder, CFrame.new(12.5, 0, -53) * CFrame.Angles(0, math.pi, 0), "LEADERBOARDS  v", nil)

	-- a few quiet details: lamps along the annex (north: at both ends of the shop approach, which is paved all the way across), two trees per annex
	for _, sign in { 1, -1 } do
		for _, x in { -1, 1 } do
			Decor.lamp(folder, Vector3.new(x * (if sign > 0 then PlazaBuilder.ShopX + 4.5 else 8), 0, sign * 46), 8)
		end
		local treeX = if sign > 0 then 30 else 16 -- north: beside the shops, not in front of their doors
		Decor.tree(folder, Vector3.new(-treeX, 0, sign * 46), "cherry", 1.2, rng)
		Decor.tree(folder, Vector3.new(treeX, 0, sign * 46), "cherry", 1.2, rng)
	end
	-- the plaza edge: four lamps on the diagonals and flower rings by the arch
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			Decor.lamp(folder, Vector3.new(sx * 22, 0, sz * 22), 8)
			Decor.flowers(folder, Vector3.new(sx * 26, 0, sz * 19), 3, 10, rng)
		end
	end

	-- the physical Lucky Wheel on its own platform in the green area behind the two shops
	LuckyWheelBuilder.build(folder, rng)

	-- the two Like & Favorite boards near the guest spawn
	buildFavoritesBoard(folder, PlazaBuilder.FAVORITES_BOARD, "FavoritesBoard")
	buildFavoritesBoard(folder, PlazaBuilder.FAVORITES_BOARD_2, "FavoritesBoard2")

	-- guest spawn on the plaza (players without a house); WorldBuilder moves it to Workspace/SpawnLocations
	PlazaBuilder.makeSpawn(folder)

	return {
		Folder = folder,
		StatueCFrame = statueCFrame,
	}
end

return PlazaBuilder
