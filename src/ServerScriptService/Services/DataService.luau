--[[
	Server-authoritative player state: cash, collector balance, hamster ownership.
	Mirrors values to player attributes / leaderstats for the UI (read only for clients).
	In-memory only for the prototype; persistence (DataStore) plugs in here later.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Rebirth = require(Shared.Config.Rebirth)

local DataService = {}

local states = {}

local function isValidAmount(amount: any): boolean
	return type(amount) == "number" and amount == amount and amount >= 0 and amount < math.huge
end

local function sync(player: Player)
	local state = states[player]
	if not state then
		return
	end
	player:SetAttribute("Cash", state.Cash)
	player:SetAttribute("Stored", state.Stored)
	local leaderstats = player:FindFirstChild("leaderstats")
	local cashValue = leaderstats and leaderstats:FindFirstChild("Cash")
	if cashValue then
		cashValue.Value = math.floor(state.Cash)
	end
end

function DataService.create(player: Player)
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local cashValue = Instance.new("NumberValue")
	cashValue.Name = "Cash"
	cashValue.Parent = leaderstats
	leaderstats.Parent = player

	states[player] = {
		UserId = player.UserId,
		Cash = GameConfig.Economy.StartingCash,
		Stored = 0, -- money waiting in the base collector
		Rebirths = 0, -- prepared for the rebirth system
		Hamsters = {}, -- [UniqueId] = hamster record
	}
	sync(player)
	DataService.recompute(player)
end

function DataService.remove(player: Player)
	states[player] = nil
end

function DataService.get(player: Player)
	return states[player]
end

function DataService.addCash(player: Player, amount: number): boolean
	local state = states[player]
	if not state or not isValidAmount(amount) then
		return false
	end
	state.Cash += amount
	sync(player)
	return true
end

function DataService.trySpend(player: Player, amount: number): boolean
	local state = states[player]
	if not state or not isValidAmount(amount) or state.Cash < amount then
		return false
	end
	state.Cash -= amount
	sync(player)
	return true
end

function DataService.addStored(player: Player, amount: number)
	local state = states[player]
	if not state or not isValidAmount(amount) then
		return
	end
	state.Stored += amount
	sync(player)
end

-- Empties the collector and returns what was in it.
function DataService.takeStored(player: Player): number
	local state = states[player]
	if not state then
		return 0
	end
	local amount = state.Stored
	state.Stored = 0
	sync(player)
	return amount
end

function DataService.addHamster(player: Player, hamster)
	local state = states[player]
	if not state then
		return
	end
	hamster.OwnerUserId = player.UserId
	hamster.State = "Owned"
	state.Hamsters[hamster.UniqueId] = hamster
	DataService.recompute(player)
end

function DataService.removeHamster(player: Player, uniqueId: string)
	local state = states[player]
	if not state then
		return
	end
	state.Hamsters[uniqueId] = nil
	DataService.recompute(player)
end

-- Returns (ownerPlayer, hamster) for a hamster id.
function DataService.getHamsterOwner(uniqueId: string)
	for player, state in states do
		local hamster = state.Hamsters[uniqueId]
		if hamster then
			return player, hamster
		end
	end
	return nil, nil
end

-- Income of all hamsters that are in wheels right now (stolen ones pay nothing).
function DataService.getIncomePerSecond(player: Player): number
	local state = states[player]
	if not state then
		return 0
	end
	local total = 0
	for _, hamster in state.Hamsters do
		if hamster.State == "Owned" then
			total += hamster.IncomePerSecond
		end
	end
	return total * Rebirth.getTier(state.Rebirths).IncomeMultiplier
end

function DataService.recompute(player: Player)
	player:SetAttribute("IncomePerSecond", DataService.getIncomePerSecond(player))
end

return DataService
