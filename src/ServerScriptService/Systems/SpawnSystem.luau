--[[
	SpawnSystem (the "hamster spawn system"): every player gets their own stream of hamsters that run
	along the road. Why per player: your Luck decides YOUR rarities, nothing is shared or stolen, and
	the server never has to move NPCs - it only remembers (spawnTime, speed) and clients animate it.

	A hamster's position is a pure function:  distance = (now - spawnTime) * speed,  pointAt(distance).
	The same function is used server-side to validate collecting (see PickupSystem).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage.Modules
local EconomyMath = require(Modules.EconomyMath)
local HamsterDatabase = require(Modules.HamsterDatabase)
local PathConfig = require(Modules.PathConfig)
local RarityConfig = require(Modules.RarityConfig)
local Util = require(Modules.Util)

local Remotes = require(ReplicatedStorage.Remotes)

local AnnounceSystem = require(script.Parent.AnnounceSystem)
local DataSystem = require(script.Parent.DataSystem)

local SpawnSystem = {}

SpawnSystem.MaxActive = 12
SpawnSystem.MinInterval = 2.4
SpawnSystem.MaxInterval = 3.8

export type Record = {
	Id: string,
	SpeciesId: string,
	Rarity: string,
	SpawnTime: number,
	Speed: number,
	Price: number,
}

local random = Random.new()
local active: { [Player]: { [string]: Record } } = {}
local nextSpawn: { [Player]: number } = {}
local counter = 0

function SpawnSystem.getRecord(player: Player, id: string): Record?
	local records = active[player]
	return if records then records[id] else nil
end

function SpawnSystem.getAll(player: Player): { [string]: Record }
	return active[player] or {}
end

-- Where the hamster is right now (server clock).
function SpawnSystem.positionOf(record: Record): Vector3
	local distance = (Workspace:GetServerTimeNow() - record.SpawnTime) * record.Speed
	local position = PathConfig.pointAt(distance)
	return position
end

function SpawnSystem.remove(player: Player, id: string, reason: string)
	local records = active[player]
	if records and records[id] then
		records[id] = nil
		Remotes.event("RemoveHamster"):FireClient(player, id, reason)
	end
end

function SpawnSystem.clear(player: Player)
	local records = active[player]
	if records then
		for id in records do
			Remotes.event("RemoveHamster"):FireClient(player, id, "Cleared")
		end
		active[player] = {}
	end
end

-- Picks a species for this player (rebirth gating + luck). Exposed for tests / capsules.
function SpawnSystem.roll(data: any, now: number): any
	local weights = RarityConfig.adjustedWeights(data.Rebirths, EconomyMath.luck(data, now))
	local ids = {}
	local values = {}
	for _, id in RarityConfig.Order do
		if weights[id] and #HamsterDatabase.Spawnable[id] > 0 then
			table.insert(ids, id)
			table.insert(values, weights[id])
		end
	end
	local index = Util.weightedIndex(values, random)
	local rarityId = if index then ids[index] else "Basic"
	local pool = HamsterDatabase.Spawnable[rarityId]
	return pool[random:NextInteger(1, #pool)]
end

function SpawnSystem.spawnFor(player: Player, forced: any?)
	local data = DataSystem.get(player)
	if not data then
		return
	end
	local records = active[player]
	if not records then
		records = {}
		active[player] = records
	end

	local species = forced or SpawnSystem.roll(data, os.time())
	local definition = RarityConfig.ById[species.Rarity]
	counter += 1
	local record: Record = {
		Id = "h" .. counter,
		SpeciesId = species.Id,
		Rarity = species.Rarity,
		SpawnTime = Workspace:GetServerTimeNow(),
		Speed = definition.Speed * (0.94 + random:NextNumber() * 0.12),
		Price = HamsterDatabase.price(species),
	}
	records[record.Id] = record
	Remotes.event("SpawnHamster"):FireClient(player, record.Id, record.SpeciesId, record.SpawnTime, record.Speed)

	if definition.Announce >= 1 then
		Remotes.event("Fx"):FireClient(player, "RareSpawn", species.Rarity)
	end
	AnnounceSystem.rareSpawn(player, species)
end

function SpawnSystem.start()
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			local serverNow = Workspace:GetServerTimeNow()
			for _, player in Players:GetPlayers() do
				local records = active[player]
				if records and DataSystem.isLoaded(player) then
					-- hamsters that reached the exit tunnel disappear
					for id, record in records do
						if (serverNow - record.SpawnTime) * record.Speed >= PathConfig.Length + 4 then
							SpawnSystem.remove(player, id, "Exit")
						end
					end
				end
				if DataSystem.isLoaded(player) and player:GetAttribute("DataLoaded") and player.Character then
					if not nextSpawn[player] then
						nextSpawn[player] = now + 1
					end
					if now >= nextSpawn[player] then
						nextSpawn[player] = now + SpawnSystem.MinInterval + random:NextNumber() * (SpawnSystem.MaxInterval - SpawnSystem.MinInterval)
						local count = 0
						local current: { [string]: Record } = active[player] or {}
						for _ in current do
							count += 1
						end
						if count < SpawnSystem.MaxActive then
							SpawnSystem.spawnFor(player)
						end
					end
				end
			end
		end
	end)
end

function SpawnSystem.forget(player: Player)
	active[player] = nil
	nextSpawn[player] = nil
end

return SpawnSystem
