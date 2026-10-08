--[[
	EconomySystem: the only place that changes Coins / Gems / Tokens.
	Passive income ticks once a second. Everything is validated here; the client can only read the numbers.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local EconomyMath = require(Modules.EconomyMath)

local DataSystem = require(script.Parent.DataSystem)
local Events = require(script.Parent.Events)
local ReplicationSystem = require(script.Parent.ReplicationSystem)

local EconomySystem = {}

local boostSignature: { [Player]: string } = {}

local function validAmount(amount: any): boolean
	return type(amount) == "number" and amount == amount and amount >= 0 and amount < 1e300
end

function EconomySystem.updateAttributes(player: Player)
	local data = DataSystem.get(player)
	if not data then
		return
	end
	player:SetAttribute("Coins", math.floor(data.Coins))
	player:SetAttribute("Gems", math.floor(data.Gems))
	player:SetAttribute("Tokens", math.floor(data.Tokens))
	player:SetAttribute("Rebirths", data.Rebirths)
end

-- Adds coins. With `applyMultiplier` the player's coin multiplier is applied (income, selling).
-- Returns the amount actually added.
function EconomySystem.addCoins(player: Player, amount: number, applyMultiplier: boolean?): number
	local data = DataSystem.get(player)
	if not data or not validAmount(amount) then
		return 0
	end
	local total = amount
	if applyMultiplier then
		total *= EconomyMath.coinMultiplier(data, os.time())
	end
	data.Coins += total
	data.Stats.CoinsEarned += total
	DataSystem.markDirty(player)
	EconomySystem.updateAttributes(player)
	return total
end

function EconomySystem.setCoins(player: Player, amount: number)
	local data = DataSystem.get(player)
	if data and validAmount(amount) then
		data.Coins = amount
		DataSystem.markDirty(player)
		EconomySystem.updateAttributes(player)
	end
end

function EconomySystem.trySpendCoins(player: Player, amount: number): boolean
	local data = DataSystem.get(player)
	if not data or not validAmount(amount) or data.Coins < amount then
		return false
	end
	data.Coins -= amount
	DataSystem.markDirty(player)
	EconomySystem.updateAttributes(player)
	return true
end

function EconomySystem.addGems(player: Player, amount: number, applyMultiplier: boolean?): number
	local data = DataSystem.get(player)
	if not data or not validAmount(amount) then
		return 0
	end
	local total = amount
	if applyMultiplier then
		total *= EconomyMath.gemMultiplier(data)
	end
	total = math.floor(total + 0.5)
	data.Gems += total
	data.Stats.GemsEarned += total
	DataSystem.markDirty(player)
	EconomySystem.updateAttributes(player)
	return total
end

function EconomySystem.trySpendGems(player: Player, amount: number): boolean
	local data = DataSystem.get(player)
	if not data or not validAmount(amount) or data.Gems < amount then
		return false
	end
	data.Gems -= amount
	DataSystem.markDirty(player)
	EconomySystem.updateAttributes(player)
	return true
end

function EconomySystem.addTokens(player: Player, amount: number)
	local data = DataSystem.get(player)
	if data and validAmount(amount) then
		data.Tokens += math.floor(amount)
		DataSystem.markDirty(player)
		EconomySystem.updateAttributes(player)
	end
end

function EconomySystem.trySpendTokens(player: Player, amount: number): boolean
	local data = DataSystem.get(player)
	if not data or not validAmount(amount) or data.Tokens < amount then
		return false
	end
	data.Tokens -= amount
	DataSystem.markDirty(player)
	EconomySystem.updateAttributes(player)
	return true
end

-- Boosts stack in time: buying a 10 minute boost twice gives 20 minutes.
function EconomySystem.addBoost(player: Player, boostId: string, seconds: number)
	local data = DataSystem.get(player)
	if not data or not validAmount(seconds) then
		return
	end
	local now = os.time()
	data.Boosts[boostId] = math.max(now, data.Boosts[boostId] or 0) + seconds
	ReplicationSystem.mark(player, "Boosts")
end

function EconomySystem.start()
	task.spawn(function()
		local last = os.clock()
		local tick = 0
		while true do
			task.wait(1)
			local now = os.clock()
			local elapsed = now - last
			last = now
			tick += 1
			local unix = os.time()
			for _, player in Players:GetPlayers() do
				local data = DataSystem.get(player)
				if data then
					EconomySystem.addCoins(player, EconomyMath.incomePerSecond(data, unix) * elapsed, false)

					-- boosts that started/ended change the derived numbers: tell the client
					local signature = ""
					for id, expires in data.Boosts do
						if expires > unix then
							signature ..= id .. ","
						end
					end
					if boostSignature[player] ~= signature then
						boostSignature[player] = signature
						ReplicationSystem.mark(player, "Boosts")
					end
					if tick % 5 == 0 then
						ReplicationSystem.mark(player, "Stats")
						Events.StatsChanged:Fire(player)
					end
				end
			end
		end
	end)
end

function EconomySystem.forget(player: Player)
	boostSignature[player] = nil
end

return EconomySystem
