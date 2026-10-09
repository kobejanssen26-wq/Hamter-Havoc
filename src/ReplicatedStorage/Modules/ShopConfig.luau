--[[
	Shop. Fair by design: everything a gamepass gives can also be earned or bought with gems,
	and nothing sells hamsters directly for Robux.

	Roblox product / gamepass ids are placeholders (0 = "coming soon", the buy button is disabled).
	Create the passes/products in the Creator Dashboard and paste the ids here.
]]

local ShopConfig = {}

-- Categories the shop can show, in order. A category only appears when it holds at least one item that can
-- really be bought right now (nothing is faked to fill a tab). "Equipment" and "Limited Offers" stay empty until
-- real equipment / timed offers (item.Limited = { EndsAt = unixTime }) are added to Items.
ShopConfig.Categories = {
	{ Id = "Boosts", Name = "Boosts", Icon = "bolt" },
	{ Id = "Equipment", Name = "Equipment", Icon = "shield" },
	{ Id = "Hamsters", Name = "Hamsters", Icon = "hamster" },
	{ Id = "Diamonds", Name = "Diamonds", Icon = "gem" },
	{ Id = "Cosmetics", Name = "Cosmetics", Icon = "paint" },
	{ Id = "Limited", Name = "Limited Offers", Icon = "star" },
}
ShopConfig.SectionToCategory = { Pets = "Hamsters", Boosts = "Boosts", Currency = "Diamonds", Gamepasses = "Diamonds", Cosmetics = "Cosmetics" }

ShopConfig.Boosts = {
	Coins2x = { Name = "2x Cash", Icon = "coin", Desc = "Doubles all cash earned." },
	Luck2x = { Name = "2x Luck", Icon = "clover", Desc = "Doubles your luck (still capped)." },
	Speed2x = { Name = "Speed Boost", Icon = "bolt", Desc = "+6 walk speed." },
	AutoCollect = { Name = "Auto Collect", Icon = "bot", Desc = "Automatically grabs hamsters you can afford within range." },
}

-- Capsules: instant hamster for gems. Pool = rarity weights.
ShopConfig.Items = {
	-- Pets
	{ Id = "capsule_cozy", Section = "Pets", Name = "Cozy Capsule", Icon = "egg", Desc = "A random Basic - Rare hamster.", Gems = 150, Kind = "Capsule", Pool = { Basic = 50, Cute = 30, Shiny = 15, Rare = 5 } },
	{ Id = "capsule_lucky", Section = "Pets", Name = "Lucky Capsule", Icon = "gift", Desc = "A random Rare - Legendary hamster.", Gems = 700, Kind = "Capsule", Pool = { Rare = 60, Epic = 28, Ultra = 9, Legendary = 3 } },
	{ Id = "capsule_royal", Section = "Pets", Name = "Royal Capsule", Icon = "crown", Desc = "Epic or better (needs 1+ rebirth for Mythic).", Gems = 2500, Kind = "Capsule", Pool = { Epic = 55, Ultra = 28, Legendary = 14, Mythic = 3 } },

	-- Boosts
	{ Id = "boost_coins", Section = "Boosts", Name = "2x Cash (15 min)", Icon = "coin", Desc = "Doubles all cash earned.", Gems = 120, Kind = "Item", ItemId = "item_coins" },
	{ Id = "boost_luck", Section = "Boosts", Name = "2x Luck (10 min)", Icon = "clover", Desc = "Rarer hamsters appear more often.", Gems = 150, Kind = "Item", ItemId = "item_luck" },
	{ Id = "boost_speed", Section = "Boosts", Name = "Speed Tonic (10 min)", Icon = "bolt", Desc = "+6 walk speed.", Gems = 60, Kind = "Item", ItemId = "item_speed" },
	{ Id = "boost_auto", Section = "Boosts", Name = "Auto Collect (10 min)", Icon = "bot", Desc = "Grabs hamsters in range for you.", Gems = 200, Kind = "Item", ItemId = "item_auto" },

	-- Cash-priced consumable (the second currency): a cheap everyday item
	{ Id = "tonic_cash", Section = "Boosts", Name = "Speed Tonic (10 min)", Icon = "bolt", Desc = "+6 walk speed. Paid in cash.", Coins = 2500, Kind = "Item", ItemId = "item_speed" },

	-- Currency
	{ Id = "coin_pouch", Section = "Boosts", Name = "Cash Pouch", Icon = "pouch", Desc = "10 minutes of your current income.", Gems = 60, Kind = "Item", ItemId = "item_pouch" },
	{ Id = "gems_small", Section = "Currency", Name = "Handful of Diamonds", Icon = "gem", Desc = "100 diamonds.", Robux = 49, Kind = "Product", ProductId = 0, GemAmount = 100 },
	{ Id = "gems_medium", Section = "Currency", Name = "Pouch of Diamonds", Icon = "gem", Desc = "550 diamonds.", Robux = 249, Kind = "Product", ProductId = 0, GemAmount = 550 },
	{ Id = "gems_large", Section = "Currency", Name = "Chest of Diamonds", Icon = "gem", Desc = "1,200 diamonds.", Robux = 499, Kind = "Product", ProductId = 0, GemAmount = 1200 },

	-- Gamepasses
	{ Id = "pass_coins", Section = "Gamepasses", Name = "2x Cash", Icon = "coin", Desc = "Permanent x2 cash.", Robux = 299, Kind = "Pass", PassKey = "DoubleCoins", PassId = 0 },
	{ Id = "pass_auto", Section = "Gamepasses", Name = "Auto Collect", Icon = "bot", Desc = "Permanent auto collect.", Robux = 399, Kind = "Pass", PassKey = "AutoCollect", PassId = 0 },
	{ Id = "pass_storage", Section = "Gamepasses", Name = "Extra Storage", Icon = "home", Desc = "+3 house display slots.", Robux = 199, Kind = "Pass", PassKey = "ExtraStorage", PassId = 0 },
	{ Id = "pass_luck", Section = "Gamepasses", Name = "Lucky Charm", Icon = "clover", Desc = "Permanent x1.25 luck.", Robux = 249, Kind = "Pass", PassKey = "LuckyCharm", PassId = 0 },
	{ Id = "pass_speed", Section = "Gamepasses", Name = "Speed Runner", Icon = "shoe", Desc = "+4 walk speed.", Robux = 99, Kind = "Pass", PassKey = "SpeedRunner", PassId = 0 },

	-- Cosmetics (roof colours for your house)
	{ Id = "roof_rose", Section = "Cosmetics", Name = "Rose Roof", Icon = "flower", Desc = "A soft pink roof.", Gems = 100, Kind = "Roof", RoofKey = "rose", Color = Color3.fromRGB(246, 150, 180) },
	{ Id = "roof_mint", Section = "Cosmetics", Name = "Mint Roof", Icon = "leaf", Desc = "A fresh mint roof.", Gems = 100, Kind = "Roof", RoofKey = "mint", Color = Color3.fromRGB(130, 215, 175) },
	{ Id = "roof_sky", Section = "Cosmetics", Name = "Sky Roof", Icon = "cloud", Desc = "A sky blue roof.", Gems = 100, Kind = "Roof", RoofKey = "sky", Color = Color3.fromRGB(120, 180, 245) },
	{ Id = "roof_sun", Section = "Cosmetics", Name = "Sunny Roof", Icon = "sun", Desc = "A warm golden roof.", Gems = 150, Kind = "Roof", RoofKey = "sun", Color = Color3.fromRGB(250, 200, 80) },
	{ Id = "roof_lavender", Section = "Cosmetics", Name = "Lavender Roof", Icon = "heart", Desc = "A dreamy lavender roof.", Gems = 150, Kind = "Roof", RoofKey = "lavender", Color = Color3.fromRGB(185, 160, 235) },
	{ Id = "roof_midnight", Section = "Cosmetics", Name = "Midnight Roof", Icon = "moon", Desc = "A deep midnight roof.", Gems = 250, Kind = "Roof", RoofKey = "midnight", Color = Color3.fromRGB(60, 62, 120) },
}

