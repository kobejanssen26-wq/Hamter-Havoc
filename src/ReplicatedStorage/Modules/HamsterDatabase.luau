--[[
	Every collectable hamster. 160+ unique designs across 14 rarities.

	Entry keys (short on purpose, expanded by `expand` below):
	  n name | f fur | b belly | c2 pattern colour | ac accent colour
	  ears eyes mouth pat tail      -> variants from HamsterBuilder.Registry
	  acc = { accessory ids }       -> hats, gear, wings, tails, effects
	  fx = { {particleKind, hex} }  glow = { hex, brightness, range }
	  size  ec eyeColor  hc hatColor  ei earInner  pc pawColor  tc tailColor  tt tailTip  nb noBlush
	  x = true  -> exclusive reward (never spawns, only given by dailies / codes / quests)

	Value: every species has a ValueMult (1.0 for the first of its rarity, +0.07 per entry) so even
	hamsters of the same rarity differ in price and income.
]]

local RarityConfig = require(script.Parent.RarityConfig)

local HamsterDatabase = {}

local function hex(value: string?): Color3?
	if not value then
		return nil
	end
	return Color3.fromHex(value)
end

local raw: { [string]: { { [string]: any } } } = {}

---------------------------------------------------------------------------
raw.Basic = {
	{ n = "Brownie", f = "8B5A2B", b = "F0D3A6", ears = "round", eyes = "dot" },
	{ n = "Snowball", f = "FAF8F5", b = "FFFFFF", ears = "round", eyes = "big", ei = "FFD9E2" },
	{ n = "Pebbles", f = "9A9AA3", b = "D6D6DC", ears = "tiny", eyes = "dot", mouth = "flat" },
	{ n = "Tiny", f = "D8B48A", ears = "tiny", eyes = "big", mouth = "oh", size = 0.7 },
	{ n = "Sleepy", f = "F2E3C6", ears = "round", eyes = "sleepy", acc = { "nightcap" }, hc = "9EB4F0" },
	{ n = "Chubby", f = "E8A860", b = "FBE3BF", ears = "round", eyes = "happy", mouth = "open", size = 1.15 },
	{ n = "Baby", f = "F6E7CB", ears = "tiny", eyes = "big", acc = { "held_bottle" }, hc = "FF9CC0" },
	{ n = "Cookie", f = "C9A074", b = "F1DDB8", c2 = "5A3A22", pat = "spots", eyes = "dot", acc = { "held_cookie" } },
	{ n = "Bread", f = "E3B76B", b = "FBE8C0", ears = "tiny", eyes = "dot", acc = { "bread" } },
	{ n = "Cheese", f = "FFD65A", b = "FFF0B0", ears = "round", eyes = "happy", acc = { "cheese" } },
	{ n = "Peanut", f = "D9B88A", ears = "bear", eyes = "dot", mouth = "oh", acc = { "shell" }, hc = "C9A06A" },
	{ n = "Toast", f = "F0D9A8", b = "FFF6DC", ears = "bear", eyes = "dot", acc = { "held_cheese" } },
	{ n = "Pudding", f = "D9A55B", b = "FFF0C8", c2 = "5A3A22", pat = "blaze", ears = "fluffy", eyes = "big", acc = { "held_cupcake" } },
	{ n = "Nugget", f = "C8903E", c2 = "8A5A22", pat = "freckles", ears = "round", eyes = "happy", mouth = "open", acc = { "beanie" }, hc = "E4B04A" },
}

---------------------------------------------------------------------------
raw.Cute = {
	{ n = "Panda", f = "FFFFFF", b = "FFFFFF", c2 = "2A2630", pat = "panda", ears = "bear", ec = "2A2630", pc = "2A2630", eyes = "dot", acc = { "held_bamboo" } },
	{ n = "Bunny", f = "F6F1EE", b = "FFFFFF", ears = "bunny", eyes = "big", mouth = "cat", tail = "fluffy", acc = { "bow" }, hc = "FF8EB8" },
	{ n = "Strawberry", f = "FFB6C1", b = "FFE3E8", c2 = "E0607A", pat = "freckles", eyes = "sparkle", acc = { "strawberry" }, ec = "FF7AA2" },
	{ n = "Honey", f = "F2B84B", b = "FFE7A8", c2 = "6B4423", pat = "stripes", eyes = "happy", acc = { "bee", "wings_bee" } },
	{ n = "Flower", f = "F7C6DA", b = "FFE9F1", ears = "round", eyes = "happy", mouth = "open", acc = { "flowers" } },
	{ n = "Cloud", f = "F2F6FF", b = "FFFFFF", ears = "tiny", eyes = "sleepy", mouth = "flat", tail = "fluffy", acc = { "cloud" } },
	{ n = "Marshmallow", f = "FFF1F6", b = "FFFFFF", ears = "round", eyes = "big", mouth = "oh", size = 1.1, acc = { "beanie" }, hc = "FFC2D9" },
	{ n = "Milk", f = "FDF6EC", b = "FFFFFF", c2 = "3A3A3A", pat = "spots", ears = "floppy", eyes = "dot", acc = { "held_bottle" }, hc = "9CD0FF" },
	{ n = "Chocolate", f = "5A3A28", b = "8A6040", ears = "round", eyes = "heart", mouth = "tongue", acc = { "bowtie" }, hc = "FFB0C8" },
	{ n = "Caramel", f = "D9A066", b = "F6D9AE", ears = "fluffy", eyes = "big", acc = { "scarf" }, hc = "B5651D" },
	{ n = "Kitty", f = "E9C9A0", b = "FFF1DC", c2 = "B5895A", pat = "tiger", ears = "cat", eyes = "cat", mouth = "cat", tail = "long", acc = { "bellcollar" }, hc = "6FB6FF" },
	{ n = "Teddy", f = "B98058", b = "E8C9A6", ears = "bear", eyes = "dot", acc = { "bowtie", "held_balloon" }, hc = "FF5E7E" },
	{ n = "Peach", f = "FFC9A8", b = "FFE8D6", c2 = "F08C7A", pat = "freckles", ears = "fluffy", eyes = "sparkle", acc = { "leaf" }, ec = "FF8F6A" },
	{ n = "Mochi", f = "FFFFFF", b = "FFE6EE", ears = "none", eyes = "happy", size = 1.2, acc = { "sprout" } },
	{ n = "Calendar Cutie", f = "FFD1E8", b = "FFF2F8", ears = "bunny", eyes = "heart", mouth = "open", acc = { "tiara", "held_balloon" }, fx = { { "hearts", "FF8EC0" } }, x = true },
}

