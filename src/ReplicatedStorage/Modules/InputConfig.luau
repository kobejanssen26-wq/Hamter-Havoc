--[[
	InputConfig: every keyboard binding of the game in ONE place, so conflicts are visible (and tested).
	Controllers read their key from here instead of hard-coding it. The emote key is chosen by the player in
	Settings ("Emote wheel key", one of EmoteConfig.KeyChoices).
]]

local EmoteConfig = require(script.Parent.EmoteConfig)

local InputConfig = {}

-- name -> KeyCode name. (Roblox's own: Esc menu, Tab player list, / chat, Shift sprint, Space jump.)
InputConfig.Bindings = {
	Interact = "E", -- claim / steal / pick up a hamster ball
	Slap = "Q",
	WorldMenu = "F", -- proximity prompts: shops, upgrades, theft hold, elevator
	FreeMouse = "LeftAlt", -- first person: hold to use the mouse
	Hotbar1 = "One", Hotbar2 = "Two", Hotbar3 = "Three", Hotbar4 = "Four", Hotbar5 = "Five", Hotbar6 = "Six",
	Emote = EmoteConfig.DefaultKey, -- overridden by the player's setting
}

-- Keys that other parts of Roblox use and that must never be rebound to a game action.
InputConfig.Reserved = { Escape = true, Tab = true, Slash = true, Space = true, LeftShift = true, W = true, A = true, S = true, D = true }

-- Returns (ok, message): no two game actions share a key and none uses a reserved key.
function InputConfig.check(bindings: { [string]: string }?): (boolean, string)
	local map = bindings or InputConfig.Bindings
	local used: { [string]: string } = {}
	for action, key in map do
		if InputConfig.Reserved[key] then
			return false, string.format("%s uses reserved key %s", action, key)
		end
		if used[key] then
			return false, string.format("%s and %s both use %s", used[key], action, key)
		end
		used[key] = action
	end
	return true, "ok"
end

-- The emote key for a player's setting: falls back to the default when the saved value is not an allowed choice or
-- would collide with another action.
function InputConfig.emoteKey(setting: any): string
	if type(setting) == "string" and table.find(EmoteConfig.KeyChoices, setting) then
		local test = table.clone(InputConfig.Bindings)
		test.Emote = setting
		if InputConfig.check(test) then
			return setting
		end
	end
	return EmoteConfig.DefaultKey
end

return InputConfig
