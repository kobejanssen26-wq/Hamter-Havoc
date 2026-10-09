--[[
	Server entry point: builds the world, starts the systems, and handles the player lifecycle.

	Join:   load profile -> attributes -> gamepasses -> house -> first sync -> ready
	Leave:  free the house -> forget runtime state -> save + release the profile
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Remotes)
Remotes.init()

local Systems = script.Parent.Systems
local AnnounceSystem = require(Systems.AnnounceSystem)
local DataSystem = require(Systems.DataSystem)
local CombatSystem = require(Systems.CombatSystem)
local EconomySystem = require(Systems.EconomySystem)
local Events = require(Systems.Events)
local HamsterSystem = require(Systems.HamsterSystem)
local HouseSystem = require(Systems.HouseSystem)
local LeaderboardSystem = require(Systems.LeaderboardSystem)
local Notifier = require(Systems.Notifier)
local PlayerState = require(Systems.PlayerState)
local QuestSystem = require(Systems.QuestSystem)
local ReplicationSystem = require(Systems.ReplicationSystem)
local RequestRouter = require(Systems.RequestRouter)
local SecuritySystem = require(Systems.SecuritySystem)
local ShopSystem = require(Systems.ShopSystem)
local ItemSystem = require(Systems.ItemSystem)
local TutorialSystem = require(Systems.TutorialSystem)
local WorldBuilder = require(Systems.WorldBuilder)

-- world first, so houses exist before anybody joins
local world = WorldBuilder.build()
AnnounceSystem.setRecentLabels(world.RecentLabels)

DataSystem.start()
ReplicationSystem.start()
EconomySystem.start()
HouseSystem.start(world)
SecuritySystem.start()
HamsterSystem.start()
CombatSystem.start()
QuestSystem.start()
ShopSystem.start()
TutorialSystem.start()
LeaderboardSystem.start()
RequestRouter.start()

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		HouseSystem.onCharacterAdded(player, character)
	end)

	task.spawn(function()
		DataSystem.load(player)
		if player.Parent == nil then
			DataSystem.release(player)
			return
		end

		EconomySystem.updateAttributes(player)
		ShopSystem.loadPasses(player)
		HouseSystem.assign(player)
		ReplicationSystem.sendFull(player)
		LeaderboardSystem.update(player)

		if DataSystem.isTemporary(player) then
			Notifier.send(player, "Your saved data couldn't be loaded, so this session won't be saved. Try rejoining.", "error")
		end

		player:SetAttribute("DataLoaded", true)
		HamsterSystem.sendAll(player)
		HouseSystem.moveToHouse(player)
		HouseSystem.applyWalkSpeed(player)
		Events.ProfileLoaded:Fire(player)
	end)
end

local function onPlayerRemoving(player: Player)
	HamsterSystem.onPlayerRemoving(player) -- refunds before the profile is saved
	HouseSystem.release(player)
	SecuritySystem.forget(player)
	CombatSystem.forget(player)
	PlayerState.forget(player)
	QuestSystem.forget(player)
	EconomySystem.forget(player)
	RequestRouter.forget(player)
	ShopSystem.forget(player)
	ItemSystem.forget(player)
	ReplicationSystem.clear(player)
	DataSystem.release(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
