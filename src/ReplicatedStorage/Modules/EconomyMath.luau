--[[
	Every multiplier and derived number in one place, so the server (which pays out) and the
	client (which only displays) always agree. Pure functions of the profile table.
]]

local FloorConfig = require(script.Parent.FloorConfig)
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

-- Extra multiplier for passive income (hamster training, turbo wheels).
function EconomyMath.incomeMultiplier(data: any, now: number): number
	return EconomyMath.coinMultiplier(data, now)
		* (1 + UpgradeConfig.effect("HamsterTraining", EconomyMath.level(data, "HamsterTraining")))
		* (1 + UpgradeConfig.effect("TurboWheels", EconomyMath.level(data, "TurboWheels")))
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
	luck *= 1 + RebirthConfig.luck(data.Rebirths) + FloorConfig.luck(data.Rebirths)
	luck *= 1 + UpgradeConfig.effect("LuckyCharms", EconomyMath.level(data, "LuckyCharms"))
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

function EconomyMath.floors(data: any): number
	return FloorConfig.unlocked(data.Rebirths)
end

-- Hamster slots: rebirth slots + Extra Storage + passes, never more than the wheels on your floors.
function EconomyMath.slots(data: any): number
	local wanted = RebirthConfig.slots(data.Rebirths)
		+ UpgradeConfig.effect("ExtraStorage", EconomyMath.level(data, "ExtraStorage"))
		+ (passEffect(data, "Slots") or 0)
	return math.min(wanted, FloorConfig.capacity(data.Rebirths))
end

export type Assignment = { SpeciesId: string, Slot: number, Floor: number, Bonus: number }

-- Which hamster runs on which wheel. Slots are used ground floor first, then top floor down, and the
-- best hamsters get the wheels with the biggest floor bonus. Shared by the payout and the house.
function EconomyMath.assignment(data: any): { Assignment }
	local slots = EconomyMath.slots(data)
	local order = FloorConfig.fillOrder(EconomyMath.floors(data))
	local active = {}
	for index = 1, math.min(slots, #order) do
		local slot = order[index]
		local floor = FloorConfig.floorOfSlot(slot)
		table.insert(active, { Slot = slot, Floor = floor, Bonus = FloorConfig.Floors[floor].WheelBonus, Order = index })
	end
	table.sort(active, function(a, b)
		if a.Bonus ~= b.Bonus then
			return a.Bonus > b.Bonus
		end
		return a.Order < b.Order
	end)

	local hamsters = {}
	for position, speciesId in data.Equipped do
		local species = HamsterDatabase.ById[speciesId]
		if species then
			table.insert(hamsters, { Id = speciesId, Income = HamsterDatabase.income(species), Position = position })
		end
	end
	table.sort(hamsters, function(a, b)
		if a.Income ~= b.Income then
			return a.Income > b.Income
		end
		return a.Position < b.Position
	end)

	local result: { Assignment } = {}
	for index, hamster in hamsters do
		local wheel = active[index]
		if not wheel then
			break
		end
		table.insert(result, { SpeciesId = hamster.Id, Slot = wheel.Slot, Floor = wheel.Floor, Bonus = wheel.Bonus })
	end
	return result
end

function EconomyMath.autoCollect(data: any, now: number): boolean
	return EconomyMath.boostActive(data, "AutoCollect", now) or passEffect(data, "AutoCollect") == true
end

-- Coins per second produced by the working hamsters (with every multiplier and floor bonus).
function EconomyMath.incomePerSecond(data: any, now: number): number
	local total = EconomyMath.BaseCoinsPerSecond
	for _, entry in EconomyMath.assignment(data) do
		total += HamsterDatabase.income(HamsterDatabase.ById[entry.SpeciesId]) * (1 + entry.Bonus)
	end
	return total * EconomyMath.incomeMultiplier(data, now)
end

-- Income of one hamster on a wheel with `bonus` (for wheel labels).
function EconomyMath.hamsterIncome(data: any, species: any, bonus: number, now: number): number
	return HamsterDatabase.income(species) * (1 + bonus) * EconomyMath.incomeMultiplier(data, now)
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
		Floors = EconomyMath.floors(data),
		Capacity = FloorConfig.capacity(data.Rebirths),
		AutoCollect = EconomyMath.autoCollect(data, now),
		IncomePerSecond = EconomyMath.incomePerSecond(data, now),
		Unique = EconomyMath.uniqueCount(data),
		IndexCoinBonus = IndexRewardConfig.bonus(data, "Coins"),
		IndexLuckBonus = IndexRewardConfig.bonus(data, "Luck"),
		Title = IndexRewardConfig.title(data) or "",
	}
end

return EconomyMath
