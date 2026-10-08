--[[
	7-day login streak. Claim once per UTC day. Miss a day and the streak restarts at day 1.
	Day 5 and day 7 give exclusive hamsters that can't be found any other way.
]]

local DailyRewardConfig = {}

DailyRewardConfig.Days = {
	{ Day = 1, Label = "Coins", Icon = "🪙", Coins = 500 },
	{ Day = 2, Label = "Gems", Icon = "💎", Gems = 50 },
	{ Day = 3, Label = "Luck Boost", Icon = "🍀", Boost = { Id = "Luck2x", Seconds = 900 } },
	{ Day = 4, Label = "More Coins", Icon = "💰", Coins = 2500 },
	{ Day = 5, Label = "Exclusive Hamster", Icon = "🎀", Hamster = "calendar_cutie" },
	{ Day = 6, Label = "Gems", Icon = "💎", Gems = 120 },
	{ Day = 7, Label = "Legendary Reward", Icon = "👑", Hamster = "sunday_sunbeam", Gems = 150 },
}

local SECONDS_PER_DAY = 86400

function DailyRewardConfig.dayNumber(unixTime: number): number
	return math.floor(unixTime / SECONDS_PER_DAY)
end

-- Coin rewards scale with rebirths so they stay meaningful. Returns a reward table.
function DailyRewardConfig.reward(day: number, rebirths: number)
	local entry = DailyRewardConfig.Days[day]
	local reward: { [string]: any } = {}
	if entry.Coins then
		reward.Coins = entry.Coins * (1 + rebirths * 2)
	end
	if entry.Gems then
		reward.Gems = entry.Gems
	end
	if entry.Boost then
		reward.Boost = entry.Boost
	end
	if entry.Hamster then
		reward.Hamster = entry.Hamster
	end
	return reward
end

-- State for the UI/server: which day is next and whether it can be claimed now.
-- Returns (nextDay, canClaim, secondsUntilNext)
function DailyRewardConfig.state(daily: { Streak: number, LastDay: number }, now: number): (number, boolean, number)
	local today = DailyRewardConfig.dayNumber(now)
	local streak = daily.Streak
	if daily.LastDay > 0 and today - daily.LastDay > 1 then
		streak = 0 -- streak broken
	end
	local nextDay = streak % 7 + 1
	local canClaim = today > daily.LastDay
	local untilNext = (today + 1) * SECONDS_PER_DAY - now
	return nextDay, canClaim, if canClaim then 0 else untilNext
end

return DailyRewardConfig
