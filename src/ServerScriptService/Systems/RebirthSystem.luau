--[[
	RebirthSystem. Requirements and rewards come from RebirthConfig (coins + secured hamsters + one
	hamster of a certain rarity). See RebirthConfig for what resets and what stays.
	From Rebirth 4 your best hamsters (RebirthConfig.keepBest) survive the reset.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local FloorConfig = require(Modules.FloorConfig)
local Format = require(Modules.Format)
local HamsterDatabase = require(Modules.HamsterDatabase)
local RebirthConfig = require(Modules.RebirthConfig)
local UpgradeConfig = require(Modules.UpgradeConfig)

local Remotes = require(ReplicatedStorage.Remotes)

local AnnounceSystem = require(script.Parent.AnnounceSystem)
local DataSystem = require(script.Parent.DataSystem)
local EconomySystem = require(script.Parent.EconomySystem)
local Events = require(script.Parent.Events)
local Notifier = require(script.Parent.Notifier)
local ReplicationSystem = require(script.Parent.ReplicationSystem)

local RebirthSystem = {}

local function rarityOf(speciesId: string): string?
	local species = HamsterDatabase.ById[speciesId]
	return species and species.Rarity
end

-- The `count` highest-income hamsters in the inventory, as an inventory table.
local function bestHamsters(data: any, count: number): { [string]: number }
	local entries = {}
	for speciesId, amount in data.Inventory do
		local species = HamsterDatabase.ById[speciesId]
		if species then
			for _ = 1, amount do
				table.insert(entries, { Id = speciesId, Income = HamsterDatabase.income(species) })
			end
		end
	end
	table.sort(entries, function(a, b)
		if a.Income ~= b.Income then
			return a.Income > b.Income
		end
		return a.Id < b.Id
	end)
	local kept = {}
	for index = 1, math.min(count, #entries) do
		kept[entries[index].Id] = (kept[entries[index].Id] or 0) + 1
	end
	return kept
end

-- Returns (ok, message)
function RebirthSystem.perform(player: Player): (boolean, string)
	local data = DataSystem.get(player)
	if not data then
		return false, "No data"
	end
	local nextRebirth = data.Rebirths + 1
	if nextRebirth > RebirthConfig.MaxRebirths then
		return false, "You reached the maximum rebirth!"
	end
	local checks, ready = RebirthConfig.check(data, rarityOf)
	if not ready then
		for _, check in checks do
			if not check.Met then
				if check.Kind == "Coins" then
					return false, "You need " .. Format.coins(check.Need) .. " coins to rebirth"
				elseif check.Kind == "Hamsters" then
					return false, string.format("You need %d secured hamsters (you have %d)", check.Need, check.Have)
				end
				return false, check.Label .. " to rebirth"
			end
		end
		return false, "Requirements not met"
	end

	local floorsBefore = FloorConfig.unlocked(data.Rebirths)

	-- reset (the Index, gems, tokens, token upgrades, cosmetics, quests and stats stay)
	data.Rebirths = nextRebirth
	EconomySystem.setCoins(player, RebirthConfig.startingCoins(nextRebirth))
	data.Inventory = bestHamsters(data, RebirthConfig.keepBest(nextRebirth))
	data.Equipped = {}
	for speciesId, amount in data.Inventory do
		for _ = 1, amount do
			table.insert(data.Equipped, speciesId) -- kept hamsters go straight back to work
		end
	end
	for id, definition in UpgradeConfig.Definitions do
		if definition.ResetOnRebirth then
			data.Upgrades[id] = nil
		end
	end

	-- rewards
	local gems = EconomySystem.addGems(player, RebirthConfig.gemReward(nextRebirth), true)
	local tokens = RebirthConfig.tokenReward(nextRebirth)
	EconomySystem.addTokens(player, tokens)

	EconomySystem.updateAttributes(player)
	ReplicationSystem.mark(player, "Rebirths", "Inventory", "Equipped", "Upgrades", "Stats")
	Events.Rebirthed:Fire(player, nextRebirth)
	Events.EquippedChanged:Fire(player)
	AnnounceSystem.rebirth(player, nextRebirth)
	Remotes.event("Fx"):FireClient(player, "Rebirth", nextRebirth)
	local floorsAfter = FloorConfig.unlocked(nextRebirth)
	if floorsAfter > floorsBefore then
		local floor = FloorConfig.Floors[floorsAfter]
		Notifier.send(player, string.format("NEW FLOOR! Floor %d: %s is open in your apartment", floor.Index, floor.Name), "reward")
	end
	Notifier.send(player, string.format("REBIRTH %d! +1 slot, +%s gems, +%d tokens", nextRebirth, Format.short(gems), tokens), "reward")
	return true, "Rebirth complete"
end

return RebirthSystem
