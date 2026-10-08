--[[
	Basic stealing prototype. The server owns every step:

	  STEAL prompt -> validate -> hamster becomes "Stolen" and rides on the thief
	  -> thief reaches own base      => ownership transfers
	  -> thief is hit / dies / leaves / times out => hamster goes back to its original wheel

	"Hit" is a simple test interaction: a [F] HIT prompt on the thief that any other player can trigger.
	A real combat system can replace it later by calling StealService.returnToOwner.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)

local Services = script.Parent
local BaseService = require(Services.BaseService)
local DataService = require(Services.DataService)
local HamsterModel = require(Services.HamsterModel)
local Notifier = require(Services.Notifier)

local StealService = {}

local stealConfig = GameConfig.Stealing

-- [thiefPlayer] = { Thief, Owner, Hamster, Model, HitPrompt, DiedConnection, StartedAt }
local carries = {}

local function isPlayerValid(player: Player): boolean
	return player.Parent == Players and DataService.get(player) ~= nil
end

local function getAliveRoot(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and humanoid and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil, nil
end

local function cleanupCarry(carry)
	carries[carry.Thief] = nil
	if carry.DiedConnection then
		carry.DiedConnection:Disconnect()
	end
	if carry.HitPrompt then
		carry.HitPrompt:Destroy()
	end
end

---------------------------------------------------------------------------
-- Outcomes
---------------------------------------------------------------------------

-- Failed steal: hamster goes back to its original owner.
function StealService.returnToOwner(thief: Player, reason: string)
	local carry = carries[thief]
	if not carry then
		return
	end
	cleanupCarry(carry)

	local hamster = carry.Hamster
	hamster.State = "Owned"
	hamster.CarrierUserId = nil
	hamster.OriginalOwnerUserId = nil

	local owner = carry.Owner
	if isPlayerValid(owner) and BaseService.reattachHamster(owner, hamster, carry.Model) then
		DataService.recompute(owner)
		Notifier.send(owner, string.format("%s was returned to your wheel!", hamster.Name), "success")
	else
		carry.Model:Destroy()
	end
	Notifier.send(thief, reason, "error")
end

-- Successful steal: ownership transfers to the thief.
local function deliver(thief: Player)
	local carry = carries[thief]
	if not carry then
		return
	end

	if not BaseService.hasFreeSlot(thief) then
		StealService.returnToOwner(thief, "No free wheel in your base - the hamster went back!")
		return
	end
	cleanupCarry(carry)

	local hamster = carry.Hamster
	local owner = carry.Owner
	if isPlayerValid(owner) then
		DataService.removeHamster(owner, hamster.UniqueId)
		BaseService.freeSlot(owner, hamster.UniqueId)
		Notifier.send(owner, string.format("%s stole your %s!", thief.DisplayName, hamster.Name), "error")
	end

	hamster.CarrierUserId = nil
	hamster.OriginalOwnerUserId = nil
	DataService.addHamster(thief, hamster) -- sets OwnerUserId + State = "Owned"
	BaseService.placeHamster(thief, hamster, carry.Model)
	Notifier.send(thief, string.format("You stole %s %s!", hamster.Rarity, hamster.Name), "success")
end

---------------------------------------------------------------------------
-- Triggers
---------------------------------------------------------------------------

local function onHitRequested(hitter: Player, thief: Player)
	local carry = carries[thief]
	if not carry or hitter == thief then
		return
	end
	if stealConfig.OnlyOwnerCanHit and hitter ~= carry.Owner then
		return
	end

	local hitterRoot = getAliveRoot(hitter)
	local thiefRoot = getAliveRoot(thief)
	if not hitterRoot or not thiefRoot then
		return
	end
	if (hitterRoot.Position - thiefRoot.Position).Magnitude > stealConfig.HitMaxDistance then
		return
	end

	Notifier.send(hitter, "Hit! The hamster went back.", "success")
	StealService.returnToOwner(thief, string.format("%s hit you - the hamster went back!", hitter.DisplayName))
end

function StealService.onStealRequested(thief: Player, uniqueId: string)
	if type(uniqueId) ~= "string" or carries[thief] then
		return
	end
	if not DataService.get(thief) or not BaseService.getBaseOf(thief) then
		return
	end
	local thiefRoot, thiefHumanoid = getAliveRoot(thief)
	if not thiefRoot or not thiefHumanoid then
		return
	end

	local owner, hamster = DataService.getHamsterOwner(uniqueId)
	if not owner or owner == thief or hamster.State ~= "Owned" then
		return
	end

	local hamsterModel = BaseService.getHamsterModel(owner, uniqueId)
	if not hamsterModel or not hamsterModel.PrimaryPart then
		return
	end
	if (hamsterModel.PrimaryPart.Position - thiefRoot.Position).Magnitude > stealConfig.MaxDistance then
		return
	end
	if not BaseService.hasFreeSlot(thief) then
		Notifier.send(thief, "You need a free wheel in your own base first!", "error")
		return
	end

	local model = BaseService.detachHamster(owner, uniqueId)
	if not model then
		return
	end

	hamster.State = "Stolen"
	hamster.CarrierUserId = thief.UserId
	hamster.OriginalOwnerUserId = owner.UserId
	DataService.recompute(owner)

	local character = thief.Character :: Model
	HamsterModel.attachToCharacter(model, character)

	local hitPrompt = Instance.new("ProximityPrompt")
	hitPrompt.Name = "HitPrompt"
	hitPrompt.ObjectText = "Thief carrying " .. hamster.Name
	hitPrompt.ActionText = "HIT"
	hitPrompt.KeyboardKeyCode = Enum.KeyCode.F
	hitPrompt.HoldDuration = 0
	hitPrompt.MaxActivationDistance = 12
	hitPrompt.RequiresLineOfSight = false
	hitPrompt:SetAttribute("CarrierUserId", thief.UserId)
	hitPrompt:AddTag("HitPrompt") -- clients hide it for the thief
	hitPrompt.Triggered:Connect(function(hitter)
		onHitRequested(hitter, thief)
	end)
	hitPrompt.Parent = thiefRoot

	carries[thief] = {
		Thief = thief,
		Owner = owner,
		Hamster = hamster,
		Model = model,
		HitPrompt = hitPrompt,
		DiedConnection = thiefHumanoid.Died:Connect(function()
			StealService.returnToOwner(thief, "You were stopped - the hamster went back!")
		end),
		StartedAt = os.clock(),
	}

	Notifier.send(thief, "Run to your base with the hamster!", "info")
	Notifier.send(owner, string.format("%s is stealing your %s!", thief.DisplayName, hamster.Name), "error")
end

---------------------------------------------------------------------------
-- Lifecycle
---------------------------------------------------------------------------

-- Called by Main BEFORE the player's base and data are removed.
function StealService.onPlayerLeaving(player: Player)
	-- The leaving player was carrying a hamster -> it goes home.
	if carries[player] then
		StealService.returnToOwner(player, "")
	end
	-- The leaving player was being robbed -> the stolen hamster is gone with them.
	for _, carry in carries do
		if carry.Owner == player then
			cleanupCarry(carry)
			carry.Model:Destroy()
			Notifier.send(carry.Thief, "The owner left - the hamster vanished.", "info")
		end
	end
end

function StealService.start()
	BaseService.setStealHandler(StealService.onStealRequested)

	task.spawn(function()
		while true do
			task.wait(stealConfig.CheckIntervalSeconds)
			local thieves = {}
			for thief in carries do
				table.insert(thieves, thief)
			end
			for _, thief in thieves do
				local carry = carries[thief]
				if carry then
					if not isPlayerValid(thief) or not getAliveRoot(thief) then
						StealService.returnToOwner(thief, "You were stopped - the hamster went back!")
					elseif os.clock() - carry.StartedAt > stealConfig.CarryTimeoutSeconds then
						StealService.returnToOwner(thief, "Too slow - the hamster went back!")
					elseif BaseService.isInOwnBase(thief) then
						deliver(thief)
					end
				end
			end
		end
	end)
end

return StealService
