--[[
	Creates hamster data records (never models) and rolls rarities from the central config.
]]

local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local HamsterCatalog = require(Shared.Config.HamsterCatalog)

local HamsterFactory = {}

local random = Random.new()
local issuedSupply = {} -- [rarity] = how many limited hamsters were created

local function isSpawnable(name: string): boolean
	local definition = Rarities.Definitions[name]
	if not definition.SpawnsNaturally or definition.SpawnWeight <= 0 then
		return false
	end
	if definition.IsLimited and definition.MaximumSupply and (issuedSupply[name] or 0) >= definition.MaximumSupply then
		return false
	end
	return true
end

function HamsterFactory.rollRarity(): string
	local forced = GameConfig.Debug.ForceRarity
	if forced and Rarities.Definitions[forced] then
		return forced
	end

	local totalWeight = 0
	for _, name in Rarities.Order do
		if isSpawnable(name) then
			totalWeight += Rarities.Definitions[name].SpawnWeight
		end
	end

	local roll = random:NextNumber() * totalWeight
	local accumulated = 0
	for _, name in Rarities.Order do
		if isSpawnable(name) then
			accumulated += Rarities.Definitions[name].SpawnWeight
			if roll <= accumulated then
				return name
			end
		end
	end
	return "Common"
end

function HamsterFactory.create(rarityName: string?)
	rarityName = rarityName or HamsterFactory.rollRarity()
	local definition = Rarities.Definitions[rarityName]

	-- Limited rarities stop at their maximum supply.
	if definition.IsLimited and definition.MaximumSupply and (issuedSupply[rarityName] or 0) >= definition.MaximumSupply then
		return HamsterFactory.create("Common")
	end

	local mutationName = Mutations.Default
	local mutation = Mutations.Definitions[mutationName]
	local size = 1

	local serialNumber = nil
	if definition.IsLimited then
		issuedSupply[rarityName] = (issuedSupply[rarityName] or 0) + 1
		serialNumber = issuedSupply[rarityName]
	end

	local economy = GameConfig.Economy
	return {
		UniqueId = HttpService:GenerateGUID(false),
		Name = HamsterCatalog.pickName(rarityName, random),
		Rarity = rarityName,
		Mutation = mutationName,
		Size = size,
		IncomePerSecond = math.floor(economy.BaseIncomePerSecond * definition.IncomeMultiplier * mutation.IncomeMultiplier * size + 0.5),
		PurchasePrice = math.floor(economy.BasePrice * definition.PriceMultiplier * mutation.PriceMultiplier + 0.5),
		OwnerUserId = 0,
		IsLimited = definition.IsLimited,
		SerialNumber = serialNumber,
		State = "OnRoute",
		SlotIndex = nil,
		CarrierUserId = nil,
		OriginalOwnerUserId = nil,
	}
end

return HamsterFactory
