--[[
	TheftSystem: stealing a hamster from a wheel in somebody else's open base ("rack theft").
	It reuses the existing carry machinery of HamsterSystem (the stolen hamster becomes a carried ball whose payer is
	the OWNER), so slaps, drops, recovery, the secure pad and the HUD tracker all work unchanged. This module adds:

	  begin      validates a prompt hold and starts the theft (nothing is saved, the hamster stays in the owner's data)
	  settle     the ball reached a pad: the thief's own pad -> transfer, the owner's pad -> back home
	  fail       owner hit the thief / timeout / owner reborn / thief or owner gone: nothing changes, the wheel is shown again
	  trap       the gate was switched on with a carrying thief inside: they are held inside (no zap, no exit) until
	             the owner hits them, the gate switches off or EscapeTimeout runs out (then the theft fails and they
	             are put outside) - nobody stays trapped for ever
	Security: every decision is made here from server state; the client only asks "I held the prompt".
	The transfer is one synchronous block (remove from owner, then grant to thief): it can never run twice because
	`Settled` is set first, and a failed grant rolls the removal back.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local HamsterDatabase = require(Modules.HamsterDatabase)
local TheftConfig = require(Modules.TheftConfig)
local WorldLayout = require(Modules.WorldLayout)

local Remotes = require(ReplicatedStorage.Remotes)

local AnnounceSystem = require(script.Parent.AnnounceSystem)
local CollectionSystem = require(script.Parent.CollectionSystem)
local CombatSystem = require(script.Parent.CombatSystem)
local DataSystem = require(script.Parent.DataSystem)
local Events = require(script.Parent.Events)
local HamsterSystem = require(script.Parent.HamsterSystem)
local HouseSystem = require(script.Parent.HouseSystem)
local Notifier = require(script.Parent.Notifier)
local PlayerState = require(script.Parent.PlayerState)
local ReplicationSystem = require(script.Parent.ReplicationSystem)
local SecuritySystem = require(script.Parent.SecuritySystem)
local TheftState = require(script.Parent.TheftState)

local TheftSystem = {}

local active: { [string]: any } = {} -- theft id -> theft
local counter = 0
local lastAttempt: { [Player]: number } = {}
local joinedAt: { [Player]: number } = {}

---------------------------------------------------------------------------
-- prompts on the wheels
---------------------------------------------------------------------------

-- Is the hamster on this wheel stealable right now? Returns (available, species?).
function TheftSystem.slotInfo(house: any, index: number): (boolean, any?)
	local owner = house.Owner
	if not owner or owner.Parent ~= Players then
		return false, nil
	end
	local data = DataSystem.get(owner)
	if not data then
		return false, nil
	end
	local slot = house.Slots[index]
	if not slot or not TheftConfig.floorStealable(slot.Floor) then
		return false, nil
	end
	local speciesId = data.Equipped[index]
	local species = if speciesId then HamsterDatabase.ById[speciesId] else nil
	if not species or index > require(Modules.EconomyMath).slots(data) then
		return false, nil
	end
	if TheftState.slotLocked(owner.UserId, index) or not TheftConfig.eligible(species) then
		return false, species
	end
	if SecuritySystem.status(house) == "Active" then
		return false, species
	end
	if os.clock() - (joinedAt[owner] or 0) < TheftConfig.OwnerProtectionSeconds then
		return false, species
	end
	return true, species
end

function TheftSystem.refreshHouse(house: any)
	for index, prompt in house.TheftPrompts do
		local available, species = TheftSystem.slotInfo(house, index)
		prompt.Enabled = available
		prompt:SetAttribute("Available", available)
		prompt:SetAttribute("OwnerUserId", if house.Owner then house.Owner.UserId else 0)
		prompt.ObjectText = if species then species.Name else "Wheel"
		prompt.ActionText = "Steal hamster"
	end
end

local function refreshOwner(owner: Player)
	local house = HouseSystem.getHouse(owner)
	if house then
		TheftSystem.refreshHouse(house)
	end
end

---------------------------------------------------------------------------
-- begin
---------------------------------------------------------------------------

function TheftSystem.begin(thief: Player, houseIndex: any, slotIndex: any): (boolean, string)
	if type(houseIndex) ~= "number" or type(slotIndex) ~= "number" or slotIndex % 1 ~= 0 then
		return false, "Invalid"
	end
	local house = HouseSystem.all()[houseIndex]
	local thiefData = DataSystem.get(thief)
	local humanoid, root = PlayerState.character(thief)
	if not house or not thiefData or not humanoid or not root then
		return false, "You can't do that right now"
	end
	local owner = house.Owner
	if not owner or owner == thief or owner.Parent ~= Players then
		return false, "Nobody to steal from"
	end
	if PlayerState.isStunned(thief) or HamsterSystem.isChanneling(thief) then
		return false, "You can't steal right now"
	end
	if HamsterSystem.carriedBy(thief) then
		return false, "You're already carrying a hamster!"
	end
	if not HouseSystem.getHouse(thief) then
		return false, "You need a house of your own first"
	end
	local clock = os.clock()
	if (lastAttempt[thief] or 0) + TheftConfig.ThiefCooldown > clock then
		return false, "Not so fast"
	end
	local available, species = TheftSystem.slotInfo(house, slotIndex)
	if not available or not species then
		if SecuritySystem.status(house) == "Active" then
			Notifier.send(thief, "The gate is locked - you can't steal from this base!", "error")
		end
		return false, "That hamster can't be stolen right now"
	end
	local slot = house.Slots[slotIndex]
	if (root.Position - slot.RunCFrame.Position).Magnitude > TheftConfig.MaxDistance or not WorldLayout.inLot(house.CFrame, root.Position, 4) then
		return false, "Too far from the wheel"
	end
	lastAttempt[thief] = clock

	counter += 1
	local theft = {
		Id = "t" .. counter,
		Owner = owner,
		Thief = thief,
		Slot = slotIndex,
		SpeciesId = species.Id,
		HouseIndex = house.Index,
		Started = clock,
		Settled = false,
	}
	-- lock the wheel first (the hamster disappears from the wheel), then create the carried ball
	TheftState.locks[owner.UserId] = TheftState.locks[owner.UserId] or {}
	TheftState.locks[owner.UserId][slotIndex] = species.Id
	active[theft.Id] = theft
	local entity = HamsterSystem.spawnStolen(species, owner, thief, slot.RunCFrame.Position, theft)
	if not entity then
		TheftState.locks[owner.UserId][slotIndex] = nil
		active[theft.Id] = nil
		return false, "You can't carry it"
	end
	theft.Entity = entity
	HouseSystem.queueDisplay(owner)
	refreshOwner(owner)
	Notifier.send(thief, string.format("You grabbed %s from %s's wheel! Run it to YOUR house - and don't get hit!", species.Name, owner.DisplayName), "success")
	Notifier.send(owner, string.format("THEFT! %s is stealing your %s! Hit them (Q) to get it back.", thief.DisplayName, species.Name), "error")
	return true, "Stealing"
end

---------------------------------------------------------------------------
-- ending a theft
---------------------------------------------------------------------------

local function unlock(theft: any)
	local locks = TheftState.locks[theft.Owner.UserId]
	if locks and locks[theft.Slot] == theft.SpeciesId then
		locks[theft.Slot] = nil
		if next(locks) == nil then
			TheftState.locks[theft.Owner.UserId] = nil
		end
	end
	active[theft.Id] = nil
	TheftState.trapped[theft.Thief] = nil
	if theft.Owner.Parent == Players then
		HouseSystem.queueDisplay(theft.Owner)
		refreshOwner(theft.Owner)
	end
end

local function speciesName(theft: any): string
	local species = HamsterDatabase.ById[theft.SpeciesId]
	return if species then species.Name else "hamster"
end

-- Failed theft: nothing was ever changed in the data, the wheel just shows the hamster again.
local function fail(theft: any, reason: string)
	if theft.Settled then
		return
	end
	theft.Settled = true
	local name = speciesName(theft)
	local owner, thief = theft.Owner, theft.Thief
	local position = if theft.Entity then theft.Entity.Position else nil
	unlock(theft)
	if position then
		Remotes.event("Fx"):FireAllClients("TheftFailed", "", position, nil)
	end
	local thiefData = DataSystem.get(thief)
	if reason == "Hit" then
		if thief.Parent == Players then
			Notifier.send(thief, string.format("THEFT FAILED! %s hit you - %s went back to its owner.", owner.DisplayName, name), "error")
		end
		if owner.Parent == Players then
			Notifier.send(owner, string.format("THEFT STOPPED! %s is back on its wheel.", name), "success")
		end
	elseif reason == "Timeout" then
		if thief.Parent == Players then
			Notifier.send(thief, "THEFT FAILED! The gate stayed locked too long - you were put outside.", "error")
		end
		if owner.Parent == Players then
			Notifier.send(owner, string.format("The thief got stuck - %s is safe.", name), "info")
		end
	elseif reason == "Returned" or reason == "Lost" then
		if owner.Parent == Players then
			Notifier.send(owner, string.format("Your %s is back home.", name), "success")
		end
		if thief.Parent == Players then
			Notifier.send(thief, "THEFT FAILED! The hamster went back to its owner.", "error")
		end
	elseif reason == "PayerLeft" then
		if thief.Parent == Players then
			Notifier.send(thief, "The owner left - the theft was cancelled.", "info")
		end
	elseif reason ~= "ThiefLeft" then
		if thief.Parent == Players then
			Notifier.send(thief, "THEFT FAILED! " .. name .. " is safe.", "error")
		end
	end
	if reason == "Hit" and owner.Parent == Players then
		local ownerData = DataSystem.get(owner)
		if ownerData then
			ownerData.Stats.TheftsStopped = (ownerData.Stats.TheftsStopped or 0) + 1
			ReplicationSystem.mark(owner, "Stats")
		end
	end
	if thiefData and reason ~= "ThiefLeft" and reason ~= "PayerLeft" then
		thiefData.Stats.TheftsFailed = (thiefData.Stats.TheftsFailed or 0) + 1
		ReplicationSystem.mark(thief, "Stats")
	end
	Events.TheftFailed:Fire(thief, owner, theft.SpeciesId, reason)
end

-- Called by HamsterSystem when the ball of a theft reaches a pad: returns "Stolen" or "Returned".
local function settle(e: any, player: Player): string
	local theft = e.Theft
	if theft.Settled then
		return "Returned"
	end
	local owner = theft.Owner
	if player == owner then
		fail(theft, "Returned")
		return "Returned"
	end

	-- transfer: the owner must still be here and still own the hamster
	local ownerData = if owner.Parent == Players then DataSystem.get(owner) else nil
	local thiefData = DataSystem.get(player)
	local speciesId = theft.SpeciesId
	if not ownerData or not thiefData or (ownerData.Inventory[speciesId] or 0) < 1 then
		fail(theft, "Returned")
		return "Returned"
	end
	theft.Settled = true -- from here on this theft can never settle again

	-- 1. take it from the owner (inventory + the wheel it ran on)
	ownerData.Inventory[speciesId] -= 1
	if ownerData.Inventory[speciesId] <= 0 then
		ownerData.Inventory[speciesId] = nil
	end
	local equippedAt = table.find(ownerData.Equipped, speciesId)
	local removedFromWheel = false
	if equippedAt then
		table.remove(ownerData.Equipped, equippedAt)
		removedFromWheel = true
	end
	-- 2. give it to the thief; if that fails put everything back
	local result = CollectionSystem.grant(player, speciesId, "Collect")
	if not result then
		ownerData.Inventory[speciesId] = (ownerData.Inventory[speciesId] or 0) + 1
		if removedFromWheel then
			table.insert(ownerData.Equipped, equippedAt :: number, speciesId)
		end
		theft.Settled = false
		fail(theft, "Returned")
		return "Returned"
	end
	ownerData.Stats.TimesRobbed = (ownerData.Stats.TimesRobbed or 0) + 1
	thiefData.Stats.Stolen = (thiefData.Stats.Stolen or 0) + 1
	thiefData.Stats.Secured = (thiefData.Stats.Secured or 0) + 1
	ReplicationSystem.mark(owner, "Inventory", "Equipped", "Stats")
	ReplicationSystem.mark(player, "Stats")
	DataSystem.markDirty(owner)
	DataSystem.markDirty(player)
	Events.EquippedChanged:Fire(owner)

	local species = HamsterDatabase.ById[speciesId]
	unlock(theft)
	Remotes.event("CollectResult"):FireClient(player, true, e.Id, speciesId, result.IsNew, if result.AutoSold then "AutoSold" else "")
	Notifier.send(player, string.format("THEFT COMPLETE! %s is yours now.", species.Name), "success")
	Notifier.send(owner, string.format("%s stole your %s!", player.DisplayName, species.Name), "error")
	AnnounceSystem.stolenSecured(player, owner, species)
	Events.TheftCompleted:Fire(player, owner, speciesId)
	-- save both profiles soon (a crash between the two saves loses the hamster rather than duplicating it)
	task.spawn(function()
		DataSystem.save(owner)
		DataSystem.save(player)
	end)
	return "Stolen"
end

---------------------------------------------------------------------------
-- hits, trapping, cleanup
---------------------------------------------------------------------------

-- The owner hit the thief: the theft fails right now. Returns true when it did.
function TheftSystem.ownerHit(attacker: Player, target: Player): boolean
	local e = HamsterSystem.carriedBy(target)
	local theft = e and e.Theft
	if not theft or theft.Owner ~= attacker or theft.Settled then
		return false
	end
	HamsterSystem.endTheft(e :: any, "Hit")
	return true
end

local function eject(thief: Player, house: any)
	local character = thief.Character
	if character then
		character:PivotTo(house.CFrame * CFrame.new(0, 4, -8) * CFrame.Angles(0, math.pi, 0))
	end
end

local function trapThieves(house: any)
	for _, theft in active do
		if theft.HouseIndex == house.Index and not theft.Settled then
			local thief = theft.Thief
			local e = HamsterSystem.carriedBy(thief)
			local _, root = PlayerState.character(thief)
			if e and e.Theft == theft and root and WorldLayout.inLot(house.CFrame, root.Position, 0) then
				TheftState.trapped[thief] = { HouseIndex = house.Index, Until = os.clock() + TheftConfig.EscapeTimeout, LastInside = root.CFrame, NextNotice = 0 }
				Notifier.send(thief, "The gate just locked! You're trapped - hide, or wait until it opens.", "error")
			end
		end
	end
end

local function trapTick()
	local clock = os.clock()
	for thief, trap in TheftState.trapped do
		local house = HouseSystem.all()[trap.HouseIndex]
		local e = HamsterSystem.carriedBy(thief)
		local _, root = PlayerState.character(thief)
		if thief.Parent ~= Players or not house or not e or not e.Theft or e.Theft.HouseIndex ~= trap.HouseIndex then
			TheftState.trapped[thief] = nil
		elseif SecuritySystem.status(house) ~= "Active" then
			TheftState.trapped[thief] = nil -- the gate opened: a valid exit
			Notifier.send(thief, "The gate opened - RUN!", "success")
		elseif clock >= trap.Until then
			TheftState.trapped[thief] = nil
			HamsterSystem.endTheft(e, "Timeout")
			eject(thief, house)
		elseif root then
			if WorldLayout.inLot(house.CFrame, root.Position, -TheftConfig.LeashMargin) then
				trap.LastInside = root.CFrame
			else
				-- walking out through a closed gate: put them back where they last were inside
				if trap.LastInside then
					(thief.Character :: Model):PivotTo(trap.LastInside)
				end
				if clock >= trap.NextNotice then
					trap.NextNotice = clock + 2
					Notifier.send(thief, "The gate is locked - you can't leave yet!", "error")
				end
			end
		end
	end
end

-- Rebirth reset the owner's collection: any running theft of their hamsters is cancelled.
local function cancelOwner(owner: Player, reason: string)
	for _, theft in active do
		if theft.Owner == owner and theft.Entity then
			HamsterSystem.endTheft(theft.Entity, reason)
		end
	end
end

function TheftSystem.activeCount(): number
	local n = 0
	for _ in active do
		n += 1
	end
	return n
end

function TheftSystem.start()
	CombatSystem.theftHook = TheftSystem.ownerHit
	HamsterSystem.Hooks.Settle = settle
	HamsterSystem.Hooks.Aborted = function(e, reason)
		local theft = e.Theft
		if theft and not theft.Settled then
			fail(theft, reason)
		end
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local slot = prompt:GetAttribute("TheftSlot")
		if type(slot) ~= "number" then
			return
		end
		local ok, message = TheftSystem.begin(player, prompt:GetAttribute("HouseIndex"), slot)
		if not ok and message ~= "Not so fast" then
			Notifier.send(player, message, "error")
		end
	end)

	Events.GateChanged:Connect(function(house, status)
		if status == "Active" then
			trapThieves(house)
		end
		TheftSystem.refreshHouse(house)
	end)
	Events.EquippedChanged:Connect(refreshOwner)
	Events.Collected:Connect(refreshOwner)
	Events.HouseClaimed:Connect(function(house)
		TheftSystem.refreshHouse(house)
	end)
	Events.HouseFreed:Connect(function(house)
		TheftSystem.refreshHouse(house)
	end)
	Events.Rebirthed:Connect(function(player)
		cancelOwner(player, "Rebirth")
	end)
	Events.ProfileLoaded:Connect(function(player)
		joinedAt[player] = os.clock()
		task.delay(TheftConfig.OwnerProtectionSeconds + 0.5, function()
			if player.Parent == Players then
				refreshOwner(player)
			end
		end)
	end)

	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(trapTick)
			if not ok then
				warn("[TheftSystem] " .. tostring(err))
			end
		end
	end)
end

function TheftSystem.forget(player: Player)
	lastAttempt[player] = nil
	joinedAt[player] = nil
	TheftState.trapped[player] = nil
	-- a thief who leaves: the hamster goes straight back to its owner (never stuck in limbo)
	for _, theft in active do
		if theft.Thief == player and theft.Entity then
			HamsterSystem.endTheft(theft.Entity, "ThiefLeft")
		end
	end
end

return TheftSystem
