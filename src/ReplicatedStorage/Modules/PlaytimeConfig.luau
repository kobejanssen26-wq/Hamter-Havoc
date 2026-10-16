--[[
	PlaytimeConfig: the playtime rewards. Stay in the game and open the Playtime window (hourglass in the right rail) to claim
	a reward for every milestone you reached, up to 8 hours.

	How it works (decided for this first version, change it here):
	  * Only time spent in THIS experience counts. The SERVER counts it (every 5 seconds a player is in the game adds 5), the
	    window only shows it. Closing the window, switching tabs or editing the client changes nothing.
	  * The time is saved with the player, so it also counts over several visits: 8 hours may be spread over days.
	  * Every milestone can be claimed ONCE PER PLAYER, ever (a permanent series, not daily and not per season). Rebirths do not
	    reset it. Want a daily / seasonal series later? Change `Playtime.Season` in the profile (PlaytimeSystem.resetSeason).
	  * The reward is marked as claimed in the same saved profile that receives it, and nothing is paid twice for one milestone.

	Edit the list below: Minutes, Icon (see UI/Icons), Reward. A reward can hold any of
	    Coins = n          cash (grows with rebirths: x(1 + CoinsPerRebirth * rebirths), like the daily rewards)
	    Gems = n           diamonds
	    Boost = { Id = "Luck2x", Seconds = 900 }   a running boost (Coins2x, Luck2x, Speed2x, AutoCollect)
	    Items = { "item_speed" }                   items from Content/Items
	    HamsterRarity = "Epic"                     one random hamster of that rarity (never an exclusive / limited one)
	Only existing currencies and items are used. A broken milestone is reported by PlaytimeConfig.validate() and skipped.
]]

local PlaytimeConfig = {}

PlaytimeConfig.CoinsPerRebirth = 2
PlaytimeConfig.TickSeconds = 5 -- how often the server adds time (also the longest time one tick can add)

PlaytimeConfig.Milestones = {
	{ Id = "t10m", Minutes = 10, Icon = "coin", Reward = { Coins = 1000 } },
	{ Id = "t30m", Minutes = 30, Icon = "gem", Reward = { Gems = 25 } },
	{ Id = "t1h", Minutes = 60, Icon = "pouch", Reward = { Coins = 6000, Items = { "item_speed" } } },
	{ Id = "t2h", Minutes = 120, Icon = "clover", Reward = { Gems = 60, Boost = { Id = "Luck2x", Seconds = 900 } } },
	{ Id = "t3h", Minutes = 180, Icon = "cash", Reward = { Coins = 20000, Items = { "item_auto" } } },
	{ Id = "t4h", Minutes = 240, Icon = "gift", Reward = { Gems = 120, Items = { "item_coins" } } },
	{ Id = "t6h", Minutes = 360, Icon = "heart", Reward = { Gems = 250, HamsterRarity = "Epic" } },
	{ Id = "t8h", Minutes = 480, Icon = "crown", Reward = { Gems = 500, Coins = 60000, HamsterRarity = "Legendary" } },
}

-- seconds a milestone needs
function PlaytimeConfig.seconds(milestone: any): number
	return math.floor(milestone.Minutes * 60)
end

function PlaytimeConfig.maxSeconds(): number
	local best = 0
	for _, milestone in PlaytimeConfig.Milestones do
		best = math.max(best, PlaytimeConfig.seconds(milestone))
	end
	return best
end

function PlaytimeConfig.byId(id: any): any?
	for _, milestone in PlaytimeConfig.Milestones do
		if milestone.Id == id then
			return milestone
		end
	end
	return nil
end

-- The reward as it is paid (Rewards.grant format) for a player with `rebirths` rebirths. A HamsterRarity stays a rarity here:
-- the server picks the species when the reward is claimed.
function PlaytimeConfig.reward(milestone: any, rebirths: number): { [string]: any }
	local reward = {}
	for key, value in milestone.Reward do
		reward[key] = value
	end
	if reward.Coins then
		reward.Coins = math.floor(reward.Coins * (1 + PlaytimeConfig.CoinsPerRebirth * math.max(0, rebirths)))
	end
	return reward
