--[[
	ActionFx: the server announces that a character action happened (see Modules/ActionCatalog). Call it only AFTER the thing
	really happened (purchase went through, placement validated ...). Every client animates it for that player.
	Unknown ids are ignored with a warning; the same player can not repeat the same action faster than its catalog Cooldown.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ActionCatalog = require(ReplicatedStorage.Modules.ActionCatalog)
local Remotes = require(ReplicatedStorage.Remotes)

local ActionFx = {}

local last: { [Player]: { [string]: number } } = {}

function ActionFx.play(player: Player, actionId: string): boolean
	local entry = ActionCatalog.ById[actionId]
	if not entry then
		warn("[ActionFx] unknown action '" .. tostring(actionId) .. "'")
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local clock = os.clock()
	local mine = last[player]
	if not mine then
		mine = {}
		last[player] = mine
	end
	if mine[actionId] and clock - mine[actionId] < entry.Cooldown then
		return false
	end
	mine[actionId] = clock
	Remotes.event("Fx"):FireAllClients("Action", actionId, root.Position, player.UserId)
	return true
end

function ActionFx.forget(player: Player)
	last[player] = nil
end

return ActionFx
