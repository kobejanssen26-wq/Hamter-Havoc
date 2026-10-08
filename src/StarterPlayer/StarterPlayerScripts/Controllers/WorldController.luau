--[[
	WorldController: renders YOUR stream of hamsters on the road.
	The server only sends (id, species, spawnTime, speed); the client places each hamster at
	pointAt((serverNow - spawnTime) * speed) every frame, animates it and shows its price tag.
	It also picks the hamster you can currently grab (nearest one in range) for the [E] prompt.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Format = require(Modules:WaitForChild("Format"))
local HamsterBuilder = require(Modules:WaitForChild("HamsterBuilder"))
local HamsterDatabase = require(Modules:WaitForChild("HamsterDatabase"))
local PathConfig = require(Modules:WaitForChild("PathConfig"))
local RarityConfig = require(Modules:WaitForChild("RarityConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local AudioController = require(script.Parent.AudioController)
local DataController = require(script.Parent.DataController)
local FxController = require(script.Parent.FxController)
local HamsterAnimator = require(script.Parent.HamsterAnimator)

local WorldController = {}

local player = Players.LocalPlayer

type Hamster = {
	Id: string,
	Species: any,
	Model: Model,
	Animator: HamsterAnimator.Animator,
	Gui: BillboardGui,
	Frame: Frame,
	Stroke: UIStroke,
	NameLabel: TextLabel,
	PriceLabel: TextLabel,
	SpawnTime: number,
	Speed: number,
	Price: number,
	BaseScale: number,
	Pop: number,
	InRange: boolean,
	Collecting: { Start: number, From: CFrame }?,
	LastCFrame: CFrame,
}

local hamsters: { [string]: Hamster } = {}
local container: Folder
local currentTarget: string? = nil
local targetListeners: { (info: { Id: string, Species: any, Price: number, Affordable: boolean }?) -> () } = {}
local lastStepSound = 0
local lastRefresh = 0

local ROAD_Y = PathConfig.RoadHeight

local function displayName(species: any): string
	local definition = RarityConfig.ById[species.Rarity]
	local index = DataController.get("Index") or {}
	if definition.Hidden and not index[species.Id] then
		return "???"
	end
	return species.Name
end

local function createGui(species: any, model: Model, id: string, price: number): (BillboardGui, Frame, UIStroke, TextLabel, TextLabel)
	local definition = RarityConfig.ById[species.Rarity]
	local color = if definition.Hidden then definition.Accent else definition.Color

	local gui = Instance.new("BillboardGui")
	gui.Name = "HamsterTag_" .. id
	gui.Adornee = model.PrimaryPart
	gui.Size = UDim2.fromOffset(176, 74)
	gui.StudsOffsetWorldSpace = Vector3.new(0, ((model:GetAttribute("Height") :: number?) or 3.4) + 1.4, 0)
	gui.MaxDistance = 150
	gui.LightInfluence = 0
	gui.Active = true
	gui.ResetOnSpawn = false

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(38, 28, 40)
	frame.BackgroundTransparency = 0.2
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = frame

	local rarityLabel = Instance.new("TextLabel")
	rarityLabel.BackgroundTransparency = 1
	rarityLabel.Position = UDim2.fromOffset(0, 5)
	rarityLabel.Size = UDim2.new(1, 0, 0, 16)
	rarityLabel.Font = Enum.Font.GothamBold
	rarityLabel.TextSize = 13
	rarityLabel.TextColor3 = color
	rarityLabel.Text = string.upper(definition.Name)
	rarityLabel.Parent = frame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(0, 21)
	nameLabel.Size = UDim2.new(1, 0, 0, 24)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextSize = 20
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextScaled = false
	nameLabel.Text = displayName(species)
	nameLabel.Parent = frame

	local priceLabel = Instance.new("TextLabel")
	priceLabel.BackgroundTransparency = 1
	priceLabel.Position = UDim2.fromOffset(0, 47)
	priceLabel.Size = UDim2.new(1, 0, 0, 22)
	priceLabel.Font = Enum.Font.GothamBold
	priceLabel.TextSize = 16
	priceLabel.TextColor3 = Color3.fromRGB(255, 220, 110)
	priceLabel.Text = "🪙 " .. Format.short(price)
	priceLabel.Parent = frame

	local button = Instance.new("TextButton")
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromScale(1, 1)
	button.Text = ""
	button.Parent = frame
	button.Activated:Connect(function()
		WorldController.collect(id)
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	return gui, frame, stroke, nameLabel, priceLabel
end

local function destroyHamster(id: string)
	local hamster = hamsters[id]
	if not hamster then
		return
	end
	hamsters[id] = nil
	hamster.Gui:Destroy()
	hamster.Model:Destroy()
	if currentTarget == id then
		currentTarget = nil
	end
end

local function spawnHamster(id: string, speciesId: string, spawnTime: number, speed: number)
	local species = HamsterDatabase.ById[speciesId]
	if not species or hamsters[id] then
		return
	end
	local model = HamsterBuilder.build(species, {
		LowDetail = DataController.setting("LowGraphics") == true,
		Particles = DataController.setting("Particles") == true,
	})
	model.Name = "Run_" .. id
	local baseScale = model:GetScale()
	model:ScaleTo(baseScale * 0.2)

	local price = HamsterDatabase.price(species)
	local startDistance = math.max(0, (Workspace:GetServerTimeNow() - spawnTime) * speed)
	local position, tangent = PathConfig.pointAt(startDistance)
	local cframe = CFrame.lookAt(Vector3.new(position.X, ROAD_Y, position.Z), Vector3.new(position.X, ROAD_Y, position.Z) + tangent)
	model:PivotTo(cframe)
	model.Parent = container

	FxController.attach(model, species.Rarity)
	local gui, frame, stroke, nameLabel, priceLabel = createGui(species, model, id, price)

	local animator = HamsterAnimator.new(model)
	animator.OnStep = function()
		local now = os.clock()
		if now - lastStepSound < 0.12 then
			return
		end
		local camera = Workspace.CurrentCamera
		if camera and (camera.CFrame.Position - model:GetPivot().Position).Magnitude < 45 then
			lastStepSound = now
			AudioController.play("Footstep", { Position = model:GetPivot().Position, Pitch = 0.85 + math.random() * 0.4 })
		end
	end

	hamsters[id] = {
		Id = id,
		Species = species,
		Model = model,
		Animator = animator,
		Gui = gui,
		Frame = frame,
		Stroke = stroke,
		NameLabel = nameLabel,
		PriceLabel = priceLabel,
		SpawnTime = spawnTime,
		Speed = speed,
		Price = price,
		BaseScale = baseScale,
		Pop = 0,
		InRange = false,
		Collecting = nil,
		LastCFrame = cframe,
	}
end

local function removeHamster(id: string, reason: string)
	local hamster = hamsters[id]
	if not hamster then
		return
	end
	if reason == "Collected" then
		FxController.collected(hamster.Species.Rarity, hamster.LastCFrame.Position + Vector3.new(0, 2, 0))
		hamster.Gui.Enabled = false
		hamster.Animator:PlayOneShot("Collect")
		hamster.Collecting = { Start = os.clock(), From = hamster.LastCFrame }
		hamster.Speed = 0
		if currentTarget == id then
			currentTarget = nil
		end
	else
		destroyHamster(id)
	end
end

---------------------------------------------------------------------------
-- targeting
---------------------------------------------------------------------------

local function notifyTarget(info: { Id: string, Species: any, Price: number, Affordable: boolean }?)
	for _, listener in targetListeners do
		task.spawn(listener, info)
	end
end

function WorldController.onTargetChanged(callback: (info: { Id: string, Species: any, Price: number, Affordable: boolean }?) -> ())
	table.insert(targetListeners, callback)
end

function WorldController.getTarget(): string?
	return currentTarget
end

local lastCollectAttempt = 0

-- Asks the server to collect `id` (or the current target). The server validates everything.
function WorldController.collect(id: string?)
	local targetId = id or currentTarget
	if not targetId or not hamsters[targetId] then
		return
	end
	local now = os.clock()
	if now - lastCollectAttempt < 0.1 then
		return
	end
	lastCollectAttempt = now
	local hamster = hamsters[targetId]
	if DataController.coins() < hamster.Price then
		AudioController.play("Error")
	end
	Remotes.event("Collect"):FireServer(targetId)
end

---------------------------------------------------------------------------
-- frame update
---------------------------------------------------------------------------

local function easeOutBack(t: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function step(dt: number)
	local now = Workspace:GetServerTimeNow()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local rootPosition = if root and root:IsA("BasePart") then root.Position else nil
	local range = (DataController.derived().CollectRange or 16) + 4
	local coins = DataController.coins()

	local bestId: string? = nil
	local bestDistance = math.huge

	for id, hamster in hamsters do
		if hamster.Collecting then
			-- hop towards the player and shrink away
			local progress = (os.clock() - hamster.Collecting.Start) / 0.4
			if progress >= 1 or not rootPosition then
				destroyHamster(id)
			else
				local target = CFrame.new(rootPosition + Vector3.new(0, 2.5, 0))
				local eased = progress * progress * (3 - 2 * progress)
				local from = hamster.Collecting.From
				local position = from.Position:Lerp(target.Position, eased) + Vector3.new(0, math.sin(progress * math.pi) * 3, 0)
				hamster.Model:ScaleTo(math.max(hamster.BaseScale * (1 - eased), 0.05))
				hamster.Model:PivotTo(CFrame.new(position) * (from - from.Position))
				hamster.Animator:Update(dt, 0)
			end
		else
			local distance = (now - hamster.SpawnTime) * hamster.Speed
			if distance >= PathConfig.Length + 3 then
				destroyHamster(id)
			else
				local position, tangent = PathConfig.pointAt(math.max(distance, 0))
				local flat = Vector3.new(position.X, ROAD_Y, position.Z)
				local cframe = CFrame.lookAt(flat, flat + tangent)
				hamster.LastCFrame = cframe

				if hamster.Pop < 1 then
					hamster.Pop = math.min(1, hamster.Pop + dt / 0.5)
					hamster.Model:ScaleTo(hamster.BaseScale * math.max(0.2 + 0.8 * easeOutBack(hamster.Pop), 0.05))
				end
				hamster.Model:PivotTo(cframe)
				hamster.Animator:Update(dt, hamster.Speed)

				if rootPosition then
					local d = (rootPosition - (flat + Vector3.new(0, 1.5, 0))).Magnitude
					hamster.InRange = d <= range
					if hamster.InRange and d < bestDistance then
						bestDistance = d
						bestId = id
					end
				end
			end
		end
	end

	-- tag styling: affordable / in range
	if os.clock() - lastRefresh > 0.1 then
		lastRefresh = os.clock()
		for id, hamster in hamsters do
			if not hamster.Collecting then
				local definition = RarityConfig.ById[hamster.Species.Rarity]
				local baseColor = if definition.Hidden then definition.Accent else definition.Color
				local isTarget = id == bestId
				hamster.Stroke.Thickness = if isTarget then 4 else 2
				hamster.Stroke.Color = if isTarget then Color3.new(1, 1, 1) else baseColor
				hamster.PriceLabel.TextColor3 = if coins >= hamster.Price then Color3.fromRGB(255, 220, 110) else Color3.fromRGB(255, 120, 120)
				hamster.PriceLabel.Visible = DataController.setting("ShowValues") == true
				hamster.NameLabel.Text = displayName(hamster.Species)
				hamster.Frame.BackgroundTransparency = if isTarget then 0.05 else 0.25
			end
		end
	end

	if bestId ~= currentTarget then
		currentTarget = bestId
		if bestId then
			local hamster = hamsters[bestId]
			notifyTarget({ Id = bestId, Species = hamster.Species, Price = hamster.Price, Affordable = coins >= hamster.Price })
		else
			notifyTarget(nil)
		end
	end
end

function WorldController.start()
	container = Instance.new("Folder")
	container.Name = "ClientHamsters"
	container.Parent = Workspace

	Remotes.event("SpawnHamster").OnClientEvent:Connect(spawnHamster)
	Remotes.event("RemoveHamster").OnClientEvent:Connect(removeHamster)
	Remotes.event("CollectResult").OnClientEvent:Connect(function(success: boolean, id: string, speciesId: string, isNew: boolean, note: string)
		WorldController.OnCollectResult(success, speciesId, isNew, note)
	end)

	RunService.RenderStepped:Connect(step)
end

-- UI modules replace this to show reveals (set after require to avoid cycles)
WorldController.OnCollectResult = function(_success: boolean, _speciesId: string, _isNew: boolean, _note: string) end

return WorldController
