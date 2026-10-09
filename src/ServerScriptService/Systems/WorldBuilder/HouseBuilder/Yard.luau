--[[
	The front yard and gate of an apartment lot (local frame: origin = middle of the gate line, +Z into the lot).
	Calm on purpose: a hedge ring, a wide driveway, one flower bed, a tree, a bench, a lamp, a mailbox, the name sign,
	the rebirth altar, the backyard pond - and the modern security portal (pylons, laser beams, panel).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Parent.Build)
local Decor = require(script.Parent.Parent.Decor)
local Palette = require(script.Parent.Parent.Palette)

local SecurityConfig = require(ReplicatedStorage.Modules.SecurityConfig)
local WorldLayout = require(ReplicatedStorage.Modules.WorldLayout)

local Yard = {}

local PLASTIC = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon
local METAL = Enum.Material.Metal
local WOOD = Enum.Material.WoodPlanks
local FRAME = Color3.fromRGB(58, 52, 66)

local function makePrompt(parent: BasePart, objectText: string, actionText: string, opens: string, distance: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = objectText
	prompt.ActionText = actionText
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = distance
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt:SetAttribute("OpenUI", opens)
	prompt:SetAttribute("OwnerUserId", 0)
	prompt:AddTag("OwnerOnlyPrompt")
	prompt.Parent = parent
	return prompt
end

function Yard.build(house: any, rng: Random)
	local cframe: CFrame = house.CFrame
	local yard = Build.model(house.Model, "Yard")
	local function L(x: number, y: number, z: number): CFrame
		return cframe * CFrame.new(x, y, z)
	end
	local function P(x: number, z: number): Vector3
		return (cframe * CFrame.new(x, 0, z)).Position
	end
	local half = WorldLayout.LotHalfWidth
	local depth = WorldLayout.LotDepth

	-- lawn, driveway, gate apron
	Build.part(yard, "Lawn", Vector3.new(half * 2, 0.1, depth), L(0, 0.02, depth / 2), Palette.GrassLight, Enum.Material.Grass, { CanCollide = false })
	Build.part(yard, "Driveway", Vector3.new(10.4, 0.14, WorldLayout.TowerFront + 0.5), L(0, 0.07, WorldLayout.TowerFront / 2), Palette.Pavement, Enum.Material.Cobblestone, { CanCollide = false })
	for _, side in { -1, 1 } do
		Build.deco(yard, "DrivewayEdge", Vector3.new(0.5, 0.18, WorldLayout.TowerFront), L(side * 5.45, 0.09, WorldLayout.TowerFront / 2), Palette.PavementDark, Enum.Material.Cobblestone)
	end
	Build.part(yard, "GateApron", Vector3.new(18, 0.14, 5), L(0, 0.07, 0), Palette.PavementDark, Enum.Material.Cobblestone, { CanCollide = false })

	-- boundary: low hedge all around; the gate side has a low wall with a wide opening
	Decor.hedgeRun(yard, P(-half + 0.5, 4), P(-half + 0.5, depth - 0.5), rng)
	Decor.hedgeRun(yard, P(half - 0.5, 4), P(half - 0.5, depth - 0.5), rng)
	Decor.hedgeRun(yard, P(-half + 0.5, depth - 0.5), P(half - 0.5, depth - 0.5), rng)
	Decor.fenceRun(yard, P(-half + 0.5, 0), P(-9, 0), { Color = Palette.Cream })
	Decor.fenceRun(yard, P(9, 0), P(half - 0.5, 0), { Color = Palette.Cream })

	-----------------------------------------------------------------------
	-- security portal: two lit pylons, a crossbeam, laser beams, a field
	-----------------------------------------------------------------------
	local lamps: { BasePart } = {}
	for _, side in { -1, 1 } do
		Build.part(yard, "GatePylon", Vector3.new(1.8, 8, 1.8), L(side * 7.4, 4, 0), FRAME, PLASTIC)
		Build.deco(yard, "GatePylonStripe", Vector3.new(0.3, 7, 1.9), L(side * 7.4, 4, 0), Color3.fromRGB(120, 130, 150), METAL)
		table.insert(lamps, Build.blob(yard, "GateLamp", Vector3.new(1.3, 1.3, 1.3), L(side * 7.4, 8.6, 0), Color3.fromRGB(110, 230, 140), NEON, { CanCollide = false }))
	end
	Build.deco(yard, "GateBeam", Vector3.new(16.6, 0.9, 1.2), L(0, 7.6, 0), FRAME, PLASTIC)
	Build.deco(yard, "GateBeamStripe", Vector3.new(16.6, 0.2, 1.3), L(0, 7.2, 0), Color3.fromRGB(150, 160, 185), METAL)
	local beams: { BasePart } = {}
	for beam = 1, SecurityConfig.MaxBeams do
		table.insert(beams, Build.deco(yard, "LaserBeam", Vector3.new(13, 0.2, 0.2), L(0, 0.7 + beam * 1.15, 0), Color3.fromRGB(255, 96, 96), NEON, { Shape = Enum.PartType.Cylinder, Transparency = 1 }))
	end
	local field = Build.deco(yard, "SecurityField", Vector3.new(13, 6.6, 0.12), L(0, 3.9, 0), Color3.fromRGB(255, 96, 96), NEON, { Transparency = 1 })
	local anchor = Build.deco(yard, "SecurityAnchor", Vector3.one * 0.3, L(0, 11, 0), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1, CanQuery = false })

	-- security panel just inside the gate: shows the state, F/E there switches the gate back on
	Build.pillar(yard, "PanelBase", 2.2, 0.6, L(11.5, 0.3, 4), FRAME, PLASTIC)
	local panel = Build.part(yard, "SecurityPanel", Vector3.new(2.6, 3.4, 1), L(11.5, 2.3, 4), Palette.Cream, PLASTIC)
	local screen = Build.deco(yard, "PanelScreen", Vector3.new(2.1, 1.5, 0.12), L(11.5, 3.1, 3.46), FRAME, PLASTIC)
	local screenLabel = Build.surfaceText(screen, Enum.NormalId.Front, "SECURE", { TextColor = Color3.fromRGB(110, 230, 140), PixelsPerStud = 50 })
	local pylonLamp = Build.blob(yard, "PanelLamp", Vector3.new(1.1, 0.8, 0.8), L(11.5, 1.7, 3.4), Color3.fromRGB(110, 230, 140), NEON, { CanCollide = false })
	local securityPrompt = Instance.new("ProximityPrompt")
	securityPrompt.ObjectText = "Security Panel"
	securityPrompt.ActionText = "Reactivate Security"
	securityPrompt.KeyboardKeyCode = Enum.KeyCode.E
	securityPrompt.HoldDuration = 0
	securityPrompt.MaxActivationDistance = 9
	securityPrompt.RequiresLineOfSight = false
	securityPrompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	securityPrompt.Enabled = false
	securityPrompt:SetAttribute("SecurityHouse", house.Index)
	securityPrompt.Parent = panel
	house.Security = { Beams = beams, Field = field, Lamps = lamps, PylonLamp = pylonLamp, Prompt = securityPrompt, Anchor = anchor, Screen = screenLabel }

	-----------------------------------------------------------------------
	-- rebirth altar, mailbox, name sign
	-----------------------------------------------------------------------
	Build.pillar(yard, "AltarBase", 4.6, 0.7, L(19, 0.35, 12), Palette.Stone, Enum.Material.Cobblestone)
	local altar = Build.pillar(yard, "AltarPillar", 2.4, 1.8, L(19, 1.6, 12), Palette.Cream, PLASTIC)
	Build.pillar(yard, "AltarCap", 3, 0.3, L(19, 2.65, 12), Palette.Gold, METAL, { CanCollide = false })
	local orb = Build.blob(yard, "AltarOrb", Vector3.one * 1.6, L(19, 4.1, 12), Color3.fromRGB(255, 130, 60), NEON, { CanCollide = false })
	Build.light(orb, Color3.fromRGB(255, 150, 80), 1, 16)
	Build.animate(orb, "Bob", { Amplitude = 0.35, Speed = 1.6 })
	house.Prompts.Rebirth = makePrompt(altar, "Rebirth Altar", "Rebirth", "Rebirth", 11)

	Build.part(yard, "MailPost", Vector3.new(0.5, 3.4, 0.5), L(-12, 1.7, 3.6), Palette.WoodDark, WOOD)
	local mailbox = Build.blob(yard, "Mailbox", Vector3.new(2.6, 1.8, 1.8), L(-12, 3.7, 3.6), Color3.fromRGB(100, 170, 255), PLASTIC)
	Build.deco(yard, "MailFlag", Vector3.new(0.2, 1.1, 0.5), L(-13.3, 4.1, 3.6), Color3.fromRGB(255, 90, 90), PLASTIC)
	house.Prompts.Mailbox = makePrompt(mailbox, "Mailbox", "Daily Gift", "Daily", 10)

	for _, x in { -27, -17 } do
		Build.part(yard, "SignPost", Vector3.new(0.6, 5.2, 0.6), L(x, 2.6, 3), Palette.WoodDark, WOOD)
	end
	local board = Build.part(yard, "SignBoard", Vector3.new(11.2, 4.2, 0.5), L(-22, 4, 3), Palette.WoodLight, WOOD, { CanCollide = false })
	local signGui = Instance.new("SurfaceGui")
	signGui.Face = Enum.NormalId.Front
	signGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	signGui.PixelsPerStud = 60
	signGui.Parent = board
	local function signLine(name: string, y: number, h: number, font: Enum.Font, color: Color3): TextLabel
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.04, y)
		label.Size = UDim2.fromScale(0.92, h)
		label.TextScaled = true
		label.RichText = true
		label.Font = font
		label.TextColor3 = color
		label.Text = ""
		label.Parent = signGui
		return label
	end
	house.Labels.Name = signLine("Name", 0.04, 0.38, Enum.Font.FredokaOne, Palette.Ink)
	house.Labels.Stats = signLine("Stats", 0.44, 0.26, Enum.Font.GothamBold, Color3.fromRGB(120, 70, 40))
	house.Labels.Best = signLine("Best", 0.72, 0.24, Enum.Font.GothamMedium, Color3.fromRGB(120, 70, 40))

	-----------------------------------------------------------------------
	-- a calm garden
	-----------------------------------------------------------------------
	Decor.tree(yard, P(-26, 14), if house.Index % 2 == 0 then "cherry" else "round", 1.1, rng)
	Decor.tree(yard, P(27, 24), "round", 1.1, rng)
	Decor.tree(yard, P(-27, 62), "pine", 1.1, rng)
	Decor.tree(yard, P(27, 62), "round", 1.2, rng)
	Decor.flowers(yard, P(-16, 14), 3.5, 12, rng)
	Decor.bench(yard, cframe * CFrame.new(16, 0, 19) * CFrame.Angles(0, math.pi, 0))
	Decor.lamp(yard, P(-7, 10), 7)
	Decor.lamp(yard, P(7, 10), 7)
	-- backyard pond behind the tower
	Decor.pond(yard, P(0, 79), 4.5, rng)
end

return Yard