---------------------------------------------------------------------------
raw.Shiny = {
	{ n = "Crystal", f = "C8F4FF", b = "FFFFFF", ears = "bear", eyes = "crystal", acc = { "crystal_crown", "orbit_shards" }, ac = "7FDBFF", fx = { { "sparkle", "BFEFFF" } } },
	{ n = "Neon", f = "1A1A2E", b = "2C2C4A", c2 = "00FFC8", ac = "00FFC8", pat = "stripes", ears = "round", eyes = "glow", ec = "00FFC8", acc = { "visor" }, glow = { "00FFC8", 1.2, 10 } },
	{ n = "Rainbow", f = "FFFFFF", b = "FFF7FF", ears = "fluffy", eyes = "sparkle", acc = { "propeller", "orbit_ring" }, ac = "FF9AD8", hc = "6FA8FF", fx = { { "sparkle", "FFB0E8" } } },
	{ n = "Gem", f = "FF8AD8", b = "FFD0F0", ears = "round", eyes = "sparkle", acc = { "top_gem", "pendant" }, ac = "FF4FC0", ec = "FF5FD0", fx = { { "sparkle", "FF9FE0" } } },
	{ n = "Star", f = "FFE98A", b = "FFF8D0", ears = "tiny", eyes = "star", mouth = "open", acc = { "star_crown", "orbit_stars" }, fx = { { "stars", "FFE066" } } },
	{ n = "Bubble", f = "BFEFFF", b = "F0FBFF", ears = "tiny", eyes = "big", acc = { "astro" }, fx = { { "bubbles", "D0F4FF" } } },
	{ n = "Electric", f = "FFE14A", b = "FFF6B0", ears = "cat", eyes = "happy", mouth = "open", tail = "none", acc = { "tail_lightning", "goggles" }, glow = { "FFE14A", 1, 9 }, fx = { { "sparkle", "FFF08A" } } },
	{ n = "Golden", f = "F5C842", b = "FFE79A", ears = "round", eyes = "sparkle", acc = { "crown", "medal" }, ec = "FFB300", glow = { "FFD54A", 1, 9 } },
	{ n = "Silver", f = "D8DCE6", b = "F4F6FA", ears = "bear", eyes = "dot", acc = { "tophat", "monocle" }, hc = "6A6E80" },
	{ n = "Diamond", f = "F0FBFF", b = "FFFFFF", ears = "fluffy", eyes = "crystal", acc = { "tiara", "orbit_shards" }, ac = "9FE8FF", fx = { { "sparkle", "FFFFFF" } } },
	{ n = "Glitter", f = "FFB6F2", b = "FFE4FA", ears = "round", eyes = "sparkle", mouth = "tongue", acc = { "bow", "held_wand" }, hc = "B06BFF", fx = { { "sparkle", "FFD0F8" } } },
	{ n = "Prism", f = "FFFFFF", b = "F4F0FF", ears = "tiny", eyes = "glow", ec = "FF8EE6", acc = { "visor", "orbit_ring" }, ac = "7FD6FF", fx = { { "sparkle", "C8B0FF" } } },
	{ n = "Opal", f = "E4F1F0", b = "FFFFFF", c2 = "BCE6FF", pat = "spots", ears = "round", eyes = "sparkle", mouth = "cat", acc = { "moon_circlet" }, ac = "BCE6FF" },
	{ n = "Disco", f = "D9B3FF", b = "F1E4FF", ears = "big", eyes = "happy", mouth = "grin", acc = { "sunglasses", "headphones", "ground_glow" }, ac = "FF6FD8", fx = { { "sparkle", "FFFFFF" } } },
}

---------------------------------------------------------------------------
raw.Rare = {
	{ n = "Ninja", f = "33333D", b = "55556A", ears = "round", eyes = "angry", mouth = "flat", acc = { "ninja_band", "held_sword" }, hc = "E04040" },
	{ n = "Pirate", f = "B07B4A", b = "E6C8A0", ears = "round", eyes = "dot", mouth = "grin", acc = { "pirate", "eyepatch", "held_sword" } },
	{ n = "Cowboy", f = "C98F57", b = "EBD0A8", ears = "floppy", eyes = "happy", mouth = "tongue", acc = { "cowboy", "bandana" }, hc = "E85A4F" },
	{ n = "Chef", f = "F7E7CE", ears = "bear", eyes = "happy", mouth = "open", acc = { "chef", "apron" } },
	{ n = "Detective", f = "A9886A", b = "DCC7A8", ears = "round", eyes = "dot", mouth = "flat", acc = { "detective", "monocle", "tie" }, hc = "7A4A2A" },
	{ n = "Apprentice", f = "C9B8FF", b = "EEE8FF", ears = "elf", eyes = "big", acc = { "wizard", "held_book" }, hc = "7A5BE0" },
	{ n = "Cadet", f = "B7BCC9", b = "E6E8EE", ears = "tiny", eyes = "dot", acc = { "knight", "held_shield" } },
	{ n = "Scientist", f = "F2F2F2", b = "FFFFFF", ears = "round", eyes = "sparkle", acc = { "goggles", "apron", "held_orb" }, ac = "7DFFB0" },
	{ n = "Explorer", f = "D2A66A", b = "F0D9B0", ears = "big", eyes = "happy", acc = { "sunhat", "backpack" }, hc = "58A0FF" },
	{ n = "Painter", f = "F6D6A8", b = "FFF0D8", c2 = "FF6B8B", pat = "freckles", ears = "round", eyes = "wink", acc = { "beret", "held_brush" } },
	{ n = "Musician", f = "9AD0FF", b = "D6ECFF", ears = "fluffy", eyes = "happy", mouth = "open", acc = { "headphones", "bowtie" }, hc = "FF6B9A" },
	{ n = "Gardener", f = "B8E0A0", b = "E6F6D8", ears = "floppy", eyes = "dot", acc = { "sunhat", "held_flower" }, hc = "FF8EB8" },
	{ n = "Sailor", f = "E8E8F0", b = "FFFFFF", ears = "round", eyes = "big", acc = { "sailor", "scarf" }, hc = "3A5AA8" },
}

