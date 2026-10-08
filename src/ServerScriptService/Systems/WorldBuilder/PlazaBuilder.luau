--[[
	Hamster Plaza: the heart of the map. Paved circle with a fountain, five little buildings/stalls on the
	south arc (quests, shop, the Hamster Library, daily gift, promo codes), benches and lamps facing the road,
	a garden with a windmill and a pond on the north side, a rarity chart and a "recent finds" board.
	The hamster road arcs around the north side of the fountain, so everything faces the action.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Build)
local Decor = require(script.Parent.Decor)
local Palette = require(script.Parent.Palette)

local RarityConfig = require(ReplicatedStorage.Modules.RarityConfig)

local PlazaBuilder = {}

local WOOD = Enum.Material.WoodPlanks
local PLASTIC = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

export type PlazaInfo = {
	Folder: Folder,
	RecentLabels: { TextLabel },
	StatueCFrame: CFrame,
}

local function polar(radius: number, degrees: number): Vector3
	local radians = math.rad(degrees)
	return Vector3.new(math.cos(radians) * radius, 0, math.sin(radians) * radius)
end

local function facingCenter(position: Vector3): CFrame
	return CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
end

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

-- Small market stall. Customers stand at -Z; `cframe` is the ground point in front of the counter.
local function buildStall(parent: Instance, name: string, cframe: CFrame, title: string, icon: string, awning: Color3, opens: string, action: string)
	local model = Build.model(parent, name)
	Build.part(model, "Base", Vector3.new(11, 0.5, 8), cframe * CFrame.new(0, 0.25, 2.8), Palette.Stone, Enum.Material.Cobblestone)
	Build.part(model, "BackWall", Vector3.new(9.6, 7.4, 0.6), cframe * CFrame.new(0, 4.2, 6), Palette.Wall, PLASTIC)
	for _, side in { -1, 1 } do
		Build.part(model, "SideWall", Vector3.new(0.6, 7.4, 6), cframe * CFrame.new(side * 4.8, 4.2, 3), Palette.Wall, PLASTIC)
		Build.part(model, "Post", Vector3.new(0.8, 8.2, 0.8), cframe * CFrame.new(side * 4.9, 4.6, -0.2), Palette.WoodDark, WOOD)
		local lantern = Build.blob(model, "Lantern", Vector3.new(0.9, 1.1, 0.9), cframe * CFrame.new(side * 4.9, 3.4, -0.9), Color3.fromRGB(255, 226, 150), NEON, { CanCollide = false })
		Build.light(lantern, Color3.fromRGB(255, 214, 140), 0.7, 10)
	end
	local counter = Build.part(model, "Counter", Vector3.new(9.2, 2.6, 2.4), cframe * CFrame.new(0, 1.8, 0.4), Palette.WoodLight, WOOD)
	Build.part(model, "CounterTop", Vector3.new(9.8, 0.4, 3), cframe * CFrame.new(0, 3.3, 0.3), Palette.WoodDark, WOOD, { CanCollide = false })

	for index = 1, 5 do
		local color = if index % 2 == 0 then Palette.Cream else awning
		Build.part(model, "Awning", Vector3.new(2.1, 0.3, 6.4), cframe * CFrame.new(-4.2 + (index - 1) * 2.1, 8.1, 1.7) * CFrame.Angles(math.rad(-14), 0, 0), color, PLASTIC, { CanCollide = false })
	end

	local sign = Build.part(model, "Sign", Vector3.new(9, 2.4, 0.5), cframe * CFrame.new(0, 10.2, -1.3), Palette.WoodLight, WOOD, { CanCollide = false })
	Build.surfaceText(sign, Enum.NormalId.Front, icon .. " " .. title, { TextColor = Palette.Ink, PixelsPerStud = 50 })
	for _, side in { -1, 1 } do
		Build.deco(model, "SignPost", Vector3.new(0.4, 2.2, 0.4), cframe * CFrame.new(side * 3.8, 9, -1.3), Palette.WoodDark, WOOD)
	end

	-- little trinkets on the counter so each stall feels lived in
	Build.blob(model, "Trinket", Vector3.new(1.2, 1.2, 1.2), cframe * CFrame.new(-2.8, 4.1, 0.3), awning, PLASTIC, { CanCollide = false })
	Build.blob(model, "Trinket", Vector3.new(1, 1, 1), cframe * CFrame.new(2.6, 4, 0.3), Palette.Gold, Enum.Material.Metal, { CanCollide = false })

	publicPrompt(counter, title, action, opens, 13)
	return model
end

local function buildLibrary(parent: Instance, cframe: CFrame)
	local model = Build.model(parent, "HamsterLibrary")
	local wallColor = Palette.Wall
	Build.part(model, "Floor", Vector3.new(15, 0.5, 10.4), cframe * CFrame.new(0, 0.25, 5), Palette.WoodLight, WOOD)
	Build.part(model, "WallBack", Vector3.new(14, 8, 0.7), cframe * CFrame.new(0, 4, 9.6), wallColor, PLASTIC)
	for _, side in { -1, 1 } do
		Build.part(model, "WallSide", Vector3.new(0.7, 8, 9.6), cframe * CFrame.new(side * 6.65, 4, 4.8), wallColor, PLASTIC)
		Build.part(model, "WallFrontSide", Vector3.new(4.4, 8, 0.7), cframe * CFrame.new(side * 4.8, 4, 0.2), wallColor, PLASTIC)
		Build.part(model, "Pillar", Vector3.new(1, 8.6, 1), cframe * CFrame.new(side * 7, 4.3, 0.2), Palette.WoodDark, WOOD)
		Build.part(model, "Window", Vector3.new(0.2, 3, 3.6), cframe * CFrame.new(side * 6.72, 4.8, 4.8), Palette.Sky, Enum.Material.Glass, { Transparency = 0.45, CanCollide = false })
	end
	Build.part(model, "Lintel", Vector3.new(5.2, 2.4, 0.7), cframe * CFrame.new(0, 6.8, 0.2), wallColor, PLASTIC)

	-- gable roof (ridge along X)
	local rise = 5.4 * math.tan(math.rad(28))
	for _, side in { -1, 1 } do
		Build.part(model, "Roof", Vector3.new(15.6, 0.7, 6.6), cframe * CFrame.new(0, 8 + rise / 2 + 0.4, 4.8 + side * 2.7) * CFrame.Angles(math.rad(side * 28), 0, 0), Palette.RoofColors[3], Enum.Material.Slate)
	end
	Build.part(model, "Ridge", Vector3.new(15.6, 0.6, 1), cframe * CFrame.new(0, 8 + rise + 0.45, 4.8), Palette.RoofColors[3], Enum.Material.Slate)
	for _, x in { -6.9, 6.9 } do
		for slice = 1, 5 do
			local height = rise / 5
			Build.part(model, "Gable", Vector3.new(0.7, height + 0.02, 10.4 * (1 - (slice - 0.5) / 5)), cframe * CFrame.new(x, 8 + (slice - 0.5) * height, 4.8), wallColor, PLASTIC)
		end
	end

	-- interior glow, bookshelf, lectern
	Build.part(model, "Shelf", Vector3.new(11, 5, 1), cframe * CFrame.new(0, 3, 9), Palette.WoodDark, WOOD)
	for row = 1, 3 do
		for book = 1, 9 do
			local color = Palette.FlowerColors[(book + row) % #Palette.FlowerColors + 1]
			Build.deco(model, "Book", Vector3.new(0.7, 1.1, 0.5), cframe * CFrame.new(-4.6 + (book - 1) * 1.15, 1.6 + row * 1.3, 8.4), color, PLASTIC)
		end
	end
	local lamp = Build.blob(model, "HallLamp", Vector3.new(1.6, 1.4, 1.6), cframe * CFrame.new(0, 7.2, 4.5), Color3.fromRGB(255, 226, 160), NEON, { CanCollide = false })
	Build.light(lamp, Color3.fromRGB(255, 224, 170), 1.2, 18)
	local lectern = Build.part(model, "Lectern", Vector3.new(2.6, 2.8, 1.6), cframe * CFrame.new(0, 1.9, 3.4), Palette.Wood, WOOD)
	Build.part(model, "Book", Vector3.new(2.2, 0.2, 1.4), cframe * CFrame.new(0, 3.4, 3.4) * CFrame.Angles(math.rad(-20), 0, 0), Palette.Cream, PLASTIC, { CanCollide = false })

	local sign = Build.part(model, "Sign", Vector3.new(12, 2.6, 0.6), cframe * CFrame.new(0, 12.4, -0.4), Palette.WoodDark, WOOD, { CanCollide = false })
	Build.surfaceText(sign, Enum.NormalId.Front, "📖 HAMSTER INDEX", { TextColor = Palette.Cream, PixelsPerStud = 50 })
	publicPrompt(lectern, "Hamster Index", "Open", "Index", 14)
end

local function buildQuestBoard(parent: Instance, cframe: CFrame)
	local model = Build.model(parent, "QuestBoard")
	for _, side in { -1, 1 } do
		Build.part(model, "Post", Vector3.new(0.7, 8, 0.7), cframe * CFrame.new(side * 4.6, 4, 1), Palette.WoodDark, WOOD)
	end
	local board = Build.part(model, "Board", Vector3.new(10, 6, 0.6), cframe * CFrame.new(0, 5, 1), Palette.WoodLight, WOOD)
	Build.part(model, "Roof", Vector3.new(11.4, 0.6, 2.6), cframe * CFrame.new(0, 8.4, 0.8) * CFrame.Angles(math.rad(-10), 0, 0), Palette.RoofColors[1], PLASTIC, { CanCollide = false })
	Build.surfaceText(board, Enum.NormalId.Front, "📜 QUESTS", { TextColor = Palette.Ink, PixelsPerStud = 50, BackgroundTransparency = 1 })
	for index = 1, 6 do
		local color = if index % 2 == 0 then Palette.Cream else Palette.Peach
		Build.deco(model, "Note", Vector3.new(1.4, 1.8, 0.1), cframe * CFrame.new(-3.6 + (index - 1) * 1.45, 3.4 + (index % 2) * 0.5, 0.65) * CFrame.Angles(0, 0, math.rad((index % 3 - 1) * 4)), color, PLASTIC)
	end
	Build.part(model, "Step", Vector3.new(8, 0.4, 3), cframe * CFrame.new(0, 0.2, -1), Palette.Stone, Enum.Material.Cobblestone)
	publicPrompt(board, "Quest Board", "Quests", "Quests", 14)
end

local function buildGiftStand(parent: Instance, cframe: CFrame)
	local model = Build.model(parent, "DailyGift")
	Build.pillar(model, "Stand", 7, 0.8, cframe * CFrame.new(0, 0.4, 2.5), Palette.Stone, Enum.Material.Cobblestone)
	local gift = Build.part(model, "Gift", Vector3.new(3.4, 3, 3.4), cframe * CFrame.new(0, 2.4, 2.5), Palette.Pink, PLASTIC)
	Build.part(model, "Lid", Vector3.new(3.8, 0.8, 3.8), cframe * CFrame.new(0, 4.2, 2.5), Palette.RoofColors[6], PLASTIC, { CanCollide = false })
	Build.deco(model, "RibbonA", Vector3.new(0.7, 3.2, 3.5), cframe * CFrame.new(0, 2.4, 2.5), Palette.Gold, PLASTIC)
	Build.deco(model, "RibbonB", Vector3.new(3.5, 3.2, 0.7), cframe * CFrame.new(0, 2.4, 2.5), Palette.Gold, PLASTIC)
	Build.blob(model, "BowL", Vector3.new(1.6, 1.1, 1), cframe * CFrame.new(-0.9, 5, 2.5), Palette.Gold, PLASTIC, { CanCollide = false })
	Build.blob(model, "BowR", Vector3.new(1.6, 1.1, 1), cframe * CFrame.new(0.9, 5, 2.5), Palette.Gold, PLASTIC, { CanCollide = false })
	Build.animate(model, "Bob", { Amplitude = 0.25, Speed = 1.8 })
	local anchor = Build.deco(model, "Anchor", Vector3.one * 0.2, cframe * CFrame.new(0, 7.2, 2.5), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1 })
	Build.billboard(anchor, "🎁 Daily Gift", Vector2.new(190, 34), Vector3.zero, { MaxDistance = 60 })
	publicPrompt(gift, "Daily Gift", "Open", "Daily", 12)
end

local function buildRarityBoard(parent: Instance, cframe: CFrame)
	local model = Build.model(parent, "RarityBoard")
	for _, side in { -1, 1 } do
		Build.part(model, "Post", Vector3.new(0.9, 12, 0.9), cframe * CFrame.new(side * 10.4, 6, 0.8), Palette.WoodDark, WOOD)
	end
	local board = Build.part(model, "Board", Vector3.new(22, 12.6, 0.8), cframe * CFrame.new(0, 7.4, 0.8), Palette.Cream, WOOD)
	Build.part(model, "Frame", Vector3.new(23, 13.6, 0.5), cframe * CFrame.new(0, 7.4, 1.2), Palette.WoodDark, WOOD, { CanCollide = false })

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 32
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 52)
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 40
	title.TextColor3 = Palette.Ink
	title.Text = "🐹 HAMSTER RARITIES"
	title.Parent = gui

	local total = 0
	for _, id in RarityConfig.Order do
		total += RarityConfig.ById[id].Weight
	end
	for index, id in RarityConfig.Order do
		local definition = RarityConfig.ById[id]
		local y = 56 + (index - 1) * 21.5
		local function cell(text: string, x: number, width: number, align: Enum.TextXAlignment, color: Color3)
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Position = UDim2.new(x, 0, 0, y)
			label.Size = UDim2.new(width, 0, 0, 21)
			label.Font = Enum.Font.GothamBold
			label.TextSize = 17
			label.TextXAlignment = align
			label.TextColor3 = color
			label.Text = text
			label.Parent = gui
		end
		local nameColor = if definition.Hidden then definition.Accent else definition.Color
		cell("● " .. definition.Name, 0.05, 0.3, Enum.TextXAlignment.Left, nameColor)
		local percent = definition.Weight / total * 100
		local chance = if percent >= 1 then string.format("%.1f%%", percent) else string.format("1 in %s", tostring(math.floor(100 / percent + 0.5)))
		cell(chance, 0.36, 0.26, Enum.TextXAlignment.Right, Palette.Ink)
		cell(string.format("%g studs/s", definition.Speed), 0.64, 0.2, Enum.TextXAlignment.Right, Color3.fromRGB(120, 70, 40))
		cell(if definition.MinRebirth > 0 then "R" .. definition.MinRebirth else "", 0.87, 0.1, Enum.TextXAlignment.Right, Color3.fromRGB(190, 90, 60))
	end
	return model
