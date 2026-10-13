--[[
	7-day login streak. Claim once per UTC day. Miss a day and the streak restarts at day 1.
	Day 5 and day 7 give exclusive hamsters that can't be found any other way.
]]

local DailyRewardConfig = {}

-- One entry per day. Every reward is named exactly in the calendar (amount + item). Fields (all optional, combine freely):
--   Coins = 500            cash (grows with rebirths: x(1 + 2 * rebirths))      Gems = 50          diamonds
--   Boost = { Id, Seconds }  a running boost (Coins2x, Luck2x, Speed2x, AutoCollect)
--   Items = { "item_speed", ... }  items from Content/Items (a boost item you keep and use from the hotbar, or a weapon / trap)
--   Hamster = "species_id"   an exclusive hamster
DailyRewardConfig.Days = {
	{ Day = 1, Icon = "coin", Coins = 500, Items = { "item_speed" } },
	{ Day = 2, Icon = "gem", Gems = 50, Items = { "item_pouch" } },
	{ Day = 3, Icon = "clover", Boost = { Id = "Luck2x", Seconds = 900 }, Items = { "item_luck" } },
	{ Day = 4, Icon = "pouch", Coins = 2500, Items = { "item_auto" } },
	{ Day = 5, Icon = "gift", Hamster = "calendar_cutie", Gems = 100 },
	{ Day = 6, Icon = "gem", Gems = 120, Items = { "item_coins" } },
	{ Day = 7, Icon = "crown", Hamster = "sunday_sunbeam", Gems = 150, Items = { "spike_trap" } },
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
	if entry.Items then
		reward.Items = entry.Items
	end
	return reward
end

-- The exact lines the calendar shows for a day ("500 Cash", "Speed Tonic", "Calendar Cutie (exclusive hamster)" ...).
function DailyRewardConfig.lines(day: number, rebirths: number): { string }
	local Format = require(script.Parent.Format)
	local HamsterDatabase = require(script.Parent.HamsterDatabase)
	local ItemRegistry = require(script.Parent.ItemRegistry)
	local ShopConfig = require(script.Parent.ShopConfig)
	local reward = DailyRewardConfig.reward(day, rebirths)
	local lines = {}
	if reward.Coins then
		table.insert(lines, Format.commas(reward.Coins) .. " Cash")
	end
	if reward.Gems then
		table.insert(lines, Format.commas(reward.Gems) .. " Diamonds")
	end
	if reward.Boost then
		local info = ShopConfig.Boosts[reward.Boost.Id]
		table.insert(lines, string.format("%s (%d min)", if info then info.Name else reward.Boost.Id, math.floor(reward.Boost.Seconds / 60)))
	end
	for _, id in reward.Items or {} do
		local def = ItemRegistry.get(id)
		table.insert(lines, if def then def.DisplayName else id)
	end
	if reward.Hamster then
		local species = HamsterDatabase.ById[reward.Hamster]
		table.insert(lines, (if species then species.Name else reward.Hamster) .. " (exclusive hamster)")
	end
	return lines
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