---------------------------------------------------------------------------
raw.Epic = {
	{ n = "Samurai", f = "7B5B4A", b = "BFA08A", ears = "round", eyes = "angry", mouth = "flat", acc = { "samurai", "held_sword", "pauldrons" } },
	{ n = "Viking", f = "C99A63", b = "EBCFA6", ears = "bear", eyes = "angry", mouth = "grin", acc = { "viking", "held_hammer", "cape" }, hc = "9A3A2A" },
	{ n = "Vampire", f = "E6DAD5", b = "FFFFFF", ears = "cat", eyes = "glow", ec = "FF3355", mouth = "fang", acc = { "cape_royal" }, hc = "6A1030" },
	{ n = "Mummy", f = "E9DDBF", b = "F7F0DA", c2 = "D8C79B", pat = "stripes", ears = "tiny", eyes = "glow", ec = "FFE066", mouth = "flat", acc = { "bandana" }, hc = "E9DDBF" },
	{ n = "Witch", f = "7DA86B", b = "BEDDAE", ears = "cat", eyes = "cat", mouth = "grin", acc = { "witch", "held_staff", "bellcollar" }, hc = "B070FF" },
	{ n = "Pharaoh", f = "E0B84A", b = "F7E2A6", ears = "round", eyes = "dot", acc = { "pharaoh", "pendant" } },
	{ n = "Robot", f = "B9C2D0", b = "E1E6EE", ears = "none", eyes = "crystal", mouth = "none", acc = { "visor", "jetpack" }, ac = "5AD1FF" },
	{ n = "Alien", f = "8BE08B", b = "C8F5C8", ears = "elf", eyes = "void", mouth = "oh", acc = { "alien" }, nb = true },
	{ n = "Yeti", f = "E8F4FF", b = "FFFFFF", ears = "tiny", eyes = "angry", mouth = "fang", size = 1.3, acc = { "hood" }, hc = "BFE3FF" },
	{ n = "Mermaid", f = "7FE0D8", b = "C9F5F1", ears = "fluffy", eyes = "sparkle", tail = "none", acc = { "tail_fish", "lei" }, ec = "FF8EC0" },
	{ n = "Pumpkin", f = "FF9A3C", b = "FFD4A0", ears = "tiny", eyes = "angry", mouth = "grin", acc = { "sprout", "held_lantern" } },
	{ n = "Ghost", f = "F4F4FF", b = "FFFFFF", ears = "none", eyes = "dot", mouth = "oh", size = 0.95, acc = { "ghost_sheet" } },
	{ n = "Jester", f = "F59AC4", b = "FFD6E8", ears = "round", eyes = "happy", mouth = "tongue", acc = { "jester", "bellcollar" } },
	{ n = "Founder Fuzz", f = "FFE0A0", b = "FFF4D8", ears = "fluffy", eyes = "sparkle", acc = { "party", "medal", "bowtie" }, hc = "FF7A59", fx = { { "sparkle", "FFE066" } }, x = true },
}

---------------------------------------------------------------------------
raw.Ultra = {
	{ n = "Inferno", f = "FF6A2A", b = "FFC08A", ears = "cat", eyes = "angry", mouth = "grin", acc = { "flame_crown", "wings_flame", "tail_flame" }, tail = "none", fx = { { "flame", "FF8A3A" } }, glow = { "FF7A3A", 1.6, 12 } },
	{ n = "Frostbite", f = "9DE0FF", b = "E4F7FF", ears = "round", eyes = "glow", ec = "FFFFFF", acc = { "ice_crown", "wings_ice", "scarf" }, hc = "6FB6FF", fx = { { "snow", "FFFFFF" } } },
	{ n = "Thunderbolt", f = "FFE93D", b = "FFF7A8", ears = "big", eyes = "angry", mouth = "open", tail = "none", acc = { "tail_lightning", "visor", "cape" }, hc = "6A5ACD", glow = { "FFE93D", 1.8, 12 }, fx = { { "sparkle", "FFF6A0" } } },
	{ n = "Magma", f = "5A2A24", b = "8A4A3A", c2 = "FF5A1E", pat = "tiger", ears = "round", eyes = "glow", ec = "FF7A2E", mouth = "fang", acc = { "horns", "pauldrons" }, glow = { "FF5A1E", 1.5, 11 }, fx = { { "embers", "FF7A2E" } } },
	{ n = "Tsunami", f = "4BA3E8", b = "B8DEFA", ears = "fluffy", eyes = "sparkle", tail = "none", acc = { "held_trident", "tail_fish" }, fx = { { "bubbles", "BFE8FF" } } },
	{ n = "Blossom", f = "FFB7D5", b = "FFE3EE", ears = "round", eyes = "heart", acc = { "flowers", "wings_butterfly" }, hc = "FF7FB5", fx = { { "hearts", "FF9FC8" } } },
	{ n = "Shadow", f = "2B2B38", b = "4A4A60", c2 = "5B5B78", pat = "saddle", ears = "cat", eyes = "glow", ec = "FFFFFF", mouth = "flat", acc = { "hood", "cape", "held_sword" }, hc = "2B2B38" },
	{ n = "Cyberpunk", f = "2A2A55", b = "46468A", c2 = "FF4DD2", pat = "stripes", ears = "big", eyes = "glow", ec = "FF4DD2", acc = { "visor", "headphones", "jetpack" }, ac = "FF4DD2", glow = { "FF4DD2", 1.4, 11 } },
	{ n = "Steampunk", f = "B07A4A", b = "E0B88A", ears = "round", eyes = "dot", acc = { "tophat", "goggles", "wings_mecha" }, hc = "6A4A30" },
	{ n = "Candyland", f = "FFC4E1", b = "FFFFFF", c2 = "FF6FAE", pat = "stripes", ears = "fluffy", eyes = "sparkle", mouth = "tongue", acc = { "held_lollipop", "tutu", "bow" }, hc = "7FD6FF" },
	{ n = "Aurora", f = "7DFFC8", b = "D6FFF0", ears = "tiny", eyes = "sparkle", ec = "C58BFF", acc = { "wings_aurora", "moon_circlet", "ground_glow" }, ac = "7DFFC8", fx = { { "sparkle", "B8FFE6" } } },
	{ n = "Neon Samurai", f = "18182E", b = "2C2C4A", ears = "round", eyes = "glow", ec = "00E5FF", mouth = "flat", acc = { "samurai", "held_sword", "visor" }, ac = "00E5FF", glow = { "00E5FF", 1.3, 10 } },
}

