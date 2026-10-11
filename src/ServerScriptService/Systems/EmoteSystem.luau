--[[
	EmoteSystem: the server decides whether a player may use an emote (it exists, is unlocked, cooldown), the client
	plays the animation on its own character (Roblox replicates it to everybody) and the server broadcasts a tiny
	effect event so nearby players hear the optional emote sound.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmoteConfig = require(ReplicatedStorage.Modules.EmoteConfig)

local Remotes = require(ReplicatedStorage.Remotes)

local DataSystem = require(script.Parent.DataSystem)
local PlayerState = require(script.Parent.PlayerState)

local EmoteSystem = {}

local lastUse: { [Player]: number } = {}

-- Returns (ok, message, emote-info for the client)
function EmoteSystem.request(player: Player, emoteId: any): (boolean, string, any?)
	local data = DataSystem.get(player)
	local def = if type(emoteId) == "string" then EmoteConfig.ById[emoteId] else nil
	if not data or not def then
		return false, "Unknown emote"
	end
	if not EmoteConfig.isUnlocked(def, data.Rebirths) then
		return false, "Locked: " .. EmoteConfig.lockText(def)
	end
	local humanoid, root = PlayerState.character(player)
	if not humanoid or not root then
		return false, "You can't emote right now"
	end
	if PlayerState.isStunned(player) then
		return false, "You can't emote while stunned"
	end
	local clock = os.clock()
	if (lastUse[player] or 0) + EmoteConfig.Cooldown > clock then
		return false, "Slow down"
	end
	lastUse[player] = clock
	if def.Sound then
		Remotes.event("Fx"):FireAllClients("Emote", "", root.Position, def.Sound)
	end
	return true, def.DisplayName, { Id = def.Id, Builtin = def.Builtin, AnimationId = def.AnimationId, Animation = def.Animation }
end

function EmoteSystem.forget(player: Player)
	lastUse[player] = nil
end

return EmoteSystem
