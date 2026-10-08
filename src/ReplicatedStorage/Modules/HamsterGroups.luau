--[[
	Ways to browse the Hamster Index besides rarity: by THEME, by WORLD (where in the game it lives) and by EVENT.
	Pure data + a few helpers: every species belongs to exactly one theme and one world.
]]

local HamsterDatabase = require(script.Parent.HamsterDatabase)

local HamsterGroups = {}

export type Group = { Id: string, Name: string, Icon: string, Info: string, Species: { any } }

-- Themes: first list that contains the hamster's name wins.
local THEMES = {
	{ Id = "treats", Name = "Sweet Treats", Icon = "Heart", Info = "Snacks, sweets and sugary friends", Members = {
		"Cookie", "Bread", "Cheese", "Peanut", "Toast", "Pudding", "Nugget", "Nibbles", "Strawberry", "Honey", "Marshmallow", "Milk", "Chocolate", "Caramel", "Peach", "Mochi", "Candyland",
	} },
	{ Id = "cuddly", Name = "Cuddly Pals", Icon = "Hamster", Info = "The softest, fluffiest hamsters around", Members = {
		"Brownie", "Snowball", "Pebbles", "Tiny", "Sleepy", "Chubby", "Baby", "Panda", "Bunny", "Flower", "Cloud", "Kitty", "Teddy", "Calendar Cutie",
	} },
	{ Id = "shiny", Name = "Shiny & Neon", Icon = "Sparkle", Info = "Glitter, gems and glowing lights", Members = {
		"Crystal", "Neon", "Rainbow", "Gem", "Star", "Bubble", "Electric", "Golden", "Silver", "Diamond", "Glitter", "Prism", "Opal", "Disco", "Cyberpunk",
	} },
	{ Id = "jobs", Name = "Heroes & Jobs", Icon = "Shield", Info = "Adventurers, warriors and hard workers", Members = {
		"Ninja", "Pirate", "Cowboy", "Chef", "Detective", "Apprentice", "Cadet", "Scientist", "Explorer", "Painter", "Musician", "Gardener", "Sailor",
		"Samurai", "Viking", "Jester", "DJ", "Gamer", "Steampunk", "Neon Samurai", "Pirate Captain", "Dark Knight",
	} },
	{ Id = "spooky", Name = "Spooky Night", Icon = "Clock", Info = "Things that go squeak in the night", Members = {
		"Vampire", "Mummy", "Witch", "Pumpkin", "Ghost", "Shadow", "Hellfire Lord", "Demon Lord", "Reaper", "Lich King",
	} },
	{ Id = "fantasy", Name = "Fantasy Realm", Icon = "Rebirth", Info = "Dragons, wizards and legendary beasts", Members = {
		"Yeti", "Mermaid", "Wizard", "Dragon Hamster", "Phoenix", "Unicorn", "Griffin", "Angel Guardian", "Archmage", "Dragon Lord",
		"Kraken Pup", "Leviathan", "Behemoth", "Chimera", "Minotaur", "Nine-Tails", "Titan", "Valkyrie",
	} },
	{ Id = "elements", Name = "Elements", Icon = "Rebirth", Info = "Fire, ice, thunder, water and the wild", Members = {
		"Inferno", "Frostbite", "Thunderbolt", "Magma", "Tsunami", "Blossom", "Aurora", "Storm Lord", "Tidal King", "Gaia", "Solar Flare",
	} },
	{ Id = "royal", Name = "Royalty & Gods", Icon = "Star", Info = "Kings, queens and the divine", Members = {
		"Pharaoh", "Golden King", "Lion Heart", "Ruby Queen", "Royal Hamster", "Sunday Sunbeam", "Founder Fuzz",
		"Skyfather", "Athena", "Sun Priest", "Moon Priestess", "Divine Empress", "Ra", "Anubis", "Odin", "Seraph",
	} },
	{ Id = "space", Name = "Space & Stars", Icon = "Speed", Info = "Astronauts, planets and the night sky", Members = {
		"Robot", "Alien", "Astronaut", "Nebula", "Galaxy", "Supernova", "Comet", "Black Hole", "Quasar", "Pulsar", "Meteor", "Moonwalker", "Astro Prime",
		"Dawn Bringer", "Twilight Sage", "Starweaver", "Moonlight Oracle", "Sun Empress", "Aether", "Constellation", "Zodiac", "Eclipse", "Harmonic",
	} },
	{ Id = "relics", Name = "Ancient Relics", Icon = "Storage", Info = "Old stones, old magic, older hamsters", Members = {
		"Ancient Hamster", "Fossil", "Stone Guardian", "Rune Keeper", "Primal", "Mammoth Pup", "Temple Warden", "Atlantean", "Elder Druid", "Obsidian Idol",
	} },
	{ Id = "mystery", Name = "Mystery", Icon = "Info", Info = "Glitches, voids and things nobody understands", Members = {
		"Glitch", "Void Walker", "Shadow Monarch", "Phantom", "Enigma", "Cipher", "Echo", "Null", "Paradox", "Wraith",
		"The Hollow One", "Mr. Nobody", "Fragment", "Anomaly", "Origin", "Final Hamster",
	} },
}

