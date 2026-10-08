--[[
	Audio. All sound ids live here.

	The SFX below use sounds that ship with the Roblox client (rbxasset://sounds/...), so the game
	is never silent. They are layered/pitched per rarity tier to sound more impressive.
	Music has NO default track: pick licensed tracks in the Creator Store and paste their
	"rbxassetid://..." ids into Music.Tracks (the music system loops/shuffles whatever is listed).
]]

local AudioConfig = {}

AudioConfig.Music = {
	Volume = 0.4,
	Tracks = {
		-- "rbxassetid://0000000", -- paste cozy background tracks here
	},
}

-- name -> { Id, Volume, Pitch }
AudioConfig.Sfx = {
	Click = { Id = "rbxasset://sounds/switch.wav", Volume = 0.5, Pitch = 1.2 },
	Hover = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.15, Pitch = 1.6 },
	Open = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.35, Pitch = 1.3 },
	Close = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.3, Pitch = 0.9 },
	Coin = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.35, Pitch = 1.5 },
	Collect = { Id = "rbxasset://sounds/snap.mp3", Volume = 0.6, Pitch = 1.1 },
	Error = { Id = "rbxasset://sounds/bass.wav", Volume = 0.35, Pitch = 0.8 },
	Upgrade = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5, Pitch = 1.9 },
	Rebirth = { Id = "rbxasset://sounds/victory.wav", Volume = 0.7, Pitch = 1 },
	Footstep = { Id = "rbxasset://sounds/action_footsteps_plastic.mp3", Volume = 0.08, Pitch = 2.4 },
	Reward = { Id = "rbxasset://sounds/victory.wav", Volume = 0.5, Pitch = 1.3 },
	Splash = { Id = "rbxasset://sounds/impact_water.mp3", Volume = 0.2, Pitch = 1.4 },
}

-- Higher tier = bigger layered fanfare. `Layers` play together with rising pitch.
AudioConfig.RarityFanfare = {
	[1] = { Sound = "Collect", Layers = { 1 } },
	[2] = { Sound = "Collect", Layers = { 1, 1.25 } },
	[3] = { Sound = "Coin", Layers = { 1, 1.26, 1.5 } },
	[4] = { Sound = "Coin", Layers = { 1, 1.26, 1.5, 2 } },
	[5] = { Sound = "Reward", Layers = { 1, 1.5 } },
	[6] = { Sound = "Reward", Layers = { 0.8, 1.2, 1.6 } },
	[7] = { Sound = "Rebirth", Layers = { 1, 1.5 } },
}

-- Alert for a rare spawn (played to everyone for global announcements).
AudioConfig.RareAlert = {
	Epic = { Sound = "Coin", Layers = { 1, 1.5 } },
	Ultra = { Sound = "Coin", Layers = { 1, 1.26, 1.5 } },
	Legendary = { Sound = "Reward", Layers = { 1, 1.5, 2 } },
	Mythic = { Sound = "Rebirth", Layers = { 0.8, 1.2 } },
	Divine = { Sound = "Rebirth", Layers = { 1, 1.5, 2 } },
	Cosmic = { Sound = "Rebirth", Layers = { 0.7, 1, 1.5 } },
	Celestial = { Sound = "Rebirth", Layers = { 0.7, 1.2, 1.8 } },
	Secret = { Sound = "Rebirth", Layers = { 0.5, 0.75, 1.2 } },
	Ancient = { Sound = "Rebirth", Layers = { 0.5, 0.6, 1 } },
	Unknown = { Sound = "Rebirth", Layers = { 0.4, 0.5, 0.75, 1.5 } },
}

return AudioConfig
