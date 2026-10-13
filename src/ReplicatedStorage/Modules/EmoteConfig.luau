--[[
	EmoteConfig: the emote registry. Emotes are files in Modules/Content/Emotes/ (see _Template.luau); this module loads and
	validates them and exposes the list the wheel shows. Server and client use the same list, so an emote that exists in
	the wheel always exists on the server (which decides who has unlocked it).
]]

local ContentRegistry = require(script.Parent.ContentRegistry)
local ContentValidator = require(script.Parent.ContentValidator)

local EmoteConfig = {}

EmoteConfig.Cooldown = 1.5 -- seconds between two emotes of one player (enforced on the server)
EmoteConfig.MaxSeconds = 12 -- an emote that is still running after this long is stopped (a looping or broken animation can never hold a player)
EmoteConfig.MaxSlots = 8 -- the wheel shows at most this many (extra emotes are ignored with a warning)
EmoteConfig.DefaultKey = "B"
-- Keys a player may choose in Settings for the wheel (all of them are free: see InputConfig).
EmoteConfig.KeyChoices = { "B", "G", "V", "X", "Z" }

-- Roblox's default emotes (played with Humanoid:PlayEmote, they need no asset ids).
EmoteConfig.BuiltinEmotes = { wave = true, point = true, dance = true, dance2 = true, dance3 = true, laugh = true, cheer = true }

-- Fallback when Humanoid:PlayEmote does nothing (a custom Animate script, a rig without the emote bindables, Studio quirks):
-- the animations Roblox's own default Animate script uses for these emotes, per rig. They are Roblox's, so every experience may play them.
EmoteConfig.BuiltinFallback = {
	R15 = {
		wave = "rbxassetid://507770239", point = "rbxassetid://507770453", dance = "rbxassetid://507771019",
		dance2 = "rbxassetid://507776043", dance3 = "rbxassetid://507777268", laugh = "rbxassetid://507770818", cheer = "rbxassetid://507770677",
	},
	R6 = {
		wave = "rbxassetid://128777973", point = "rbxassetid://128853357", dance = "rbxassetid://182435998",
		dance2 = "rbxassetid://182436842", dance3 = "rbxassetid://182436935", laugh = "rbxassetid://129423131", cheer = "rbxassetid://129423030",
	},
}

EmoteConfig.List = {} :: { any }
EmoteConfig.ById = {} :: { [string]: any }
EmoteConfig.Issues = {} :: { ContentValidator.Issue }

local function load()
	local loaded, problems = ContentRegistry.load("Emotes")
	for _, message in problems do
		table.insert(EmoteConfig.Issues, { Level = "error", Kind = "Emote", Id = "?", Message = message })
	end
	local seen: { [string]: boolean } = {}
	local animations = nil
	local registry = script.Parent:FindFirstChild("AnimationRegistry")
	if registry then
		animations = require(registry).ByName
	end
	local context = { Builtin = EmoteConfig.BuiltinEmotes, Animations = animations }
	local list = {}
	for _, entry in loaded do
		local found = ContentValidator.validateEmote(entry.Def, context, seen)
		local fatal = false
		for _, problem in found do
			table.insert(EmoteConfig.Issues, problem)
			fatal = fatal or problem.Level == "error"
		end
		if not fatal then
			seen[entry.Def.Id] = true
			table.insert(list, entry.Def)
		end
	end
	table.sort(list, function(a, b)
		local ao, bo = a.Order or 100, b.Order or 100
		if ao ~= bo then
			return ao < bo
		end
		return a.Id < b.Id
	end)
	for index, def in list do
		if index <= EmoteConfig.MaxSlots then
			table.insert(EmoteConfig.List, def)
			EmoteConfig.ById[def.Id] = def
		else
			table.insert(EmoteConfig.Issues, { Level = "warn", Kind = "Emote", Id = def.Id, Message = "ignored: the wheel holds at most " .. EmoteConfig.MaxSlots .. " emotes" })
		end
	end
end
load()

-- Has a player with this many rebirths unlocked the emote?
function EmoteConfig.isUnlocked(def: any, rebirths: number): boolean
	if def.Default == true and not def.Unlock then
		return true
	end
	if def.Unlock and def.Unlock.MinRebirth then
		return rebirths >= def.Unlock.MinRebirth
	end
	return def.Default == true
end

-- Text for locked emotes in the wheel.
function EmoteConfig.lockText(def: any): string
	if def.Unlock and def.Unlock.MinRebirth then
		return "Rebirth " .. def.Unlock.MinRebirth
	end
	return "Locked"
end

return EmoteConfig