---------------------------------------------------------------------------
raw.Legendary = {
	{ n = "Golden King", f = "F7C93E", b = "FFE9A0", ears = "round", eyes = "sparkle", mouth = "grin", acc = { "royal", "cape_royal", "held_staff", "medal" }, ac = "FFD54A", glow = { "FFD54A", 2, 14 }, fx = { { "sparkle", "FFE066" } } },
	{ n = "Dragon Hamster", f = "6FBF6F", b = "D6F0C0", ears = "cat", eyes = "cat", mouth = "fang", tail = "none", acc = { "horns", "wings_dragon", "tail_dragon", "dino_spikes" }, hc = "D84A3A", fx = { { "flame", "FF8A3A" } } },
	{ n = "Phoenix", f = "FF7A3C", b = "FFD08A", ears = "tiny", eyes = "glow", ec = "FFE066", tail = "none", acc = { "sun_crown", "wings_flame", "tail_peacock" }, glow = { "FF8A3A", 2, 14 }, fx = { { "flame", "FFB347" } } },
	{ n = "Unicorn", f = "FFF3FA", b = "FFFFFF", ears = "elf", eyes = "sparkle", ec = "C58BFF", mouth = "cat", tail = "none", acc = { "unicorn_horn", "tail_fluffy", "ground_glow" }, tc = "FFB0E8", tt = "AEE1FF", ac = "FFB0E8", fx = { { "sparkle", "FFE0F8" } } },
	{ n = "Griffin", f = "D9A25F", b = "F6DDB0", ears = "cat", eyes = "cat", mouth = "flat", tail = "none", acc = { "wings_golden", "tail_squirrel", "laurel" }, tc = "B87A3A" },
	{ n = "Angel Guardian", f = "FFFFFF", b = "FFFFFF", ears = "round", eyes = "happy", acc = { "halo", "wings_angel", "held_sword", "armor" }, hc = "F4F8FF", glow = { "FFFFFF", 2, 14 } },
	{ n = "Archmage", f = "7A5CE0", b = "C8B8FF", ears = "elf", eyes = "glow", ec = "FFE066", mouth = "grin", acc = { "wizard", "held_staff", "cape", "orbit_orbs" }, ac = "FFD54A", hc = "4A2A9A", glow = { "A58BFF", 1.8, 13 } },
	{ n = "Pirate Captain", f = "8C4E30", b = "D9A883", ears = "bear", eyes = "angry", mouth = "grin", acc = { "pirate", "cape_royal", "held_sword", "eyepatch" }, hc = "2A5AA8" },
	{ n = "Lion Heart", f = "E8A94B", b = "FFE0A0", ears = "tiny", eyes = "cat", mouth = "fang", acc = { "ruff", "crown", "held_shield" }, size = 1.15 },
	{ n = "Dark Knight", f = "3A3A48", b = "6A6A80", ears = "tiny", eyes = "glow", ec = "FF3355", mouth = "none", acc = { "knight", "armor", "cape", "held_sword" }, hc = "6A1030" },
	{ n = "Storm Lord", f = "7FB5FF", b = "D0E6FF", ears = "big", eyes = "glow", ec = "FFF176", mouth = "open", acc = { "viking", "held_hammer", "orbit_ring" }, ac = "FFF176", glow = { "9FC8FF", 1.8, 13 }, fx = { { "sparkle", "FFF176" } } },
	{ n = "Ruby Queen", f = "E0446A", b = "FF9DB5", ears = "fluffy", eyes = "sparkle", ec = "FF2255", acc = { "crown", "cape_royal", "pendant" }, hc = "B01040", glow = { "FF4D7A", 1.6, 12 } },
	{ n = "Sunday Sunbeam", f = "FFE08A", b = "FFF5CC", ears = "round", eyes = "happy", mouth = "open", acc = { "sun_crown", "wings_angel", "ground_glow" }, ac = "FFD54A", glow = { "FFE08A", 2, 14 }, fx = { { "sparkle", "FFF0A8" } }, x = true },
}