end

local function buildRecentBoard(parent: Instance, cframe: CFrame): { TextLabel }
	local model = Build.model(parent, "RecentFinds")
	for _, side in { -1, 1 } do
		Build.part(model, "Post", Vector3.new(0.9, 10, 0.9), cframe * CFrame.new(side * 7.4, 5, 0.8), Palette.WoodDark, WOOD)
	end
	local board = Build.part(model, "Board", Vector3.new(16, 8.6, 0.8), cframe * CFrame.new(0, 6.2, 0.8), Palette.Ink, PLASTIC)
	Build.part(model, "Frame", Vector3.new(17, 9.6, 0.5), cframe * CFrame.new(0, 6.2, 1.2), Palette.WoodDark, WOOD, { CanCollide = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 32
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 46)
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 34
	title.TextColor3 = Palette.Gold
	title.Text = "✨ RECENT FINDS"
	title.Parent = gui

	local labels = {}
	for index = 1, 6 do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.new(0.05, 0, 0, 52 + (index - 1) * 33)
		label.Size = UDim2.new(0.9, 0, 0, 30)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 19
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Color3.fromRGB(200, 200, 215)
		label.RichText = true
		label.Text = "—"
		label.Parent = gui
		table.insert(labels, label)
	end
	return labels
end

local function buildFountain(parent: Instance): CFrame
	local model = Build.model(parent, "Fountain")
	Build.pillar(model, "Basin", 17, 1.4, CFrame.new(0, 0.7, 0), Palette.Stone, Enum.Material.Slate)
	Build.pillar(model, "BasinRim", 15.4, 1.6, CFrame.new(0, 0.8, 0), Palette.Pavement, Enum.Material.Marble, { CanCollide = false })
	local water = Build.pillar(model, "Water", 14.2, 1.3, CFrame.new(0, 0.85, 0), Palette.Water, Enum.Material.Glass, { CanCollide = false, Transparency = 0.2, Reflectance = 0.15 })
	water:SetAttribute("Ripple", true)
	Build.pillar(model, "Pedestal", 5.4, 3.4, CFrame.new(0, 2.2, 0), Palette.Pavement, Enum.Material.Marble)
	Build.pillar(model, "PedestalTop", 6.4, 0.6, CFrame.new(0, 4.2, 0), Palette.Gold, Enum.Material.Metal, { CanCollide = false })

	local jets = Build.deco(model, "Jets", Vector3.new(6, 1, 6), CFrame.new(0, 4.8, 0), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1, CanQuery = false })
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	spray.Color = ColorSequence.new(Color3.fromRGB(190, 232, 255))
	spray.LightEmission = 0.6
	spray.Rate = 22
	spray.Lifetime = NumberRange.new(1.2, 1.8)
	spray.Speed = NumberRange.new(9, 12)
	spray.SpreadAngle = Vector2.new(24, 24)
	spray.EmissionDirection = Enum.NormalId.Top
	spray.Acceleration = Vector3.new(0, -22, 0)
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0.2) })
	spray.Parent = jets
	jets:AddTag("AmbientParticles")
	Build.light(jets, Color3.fromRGB(150, 220, 255), 1, 22)

	-- statue anchor: a big golden hamster sits on top (see WorldBuilder)
	return CFrame.new(0, 4.5, 0) * CFrame.Angles(0, math.rad(-90), 0)
