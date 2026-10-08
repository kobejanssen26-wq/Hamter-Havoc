--[[
	FxController: rarity visuals on running hamsters (glow, outline, ring, light pillar, trail, particles,
	orbiting floaters, glitch / rainbow shimmer) plus one-off effects (collect bursts, camera shake,
	rebirth fireworks). Every effect respects the Particles / Low Graphics settings.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local RarityConfig = require(Modules:WaitForChild("RarityConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local AudioController = require(script.Parent.AudioController)
local DataController = require(script.Parent.DataController)

local FxController = {}

-- UI modules register here (avoids circular requires)
FxController.OnRareAlert = nil :: ((rarityId: string) -> ())?
FxController.OnQuestDone = nil :: (() -> ())?

local TEXTURES = {
	sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	fire = "rbxasset://textures/particles/fire_main.dds",
	smoke = "rbxasset://textures/particles/smoke_main.dds",
}

local KIND_TEXTURE = {
	sparkle = "sparkle", hearts = "sparkle", stars = "sparkle", rays = "sparkle", glitch = "sparkle", runes = "sparkle",
	embers = "fire", snow = "smoke", bubbles = "smoke", dust = "smoke",
}

type Tracked = {
	Model: Model,
	Root: BasePart,
	Spec: any,
	Floaters: { { Part: BasePart, Radius: number, Height: number, Speed: number, Offset: number } },
	Highlight: Highlight?,
	Ring: BasePart?,
	Light: PointLight?,
	Time: number,
	NextGlitch: number,
}

local tracked: { Tracked } = {}

local function particlesAllowed(): boolean
	return DataController.setting("Particles") == true and DataController.setting("LowGraphics") ~= true
end

local function colorSequence(colors: { Color3 }): ColorSequence
	if #colors == 1 then
		return ColorSequence.new(colors[1])
	end
	local keypoints = {}
	for index, color in colors do
		table.insert(keypoints, ColorSequenceKeypoint.new((index - 1) / (#colors - 1), color))
	end
	return ColorSequence.new(keypoints)
end

local function makePart(name: string, size: Vector3, color: Color3, shape: Enum.PartType?, transparency: number?): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Transparency = transparency or 0
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Massless = true
	if shape then
		part.Shape = shape
	end
	return part
end

-- Attaches the rarity effects to a hamster model that moves along the road.
function FxController.attach(model: Model, rarityId: string)
	local definition = RarityConfig.ById[rarityId]
	local spec = definition and definition.Fx
	local root = model.PrimaryPart
	local body = model:FindFirstChild("Body")
	if not spec or not root or not body or next(spec) == nil then
		return
	end

	local entry: Tracked = {
		Model = model,
		Root = root,
		Spec = spec,
		Floaters = {},
		Highlight = nil,
		Ring = nil,
		Light = nil,
		Time = math.random() * 10,
		NextGlitch = 0,
	}
	local lowGraphics = DataController.setting("LowGraphics") == true

	if spec.Light then
		local light = Instance.new("PointLight")
		light.Color = spec.Light.Color
		light.Brightness = spec.Light.Brightness
		light.Range = spec.Light.Range
		light.Shadows = false
		light.Parent = body
		entry.Light = light
	end

	if spec.Outline then
		local highlight = Instance.new("Highlight")
		highlight.Adornee = model
		highlight.FillTransparency = 1
		highlight.OutlineColor = spec.Outline
		highlight.OutlineTransparency = 0.15
		highlight.DepthMode = Enum.HighlightDepthMode.Occluded
		highlight.Parent = model
		entry.Highlight = highlight
	end

	if spec.Ring then
		local ring = makePart("RarityRing", Vector3.new(0.12, 5.4, 5.4), spec.Ring, Enum.PartType.Cylinder, 0.35)
		ring.CFrame = root.CFrame * CFrame.new(0, 0.12, 0) * CFrame.Angles(0, 0, math.rad(90))
		ring.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = ring
		weld.Parent = ring
		ring.Parent = model
		entry.Ring = ring
	end

	if spec.Beam and not lowGraphics then
		local height = spec.Beam.Height
		local beam = makePart("RarityBeam", Vector3.new(0.9, height, 0.9), spec.Beam.Color, nil, 0.55)
		beam.CFrame = root.CFrame * CFrame.new(0, height / 2 + 2, 0)
		beam.Anchored = false
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = beam
		weld.Parent = beam
		beam.Parent = model
	end

	if spec.Trail and not lowGraphics then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.4, 0.9)
		a0.Parent = body
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, 2.4, 0.9)
		a1.Parent = body
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(spec.Trail)
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		trail.Lifetime = 0.9
		trail.LightEmission = 0.8
		trail.MinLength = 0.1
		trail.Parent = body
	end

	if spec.Particles and particlesAllowed() then
		local particles = spec.Particles
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = TEXTURES[KIND_TEXTURE[particles.Kind] or "sparkle"]
		emitter.Color = colorSequence(particles.Colors)
		emitter.LightEmission = if particles.Kind == "dust" or particles.Kind == "snow" then 0.1 else 0.8
		emitter.Rate = particles.Rate
		emitter.Lifetime = NumberRange.new(particles.Lifetime * 0.7, particles.Lifetime)
		emitter.Speed = NumberRange.new(particles.Speed * 0.5, particles.Speed)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Rotation = NumberRange.new(0, 360)
		emitter.RotSpeed = NumberRange.new(-60, 60)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, particles.Size), NumberSequenceKeypoint.new(1, 0) })
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		if particles.Kind == "hearts" or particles.Kind == "bubbles" or particles.Kind == "embers" then
			emitter.Acceleration = Vector3.new(0, 4, 0)
		elseif particles.Kind == "snow" or particles.Kind == "dust" then
			emitter.Acceleration = Vector3.new(0, -1.5, 0)
		end
		emitter.Parent = body
	end

	if spec.Floaters and particlesAllowed() then
		local floaters = spec.Floaters
		for index = 1, floaters.Count do
			local part
			if floaters.Kind == "squares" then
				part = makePart("Floater", Vector3.new(0.5, 0.5, 0.1), floaters.Color)
			elseif floaters.Kind == "runes" then
				part = makePart("Floater", Vector3.new(0.5, 0.8, 0.1), floaters.Color)
			elseif floaters.Kind == "stars" then
				part = makePart("Floater", Vector3.new(0.45, 0.45, 0.45), floaters.Color, Enum.PartType.Ball)
			else
				part = makePart("Floater", Vector3.new(0.55, 0.55, 0.55), floaters.Color, Enum.PartType.Ball)
			end
			part.Anchored = true
			part.Parent = model
			table.insert(entry.Floaters, {
				Part = part,
				Radius = 2.6 + (index % 2) * 0.5,
				Height = 1.2 + (index % 3) * 0.9,
				Speed = (1.4 + index * 0.15) * (if index % 2 == 0 then 1 else -1),
				Offset = (index / floaters.Count) * math.pi * 2,
			})
		end
	end

	table.insert(tracked, entry)
end

---------------------------------------------------------------------------
-- one-off effects
---------------------------------------------------------------------------

-- Burst of sparkles + an expanding ring at a world position.
function FxController.burst(position: Vector3, color: Color3, rank: number)
	local holder = makePart("Burst", Vector3.one * 0.2, color, Enum.PartType.Ball, 1)
	holder.Anchored = true
	holder.Position = position
	holder.Parent = workspace
	Debris:AddItem(holder, 3)

	if particlesAllowed() then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = TEXTURES.sparkle
		emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
		emitter.LightEmission = 1
		emitter.Lifetime = NumberRange.new(0.5, 1.1)
		emitter.Speed = NumberRange.new(6, 8 + rank * 1.5)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9 + rank * 0.08), NumberSequenceKeypoint.new(1, 0) })
		emitter.Rate = 0
		emitter.Enabled = false
		emitter.Parent = holder
		emitter:Emit(8 + rank * 4)
	end

	local ring = makePart("BurstRing", Vector3.new(0.1, 1, 1), color, Enum.PartType.Cylinder, 0.2)
	ring.Anchored = true
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	local size = 6 + rank * 1.4
	TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.1, size, size),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, 0.7)