---------------------------------------------------------------------------
raw.Mythic = {
	{ n = "Hellfire Lord", f = "8E1F1F", b = "C45A4A", ears = "cat", eyes = "glow", ec = "FFB347", mouth = "fang", tail = "none", acc = { "horns", "wings_bat", "tail_dragon", "pauldrons", "held_torch" }, hc = "2A0A0A", glow = { "FF3B1F", 2.4, 15 }, fx = { { "flame", "FF5A2E" } } },
	{ n = "Kraken Pup", f = "6A4FB0", b = "B9A6E8", ears = "tiny", eyes = "glow", ec = "7DF9FF", mouth = "oh", tail = "none", acc = { "hood", "held_trident", "tail_fish", "fish_scales" }, hc = "4A2F90", fx = { { "bubbles", "CFC0FF" } } },
	{ n = "Leviathan", f = "2E7FA8", b = "8EC9E0", ears = "fluffy", eyes = "cat", ec = "FFE066", mouth = "fang", tail = "none", acc = { "crystal_crown", "tail_dragon", "fish_scales", "wings_ice" }, ac = "7FF0FF", fx = { { "bubbles", "BFF4FF" } } },
	{ n = "Behemoth", f = "7A6A58", b = "B8A890", ears = "tiny", eyes = "angry", mouth = "grin", size = 1.4, acc = { "stone_crown", "armor", "pauldrons" } },
	{ n = "Chimera", f = "C98F4E", b = "F0D4A6", ears = "big", eyes = "cat", mouth = "fang", tail = "none", acc = { "antlers", "wings_dragon", "tail_peacock", "ruff" }, hc = "9A5A2A" },
	{ n = "Minotaur", f = "7A4A2E", b = "B88A66", ears = "floppy", eyes = "angry", mouth = "grin", size = 1.25, acc = { "horns", "spiked_collar", "held_hammer", "armor" }, hc = "EDE2C8" },
	{ n = "Nine-Tails", f = "FF9D4D", b = "FFE0B8", ears = "cat", eyes = "cat", ec = "FF4D4D", mouth = "cat", tail = "none", acc = { "tail_nine", "cat_hood", "orbit_orbs" }, hc = "FFFFFF", ac = "6FD6FF", tt = "6FD6FF", fx = { { "flame", "6FD6FF" } } },
	{ n = "Demon Lord", f = "3B0F4A", b = "7A3A8A", ears = "elf", eyes = "glow", ec = "FF3355", mouth = "fang", acc = { "crown_of_thorns", "cape_royal", "held_scythe" }, hc = "3A0A20", glow = { "A020F0", 2, 14 } },
	{ n = "Titan", f = "B0B8C8", b = "E0E4EE", ears = "tiny", eyes = "glow", ec = "7DF9FF", mouth = "flat", size = 1.45, acc = { "golden_helm", "armor", "held_hammer" } },
	{ n = "Valkyrie", f = "F4E7C8", b = "FFFFFF", ears = "fluffy", eyes = "sparkle", ec = "7DB6FF", acc = { "golden_helm", "wings_angel", "held_shield", "cape" }, hc = "3A6AD8", glow = { "FFF1B8", 1.6, 13 } },
	{ n = "Reaper", f = "2F2640", b = "5A4A78", ears = "none", eyes = "void", mouth = "none", acc = { "hood", "held_scythe" }, hc = "1A1226", fx = { { "smoke", "6A5A8A" } }, nb = true },
	{ n = "Lich King", f = "5D7A8C", b = "A8C4D4", ears = "tiny", eyes = "glow", ec = "7DF9FF", mouth = "flat", acc = { "ice_crown", "cape_royal", "held_staff" }, hc = "2A3A5A", glow = { "7DF9FF", 1.8, 13 }, fx = { { "snow", "BFF4FF" } } },
}

---------------------------------------------------------------------------
raw.Divine = {
	{ n = "Skyfather", f = "F3F3FF", b = "FFFFFF", ears = "round", eyes = "glow", ec = "FFF176", mouth = "grin", acc = { "laurel", "cape", "held_orb", "orbit_ring" }, hc = "6FB6FF", ac = "FFF176", glow = { "FFF9C4", 2.2, 15 }, fx = { { "sparkle", "FFF9C4" } } },
	{ n = "Tidal King", f = "7FD6F0", b = "D6F6FF", ears = "fluffy", eyes = "sparkle", tail = "none", acc = { "crown", "held_trident", "fish_scales", "tail_fish" }, ac = "7FF0FF", fx = { { "bubbles", "D6F6FF" } } },
	{ n = "Athena", f = "F0E6D2", b = "FFFFFF", ears = "tiny", eyes = "glow", ec = "7DB6FF", mouth = "flat", acc = { "golden_helm", "held_shield", "held_book" }, glow = { "FFF1B8", 2, 14 } },
	{ n = "Sun Priest", f = "FFD98A", b = "FFF3CC", ears = "round", eyes = "happy", acc = { "sun_crown", "wings_golden" }, glow = { "FFD54A", 2.2, 15 }, fx = { { "sparkle", "FFF0A8" } } },
	{ n = "Moon Priestess", f = "DCE4FF", b = "FFFFFF", ears = "elf", eyes = "sleepy", acc = { "moon_circlet", "wings_fairy", "held_wand" }, ac = "C8D4FF", glow = { "C8D4FF", 1.8, 14 } },
	{ n = "Divine Empress", f = "FFE9F4", b = "FFFFFF", ears = "fluffy", eyes = "sparkle", ec = "FF9EC8", acc = { "tiara", "cape_royal", "held_flower" }, hc = "FF7FB5", glow = { "FFD0EA", 1.8, 14 } },
	{ n = "Ra", f = "FFC94A", b = "FFE9A0", ears = "round", eyes = "glow", ec = "FF7A1E", acc = { "pharaoh", "wings_golden", "held_orb" }, ac = "FFB300", glow = { "FFB300", 2.4, 16 }, fx = { { "flame", "FFC94A" } } },
	{ n = "Anubis", f = "3A3440", b = "6A6278", ears = "cat", eyes = "glow", ec = "FFD54A", mouth = "flat", acc = { "pharaoh", "medal", "held_staff" }, glow = { "FFD54A", 1.6, 13 } },
	{ n = "Odin", f = "A8B4C8", b = "DDE4F0", ears = "tiny", eyes = "glow", ec = "7DB6FF", mouth = "flat", acc = { "eyepatch", "viking", "cape", "orbit_orbs" }, hc = "3A4A78", ac = "7DB6FF" },
	{ n = "Seraph", f = "FFFFFF", b = "FFFFFF", ears = "none", eyes = "happy", acc = { "halo", "wings_seraph", "armor" }, glow = { "FFFFFF", 2.6, 16 }, fx = { { "sparkle", "FFFFFF" } } },
	{ n = "Gaia", f = "9ED88A", b = "E0F5D0", ears = "floppy", eyes = "sparkle", ec = "58C86A", acc = { "laurel", "wings_leaf", "lei" }, fx = { { "sparkle", "C8F5B0" } }, glow = { "9ED88A", 1.6, 13 } },
}

