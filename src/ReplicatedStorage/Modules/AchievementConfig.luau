--[[
	Achievements: permanent milestones with a reward. Uses the same stat names as QuestConfig.
	"Completionist" targets the total index size (set at load from the database).
]]

local HamsterDatabase = require(script.Parent.HamsterDatabase)

local AchievementConfig = {}

AchievementConfig.List = {
	{ Id = "first_hamster", Title = "First Hamster", Desc = "Collect your first hamster", Icon = "hamster", Stat = "HamstersCollected", Target = 1, Reward = { Gems = 20 } },
	{ Id = "collector", Title = "Collector", Desc = "Collect 50 different hamsters", Icon = "book", Stat = "Unique", Target = 50, Reward = { Gems = 300 } },
	{ Id = "rare_hunter", Title = "Rare Hunter", Desc = "Find 25 Rare hamsters", Icon = "gem", Stat = "Found:Rare", Target = 25, Reward = { Gems = 200 } },
	{ Id = "legendary_hunter", Title = "Legendary Hunter", Desc = "Find 5 Legendary hamsters", Icon = "crown", Stat = "Found:Legendary", Target = 5, Reward = { Gems = 500 } },
	{ Id = "millionaire", Title = "Millionaire", Desc = "Earn 1,000,000 cash", Icon = "pouch", Stat = "CoinsEarned", Target = 1000000, Reward = { Gems = 300 } },
	{ Id = "rebirth_master", Title = "Rebirth Master", Desc = "Reach 10 rebirths", Icon = "flame", Stat = "Rebirths", Target = 10, Reward = { Gems = 1000, Tokens = 5 } },
	{ Id = "mythic_master", Title = "Mythic Master", Desc = "Find 3 Mythic hamsters", Icon = "flame", Stat = "Found:Mythic", Target = 3, Reward = { Gems = 800 } },
	{ Id = "secret_finder", Title = "Secret Finder", Desc = "Find a Secret hamster", Icon = "sparkle", Stat = "Found:Secret", Target = 1, Reward = { Gems = 1500, Tokens = 3 } },
	{ Id = "who_are_you", Title = "Who Are You?", Desc = "Find a ??? hamster", Icon = "question", Stat = "Found:Unknown", Target = 1, Reward = { Gems = 5000, Tokens = 10 } },
	{ Id = "master_thief", Title = "Master Thief", Desc = "Steal 25 hamsters and get them home", Icon = "shield", Stat = "Stolen", Target = 25, Reward = { Gems = 600, Tokens = 1 } },
	{ Id = "guardian", Title = "Guardian", Desc = "Take back 20 hamsters", Icon = "shield", Stat = "Recovered", Target = 20, Reward = { Gems = 600, Tokens = 1 } },
	{ Id = "home_run", Title = "Home Run", Desc = "Get 250 hamsters home safely", Icon = "home", Stat = "Secured", Target = 250, Reward = { Gems = 800 } },
	{ Id = "completionist", Title = "Completionist", Desc = "Complete the entire Hamster Index", Icon = "trophy", Stat = "Unique", Target = HamsterDatabase.Total, Reward = { Gems = 10000, Tokens = 20 } },
}

AchievementConfig.ById = {} :: { [string]: any }
for _, achievement in AchievementConfig.List do
	AchievementConfig.ById[achievement.Id] = achievement
end

return AchievementConfig
