--[[
	Placeholder hamster names per rarity. Replace/extend freely.
]]

local HamsterCatalog = {}

HamsterCatalog.Names = {
	Common = { "Biscuit", "Nibbles", "Peanut" },
	Uncommon = { "Clover", "Maple" },
	Rare = { "Blueberry", "Frostwhisker" },
	Epic = { "Amethyst", "Plumpaw" },
	Legendary = { "Sunnyfluff", "Goldenpaws" },
	Mythic = { "Cinderpuff", "Rubytail" },
	Divine = { "Halo" },
	Secret = { "Void Whisper" },
	Admin = { "The Overseer" },
}

function HamsterCatalog.pickName(rarityName: string, random: Random): string
	local names = HamsterCatalog.Names[rarityName]
	if not names or #names == 0 then
		return rarityName .. " Hamster"
	end
	return names[random:NextInteger(1, #names)]
end

return HamsterCatalog
