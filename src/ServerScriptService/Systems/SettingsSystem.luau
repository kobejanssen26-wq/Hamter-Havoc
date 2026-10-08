--[[
	SettingsSystem: validated, saved player settings (see SettingsConfig for the schema).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SettingsConfig = require(ReplicatedStorage.Modules.SettingsConfig)

local DataSystem = require(script.Parent.DataSystem)
local ReplicationSystem = require(script.Parent.ReplicationSystem)

local SettingsSystem = {}

function SettingsSystem.update(player: Player, key: any, value: any): (boolean, string)
	local data = DataSystem.get(player)
	if not data then
		return false, "No data"
	end
	local ok, clean = SettingsConfig.validate(key, value)
	if not ok then
		return false, "Invalid setting"
	end
	data.Settings[key] = clean
	ReplicationSystem.mark(player, "Settings")
	return true, "Saved"
end

return SettingsSystem