---------------------------------------------------------------------------
raw.Cosmic = {
	{ n = "Nebula", f = "5B3FA8", b = "A88AE8", ears = "round", eyes = "sparkle", ec = "FF8AE0", acc = { "galaxy_crown", "wings_cosmic", "orbit_stars" }, ac = "C58BFF", fx = { { "stars", "E0C8FF" } }, glow = { "A070FF", 2, 14 } },
	{ n = "Galaxy", f = "2A2B7A", b = "5A5CBA", c2 = "FFFFFF", pat = "spots", ears = "fluffy", eyes = "glow", ec = "9FB4FF", acc = { "orbit_ring", "wings_cosmic", "held_orb" }, ac = "6A7CFF", fx = { { "stars", "FFFFFF" } } },
	{ n = "Supernova", f = "FFB347", b = "FFE0A8", ears = "tiny", eyes = "glow", ec = "FFFFFF", tail = "none", acc = { "sun_crown", "orbit_shards", "tail_flame" }, ac = "FF8A3A", glow = { "FFB347", 2.6, 16 }, fx = { { "flame", "FFD08A" } } },
	{ n = "Comet", f = "9FD8FF", b = "E0F4FF", ears = "cat", eyes = "happy", tail = "none", acc = { "tail_star", "goggles", "orbit_stars" }, fx = { { "sparkle", "E0F4FF" } } },
	{ n = "Black Hole", f = "0E0B1A", b = "2A2244", ears = "none", eyes = "void", mouth = "none", acc = { "orbit_ring", "hood", "orbit_shards" }, hc = "0E0B1A", ac = "A070FF", glow = { "7A3AD8", 2.2, 15 }, fx = { { "glitch", "A070FF" } }, nb = true },
	{ n = "Quasar", f = "7DF9FF", b = "D6FFFF", ears = "big", eyes = "glow", ec = "FFFFFF", acc = { "visor", "jetpack", "orbit_ring" }, ac = "7DF9FF", glow = { "7DF9FF", 2, 14 } },
	{ n = "Pulsar", f = "D77DFF", b = "F0CCFF", ears = "round", eyes = "star", mouth = "open", tail = "none", acc = { "alien", "orbit_orbs", "tail_lightning" }, ac = "FF9AF0", fx = { { "sparkle", "FFB0FF" } } },
	{ n = "Meteor", f = "8A5A3C", b = "C49A78", ears = "tiny", eyes = "angry", tail = "none", acc = { "stone_crown", "tail_flame", "orbit_shards" }, ac = "FF8A3A", fx = { { "embers", "FF8A3A" } } },
	{ n = "Moonwalker", f = "E8E8F0", b = "FFFFFF", ears = "none", eyes = "dot", acc = { "astro", "backpack", "orbit_orbs" }, ac = "9FB4FF", hc = "FF7A59" },
	{ n = "Solar Flare", f = "FFCF3F", b = "FFF0A8", ears = "fluffy", eyes = "glow", ec = "FF7A1E", acc = { "sun_crown", "wings_flame", "ground_glow" }, ac = "FF9A1E", glow = { "FFCF3F", 2.6, 16 }, fx = { { "flame", "FFB347" } } },
	{ n = "Astro Prime", f = "5AA0FF", b = "BCD8FF", ears = "tiny", eyes = "sparkle", ec = "FFFFFF", acc = { "astro", "armor", "held_wand" }, ac = "7DF9FF", glow = { "7DB6FF", 1.8, 13 } },
}

---------------------------------------------------------------------------
raw.Celestial = {
	{ n = "Dawn Bringer", f = "FFD9A8", b = "FFF0DC", ears = "round", eyes = "happy", acc = { "sun_crown", "wings_aurora", "cape" }, hc = "FF9A6A", ac = "FFB07A", glow = { "FFD9A8", 2.4, 16 }, fx = { { "sparkle", "FFE9C8" } } },
	{ n = "Twilight Sage", f = "B79CFF", b = "E6DAFF", ears = "elf", eyes = "sleepy", acc = { "moon_circlet", "wings_fairy", "held_staff" }, ac = "D8C8FF", glow = { "B79CFF", 2, 15 }, fx = { { "sparkle", "E6DAFF" } } },
	{ n = "Starweaver", f = "3E4DBA", b = "8C9AF0", ears = "fluffy", eyes = "star", acc = { "star_crown", "orbit_stars", "cape_royal" }, hc = "1E2A7A", glow = { "8C9AF0", 2, 15 }, fx = { { "stars", "FFF6B0" } } },
	{ n = "Moonlight Oracle", f = "DDE6FF", b = "FFFFFF", ears = "tiny", eyes = "glow", ec = "B8C8FF", mouth = "flat", acc = { "moon_circlet", "held_orb", "orbit_ring" }, ac = "B8C8FF", glow = { "DDE6FF", 2, 15 } },
	{ n = "Sun Empress", f = "FFE08A", b = "FFF8D6", ears = "round", eyes = "sparkle", ec = "FF9A1E", acc = { "sun_crown", "cape_royal", "wings_golden", "held_staff" }, hc = "D86A1A", glow = { "FFE08A", 2.8, 17 } },
	{ n = "Aether", f = "BFF3FF", b = "FFFFFF", ears = "none", eyes = "happy", acc = { "halo", "wings_aurora", "orbit_orbs" }, ac = "9FFCFF", glow = { "BFF3FF", 2.4, 16 }, fx = { { "bubbles", "E8FCFF" } } },
	{ n = "Constellation", f = "1D2260", b = "4A52B0", ears = "tiny", eyes = "star", acc = { "star_crown", "orbit_stars", "wings_cosmic", "ground_glow" }, ac = "FFF6B0", fx = { { "stars", "FFFFFF" } }, glow = { "6A7CFF", 2, 15 } },
	{ n = "Zodiac", f = "F3D7FF", b = "FFFFFF", ears = "fluffy", eyes = "crystal", ec = "C58BFF", acc = { "galaxy_crown", "held_gem", "orbit_ring" }, ac = "C58BFF", glow = { "E0B8FF", 2, 15 } },
	{ n = "Eclipse", f = "1B1B28", b = "3A3A52", ears = "round", eyes = "glow", ec = "FFB347", mouth = "flat", acc = { "sun_crown", "cape", "ground_glow" }, hc = "1B1B28", ac = "FF9A1E", glow = { "FF9A1E", 2.4, 16 } },
	{ n = "Harmonic", f = "FFC3F7", b = "FFE8FB", ears = "big", eyes = "happy", mouth = "open", acc = { "headphones", "wings_seraph", "orbit_stars" }, hc = "9A6BFF", ac = "FF9AF0", fx = { { "hearts", "FFB0F4" } }, glow = { "FFC3F7", 2, 15 } },
}

