--[[
	QuestSystem: quests + achievements. Progress is derived from stats the server already tracks;
	this module validates claims and pays rewards once. A scan loop pops a toast when something completes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local AchievementConfig = require(Modules.AchievementConfig)
local QuestConfig = require(Modules.QuestConfig)

local Remotes = require(ReplicatedStorage.Remotes)

local DataSystem = require(script.Parent.DataSystem)
local Notifier = require(script.Parent.Notifier)
local ReplicationSystem = require(script.Parent.ReplicationSystem)
local Rewards = require(script.Parent.Rewards)

local QuestSystem = {}

local announced: { [Player]: { [string]: boolean } } = {}

-- Returns (ok, message)
function QuestSystem.claimQuest(player: Player, questId: any): (boolean, string)
	local data = DataSystem.get(player)
	local quest = if type(questId) == "string" then QuestConfig.ById[questId] else nil
	if not data or not quest then
		return false, "Unknown quest"
	end
	if data.Quests.Claimed[quest.Id] then
		return false, "Already claimed"
	end
	if not QuestConfig.isComplete(data, quest) then
		return false, "Quest not finished yet"
	end
	data.Quests.Claimed[quest.Id] = true
	ReplicationSystem.mark(player, "Quests")
	local text = Rewards.grantAndNotify(player, quest.Title, quest.Reward)
	return true, text
end

function QuestSystem.claimAchievement(player: Player, achievementId: any): (boolean, string)
	local data = DataSystem.get(player)
	local achievement = if type(achievementId) == "string" then AchievementConfig.ById[achievementId] else nil
	if not data or not achievement then
		return false, "Unknown achievement"
	end
	if data.Achievements.Claimed[achievement.Id] then
		return false, "Already claimed"
	end
	if QuestConfig.getStat(data, achievement.Stat) < achievement.Target then
		return false, "Achievement not unlocked yet"
	end
	data.Achievements.Claimed[achievement.Id] = true
	ReplicationSystem.mark(player, "Achievements")
	local text = Rewards.grantAndNotify(player, achievement.Title, achievement.Reward)
	return true, text
end

local function scan(player: Player)
	local data = DataSystem.get(player)
	if not data then
		return
	end
	local seen = announced[player]
	if not seen then
		seen = {}
		announced[player] = seen
		-- everything already complete on join is silent
		for _, quest in QuestConfig.Quests do
			if QuestConfig.isComplete(data, quest) then
				seen["q_" .. quest.Id] = true
			end
		end
		for _, achievement in AchievementConfig.List do
			if QuestConfig.getStat(data, achievement.Stat) >= achievement.Target then
				seen["a_" .. achievement.Id] = true
			end
		end
		return
	end
	for _, quest in QuestConfig.Quests do
		local key = "q_" .. quest.Id
		if not seen[key] and QuestConfig.isComplete(data, quest) then
			seen[key] = true
			Notifier.send(player, "Quest complete: " .. quest.Title .. " - claim it in the Quests menu!", "reward")
			Remotes.event("Fx"):FireClient(player, "QuestDone", quest.Id)
		end
	end
	for _, achievement in AchievementConfig.List do
		local key = "a_" .. achievement.Id
		if not seen[key] and QuestConfig.getStat(data, achievement.Stat) >= achievement.Target then
			seen[key] = true
			Notifier.send(player, "Achievement unlocked: " .. achievement.Title, "reward")
			Remotes.event("Fx"):FireClient(player, "QuestDone", achievement.Id)
		end
	end
end

function QuestSystem.start()
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				scan(player)
			end
		end
	end)
end

function QuestSystem.forget(player: Player)
	announced[player] = nil
end

return QuestSystem
