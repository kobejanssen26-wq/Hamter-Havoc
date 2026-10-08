--[[
	Builds and manipulates placeholder hamster models (ball + hamster, wheel hamster, carried hamster).
	Models are purely visual; the truth about a hamster lives in DataService / HamsterFactory records.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Format = require(Shared.Util.Format)
local PartUtil = require(Shared.Util.PartUtil)
local VisualEffects = require(script.Parent.VisualEffects)

local HamsterModel = {}

local EYE_COLOR = Color3.fromRGB(15, 15, 15)
local PINK = Color3.fromRGB(255, 170, 180)

-- Rich text block: rarity (coloured), name, optional limited serial / price.
function HamsterModel.richDescription(hamster, includePrice: boolean): string
	local hex = Rarities.getAccentColor(hamster.Rarity):ToHex()
	local lines = {
		string.format('<font color="#%s"><b>%s</b></font>', hex, string.upper(hamster.Rarity)),
		hamster.Name,
	}
	if hamster.Mutation ~= "Normal" then
		table.insert(lines, hamster.Mutation)
	end
	if hamster.IsLimited and hamster.SerialNumber then
		table.insert(lines, string.format("LIMITED #%d", hamster.SerialNumber))
	end
	if includePrice then
		table.insert(lines, Format.money(hamster.PurchasePrice))
	end
	return table.concat(lines, "\n")
end

-- Floating text above a part. Returns the TextLabel so callers can update it.
function HamsterModel.createBillboard(parent: BasePart, richText: string, worldOffset: Vector3, pixelSize: Vector2?): TextLabel
	local size = pixelSize or Vector2.new(240, 90)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(size.X, size.Y)
	gui.StudsOffsetWorldSpace = worldOffset
	gui.MaxDistance = 160
	gui.AlwaysOnTop = false

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.RichText = true
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.35
	label.Text = richText
	label.Parent = gui

	gui.Parent = parent
	return label
end

-- Simple placeholder hamster. Body is the PrimaryPart and the only anchored part;
-- everything else is welded to it.
function HamsterModel.build(hamster, cframe: CFrame): Model
	local fur = Rarities.Definitions[hamster.Rarity].VisualEffect.FurColor
	local scale = hamster.Size

	local model = Instance.new("Model")
	model.Name = "Hamster"
	model:SetAttribute("UniqueId", hamster.UniqueId)

	local function makePart(name: string, diameter: number, x: number, y: number, z: number, color: Color3): Part
		return PartUtil.create(name, Vector3.one * diameter * scale, cframe * CFrame.new(x * scale, y * scale, z * scale), {
			Shape = Enum.PartType.Ball,
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CanTouch = false,
			Massless = true,
		})
	end

	local body = makePart("Body", 2.4, 0, 0, 0, fur)
	local extras = {
		makePart("Head", 1.7, 0, 0.5, -1.15, fur),
		makePart("EyeLeft", 0.32, -0.45, 0.95, -1.9, EYE_COLOR),
		makePart("EyeRight", 0.32, 0.45, 0.95, -1.9, EYE_COLOR),
		makePart("Nose", 0.28, 0, 0.55, -1.98, PINK),
		makePart("EarLeft", 0.8, -0.6, 1.35, -0.95, PINK),
		makePart("EarRight", 0.8, 0.6, 1.35, -0.95, PINK),
	}
	for _, part in extras do
		PartUtil.weld(part, body)
		part.Parent = model
	end
	body.Parent = model
	model.PrimaryPart = body
	return model
end

-- Rolling ball with a hamster inside. Returns (model, carrier, hull).
-- Carrier = invisible centre part that moves along the route; Hull = glass sphere that rolls.
function HamsterModel.buildBall(hamster, cframe: CFrame): (Model, Part, Part)
	local diameter = GameConfig.Route.BallDiameter
	local radius = diameter / 2

	local model = Instance.new("Model")
	model.Name = "HamsterBall"
	model:SetAttribute("UniqueId", hamster.UniqueId)
	model:SetAttribute("Rarity", hamster.Rarity)

	local carrier = PartUtil.create("Carrier", Vector3.one, cframe, {
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})

	local hull = PartUtil.create("Hull", Vector3.one * diameter, cframe, {
		Shape = Enum.PartType.Ball,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})

	-- Stripe makes the rolling visible; it is welded to (and rolls with) the hull.
	local stripe = PartUtil.create("Stripe", Vector3.new(0.3, diameter + 0.1, diameter + 0.1), cframe * CFrame.Angles(0, math.pi / 2, 0), {
		Shape = Enum.PartType.Cylinder,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Massless = true,
	})
	PartUtil.weld(stripe, hull)

	local hamsterModel = HamsterModel.build(hamster, cframe * CFrame.new(0, -radius + 1.3 * hamster.Size, 0))
	PartUtil.weld(hamsterModel.PrimaryPart, carrier)

	carrier.Parent = model
	hull.Parent = model
	stripe.Parent = model
	hamsterModel.Parent = model
	model.PrimaryPart = carrier

	VisualEffects.applyToBall(model, carrier, hull, stripe, hamster.Rarity)
	return model, carrier, hull
end

-- Anchors the hamster at `cframe` (used when it enters a wheel).
function HamsterModel.placeAt(model: Model, cframe: CFrame)
	local body = model.PrimaryPart :: BasePart
	local carryWeld = body:FindFirstChild("CarryWeld")
	if carryWeld then
		carryWeld:Destroy()
	end
	body.Anchored = true
	model:PivotTo(cframe)
end

-- The hamster rides on the thief's back until it is delivered or returned.
function HamsterModel.attachToCharacter(model: Model, character: Model): boolean
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local body = model.PrimaryPart :: BasePart
	if not root then
		return false
	end
	body.Anchored = true
	model:PivotTo(root.CFrame * CFrame.new(GameConfig.Stealing.CarryOffset))
	model.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Name = "CarryWeld"
	weld.Part0 = root
	weld.Part1 = body
	weld.Parent = body
	body.Anchored = false
	return true
end

function HamsterModel.addStealPrompt(model: Model, hamster, onTriggered: (Player, string) -> ())
	local body = model.PrimaryPart :: BasePart
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ObjectText = string.upper(hamster.Rarity) .. " " .. hamster.Name
	prompt.ActionText = "STEAL"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 1
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", hamster.OwnerUserId)
	prompt:AddTag("StealPrompt") -- clients hide it for the owner
	prompt.Triggered:Connect(function(player)
		onTriggered(player, hamster.UniqueId)
	end)
	prompt.Parent = body
end

function HamsterModel.removeStealPrompt(model: Model)
	local body = model.PrimaryPart
	local prompt = body and body:FindFirstChild("StealPrompt")
	if prompt then
		prompt:Destroy()
	end
end

return HamsterModel
