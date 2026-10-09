--[[
	Shop. Fair by design: everything a gamepass gives can also be earned or bought with gems,
	and nothing sells hamsters directly for Robux.

	Roblox product / gamepass ids are placeholders (0 = "coming soon", the buy button is disabled).
	Create the passes/products in the Creator Dashboard and paste the ids here.
]]

local ShopConfig = {}

ShopConfig.Sections = { "Pets", "Boosts", "Currency", "Gamepasses", "Cosmetics" }

ShopConfig.Boosts = {
	Coins2x = { Name = "2x Coins", Icon = "coin", Desc = "Doubles all coins earned." },
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
	{ Id = "boost_coins", Section = "Boosts", Name = "2x Coins (15 min)", Icon = "coin", Desc = "Doubles all coins earned.", Gems = 120, Kind = "Boost", BoostId = "Coins2x", Seconds = 900 },
	{ Id = "boost_luck", Section = "Boosts", Name = "2x Luck (10 min)", Icon = "clover", Desc = "Rarer hamsters appear more often.", Gems = 150, Kind = "Boost", BoostId = "Luck2x", Seconds = 600 },
	{ Id = "boost_speed", Section = "Boosts", Name = "Speed Boost (10 min)", Icon = "bolt", Desc = "+6 walk speed.", Gems = 60, Kind = "Boost", BoostId = "Speed2x", Seconds = 600 },
	{ Id = "boost_auto", Section = "Boosts", Name = "Auto Collect (10 min)", Icon = "bot", Desc = "Grabs hamsters in range for you.", Gems = 200, Kind = "Boost", BoostId = "AutoCollect", Seconds = 600 },

	-- Currency
	{ Id = "coin_pouch", Section = "Currency", Name = "Coin Pouch", Icon = "pouch", Desc = "10 minutes of your current income.", Gems = 60, Kind = "CoinPouch", Minutes = 10 },
	{ Id = "gems_small", Section = "Currency", Name = "Handful of Gems", Icon = "gem", Desc = "100 gems.", Robux = 49, Kind = "Product", ProductId = 0, GemAmount = 100 },
	{ Id = "gems_medium", Section = "Currency", Name = "Pouch of Gems", Icon = "gem", Desc = "550 gems.", Robux = 249, Kind = "Product", ProductId = 0, GemAmount = 550 },
	{ Id = "gems_large", Section = "Currency", Name = "Chest of Gems", Icon = "gem", Desc = "1,200 gems.", Robux = 499, Kind = "Product", ProductId = 0, GemAmount = 1200 },

	-- Gamepasses
	{ Id = "pass_coins", Section = "Gamepasses", Name = "2x Coins", Icon = "coin", Desc = "Permanent x2 coins.", Robux = 299, Kind = "Pass", PassKey = "DoubleCoins", PassId = 0 },
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
