--[[
	RebirthSystem. A rebirth has real requirements (coins + a collection + a hamster of the right rarity, see
	RebirthConfig) and real rewards (a slot, permanent income + luck, floors, advanced upgrades, keepsakes ...).

	RESET: coins, owned hamsters except your best "keepsakes", coin upgrades.
	KEEP:  Hamster Index, rebirths + everything they unlocked, floors, token upgrades, gems, tokens,
	       quests, achievements, daily streak, cosmetics, gamepasses.
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
local CollectionSystem = require(script.Parent.CollectionSystem)
local DataSystem = require(script.Parent.DataSystem)
local EconomySystem = require(script.Parent.EconomySystem)
local Events = require(script.Parent.Events)
local Notifier = require(script.Parent.Notifier)
local ReplicationSystem = require(script.Parent.ReplicationSystem)

local RebirthSystem = {}

-- The `count` best hamsters (by income) of an inventory, as a new inventory table.
local function keepsakeInventory(inventory: { [string]: number }, count: number): { [string]: number }
	local entries = {}
	for speciesId, owned in inventory do
		local species = HamsterDatabase.ById[speciesId]
		if species and owned > 0 then
			table.insert(entries, { Id = speciesId, Income = HamsterDatabase.income(species), Owned = owned })
		end
	end
	table.sort(entries, function(a, b)
		if a.Income ~= b.Income then
			return a.Income > b.Income
		end
		return a.Id < b.Id
	end)
	local kept: { [string]: number } = {}
	local left = count
	for _, entry in entries do
		if left <= 0 then
			break
		end
		local take = math.min(entry.Owned, left)
		kept[entry.Id] = take
		left -= take
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
	local allMet, requirements = RebirthConfig.check(data, nextRebirth)
	if not allMet then
		for _, requirement in requirements do
			if not requirement.Met then
				if requirement.Kind == "Coins" then
					return false, "You need " .. Format.coins(requirement.Need) .. " to rebirth"
				elseif requirement.Kind == "Hamsters" then
					return false, string.format("You need %d hamsters in your collection (you have %d)", requirement.Need, requirement.Have)
				elseif requirement.Kind == "Species" then
					return false, "You need to own " .. requirement.Label
				end
				return false, string.format("You need at least one %s hamster (or better)", requirement.Rarity or "rare")
			end
		end
		return false, "Requirements not met"
	end

	local floorsBefore = FloorConfig.count(data.Rebirths)

	-- reset
	data.Rebirths = nextRebirth
	EconomySystem.setCoins(player, RebirthConfig.startingCoins(nextRebirth))
	data.Inventory = keepsakeInventory(data.Inventory, RebirthConfig.keepsakes(nextRebirth))
	data.Equipped = {}
	for id, definition in UpgradeConfig.Definitions do
		if definition.ResetOnRebirth then
			data.Upgrades[id] = nil
		end
	end
	CollectionSystem.equipBest(player)

	-- rewards
	local gems = EconomySystem.addGems(player, RebirthConfig.gemReward(nextRebirth), true)
	local tokens = RebirthConfig.tokenReward(nextRebirth)
	EconomySystem.addTokens(player, tokens)

	EconomySystem.updateAttributes(player)
	ReplicationSystem.mark(player, "Rebirths", "Inventory", "Equipped", "Upgrades", "Stats")
	Events.EquippedChanged:Fire(player)
	Events.Rebirthed:Fire(player, nextRebirth)
	AnnounceSystem.rebirth(player, nextRebirth)
	Remotes.event("Fx"):FireClient(player, "Rebirth", nextRebirth)
	Notifier.send(player, string.format("REBIRTH %d! +%s gems, +%d tokens, +1 hamster slot", nextRebirth, Format.short(gems), tokens), "reward")
	local floorsAfter = FloorConfig.count(nextRebirth)
	if floorsAfter > floorsBefore then
		local floor = FloorConfig.Floors[floorsAfter]
		Notifier.send(player, string.format("NEW FLOOR! Floor %d: %s is open", floor.Index, floor.Name), "reward")
	end
	return true, "Rebirth complete"
end

return RebirthSystem