ShopConfig.ById = {} :: { [string]: any }
-- Currency + price in one place: item.Currency is "Coins", "Gems" or "Robux"; the UI shows them as Cash / Diamonds / Robux.
for _, item in ShopConfig.Items do
	item.Category = item.Category or ShopConfig.SectionToCategory[item.Section] or "Boosts"
	if item.Coins then
		item.Currency, item.Price = "Coins", item.Coins
	elseif item.Gems then
		item.Currency, item.Price = "Gems", item.Gems
	elseif item.Robux then
		item.Currency, item.Price = "Robux", item.Robux
	end
end

-- Can this item be bought right now? (Robux items need a real pass / product id; timed offers must be running.)
function ShopConfig.available(item: any, now: number?): boolean
	if (item.Kind == "Pass" and item.PassId == 0) or (item.Kind == "Product" and item.ProductId == 0) then
		return false
	end
	if item.Limited and item.Limited.EndsAt and (now or os.time()) >= item.Limited.EndsAt then
		return false
	end
	return true
end

-- Categories that really have something to sell, each with its items.
function ShopConfig.categories(now: number?): { any }
	local result = {}
	for _, category in ShopConfig.Categories do
		local items = {}
		for _, item in ShopConfig.Items do
			if (item.Limited and category.Id == "Limited" or (not item.Limited and item.Category == category.Id)) and ShopConfig.available(item, now) then
				table.insert(items, item)
			end
		end
		if #items > 0 then
			table.insert(result, { Id = category.Id, Name = category.Name, Icon = category.Icon, Items = items })
		end
	end
	return result
end
ShopConfig.RoofByKey = {} :: { [string]: any }
for _, item in ShopConfig.Items do
	ShopConfig.ById[item.Id] = item
	if item.RoofKey then
		ShopConfig.RoofByKey[item.RoofKey] = item
	end
end

-- Permanent effects of gamepasses (read by EconomyMath on both sides).
ShopConfig.PassEffects = {
	DoubleCoins = { CoinMult = 2 },
	AutoCollect = { AutoCollect = true },
	ExtraStorage = { Slots = 3 },
	LuckyCharm = { Luck = 1.25 },
	SpeedRunner = { WalkSpeed = 4 },
}

return ShopConfig
