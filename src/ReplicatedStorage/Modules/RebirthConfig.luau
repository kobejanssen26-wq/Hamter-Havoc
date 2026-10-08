--[[
	Rebirth: the main long-term progression.

	A rebirth needs real progress (coins, secured hamsters, one hamster of a certain rarity) and gives
	permanent rewards: a hamster slot every time, a bigger income multiplier, luck, new floors for your
	apartment, new rarities, better security, and from Rebirth 4 you keep your best hamsters.

	RESETS: coins, coin upgrades, hamsters (except the ones you keep), the hamsters on your wheels.
	KEEPS:  Hamster Index + discoveries, rebirths, gems, rebirth tokens + token upgrades, floors,
	        permanent multipliers and slots, cosmetics, quests, achievements, daily streak.

	Every number is generated from the tables below and checked by tools/lune/economy_sim.luau.
	To add rebirths later: raise MaxRebirths (the generator keeps scaling) or add Milestones entries.
]]

local FloorConfig = require(script.Parent.FloorConfig)
local RarityConfig = require(script.Parent.RarityConfig)
local SecurityConfig = require(script.Parent.SecurityConfig)

local RebirthConfig = {}

RebirthConfig.MaxRebirths = 25
RebirthConfig.BaseSlots = 3 -- hamster slots before any rebirth
RebirthConfig.SlotsPerRebirth = 1
RebirthConfig.GemReward = 250 -- kept for old callers; see gemReward

-- Coins needed for each rebirth (index = rebirth number). Beyond the table: x4.5 per rebirth.
local COINS = {
	2_500_000, -- R1
	12_000_000,
	55_000_000,
	250_000_000,
	1_100_000_000, -- R5
	5_000_000_000,
	22_000_000_000,
	100_000_000_000,
	450_000_000_000,
	2_000_000_000_000, -- R10
}

-- Rarity you must OWN (secured, at least one) for each rebirth. Beyond the table: the last entry.
local RARITY = {
	"Rare", "Epic", "Epic", "Ultra", "Ultra", -- R1-5
	"Legendary", "Legendary", "Mythic", "Mythic", "Mythic", -- R6-10
	"Divine", "Divine", "Divine", "Cosmic", "Cosmic", -- R11-15
	"Cosmic", "Celestial", "Celestial", "Celestial", "Celestial", -- R16-20
	"Secret",
}

-- Extra income added to the permanent multiplier by each rebirth.
local function incomeStep(n: number): number
	if n <= 5 then
		return 0.25
	elseif n <= 10 then
		return 0.35
	end
	return 0.5
end

-- How many of your best hamsters survive a rebirth (unlocked at these rebirths).
local KEEP = { [4] = 1, [8] = 2, [12] = 3, [16] = 4, [20] = 5 }

-- Named milestone rewards on top of the generated ones.
local MILESTONES: { [number]: { string } } = {
	[5] = { "Advanced upgrades (Research Lab)" },
	[10] = { "Major apartment upgrade: premium facade" },
	[15] = { "Royal rooftop crown" },
	[20] = { "Legendary apartment lights" },
	[25] = { "Hamster Tycoon title" },
}

