--[[
	RewardSystem: the 7-day daily streak and promo codes.
	Both are claim-once and recorded BEFORE paying out, so a double click can never pay twice.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local DailyRewardConfig = require(Modules.DailyRewardConfig)

local CodesConfig = require(script.Parent.Parent.Config.CodesConfig)
local DataSystem = require(script.Parent.DataSystem)
local ReplicationSystem = require(script.Parent.ReplicationSystem)
local Rewards = require(script.Parent.Rewards)

local RewardSystem = {}

-- Returns (ok, message)
function RewardSystem.claimDaily(player: Player): (boolean, string)
	local data = DataSystem.get(player)
	if not data then
		return false, "No data"
	end
	local now = os.time()
	local day, canClaim = DailyRewardConfig.state(data.Daily, now)
	if not canClaim then
		return false, "Come back tomorrow for your next gift!"
	end

	data.Daily.Streak = day
	data.Daily.LastDay = DailyRewardConfig.dayNumber(now)
	ReplicationSystem.mark(player, "Daily")

	local text = Rewards.grantAndNotify(player, "Daily reward (day " .. day .. ")", DailyRewardConfig.reward(day, data.Rebirths))
	return true, text
end

-- Returns (ok, message)
function RewardSystem.redeemCode(player: Player, rawCode: any): (boolean, string)
	local data = DataSystem.get(player)
	if not data or type(rawCode) ~= "string" then
		return false, "Invalid code"
	end
	if #rawCode > 40 then
		return false, "Invalid code"
	end
	local code = string.upper((string.gsub(rawCode, "%s+", "")))
	local entry = CodesConfig[code]
	if code == "" or not entry then
		return false, "That code doesn't exist"
	end
	if entry.ExpiresAt and os.time() > entry.ExpiresAt then
		return false, "That code has expired"
	end
	if data.Codes[code] then
		return false, "You already used that code"
	end

	data.Codes[code] = true
	DataSystem.markDirty(player)
	local text = Rewards.grantAndNotify(player, "Code " .. code, entry.Reward)
	return true, text
end

return RewardSystem