-- Worlds: which part of the progression a rarity belongs to.
local WORLDS = {
	{ Id = "meadow", Name = "Meadow Burrow", Icon = "Luck", Info = "Where every hamster story begins", Rarities = { "Basic", "Cute" } },
	{ Id = "caverns", Name = "Crystal Caverns", Icon = "Gem", Info = "Shiny finds and clever workers", Rarities = { "Shiny", "Rare" } },
	{ Id = "kingdom", Name = "Hero Kingdom", Icon = "Floor", Info = "Legends of the realm", Rarities = { "Epic", "Ultra", "Legendary" } },
	{ Id = "peaks", Name = "Mythic Peaks", Icon = "Rebirth", Info = "Monsters and gods", Rarities = { "Mythic", "Divine" } },
	{ Id = "cosmos", Name = "Starlit Cosmos", Icon = "Sparkle", Info = "Beyond the sky", Rarities = { "Cosmic", "Celestial" } },
	{ Id = "depths", Name = "Hidden Depths", Icon = "Lock", Info = "Secrets, ruins and the unknown", Rarities = { "Secret", "Ancient", "Unknown" } },
}

local themeByName: { [string]: string } = {}
for _, theme in THEMES do
	for _, name in theme.Members do
		if not themeByName[name] then
			themeByName[name] = theme.Id
		end
	end
end

local worldByRarity: { [string]: string } = {}
for _, world in WORLDS do
	for _, rarity in world.Rarities do
		worldByRarity[rarity] = world.Id
	end
end

function HamsterGroups.themeOf(species: any): string
	return themeByName[species.Name] or "cuddly"
end

function HamsterGroups.worldOf(species: any): string
	return worldByRarity[species.Rarity] or "meadow"
end

local cache: { [string]: { Group } } = {}

-- Ordered groups for a browsing mode: "Theme", "World" or "Event".
function HamsterGroups.groups(mode: string): { Group }
	if cache[mode] then
		return cache[mode]
	end
	local result: { Group } = {}
	if mode == "Theme" then
		for _, theme in THEMES do
			table.insert(result, { Id = theme.Id, Name = theme.Name, Icon = theme.Icon, Info = theme.Info, Species = {} })
		end
	elseif mode == "World" then
		for _, world in WORLDS do
			table.insert(result, { Id = world.Id, Name = world.Name, Icon = world.Icon, Info = world.Info, Species = {} })
		end
	else
		table.insert(result, { Id = "event", Name = "Events & Exclusives", Icon = "Daily", Info = "Only from daily rewards, codes and quests - they never spawn", Species = {} })
	end
	local byId: { [string]: Group } = {}
	for _, group in result do
		byId[group.Id] = group
	end
	for _, species in HamsterDatabase.Species do
		local id = if mode == "Theme" then HamsterGroups.themeOf(species) elseif mode == "World" then HamsterGroups.worldOf(species) elseif species.Exclusive then "event" else nil
		local group = if id then byId[id] else nil
		if group then
			table.insert(group.Species, species)
		end
	end
	cache[mode] = result
	return result
end

return HamsterGroups
