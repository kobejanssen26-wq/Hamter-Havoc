--[[
	ShopSystem: gem purchases (capsules, boosts, coin pouch, roof colours) and the Robux side
	(gamepasses + gem packs through MarketplaceService). Prices come from ShopConfig only.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local HotbarConfig = require(Modules.HotbarConfig)
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

local MAX_ITEM_STACK = 99
local DOUBLE_CLICK_SECONDS = 0.4
local lastRequest: { [Player]: { [string]: number } } = {}

local function currencyName(currency: string): string
	return if currency == "Gems" then "diamonds" elseif currency == "Coins" then "cash" else "Robux"
end

local function spend(player: Player, item: any): boolean
	if item.Currency == "Coins" then
		return EconomySystem.trySpendCoins(player, item.Price)
	elseif item.Currency == "Gems" then
		return EconomySystem.trySpendGems(player, item.Price)
	end
	return false
end

-- Returns (ok, message, extra) - extra is a table the UI can use (e.g. capsule result).
-- Everything is decided here: the client only sends the item id, never a price or a reward.
function ShopSystem.buy(player: Player, itemId: any): (boolean, string, any?)
	local data = DataSystem.get(player)
	local item = if type(itemId) == "string" then ShopConfig.ById[itemId] else nil
	if not data or not item then
		return false, "Unknown item"
	end

	-- duplicate request protection (double clicks, replayed remotes)
	local requests = lastRequest[player]
	if not requests then
		requests = {}
		lastRequest[player] = requests
	end
	local clock = os.clock()
	if requests[item.Id] and clock - requests[item.Id] < DOUBLE_CLICK_SECONDS then
		return false, "Purchase already in progress"
	end
	requests[item.Id] = clock

	if not ShopConfig.available(item) then
		return false, "This item isn't available right now"
	end

	if item.Kind == "Pass" then
		if data.Passes[item.PassKey] then
			return false, "You already own this"
		end
		MarketplaceService:PromptGamePassPurchase(player, item.PassId)
		return true, "Opening purchase..."
	elseif item.Kind == "Product" then
		MarketplaceService:PromptProductPurchase(player, item.ProductId)
		return true, "Opening purchase..."
	end

	if item.MinRebirth and data.Rebirths < item.MinRebirth then
		return false, string.format("Unlocks at rebirth %d", item.MinRebirth)
	end

	if item.Kind == "Roof" and data.Cosmetics.Owned[item.RoofKey] then
		data.Cosmetics.Roof = item.RoofKey
		ReplicationSystem.mark(player, "Cosmetics")
		Events.RoofChanged:Fire(player)
		return true, item.Name .. " equipped", { Equipped = true }
	end

	-- validate everything BEFORE taking money, so deduct + grant is all-or-nothing
	local hotbarItem = if item.Kind == "Item" then HotbarConfig.ById[item.ItemId] else nil
	if item.Kind == "Item" then
		if not hotbarItem then
			return false, "Unsupported item"
		end
		if (data.Items[item.ItemId] or 0) >= MAX_ITEM_STACK then
			return false, string.format("You can hold at most %d of these", MAX_ITEM_STACK)
		end
	elseif item.Kind ~= "Capsule" and item.Kind ~= "Roof" then
		return false, "Unsupported item"
	end

	if not spend(player, item) then
		local have = if item.Currency == "Coins" then data.Coins else data.Gems
		return false, string.format("Not enough %s (need %s, you have %s)", currencyName(item.Currency), Format.short(item.Price), Format.short(have))
	end

	if item.Kind == "Capsule" then
		local species = rollCapsule(data, item.Pool)
		local result = CollectionSystem.grant(player, species.Id, "Capsule")
		return true, "You got " .. species.Name .. "!", { SpeciesId = species.Id, IsNew = result and result.IsNew or false }
	elseif item.Kind == "Item" then
		data.Items[item.ItemId] = (data.Items[item.ItemId] or 0) + 1
		ReplicationSystem.mark(player, "Items")
		return true, string.format("%s added to your hotbar", hotbarItem.Name), { ItemId = item.ItemId }
	elseif item.Kind == "Roof" then
		data.Cosmetics.Owned[item.RoofKey] = true
		data.Cosmetics.Roof = item.RoofKey
		ReplicationSystem.mark(player, "Cosmetics")
		Events.RoofChanged:Fire(player)
		return true, item.Name .. " bought and equipped!"
	end
	return true, "Purchased"
end

function ShopSystem.forget(player: Player)
	lastRequest[player] = nil
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