function RebirthConfig.cost(n: number): number
	if n <= #COINS then
		return COINS[n]
	end
	return COINS[#COINS] * 4.5 ^ (n - #COINS)
end

function RebirthConfig.requirements(n: number)
	return {
		Coins = RebirthConfig.cost(n),
		Hamsters = math.min(4 + 2 * n, 40),
		Rarity = RARITY[math.min(n, #RARITY)],
	}
end

-- Permanent multiplier from rebirths. `boostLevel` = RebirthBoost token upgrade (+10% per level).
function RebirthConfig.multiplier(rebirths: number, boostLevel: number?): number
	local bonus = 0
	for n = 1, rebirths do
		bonus += incomeStep(n)
	end
	return 1 + bonus * (1 + 0.1 * (boostLevel or 0))
end

function RebirthConfig.slots(rebirths: number): number
	return RebirthConfig.BaseSlots + RebirthConfig.SlotsPerRebirth * rebirths
end

-- Old name kept for callers: slots earned through rebirths.
function RebirthConfig.bonusSlots(rebirths: number): number
	return RebirthConfig.SlotsPerRebirth * rebirths
end

-- Luck from rebirths: +5% every second rebirth.
function RebirthConfig.luck(rebirths: number): number
	return 0.05 * math.floor(rebirths / 2)
end

function RebirthConfig.keepBest(rebirths: number): number
	local keep = 0
	for n, count in KEEP do
		if rebirths >= n then
			keep = math.max(keep, count)
		end
	end
	return keep
end

function RebirthConfig.tokenReward(n: number): number
	return 1 + math.floor((n - 1) / 3)
end

function RebirthConfig.gemReward(n: number): number
	return RebirthConfig.GemReward + 50 * n
end

function RebirthConfig.startingCoins(rebirths: number): number
	return math.floor(150 * 1.5 ^ rebirths)
end

export type Reward = { Kind: string, Text: string, Major: boolean? }

-- Everything rebirth number `n` gives, in display order.
function RebirthConfig.rewards(n: number): { Reward }
	local list: { Reward } = {}
	table.insert(list, { Kind = "Slot", Text = string.format("+%d hamster slot (%d total)", RebirthConfig.SlotsPerRebirth, RebirthConfig.slots(n)) })
	table.insert(list, { Kind = "Income", Text = string.format("+%d%% income (x%s total)", math.floor(incomeStep(n) * 100 + 0.5), RebirthConfig.formatMultiplier(RebirthConfig.multiplier(n, 0))) })
	if n % 2 == 0 then
		table.insert(list, { Kind = "Luck", Text = "+5% luck" })
	end
	local floor = FloorConfig.unlockedAt(n)
	if floor then
		table.insert(list, { Kind = "Floor", Text = string.format("Floor %d unlocked: %s", floor.Index, floor.Name), Major = true })
	end
	for _, id in RarityConfig.Order do
		local definition = RarityConfig.ById[id]
		if definition.MinRebirth == n then
			table.insert(list, { Kind = "Rarity", Text = (if definition.Hidden then "???" else definition.Name) .. " hamsters can spawn", Major = true })
		end
	end
	for _, tier in SecurityConfig.Tiers do
		if tier.MinRebirth == n and n > 0 then
			table.insert(list, { Kind = "Security", Text = tier.Name .. " (" .. tier.Duration .. "s)" })
		end
	end
	if KEEP[n] then
		table.insert(list, { Kind = "Keep", Text = string.format("Keep your best %d hamster%s after rebirth", KEEP[n], if KEEP[n] > 1 then "s" else ""), Major = true })
	end
	local milestones: { string } = MILESTONES[n] or {}
	for _, text in milestones do
		table.insert(list, { Kind = "Milestone", Text = text, Major = true })
	end
	table.insert(list, { Kind = "Gems", Text = string.format("+%d gems, +%d rebirth token%s", RebirthConfig.gemReward(n), RebirthConfig.tokenReward(n), if RebirthConfig.tokenReward(n) > 1 then "s" else "") })
	return list
end

-- Old API: text lines of what rebirth `n` unlocks.
function RebirthConfig.unlocks(n: number): { string }
	local lines = {}
	for _, reward in RebirthConfig.rewards(n) do
		table.insert(lines, reward.Text)
	end
	return lines
end

-- What a rebirth resets and what it keeps (shown in the Rebirth screen).
RebirthConfig.Resets = { "Coins", "Coin upgrades", "Hamsters and wheels" }
RebirthConfig.Keeps = { "Hamster Index", "Rebirths, floors and slots", "Multipliers and luck", "Gems and tokens", "Token upgrades", "Cosmetics" }

local function ownedCount(data: any): number
	local count = 0
	for _, amount in data.Inventory do
		count += amount
	end
	return count
end

local function bestRank(data: any, rarityOf: (string) -> string?): number
	local best = 0
	for speciesId, amount in data.Inventory do
		local rarity = rarityOf(speciesId)
		if amount > 0 and rarity then
			best = math.max(best, RarityConfig.rank(rarity))
		end
	end
	return best
end

export type Check = { Kind: string, Label: string, Have: number, Need: number, Met: boolean }

-- Requirement check for the NEXT rebirth. `rarityOf(speciesId)` returns the rarity id.
function RebirthConfig.check(data: any, rarityOf: (string) -> string?): ({ Check }, boolean)
	local n = data.Rebirths + 1
	if n > RebirthConfig.MaxRebirths then
		return {}, false
	end
	local req = RebirthConfig.requirements(n)
	local rarity = RarityConfig.ById[req.Rarity]
	local owned = ownedCount(data)
	local best = bestRank(data, rarityOf)
	local checks: { Check } = {
		{ Kind = "Coins", Label = "Coins", Have = data.Coins, Need = req.Coins, Met = data.Coins >= req.Coins },
		{ Kind = "Hamsters", Label = "Secured hamsters", Have = owned, Need = req.Hamsters, Met = owned >= req.Hamsters },
		{ Kind = "Rarity", Label = string.format("Own a %s hamster or rarer", rarity.Name), Have = best, Need = rarity.Rank, Met = best >= rarity.Rank },
	}
	local all = true
	for _, check in checks do
		all = all and check.Met
	end
	return checks, all
end

function RebirthConfig.formatMultiplier(value: number): string
	local text = string.format("%.2f", value)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return text
end

return RebirthConfig
