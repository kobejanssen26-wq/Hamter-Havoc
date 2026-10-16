--[[
	SpinWheelConfig: the Lucky Wheel. Edit the numbers here (or the two live ones in the admin panel: Settings -> Wheel).

	  Wheel.FreeSpinSeconds   (GameConfig, live)  one free spin becomes available this often. Default 10800 = every 3 hours.
	                          There is ONE free spin per period and nothing to pay for another one.
	  Wheel.Clockwise         (GameConfig, live)  which way the wheel turns, seen from the front. Flip it if it turns the wrong way.
	  Wheel.SpinSeconds       (GameConfig, live)  how long a spin takes
	  Wheel.CashCapPercent    (GameConfig, live)  no cash prize may be worth more than this % of the player's NEXT REBIRTH COST

	Prizes: the slices, in order around the wheel. Fields of a prize:
	  Id, Label, Icon, Color    what the slice shows (Label is a general name, the exact amount is shown to the player and depends
	                            on how far they are). The physical wheel shows a PICTURE: Icon names a drawn icon (UI/Icons) that is
	                            used until you set Image = "rbxassetid://<your image>" - that image (uploaded by you) replaces it.
	  Short                     only the fallback word for places that cannot draw pictures (the exported standalone model)
	  Weight                    how likely, relative to the other prizes that this player can win right now
	  MinRebirth / MaxRebirth   optional: the prize can only be won from / up to this rebirth (locked slices are greyed out)
	  Reward                    what it pays. Any of:
	    Coins = { Percent = {lo, hi}, Minutes = {lo, hi} }
	        cash that SCALES WITH PROGRESS: the bigger of
	          "lo..hi percent of the cost of your next rebirth"  and  "lo..hi minutes of your current income per second"
	        so it feels good at every stage: a new player gets a few thousand, a late-game player millions, never 200,000 for a
	        beginner and never pocket change for a veteran. Never above Wheel.CashCapPercent of the next rebirth cost.
	    Gems = { Min, Max, PerRebirth }   diamonds: between Min and Max, +PerRebirth (0.15 = 15%) for every rebirth, capped at MaxGems
	    Items = { "item_id" }, Boost = { Id, Seconds }, Tokens = n   fixed rewards
	    HamsterRarity = "Rare" | HamsterByRebirth = { [0] = "Cute", [3] = "Rare" }
	        a random hamster of that rarity; the by-rebirth table uses the highest entry at or below the player's rebirths
	    Hamster = "species_id"   one specific hamster

	The draw happens on the SERVER (SpinSystem); the client only animates the result it was told. Everything below is validated:
	a broken prize is skipped (and reported by SpinWheelConfig.validate()), never paid out.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(script.Parent.GameConfig)
local HamsterDatabase = require(script.Parent.HamsterDatabase)
local RarityConfig = require(script.Parent.RarityConfig)
local RebirthConfig = require(script.Parent.RebirthConfig)
local EconomyMath = require(script.Parent.EconomyMath)
local Format = require(script.Parent.Format)

local SpinWheelConfig = {}

SpinWheelConfig.MaxGems = 5000 -- hard cap on one diamond prize
SpinWheelConfig.MinCoins = 100 -- a cash prize is never smaller than this

SpinWheelConfig.Prizes = {
	{ Id = "cash_small", Short = "CASH", Label = "Cash", Icon = "coin", Color = Color3.fromRGB(60, 214, 84), Weight = 24, Reward = { Coins = { Percent = { 0.12, 0.25 }, Minutes = { 1, 2 } } } },
	{ Id = "gems_small", Short = "GEMS", Label = "Diamonds", Icon = "gem", Color = Color3.fromRGB(176, 98, 255), Weight = 16, Reward = { Gems = { Min = 25, Max = 40, PerRebirth = 0.15 } } },
	{ Id = "speed", Short = "SPEED", Label = "Speed Tonic", Icon = "bolt", Color = Color3.fromRGB(56, 160, 255), Weight = 11, Reward = { Items = { "item_speed" } } },
	{ Id = "cash_mid", Short = "BIG CASH", Label = "Big Cash", Icon = "pouch", Color = Color3.fromRGB(255, 148, 28), Weight = 13, Reward = { Coins = { Percent = { 0.35, 0.7 }, Minutes = { 3, 6 } } } },
	{ Id = "luck", Short = "LUCK", Label = "Lucky Boost 15 min", Icon = "clover", Color = Color3.fromRGB(26, 214, 190), Weight = 8, Reward = { Boost = { Id = "Luck2x", Seconds = 900 } } },
	{ Id = "hamster", Short = "HAMSTER", Label = "Mystery Hamster", Icon = "heart", Color = Color3.fromRGB(255, 120, 200), Weight = 6, Reward = { HamsterByRebirth = { [0] = "Cute", [1] = "Shiny", [3] = "Rare", [5] = "Epic", [8] = "Ultra", [12] = "Legendary" } } },
	{ Id = "banana", Short = "BANANA", Label = "Banana Peel", Icon = "banana", Color = Color3.fromRGB(255, 214, 40), Weight = 7, Reward = { Items = { "banana_peel" } } },
	{ Id = "gems_big", Short = "MANY GEMS", Label = "Many Diamonds", Icon = "gem", Color = Color3.fromRGB(255, 84, 170), Weight = 6, MinRebirth = 1, Reward = { Gems = { Min = 100, Max = 160, PerRebirth = 0.2 } } },
	{ Id = "cash_big", Short = "HUGE CASH", Label = "Huge Cash", Icon = "crown", Color = Color3.fromRGB(255, 72, 88), Weight = 3, MinRebirth = 1, Reward = { Coins = { Percent = { 1.2, 2.2 }, Minutes = { 10, 18 } } } },
	{ Id = "jackpot", Short = "JACKPOT", Label = "JACKPOT", Icon = "gift", Color = Color3.fromRGB(255, 214, 40), Weight = 1, Reward = { Gems = { Min = 400, Max = 600, PerRebirth = 0.2 }, Coins = { Percent = { 3, 5 }, Minutes = { 30, 40 } } } },
}

---------------------------------------------------------------------------
-- settings that can be changed live
---------------------------------------------------------------------------

-- The server reads GameConfig directly; clients get the live values from attributes the server publishes (SpinSystem), so the
-- window shows the real price even after an admin changed it.
local function setting(key: string): any
	if not RunService:IsServer() then
		local published = ReplicatedStorage:GetAttribute("Wheel_" .. key)
		if published ~= nil then
			return published
		end
	end
	return GameConfig.get("Wheel", key)
end

SpinWheelConfig.Settings = { "FreeSpinSeconds", "CashCapPercent", "Clockwise", "SpinSeconds" }

function SpinWheelConfig.freeSpinSeconds(): number
	return setting("FreeSpinSeconds")
end

-- true = the wheel turns clockwise seen from the FRONT (the side with the prizes).
function SpinWheelConfig.clockwise(): boolean
	return setting("Clockwise") == true
end

function SpinWheelConfig.spinSeconds(): number
	return setting("SpinSeconds")
end

---------------------------------------------------------------------------
-- how the physical wheel turns (ONE place, used by the server, every client and the tests)
---------------------------------------------------------------------------

SpinWheelConfig.Turns = 6 -- full rounds before it stops

-- Angles are in DEGREES, positive = clockwise seen from the front of the wheel. The wheel plane faces -Z (towards the road), and
-- a positive rotation about +Z turns clockwise for somebody standing at -Z, so this is just base * Angles(0, 0, rad(degrees)).
function SpinWheelConfig.rotorCFrame(base: CFrame, degrees: number): CFrame
	return base * CFrame.Angles(0, 0, math.rad(degrees))
end

-- Where the rotor has to stop so that prize `index` (slice i sits (i-1) * 360 / count degrees clockwise from the top) is under the
-- fixed pointer at the top, after at least `turns` rounds in the configured direction, starting from angle `current`.
function SpinWheelConfig.targetAngle(current: number, index: number, count: number, clockwise: boolean?, turns: number?): number
	local slice = (index - 1) * 360 / count
	local rounds = 360 * (turns or SpinWheelConfig.Turns)
	if clockwise == nil then
		clockwise = SpinWheelConfig.clockwise()
	end
	if clockwise then
		return current + rounds + ((360 - slice - current % 360) % 360)
	end
	return current - rounds - ((current % 360 + slice) % 360)
end

-- Which prize index is under the pointer when the rotor stands at `angle`.
function SpinWheelConfig.indexAt(angle: number, count: number): number
	local step = 360 / count
	return math.floor(((-angle) % 360) / step + 0.5) % count + 1
end

-- Progress of the turn (0..1) from the progress of the time (0..1): the wheel speeds up for the first part, then slows down to a stop
-- (velocity ramps up linearly, then falls off smoothly; this is the integral of that, so position and speed are both continuous).
local ACCELERATE = 0.12
local TOTAL = ACCELERATE / 2 + (1 - ACCELERATE) / 4
function SpinWheelConfig.ease(t: number): number
	t = math.clamp(t, 0, 1)
	if t < ACCELERATE then
		return (t * t / (2 * ACCELERATE)) / TOTAL
	end
	local rest = (1 - ACCELERATE)
	local s = (t - ACCELERATE) / rest -- 0..1 over the slowing part
	return (ACCELERATE / 2 + rest * (1 - (1 - s) ^ 4) / 4) / TOTAL
end

---------------------------------------------------------------------------
-- the player's situation (the same numbers on the server and the client, so the wheel can show real amounts)
---------------------------------------------------------------------------

export type Context = { Rebirths: number, Income: number, NextRebirthCost: number }

function SpinWheelConfig.context(data: any, now: number): Context
	local rebirths = math.max(0, math.floor(data.Rebirths or 0))
	return {
		Rebirths = rebirths,
		Income = EconomyMath.incomePerSecond(data, now),
		NextRebirthCost = RebirthConfig.cost(rebirths + 1),
	}
end

local function isRange(range: any): boolean
	return type(range) == "table" and type(range[1]) == "number" and type(range[2]) == "number" and range[1] >= 0 and range[2] >= range[1] and range[2] == range[2]
end

---------------------------------------------------------------------------
-- validation (run at server start; the draw skips prizes that fail)
---------------------------------------------------------------------------

-- Returns a problem description, or nil when the prize is usable.
function SpinWheelConfig.problem(prize: any): string?
	if type(prize) ~= "table" or type(prize.Id) ~= "string" or prize.Id == "" then
		return "a prize has no Id"
	end
	if prize.Image ~= nil and (type(prize.Image) ~= "string" or string.match(prize.Image, "^rbxassetid://%d+$") == nil) then
		return prize.Id .. ': Image must look like "rbxassetid://1234567" (or be left out to use the drawn Icon)'
	end
	if type(prize.Weight) ~= "number" or prize.Weight ~= prize.Weight or prize.Weight <= 0 or prize.Weight > 1e6 then
		return prize.Id .. ": Weight must be a number above 0"
	end
	local reward = prize.Reward
	if type(reward) ~= "table" then
		return prize.Id .. ": Reward is missing"
	end
	local pays = false
	if reward.Coins ~= nil then
		pays = true
		if type(reward.Coins) == "number" then
			if reward.Coins <= 0 then return prize.Id .. ": Coins must be above 0" end
		elseif not (isRange(reward.Coins.Percent) or isRange(reward.Coins.Minutes)) then
			return prize.Id .. ": Coins needs a valid Percent = {lo, hi} and/or Minutes = {lo, hi}"
		end
	end
	if reward.Gems ~= nil then
		pays = true
		local gems = reward.Gems
		if type(gems) == "number" then
			if gems <= 0 then return prize.Id .. ": Gems must be above 0" end
		elseif type(gems) ~= "table" or type(gems.Min) ~= "number" or type(gems.Max) ~= "number" or gems.Min < 1 or gems.Max < gems.Min or (gems.PerRebirth ~= nil and (type(gems.PerRebirth) ~= "number" or gems.PerRebirth < 0)) then
			return prize.Id .. ": Gems needs Min >= 1, Max >= Min and PerRebirth >= 0"
		end
	end
	if reward.Tokens ~= nil then
		pays = true
		if type(reward.Tokens) ~= "number" or reward.Tokens < 1 then return prize.Id .. ": Tokens must be 1 or more" end
	end
	if reward.Boost ~= nil then
		pays = true
		if type(reward.Boost) ~= "table" or type(reward.Boost.Id) ~= "string" or type(reward.Boost.Seconds) ~= "number" or reward.Boost.Seconds <= 0 then
			return prize.Id .. ": Boost needs Id and Seconds above 0"
		end
	end
	if reward.Items ~= nil then
		pays = true
		if type(reward.Items) ~= "table" or #reward.Items == 0 then return prize.Id .. ": Items must be a list of item ids" end
	end
	if reward.Hamster ~= nil then
		pays = true
		if not HamsterDatabase.ById[reward.Hamster] then return prize.Id .. ": unknown hamster " .. tostring(reward.Hamster) end
	end
	if reward.HamsterRarity ~= nil then
		pays = true
		if not RarityConfig.ById[reward.HamsterRarity] then return prize.Id .. ": unknown rarity " .. tostring(reward.HamsterRarity) end
	end
	if reward.HamsterByRebirth ~= nil then
		pays = true
		local any = false
		for rebirth, rarity in reward.HamsterByRebirth do
			any = true
			if type(rebirth) ~= "number" or not RarityConfig.ById[rarity] then
				return prize.Id .. ": HamsterByRebirth needs [rebirth] = \"Rarity\" entries with real rarities"
			end
		end
		if not any then return prize.Id .. ": HamsterByRebirth is empty" end
	end
	if not pays then
		return prize.Id .. ": the Reward pays nothing"
	end
	if prize.MinRebirth ~= nil and type(prize.MinRebirth) ~= "number" then return prize.Id .. ": MinRebirth must be a number" end
	if prize.MaxRebirth ~= nil and type(prize.MaxRebirth) ~= "number" then return prize.Id .. ": MaxRebirth must be a number" end
	return nil
end

function SpinWheelConfig.validate(): { string }
	local issues = {}
	local usable = 0
	local seen = {}
	for _, prize in SpinWheelConfig.Prizes do
		local issue = SpinWheelConfig.problem(prize)
		if issue then
			table.insert(issues, issue)
		elseif seen[prize.Id] then
			table.insert(issues, prize.Id .. ": duplicate Id")
		else
			seen[prize.Id] = true
			usable += 1
		end
	end
	if usable == 0 then
		table.insert(issues, "the wheel has no usable prize")
	end
	return issues
end

---------------------------------------------------------------------------
-- drawing
---------------------------------------------------------------------------

-- Can this player win this prize right now?
function SpinWheelConfig.eligible(prize: any, ctx: Context): boolean
	if SpinWheelConfig.problem(prize) then
		return false
	end
	if prize.MinRebirth and ctx.Rebirths < prize.MinRebirth then
		return false
	end
	if prize.MaxRebirth and ctx.Rebirths > prize.MaxRebirth then
		return false
	end
	return true
end

function SpinWheelConfig.totalWeight(ctx: Context): number
	local total = 0
	for _, prize in SpinWheelConfig.Prizes do
		if SpinWheelConfig.eligible(prize, ctx) then
			total += prize.Weight
		end
	end
	return total
end

-- Picks a prize index for a random number in [0, 1), among the prizes this player can win. nil = nothing can be won.
function SpinWheelConfig.pick(roll: number, ctx: Context): number?
	local total = SpinWheelConfig.totalWeight(ctx)
	if total <= 0 then
		return nil
	end
	local target = math.clamp(roll, 0, 0.999999) * total
	local running = 0
	local last = nil
	for index, prize in SpinWheelConfig.Prizes do
		if SpinWheelConfig.eligible(prize, ctx) then
			running += prize.Weight
			last = index
			if target < running then
				return index
			end
		end
	end
	return last
end

local function lerp(range: { number }, t: number): number
	return range[1] + (range[2] - range[1]) * math.clamp(t, 0, 1)
end

local function coinAmount(spec: any, ctx: Context, t: number): number
	if type(spec) == "number" then
		return spec
	end
	local amount = 0
	if isRange(spec.Percent) then
		amount = math.max(amount, ctx.NextRebirthCost * lerp(spec.Percent, t) / 100)
	end
	if isRange(spec.Minutes) then
		amount = math.max(amount, ctx.Income * 60 * lerp(spec.Minutes, t))
	end
	return amount
end

local function gemAmount(spec: any, ctx: Context, t: number): number
	if type(spec) == "number" then
		return spec
	end
	return lerp({ spec.Min, spec.Max }, t) * (1 + (spec.PerRebirth or 0) * ctx.Rebirths)
end

-- The rarity a "mystery hamster" prize uses for this player.
function SpinWheelConfig.hamsterRarity(reward: any, ctx: Context): string?
	if reward.HamsterRarity then
		return reward.HamsterRarity
	end
	if reward.HamsterByRebirth then
		local bestKey, best = -1, nil
		for rebirth, rarity in reward.HamsterByRebirth do
			if rebirth <= ctx.Rebirths and rebirth > bestKey then
				bestKey, best = rebirth, rarity
			end
		end
		return best
	end
	return nil
end

-- The reward table (for Rewards.grant) a prize pays this player. rolls.Amount / rolls.Pick are random numbers in [0, 1).
-- Always sane: cash >= MinCoins and <= CashCapPercent of the next rebirth cost, diamonds 1..MaxGems.
function SpinWheelConfig.reward(prize: any, ctx: Context, rolls: { Amount: number?, Pick: number? }?): any
	local r = rolls or {}
	local source = prize.Reward
	local reward: any = {}
	if source.Coins ~= nil then
		local cap = math.max(SpinWheelConfig.MinCoins, ctx.NextRebirthCost * setting("CashCapPercent") / 100)
		reward.Coins = math.floor(math.clamp(coinAmount(source.Coins, ctx, r.Amount or 0.5), SpinWheelConfig.MinCoins, cap))
	end
	if source.Gems ~= nil then
		reward.Gems = math.floor(math.clamp(gemAmount(source.Gems, ctx, r.Amount or 0.5), 1, SpinWheelConfig.MaxGems))
	end
	if source.Tokens ~= nil then
		reward.Tokens = source.Tokens
	end
	if source.Boost ~= nil then
		reward.Boost = table.clone(source.Boost)
	end
	if source.Items ~= nil then
		reward.Items = table.clone(source.Items)
	end
	if source.Hamster ~= nil then
		reward.Hamster = source.Hamster
	end
	local rarity = SpinWheelConfig.hamsterRarity(source, ctx)
	if rarity then
		local pool = HamsterDatabase.Spawnable[rarity]
		if pool and #pool > 0 then
			reward.Hamster = pool[math.clamp(math.floor((r.Pick or 0.5) * #pool) + 1, 1, #pool)].Id
		end
	end
	return reward
end

-- Text for the wheel window: what this prize is worth to THIS player (midpoint of the possible amounts).
function SpinWheelConfig.preview(prize: any, ctx: Context): string
	if not SpinWheelConfig.eligible(prize, ctx) then
		if prize.MinRebirth and ctx.Rebirths < prize.MinRebirth then
			return string.format("%s (from rebirth %d)", prize.Label, prize.MinRebirth)
		end
		return prize.Label
	end
	local reward = SpinWheelConfig.reward(prize, ctx, { Amount = 0.5, Pick = 0.5 })
	local parts = {}
	if reward.Coins then
		table.insert(parts, "~" .. Format.short(reward.Coins) .. " cash")
	end
	if reward.Gems then
		table.insert(parts, "~" .. Format.short(reward.Gems) .. " diamonds")
	end
	local rarity = SpinWheelConfig.hamsterRarity(prize.Reward, ctx)
	if rarity then
		table.insert(parts, rarity .. " hamster")
	end
	if #parts == 0 then
		return prize.Label
	end
	return (if prize.Id == "jackpot" then "JACKPOT: " else "") .. table.concat(parts, " + ")
end

return SpinWheelConfig
