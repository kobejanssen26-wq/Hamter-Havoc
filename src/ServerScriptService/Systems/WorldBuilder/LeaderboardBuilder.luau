--[[
	LeaderboardBuilder: the Leaderboard Hall. Three boards (Most Hamsters / Most Steals / Most Money) on a small paved
	square behind the plaza fountain, away from the hamster road, the promenades and every base. A kiosk in the middle opens
	the full leaderboard screen. The boards are plain SurfaceGuis; LeaderboardService fills in the texts.
]]

local Build = require(script.Parent.Build)
local Decor = require(script.Parent.Decor)
local Palette = require(script.Parent.Palette)

local LeaderboardBuilder = {}

local PLASTIC = Enum.Material.SmoothPlastic
local WOOD = Enum.Material.WoodPlanks
local NEON = Enum.Material.Neon

export type Board = { Metric: string, Title: TextLabel, Period: TextLabel, Rows: { TextLabel }, Footer: TextLabel }

local CENTER = Vector3.new(0, 0, -104) -- behind the plaza fountain (plaza gap, south), nothing else is built here
local RADIUS = 19
local ROWS = 10

local function label(parent: Instance, props: { [string]: any }): TextLabel
	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.RichText = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.TextColor3 = Color3.new(1, 1, 1)
	for key, value in props do
		(textLabel :: any)[key] = value
	end
	textLabel.Parent = parent
	return textLabel
end

local function buildBoard(parent: Instance, metric: string, title: string, cframe: CFrame): Board
	local model = Build.model(parent, "Board_" .. metric)
	for _, side in { -1, 1 } do
		Build.part(model, "Post", Vector3.new(0.9, 12, 0.9), cframe * CFrame.new(side * 7.4, 6, 0.9), Palette.WoodDark, WOOD)
	end
	local board = Build.part(model, "Screen", Vector3.new(15, 10, 0.8), cframe * CFrame.new(0, 7.4, 0.9), Color3.fromRGB(24, 26, 44), PLASTIC)
	Build.deco(model, "Frame", Vector3.new(16, 11, 0.5), cframe * CFrame.new(0, 7.4, 1.3), Palette.WoodDark, WOOD)
	Build.deco(model, "Glow", Vector3.new(15.6, 0.3, 0.5), cframe * CFrame.new(0, 12.8, 0.7), Palette.Gold, NEON)

	local gui = Instance.new("SurfaceGui")
	gui.Name = "BoardGui"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.MaxDistance = 90
	gui.Parent = board

	local titleLabel = label(gui, { Size = UDim2.new(1, 0, 0, 58), Font = Enum.Font.GothamBlack, TextSize = 36, TextColor3 = Palette.Gold, Text = string.upper(title) })
	local periodLabel = label(gui, { Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 28), TextSize = 18, TextColor3 = Color3.fromRGB(165, 171, 205), Text = "" })
	local rows = {}
	for index = 1, ROWS do
		local row = label(gui, {
			Position = UDim2.new(0.05, 0, 0, 92 + (index - 1) * 29),
			Size = UDim2.new(0.9, 0, 0, 27),
			TextSize = 20,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = "",
		})
		table.insert(rows, row)
	end
	local footer = label(gui, { Position = UDim2.new(0, 0, 1, -26), Size = UDim2.new(1, 0, 0, 22), TextSize = 14, TextColor3 = Color3.fromRGB(120, 126, 160), Text = "Loading..." })
	return { Metric = metric, Title = titleLabel, Period = periodLabel, Rows = rows, Footer = footer }
end

function LeaderboardBuilder.build(parent: Instance, rng: Random): { Folder: Folder, Boards: { Board } }
	local folder = Build.folder(parent, "LeaderboardHall")

	-- paved square (dead end: nothing rolls or walks through here)
	Build.pillar(folder, "HallPaving", 56, 0.22, CFrame.new(CENTER.X, 0.11, CENTER.Z), Palette.Pavement, Enum.Material.Cobblestone)
	Build.pillar(folder, "HallRing", 48, 0.24, CFrame.new(CENTER.X, 0.12, CENTER.Z), Palette.PavementDark, Enum.Material.Cobblestone, { CanCollide = false })
	Build.part(folder, "HallPath", Vector3.new(10, 0.2, 38), CFrame.new(CENTER.X, 0.12, CENTER.Z + 33), Palette.Pavement, Enum.Material.Cobblestone, { CanCollide = false })

	local boards: { Board } = {}
	local specs = { { "Hamsters", "Most Hamsters", -58 }, { "Steals", "Most Steals", 0 }, { "Money", "Most Money", 58 } }
	for _, spec in specs do
		local angle = math.rad(spec[3])
		local position = CENTER + Vector3.new(math.sin(angle) * RADIUS, 0, -math.cos(angle) * RADIUS)
		boards[#boards + 1] = buildBoard(folder, spec[1], spec[2], CFrame.lookAt(position, Vector3.new(CENTER.X, position.Y, CENTER.Z))) -- the front of the screen faces the square
	end

	-- kiosk with a golden trophy: opens the full leaderboard screen
	local plinth = Build.pillar(folder, "KioskBase", 5, 1.2, CFrame.new(CENTER.X, 0.6, CENTER.Z), Palette.Cream, Enum.Material.Marble)
	Build.pillar(folder, "KioskCup", 1.6, 2.4, CFrame.new(CENTER.X, 2.4, CENTER.Z), Palette.Gold, Enum.Material.Metal, { CanCollide = false })
	Build.blob(folder, "KioskBowl", Vector3.new(3, 1.6, 3), CFrame.new(CENTER.X, 4.1, CENTER.Z), Palette.Gold, Enum.Material.Metal, { CanCollide = false })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Leaderboards"
	prompt.ActionText = "Open"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt:SetAttribute("OpenUI", "Leaderboards")
	prompt.Parent = plinth
	Build.target(plinth, "Leaderboard")

	local sign = Build.part(folder, "HallSign", Vector3.new(16, 2.6, 0.6), CFrame.new(CENTER.X, 3.4, CENTER.Z + 40) * CFrame.Angles(0, math.pi, 0), Palette.WoodDark, WOOD, { CanCollide = false })
	Build.surfaceText(sign, Enum.NormalId.Front, "LEADERBOARDS", { TextColor = Palette.Cream, PixelsPerStud = 50 })
	for _, x in { -22, 22 } do
		Decor.lamp(folder, Vector3.new(CENTER.X + x, 0, CENTER.Z + 10), 8)
	end
	Decor.bench(folder, CFrame.new(CENTER.X - 8, 0, CENTER.Z + 8))
	Decor.bench(folder, CFrame.new(CENTER.X + 8, 0, CENTER.Z + 8))
	Decor.flowers(folder, Vector3.new(CENTER.X - 14, 0, CENTER.Z + 26), 3, 10, rng)
	Decor.flowers(folder, Vector3.new(CENTER.X + 14, 0, CENTER.Z + 26), 3, 10, rng)
	return { Folder = folder, Boards = boards }
end

return LeaderboardBuilder
