local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Remotes)

local Notifier = {}

-- kind: "info" | "success" | "error" | "reward"
function Notifier.send(player: Player, text: string, kind: string?)
	if player.Parent == nil then
		return
	end
	Remotes.event("Notify"):FireClient(player, text, kind or "info")
end

function Notifier.openUI(player: Player, name: string, focus: string?)
	if player.Parent ~= nil then
		Remotes.event("OpenUI"):FireClient(player, name, focus)
	end
end

return Notifier
