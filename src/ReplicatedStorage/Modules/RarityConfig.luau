--[[
	All 14 rarities. This is the single source of truth for colours, spawn weights, speed, value,
	announcements and visual effects. Nothing else hard-codes rarity values.

	Fx (read by the client FxController):
	  Light     { Color, Brightness, Range }
	  Outline   Color3 (Highlight outline around the hamster)
	  Particles { Kind, Colors = {Color3...}, Rate, Size, Speed, Lifetime }   Kind: sparkle|hearts|embers|snow|stars|runes|glitch|dust|rays|bubbles
	  Ring      Color3 pulsing ring on the road
	  Beam      { Color, Height } light pillar
	  Trail     Color3
	  Floaters  { Kind = orbs|stars|runes|squares, Count, Color }
	  Special   "Glitch" | "Rainbow" (animated colour shifts)
]]

local RarityConfig = {}

--[[
	ECONOMY FORMULA (one rule for every hamster, see docs/ECONOMY.md and tools/lune/economy_sim.luau):

	  Price   = rarity Price   * species ValueMult      (ValueMult spreads 1.00 .. 1.50 inside a rarity)
	  Income  = Price / rarity Payback                  (seconds a hamster needs to earn back its price)

	Each rarity is ~4.5x the price of the one below and earns ~3.3x more per second, so a rarer hamster
	always costs more AND earns more than any hamster of a lower rarity (the best of a rarity is still
	worth 1.5x less than the cheapest of the next). Rarer hamsters pay back more slowly, but they are
	much better per house slot - slots are limited, so progression naturally pushes towards rarer ones.
]]
RarityConfig.ValueSpread = 0.5 -- the last species of a rarity is worth 1 + ValueSpread times the first
RarityConfig.ExclusiveValue = 1.25 -- event / reward-only hamsters
RarityConfig.SellRatio = 0.5
RarityConfig.LuckCap = 15

local function c(hex: string): Color3
	return Color3.fromHex(hex)
end

