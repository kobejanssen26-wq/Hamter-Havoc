--[[
	Player bases: builds 8 plots, assigns them to players, owns the wheel slots and the collector.
	More than 8 players: extra players wait in a queue and get a base when one frees up
	(they can still walk around, they just can't buy until they have a base).

	Slot life cycle:  free -> occupied (Hamster set, Model mounted) -> [stolen: Hamster kept, Model nil]
	                  -> back to occupied (returned) or free (delivered to the thief).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Rebirth = require(Shared.Config.Rebirth)
local Format = require(Shared.Util.Format)
local PartUtil = require(Shared.Util.PartUtil)

local Services = script.Parent
local DataService = require(Services.DataService)
local HamsterModel = require(Services.HamsterModel)
local IncomeService = require(Services.IncomeService)
local Notifier = require(Services.Notifier)
local SecurityService = require(Services.SecurityService)

local BaseService = {}

local baseConfig = GameConfig.Bases
local wheelConfig = GameConfig.Wheel
local FLOOR_TOP = baseConfig.Size.Y

local bases = {}
local baseByPlayer = {}
local waitingQueue = {}
local stealHandler: ((Player, string) -> ())? = nil

local EMPTY_TEXT = '<font color="#9a9aa5">Empty wheel</font>'

function BaseService.setStealHandler(handler: (Player, string) -> ())
	stealHandler = handler
end

---------------------------------------------------------------------------
-- Slot helpers
---------------------------------------------------------------------------

local function updateSlotDisplay(slot)
	if slot.Hamster == nil then
		slot.Label.Text = EMPTY_TEXT
	elseif slot.Stolen then
		slot.Label.Text = '<font color="#ff5555"><b>STOLEN!</b></font>'
	else
		slot.Label.Text = HamsterModel.richDescription(slot.Hamster, false)
			.. string.format('\n<font color="#7dff8a">%s/s</font>', Format.money(slot.Hamster.IncomePerSecond))
	end
end

local function findFreeSlot(base)
	for _, slot in base.Slots do
		if slot.Hamster == nil then
			return slot
		end
	end
	return nil
end

local function findSlotByHamster(base, uniqueId: string)
	for _, slot in base.Slots do
		if slot.Hamster and slot.Hamster.UniqueId == uniqueId then
			return slot
		end
	end
	return nil
end

local function mountHamster(slot, hamster, model: Model)
	slot.Hamster = hamster
	slot.Stolen = false
	slot.Model = model
	hamster.SlotIndex = slot.Index

	HamsterModel.placeAt(model, slot.HamsterCFrame)
	model.Parent = slot.Folder
	model:SetAttribute("HomeCFrame", slot.HamsterCFrame)
	CollectionService:AddTag(model, "RunningHamster")
	slot.Wheel:SetAttribute("SpinSpeed", wheelConfig.SpinSpeed)

	HamsterModel.addStealPrompt(model, hamster, function(player, uniqueId)
		if stealHandler then
			stealHandler(player, uniqueId)
		end
	end)
	updateSlotDisplay(slot)
end

local function clearSlot(slot)
	if slot.Model then
		slot.Model:Destroy()
	end
	if slot.Hamster then
		slot.Hamster.SlotIndex = nil
	end
	slot.Model = nil
	slot.Hamster = nil
	slot.Stolen = false
	slot.Wheel:SetAttribute("SpinSpeed", 0)
	updateSlotDisplay(slot)
end

---------------------------------------------------------------------------
-- Building
---------------------------------------------------------------------------

local function buildWheel(slotCFrame: CFrame): (Model, CFrame)
	local radius = wheelConfig.Radius
	local wheelCFrame = slotCFrame * CFrame.new(0, 0.6 + radius, 0)
	local model = Instance.new("Model")
	model.Name = "Wheel"

	local disc = PartUtil.create("Disc", Vector3.new(wheelConfig.Thickness, radius * 2, radius * 2), wheelCFrame, {
		Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(190, 210, 235),
		Material = Enum.Material.Glass,
		Transparency = 0.7,
		CanCollide = false,
	})
	local spokeA = PartUtil.create("SpokeA", Vector3.new(0.4, radius * 2, 0.4), wheelCFrame, {
		Color = Color3.fromRGB(255, 190, 90),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local spokeB = PartUtil.create("SpokeB", Vector3.new(0.4, 0.4, radius * 2), wheelCFrame, {
		Color = Color3.fromRGB(255, 190, 90),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local axle = PartUtil.create("Axle", Vector3.new(wheelConfig.Thickness + 2, 0.6, 0.6), wheelCFrame, {
		Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(70, 70, 80),
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
	disc.Parent = model
	spokeA.Parent = model
	spokeB.Parent = model
	axle.Parent = model

	for i = 0, 3 do
		local angle = i * math.pi / 2 + math.pi / 4
		local rung = PartUtil.create(
			"Rung",
			Vector3.new(wheelConfig.Thickness, 0.5, 0.5),
			wheelCFrame * CFrame.new(0, math.cos(angle) * (radius - 0.25), math.sin(angle) * (radius - 0.25)),
			{ Color = Color3.fromRGB(255, 120, 60), Material = Enum.Material.Neon, CanCollide = false }
		)
		rung.Parent = model
	end

	model.PrimaryPart = disc
	model:SetAttribute("HomeCFrame", wheelCFrame)
	model:SetAttribute("SpinSpeed", 0)
	CollectionService:AddTag(model, "SpinningWheel")
	return model, wheelCFrame
end

local function buildSlot(base, index: number, count: number)
	local x = (index - (count + 1) / 2) * baseConfig.SlotSpacing
	local slotCFrame = base.CFrame * CFrame.new(x, FLOOR_TOP, baseConfig.SlotZ)

	local folder = Instance.new("Model")
	folder.Name = "Slot" .. index

	local platformSize = wheelConfig.PlatformSize
	local platform = PartUtil.create("Platform", Vector3.new(platformSize, 0.6, platformSize), slotCFrame * CFrame.new(0, 0.3, 0), {
		Color = Color3.fromRGB(120, 90, 70),
		Material = Enum.Material.WoodPlanks,
	})
	platform.Parent = folder

	for _, side in { -1, 1 } do
		local postHeight = wheelConfig.Radius + 0.6
		local post = PartUtil.create("Post", Vector3.new(0.6, postHeight, 0.6), slotCFrame * CFrame.new(side * (wheelConfig.Thickness / 2 + 1), 0.6 + postHeight / 2, 0), {
			Color = Color3.fromRGB(70, 70, 80),
			Material = Enum.Material.Metal,
		})
		post.Parent = folder
	end

	local wheel = buildWheel(slotCFrame)
	wheel.Parent = folder

	local label = HamsterModel.createBillboard(platform, EMPTY_TEXT, Vector3.new(0, 12, 0), Vector2.new(220, 70))

	folder.Parent = base.SlotsFolder
	return {
		Index = index,
		Folder = folder,
		Wheel = wheel,
		Label = label,
		HamsterCFrame = slotCFrame * CFrame.new(0, 0.6 + 1.2, 0),
		Hamster = nil,
		Model = nil,
		Stolen = false,
	}
end

local function refreshCollector(base)
	local stored = base.Owner and base.Owner:GetAttribute("Stored") or 0
	base.CollectorPrompt.ActionText = "COLLECT " .. Format.money(stored)
	base.CollectorLabel.Text = string.format('<b>COLLECTOR</b>\n<font color="#7dff8a">%s</font>', Format.money(stored))
end

local function refreshSign(base)
	if base.Owner then
		base.SignLabel.Text = string.format("<b>%s's Base</b>", base.Owner.DisplayName)
	else
		base.SignLabel.Text = '<font color="#9a9aa5"><b>Free plot</b></font>'
	end
end

local function buildCollector(base)
	local part = PartUtil.create("Collector", Vector3.new(6, 3, 6), base.CFrame * CFrame.new(baseConfig.CollectorX, FLOOR_TOP + 1.5, baseConfig.SpawnZ), {
		Color = Color3.fromRGB(60, 190, 90),
		Material = Enum.Material.SmoothPlastic,
	})
	local top = PartUtil.create("CollectorTop", Vector3.new(5, 0.3, 5), part.CFrame * CFrame.new(0, 1.65, 0), {
		Color = Color3.fromRGB(255, 220, 90),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	part.Parent = base.Model
	top.Parent = base.Model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CollectPrompt"
	prompt.ObjectText = "Collector"
	prompt.ActionText = "COLLECT $0"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", 0)
	prompt:AddTag("OwnerOnlyPrompt") -- clients hide it for non-owners
	prompt.Triggered:Connect(function(player)
		if base.Owner ~= player then
			Notifier.send(player, "That's not your collector!", "error")
			return
		end
		IncomeService.collect(player)
	end)
	prompt.Parent = part

	base.CollectorPrompt = prompt
	base.CollectorLabel = HamsterModel.createBillboard(part, "", Vector3.new(0, 4, 0), Vector2.new(160, 50))
end

local function buildBase(index: number)
	local angle = (index - 1) / baseConfig.Count * math.pi * 2
	local position = Vector3.new(math.cos(angle) * baseConfig.RingRadius, GameConfig.Map.GroundY, math.sin(angle) * baseConfig.RingRadius)
	local cframe = CFrame.lookAt(position, Vector3.new(0, position.Y, 0)) -- front (-Z) faces the plaza

	local model = Instance.new("Model")
	model.Name = "Base" .. index
	model:SetAttribute("BaseId", index)
	model:SetAttribute("OwnerUserId", 0)
	model:SetAttribute("OwnerName", "")
	model:SetAttribute("BaseCFrame", cframe)
	model:SetAttribute("BaseSize", baseConfig.Size)

	local slotsFolder = Instance.new("Folder")
	slotsFolder.Name = "Slots"
	slotsFolder.Parent = model

	local base = {
		Id = index,
		Model = model,
		CFrame = cframe,
		Size = baseConfig.Size,
		FloorTop = FLOOR_TOP,
		SlotsFolder = slotsFolder,
		SpawnCFrame = cframe * CFrame.new(0, FLOOR_TOP + 3, baseConfig.SpawnZ),
		Owner = nil,
		Slots = {},
		SecurityLevel = GameConfig.Security.DefaultLevel,
	}

	PartUtil.create("Floor", baseConfig.Size, cframe * CFrame.new(0, baseConfig.Size.Y / 2, 0), {
		Color = Color3.fromRGB(95 + index * 8, 110, 140),
		Material = Enum.Material.Slate,
	}).Parent = model

	PartUtil.create("SpawnPad", Vector3.new(8, 0.2, 8), cframe * CFrame.new(0, FLOOR_TOP + 0.1, baseConfig.SpawnZ), {
		Color = Color3.fromRGB(90, 220, 255),
		Material = Enum.Material.Neon,
		CanCollide = false,
	}).Parent = model

	local signAnchor = PartUtil.create("SignAnchor", Vector3.one, cframe * CFrame.new(0, FLOOR_TOP + 16, 0), {
		Transparency = 1,
		CanCollide = false,
		CanTouch = false,
		CanQuery = false,
	})
	signAnchor.Parent = model
	base.SignLabel = HamsterModel.createBillboard(signAnchor, "", Vector3.zero, Vector2.new(260, 50))
	base.SignLabel.TextSize = 24
	base.SignLabel.Parent.MaxDistance = 600

	buildCollector(base)

	local slotCount = Rebirth.getTier(0).SlotCount
	for slotIndex = 1, slotCount do
		table.insert(base.Slots, buildSlot(base, slotIndex, slotCount))
	end

	SecurityService.build(base)
	refreshSign(base)
	refreshCollector(base)

	model.Parent = Workspace:WaitForChild("Bases")
	return base
end

---------------------------------------------------------------------------
-- Assignment
---------------------------------------------------------------------------

local function moveToBase(player: Player, base)
	local character = player.Character
	if character and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(base.SpawnCFrame)
	end
end

local function claimBase(base, player: Player)
	base.Owner = player
	baseByPlayer[player] = base
	base.Model:SetAttribute("OwnerUserId", player.UserId)
	base.Model:SetAttribute("OwnerName", player.DisplayName)
	base.CollectorPrompt:SetAttribute("OwnerUserId", player.UserId)
	player:SetAttribute("BaseId", base.Id)

	base.StoredConnection = player:GetAttributeChangedSignal("Stored"):Connect(function()
		refreshCollector(base)
	end)

	refreshSign(base)
	refreshCollector(base)
	moveToBase(player, base)
end

local function freeBase(base)
	if base.StoredConnection then
		base.StoredConnection:Disconnect()
		base.StoredConnection = nil
	end
	for _, slot in base.Slots do
		clearSlot(slot)
	end
	base.Owner = nil
	base.Model:SetAttribute("OwnerUserId", 0)
	base.Model:SetAttribute("OwnerName", "")
	base.CollectorPrompt:SetAttribute("OwnerUserId", 0)
	refreshSign(base)
	refreshCollector(base)
end

local function assignFreeBase(player: Player): boolean
	for _, base in bases do
		if base.Owner == nil then
			claimBase(base, player)
			return true
		end
	end
	return false
end

function BaseService.assign(player: Player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			local base = baseByPlayer[player]
			if base then
				moveToBase(player, base)
			end
		end)
	end)

	if not assignFreeBase(player) then
		table.insert(waitingQueue, player)
		Notifier.send(player, "All bases are taken. You'll get one as soon as a player leaves.", "info")
	end
end

function BaseService.release(player: Player)
	local queueIndex = table.find(waitingQueue, player)
	if queueIndex then
		table.remove(waitingQueue, queueIndex)
	end

	local base = baseByPlayer[player]
	if not base then
		return
	end
	baseByPlayer[player] = nil
	freeBase(base)

	while #waitingQueue > 0 do
		local nextPlayer = table.remove(waitingQueue, 1)
		if nextPlayer.Parent == Players and DataService.get(nextPlayer) then
			claimBase(base, nextPlayer)
			Notifier.send(nextPlayer, "A base is free - it's yours now!", "success")
			break
		end
	end
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------

function BaseService.getBaseOf(player: Player)
	return baseByPlayer[player]
end

function BaseService.hasFreeSlot(player: Player): boolean
	local base = baseByPlayer[player]
	return base ~= nil and findFreeSlot(base) ~= nil
end

function BaseService.isInOwnBase(player: Player): boolean
	local base = baseByPlayer[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not base or not root then
		return false
	end
	local relative = base.CFrame:PointToObjectSpace(root.Position)
	return math.abs(relative.X) <= base.Size.X / 2 and math.abs(relative.Z) <= base.Size.Z / 2 and relative.Y < 40
end

-- Puts a hamster into the first free wheel. `existingModel` is used for delivered (carried) hamsters.
function BaseService.placeHamster(player: Player, hamster, existingModel: Model?): boolean
	local base = baseByPlayer[player]
	local slot = base and findFreeSlot(base)
	if not base or not slot then
		return false
	end
	mountHamster(slot, hamster, existingModel or HamsterModel.build(hamster, slot.HamsterCFrame))
	DataService.recompute(player)
	return true
end

function BaseService.getHamsterModel(player: Player, uniqueId: string): Model?
	local base = baseByPlayer[player]
	local slot = base and findSlotByHamster(base, uniqueId)
	return slot and slot.Model
end

-- Steal step 1: take the model out of the wheel but keep the slot reserved for a possible return.
function BaseService.detachHamster(player: Player, uniqueId: string): Model?
	local base = baseByPlayer[player]
	local slot = base and findSlotByHamster(base, uniqueId)
	if not slot or slot.Stolen or not slot.Model then
		return nil
	end
	local model = slot.Model
	slot.Model = nil
	slot.Stolen = true
	CollectionService:RemoveTag(model, "RunningHamster")
	HamsterModel.removeStealPrompt(model)
	slot.Wheel:SetAttribute("SpinSpeed", 0)
	updateSlotDisplay(slot)
	return model
end

-- Failed steal: the hamster goes back into its reserved wheel.
function BaseService.reattachHamster(player: Player, hamster, model: Model): boolean
	local base = baseByPlayer[player]
	local slot = base and findSlotByHamster(base, hamster.UniqueId)
	if not slot or not slot.Stolen then
		return false
	end
	mountHamster(slot, hamster, model)
	DataService.recompute(player)
	return true
end

-- Successful steal: the wheel becomes free for good.
function BaseService.freeSlot(player: Player, uniqueId: string)
	local base = baseByPlayer[player]
	local slot = base and findSlotByHamster(base, uniqueId)
	if slot then
		clearSlot(slot)
	end
end

function BaseService.start()
	local folder = Instance.new("Folder")
	folder.Name = "Bases"
	folder.Parent = Workspace

	for index = 1, baseConfig.Count do
		table.insert(bases, buildBase(index))
	end
end

return BaseService
