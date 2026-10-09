--[[
	Display names. The keys are the ORIGINAL names the species were authored with; the internal species Id is
	always derived from the original name, so renaming here never touches saves, indexes or code that uses ids
	(for example `silver`, `golden_king`). HamsterDatabase applies this map; UI only ever reads species.Name.
]]
return {
	-- Basic
	["Brownie"] = "Pebblepaws", ["Snowball"] = "Frostwhisker", ["Pebbles"] = "Gravelnose", ["Tiny"] = "Thimblefur",
	["Sleepy"] = "Drowsypouch", ["Chubby"] = "Roundcheek", ["Baby"] = "Littlecrumb", ["Cookie"] = "Crumbpatch",
	["Bread"] = "Loafwhisker", ["Cheese"] = "Wedgenibble", ["Peanut"] = "Shellscamper", ["Toast"] = "Embercrust",
	["Pudding"] = "Wobbletail", ["Nugget"] = "Goldpebble", ["Nibbles"] = "Gnawlet",
	-- Cute
	["Panda"] = "Inkpatch", ["Bunny"] = "Hopwhisker", ["Strawberry"] = "Berrypuff", ["Honey"] = "Amberpaw",
	["Flower"] = "Petalsnout", ["Cloud"] = "Driftfluff", ["Marshmallow"] = "Squishcloud", ["Milk"] = "Creamwhisker",
	["Chocolate"] = "Cocoadash", ["Caramel"] = "Toffeetail", ["Kitty"] = "Purrnibble", ["Teddy"] = "Cuddlegrizzle",
	["Peach"] = "Blushcheek", ["Mochi"] = "Doughpuff", ["Calendar Cutie"] = "Almanac Pip",
	-- Shiny
	["Crystal"] = "Prismtooth", ["Neon"] = "Glowbristle", ["Rainbow"] = "Spectrumtail", ["Gem"] = "Facetpaw",
	["Star"] = "Starcrumb", ["Bubble"] = "Fizzpop", ["Electric"] = "Voltwhisker", ["Golden"] = "Auric Nibbler",
	["Silver"] = "Argent Nibbler", ["Diamond"] = "Brilliant Gnaw", ["Glitter"] = "Sparklefluff", ["Prism"] = "Refractor",
	["Opal"] = "Milkglass", ["Disco"] = "Mirrorball Pip",
	-- Rare
	["Ninja"] = "Shadowstep", ["Pirate"] = "Saltwhisker", ["Cowboy"] = "Dustrider", ["Chef"] = "Saucepaw",
	["Detective"] = "Cluesniff", ["Apprentice"] = "Novice Gnaw", ["Cadet"] = "Brasscap", ["Scientist"] = "Beakerwhisker",
	["Explorer"] = "Trailblazer Pip", ["Painter"] = "Brushtail", ["Musician"] = "Lutenibble", ["Gardener"] = "Sproutkeeper",
	["Sailor"] = "Knotwhisker",
	-- Epic
	["Samurai"] = "Bladewhisker", ["Viking"] = "Ironbeard Pup", ["Vampire"] = "Dusknibble", ["Mummy"] = "Relicpuff",
	["Witch"] = "Hexsnout", ["Pharaoh"] = "Sandcrown", ["Robot"] = "Cogwhisker", ["Alien"] = "Zorbnose",
	["Yeti"] = "Snowdrift Brute", ["Mermaid"] = "Tidecheek", ["Pumpkin"] = "Gourdgrin", ["Ghost"] = "Wispfur",
	["Jester"] = "Mirthtail", ["Wizard"] = "Runebrew", ["Astronaut"] = "Orbitpaw", ["DJ"] = "Bassnibble",
	["Gamer"] = "Pixelpaw", ["Founder Fuzz"] = "Founder's Fuzz",
	-- Ultra
	["Inferno"] = "Embercheeks", ["Frostbite"] = "Rimeclaw", ["Thunderbolt"] = "Stormcrackle", ["Magma"] = "Cinderback",
	["Tsunami"] = "Wavecrest", ["Blossom"] = "Bloomtail", ["Shadow"] = "Umbrapaw", ["Cyberpunk"] = "Neonwire",
	["Steampunk"] = "Gearsnout", ["Candyland"] = "Sugarspire", ["Aurora"] = "Skyribbon", ["Neon Samurai"] = "Glowblade",
	-- Legendary
	["Golden King"] = "Sovereign Auric", ["Dragon Hamster"] = "Wyrmwhisker", ["Phoenix"] = "Ashfeather", ["Unicorn"] = "Horncrest",
	["Griffin"] = "Talonpaw", ["Angel Guardian"] = "Haloed Warden", ["Archmage"] = "Arcane Gnawer", ["Pirate Captain"] = "Captain Brinewhisker",
	["Lion Heart"] = "Manehart", ["Dark Knight"] = "Nightplate", ["Storm Lord"] = "Tempest Sire", ["Ruby Queen"] = "Crimson Regent",
	["Royal Hamster"] = "Crownpaw", ["Ancient Hamster"] = "Elderwhisker", ["Dragon Lord"] = "Drakemaw Sire", ["Sunday Sunbeam"] = "Sundial Glow",
	-- Mythic
	["Hellfire Lord"] = "Brimstone Sire", ["Kraken Pup"] = "Inkmaw", ["Leviathan"] = "Deepcoil", ["Behemoth"] = "Mountainback",
	["Chimera"] = "Tripleclaw", ["Minotaur"] = "Labyrinth Brute", ["Nine-Tails"] = "Ninefold Fox", ["Demon Lord"] = "Hollowhorn",
	["Titan"] = "Colossus Pip", ["Valkyrie"] = "Skyspear", ["Reaper"] = "Scythetail", ["Lich King"] = "Bonecrown",
	-- Divine
	["Skyfather"] = "Zenith Elder", ["Tidal King"] = "Brinecrown", ["Athena"] = "Aegis Owlpaw", ["Sun Priest"] = "Dawnchanter",
	["Moon Priestess"] = "Lunar Votary", ["Divine Empress"] = "Radiant Matron", ["Ra"] = "Solarch", ["Anubis"] = "Jackalscribe",
	["Odin"] = "Ravenwatcher", ["Seraph"] = "Sixwing", ["Gaia"] = "Rootmother",
	-- Cosmic
	["Nebula"] = "Dustveil", ["Galaxy"] = "Spiralwhisker", ["Supernova"] = "Blastbloom", ["Comet"] = "Tailstreak",
	["Black Hole"] = "Voidmaw", ["Quasar"] = "Beaconpaw", ["Pulsar"] = "Ticktail", ["Meteor"] = "Cratercheek",
	["Moonwalker"] = "Lunarstep", ["Solar Flare"] = "Coronasnap", ["Astro Prime"] = "Vanguard Orbit",
	-- Celestial
	["Dawn Bringer"] = "First Light", ["Twilight Sage"] = "Duskreader", ["Starweaver"] = "Loomstar", ["Moonlight Oracle"] = "Silverfate",
	["Sun Empress"] = "Noonthrone", ["Aether"] = "Ethersong", ["Constellation"] = "Starmap Pip", ["Zodiac"] = "Twelvesign",
	["Eclipse"] = "Eclipse Squeak", ["Harmonic"] = "Chimewhisker",
	-- Secret
	["Glitch"] = "Static Pip", ["Void Walker"] = "Gapstrider", ["Shadow Monarch"] = "Umbral Regent", ["Phantom"] = "Veilnibble",
	["Enigma"] = "Riddlefur", ["Cipher"] = "Codetail", ["Echo"] = "Hollowsqueak", ["Null"] = "Blankpaw",
	["Paradox"] = "Twicewhisker", ["Wraith"] = "Mournfur",
	-- Ancient
	["Fossil"] = "Amberbone", ["Stone Guardian"] = "Cairn Warden", ["Rune Keeper"] = "Glyphkeeper", ["Primal"] = "Firstburrow",
	["Mammoth Pup"] = "Tuskling", ["Temple Warden"] = "Ziggurat Guard", ["Atlantean"] = "Sunkencrest", ["Elder Druid"] = "Moss Elder",
	["Obsidian Idol"] = "Glassstone Idol",
	-- Unknown
	["The Hollow One"] = "The Hollow One", ["Mr. Nobody"] = "Mx. Nobody", ["Fragment"] = "Shardling", ["Anomaly"] = "Oddity",
	["Origin"] = "First Burrow", ["Final Hamster"] = "Last Whisker",
}