---------------------------------------------------------------------------
raw.Secret = {
	{ n = "Glitch", f = "1A0F2E", b = "3A2A5A", ears = "round", eyes = "glow", ec = "B84DFF", acc = { "visor", "wings_void", "orbit_shards" }, ac = "B84DFF", fx = { { "glitch", "B84DFF" } }, glow = { "B84DFF", 2.6, 16 } },
	{ n = "Void Walker", f = "120A24", b = "2E1E4A", ears = "none", eyes = "void", mouth = "none", acc = { "void_crown", "cape_royal", "orbit_ring" }, hc = "1A0F2E", ac = "9A3DFF", glow = { "7A22C7", 2.6, 16 }, nb = true },
	{ n = "Shadow Monarch", f = "1E1530", b = "3E2E60", ears = "elf", eyes = "glow", ec = "B84DFF", mouth = "fang", acc = { "crown_of_thorns", "cape_royal", "armor", "held_sword" }, hc = "2A1A44", ac = "B84DFF", glow = { "B84DFF", 2.6, 16 } },
	{ n = "Phantom", f = "2A2040", b = "4A3A70", ears = "none", eyes = "void", mouth = "oh", acc = { "ghost_sheet", "orbit_orbs" }, ac = "B84DFF", fx = { { "smoke", "7A5AB0" } }, nb = true },
	{ n = "Enigma", f = "17102A", b = "34264E", ears = "tiny", eyes = "void", mouth = "flat", acc = { "hood", "orbit_shards", "held_orb" }, hc = "17102A", ac = "9A3DFF", glow = { "9A3DFF", 2.4, 15 } },
	{ n = "Cipher", f = "22183A", b = "463A66", ears = "round", eyes = "crystal", ec = "B84DFF", acc = { "rune_circlet", "floating_runes", "glasses_round" }, ac = "B84DFF", glow = { "B84DFF", 2.2, 15 } },
	{ n = "Echo", f = "281E44", b = "4C3E74", ears = "big", eyes = "glow", ec = "FFFFFF", acc = { "headphones", "orbit_ring", "wings_void" }, hc = "B84DFF", ac = "B84DFF", fx = { { "glitch", "FFFFFF" } } },
	{ n = "Null", f = "0A0714", b = "241A3A", c2 = "B84DFF", pat = "spots", ears = "none", eyes = "void", mouth = "none", acc = { "visor", "ground_glow", "orbit_stars" }, ac = "B84DFF", nb = true, glow = { "B84DFF", 2.4, 15 } },
	{ n = "Paradox", f = "1C1238", b = "3C2C68", ears = "fluffy", eyes = "star", tail = "none", acc = { "void_crown", "wings_cosmic", "tail_crystal" }, ac = "B84DFF", fx = { { "stars", "D8A8FF" } }, glow = { "B84DFF", 2.6, 16 } },
	{ n = "Wraith", f = "241A3C", b = "463666", ears = "none", eyes = "glow", ec = "FFFFFF", mouth = "none", acc = { "hood", "held_scythe", "wings_void" }, hc = "241A3C", ac = "B84DFF", fx = { { "smoke", "6A4AA0" } }, nb = true },
}

---------------------------------------------------------------------------
raw.Ancient = {
	{ n = "Fossil", f = "C8B89A", b = "E8DCC4", c2 = "9A8A6A", pat = "stripes", ears = "tiny", eyes = "dot", mouth = "flat", acc = { "stone_crown", "floating_runes" }, ac = "3DE0C0" },
	{ n = "Stone Guardian", f = "8C8A86", b = "BAB8B2", ears = "none", eyes = "glow", ec = "3DE0C0", mouth = "none", size = 1.3, acc = { "stone_crown", "armor", "held_shield" }, ac = "3DE0C0", nb = true },
	{ n = "Rune Keeper", f = "B8864B", b = "E0BC8A", ears = "elf", eyes = "glow", ec = "3DE0C0", acc = { "rune_circlet", "floating_runes", "held_staff" }, ac = "3DE0C0", glow = { "3DE0C0", 1.8, 13 } },
	{ n = "Primal", f = "A06A3C", b = "D0A070", ears = "big", eyes = "angry", mouth = "fang", acc = { "antlers", "spiked_collar", "dino_spikes" } },
	{ n = "Mammoth Pup", f = "8A6A50", b = "C0A080", ears = "big", eyes = "big", mouth = "oh", size = 1.25, acc = { "ruff", "stone_crown" } },
	{ n = "Temple Warden", f = "C9A24A", b = "EBD08A", ears = "round", eyes = "glow", ec = "3DE0C0", mouth = "flat", acc = { "pharaoh", "armor", "held_hammer" }, ac = "3DE0C0" },
	{ n = "Atlantean", f = "6FB8B0", b = "BDE6E0", ears = "fluffy", eyes = "crystal", ec = "3DE0C0", tail = "none", acc = { "tail_fish", "crystal_crown", "fish_scales", "wings_ice" }, ac = "3DE0C0", fx = { { "bubbles", "BDF4EC" } } },
	{ n = "Elder Druid", f = "7A9A5A", b = "B8D09A", ears = "floppy", eyes = "sleepy", acc = { "antlers", "wings_leaf", "held_staff", "lei" }, glow = { "9ADC6A", 1.4, 12 } },
	{ n = "Obsidian Idol", f = "1F1B26", b = "3A3444", ears = "none", eyes = "glow", ec = "3DE0C0", mouth = "none", acc = { "stone_crown", "orbit_shards", "ground_glow" }, ac = "3DE0C0", glow = { "3DE0C0", 2, 14 }, nb = true },
}

