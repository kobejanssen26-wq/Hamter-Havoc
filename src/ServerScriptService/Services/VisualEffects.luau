--[[
	Rarity visuals for hamster balls: colour, glass, light, sparkles, tall beacon, crown.
	All values come from Rarities.Definitions[...].VisualEffect.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Rarities = require(Shared.Config.Rarities)
local PartUtil = require(Shared.Util.PartUtil)

local VisualEffects = {}

local GOLD = Color3.fromRGB(255, 205, 60)

local function addCrown(model: Model, carrier: BasePart, radius: number)
	local baseY = radius + 0.5
	local band = PartUtil.create("CrownBand", Vector3.new(0.8, 3.2, 3.2), carrier.CFrame * CFrame.new(0, baseY, 0) * CFrame.Angles(0, 0, math.pi / 2), {
		Shape = Enum.PartType.Cylinder,
		Color = GOLD,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
		Massless = true,
	})
	PartUtil.weld(band, carrier)
	band.Parent = model

	for i = 1, 5 do
		local angle = (i / 5) * math.pi * 2
		local spike = PartUtil.create("CrownSpike", Vector3.new(0.5, 1.4, 0.5), carrier.CFrame * CFrame.new(math.cos(angle) * 1.5, baseY + 1, math.sin(angle) * 1.5), {
			Color = GOLD,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Massless = true,
		})
		PartUtil.weld(spike, carrier)
		spike.Parent = model
	end
end

function VisualEffects.applyToBall(model: Model, carrier: BasePart, hull: BasePart, stripe: BasePart, rarityName: string)
	local definition = Rarities.Definitions[rarityName]
	local effect = definition.VisualEffect
	local accent = Rarities.getAccentColor(rarityName)
	local radius = hull.Size.X / 2

	hull.Color = definition.DisplayColor
	hull.Transparency = effect.BallTransparency
	hull.Material = Enum.Material.Glass
	stripe.Color = accent

	if effect.LightBrightness > 0 then
		local light = Instance.new("PointLight")
		light.Color = accent
		light.Brightness = effect.LightBrightness
		light.Range = effect.LightRange or 14
		light.Shadows = false
		light.Parent = carrier
	end

	if effect.Particles then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(accent)
		emitter.LightEmission = 1
		emitter.Rate = 14
		emitter.Lifetime = NumberRange.new(1, 2)
		emitter.Speed = NumberRange.new(3, 6)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.9),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Parent = carrier
	end

	local beaconHeight = effect.BeaconHeight
	if beaconHeight > 0 then
		local beacon = PartUtil.create("Beacon", Vector3.new(0.8, beaconHeight, 0.8), carrier.CFrame * CFrame.new(0, radius + beaconHeight / 2, 0), {
			Color = accent,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = false,
			CanTouch = false,
			CanQuery = false,
			Massless = true,
		})
		PartUtil.weld(beacon, carrier)
		beacon.Parent = model
	end

	if effect.Crown then
		addCrown(model, carrier, radius)
	end
end

return VisualEffects
