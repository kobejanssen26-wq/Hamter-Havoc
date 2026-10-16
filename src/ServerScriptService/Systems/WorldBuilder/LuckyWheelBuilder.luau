--[[
	LuckyWheelBuilder: the physical Lucky Wheel (on its own platform in the green area behind the Coins Shop and Robux Shop, facing the hamster road).

	  LuckyWheel (Model, tag "LuckyWheel")
	    Base, trim, back pillar + two struts, axle, FIXED pointer, sign, bulbs   fixed
	    Rotor (Model, PrimaryPart Hub)                                           turns: backplate, rim, gold dividers and one Slice_<prize> model per prize
	      Slice_<prize> (Model)  two wedge facets in the prize colour + IconPlate (an invisible plate with a SurfaceGui "PrizeIcon")
	    PromptPad                                                                invisible pad with the [F] prompt (attribute SpinWheel = true)

	The slices come from SpinWheelConfig.Prizes (same list, same order as the server draw), so adding a prize adds a slice. A slice shows a
	PICTURE: the client (WheelWorldController) draws the prize Icon (or the Image you set in SpinWheelConfig) on the IconPlate. Only the
	exported standalone model, which has no client, gets a short word instead (options.TextFallback). The wheel never decides anything:
	SpinSystem draws, WheelWorld tells every client where to stop.
	Geometry: the wheel plane faces -Z (the road). Slice i sits (i-1) * 360 / count degrees clockwise (seen from the road) from the top.
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

function LuckyWheelBuilder.build(parent: Instance, rng: Random, options: { TextFallback: boolean? }?): Model
	local textFallback = options ~= nil and options.TextFallback == true
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
	local hubPart = ofCylinder(rotor, "Hub", 2.6, 0.9, hub * CFrame.new(0, 0, -0.85), Palette.Gold, METAL, { CanCollide = false })
	rotor.PrimaryPart = hubPart
	-- The Rotor's pivot must be the centre of the wheel with the SAME orientation as `hub` (the cylinder part itself is turned to lie
	-- in the wheel plane). Without this, the first PivotTo would tip the whole wheel over onto its edge instead of turning it.
	hubPart.PivotOffset = hubPart.CFrame:Inverse() * hub
	ofCylinder(rotor, "Rim", RADIUS * 2 + 1.5, 0.9, hub * CFrame.new(0, 0, 0.1), Palette.Gold, METAL, { CanCollide = false })
	ofCylinder(rotor, "RimInner", RADIUS * 2 + 0.6, 1.0, hub * CFrame.new(0, 0, 0.0), Palette.WoodDark, WOOD, { CanCollide = false })
	ofCylinder(rotor, "Backplate", RADIUS * 2 + 0.2, 0.7, hub * CFrame.new(0, 0, -0.05), Palette.WoodDark, WOOD, { CanCollide = false })
	local outerRadius = RADIUS - 0.1
	local half = math.pi / count
	-- a point of the wheel plane: `angle` clockwise from the top, seen from the front (the wheel faces -Z)
	local function ring(angle: number, radius: number, z: number): Vector3
		return Vector3.new(-math.sin(angle) * radius, math.cos(angle) * radius, z)
	end
	for index, prize in prizes do
		local theta = (index - 1) * 2 * half
		local slice = Build.model(rotor, "Slice_" .. prize.Id)
		slice:SetAttribute("PrizeId", prize.Id)
		slice:SetAttribute("Index", index)
		-- the segment: a clean wedge from the hub to the rim (two wedge parts) with a lighter outer half, so it reads as a petal
		local centre = hub:PointToWorldSpace(Vector3.new(0, 0, -0.45))
		local left, right = hub:PointToWorldSpace(ring(theta - half, outerRadius, -0.45)), hub:PointToWorldSpace(ring(theta + half, outerRadius, -0.45))
		Build.triangle(slice, centre, left, right, prize.Color, PLASTIC, { CanCollide = false, CastShadow = false }, 0.3)
		local outerLeft, outerRight = hub:PointToWorldSpace(ring(theta - half, outerRadius * 0.97, -0.5)), hub:PointToWorldSpace(ring(theta + half, outerRadius * 0.97, -0.5))
		local mid = hub:PointToWorldSpace(ring(theta, outerRadius * 0.45, -0.5))
		Build.triangle(slice, mid, outerLeft, outerRight, prize.Color:Lerp(Color3.new(1, 1, 1), 0.18), PLASTIC, { CanCollide = false, CastShadow = false }, 0.3)
		-- the picture plate: lies on the slice (its top points to the rim) and shows the prize picture
		local plateAt = hub * CFrame.new(ring(theta, outerRadius * 0.66, -0.7)) * CFrame.Angles(0, 0, theta)
		local plate = Build.part(slice, "IconPlate", Vector3.new(2.5, 2.5, 0.1), plateAt, prize.Color, PLASTIC, { Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false })
		plate:SetAttribute("PrizeId", prize.Id)
		plate:SetAttribute("IconName", prize.Icon)
		plate:SetAttribute("Backdrop", prize.Color)
		if prize.Image then
			plate:SetAttribute("Image", prize.Image)
		end
		if textFallback then
			Build.surfaceText(plate, Enum.NormalId.Front, prize.Short or prize.Label, { TextColor = Palette.Ink, PixelsPerStud = 60, Font = Enum.Font.FredokaOne })
		else
			local gui = Instance.new("SurfaceGui")
			gui.Name = "PrizeIcon"
			gui.Face = Enum.NormalId.Front
			gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
			gui.PixelsPerStud = 60
			gui.LightInfluence = 0
			gui.Parent = plate
		end
		-- a gold divider between this slice and the next, with a peg on the rim
		local dividerAngle = theta + half
		local dividerAt = hub * CFrame.new(ring(dividerAngle, outerRadius / 2, -0.62)) * CFrame.Angles(0, 0, dividerAngle)
		Build.part(rotor, "Divider", Vector3.new(0.22, outerRadius, 0.22), dividerAt, Palette.Gold, METAL, { CanCollide = false })
		Build.blob(rotor, "Peg", Vector3.new(0.5, 0.5, 0.5), hub * CFrame.new(ring(dividerAngle, outerRadius + 0.15, -0.6)), Palette.Gold, METAL, { CanCollide = false })
	end
	ofCylinder(rotor, "HubCap", 1.5, 0.5, hub * CFrame.new(0, 0, -1.3), Color3.fromRGB(235, 64, 72), PLASTIC, { CanCollide = false })
	Build.blob(rotor, "HubGem", Vector3.new(0.7, 0.7, 0.5), hub * CFrame.new(0, 0, -1.65), Palette.Cream, Enum.Material.Neon, { CanCollide = false })
	model:SetAttribute("BaseCFrame", hub) -- the rotor's resting pivot (the server / clients rotate relative to it)

	-- the pointer at the top is FIXED (not part of the rotor): a red flapper pointing down onto the slice under it, on a gold pivot
	local tip = hub:PointToWorldSpace(Vector3.new(0, RADIUS - 0.4, -1.1))
	local topLeft = hub:PointToWorldSpace(Vector3.new(-0.9, RADIUS + 1.5, -1.1))
	local topRight = hub:PointToWorldSpace(Vector3.new(0.9, RADIUS + 1.5, -1.1))
	local pointer = Build.model(model, "Pointer")
	Build.triangle(pointer, topLeft, topRight, tip, Color3.fromRGB(235, 64, 72), PLASTIC, { CanCollide = false }, 0.5)
	Build.blob(pointer, "PointerPivot", Vector3.new(1.2, 1.2, 0.7), hub * CFrame.new(0, RADIUS + 1.35, -1.3), Palette.Gold, METAL, { CanCollide = false })
	Build.blob(pointer, "PointerGem", Vector3.new(0.5, 0.5, 0.4), hub * CFrame.new(0, RADIUS + 1.35, -1.7), Palette.Cream, Enum.Material.Neon, { CanCollide = false })

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
	prompt:SetAttribute("SpinWheel", true) -- SpinSystem answers this prompt (nothing opens on the client)
	prompt.Parent = pad
	Build.target(pad, "Wheel") -- the tutorial points here

	return model
end

return LuckyWheelBuilder
