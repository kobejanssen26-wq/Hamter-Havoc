--[[
	Hamster Plaza: the calm centre of the map. The hamster road runs straight through a large paved
	square with an inlaid sun pattern and under the golden-hamster arch (the landmark). North and south
	of the road two courtyards lead to the only two buildings that matter: the Shop and the Hamster
	Index. Four big trees in round planters, four benches and lamps; no signs beyond the two names.
	Everything is mirror-symmetric. Nothing stands on the road or the promenades (hamsters roll there).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldLayout = require(ReplicatedStorage.Modules.WorldLayout)

local Build = require(script.Parent.Build)
local Decor = require(script.Parent.Decor)
local Palette = require(script.Parent.Palette)

local PlazaBuilder = {}

local WOOD = Enum.Material.WoodPlanks
local PLASTIC = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

export type PlazaInfo = {
	Folder: Folder,
	RecentLabels: { TextLabel },
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

-- Small market stall. Customers stand at -Z; `cframe` is the ground point in front of the counter.
local function buildStall(parent: Instance, name: string, cframe: CFrame, title: string, icon: string, awning: Color3, opens: string, action: string)
	local model = Build.model(parent, name)
	Build.part(model, "Base", Vector3.new(11, 0.5, 8), cframe * CFrame.new(0, 0.25, 2.8), Palette.Stone, Enum.Material.Cobblestone)
	Build.part(model, "BackWall", Vector3.new(9.6, 7.4, 0.6), cframe * CFrame.new(0, 4.2, 6), Palette.Wall, PLASTIC)
	for _, side in { -1, 1 } do
		Build.part(model, "SideWall", Vector3.new(0.6, 7.4, 6), cframe * CFrame.new(side * 4.8, 4.2, 3), Palette.Wall, PLASTIC)
		Build.part(model, "Post", Vector3.new(0.8, 8.2, 0.8), cframe * CFrame.new(side * 4.9, 4.6, -0.2), Palette.WoodDark, WOOD)
		Build.blob(model, "Lantern", Vector3.new(0.9, 1.1, 0.9), cframe * CFrame.new(side * 4.9, 3.4, -0.9), Color3.fromRGB(255, 226, 150), NEON, { CanCollide = false })
	end
	local counter = Build.part(model, "Counter", Vector3.new(9.2, 2.6, 2.4), cframe * CFrame.new(0, 1.8, 0.4), Palette.WoodLight, WOOD)
	Build.part(model, "CounterTop", Vector3.new(9.8, 0.4, 3), cframe * CFrame.new(0, 3.3, 0.3), Palette.WoodDark, WOOD, { CanCollide = false })

	for index = 1, 5 do
		local color = if index % 2 == 0 then Palette.Cream else awning
		Build.part(model, "Awning", Vector3.new(2.1, 0.3, 6.4), cframe * CFrame.new(-4.2 + (index - 1) * 2.1, 8.1, 1.7) * CFrame.Angles(math.rad(-14), 0, 0), color, PLASTIC, { CanCollide = false })
	end

	local sign = Build.part(model, "Sign", Vector3.new(9, 2.4, 0.5), cframe * CFrame.new(0, 10.2, -1.3), Palette.WoodLight, WOOD, { CanCollide = false })
	Build.surfaceText(sign, Enum.NormalId.Front, string.upper(title), { TextColor = Palette.Ink, PixelsPerStud = 50 })
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
	Build.surfaceText(sign, Enum.NormalId.Front, "HAMSTER INDEX", { TextColor = Palette.Cream, PixelsPerStud = 50 })
	publicPrompt(lectern, "Hamster Index", "Open", "Index", 14)
end

local function buildRecentBoard(parent: Instance, cframe: CFrame): { TextLabel }
	local model = Build.model(parent, "RecentFinds")
	for _, side in { -1, 1 } do
		Build.part(model, "Post", Vector3.new(0.9, 9, 0.9), cframe * CFrame.new(side * 5.7, 4.5, 0.8), Palette.WoodDark, WOOD)
	end
	local board = Build.part(model, "Board", Vector3.new(12, 7.4, 0.8), cframe * CFrame.new(0, 5.6, 0.8), Palette.Ink, PLASTIC)
	Build.part(model, "Frame", Vector3.new(13, 8.4, 0.5), cframe * CFrame.new(0, 5.6, 1.2), Palette.WoodDark, WOOD, { CanCollide = false })
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 46)
	title.Font = Enum.Font.FredokaOne
	title.TextSize = 32
	title.TextColor3 = Palette.Gold
	title.Text = "RECENT FINDS"
	title.Parent = gui

	local labels = {}
	for index = 1, 6 do
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.new(0.05, 0, 0, 52 + (index - 1) * 32)
		label.Size = UDim2.new(0.9, 0, 0, 30)
		label.Font = Enum.Font.GothamBold
		label.TextSize = 16
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.TextColor3 = Color3.fromRGB(200, 200, 215)
		label.RichText = true
		label.Text = "—"
		label.Parent = gui
		table.insert(labels, label)
	end
	return labels
end

-- The arch over the road: two pillars, a beam with the plaza name and the golden king on top.
local function buildArch(parent: Instance): CFrame
	local model = Build.model(parent, "PlazaArch")
	local span = WorldLayout.RoadHalfWidth + 4
	for _, side in { -1, 1 } do
		Build.part(model, "Pillar", Vector3.new(4, 18, 4), CFrame.new(0, 9, side * span), Palette.Stone, Enum.Material.Slate)
		Build.part(model, "PillarBase", Vector3.new(5.6, 1.4, 5.6), CFrame.new(0, 0.7, side * span), Palette.StoneDark, Enum.Material.Slate)
		Build.part(model, "PillarCap", Vector3.new(5.2, 0.9, 5.2), CFrame.new(0, 18.45, side * span), Palette.Gold, Enum.Material.Metal, { CanCollide = false })
		Build.deco(model, "PillarLight", Vector3.new(0.4, 12, 0.4), CFrame.new(-2.05, 9, side * span), Color3.fromRGB(255, 226, 150), NEON)
		Build.deco(model, "PillarLight", Vector3.new(0.4, 12, 0.4), CFrame.new(2.05, 9, side * span), Color3.fromRGB(255, 226, 150), NEON)
	end
	local length = span * 2 + 4
	local beam = Build.part(model, "ArchBeam", Vector3.new(4.2, 3.2, length), CFrame.new(0, 20.2, 0), Palette.Cream, Enum.Material.Marble)
	Build.deco(model, "ArchTrim", Vector3.new(4.8, 0.5, length + 0.6), CFrame.new(0, 22, 0), Palette.Gold, Enum.Material.Metal)
	Build.deco(model, "ArchTrim", Vector3.new(4.8, 0.5, length + 0.6), CFrame.new(0, 18.4, 0), Palette.Gold, Enum.Material.Metal)
	for _, face in { Enum.NormalId.Right, Enum.NormalId.Left } do
		Build.surfaceText(beam, face, "HAMSTER PLAZA", { TextColor = Palette.WoodDark, PixelsPerStud = 40 })
	end
	Build.part(model, "StatuePlinth", Vector3.new(7, 1.2, 7), CFrame.new(0, 22.4, 0), Palette.Gold, Enum.Material.Metal)
	return CFrame.new(0, 23, 0) * CFrame.Angles(0, math.rad(90), 0)
end

-- Round planter with a big tree.
local function planterTree(parent: Instance, pos: Vector3, rng: Random)
	Build.pillar(parent, "Planter", 13, 1.4, CFrame.new(pos + Vector3.new(0, 0.7, 0)), Palette.Stone, Enum.Material.Slate)
	Build.pillar(parent, "PlanterSoil", 11.6, 0.2, CFrame.new(pos + Vector3.new(0, 1.42, 0)), Palette.GrassDark, Enum.Material.Grass, { CanCollide = false })
	Decor.largeTree(parent, pos + Vector3.new(0, 1.4, 0), 0.85, rng, Palette.Cherry)
end

function PlazaBuilder.build(parent: Instance, rng: Random): PlazaInfo
	local folder = Build.folder(parent, "HamsterPlaza")
	local radius = WorldLayout.PlazaHalfWidth

	-- the square: a big paved disc with a darker ring and an inlaid sun (the road lies on top of it)
	Build.pillar(folder, "PavingOuter", radius * 2 + 4, 0.22, CFrame.new(0, 0.11, 0), Palette.PavementDark, Enum.Material.Cobblestone)
	Build.pillar(folder, "PavingField", radius * 2, 0.24, CFrame.new(0, 0.12, 0), Palette.Pavement, Enum.Material.Cobblestone, { CanCollide = false })
	Build.pillar(folder, "PavingRing", radius * 1.25, 0.25, CFrame.new(0, 0.125, 0), Color3.fromRGB(236, 206, 150), Enum.Material.Cobblestone, { CanCollide = false })
	Build.pillar(folder, "PavingInner", radius * 1.1, 0.26, CFrame.new(0, 0.13, 0), Palette.Pavement, Enum.Material.Cobblestone, { CanCollide = false })
	for ray = 0, 15 do
		local angle = ray * math.pi / 8
		Build.deco(folder, "SunRay", Vector3.new(radius * 0.36, 0.05, 1.2), CFrame.new(math.cos(angle) * radius * 0.73, 0.27, math.sin(angle) * radius * 0.73) * CFrame.Angles(0, -angle, 0), Color3.fromRGB(236, 206, 150), Enum.Material.Cobblestone)
	end

	local statueCFrame = buildArch(folder)

	-- courtyards north and south of the promenades, each leading to one building
	local promenadeOuter = WorldLayout.PromenadeZ + WorldLayout.PromenadeHalfWidth
	local courtDepth = 34
	for _, sign in { 1, -1 } do
		local z = sign * (promenadeOuter + courtDepth / 2)
		Build.part(folder, "Courtyard", Vector3.new(radius * 2 - 6, 0.22, courtDepth), CFrame.new(0, 0.11, z), Palette.Pavement, Enum.Material.Cobblestone, { CanCollide = false })
		Build.deco(folder, "CourtyardEdge", Vector3.new(radius * 2 - 6, 0.26, 0.6), CFrame.new(0, 0.13, sign * (promenadeOuter + courtDepth - 0.3)), Palette.PavementDark, Enum.Material.Cobblestone)
		for _, x in { -1, 1 } do
			planterTree(folder, Vector3.new(x * (radius - 10), 0, sign * (promenadeOuter + 9)), rng)
			local facing = if sign > 0 then math.pi else 0
			Decor.bench(folder, CFrame.new(x * 9, 0, sign * (promenadeOuter + 6)) * CFrame.Angles(0, facing + math.pi, 0))
		end
		Decor.flowerBed(folder, CFrame.new(-radius + 9, 0, sign * (promenadeOuter + 24)), Vector2.new(6, 6), { Palette.Pink, Palette.Cream }, rng)
		Decor.flowerBed(folder, CFrame.new(radius - 9, 0, sign * (promenadeOuter + 24)), Vector2.new(6, 6), { Palette.Lavender, Palette.Cream }, rng)
	end
	local buildingZ = promenadeOuter + courtDepth - 6
	local north = CFrame.new(0, 0, buildingZ - 4)
	local south = CFrame.new(0, 0, -(buildingZ - 4)) * CFrame.Angles(0, math.pi, 0)
	buildStall(folder, "ShopStall", north, "Shop", "", Palette.RoofColors[2], "Shop", "Browse")
	buildLibrary(folder, south)

	-- recent finds board (the only board in the plaza), beside the library
	local recentLabels = buildRecentBoard(folder, CFrame.new(-15, 0, -(buildingZ - 2)) * CFrame.Angles(0, math.pi, 0))

	-- guest spawn on the plaza (players without a house)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 0.7, -(WorldLayout.PromenadeZ + WorldLayout.PromenadeHalfWidth + 12))
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
