--[[
	AmbientController: makes the world feel alive without any per-frame server cost.
	  - IdleHamster models (plaza statue) run the idle/behaviour animator when you're near
	  - WheelHamster models (hamsters working in the houses) run on their wheel, with a floating +coins pop
	    and a quiet tick every so often (only when you're close, throttled)
	  - decorations tagged Bob / Sway / SpinModel / Ripple move locally
	  - ambient particle emitters (fountain, chimney smoke, fireflies, hamster auras on shelves)
	    are only enabled near the camera and when the Particles setting is on
	Everything is distance-culled and throttled.
]]

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Format = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("Format"))

local AudioController = require(script.Parent.AudioController)
local DataController = require(script.Parent.DataController)
local FxController = require(script.Parent.FxController)
local HamsterAnimator = require(script.Parent.HamsterAnimator)

local AmbientController = {}

local IDLE_DISTANCE = 85
local DECOR_DISTANCE = 140
local PARTICLE_DISTANCE = 110

local WORKER_FX_DISTANCE = 32
local WORKER_POP_SECONDS = 1.6

local idleAnimators: { [Model]: HamsterAnimator.Animator } = {}
local idleModels: { [Model]: boolean } = {}
local workerModels: { [Model]: { NextPop: number, Born: number, Greeted: boolean } } = {}
local activePops = 0

type Decor = { Instance: Instance, Home: CFrame, Phase: number, Active: boolean, Position: Vector3 }
local bobs: { [Instance]: Decor } = {}
local sways: { [Instance]: Decor } = {}
local spins: { [Instance]: Decor } = {}
local ripples: { [BasePart]: { Phase: number, Active: boolean, Base: number } } = {}

local emitterParents: { [BasePart]: boolean } = {}

local function pivotOf(instance: Instance): CFrame?
	if instance:IsA("Model") then
		return instance:GetPivot()
	elseif instance:IsA("BasePart") then
		return instance.CFrame
	end
	return nil
end

local function registerDecor(registry: { [Instance]: Decor }, instance: Instance)
	local home = pivotOf(instance)
	if instance:IsA("Model") and instance:GetAttribute("HomeCFrame") then
		home = instance:GetAttribute("HomeCFrame")
	end
	if home then
		registry[instance] = { Instance = instance, Home = home, Phase = math.random() * 6, Active = true, Position = home.Position }
	end
end

local function track(tag: string, onAdded: (Instance) -> (), onRemoved: (Instance) -> ())
	for _, instance in CollectionService:GetTagged(tag) do
		onAdded(instance)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(onAdded)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(onRemoved)
end

local function updateEmitters(model: Instance, enabled: boolean)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("ParticleEmitter") then
			descendant.Enabled = enabled
		end
	end
end

-- throttled culling pass
local function cull()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local cameraPosition = camera.CFrame.Position
	local particlesOn = DataController.setting("Particles") == true and DataController.setting("LowGraphics") ~= true

	for model in workerModels do
		local root = model.PrimaryPart
		if root then
			local near = (root.Position - cameraPosition).Magnitude < IDLE_DISTANCE
			if near and not idleAnimators[model] then
				idleAnimators[model] = HamsterAnimator.new(model)
			elseif not near and idleAnimators[model] then
				idleAnimators[model] = nil
			end
			-- a hamster that just got home hops with joy
			local worker = workerModels[model]
			local animator = idleAnimators[model]
			if worker and animator and not worker.Greeted and os.clock() - worker.Born < 8 then
				worker.Greeted = true
				animator:PlayOneShot("Happy")
				FxController.burst(root.Position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 226, 120), 4)
			end
		end
	end

	for model in idleModels do
		local root = model.PrimaryPart
		if not root then
			continue
		end
		local near = (root.Position - cameraPosition).Magnitude < IDLE_DISTANCE
		if near and not idleAnimators[model] then
			idleAnimators[model] = HamsterAnimator.new(model)
		elseif not near and idleAnimators[model] then
			idleAnimators[model] = nil
		end
		-- aura particles on shelf hamsters only when close
		updateEmitters(model, near and particlesOn and (root.Position - cameraPosition).Magnitude < 45)
	end

	for _, registry in { bobs, sways, spins } do
		for _, decor in registry do
			decor.Active = (decor.Position - cameraPosition).Magnitude < DECOR_DISTANCE
		end
	end
	for part, info in ripples do
		info.Active = (part.Position - cameraPosition).Magnitude < DECOR_DISTANCE
	end
	for part in emitterParents do
		local near = (part.Position - cameraPosition).Magnitude < PARTICLE_DISTANCE
		for _, child in part:GetChildren() do
			if child:IsA("ParticleEmitter") then
				child.Enabled = near and particlesOn
			end
		end
	end
end