end

local shakeToken = 0

function FxController.shake(intensity: number, duration: number)
	if DataController.setting("CameraShake") ~= true then
		return
	end
	local humanoid = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	shakeToken += 1
	local token = shakeToken
	task.spawn(function()
		local start = os.clock()
		while token == shakeToken do
			local elapsed = os.clock() - start
			if elapsed >= duration then
				break
			end
			local strength = intensity * (1 - elapsed / duration)
			humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * strength, (math.random() - 0.5) * strength, 0)
			RunService.RenderStepped:Wait()
		end
		if token == shakeToken then
			humanoid.CameraOffset = Vector3.zero
		end
	end)
end

-- The player collected something: burst + sound + (for big ones) shake.
function FxController.collected(rarityId: string, position: Vector3)
	local definition = RarityConfig.ById[rarityId]
	if not definition then
		return
	end
	local color = if definition.Hidden then definition.Accent else definition.Color
	FxController.burst(position, color, definition.Rank)
	AudioController.playCollect(rarityId)
	if definition.Rank >= 7 then
		FxController.shake(0.35 + (definition.Rank - 7) * 0.08, 0.5)
	end
end

function FxController.rebirth(count: number)
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	for index = 1, 4 do
		task.delay((index - 1) * 0.18, function()
			if root.Parent then
				FxController.burst(root.Position + Vector3.new(0, index, 0), Color3.fromHSV((index * 0.17 + count * 0.05) % 1, 0.6, 1), 10 + index)
			end
		end)
	end
	AudioController.play("Rebirth")
	FxController.shake(0.6, 0.9)
