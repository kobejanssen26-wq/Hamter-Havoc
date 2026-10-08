--[[
	HouseSystem: gives every player a house and keeps it in sync with their progress.

	What a house shows (all driven by the player's profile):
	  - front sign + roof banner: name, rebirths, index progress, best hamster
	  - rebirth stars on the gable
	  - the 12-slot shelf: your equipped hamsters (locked slots stay dark)
	  - 8 upgrade pedestals whose props grow with every upgrade level
	  - roof colour (cosmetic)
	More than 10 players: extra players wait in a queue; they can still play (income, collecting) and
	get a house as soon as one frees up.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local EconomyMath = require(Modules.EconomyMath)
local HamsterBuilder = require(Modules.HamsterBuilder)
local HamsterDatabase = require(Modules.HamsterDatabase)
local RarityConfig = require(Modules.RarityConfig)
local ShopConfig = require(Modules.ShopConfig)
local UpgradeConfig = require(Modules.UpgradeConfig)

local DataSystem = require(script.Parent.DataSystem)
local Events = require(script.Parent.Events)
local HouseBuilder = require(script.Parent.WorldBuilder.HouseBuilder)
local Notifier = require(script.Parent.Notifier)

local HouseSystem = {}

local DISPLAY_SCALE = 0.5
local SLOT_COUNT = 12

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
		house.Labels.Arch.Text = "Free House"
		house.Model:SetAttribute("OwnerUserId", 0)
		house.Model:SetAttribute("OwnerName", "")
		return
	end

	local best = bestHamster(data)
	local rebirthText = if data.Rebirths > 0 then string.format("Rebirth %d", data.Rebirths) else "New home"
	house.Labels.Name.Text = string.format("%s's House", player.DisplayName)
	house.Labels.Stats.Text = string.format("%s  •  %d/%d hamsters", rebirthText, EconomyMath.uniqueCount(data), HamsterDatabase.Total)
	if best then
		local definition = RarityConfig.ById[best.Rarity]
		local name = if definition.Hidden then "???" else best.Name
		house.Labels.Best.Text = string.format('Best: %s <font color="#%s">(%s)</font>', name, definition.Accent:ToHex(), definition.Name)
	else
		house.Labels.Best.Text = "Best: —"
	end
	house.Labels.Roof.Text = string.format("<b>%s</b>%s", player.DisplayName, if data.Rebirths > 0 then "  •  R" .. data.Rebirths else "")
	house.Labels.Arch.Text = player.DisplayName .. "'s Home"
	house.Model:SetAttribute("OwnerUserId", player.UserId)
	house.Model:SetAttribute("OwnerName", player.DisplayName)
	HouseBuilder.setStars(house, math.min(data.Rebirths, 10))
end

local function refreshStations(house: HouseBuilder.House, data: any?)
	for _, upgradeId in UpgradeConfig.Order do
		local level = if data then (data.Upgrades[upgradeId] or 0) else 0
		HouseBuilder.setStation(house, upgradeId, level)
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

local function refreshDisplay(house: HouseBuilder.House, data: any?)
	local slots = if data then math.min(EconomyMath.slots(data), SLOT_COUNT) else 0
	local equipped = if data then data.Equipped else {}

	-- pool the existing models by species so unchanged hamsters just move
	local pool: { [string]: { Model } } = {}
	for _, entry in house.DisplayModels do
		pool[entry.SpeciesId] = pool[entry.SpeciesId] or {}
		table.insert(pool[entry.SpeciesId], entry.Model)
	end
	local result: { [number]: { SpeciesId: string, Model: Model } } = {}

	for index, slot in house.DisplaySlots do
		local speciesId = if index <= slots then equipped[index] else nil
		local species = if speciesId then HamsterDatabase.ById[speciesId] else nil
		if species then
			local model = nil
			local candidates = pool[speciesId]
			if candidates and #candidates > 0 then
				model = table.remove(candidates)
			else
				model = HamsterBuilder.build(species, { Scale = DISPLAY_SCALE, LowDetail = true, Particles = false })
				model:AddTag("IdleHamster")
				model.Parent = house.DisplayFolder
			end
			model:PivotTo(slot.CFrame)
			result[index] = { SpeciesId = speciesId, Model = model }

			local definition = RarityConfig.ById[species.Rarity]
			slot.Ring.Color = if definition.Hidden then definition.Accent else definition.Color
			slot.Ring.Transparency = 0.15
		else
			slot.Ring.Color = if index <= slots then Color3.fromRGB(200, 190, 170) else Color3.fromRGB(70, 60, 70)
			slot.Ring.Transparency = if index <= slots then 0.5 else 0.8
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

function HouseSystem.moveToHouse(player: Player)
	local house = houseByPlayer[player]
	local character = player.Character
	if house and character and character:FindFirstChild("HumanoidRootPart") then
		character:PivotTo(house.SpawnCFrame)
	end
end

function HouseSystem.applyWalkSpeed(player: Player)
	local data = DataSystem.get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if data and humanoid then
		humanoid.WalkSpeed = EconomyMath.walkSpeed(data, os.time())
	end
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
