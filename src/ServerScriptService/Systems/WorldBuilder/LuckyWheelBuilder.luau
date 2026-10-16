--[[
	LuckyWheelBuilder: the physical Lucky Wheel in the plaza (on its own platform in the green area behind the Coins Shop and Robux Shop, facing the hamster road).

	  LuckyWheel (Model, tag "LuckyWheel")
	    Base, trim, back pillar + two struts, axle, pointer, sign, bulbs    fixed
	    Rotor (Model, PrimaryPart Hub)                                        turns: backplate, rim, one coloured slice per prize
	    PromptPad                                                             invisible pad with the [F] prompt (opens the wheel window)

	The slices come from SpinWheelConfig.Prizes (same list, same order as the window and the server draw), so adding a prize
	adds a slice. The wheel never decides anything: SpinSystem draws, WheelWorld tells every client where to stop.
	Geometry: the wheel plane faces -Z (the road). Slice i sits i * 360 / count degrees clockwise (seen from the road) from the top.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Build = require(script.Parent.Build)
local Palette = require(script.Parent.Palette)
local SpinWheelConfig = require(ReplicatedStorage.Modules.SpinWheelConfig)

local LuckyWheelBuilder = {}

local PLASTIC = Enum.Material.SmoothPlastic
local WOOD = Enum.Material.WoodPlanks
local METAL = Enum.Material.Metal
local NEON = Enum.Material.Neon

LuckyWheelBuilder.CENTER = Vector3.new(0, 0, 80) -- ground point under the wheel
local RADIUS = 5.6
local HUB_HEIGHT = 8.4

local function ofCylinder(parent: Instance, name: string, diameter: number, thickness: number, cframe: CFrame, color: Color3, material: Enum.Material, props: { [string]: any }?): Part
	-- a cylinder lying along the Z axis (a wheel disc): length = thickness
	local merged: { [string]: any } = {}
	merged.Shape = Enum.PartType.Cylinder
	if props then
		for key, value in props do
			merged[key] = value
		end
	end
	return Build.part(parent, name, Vector3.new(thickness, diameter, diameter), cframe * CFrame.Angles(0, math.rad(90), 0), color, material, merged)
end

function LuckyWheelBuilder.build(parent: Instance, rng: Random): Model
	local model = Build.model(parent, "LuckyWheel")
	model:AddTag("LuckyWheel")
	local center = LuckyWheelBuilder.CENTER
	local hub = CFrame.new(center.X, HUB_HEIGHT, center.Z)
	local prizes = SpinWheelConfig.Prizes
	local count = #prizes
	model:SetAttribute("Slices", count)
	model:SetAttribute("Angle", 0)

	-- platform: round, stone, golden trim, one low step so it reads as a stage
	Build.pillar(model, "Base", 13, 0.7, CFrame.new(center.X, 0.35, center.Z), Palette.Stone, Enum.Material.Slate)
	Build.pillar(model, "BaseTrim", 13.8, 0.3, CFrame.new(center.X, 0.7, center.Z), Palette.Gold, METAL, { CanCollide = false })
	Build.pillar(model, "BaseTop", 11.8, 0.12, CFrame.new(center.X, 0.93, center.Z), Palette.Cream, Enum.Material.Marble, { CanCollide = false })

	-- stand: a back pillar behind the wheel, braced by two struts, holding the axle
	local backZ = center.Z + 1.7
	local signY = HUB_HEIGHT + RADIUS + 3.2
	Build.part(model, "BackPillar", Vector3.new(1.5, signY - 0.7, 1.5), CFrame.new(center.X, 0.7 + (signY - 0.7) / 2, backZ), Palette.WoodDark, WOOD)
	for _, side in { -1, 1 } do
		-- strut from the platform (x = side * 3.4) up to the pillar (height 4.2)
		local from = Vector3.new(center.X + side * 3.4, 0.7, backZ)
		local to = Vector3.new(center.X + side * 0.4, 4.4, backZ)
		local mid = (from + to) / 2
		local length = (to - from).Magnitude
		Build.part(model, "Strut", Vector3.new(0.9, length + 0.3, 0.9), CFrame.lookAt(mid, to) * CFrame.Angles(math.rad(90), 0, 0), Palette.Wood, WOOD)
	end
	Build.part(model, "AxleBlock", Vector3.new(2.6, 2.6, 1.6), CFrame.new(center.X, HUB_HEIGHT, backZ - 0.2), Palette.WoodDark, WOOD)
	ofCylinder(model, "Axle", 0.9, 3.6, hub * CFrame.new(0, 0, 0.1), Palette.Gold, METAL, { CanCollide = false })

	-- the rotating wheel
	local rotor = Build.model(model, "Rotor")
	local hubPart = ofCylinder(rotor, "Hub", 1.8, 0.9, hub * CFrame.new(0, 0, -0.55), Palette.Gold, METAL, { CanCollide = false })
	rotor.PrimaryPart = hubPart
	ofCylinder(rotor, "Rim", RADIUS * 2 + 1.5, 0.9, hub * CFrame.new(0, 0, 0.1), Palette.Gold, METAL, { CanCollide = false })
	ofCylinder(rotor, "Backplate", RADIUS * 2 + 0.5, 0.7, hub * CFrame.new(0, 0, -0.05), Palette.WoodDark, WOOD, { CanCollide = false })
	local innerRadius, outerRadius = RADIUS * 0.2, RADIUS - 0.2
	local middle = (innerRadius + outerRadius) / 2
	local sliceLength = outerRadius - innerRadius
	local sliceWidth = 2 * middle * math.tan(math.pi / count) * 0.94
	for index, prize in prizes do
		local theta = math.rad((index - 1) * 360 / count)
		local direction = Vector3.new(-math.sin(theta), math.cos(theta), 0)
		local slice = Build.part(rotor, "Slice_" .. prize.Id, Vector3.new(sliceWidth, sliceLength, 0.3), hub * CFrame.new(direction * middle + Vector3.new(0, 0, -0.45)) * CFrame.Angles(0, 0, theta), prize.Color, PLASTIC, { CanCollide = false })
		Build.surfaceText(slice, Enum.NormalId.Front, prize.Short or prize.Label, { TextColor = Palette.Ink, PixelsPerStud = 60, Font = Enum.Font.FredokaOne })
		-- peg between two slices
		local pegAngle = theta + math.pi / count
		local peg = Vector3.new(-math.sin(pegAngle), math.cos(pegAngle), 0) * (outerRadius + 0.05)
		Build.blob(rotor, "Peg", Vector3.new(0.5, 0.5, 0.5), hub * CFrame.new(peg + Vector3.new(0, 0, -0.55)), Palette.Gold, METAL, { CanCollide = false })
	end
	model:SetAttribute("BaseCFrame", hub) -- the rotor's resting pivot (the server / clients rotate relative to it)

	-- pointer at the top (fixed): a red diamond pointing down onto the slice under it
	Build.part(model, "Pointer", Vector3.new(1.2, 1.2, 0.6), hub * CFrame.new(0, RADIUS + 0.55, -0.7) * CFrame.Angles(0, 0, math.rad(45)), Color3.fromRGB(235, 64, 72), PLASTIC, { CanCollide = false })
	Build.deco(model, "PointerGem", Vector3.new(0.5, 0.5, 0.3), hub * CFrame.new(0, RADIUS + 0.55, -1.1) * CFrame.Angles(0, 0, math.rad(45)), Palette.Gold, METAL)

	-- bulbs round the rim (neon), fixed to the stand so they stay still while the wheel turns
	local bulbs = 20
	for index = 1, bulbs do
		local angle = (index - 1) * 2 * math.pi / bulbs
		local at = Vector3.new(math.sin(angle), math.cos(angle), 0) * (RADIUS + 1.05)
		Build.blob(model, "Bulb", Vector3.new(0.45, 0.45, 0.45), hub * CFrame.new(at + Vector3.new(0, 0, -0.55)), if index % 2 == 0 then Color3.fromRGB(255, 236, 160) else Color3.fromRGB(255, 120, 150), NEON, { CanCollide = false })
	end
	local glow = Build.deco(model, "WheelGlow", Vector3.new(1, 1, 1), hub * CFrame.new(0, 0, -2), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1, CanQuery = false })
	Build.light(glow, Color3.fromRGB(255, 230, 170), 1.2, 26)

	-- sign above the wheel with a status line that every client fills in for itself (free spin ready / countdown)
	local sign = Build.part(model, "Sign", Vector3.new(10, 2.2, 0.5), CFrame.new(center.X, signY, backZ - 1.1), Palette.WoodDark, WOOD, { CanCollide = false })
	Build.surfaceText(sign, Enum.NormalId.Front, "LUCKY WHEEL", { TextColor = Palette.Gold, PixelsPerStud = 50 })
	local status = Build.billboard(sign, "FREE SPIN!", Vector2.new(190, 38), Vector3.new(0, 2.1, -0.6), { MaxDistance = 70, Name = "WheelStatus", TextColor = Color3.fromRGB(110, 255, 140) })
	status.Name = "Status"

	-- the interaction: a pad in front of the platform (any player may spin; the SERVER decides everything)
	local pad = Build.deco(model, "PromptPad", Vector3.new(6, 1, 3), CFrame.new(center.X, 1.2, center.Z - 5.5), Color3.new(1, 1, 1), PLASTIC, { Transparency = 1, CanQuery = false })
	local prompt = Instance.new("ProximityPrompt")
	prompt.ObjectText = "Lucky Wheel"
	prompt.ActionText = "Spin"
	prompt.KeyboardKeyCode = Enum.KeyCode.F
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt:SetAttribute("OpenUI", "Wheel")
	prompt.Parent = pad
	Build.target(pad, "Wheel") -- the tutorial points here

	return model
end

return LuckyWheelBuilder