end

---------------------------------------------------------------------------
-- per-frame (floaters, pulses, special shimmer)
---------------------------------------------------------------------------

local function step(dt: number)
	local index = #tracked
	while index >= 1 do
		local entry = tracked[index]
		if not entry.Model.Parent or not entry.Root.Parent then
			table.remove(tracked, index)
		else
			entry.Time += dt
			local time = entry.Time
			local rootCFrame = entry.Root.CFrame

			for _, floater in entry.Floaters do
				local angle = time * floater.Speed + floater.Offset
				floater.Part.CFrame = rootCFrame * CFrame.new(math.cos(angle) * floater.Radius, floater.Height + math.sin(angle * 2) * 0.25, math.sin(angle) * floater.Radius) * CFrame.Angles(time, time * 0.7, 0)
			end

			if entry.Ring then
				entry.Ring.Transparency = 0.3 + math.sin(time * 4) * 0.15
			end
			if entry.Light then
				local base = entry.Spec.Light.Brightness
				entry.Light.Brightness = base * (0.85 + math.sin(time * 5) * 0.15)
			end

			local special = entry.Spec.Special
			if special == "Rainbow" and entry.Highlight then
				local color = Color3.fromHSV((time * 0.35) % 1, 0.6, 1)
				entry.Highlight.OutlineColor = color
				if entry.Light then
					entry.Light.Color = color
				end
			elseif special == "Glitch" and entry.Highlight and time >= entry.NextGlitch then
				entry.NextGlitch = time + 0.07 + math.random() * 0.2
				local colors = entry.Spec.Particles and entry.Spec.Particles.Colors or { entry.Spec.Outline }
				entry.Highlight.OutlineColor = colors[math.random(1, #colors)]
				entry.Highlight.FillTransparency = if math.random() > 0.8 then 0.55 else 1
			end
		end
		index -= 1
	end
end

function FxController.start()
	RunService.RenderStepped:Connect(step)

	Remotes.event("Fx").OnClientEvent:Connect(function(kind: string, argument: any)
		if kind == "RareSpawn" then
			AudioController.playRareAlert(argument)
			if FxController.OnRareAlert then
				FxController.OnRareAlert(argument)
			end
			local definition = RarityConfig.ById[argument]
			if definition and definition.Rank >= 8 then
				FxController.shake(0.25, 0.6)
			end
		elseif kind == "Rebirth" then
			FxController.rebirth(argument)
		elseif kind == "QuestDone" then
			AudioController.play("Reward")
			if FxController.OnQuestDone then
				FxController.OnQuestDone()
			end
		end
	end)
end

return FxController
