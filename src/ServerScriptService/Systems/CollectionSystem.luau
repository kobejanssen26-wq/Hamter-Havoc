--[[
	CollectionSystem: inventory, equipped hamsters (the ones earning coins in your house),
	selling, and the Hamster Index with its completion rewards.
	All rules are enforced here; the UI just asks.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local EconomyMath = require(Modules.EconomyMath)
local HamsterDatabase = require(Modules.HamsterDatabase)
local RarityConfig = require(Modules.RarityConfig)

local AnnounceSystem = require(script.Parent.AnnounceSystem)
local DataSystem = require(script.Parent.DataSystem)
local EconomySystem = require(script.Parent.EconomySystem)
local Events = require(script.Parent.Events)
local ReplicationSystem = require(script.Parent.ReplicationSystem)

local CollectionSystem = {}

local function equippedCount(data: any, speciesId: string): number
	local count = 0
	for _, id in data.Equipped do
		if id == speciesId then
			count += 1
		end
	end
	return count
end

function CollectionSystem.available(data: any, speciesId: string): number
	return (data.Inventory[speciesId] or 0) - equippedCount(data, speciesId)
end

-- Fills the display slots with the highest-income hamsters you own.
function CollectionSystem.equipBest(player: Player)
	local data = DataSystem.get(player)
	if not data then
		return
	end
	local entries = {}
	for speciesId, count in data.Inventory do
		local species = HamsterDatabase.ById[speciesId]
		if species and count > 0 then
			table.insert(entries, { Id = speciesId, Income = HamsterDatabase.income(species), Count = count })
		end
	end
	table.sort(entries, function(a, b)
		if a.Income ~= b.Income then
			return a.Income > b.Income
		end
		return a.Id < b.Id
	end)

	local slots = EconomyMath.slots(data)
	local equipped = {}
	for _, entry in entries do
		for _ = 1, entry.Count do
			if #equipped >= slots then
				break
			end
			table.insert(equipped, entry.Id)
		end
	end
	data.Equipped = equipped
	ReplicationSystem.mark(player, "Equipped")
	Events.EquippedChanged:Fire(player)
end

function CollectionSystem.equip(player: Player, speciesId: string): (boolean, string)
	local data = DataSystem.get(player)
	if not data or not HamsterDatabase.ById[speciesId] then
		return false, "Unknown hamster"
	end
	if #data.Equipped >= EconomyMath.slots(data) then
		return false, "All your display slots are full"
	end
	if CollectionSystem.available(data, speciesId) <= 0 then
		return false, "You don't have a free copy of that hamster"
	end
	table.insert(data.Equipped, speciesId)
	ReplicationSystem.mark(player, "Equipped")
	Events.EquippedChanged:Fire(player)
	return true, "Equipped"
end

function CollectionSystem.unequip(player: Player, speciesId: string): (boolean, string)
	local data = DataSystem.get(player)
	if not data then
		return false, "No data"
	end
	local position = table.find(data.Equipped, speciesId)
	if not position then
		return false, "That hamster isn't equipped"
	end
	table.remove(data.Equipped, position)
	ReplicationSystem.mark(player, "Equipped")
	Events.EquippedChanged:Fire(player)
	return true, "Unequipped"
end

local function sellAmount(player: Player, data: any, speciesId: string, amount: number): number
	local species = HamsterDatabase.ById[speciesId]
	local earned = EconomySystem.addCoins(player, HamsterDatabase.sellValue(species) * amount, true)
	data.Inventory[speciesId] = (data.Inventory[speciesId] or 0) - amount
	if data.Inventory[speciesId] <= 0 then
		data.Inventory[speciesId] = nil
	end
	data.Stats.Sold += amount
	return earned
end

function CollectionSystem.sell(player: Player, speciesId: string, amount: number): (boolean, string, number?)
	local data = DataSystem.get(player)
	if not data or not HamsterDatabase.ById[speciesId] then
		return false, "Unknown hamster"
	end
	if type(amount) ~= "number" or amount ~= amount or amount < 1 then
		return false, "Invalid amount"
	end
	amount = math.floor(amount)
	local available = CollectionSystem.available(data, speciesId)
	if available < amount then
		return false, "You can only sell hamsters that aren't equipped"
	end
	local earned = sellAmount(player, data, speciesId, amount)
	ReplicationSystem.mark(player, "Inventory", "Stats")
	return true, "Sold", earned
end

-- Sells every copy beyond the first of each hamster (never touches equipped ones).
function CollectionSystem.sellDuplicates(player: Player, maxRank: number?): (boolean, string, number?)
	local data = DataSystem.get(player)
	if not data then
		return false, "No data"
	end
	local limit = maxRank or 99
	local total = 0
	local sold = 0
	local ids = {}
	for speciesId in data.Inventory do
		table.insert(ids, speciesId)
	end
	for _, speciesId in ids do
		local species = HamsterDatabase.ById[speciesId]
		if species and RarityConfig.rank(species.Rarity) <= limit then
			local extra = math.min(CollectionSystem.available(data, speciesId), (data.Inventory[speciesId] or 0) - 1)
			if extra > 0 then
				total += sellAmount(player, data, speciesId, extra)
				sold += extra
			end
		end
	end
	if sold == 0 then
		return false, "No duplicates to sell"
	end
	ReplicationSystem.mark(player, "Inventory", "Stats")
	return true, string.format("Sold %d duplicates", sold), total
end

-- Gives the player a hamster (collected, from a capsule, a reward ...).
-- Returns { IsNew, AutoSold }.
function CollectionSystem.grant(player: Player, speciesId: string, source: string?): { IsNew: boolean, AutoSold: boolean }?
	local data = DataSystem.get(player)
	local species = HamsterDatabase.ById[speciesId]
	if not data or not species then
		return nil
	end

	data.Inventory[speciesId] = (data.Inventory[speciesId] or 0) + 1
	local isNew = not data.Index[speciesId]
	data.Index[speciesId] = true
	data.Stats.HamstersCollected += 1
	data.Stats.Found[species.Rarity] = (data.Stats.Found[species.Rarity] or 0) + 1

	-- auto-delete: only extra copies of hamsters you already have, never rewards/exclusives
	local autoSold = false
	local threshold = data.Settings.AutoDelete
	if threshold > 0 and source ~= "Reward" and not species.Exclusive and (data.Inventory[speciesId] or 0) > 1 and RarityConfig.rank(species.Rarity) <= threshold then
		if CollectionSystem.available(data, speciesId) > 0 then
			sellAmount(player, data, speciesId, 1)
			autoSold = true
		end
	end

	ReplicationSystem.mark(player, "Inventory", "Index", "Stats")
	if not autoSold and data.Settings.AutoEquip then
		CollectionSystem.equipBest(player)
	end

	AnnounceSystem.rareCollected(player, species, isNew)
	Events.Collected:Fire(player, speciesId, isNew, autoSold)
	return { IsNew = isNew, AutoSold = autoSold }
end

---------------------------------------------------------------------------
-- index
---------------------------------------------------------------------------

function CollectionSystem.isRarityComplete(data: any, rarityId: string): boolean
	for _, species in HamsterDatabase.Spawnable[rarityId] do
		if not data.Index[species.Id] then
			return false
		end
	end
	return true
end

-- Returns (ok, message, reward)
function CollectionSystem.claimIndexReward(player: Player, rarityId: string): (boolean, string, any?)
	local data = DataSystem.get(player)
	local definition = RarityConfig.ById[rarityId]
	if not data or not definition then
		return false, "Unknown rarity"
	end
	if data.IndexRewards[rarityId] then
		return false, "Already claimed"
	end
	if not CollectionSystem.isRarityComplete(data, rarityId) then
		return false, "Collect every " .. definition.Name .. " hamster first"
	end
	data.IndexRewards[rarityId] = true
	ReplicationSystem.mark(player, "IndexRewards")
	return true, definition.Name .. " collection complete!", definition.IndexReward
end

return CollectionSystem
