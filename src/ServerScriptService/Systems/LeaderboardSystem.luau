--[[
	Roblox leaderboard (player list): Rebirths, Hamsters (index progress) and Coins.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EconomyMath = require(ReplicatedStorage.Modules.EconomyMath)

local DataSystem = require(script.Parent.DataSystem)

local LeaderboardSystem = {}

local function ensure(player: Player): Folder
	local folder = player:FindFirstChild("leaderstats") :: Folder?
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "leaderstats"
		for _, name in { "Rebirths", "Hamsters", "Coins" } do
			local value = Instance.new("NumberValue")
			value.Name = name
			value.Parent = folder
		end
		folder.Parent = player
	end
	return folder :: Folder
end

function LeaderboardSystem.update(player: Player)
	local data = DataSystem.get(player)
	if not data then
		return
	end
	local folder = ensure(player)
	folder.Rebirths.Value = data.Rebirths
	folder.Hamsters.Value = EconomyMath.uniqueCount(data)
	folder.Coins.Value = math.floor(data.Coins)
end

function LeaderboardSystem.start()
	task.spawn(function()
		while true do
			task.wait(3)
			for _, player in Players:GetPlayers() do
				LeaderboardSystem.update(player)
			end
		end
	end)
end

return LeaderboardSystem
