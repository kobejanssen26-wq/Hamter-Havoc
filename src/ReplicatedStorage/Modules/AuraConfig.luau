--[[
	AuraConfig: the glow / sparkle / ring ("aura") that hamsters get. Edit the numbers, press Play.

	How an aura is decided for a hamster:
	  1. the RARITY default below (ByRarity). Low rarities have none, the rarer, the more spectacular;
	  2. a hamster file can change it: in Content/Hamsters/<Name>.luau put inside Look = { ... }
	         Aura = false                                  no aura at all, whatever the rarity
	         Aura = { Style = "flame", Color = "FF8800", Rate = 6, Light = 1.2, Ring = "FFD866" }
	     every field is optional and overrides the rarity default (Ring = false removes the ring).

	Fields of an aura
	  Style    the particle kind: sparkle, stars, hearts, flame, embers, smoke, snow, bubbles, glitch (nil = no particles)
	  Color    "Rarity" (the colour of the rarity), "Accent", or a hex like "FFD866"
	  Rate     particles per second (capped by MaxRate)
	  Light    brightness of the soft glow around the hamster (0 = none; range follows Brightness)
	  Ring     a thin glowing ring on the ground under the hamster: a colour like Color, or nil/false for none

	Keeping it cheap (many hamsters can be on screen): one emitter + one light + one flat disc per hamster at most, the
	particle rate is capped, hamsters far away switch their particles off (AmbientController), previews and icons get no aura,
	and everything is a child of the hamster model, so it is removed with the model.
]]

local AuraConfig = {}

AuraConfig.Enabled = true -- false = no hamster has an aura (quick way to test performance)
AuraConfig.Intensity = 1 -- 0..1: multiplies particle rates and light brightness for every hamster
AuraConfig.MaxRate = 12 -- hard cap on particles per second for one hamster
AuraConfig.MaxLight = 2.5 -- hard cap on the glow brightness
AuraConfig.Styles = { sparkle = true, stars = true, hearts = true, flame = true, embers = true, smoke = true, snow = true, bubbles = true, glitch = true }

AuraConfig.ByRarity = {
	Rare = { Light = 0.5 }, -- a subtle glow
	Epic = { Light = 0.8, Style = "sparkle", Rate = 3, Color = "Rarity" },
	Ultra = { Light = 1.0, Style = "sparkle", Rate = 5, Color = "Rarity", Ring = "Accent" },
	Legendary = { Light = 1.3, Style = "stars", Rate = 6, Color = "Rarity", Ring = "Rarity" },
	Mythic = { Light = 1.5, Style = "flame", Rate = 6, Color = "Rarity", Ring = "Accent" },
	Divine = { Light = 1.7, Style = "stars", Rate = 7, Color = "FFE9A0", Ring = "FFD866" },
	Cosmic = { Light = 1.7, Style = "stars", Rate = 7, Color = "Rarity", Ring = "Accent" },
	Celestial = { Light = 1.8, Style = "snow", Rate = 7, Color = "FFFFFF", Ring = "Rarity" },
	Secret = { Light = 1.8, Style = "glitch", Rate = 8, Color = "Rarity", Ring = "Accent" },
	Ancient = { Light = 1.6, Style = "embers", Rate = 7, Color = "Rarity", Ring = "Accent" },
	Unknown = { Light = 1.6, Style = "smoke", Rate = 6, Color = "Rarity", Ring = "Accent" },
}

export type Resolved = { Style: string?, Color: Color3, Rate: number, Light: number, Ring: Color3? }

local function toColor(value: any, rarityColor: Color3, accent: Color3): Color3?
	if value == "Rarity" then
		return rarityColor
	elseif value == "Accent" then
		return accent
	elseif typeof(value) == "Color3" then
		return value
	elseif type(value) == "string" then
		local ok, color = pcall(Color3.fromHex, value)
		return if ok then color else nil
	end
	return nil
end

-- The aura of a species, fully validated and capped, or nil when it has none.
-- species: { Rarity = "Epic", Aura = nil | false | { ... } }; rarityColors: { Color, Accent } of its rarity.
function AuraConfig.resolve(species: any, rarityColor: Color3, accent: Color3): Resolved?
	if not AuraConfig.Enabled or AuraConfig.Intensity <= 0 or species.Aura == false then
		return nil
	end
	local merged: { [string]: any } = {}
	for key, value in AuraConfig.ByRarity[species.Rarity] or {} do
		merged[key] = value
	end
	if type(species.Aura) == "table" then
		for key, value in species.Aura do
			merged[key] = value
		end
	end
	if next(merged) == nil then
		return nil
	end
	local style = if type(merged.Style) == "string" and AuraConfig.Styles[merged.Style] then merged.Style else nil
	local rate = if style and type(merged.Rate) == "number" and merged.Rate == merged.Rate then math.clamp(merged.Rate, 0, AuraConfig.MaxRate) * AuraConfig.Intensity else 0
	local light = if type(merged.Light) == "number" and merged.Light == merged.Light then math.clamp(merged.Light, 0, AuraConfig.MaxLight) * AuraConfig.Intensity else 0
	local color = toColor(merged.Color, rarityColor, accent) or rarityColor
	local ring = if merged.Ring then toColor(merged.Ring, rarityColor, accent) else nil
	if rate <= 0 and light <= 0 and not ring then
		return nil
	end
	return { Style = if rate > 0 then style else nil, Color = color, Rate = rate, Light = light, Ring = ring }
end

-- Problems with an Aura value written in a hamster file (used by ContentValidator). Returns a message or nil.
function AuraConfig.problem(aura: any): string?
	if aura == nil or aura == false then
		return nil
	end
	if type(aura) ~= "table" then
		return "Look.Aura must be false or a table like { Style = \"flame\", Color = \"FF8800\", Rate = 6, Light = 1.2, Ring = \"FFD866\" }"
	end
	if aura.Style ~= nil and not AuraConfig.Styles[aura.Style] then
		return "Look.Aura.Style must be one of: sparkle, stars, hearts, flame, embers, smoke, snow, bubbles, glitch"
	end
	if aura.Rate ~= nil and (type(aura.Rate) ~= "number" or aura.Rate < 0 or aura.Rate > AuraConfig.MaxRate) then
		return "Look.Aura.Rate must be a number from 0 to " .. AuraConfig.MaxRate
	end
	if aura.Light ~= nil and (type(aura.Light) ~= "number" or aura.Light < 0 or aura.Light > AuraConfig.MaxLight) then
		return "Look.Aura.Light must be a number from 0 to " .. AuraConfig.MaxLight
	end
	for _, key in { "Color", "Ring" } do
		local value = aura[key]
		if value ~= nil and value ~= false and value ~= "Rarity" and value ~= "Accent" and not (type(value) == "string" and string.match(value, "^#?%x%x%x%x%x%x$")) then
			return string.format("Look.Aura.%s must be \"Rarity\", \"Accent\" or a hex colour like \"FFD866\"", key)
		end
	end
	return nil
end

return AuraConfig