local list = {
	{
		Id = "Basic", Name = "Basic", Color = c("C8BEAF"), Accent = c("8F8575"),
		Weight = 520, MinRebirth = 0, Speed = 9, Price = 100, Payback = 60, Announce = 0,
		Style = "Plain fur, simple and sweet",
		Difficulty = "Very easy",
		IndexReward = { Gems = 25 },
		Fx = {},
	},
	{
		Id = "Cute", Name = "Cute", Color = c("FF9FC8"), Accent = c("FF6FAE"),
		Weight = 250, MinRebirth = 0, Speed = 10.5, Price = 450, Payback = 80, Announce = 0,
		Style = "Soft pink hearts float up",
		Difficulty = "Easy",
		IndexReward = { Gems = 40 },
		Fx = {
			Particles = { Kind = "hearts", Colors = { c("FF9FC8"), c("FFD0E6") }, Rate = 2, Size = 0.9, Speed = 2.5, Lifetime = 1.6 },
		},
	},
	{
		Id = "Shiny", Name = "Shiny", Color = c("6FE3C1"), Accent = c("35C9A0"),
		Weight = 120, MinRebirth = 0, Speed = 12, Price = 2000, Payback = 110, Announce = 0,
		Style = "Sparkling mint glitter",
		Difficulty = "Easy",
		IndexReward = { Gems = 60 },
		Fx = {
			Light = { Color = c("6FE3C1"), Brightness = 0.6, Range = 9 },
			Particles = { Kind = "sparkle", Colors = { c("6FE3C1"), c("FFFFFF") }, Rate = 4, Size = 0.6, Speed = 2, Lifetime = 1.2 },
		},
	},
	{
		Id = "Rare", Name = "Rare", Color = c("5AA0FF"), Accent = c("2F78E8"),
		Weight = 60, MinRebirth = 0, Speed = 14, Price = 9000, Payback = 150, Announce = 0,
		Style = "Cool blue glow with a road ring",
		Difficulty = "Medium",
		IndexReward = { Gems = 90 },
		Fx = {
			Light = { Color = c("5AA0FF"), Brightness = 1, Range = 12 },
			Outline = c("5AA0FF"),
			Ring = c("5AA0FF"),
			Particles = { Kind = "sparkle", Colors = { c("5AA0FF"), c("BBD8FF") }, Rate = 5, Size = 0.6, Speed = 2, Lifetime = 1.2 },
		},
	},
	{
		Id = "Epic", Name = "Epic", Color = c("B070FF"), Accent = c("8A3DFF"),
		Weight = 24, MinRebirth = 0, Speed = 16.5, Price = 40000, Payback = 200, Announce = 1,
		Style = "Purple orbs swirl around",
		Difficulty = "Medium",
		IndexReward = { Gems = 140 },
		Fx = {
			Light = { Color = c("B070FF"), Brightness = 1.6, Range = 14 },
			Outline = c("B070FF"),
			Ring = c("B070FF"),
			Floaters = { Kind = "orbs", Count = 3, Color = c("D2A6FF") },
			Particles = { Kind = "sparkle", Colors = { c("B070FF"), c("E4CBFF") }, Rate = 6, Size = 0.7, Speed = 2.5, Lifetime = 1.3 },
		},
	},
	{
		Id = "Ultra", Name = "Ultra", Color = c("FF5FD2"), Accent = c("E0239F"),
		Weight = 10, MinRebirth = 0, Speed = 19, Price = 180000, Payback = 260, Announce = 1,
		Style = "Magenta neon with a streaking trail",
		Difficulty = "Hard",
		IndexReward = { Gems = 200 },
		Fx = {
			Light = { Color = c("FF5FD2"), Brightness = 2, Range = 16 },
			Outline = c("FF5FD2"),
			Ring = c("FF5FD2"),
			Trail = c("FF5FD2"),
			Particles = { Kind = "stars", Colors = { c("FF5FD2"), c("FFB0EC") }, Rate = 8, Size = 0.8, Speed = 3, Lifetime = 1.3 },
		},
	},
	{
		Id = "Legendary", Name = "Legendary", Color = c("FFC83D"), Accent = c("FF9F0A"),
		Weight = 4, MinRebirth = 0, Speed = 22, Price = 800000, Payback = 340, Announce = 2,
		Style = "Golden light pillar and coin sparkles",
		Difficulty = "Hard",
		IndexReward = { Gems = 300 },
		Fx = {
			Light = { Color = c("FFC83D"), Brightness = 2.6, Range = 20 },
			Outline = c("FFC83D"),
			Ring = c("FFC83D"),
			Beam = { Color = c("FFC83D"), Height = 40 },
			Trail = c("FFD866"),
			Particles = { Kind = "sparkle", Colors = { c("FFC83D"), c("FFF3B0") }, Rate = 12, Size = 0.9, Speed = 4, Lifetime = 1.4 },
		},
	},
	{
		Id = "Mythic", Name = "Mythic", Color = c("FF4B4B"), Accent = c("C41818"),
		Weight = 1.6, MinRebirth = 1, Speed = 26, Price = 3600000, Payback = 440, Announce = 2,
		Style = "Burning embers and a crimson beam",
		Difficulty = "Very hard",
		IndexReward = { Gems = 450 },
		Fx = {
			Light = { Color = c("FF4B4B"), Brightness = 3, Range = 22 },
			Outline = c("FF4B4B"),
			Ring = c("FF4B4B"),
			Beam = { Color = c("FF4B4B"), Height = 55 },
			Trail = c("FF7A3D"),
			Particles = { Kind = "embers", Colors = { c("FF4B4B"), c("FFB347") }, Rate = 16, Size = 1, Speed = 5, Lifetime = 1.4 },
		},
	},
	{
		Id = "Divine", Name = "Divine", Color = c("FFF4B8"), Accent = c("FFD866"),
		Weight = 0.6, MinRebirth = 3, Speed = 30, Price = 16000000, Payback = 560, Announce = 2,
		Style = "Holy rays, a halo ring and soft light",
		Difficulty = "Very hard",
		IndexReward = { Gems = 650 },
		Fx = {
			Light = { Color = c("FFF4B8"), Brightness = 3.4, Range = 24 },
			Outline = c("FFF4B8"),
			Ring = c("FFE9A0"),
			Beam = { Color = c("FFF4B8"), Height = 70 },
			Trail = c("FFF4B8"),
			Particles = { Kind = "rays", Colors = { c("FFF4B8"), c("FFFFFF") }, Rate = 14, Size = 1.1, Speed = 3, Lifetime = 1.8 },
			Floaters = { Kind = "orbs", Count = 4, Color = c("FFFFFF") },
		},
	},
	{
		Id = "Cosmic", Name = "Cosmic", Color = c("4A5CFF"), Accent = c("A0B0FF"),
		Weight = 0.25, MinRebirth = 5, Speed = 34, Price = 75000000, Payback = 700, Announce = 2,
		Style = "A tiny galaxy of stars follows it",
		Difficulty = "Extreme",
		IndexReward = { Gems = 900 },
		Fx = {
			Light = { Color = c("4A5CFF"), Brightness = 3.6, Range = 26 },
			Outline = c("A0B0FF"),
			Ring = c("4A5CFF"),
			Beam = { Color = c("6A7CFF"), Height = 80 },
			Trail = c("6A7CFF"),
			Particles = { Kind = "stars", Colors = { c("FFFFFF"), c("6A7CFF"), c("C58BFF") }, Rate = 22, Size = 0.9, Speed = 4, Lifetime = 2 },
			Floaters = { Kind = "stars", Count = 5, Color = c("FFFFFF") },
		},
	},
	{
		Id = "Celestial", Name = "Celestial", Color = c("9FFCFF"), Accent = c("FFFFFF"),
		Weight = 0.12, MinRebirth = 7, Speed = 38, Price = 340000000, Payback = 880, Announce = 2,
		Style = "Shimmering aurora ribbons",
		Difficulty = "Extreme",
		IndexReward = { Gems = 1200 },
		Fx = {
			Light = { Color = c("9FFCFF"), Brightness = 4, Range = 28 },
			Outline = c("FFFFFF"),
			Ring = c("9FFCFF"),
			Beam = { Color = c("9FFCFF"), Height = 90 },
			Trail = c("9FFCFF"),
			Particles = { Kind = "bubbles", Colors = { c("9FFCFF"), c("C9A8FF"), c("FFFFFF") }, Rate = 24, Size = 1.1, Speed = 4, Lifetime = 2 },
			Floaters = { Kind = "orbs", Count = 5, Color = c("C9A8FF") },
			Special = "Rainbow",
		},
	},
	{
		Id = "Secret", Name = "Secret", Color = c("2B0A4D"), Accent = c("B84DFF"),
		Weight = 0.05, MinRebirth = 9, Speed = 42, Price = 1500000000, Payback = 1100, Announce = 2,
		Style = "Black-purple with glitching shadows",
		Difficulty = "Insane",
		Hidden = true,
		IndexReward = { Gems = 1600 },
		Fx = {
			Light = { Color = c("B84DFF"), Brightness = 4.4, Range = 30 },
			Outline = c("B84DFF"),
			Ring = c("B84DFF"),
			Beam = { Color = c("B84DFF"), Height = 100 },
			Trail = c("7A22C7"),
			Particles = { Kind = "glitch", Colors = { c("B84DFF"), c("120022") }, Rate = 26, Size = 0.9, Speed = 5, Lifetime = 1.2 },
			Floaters = { Kind = "squares", Count = 6, Color = c("B84DFF") },
			Special = "Glitch",
		},
	},
	{
		Id = "Ancient", Name = "Ancient", Color = c("B8864B"), Accent = c("3DE0C0"),
		Weight = 0.02, MinRebirth = 12, Speed = 48, Price = 7000000000, Payback = 1400, Announce = 2,
		Style = "Glowing runes drift over bronze fur",
		Difficulty = "Insane",
		IndexReward = { Gems = 2200 },
		Fx = {
			Light = { Color = c("3DE0C0"), Brightness = 4.8, Range = 32 },
			Outline = c("3DE0C0"),
			Ring = c("3DE0C0"),
			Beam = { Color = c("3DE0C0"), Height = 110 },
			Trail = c("B8864B"),
			Particles = { Kind = "dust", Colors = { c("D9B26F"), c("3DE0C0") }, Rate = 22, Size = 0.9, Speed = 3, Lifetime = 2 },
			Floaters = { Kind = "runes", Count = 5, Color = c("3DE0C0") },
		},
	},
	{
		Id = "Unknown", Name = "???", Color = c("111111"), Accent = c("FF00E5"),
		Weight = 0.004, MinRebirth = 15, Speed = 56, Price = 35000000000, Payback = 1800, Announce = 2,
		Style = "Nobody knows what it is",
		Difficulty = "Impossible?",
		Hidden = true,
		IndexReward = { Gems = 5000 },
		Fx = {
			Light = { Color = c("FF00E5"), Brightness = 5.5, Range = 36 },
			Outline = c("FF00E5"),
			Ring = c("FF00E5"),
			Beam = { Color = c("FF00E5"), Height = 130 },
			Trail = c("FF00E5"),
			Particles = { Kind = "glitch", Colors = { c("FF00E5"), c("00FFFF"), c("FFFF00") }, Rate = 40, Size = 1.1, Speed = 6, Lifetime = 1 },
			Floaters = { Kind = "squares", Count = 8, Color = c("00FFFF") },
			Special = "Glitch",
		},
	},
}

