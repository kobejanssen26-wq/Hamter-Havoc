--[[
	TutorialSystem: server side of the first-time guide. The step and its completion live in profile.Tutorial and are
	only ever advanced here: "Ack" steps by the player's button (validated against the CURRENT step), "Stat" steps
	by the real profile statistics (so the player must genuinely buy / secure a hamster).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local TutorialConfig = require(ReplicatedStorage.Modules.TutorialConfig)

local HamsterDatabase = require(ReplicatedStorage.Modules.HamsterDatabase)
local HamsterStates = require(ReplicatedStorage.Modules.HamsterStates)

local DataSystem = require(script.Parent.DataSystem)
local HamsterSystem = require(script.Parent.HamsterSystem)
local ReplicationSystem = require(script.Parent.ReplicationSystem)

local TutorialSystem = {}

local STARTER_WAIT = 20 -- seconds a new player may look at the road without any hamster ball they can afford
local waiting: { [Player]: number } = {}

-- The "Get your first hamster" step must always be completable: when no ball the player can afford has rolled by for a while,
-- one cheap one (the cheapest hamster that is allowed to roll for this player) is sent down the road for them.
local function ensureAffordableBall(player: Player, data: any)
	for _, entity in HamsterSystem.all() do
		if entity.State == HamsterStates.Travelling and entity.Price <= data.Coins then
			waiting[player] = nil
			return
		end
	end
	waiting[player] = (waiting[player] or 0) + 1
	if waiting[player] < STARTER_WAIT then
		return
	end
	waiting[player] = 0
	local best = nil
	for _, species in HamsterDatabase.Spawnable.Basic or {} do
		if HamsterDatabase.rollable(species, data.Rebirths, os.time()) then
			local price = HamsterDatabase.price(species)
			if price <= data.Coins and (not best or price < HamsterDatabase.price(best)) then
				best = species
			end
		end
	end
	if best then
		HamsterSystem.spawn(best, player)
	end
end

local function finish(player: Player, data: any, skipped: boolean)
	data.Tutorial.Step = TutorialConfig.DoneStep
	data.Tutorial.Done = true
	data.Tutorial.Skipped = skipped
	ReplicationSystem.mark(player, "Tutorial")
end

local function advance(player: Player, data: any)
	local nextStep = data.Tutorial.Step + 1
	if nextStep > #TutorialConfig.Steps then
		finish(player, data, false)
	else
		data.Tutorial.Step = nextStep
		ReplicationSystem.mark(player, "Tutorial")
	end
end

-- Player pressed the step's button. Returns (ok, message)
function TutorialSystem.ack(player: Player, stepId: any): (boolean, string)
	local data = DataSystem.get(player)
	if not data or data.Tutorial.Done then
		return false, "No tutorial"
	end
	local step = TutorialConfig.Steps[data.Tutorial.Step]
	if not step or step.Kind ~= "Ack" or step.Id ~= stepId then
		return false, "Not on this step"
	end
	advance(player, data)
	return true, "OK"
end

function TutorialSystem.skip(player: Player): (boolean, string)
	local data = DataSystem.get(player)
	if not data or data.Tutorial.Done then
		return false, "No tutorial"
	end
	finish(player, data, true)
	return true, "Tutorial skipped"
end

-- Settings > Replay tutorial: starts again from step 1 (only the player's own profile, nothing else changes).
function TutorialSystem.replay(player: Player): (boolean, string)
	local data = DataSystem.get(player)
	if not data then
		return false, "No data"
	end
	data.Tutorial.Step = 1
	data.Tutorial.Done = false
	data.Tutorial.Skipped = false
	ReplicationSystem.mark(player, "Tutorial")
	return true, "Tutorial restarted"
end

-- Advances "Stat" steps from real progress. Cheap; called once a second for players still in the tutorial.
function TutorialSystem.check(player: Player)
	local data = DataSystem.get(player)
	if not data or data.Tutorial.Done then
		return
	end
	if not GameConfig.get("Tutorial", "Enabled") then
		finish(player, data, true) -- GameConfig > Tutorial > Enabled = false: nobody gets the tutorial
		return
	end
	local step = TutorialConfig.Steps[data.Tutorial.Step]
	if not step then
		return
	end
	if step.Id == "hamster" then
		ensureAffordableBall(player, data)
	end
	if step.Kind == "Stat" and (data.Stats[step.Stat] or 0) >= step.Need then
		advance(player, data)
	elseif step.Kind == "Equipped" and #data.Equipped >= 1 then
		advance(player, data)
	end
end

function TutorialSystem.forget(player: Player)
	waiting[player] = nil
end

function TutorialSystem.start()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				pcall(TutorialSystem.check, player)
			end
		end
	end)
end

return TutorialSystem
