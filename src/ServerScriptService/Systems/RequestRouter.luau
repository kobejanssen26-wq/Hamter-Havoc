--[[
	RequestRouter: the single door between UI buttons and the server.
	Client calls  Request:InvokeServer("BuyUpgrade", { Id = "SpawnLuck" })  and gets { ok, msg, ... } back.
	Every action is rate limited, payload types are checked, and the real work happens in the systems.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Remotes)

local CollectionSystem = require(script.Parent.CollectionSystem)
local DataSystem = require(script.Parent.DataSystem)
local ReplicationSystem = require(script.Parent.ReplicationSystem)
local QuestSystem = require(script.Parent.QuestSystem)
local RebirthSystem = require(script.Parent.RebirthSystem)
local RewardSystem = require(script.Parent.RewardSystem)
local Rewards = require(script.Parent.Rewards)
local SettingsSystem = require(script.Parent.SettingsSystem)
local ShopSystem = require(script.Parent.ShopSystem)
local UpgradeSystem = require(script.Parent.UpgradeSystem)

local RequestRouter = {}

local BURST = 20
local REFILL = 10 -- actions per second
local buckets: { [Player]: { Tokens: number, Last: number } } = {}

local function allow(player: Player): boolean
	local now = os.clock()
	local bucket = buckets[player]
	if not bucket then
		bucket = { Tokens = BURST, Last = now }
		buckets[player] = bucket
	end
	bucket.Tokens = math.min(BURST, bucket.Tokens + (now - bucket.Last) * REFILL)
	bucket.Last = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

local function result(ok: boolean, message: string?, extra: any?): any
	return { ok = ok, msg = message or "", extra = extra }
end

local function str(value: any): string?
	if type(value) == "string" and #value <= 64 then
		return value
	end
	return nil
end

local actions: { [string]: (Player, any) -> any } = {}

actions.Resync = function(player)
	ReplicationSystem.sendFull(player)
	return result(true)
end

actions.EquipBest = function(player)
	CollectionSystem.equipBest(player)
	return result(true, "Best hamsters equipped")
end

actions.Equip = function(player, payload)
	local id = str(payload.Id)
	if not id then
		return result(false, "Invalid hamster")
	end
	local ok, message = CollectionSystem.equip(player, id)
	return result(ok, message)
end

actions.Unequip = function(player, payload)
	local id = str(payload.Id)
	if not id then
		return result(false, "Invalid hamster")
	end
	local ok, message = CollectionSystem.unequip(player, id)
	return result(ok, message)
end

actions.Sell = function(player, payload)
	local id = str(payload.Id)
	if not id or type(payload.Count) ~= "number" then
		return result(false, "Invalid request")
	end
	local ok, message, earned = CollectionSystem.sell(player, id, payload.Count)
	return result(ok, message, earned)
end

actions.SellDuplicates = function(player, payload)
	local maxRank = if type(payload.MaxRank) == "number" then math.floor(payload.MaxRank) else nil
	local ok, message, earned = CollectionSystem.sellDuplicates(player, maxRank)
	return result(ok, message, earned)
end

actions.BuyUpgrade = function(player, payload)
	local ok, message, level = UpgradeSystem.buy(player, payload.Id)
	return result(ok, message, level)
end

actions.Rebirth = function(player)
	local ok, message = RebirthSystem.perform(player)
	return result(ok, message)
end

actions.ClaimQuest = function(player, payload)
	local ok, message = QuestSystem.claimQuest(player, payload.Id)
	return result(ok, message)
end

actions.ClaimAchievement = function(player, payload)
	local ok, message = QuestSystem.claimAchievement(player, payload.Id)
	return result(ok, message)
end

actions.ClaimIndexReward = function(player, payload)
	local rarity = str(payload.Rarity)
	if not rarity then
		return result(false, "Invalid rarity")
	end
	local ok, message, reward = CollectionSystem.claimIndexReward(player, rarity)
	if ok and reward then
		message = message .. " " .. Rewards.describe(Rewards.grant(player, reward))
	end
	return result(ok, message)
end

actions.ClaimDaily = function(player)
	local ok, message = RewardSystem.claimDaily(player)
	return result(ok, message)
end

actions.RedeemCode = function(player, payload)
	local ok, message = RewardSystem.redeemCode(player, payload.Code)
	return result(ok, message)
end

actions.UpdateSetting = function(player, payload)
	local ok, message = SettingsSystem.update(player, payload.Key, payload.Value)
	return result(ok, message)
end

actions.ShopBuy = function(player, payload)
	local ok, message, extra = ShopSystem.buy(player, payload.Id)
	return result(ok, message, extra)
end

actions.SetRoof = function(player, payload)
	local ok, message = ShopSystem.setRoof(player, payload.Key)
	return result(ok, message)
end

function RequestRouter.start()
	Remotes.func("Request").OnServerInvoke = function(player: Player, action: any, payload: any)
		if type(action) ~= "string" or not DataSystem.isLoaded(player) then
			return result(false, "Not ready")
		end
		if not allow(player) then
			return result(false, "Slow down!")
		end
		local handler = actions[action]
		if not handler then
			return result(false, "Unknown action")
		end
		if type(payload) ~= "table" then
			payload = {}
		end
		local ok, response = pcall(handler, player, payload)
		if not ok then
			warn(string.format("[RequestRouter] %s failed for %s: %s", action, player.Name, tostring(response)))
			return result(false, "Something went wrong")
		end
		return response
	end
end

function RequestRouter.forget(player: Player)
	buckets[player] = nil
end

return RequestRouter