end

function PlazaBuilder.build(parent: Instance, rng: Random): PlazaInfo
	local folder = Build.folder(parent, "HamsterPlaza")

	-- concentric paving
	Build.pillar(folder, "PavingOuter", 68, 0.2, CFrame.new(0, 0.1, 0), Palette.Pavement, Enum.Material.Cobblestone)
	Build.pillar(folder, "PavingRing", 66, 0.22, CFrame.new(0, 0.11, 0), Palette.PavementDark, Enum.Material.Cobblestone, { CanCollide = false })
	Build.pillar(folder, "PavingInner", 64.4, 0.24, CFrame.new(0, 0.12, 0), Palette.Pavement, Enum.Material.Cobblestone, { CanCollide = false })
	Build.pillar(folder, "PavingCenter", 32, 0.26, CFrame.new(0, 0.13, 0), Palette.PavementDark, Enum.Material.Cobblestone, { CanCollide = false })
	Build.pillar(folder, "PavingCore", 30.4, 0.27, CFrame.new(0, 0.135, 0), Palette.Pavement, Enum.Material.Cobblestone, { CanCollide = false })

	local statueCFrame = buildFountain(folder)

	-- south arc buildings, all facing the fountain
	buildQuestBoard(folder, facingCenter(polar(32, 200)))
	buildStall(folder, "ShopStall", facingCenter(polar(31, 235)), "Shop", "🛍️", Palette.RoofColors[2], "Shop", "Browse")
	buildLibrary(folder, facingCenter(polar(32, 270)))
	buildGiftStand(folder, facingCenter(polar(31, 305)))
	buildStall(folder, "CodesStall", facingCenter(polar(31, 340)), "Promo Codes", "🎟️", Palette.RoofColors[5], "Codes", "Redeem")

	-- benches (watch the road), lamps and flowers
	for _, angle in { 40, 70, 110, 140 } do
		local position = polar(13.5, angle)
		Decor.bench(folder, CFrame.lookAt(position, position * 2))
	end
	for _, angle in { 217, 252, 288, 323 } do
		Decor.lamp(folder, polar(31, angle), 8)
	end
	for _, angle in { 20, 160, 200, 340 } do
		Decor.flowers(folder, polar(12, angle), 3.2, 14, rng)
	end
	Decor.flowers(folder, polar(11, 270), 4, 16, rng)
	Decor.flowers(folder, polar(11, 235), 3, 12, rng)
	Decor.flowers(folder, polar(11, 305), 3, 12, rng)
	for _, position in { Vector3.new(-37, 0, -4), Vector3.new(37, 0, -4) } do
		Decor.flag(folder, position, Palette.RoofColors[1])
	end
	for index, angle in { 250, 290, 215, 325 } do
		Decor.balloon(folder, polar(36, angle), Palette.RoofColors[index + 1])
	end

	-- north garden
	for index = -2, 2 do
		Decor.sunflower(folder, Vector3.new(index * 5.5, 0, 41 + math.abs(index) * 0.4), 0.9 + rng:NextNumber() * 0.2)
	end
	Decor.windmill(folder, Vector3.new(-64, 0, 38), math.rad(180))
	Decor.pond(folder, Vector3.new(62, 0, 38), 7, rng)
	Decor.fireflies(folder, Vector3.new(62, 0, 38), 9)
	Decor.fireflies(folder, Vector3.new(-30, 0, 34), 12)
	Decor.bench(folder, CFrame.new(50, 0, 29) * CFrame.Angles(0, math.rad(200), 0))
	Decor.bench(folder, CFrame.new(-50, 0, 29) * CFrame.Angles(0, math.rad(160), 0))
	for _, x in { -48, 48 } do
		Decor.lamp(folder, Vector3.new(x, 0, 36), 8)
	end
	Decor.tree(folder, Vector3.new(-42, 0, 44), "cherry", 1.1, rng)
	Decor.tree(folder, Vector3.new(42, 0, 46), "cherry", 1.1, rng)

	-- boards (north side of the plaza, facing the road and the fountain)
	buildRarityBoard(folder, CFrame.new(-19, 0, 42))
	local recentLabels = buildRecentBoard(folder, CFrame.new(19, 0, 42))
	Decor.signpost(folder, CFrame.new(0, 0, 41), "Collect hamsters as they run past!", Palette.Cream)

	-- guest spawn on the plaza (players without a house)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 0.7, -13)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Parent = folder

	return {
		Folder = folder,
		RecentLabels = recentLabels,
		StatueCFrame = statueCFrame,
	}
end

return PlazaBuilder
