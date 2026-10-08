local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Notifier = {}

function Notifier.send(player: Player, text: string, kind: string?)
	if player.Parent == nil then
		return
	end
	Remotes.get("Notify"):FireClient(player, text, kind or "info")
end

return Notifier
