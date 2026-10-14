--[[
	ShopSystem: gem purchases (capsules, boosts, coin pouch, roof colours) and the Robux side
	(gamepasses + gem packs through MarketplaceService). Prices come from ShopConfig only.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local GamepassConfig = require(Modules.GamepassConfig)
local ItemRegistry = require(Modules.ItemRegistry)
local Format = require(Modules.Format)
local HamsterDatabase = require(Modules.HamsterDatabase)
local RarityConfig = require(Modules.RarityConfig)
local ShopConfig = require(Modules.ShopConfig)
local Util = require(Modules.Util)

local CollectionSystem = require(script.Parent.CollectionSystem)
local DataSystem = require(script.Parent.DataSystem)
local EconomySystem = require(script.Parent.EconomySystem)
local GearSystem = require(script.Parent.GearSystem)
local DiscordLog = require(script.Parent.DiscordLog)
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
		local entry = GamepassConfig.ByKey[item.PassKey]
		if not entry or not GamepassConfig.configured(entry) then
			return false, "This pass isn't available yet"
		end
		if data.Passes[entry.Key] then
			return false, "You already own this"
		end
		-- already owned on Roblox but not yet granted here (bought elsewhere / earlier): grant, don't charge twice
		if ShopSystem.verifyPass(player, entry, 1) then
			return true, entry.Name .. " unlocked!"
		end
		MarketplaceService:PromptGamePassPurchase(player, entry.PassId)
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
	local gearItem = if item.Kind == "Item" or item.Kind == "Gear" then ItemRegistry.get(item.ItemId) else nil
	if item.Kind == "Item" or item.Kind == "Gear" then
		if not gearItem then
			return false, "Unsupported item"
		end
		-- price and currency are the ITEM's, never the client's
		if item.Kind == "Gear" and gearItem.Equip.Kind == "Consume" then
			return false, "Unsupported item"
		end
		if item.Kind == "Item" and gearItem.Equip.Kind ~= "Consume" then
			return false, "Unsupported item"
		end
		if item.Kind == "Gear" and ItemRegistry.owned(data, gearItem.Id) > 0 then
			return false, "You already own this"
		end
		if item.Kind == "Item" and (data.Items[item.ItemId] or 0) >= GearSystem.MaxStack then
			return false, string.format("You can hold at most %d of these", GearSystem.MaxStack)
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
	elseif item.Kind == "Item" or item.Kind == "Gear" then
		GearSystem.grant(player, item.ItemId)
		if item.Kind == "Gear" then
			return true, string.format("%s bought!", gearItem.DisplayName), { ItemId = item.ItemId }
		end
		return true, string.format("%s added to your hotbar", gearItem.DisplayName), { ItemId = item.ItemId }
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

---------------------------------------------------------------------------
-- game passes: Roblox is the only source of truth. A "purchased" report from the client or even from the prompt
-- event is only a hint to ask Roblox again; the benefit is granted when UserOwnsGamePassAsync says so.
---------------------------------------------------------------------------

local priceCache: { [number]: { At: number, Robux: number? } } = {}
local PRICE_TTL = 300

-- Does Roblox say this player owns the pass? Grants it on the profile when yes. Retries a few times because ownership
-- can lag a moment behind the purchase prompt closing.
function ShopSystem.verifyPass(player: Player, entry: any, attempts: number?): boolean
	local data = DataSystem.get(player)
	if not data or not GamepassConfig.configured(entry) then
		return false
	end
	for attempt = 1, attempts or 1 do
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, entry.PassId)
		end)
		if ok and owns then
			if not data.Passes[entry.Key] then
				data.Passes[entry.Key] = true
				ReplicationSystem.mark(player, "Passes")
				require(script.Parent.EconomySystem).updateAttributes(player)
				require(script.Parent.PlayerState).apply(player)
				DataSystem.markDirty(player)
				Notifier.send(player, entry.Name .. " unlocked! Thank you!", "reward")
				pcall(DiscordLog.purchase, player, "Game Pass", entry.Name, "granted")
			end
			return true
		end
		if attempt < (attempts or 1) then
			task.wait(1.5)
		end
	end
	return false
end

-- Checks which gamepasses the player owns (once per join, and on demand from the Refresh button).
function ShopSystem.loadPasses(player: Player)
	local data = DataSystem.get(player)
	if not data then
		return
	end
	for _, entry in GamepassConfig.List do
		if GamepassConfig.configured(entry) then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, entry.PassId)
			end)
			if ok then
				data.Passes[entry.Key] = owns or nil
			end
		end
	end
	ReplicationSystem.mark(player, "Passes")
end

function ShopSystem.refreshPasses(player: Player): (boolean, string)
	local data = DataSystem.get(player)
	if not data then
		return false, "Not ready"
	end
	ShopSystem.loadPasses(player)
	require(script.Parent.EconomySystem).updateAttributes(player)
	require(script.Parent.PlayerState).apply(player)
	return true, "Passes refreshed"
end

-- Robux prices straight from Roblox (never from our config). { [passKey] = robux | false } false = unknown.
function ShopSystem.passPrices(): { [string]: any }
	local prices = {}
	local now = os.clock()
	for _, entry in GamepassConfig.List do
		if GamepassConfig.configured(entry) then
			local cached = priceCache[entry.PassId]
			if not cached or now - cached.At > PRICE_TTL then
				local ok, info = pcall(function()
					return MarketplaceService:GetProductInfo(entry.PassId, Enum.InfoType.GamePass)
				end)
				cached = { At = now, Robux = if ok and info and info.IsForSale then info.PriceInRobux else nil }
				priceCache[entry.PassId] = cached
			end
			prices[entry.Key] = cached.Robux or false
		end
	end
	return prices
end

function ShopSystem.start()
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		local entry = GamepassConfig.ById[passId]
		if not entry or not purchased then
			return
		end
		-- the report only tells us to look; Roblox decides
		task.spawn(ShopSystem.verifyPass, player, entry, 4)
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
					pcall(DiscordLog.purchase, player, "Developer product", item.Name, "granted")
					return Enum.ProductPurchaseDecision.PurchaseGranted
				end
				pcall(DiscordLog.purchase, player, "Developer product", item.Name, "saving failed, will retry")
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

return ShopSystem
