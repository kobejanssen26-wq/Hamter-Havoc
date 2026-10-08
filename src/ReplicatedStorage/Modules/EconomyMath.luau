--[[
	Every multiplier and derived number in one place, so the server (which pays out) and the
	client (which only displays) always agree. Pure functions of the profile table.
]]

local HamsterDatabase = require(script.Parent.HamsterDatabase)
local IndexRewardConfig = require(script.Parent.IndexRewardConfig)
local RarityConfig = require(script.Parent.RarityConfig)
local RebirthConfig = require(script.Parent.RebirthConfig)
local ShopConfig = require(script.Parent.ShopConfig)
local UpgradeConfig = require(script.Parent.UpgradeConfig)

local EconomyMath = {}

EconomyMath.BaseCollectRange = 16
EconomyMath.BaseWalkSpeed = 16
EconomyMath.IndexBonusPerHamster = 0.005
EconomyMath.BaseCoinsPerSecond = 0.5 -- tiny trickle so nobody is ever stuck at 0 income

function EconomyMath.level(data: any, upgradeId: string): number
	return data.Upgrades[upgradeId] or 0
end

function EconomyMath.boostActive(data: any, boostId: string, now: number): boolean
	local expires = data.Boosts[boostId]
	return expires ~= nil and expires > now
end

function EconomyMath.boostRemaining(data: any, boostId: string, now: number): number
	local expires = data.Boosts[boostId]
	if expires and expires > now then
		return expires - now
	end
	return 0
end

local MULTIPLICATIVE = { Luck = true, CoinMult = true }

-- Combined value of one pass effect over every owned pass (nil if no pass grants it).
local function passEffect(data: any, effect: string): any
	local result = nil
	for key, owned in data.Passes do
		local effects = ShopConfig.PassEffects[key]
		local value = if owned and effects then effects[effect] else nil
		if value ~= nil and value ~= false then
			if type(value) == "number" then
				if MULTIPLICATIVE[effect] then
					result = (result or 1) * value
				else
					result = (result or 0) + value
				end
			else
				result = value
			end
		end
	end
	return result
end

function EconomyMath.uniqueCount(data: any): number
	local count = 0
	for _ in data.Index do
		count += 1
	end
	return count
end

function EconomyMath.rebirthMultiplier(data: any): number
	return RebirthConfig.multiplier(data.Rebirths, EconomyMath.level(data, "RebirthBoost"))
end

function EconomyMath.indexBonus(data: any): number
	return 1 + EconomyMath.IndexBonusPerHamster * EconomyMath.uniqueCount(data)
end

-- Multiplier applied to every coin gain.
function EconomyMath.coinMultiplier(data: any, now: number): number
	local multiplier = EconomyMath.rebirthMultiplier(data) * EconomyMath.indexBonus(data)
	multiplier *= 1 + UpgradeConfig.effect("CoinMultiplier", EconomyMath.level(data, "CoinMultiplier"))
	if EconomyMath.boostActive(data, "Coins2x", now) then
		multiplier *= 2
	end
	multiplier *= passEffect(data, "CoinMult") or 1
	multiplier *= 1 + IndexRewardConfig.bonus(data, "Coins")
	return multiplier
end

-- Extra multiplier for passive income (hamster training).
function EconomyMath.incomeMultiplier(data: any, now: number): number
	return EconomyMath.coinMultiplier(data, now) * (1 + UpgradeConfig.effect("HamsterTraining", EconomyMath.level(data, "HamsterTraining")))
end

function EconomyMath.gemMultiplier(data: any): number
	return 1 + UpgradeConfig.effect("GemBoost", EconomyMath.level(data, "GemBoost"))
end

function EconomyMath.luck(data: any, now: number): number
	local luck = UpgradeConfig.effect("SpawnLuck", EconomyMath.level(data, "SpawnLuck"))
	if EconomyMath.boostActive(data, "Luck2x", now) then
		luck *= 2
	end
	luck *= passEffect(data, "Luck") or 1
	luck *= 1 + IndexRewardConfig.bonus(data, "Luck")
	return math.clamp(luck, 1, RarityConfig.LuckCap)
end

function EconomyMath.collectRange(data: any): number
	return EconomyMath.BaseCollectRange + UpgradeConfig.effect("CollectionRange", EconomyMath.level(data, "CollectionRange"))
end

function EconomyMath.walkSpeed(data: any, now: number): number
	local speed = EconomyMath.BaseWalkSpeed + UpgradeConfig.effect("WalkSpeed", EconomyMath.level(data, "WalkSpeed"))
	if EconomyMath.boostActive(data, "Speed2x", now) then
		speed += 6
	end
	speed += passEffect(data, "WalkSpeed") or 0
	return speed
end

function EconomyMath.slots(data: any): number
	return RebirthConfig.BaseSlots
		+ UpgradeConfig.effect("ExtraStorage", EconomyMath.level(data, "ExtraStorage"))
		+ RebirthConfig.bonusSlots(data.Rebirths)
		+ (passEffect(data, "Slots") or 0)
end

function EconomyMath.autoCollect(data: any, now: number): boolean
	return EconomyMath.boostActive(data, "AutoCollect", now) or passEffect(data, "AutoCollect") == true
end

-- Coins per second produced by the equipped hamsters (with every multiplier).
function EconomyMath.incomePerSecond(data: any, now: number): number
	local total = EconomyMath.BaseCoinsPerSecond
	for _, speciesId in data.Equipped do
		local species = HamsterDatabase.ById[speciesId]
		if species then
			total += HamsterDatabase.income(species)
		end
	end
	return total * EconomyMath.incomeMultiplier(data, now)
end

-- Everything the UI needs in one table.
function EconomyMath.derived(data: any, now: number)
	return {
		CoinMultiplier = EconomyMath.coinMultiplier(data, now),
		IncomeMultiplier = EconomyMath.incomeMultiplier(data, now),
		GemMultiplier = EconomyMath.gemMultiplier(data),
		RebirthMultiplier = EconomyMath.rebirthMultiplier(data),
		IndexBonus = EconomyMath.indexBonus(data),
		Luck = EconomyMath.luck(data, now),
		CollectRange = EconomyMath.collectRange(data),
		WalkSpeed = EconomyMath.walkSpeed(data, now),
		Slots = EconomyMath.slots(data),
		AutoCollect = EconomyMath.autoCollect(data, now),
		IncomePerSecond = EconomyMath.incomePerSecond(data, now),
		Unique = EconomyMath.uniqueCount(data),
		IndexCoinBonus = IndexRewardConfig.bonus(data, "Coins"),
		IndexLuckBonus = IndexRewardConfig.bonus(data, "Luck"),
		Title = IndexRewardConfig.title(data) or "",
	}
end

return EconomyMath