RarityConfig.Order = {} :: { string }
RarityConfig.ById = {} :: { [string]: any }
RarityConfig.Ranks = {} :: { [string]: number }

for rank, definition in list do
	definition.Rank = rank
	table.insert(RarityConfig.Order, definition.Id)
	RarityConfig.ById[definition.Id] = definition
	RarityConfig.Ranks[definition.Id] = rank
end

RarityConfig.Count = #list

-- Base income per second of the cheapest species of each rarity (before player multipliers).
for _, definition in list do
	definition.Income = definition.Price / definition.Payback
end

function RarityConfig.get(id: string)
	return RarityConfig.ById[id]
end

function RarityConfig.rank(id: string): number
	return RarityConfig.Ranks[id] or 1
end

function RarityConfig.isUnlocked(id: string, rebirths: number): boolean
	local definition = RarityConfig.ById[id]
	return definition ~= nil and rebirths >= definition.MinRebirth
end

-- Spawn weights after rebirth gating and luck. Luck shifts probability towards rarer hamsters
-- but is capped, and the very rarest tiers only benefit from half of it.
function RarityConfig.adjustedWeights(rebirths: number, luck: number): { [string]: number }
	local effectiveLuck = math.clamp(luck, 1, RarityConfig.LuckCap)
	local weights = {}
	for _, id in RarityConfig.Order do
		local definition = RarityConfig.ById[id]
		if rebirths >= definition.MinRebirth and definition.Weight > 0 and not definition.NoSpawn then
			local factor = (definition.Rank - 1) / (RarityConfig.Count - 1)
			if definition.Rank >= 12 then
				factor *= 0.5
			end
			weights[id] = definition.Weight * (1 + (effectiveLuck - 1) * factor)
		end
	end
	return weights
end

-- Probability table (for the rarity board and for tests).
function RarityConfig.chances(rebirths: number, luck: number): { [string]: number }
	local weights = RarityConfig.adjustedWeights(rebirths, luck)
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local chances = {}
	for id, weight in weights do
		chances[id] = weight / total
	end
	return chances
end

return RarityConfig
