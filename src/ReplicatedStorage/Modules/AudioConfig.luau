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

	-- claim / steal loop
	Claim = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Pitch = 1.3 },
	Steal = { Id = "rbxasset://sounds/bass.wav", Volume = 0.7, Pitch = 1.5 },
	Alarm = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.4, Pitch = 0.8 },
	Drop = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.7, Pitch = 0.8 },
	Recover = { Id = "rbxasset://sounds/victory.wav", Volume = 0.5, Pitch = 1.6 },
	Secure = { Id = "rbxasset://sounds/victory.wav", Volume = 0.65, Pitch = 1.15 },
	Channel = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.25, Pitch = 1.1 },
	SecurityOn = { Id = "rbxasset://sounds/switch.wav", Volume = 0.5, Pitch = 0.9 },
	SecurityOff = { Id = "rbxasset://sounds/switch.wav", Volume = 0.45, Pitch = 0.7 },
	Zap = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Pitch = 0.7 },
	Slap = { Id = "rbxasset://sounds/swoosh.wav", Volume = 0.5, Pitch = 1.7 },
	Hit = { Id = "rbxasset://sounds/kickhurt.wav", Volume = 0.7, Pitch = 1.1 },
	WheelTick = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.05, Pitch = 2.2 },
}

-- One quiet tick for the last seconds of your gate timer (replaces the old repeating beeps).
AudioConfig.Sfx.GateTick = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.3, Pitch = 1.3 }

-- Category volumes (multiplied with each sound's own Volume, the player's Effects volume and, for gate sounds,
-- the "Gate sounds" setting). Change a number here to rebalance a whole group.
AudioConfig.Categories = {
	UI = 1, -- clicks, hovers, panels
	Purchase = 1,
	Movement = 0.8, -- footsteps, wheel ticks
	Gate = 0.4, -- security on/off, alarms, zaps, ticks
	Steal = 0.8,
	Escape = 1, -- secure / recover fanfares
	Failed = 0.9, -- drops, errors, failed thefts
	Rebirth = 1,
	Emote = 0.8,
	Notification = 0.8,
}

-- Sound name -> category (anything not listed is "UI").
AudioConfig.CategoryOf = {
	Click = "UI", Hover = "UI", Open = "UI", Close = "UI",
	Coin = "Purchase", Upgrade = "Purchase", Reward = "Notification",
	Footstep = "Movement", WheelTick = "Movement", Splash = "Movement",
	SecurityOn = "Gate", SecurityOff = "Gate", Alarm = "Gate", Zap = "Gate", GateTick = "Gate",
	Steal = "Steal", Slap = "Steal", Hit = "Steal", Channel = "Steal", Claim = "Steal",
	Secure = "Escape", Recover = "Escape", Collect = "Escape",
	Drop = "Failed", Error = "Failed", TheftFailed = "Failed",
	Rebirth = "Rebirth",
	Emote = "Emote",
}

-- Minimum seconds between two plays of the same sound (stops stacking from busy loops / duplicate events).
AudioConfig.MinInterval = { Default = 0.05, SecurityOn = 1.5, SecurityOff = 1.5, Alarm = 0.6, Zap = 0.8, GateTick = 0.8, Footstep = 0.12 }

AudioConfig.Sfx.TheftFailed = { Id = "rbxasset://sounds/bass.wav", Volume = 0.5, Pitch = 0.9 }
AudioConfig.Sfx.Emote = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.3, Pitch = 1.7 }

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
