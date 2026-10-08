--[[
	Rebirth progression. Requirement for rebirth n = 10^(n + 3) coins (R1 = $10K, R2 = $100K, R3 = $1M ...).
	A rebirth resets coins, coin-upgrades and your inventory but KEEPS the Hamster Index,
	gems, tokens, token-upgrades, quests and achievements.
]]

local RarityConfig = require(script.Parent.RarityConfig)

local RebirthConfig = {}

RebirthConfig.MaxRebirths = 25
RebirthConfig.GemReward = 500
RebirthConfig.BaseSlots = 3

-- Coins needed to perform rebirth number `n` (n = current rebirths + 1).
function RebirthConfig.cost(n: number): number
	return 10 ^ (n + 3)
end

-- Permanent multiplier shown on the rebirth screen. `boostLevel` = RebirthBoost token upgrade.
function RebirthConfig.multiplier(rebirths: number, boostLevel: number): number
	return 1 + rebirths * (1 + 0.1 * boostLevel)
end

function RebirthConfig.tokenReward(n: number): number
	return 1 + math.floor((n - 1) / 3)
end

function RebirthConfig.gemReward(n: number): number
	return RebirthConfig.GemReward
end

function RebirthConfig.startingCoins(rebirths: number): number
	return 50 * (1 + rebirths)
end

-- Extra house display slots earned through rebirths (+1 every 3 rebirths).
function RebirthConfig.bonusSlots(rebirths: number): number
	return math.floor(rebirths / 3)
end

-- Human readable list of what rebirth number `n` unlocks.
function RebirthConfig.unlocks(n: number): { string }
	local lines = {}
	for _, id in RarityConfig.Order do
		local definition = RarityConfig.ById[id]
		if definition.MinRebirth == n then
			table.insert(lines, string.format("%s hamsters start appearing", definition.Name))
		end
	end
	if n % 3 == 0 then
		table.insert(lines, "+1 permanent house display slot")
	end
	table.insert(lines, "+1 permanent multiplier step")
	return lines
end

return RebirthConfig
