--[[
	HouseSystem: gives every player a house and keeps it in sync with their progress.

	What a house shows (all driven by the player's profile):
	  - front sign + roof banner: name, rebirths, index progress, best hamster
	  - rebirth stars on the gable
	  - the apartment tower: 1-5 floors depending on rebirths (FloorConfig), 8 wheel stations per floor,
	    every equipped hamster runs on its own wheel (locked slots stay empty)
	  - 8 upgrade pedestals on the ground floor whose props grow with every upgrade level
	  - rebirth stars, trim material (rebirth cosmetic), accent colour (cosmetic)
	  - elevator between floors (prompts handled at the bottom of this file)
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
local RebirthConfig = require(Modules.RebirthConfig)
local ShopConfig = require(Modules.ShopConfig)
local UpgradeConfig = require(Modules.UpgradeConfig)

local DataSystem = require(script.Parent.DataSystem)
local Events = require(script.Parent.Events)
local Build = require(script.Parent.WorldBuilder.Build)
local HouseBuilder = require(script.Parent.WorldBuilder.HouseBuilder)
local Notifier = require(script.Parent.Notifier)
local PlayerState = require(script.Parent.PlayerState)

local HouseSystem = {}

local MAX_DISPLAY_HEIGHT = 1.9 -- a hamster has to fit inside its wheel
local WHEEL_SPIN = 3 -- rad/s
local RUN_SPEED = 7 -- animation speed of the running hamster
local towerRng = Random.new(77)

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
		house.Labels.Name.Text = "FREE HOUSE"
		house.Labels.Stats.Text = "Waiting for a new neighbour"
		house.Labels.Best.Text = ""
		house.Labels.Roof.Text = '<font color="#ffffff">Free house</font>'
		house.Model:SetAttribute("OwnerUserId", 0)
		house.Model:SetAttribute("OwnerName", "")
		return
	end

	local best = bestHamster(data)
	local rebirthText = if data.Rebirths > 0 then string.format("Rebirth %d", data.Rebirths) else "New home"
	house.Labels.Name.Text = string.format("%s's House", player.DisplayName)
	house.Labels.Stats.Text = string.format("%s  -  %d/%d hamsters", rebirthText, EconomyMath.uniqueCount(data), HamsterDatabase.Total)
	if best then
		local definition = RarityConfig.ById[best.Rarity]
		local name = if definition.Hidden then "???" else best.Name
		house.Labels.Best.Text = string.format('Best: %s <font color="#%s">(%s)</font>', name, definition.Accent:ToHex(), definition.Name)
	else
		house.Labels.Best.Text = "Best: —"
	end
	local title = IndexRewardConfig.title(data)
	house.Labels.Roof.Text = string.format("<b>%s</b>%s%s", player.DisplayName, if data.Rebirths > 0 then "  -  R" .. data.Rebirths else "", if title then "\n" .. title else "")
	house.Model:SetAttribute("OwnerUserId", player.UserId)
	house.Model:SetAttribute("OwnerName", player.DisplayName)
	HouseBuilder.setStars(house, math.min(data.Rebirths, 10))
end

local function refreshStations(house: HouseBuilder.House, data: any?)
	for _, upgradeId in UpgradeConfig.Order do
		local level = if data then (data.Upgrades[upgradeId] or 0) else 0
		HouseBuilder.setStation(house, upgradeId, level, if data then data.Rebirths else 0)
	end
end

-- Floors follow rebirths; trim material is the rebirth cosmetic. Also fills the board in the lobby.
local function refreshTower(house: HouseBuilder.House, data: any?)
	local rebirths = if data then data.Rebirths else 0
	HouseBuilder.setFloors(house, FloorConfig.count(rebirths), towerRng)
	HouseBuilder.setTrim(house, RebirthConfig.trim(rebirths))
	local nextFloor = FloorConfig.nextFloor(rebirths)
	local lines = { string.format("<b>%s</b>", "TOWER") }
	for _, floor in FloorConfig.Floors do
		local built = floor.Index <= FloorConfig.count(rebirths)
		table.insert(lines, string.format('<font color="#%s">%d  %s</font>', if built then "FFE08A" else "8A8294", floor.Index, floor.Name))
	end
	table.insert(lines, if nextFloor then string.format('<font color="#9DE0FF">Next: Rebirth %d</font>', nextFloor.MinRebirth) else '<font color="#9DE0FF">Tower complete</font>')
	if house.Labels.Progress then
		house.Labels.Progress.Text = table.concat(lines, "\n")
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

-- Text under a running hamster: how much it earns per second.
local function wheelIncomeText(species: any, data: any): string
	local perSecond = HamsterDatabase.income(species) * EconomyMath.incomeMultiplier(data, os.time())
	return string.format('<font color="#FFE08A">+%s/s</font>', Format.short(perSecond))
end

local function refreshWheelLabels(house: HouseBuilder.House, data: any?)
	if not data then
		return
	end
	for index, entry in house.DisplayModels do
		local slot = house.Slots[index]
		local species = HamsterDatabase.ById[entry.SpeciesId]
		entry.Model:SetAttribute("Income", HamsterDatabase.income(species) * EconomyMath.incomeMultiplier(data, os.time()))
		if slot and slot.Label then
			slot.Label.Text = wheelIncomeText(species, data)
		end
	end
end

local function refreshDisplay(house: HouseBuilder.House, data: any?)
	local slots = if data then EconomyMath.slots(data) else 0
	local equipped = if data then data.Equipped else {}

	-- pool the existing models by species so unchanged hamsters just stay where they run
	local pool: { [string]: { Model } } = {}
	for _, entry in house.DisplayModels do
		pool[entry.SpeciesId] = pool[entry.SpeciesId] or {}
		table.insert(pool[entry.SpeciesId], entry.Model)
	end
	local result: { [number]: { SpeciesId: string, Model: Model } } = {}

	for index, slot in house.Slots do
		local unlocked = index <= slots
		HouseBuilder.setWheel(house, index, unlocked)
		local speciesId = if unlocked then equipped[index] else nil
		local species = if speciesId then HamsterDatabase.ById[speciesId] else nil
		if species and data then
			local model = nil
			local candidates = pool[speciesId]
			if candidates and #candidates > 0 then
				model = table.remove(candidates)
			else
				local scale = math.min(0.5, MAX_DISPLAY_HEIGHT / (3.4 * (species.Size or 1)))
				model = HamsterBuilder.build(species, { Scale = scale, LowDetail = true, Particles = false })
				model:AddTag("WheelHamster")
				model:SetAttribute("RunSpeed", RUN_SPEED)
				model.Parent = house.DisplayFolder
			end
			model:SetAttribute("Income", HamsterDatabase.income(species) * EconomyMath.incomeMultiplier(data, os.time()))
			model:PivotTo(slot.RunCFrame)
			result[index] = { SpeciesId = speciesId, Model = model }
			HouseBuilder.setWheelSpeed(slot, WHEEL_SPIN)

			if not slot.Label then
				slot.Label = Build.billboard(slot.LabelAnchor, "", Vector2.new(120, 26), Vector3.zero, { MaxDistance = 24, Name = "WheelIncome" })
			end
			slot.Label.Text = wheelIncomeText(species, data)

			local definition = RarityConfig.ById[species.Rarity]
			slot.Ring.Color = if definition.Hidden then definition.Accent else definition.Color
			slot.Ring.Transparency = 0.5
		else
			HouseBuilder.setWheelSpeed(slot, 0)
			if slot.Label then
				slot.Label.Text = ""
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
	refreshTower(house, data)
	refreshSign(house, player)
	refreshStations(house, data)
	refreshRoof(house, data)
	refreshDisplay(house, data)
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
			refreshDisplay(house, data)
			refreshSign(house, player)
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

-- Elevator buttons: moves the owner to the landing of the next floor up/down.
function HouseSystem.useElevator(player: Player, houseIndex: any, floor: any, direction: string)
	local house = houses[houseIndex]
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not house or type(floor) ~= "number" or not root then
		return
	end
	if house.Owner ~= player then
		Notifier.send(player, "That elevator belongs to another player's house.", "error")
		return
	end
	local target = floor + (if direction == "Up" then 1 else -1)
	local landing = house.Landing[target]
	if not landing or not house.Landing[floor] then
		return
	end
	if (root.Position - house.Landing[floor].Position).Magnitude > 24 then
		return
	end
	(player.Character :: Model):PivotTo(landing)
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
			HouseBuilder.setStation(house, upgradeId, data.Upgrades[upgradeId] or 0, data.Rebirths)
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
		local direction = prompt:GetAttribute("Elevator")
		if type(direction) == "string" then
			HouseSystem.useElevator(player, prompt:GetAttribute("HouseIndex"), prompt:GetAttribute("Floor"), direction)
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