---------------------------------------------------------------------------
raw.Unknown = {
	{ n = "The Hollow One", f = "0A0A0A", b = "1E1E1E", ears = "none", eyes = "void", mouth = "none", acc = { "hood", "wings_void", "orbit_ring", "floating_runes" }, hc = "0A0A0A", ac = "FF00E5", glow = { "FF00E5", 3, 18 }, fx = { { "glitch", "FF00E5" } }, nb = true },
	{ n = "Mr. Nobody", f = "F4F4F4", b = "FFFFFF", ears = "none", eyes = "dot", mouth = "flat", acc = { "tophat", "monocle", "cape_royal", "orbit_orbs" }, hc = "111111", ac = "00FFFF", glow = { "00FFFF", 2.6, 16 }, fx = { { "glitch", "00FFFF" } } },
	{ n = "Fragment", f = "20142E", b = "44306A", ears = "tiny", eyes = "crystal", ec = "FF00E5", tail = "none", acc = { "crystal_crown", "tail_crystal", "orbit_shards", "wings_ice" }, ac = "FF00E5", glow = { "FF00E5", 2.8, 17 }, fx = { { "glitch", "00FFFF" } } },
	{ n = "Anomaly", f = "12122A", b = "2A2A5A", ears = "elf", eyes = "star", mouth = "grin", acc = { "propeller", "wings_cosmic", "orbit_ring", "glasses_3d" }, hc = "FF00E5", ac = "FFFF00", glow = { "FFFF00", 2.8, 17 }, fx = { { "glitch", "FFFF00" } } },
	{ n = "Origin", f = "FFFFFF", b = "FFFFFF", ears = "round", eyes = "glow", ec = "FF00E5", acc = { "halo", "wings_seraph", "crown_of_thorns", "orbit_stars" }, ac = "FF00E5", glow = { "FFFFFF", 3, 18 }, fx = { { "glitch", "FF00E5" }, { "sparkle", "FFFFFF" } } },
	{ n = "Final Hamster", f = "050505", b = "181818", ears = "cat", eyes = "glow", ec = "FF00E5", mouth = "fang", size = 1.2, acc = { "void_crown", "wings_void", "armor", "held_scythe", "orbit_ring", "ground_glow" }, ac = "FF00E5", glow = { "FF00E5", 3.4, 20 }, fx = { { "glitch", "00FFFF" }, { "flame", "FF00E5" } } },
}

---------------------------------------------------------------------------
-- expansion
---------------------------------------------------------------------------

local function makeId(name: string): string
	local id = string.lower(name)
	id = string.gsub(id, "[^%w]+", "_")
	id = string.gsub(id, "^_+", "")
	id = string.gsub(id, "_+$", "")
	return id
end

HamsterDatabase.Species = {} :: { any }
HamsterDatabase.ById = {} :: { [string]: any }
HamsterDatabase.ByRarity = {} :: { [string]: { any } }
HamsterDatabase.Spawnable = {} :: { [string]: { any } }

for _, rarityId in RarityConfig.Order do
	HamsterDatabase.ByRarity[rarityId] = {}
	HamsterDatabase.Spawnable[rarityId] = {}
	local entries = raw[rarityId] or {}
	local ordinal = 0
	for _, entry in entries do
		local species = {
			Id = makeId(entry.n),
			Name = entry.n,
			Rarity = rarityId,
			Fur = hex(entry.f),
			Belly = hex(entry.b),
			Color2 = hex(entry.c2),
			Accent = hex(entry.ac) or RarityConfig.ById[rarityId].Accent,
			Ears = entry.ears or "round",
			Eyes = entry.eyes or "dot",
			Mouth = entry.mouth or "smile",
			Pattern = entry.pat or "none",
			Tail = entry.tail or "nub",
			Acc = entry.acc or {},
			Fx = {},
			Glow = nil,
			Size = entry.size or 1,
			EyeColor = hex(entry.ec),
			HatColor = hex(entry.hc),
			EarInner = hex(entry.ei),
			EarColor = hex(entry.earc),
			PawColor = hex(entry.pc),
			TailColor = hex(entry.tc),
			TailTip = hex(entry.tt),
			NoBlush = entry.nb == true,
			Exclusive = entry.x == true,
		}
		if entry.ec and entry.pat == "panda" then
			species.EarColor = hex(entry.ec)
		end
		for _, effect in entry.fx or {} do
			table.insert(species.Fx, { effect[1], Color3.fromHex(effect[2]) })
		end
		if entry.glow then
			species.Glow = { Color3.fromHex(entry.glow[1]), entry.glow[2], entry.glow[3] }
		end

		-- value: 1.0 for the first entry, +0.07 per entry; exclusives are worth 1.5x
		if species.Exclusive then
			species.ValueMult = 1.5
		else
			ordinal += 1
			species.ValueMult = 1 + 0.07 * (ordinal - 1)
			table.insert(HamsterDatabase.Spawnable[rarityId], species)
		end

		table.insert(HamsterDatabase.Species, species)
		table.insert(HamsterDatabase.ByRarity[rarityId], species)
		assert(HamsterDatabase.ById[species.Id] == nil, "duplicate hamster id " .. species.Id)
		HamsterDatabase.ById[species.Id] = species
	end
end

HamsterDatabase.Total = #HamsterDatabase.Species

function HamsterDatabase.get(id: string)
	return HamsterDatabase.ById[id]
end

-- Income per second of one hamster (before player multipliers).
function HamsterDatabase.income(species: any): number
	return RarityConfig.ById[species.Rarity].Income * species.ValueMult
end

-- What it costs to collect the hamster when it runs by.
function HamsterDatabase.price(species: any): number
	return math.floor(HamsterDatabase.income(species) * RarityConfig.PriceFactor + 0.5)
end

function HamsterDatabase.sellValue(species: any): number
	return math.floor(HamsterDatabase.price(species) * RarityConfig.SellRatio)
end

-- Rarities whose names stay hidden in the index until the player owns one.
function HamsterDatabase.isHidden(species: any): boolean
	return RarityConfig.ById[species.Rarity].Hidden == true
end

return HamsterDatabase
