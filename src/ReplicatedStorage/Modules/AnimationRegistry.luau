--[[
	AnimationRegistry: animations are files in Modules/Content/Animations/ (see _Template.luau). Each names a Roblox
	animation asset, the rig it is made for and what it is used for. Definitions without an AssetId are kept but reported
	as "not set up" and never played, so a missing upload can never break movement.
	Loading the asset itself happens in the client's AnimationController (with pcall and a one-time warning).
]]

local ContentRegistry = require(script.Parent.ContentRegistry)
local ContentValidator = require(script.Parent.ContentValidator)

local AnimationRegistry = {}

AnimationRegistry.List = {} :: { any }
AnimationRegistry.ByName = {} :: { [string]: any }
AnimationRegistry.Issues = {} :: { ContentValidator.Issue }

do
	local loaded, problems = ContentRegistry.load("Animations")
	for _, message in problems do
		table.insert(AnimationRegistry.Issues, { Level = "error", Kind = "Animation", Id = "?", Message = message })
	end
	local seen: { [string]: boolean } = {}
	for _, entry in loaded do
		local found = ContentValidator.validateAnimation(entry.Def, seen)
		local fatal = false
		for _, problem in found do
			table.insert(AnimationRegistry.Issues, problem)
			fatal = fatal or problem.Level == "error"
		end
		if not fatal then
			seen[entry.Def.Name] = true
			table.insert(AnimationRegistry.List, entry.Def)
			AnimationRegistry.ByName[entry.Def.Name] = entry.Def
		end
	end
end

-- The definition when it can be played (has a valid AssetId), else nil.
function AnimationRegistry.playable(name: string): any?
	local def = AnimationRegistry.ByName[name]
	if def and def.AssetId and def.AssetId ~= "" then
		return def
	end
	return nil
end

-- All animations of one use ("Idle", "Walk", ...) for one rig that can be played.
function AnimationRegistry.forUse(use: string, rig: string): { any }
	local result = {}
	for _, def in AnimationRegistry.List do
		if def.Use == use and (def.Rig == rig or def.Rig == "Any") and def.AssetId and def.AssetId ~= "" then
			table.insert(result, def)
		end
	end
	return result
end

return AnimationRegistry