-- A little "+coins" that floats up from a working hamster (quiet, limited to a few at once).
local function workerPop(model: Model)
	local root = model.PrimaryPart
	local income = model:GetAttribute("Income")
	if not root or type(income) ~= "number" or activePops >= 5 then
		return
	end
	activePops += 1
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(90, 22)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = WORKER_FX_DISTANCE + 8
	gui.LightInfluence = 0
	gui.Adornee = root
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextColor3 = Color3.fromRGB(255, 226, 120)
	label.TextStrokeTransparency = 0.5
	label.Text = "+" .. Format.short(income)
	label.Parent = gui
	gui.Parent = root
	TweenService:Create(gui, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(1.1), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.2, function()
		activePops -= 1
		gui:Destroy()
	end)
	if DataController.setting("Particles") == true and DataController.setting("LowGraphics") ~= true then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90))
		emitter.LightEmission = 0.8
		emitter.Lifetime = NumberRange.new(0.5, 0.9)
		emitter.Speed = NumberRange.new(3, 5)
		emitter.SpreadAngle = Vector2.new(40, 40)
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		emitter.Rate = 0
		emitter.Parent = root
		emitter:Emit(3)
		Debris:AddItem(emitter, 1.2)
	end
	if DataController.setting("SFX") == true then
		AudioController.play("WheelTick", { Position = root.Position })
	end
end

local function step(dt: number)
	local camera = Workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else nil
	local clock = os.clock()
	for model, animator in idleAnimators do
		if model.Parent then
			local worker = workerModels[model]
			if worker then
				animator:Update(dt, (model:GetAttribute("RunSpeed") :: number?) or 7)
				if cameraPosition and model.PrimaryPart and clock >= worker.NextPop and (model.PrimaryPart.Position - cameraPosition).Magnitude < WORKER_FX_DISTANCE then
					worker.NextPop = clock + WORKER_POP_SECONDS + math.random() * 1.2
					workerPop(model)
				end
			else
				animator:Update(dt, 0)
			end
		end
	end

	local time = os.clock()
	for instance, decor in bobs do
		if decor.Active then
			local amplitude = instance:GetAttribute("Amplitude") or 0.4
			local speed = instance:GetAttribute("Speed") or 1.5
			local cframe = decor.Home * CFrame.new(0, math.sin(time * speed + decor.Phase) * amplitude, 0)
			if instance:IsA("Model") then
				instance:PivotTo(cframe)
			elseif instance:IsA("BasePart") then
				instance.CFrame = cframe
			end
		end
	end
	for instance, decor in sways do
		if decor.Active then
			local amplitude = math.rad(instance:GetAttribute("Amplitude") or 3)
			local speed = instance:GetAttribute("Speed") or 1.2
			local angle = math.sin(time * speed + decor.Phase) * amplitude
			local rotation = if instance:GetAttribute("Axis") == "Y" then CFrame.Angles(0, angle, 0) else CFrame.Angles(0, 0, angle)
			-- rotate around the base for tall things (flowers), around the centre for cloth
			local cframe = decor.Home * rotation
			if instance:IsA("Model") then
				instance:PivotTo(cframe)
			elseif instance:IsA("BasePart") then
				instance.CFrame = cframe
			end
		end
	end
	for instance, decor in spins do
		if decor.Active and instance:IsA("Model") and instance.PrimaryPart then
			local speed = instance:GetAttribute("Speed") or 1
			local angle = time * speed
			local axis = instance:GetAttribute("Axis")
			local rotation = if axis == "X" then CFrame.Angles(angle, 0, 0) elseif axis == "Y" then CFrame.Angles(0, angle, 0) else CFrame.Angles(0, 0, angle)
			instance:PivotTo(decor.Home * rotation)
		end
	end
	for part, info in ripples do
		if info.Active then
			part.Transparency = info.Base + math.sin(time * 1.6 + info.Phase) * 0.05
		end
	end
end

function AmbientController.start()
	track("IdleHamster", function(instance)
		if instance:IsA("Model") then
			idleModels[instance] = true
		end
	end, function(instance)
		if instance:IsA("Model") then
			idleModels[instance] = nil
			idleAnimators[instance] = nil
		end
	end)
	track("WheelHamster", function(instance)
		if instance:IsA("Model") then
			workerModels[instance] = { NextPop = os.clock() + math.random() * WORKER_POP_SECONDS, Born = os.clock(), Greeted = false }
		end
	end, function(instance)
		if instance:IsA("Model") then
			workerModels[instance] = nil
			idleAnimators[instance] = nil
		end
	end)
	track("Bob", function(instance)
		registerDecor(bobs, instance)
	end, function(instance)
		bobs[instance] = nil
	end)
	track("Sway", function(instance)
		registerDecor(sways, instance)
	end, function(instance)
		sways[instance] = nil
	end)
	track("SpinModel", function(instance)
		registerDecor(spins, instance)
	end, function(instance)
		spins[instance] = nil
	end)
	track("AmbientParticles", function(instance)
		if instance:IsA("BasePart") then
			emitterParents[instance] = true
		end
	end, function(instance)
		emitterParents[instance :: BasePart] = nil
	end)
	track("BuilderFx", function() end, function() end)

	-- water ripples (any part carrying the Ripple attribute inside the plaza / ponds)
	task.spawn(function()
		for _, descendant in Workspace:WaitForChild("HamsterPlaza"):GetDescendants() do
			if descendant:IsA("BasePart") and descendant:GetAttribute("Ripple") then
				ripples[descendant] = { Phase = math.random() * 6, Active = true, Base = descendant.Transparency }
			end
		end
		local environment = Workspace:FindFirstChild("Environment")
		if environment then
			for _, descendant in environment:GetDescendants() do
				if descendant:IsA("BasePart") and descendant:GetAttribute("Ripple") then
					ripples[descendant] = { Phase = math.random() * 6, Active = true, Base = descendant.Transparency }
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			cull()
			task.wait(0.4)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return AmbientController
