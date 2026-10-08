--[[
	ShopSystem: gem purchases (capsules, boosts, coin pouch, roof colours) and the Robux side
	(gamepasses + gem packs through MarketplaceService). Prices come from ShopConfig only.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local EconomyMath = require(Modules.EconomyMath)
local Format = require(Modules.Format)
local HamsterDatabase = require(Modules.HamsterDatabase)
local RarityConfig = require(Modules.RarityConfig)
local ShopConfig = require(Modules.ShopConfig)
local Util = require(Modules.Util)

local CollectionSystem = require(script.Parent.CollectionSystem)
local DataSystem = require(script.Parent.DataSystem)
local EconomySystem = require(script.Parent.EconomySystem)
local Events = require(script.Parent.Events)
local Notifier = require(script.Parent.Notifier)
local ReplicationSystem = require(script.Parent.ReplicationSystem)

local ShopSystem = {}

local random = Random.new()

local function rollCapsule(data: any, pool: { [string]: number }): any
	local ids = {}
	local weights = {}
	for _, rarityId in RarityConfig.Order do
		local weight = pool[rarityId]
		if weight and RarityConfig.isUnlocked(rarityId, data.Rebirths) and #HamsterDatabase.Spawnable[rarityId] > 0 then
			table.insert(ids, rarityId)
			table.insert(weights, weight)
		end
	end
	local index = Util.weightedIndex(weights, random)
	if not index then
		return HamsterDatabase.Spawnable.Basic[1]
	end
	local list = HamsterDatabase.Spawnable[ids[index]]
	return list[random:NextInteger(1, #list)]
end

-- Returns (ok, message, extra) - extra is a table the UI can use (e.g. capsule result).
function ShopSystem.buy(player: Player, itemId: any): (boolean, string, any?)
	local data = DataSystem.get(player)
	local item = if type(itemId) == "string" then ShopConfig.ById[itemId] else nil
	if not data or not item then
		return false, "Unknown item"
	end

	if item.Kind == "Pass" then
		if item.PassId == 0 then
			return false, "This gamepass isn't available yet"
		end
		if data.Passes[item.PassKey] then
			return false, "You already own this"
		end
		MarketplaceService:PromptGamePassPurchase(player, item.PassId)
		return true, "Opening purchase..."
	elseif item.Kind == "Product" then
		if item.ProductId == 0 then
			return false, "Gem packs aren't available yet"
		end
		MarketplaceService:PromptProductPurchase(player, item.ProductId)
		return true, "Opening purchase..."
	end

	if item.Kind == "Roof" then
		if data.Cosmetics.Owned[item.RoofKey] then
			data.Cosmetics.Roof = item.RoofKey
			ReplicationSystem.mark(player, "Cosmetics")
			Events.RoofChanged:Fire(player)
			return true, item.Name .. " equipped"
		end
	end

	if not EconomySystem.trySpendGems(player, item.Gems) then
		return false, string.format("Not enough gems (need %s)", Format.short(item.Gems))
	end

	if item.Kind == "Capsule" then
		local species = rollCapsule(data, item.Pool)
		local result = CollectionSystem.grant(player, species.Id, "Capsule")
		return true, "You got " .. species.Name .. "!", { SpeciesId = species.Id, IsNew = result and result.IsNew or false }
	elseif item.Kind == "Boost" then
		EconomySystem.addBoost(player, item.BoostId, item.Seconds)
		return true, item.Name .. " activated!"
	elseif item.Kind == "CoinPouch" then
		local amount = math.max(1000, EconomyMath.incomePerSecond(data, os.time()) * 60 * item.Minutes)
		EconomySystem.addCoins(player, amount, false)
		return true, "+" .. Format.coins(amount) .. " coins"
	elseif item.Kind == "Roof" then
		data.Cosmetics.Owned[item.RoofKey] = true
		data.Cosmetics.Roof = item.RoofKey
		ReplicationSystem.mark(player, "Cosmetics")
		Events.RoofChanged:Fire(player)
		return true, item.Name .. " bought and equipped!"
	end
	return false, "Unsupported item"
end

function ShopSystem.setRoof(player: Player, key: any): (boolean, string)
	local data = DataSystem.get(player)
	if not data or type(key) ~= "string" then
		return false, "Invalid roof"
	end
	if key ~= "default" and not data.Cosmetics.Owned[key] then
		return false, "You don't own that roof yet"
	end
	data.Cosmetics.Roof = key
	ReplicationSystem.mark(player, "Cosmetics")
	Events.RoofChanged:Fire(player)
	return true, "Roof changed"
end

-- Checks which gamepasses the player owns (once per join).
function ShopSystem.loadPasses(player: Player)
	local data = DataSystem.get(player)
	if not data then
		return
	end
	for _, item in ShopConfig.Items do
		if item.Kind == "Pass" and item.PassId ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, item.PassId)
			end)
			if ok then
				data.Passes[item.PassKey] = owns or nil
			end
		end
	end
	ReplicationSystem.mark(player, "Passes")
end

function ShopSystem.start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local data = DataSystem.get(player)
		if not data then
			return
		end
		for _, item in ShopConfig.Items do
			if item.Kind == "Pass" and item.PassId == passId then
				data.Passes[item.PassKey] = true
				ReplicationSystem.mark(player, "Passes")
				Notifier.send(player, item.Name .. " unlocked! Thank you!", "reward")
			end
		end
	end)

	-- Developer products (gem packs). Must return PurchaseGranted only after the grant is saved.
	MarketplaceService.ProcessReceipt = function(receipt)
		local player = Players:GetPlayerByUserId(receipt.PlayerId)
		if not player then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local data = DataSystem.get(player)
		if not data then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
		local receiptKey = tostring(receipt.PurchaseId)
		if data.Receipts[receiptKey] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
		for _, item in ShopConfig.Items do
			if item.Kind == "Product" and item.ProductId == receipt.ProductId and item.ProductId ~= 0 then
				data.Receipts[receiptKey] = true
				EconomySystem.addGems(player, item.GemAmount, false)
				Notifier.send(player, "+" .. item.GemAmount .. " gems - thank you!", "reward")
				if DataSystem.save(player, false) then
					return Enum.ProductPurchaseDecision.PurchaseGranted
				end
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

return ShopSystem
