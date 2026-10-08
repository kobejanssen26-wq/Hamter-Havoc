--[[
	Player settings: defaults, validation schema and the order shown in the Settings UI.
	The server validates every change against this schema (clients can't store junk).
]]

local SettingsConfig = {}

SettingsConfig.Defaults = {
	Music = true,
	MusicVolume = 0.4,
	SFX = true,
	SFXVolume = 0.8,
	Particles = true,
	LowGraphics = false,
	ShowOtherPlayers = true,
	ShowValues = true,
	Notifications = true,
	CameraShake = true,
	AutoEquip = true,
	AutoDelete = 0, -- 0 = off, otherwise auto-sell duplicates up to this rarity rank
}

-- Type: toggle | slider | choice
SettingsConfig.List = {
	{ Key = "Music", Label = "Music", Type = "toggle", Icon = "Sparkle" },
	{ Key = "MusicVolume", Label = "Music volume", Type = "slider", Min = 0, Max = 1, Icon = "Info" },
	{ Key = "SFX", Label = "Sound effects", Type = "toggle", Icon = "Info" },
	{ Key = "SFXVolume", Label = "Effects volume", Type = "slider", Min = 0, Max = 1, Icon = "Info" },
	{ Key = "Particles", Label = "Particle effects", Type = "toggle", Icon = "Sparkle" },
	{ Key = "LowGraphics", Label = "Low graphics mode", Type = "toggle", Icon = "Settings" },
	{ Key = "ShowOtherPlayers", Label = "Show other players", Type = "toggle", Icon = "Hamster" },
	{ Key = "ShowValues", Label = "Show hamster values", Type = "toggle", Icon = "Coins" },
	{ Key = "Notifications", Label = "Notifications", Type = "toggle", Icon = "Info" },
	{ Key = "CameraShake", Label = "Camera shake", Type = "toggle", Icon = "Speed" },
	{ Key = "AutoEquip", Label = "Auto-equip best hamsters", Type = "toggle", Icon = "Star" },
	{
		Key = "AutoDelete",
		Label = "Auto-delete duplicates",
		Type = "choice",
		Icon = "Storage",
		-- value = highest rarity rank that is auto-sold when you already own the hamster
		Options = {
			{ Value = 0, Text = "Off" },
			{ Value = 1, Text = "Basic" },
			{ Value = 2, Text = "Up to Cute" },
			{ Value = 3, Text = "Up to Shiny" },
			{ Value = 4, Text = "Up to Rare" },
			{ Value = 5, Text = "Up to Epic" },
		},
	},
}

SettingsConfig.ByKey = {} :: { [string]: any }
for _, entry in SettingsConfig.List do
	SettingsConfig.ByKey[entry.Key] = entry
end

-- Returns (ok, cleanedValue)
function SettingsConfig.validate(key: any, value: any): (boolean, any)
	if type(key) ~= "string" then
		return false, nil
	end
	local entry = SettingsConfig.ByKey[key]
	if not entry then
		return false, nil
	end
	if entry.Type == "toggle" then
		if type(value) ~= "boolean" then
			return false, nil
		end
		return true, value
	elseif entry.Type == "slider" then
		if type(value) ~= "number" or value ~= value then
			return false, nil
		end
		return true, math.clamp(math.floor(value * 100 + 0.5) / 100, entry.Min, entry.Max)
	elseif entry.Type == "choice" then
		for _, option in entry.Options do
			if option.Value == value then
				return true, value
			end
		end
		return false, nil
	end
	return false, nil
end

return SettingsConfig
