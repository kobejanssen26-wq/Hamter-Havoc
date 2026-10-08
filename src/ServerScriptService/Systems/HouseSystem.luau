--[[
	HouseSystem: gives every player a house and keeps it in sync with their progress.

	What a house shows (all driven by the player's profile):
	  - gate name plate + roof sign: name, rebirths, index progress, best hamster
	  - rebirth stars on the gate canopy
	  - the apartment's floors (FloorConfig, unlocked by rebirths) + scaffolding for the next floor
	  - up to 30 hamster wheels (6 per floor): every working hamster runs on its own wheel, the best
	    ones on the floors with the biggest bonus (EconomyMath.assignment)
	  - upgrade pedestals whose props grow with every upgrade level (advanced ones in the lab)
	  - accent colour (cosmetic) and premium facade details at high rebirths
	  - the lift between floors (anyone may ride it)
	More than 10 players: extra players wait in a queue; they can still play (income, collecting) and
	get a house as soon as one frees up.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local EconomyMath = require(Modules.EconomyMath)
local FloorConfig = require(Modules.FloorConfig)
local Format = require(Modules.Format)
local HamsterBuilder = require(Modules.HamsterBuilder)
local HamsterDatabase = require(Modules.HamsterDatabase)
local IndexRewardConfig = require(Modules.IndexRewardConfig)
local RarityConfig = require(Modules.RarityConfig)
local ShopConfig = require(Modules.ShopConfig)
local UpgradeConfig = require(Modules.UpgradeConfig)

local DataSystem = require(script.Parent.DataSystem)
local Events = require(script.Parent.Events)
local Build = require(script.Parent.WorldBuilder.Build)
local HouseBuilder = require(script.Parent.WorldBuilder.HouseBuilder)
local Notifier = require(script.Parent.Notifier)
local PlayerState = require(script.Parent.PlayerState)

local HouseSystem = {}

local MAX_DISPLAY_HEIGHT = 2.5 -- a hamster has to fit inside its wheel (radius 3)
local WHEEL_SPIN = 2.6 -- rad/s: the wheel's surface speed (7.8 studs/s) matches the run animation
local RUN_SPEED = 7.8 -- animation speed of the running hamster

local houses: { HouseBuilder.House } = {}
local houseByPlayer: { [Player]: HouseBuilder.House } = {}
local waiting: { Player } = {}
local pending: { [Player]: boolean } = {}

---------------------------------------------------------------------------
-- refresh helpers
---------------------------------------------------------------------------

local function bestHamster(data: any): any?
	local best = nil
	local bestIncome = -1
	for speciesId, count in data.Inventory do
		local species = HamsterDatabase.ById[speciesId]
		if species and count > 0 then
			local income = HamsterDatabase.income(species)
			if income > bestIncome then
				best = species
				bestIncome = income
			end
		end
	end
	return best
end

local function refreshSign(house: HouseBuilder.House, player: Player?)
	local data = if player then DataSystem.get(player) else nil
	if not player or not data then
		house.Labels.Name.Text = "FREE APARTMENT"
		house.Labels.Stats.Text = "Waiting for a new neighbour"
		house.Labels.Best.Text = ""
		house.Labels.Roof.Text = '<font color="#ffffff">Free house</font>'
		house.Model:SetAttribute("OwnerUserId", 0)
		house.Model:SetAttribute("OwnerName", "")
		return
	end

	local best = bestHamster(data)
	local rebirthText = if data.Rebirths > 0 then string.format("Rebirth %d", data.Rebirths) else "New home"
	house.Labels.Name.Text = string.format("%s's Apartment", player.DisplayName)
	house.Labels.Stats.Text = string.format("%s  -  %d floor%s  -  %d/%d found", rebirthText, house.FloorCount, if house.FloorCount == 1 then "" else "s", EconomyMath.uniqueCount(data), HamsterDatabase.Total)
	if best then
		local definition = RarityConfig.ById[best.Rarity]
		local name = if definition.Hidden then "???" else best.Name
		house.Labels.Best.Text = string.format('Best: %s <font color="#%s">(%s)</font>', name, definition.Accent:ToHex(), definition.Name)
	else
		house.Labels.Best.Text = "Best: -"
	end
	local title = IndexRewardConfig.title(data)
	house.Labels.Roof.Text = string.format("<b>%s</b>%s%s", player.DisplayName, if data.Rebirths > 0 then "  -  Rebirth " .. data.Rebirths else "", if title then '\n<font color="#FFD866">' .. title .. "</font>" else "")
	house.Model:SetAttribute("OwnerUserId", player.UserId)
	house.Model:SetAttribute("OwnerName", player.DisplayName)
	HouseBuilder.setStars(house, math.min(data.Rebirths, 10))
end

local function refreshStations(house: HouseBuilder.House, data: any?)
	for _, upgradeId in UpgradeConfig.Order do
		if house.Stations[upgradeId] then
			local level = if data then (data.Upgrades[upgradeId] or 0) else 0
			HouseBuilder.setStation(house, upgradeId, level)
		end
	end
end

local function refreshRoof(house: HouseBuilder.House, data: any?)
	local color = house.DefaultRoof
	if data then
		local roof = ShopConfig.RoofByKey[data.Cosmetics.Roof]
		if roof then
			color = roof.Color
		end
	end
	HouseBuilder.setRoofColor(house, color)
end

-- Label above a running hamster: its name and what it earns per second on this wheel.
local function wheelText(species: any, data: any, bonus: number): string
	local definition = RarityConfig.ById[species.Rarity]
	local name = if definition.Hidden then "???" else species.Name
	local perSecond = EconomyMath.hamsterIncome(data, species, bonus, os.time())
	return string.format('<font color="#%s"><b>%s</b></font>\n<font color="#FFE08A">+%s/s</font>', definition.Color:ToHex(), name, Format.coins(perSecond))
end

local function assignmentBySlot(data: any?): { [number]: EconomyMath.Assignment }
	local bySlot = {}
	if data then
		for _, entry in EconomyMath.assignment(data) do
			bySlot[entry.Slot] = entry
		end
	end
	return bySlot
end

local function refreshWheelLabels(house: HouseBuilder.House, data: any?)
	if not data then
		return
	end
	local bySlot = assignmentBySlot(data)
	for slotIndex, entry in house.DisplayModels do
		local slot = house.Slots[slotIndex]
		local species = HamsterDatabase.ById[entry.SpeciesId]
		local bonus = if bySlot[slotIndex] then bySlot[slotIndex].Bonus else 0
		entry.Model:SetAttribute("Income", EconomyMath.hamsterIncome(data, species, bonus, os.time()))
		if slot and slot.Label then
			slot.Label.Text = wheelText(species, data, bonus)
		end
	end
end

-- Lift prompts say where they go: up to the next floor, from the top back down to the lobby.
local function refreshLift(house: HouseBuilder.House)
	for floor, prompt in house.ElevatorPrompts do
		local target = if floor < house.FloorCount then floor + 1 else 1
		prompt.ObjectText = string.format("Lift  -  Floor %d", floor)
		prompt.ActionText = if target == 1 then "Down to the lobby" else string.format("Up to Floor %d", target)
	end
end

-- Floors follow the owner's rebirths; a free house shows only the ground floor.
local function refreshFloors(house: HouseBuilder.House, data: any?)
	local floors = if data then EconomyMath.floors(data) else 1
	local rebirths = if data then data.Rebirths else 0
	if house.FloorCount ~= floors or house.Model:GetAttribute("ShowsNext") ~= (data ~= nil) then
		HouseBuilder.setFloors(house, floors, data ~= nil)
		house.Model:SetAttribute("ShowsNext", data ~= nil)
		refreshLift(house)
	end
	if house.Prestige ~= rebirths then
		HouseBuilder.setPrestige(house, rebirths)
	end
end

local function refreshDisplay(house: HouseBuilder.House, data: any?)
	refreshFloors(house, data)
	local slots = if data then EconomyMath.slots(data) else 0
	local active = {}
	for position, slotIndex in FloorConfig.fillOrder(house.FloorCount) do
		if position <= slots then
			active[slotIndex] = true
		end
	end
	local bySlot = assignmentBySlot(data)

	-- pool the existing models by species so unchanged hamsters just stay where they run
	local pool: { [string]: { Model } } = {}
	for _, entry in house.DisplayModels do
		pool[entry.SpeciesId] = pool[entry.SpeciesId] or {}
		table.insert(pool[entry.SpeciesId], entry.Model)
	end
	local result: { [number]: { SpeciesId: string, Model: Model } } = {}

	for index, slot in house.Slots do
		local unlocked = active[index] == true
		HouseBuilder.setWheel(house, index, unlocked)
		local entry = bySlot[index]
		local species = if entry then HamsterDatabase.ById[entry.SpeciesId] else nil
		if species and entry and data then
			local model = nil
			local candidates = pool[entry.SpeciesId]
			if candidates and #candidates > 0 then
				model = table.remove(candidates)
			else
				local scale = math.min(0.62, MAX_DISPLAY_HEIGHT / (3.4 * (species.Size or 1)))
				model = HamsterBuilder.build(species, { Scale = scale, LowDetail = true, Particles = false })
				model:AddTag("WheelHamster")
				model:SetAttribute("RunSpeed", RUN_SPEED)
				model.Parent = house.DisplayFolder
			end
			model:SetAttribute("Income", EconomyMath.hamsterIncome(data, species, entry.Bonus, os.time()))
			model:PivotTo(slot.RunCFrame)
			result[index] = { SpeciesId = entry.SpeciesId, Model = model }
			HouseBuilder.setWheelSpeed(slot, WHEEL_SPIN)

			if not slot.Label then
				slot.Label = Build.billboard(slot.LabelAnchor, "", Vector2.new(150, 40), Vector3.zero, { MaxDistance = 30, Name = "WheelIncome" })
			end
			slot.Label.Text = wheelText(species, data, entry.Bonus)

			local definition = RarityConfig.ById[species.Rarity]
			slot.Ring.Color = if definition.Hidden then definition.Accent else definition.Color
			slot.Ring.Transparency = 0.45
		else
			HouseBuilder.setWheelSpeed(slot, 0)
			if slot.Label then
				slot.Label.Text = if unlocked or not data then "" else '<font color="#B8B0C8">Locked: more slots with Rebirth</font>'
			elseif data and not unlocked then
				slot.Label = Build.billboard(slot.LabelAnchor, '<font color="#B8B0C8">Locked: more slots with Rebirth</font>', Vector2.new(150, 40), Vector3.zero, { MaxDistance = 30, Name = "WheelIncome" })
			end
			slot.Ring.Color = if unlocked then Color3.fromRGB(200, 190, 170) else Color3.fromRGB(70, 60, 70)
			slot.Ring.Transparency = if unlocked then 0.5 else 0.8
		end
	end

	for _, models in pool do
		for _, model in models do
			model:Destroy()
		end
	end
	house.DisplayModels = result
end

local function refreshAll(house: HouseBuilder.House, player: Player?)
	local data = if player then DataSystem.get(player) else nil
	house.Owner = player
	refreshSign(house, player)
	refreshDisplay(house, data) -- builds the floors first (stations of upper floors live there)
	refreshStations(house, data)
	refreshRoof(house, data)
	local userId = if player then player.UserId else 0
	for _, prompt in house.Prompts do
		prompt:SetAttribute("OwnerUserId", userId)
	end
end

-- Several changes in the same frame are merged into one refresh.
local function queueDisplay(player: Player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.defer(function()
		pending[player] = nil
		local house = houseByPlayer[player]
		local data = DataSystem.get(player)
		if house and data then
			local floorsBefore = house.FloorCount
			refreshDisplay(house, data)
			refreshSign(house, player)
			if house.FloorCount ~= floorsBefore then
				refreshAll(house, player)
			end
		end
	end)
end

---------------------------------------------------------------------------
-- assignment
---------------------------------------------------------------------------

local function claim(house: HouseBuilder.House, player: Player)
	house.Owner = player
	houseByPlayer[player] = house
	refreshAll(house, player)
	player:SetAttribute("HouseId", house.Index)
	Events.HouseClaimed:Fire(house, player)
end

function HouseSystem.assign(player: Player)
	if houseByPlayer[player] then
		return
	end
	for _, house in houses do
		if house.Owner == nil then
			claim(house, player)
			return
		end
	end
	table.insert(waiting, player)
	Notifier.send(player, "All houses are taken - you'll get one when a neighbour leaves. You can still play!", "info")
end

function HouseSystem.release(player: Player)
	local queued = table.find(waiting, player)
	if queued then
		table.remove(waiting, queued)
	end
	pending[player] = nil

	local house = houseByPlayer[player]
	if not house then
		return
	end
	houseByPlayer[player] = nil
	house.Owner = nil
	refreshAll(house, nil)
	Events.HouseFreed:Fire(house)

	while #waiting > 0 do
		local nextPlayer = table.remove(waiting, 1)
		if nextPlayer and nextPlayer.Parent == Players and DataSystem.isLoaded(nextPlayer) then
			claim(house, nextPlayer)
			Notifier.send(nextPlayer, "A house is free - it's yours now!", "success")
			HouseSystem.moveToHouse(nextPlayer)
			break
		end
	end
end

function HouseSystem.getHouse(player: Player): HouseBuilder.House?
	return houseByPlayer[player]
end

function HouseSystem.all(): { HouseBuilder.House }
	return houses
end

function HouseSystem.moveToHouse(player: Player)
	local house = houseByPlayer[player]
	local character = player.Character
	if house and character and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(house.SpawnCFrame)
	end
end

-- The lift: up one floor, from the top floor back down to the lobby. Anyone may ride it (secured
-- hamsters can't be stolen, and the security gate still guards the plot itself).
function HouseSystem.ride(player: Player, prompt: ProximityPrompt, houseIndex: number)
	local house = houses[houseIndex]
	local from = prompt:GetAttribute("LiftFloor")
	local part = prompt.Parent
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not house or type(from) ~= "number" or not character or not root or not part or not part:IsA("BasePart") then
		return
	end
	if (root.Position - part.Position).Magnitude > prompt.MaxActivationDistance + 12 then
		return
	end
	local target = if from < house.FloorCount then from + 1 else 1
	character:PivotTo(HouseBuilder.landingCFrame(house, target))
end

function HouseSystem.applyWalkSpeed(player: Player)
	PlayerState.apply(player)
end

function HouseSystem.onCharacterAdded(player: Player, character: Model)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if not root then
		return
	end
	if houseByPlayer[player] then
		character:PivotTo(houseByPlayer[player].SpawnCFrame)
	end
	HouseSystem.applyWalkSpeed(player)
end

---------------------------------------------------------------------------
-- setup
---------------------------------------------------------------------------

function HouseSystem.start(world: { Houses: { HouseBuilder.House } })
	houses = world.Houses
	for _, house in houses do
		refreshAll(house, nil)
	end

	Events.EquippedChanged:Connect(queueDisplay)
	Events.Collected:Connect(function(player)
		queueDisplay(player)
	end)
	Events.UpgradeChanged:Connect(function(player, upgradeId)
		local house = houseByPlayer[player]
		local data = DataSystem.get(player)
		if house and data then
			HouseBuilder.setStation(house, upgradeId, data.Upgrades[upgradeId] or 0)
			refreshDisplay(house, data) -- ExtraStorage unlocks shelf slots
		end
		HouseSystem.applyWalkSpeed(player)
	end)
	Events.Rebirthed:Connect(function(player)
		local house = houseByPlayer[player]
		if house then
			refreshAll(house, player)
		end
		HouseSystem.applyWalkSpeed(player)
	end)
	Events.RoofChanged:Connect(function(player)
		local house = houseByPlayer[player]
		if house then
			refreshRoof(house, DataSystem.get(player))
		end
	end)
	Events.StatsChanged:Connect(function(player)
		local house = houseByPlayer[player]
		if house then
			refreshSign(house, player)
			refreshWheelLabels(house, DataSystem.get(player))
		end
	end)

	-- walk speed follows boosts (expiring) without any client involvement
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				HouseSystem.applyWalkSpeed(player)
			end
		end
	end)

	-- world prompts (houses + plaza buildings) open menus on the owner's screen
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local liftHouse = prompt:GetAttribute("LiftHouse")
		if type(liftHouse) == "number" then
			HouseSystem.ride(player, prompt, liftHouse)
			return
		end
		local menu = prompt:GetAttribute("OpenUI")
		if type(menu) ~= "string" then
			return
		end
		local part = prompt.Parent
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not part or not part:IsA("BasePart") or not root or (root.Position - part.Position).Magnitude > prompt.MaxActivationDistance + 12 then
			return
		end
		if prompt:HasTag("OwnerOnlyPrompt") and prompt:GetAttribute("OwnerUserId") ~= player.UserId then
			Notifier.send(player, "That belongs to another player's house.", "error")
			return
		end
		local focus = prompt:GetAttribute("Focus")
		Notifier.openUI(player, menu, if type(focus) == "string" then focus else nil)
	end)
end

return HouseSystem