end

-- The exact lines the window shows ("6,000 Cash", "Speed Tonic", "Epic hamster" ...).
function PlaytimeConfig.lines(milestone: any, rebirths: number): { string }
	local Format = require(script.Parent.Format)
	local ItemRegistry = require(script.Parent.ItemRegistry)
	local ShopConfig = require(script.Parent.ShopConfig)
	local reward = PlaytimeConfig.reward(milestone, rebirths)
	local lines = {}
	if reward.Coins then
		table.insert(lines, Format.commas(reward.Coins) .. " Coins")
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
	if reward.HamsterRarity then
		table.insert(lines, reward.HamsterRarity .. " hamster")
	end
	return lines
end

-- Where a player stands. `seconds` = time played (the server's number, the client interpolates it).
-- Returns the list { { Milestone, Status = "claimed" | "ready" | "locked", Remaining } } and the index of the next unclaimed one (or nil).
function PlaytimeConfig.state(profile: any, seconds: number)
	local claimed = if profile and profile.Claimed then profile.Claimed else {}
	local list = {}
	local nextIndex = nil
	for index, milestone in PlaytimeConfig.Milestones do
		local needed = PlaytimeConfig.seconds(milestone)
		local status = if claimed[milestone.Id] then "claimed" elseif seconds >= needed then "ready" else "locked"
		if status ~= "claimed" and not nextIndex then
			nextIndex = index
		end
		table.insert(list, { Milestone = milestone, Status = status, Remaining = math.max(0, needed - seconds) })
	end
	return list, nextIndex
end

-- Problems with the milestone list (empty = fine). Run at server start.
function PlaytimeConfig.validate(): { string }
	local issues = {}
	local ItemRegistry = require(script.Parent.ItemRegistry)
	local RarityConfig = require(script.Parent.RarityConfig)
	local seen, last = {}, 0
	for _, milestone in PlaytimeConfig.Milestones do
		local id = milestone.Id
		if type(id) ~= "string" or id == "" or seen[id] then
			table.insert(issues, "a milestone has a missing or duplicate Id: " .. tostring(id))
		end
		seen[id] = true
		if type(milestone.Minutes) ~= "number" or milestone.Minutes <= 0 or milestone.Minutes > 480 then
			table.insert(issues, tostring(id) .. ": Minutes must be between 1 and 480 (8 hours)")
		elseif milestone.Minutes <= last then
			table.insert(issues, tostring(id) .. ": milestones must be in increasing order of Minutes")
		else
			last = milestone.Minutes
		end
		local reward = milestone.Reward
		if type(reward) ~= "table" then
			table.insert(issues, tostring(id) .. ": no Reward")
		else
			local pays = false
			for _, key in { "Coins", "Gems" } do
				if reward[key] ~= nil then
					pays = true
					if type(reward[key]) ~= "number" or reward[key] <= 0 or reward[key] > 1e9 then
						table.insert(issues, tostring(id) .. ": " .. key .. " must be a number above 0")
					end
				end
			end
			if reward.Boost ~= nil then
				pays = true
				if type(reward.Boost) ~= "table" or type(reward.Boost.Id) ~= "string" or type(reward.Boost.Seconds) ~= "number" or reward.Boost.Seconds <= 0 then
					table.insert(issues, tostring(id) .. ": Boost needs Id and Seconds")
				end
			end
			if reward.Items ~= nil then
				pays = true
				for _, itemId in reward.Items do
					if not ItemRegistry.get(itemId) then
						table.insert(issues, tostring(id) .. ": unknown item " .. tostring(itemId))
					end
				end
			end
			if reward.HamsterRarity ~= nil then
				pays = true
				if not RarityConfig.ById[reward.HamsterRarity] then
					table.insert(issues, tostring(id) .. ": unknown rarity " .. tostring(reward.HamsterRarity))
				end
			end
			if not pays then
				table.insert(issues, tostring(id) .. ": the reward pays nothing")
			end
		end
	end
	return issues
end

return PlaytimeConfig
