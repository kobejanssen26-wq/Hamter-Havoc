--[[
	GAME PASSES - configure your Robux passes here. This is the ONLY place you edit to add one.

	1. Create the pass in the Creator Dashboard (Monetization > Passes), copy its id.
	2. Add an entry below (or set the PassId of an existing one). PassId = 0 means "NOT CONFIGURED": the pass is
	   never purchasable and is only listed (greyed out, "Not configured") while testing in Studio.
	3. Put its benefit in `Benefit`. Supported benefit stats (read by EconomyMath on the server):
	     CoinMult (x cash), Luck (x luck), WalkSpeed (+speed), Slots (+hamster display slots), AutoCollect (true),
	     Gear = "item_id" (the owner receives that item from Content/Items, for example the Sky Glider)
	   A benefit that needs new code (a new stat) must be added to EconomyMath first - the shop UI never needs to change.
	4. Test: see docs/CONTENT_GUIDE.md ("Game passes").

	Fields: Key (stable, never change), PassId, Name, Description, Icon (drawn icon id or "rbxassetid://..." thumbnail),
	Order (sort position), Category (optional, default "Gamepasses"), Benefit, Enabled (optional, false = hidden and not purchasable).
	The Robux price is NOT written here: the server asks Roblox for it (MarketplaceService:GetProductInfo), so it can never be out of date.
]]

local GamepassConfig = {}

GamepassConfig.DefaultCategory = "Gamepasses"

GamepassConfig.List = {
	{ Key = "DoubleCoins", PassId = 0, Name = "2x Cash", Description = "Permanent x2 cash from everything.", Icon = "coin", Order = 10, Benefit = { CoinMult = 2 } },
	{ Key = "AutoCollect", PassId = 0, Name = "Auto Collect", Description = "Automatically claims affordable hamsters in range.", Icon = "bot", Order = 20, Benefit = { AutoCollect = true } },
	{ Key = "ExtraStorage", PassId = 0, Name = "Extra Storage", Description = "+3 hamster display slots.", Icon = "home", Order = 30, Benefit = { Slots = 3 } },
	{ Key = "LuckyCharm", PassId = 0, Name = "Lucky Charm", Description = "Permanent x1.25 luck.", Icon = "clover", Order = 40, Benefit = { Luck = 1.25 } },
	{ Key = "SkyGlider", PassId = 0, Name = "Sky Glider", Description = "A hang glider: jump, click and soar across the plaza for a few seconds. Recharges after every flight.", Icon = "glider", Order = 60, Category = "Equipment", Benefit = { Gear = "sky_glider" } },
	{ Key = "RocketBooster", PassId = 0, Name = "Rocket Booster", Description = "A hand-held rocket: click to launch yourself up and forward. Short, strong, every few seconds.", Icon = "rocket", Order = 70, Category = "Equipment", Benefit = { Gear = "rocket_booster" } },
	{ Key = "SpeedRunner", PassId = 0, Name = "Speed Runner", Description = "+4 walk speed.", Icon = "shoe", Order = 50, Benefit = { WalkSpeed = 4 } },
}

GamepassConfig.ByKey = {} :: { [string]: any }
GamepassConfig.ById = {} :: { [number]: any }
GamepassConfig.Effects = {} :: { [string]: any } -- key -> benefit (EconomyMath reads this)
GamepassConfig.Issues = {} :: { any }

local SUPPORTED = { CoinMult = true, Luck = true, WalkSpeed = true, Slots = true, AutoCollect = true, Gear = true }

table.sort(GamepassConfig.List, function(a, b)
	return (a.Order or 100) < (b.Order or 100)
end)
for _, entry in GamepassConfig.List do
	local function problem(message: string)
		table.insert(GamepassConfig.Issues, { Level = "error", Kind = "GamePass", Id = tostring(entry.Key), Message = message })
	end
	local ok = true
	if type(entry.Key) ~= "string" or entry.Key == "" or GamepassConfig.ByKey[entry.Key] then
		problem("Key must be a unique non-empty text")
		ok = false
	end
	if type(entry.PassId) ~= "number" or entry.PassId < 0 or entry.PassId % 1 ~= 0 then
		problem("PassId must be a whole number (0 = not configured)")
		ok = false
	end
	if type(entry.Name) ~= "string" or entry.Name == "" then
		problem("Name is missing")
		ok = false
	end
	if entry.Enabled ~= nil and type(entry.Enabled) ~= "boolean" then
		problem("Enabled must be true or false")
		ok = false
	end
	if type(entry.Benefit) ~= "table" then
		problem("Benefit is missing")
		ok = false
	else
		for stat in entry.Benefit do
			if not SUPPORTED[stat] then
				problem("unsupported benefit '" .. tostring(stat) .. "' (add it to EconomyMath first)")
				ok = false
			end
		end
	end
	if entry.PassId == 0 then
		table.insert(GamepassConfig.Issues, { Level = "warn", Kind = "GamePass", Id = tostring(entry.Key), Message = "PassId is 0: not configured, not purchasable" })
	elseif ok and GamepassConfig.ById[entry.PassId] then
		problem("PassId " .. entry.PassId .. " is used twice")
		ok = false
	end
	if ok then
		entry.Category = entry.Category or GamepassConfig.DefaultCategory
		GamepassConfig.ByKey[entry.Key] = entry
		GamepassConfig.Effects[entry.Key] = entry.Benefit
		if entry.PassId > 0 then
			GamepassConfig.ById[entry.PassId] = entry
		end
	end
end

function GamepassConfig.configured(entry: any): boolean
	return type(entry.PassId) == "number" and entry.PassId > 0
end

return GamepassConfig
