--[[
	Remote registry. Network surface is deliberately small:

	Client -> Server
	  Request (RemoteFunction)  one validated entry point for every UI action: Request:InvokeServer(action, payload)
	  Interact (RemoteEvent)    "I want to claim / steal / pick up hamster <id>" (rate limited, fully validated)
	  Attack (RemoteEvent)      "slap whoever is in front of me" (server picks the target, cooldown enforced)

	Server -> Client
	  DataUpdate     partial profile updates (+ derived numbers)
	  HamsterAdd     list of hamster balls that exist (sent when they appear / when you join)
	  HamsterState   one ball changed state (claimed, stolen, carried, dropped ...)
	  HamsterSnap    positions of the balls that moved (10 Hz)
	  HamsterRemove  a ball is gone (secured, exited, lost ...)
	  Channel        progress bar for a steal / pick-up you started
	  CollectResult  a hamster of yours was secured (reveal + effects)
	  Knockback      you were slapped or zapped: apply this velocity
	  Announce       server-wide rare event banners
	  Notify         small toast messages
	  OpenUI         opens a menu (from world prompts)
	  Fx             one-off effects (rare spawn alert, claim, steal, drop, secure, zap, rebirth ...)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "RemoteEvents"

local EVENTS = {
	"Interact",
	"Attack",
	"DataUpdate",
	"HamsterAdd",
	"HamsterState",
	"HamsterSnap",
	"HamsterRemove",
	"Channel",
	"CollectResult",
	"Knockback",
	"Announce",
	"Notify",
	"OpenUI",
	"Fx",
}
local FUNCTIONS = { "Request" }

local Remotes = {}

-- Server: call once at startup.
function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init is server only")
	if ReplicatedStorage:FindFirstChild(FOLDER_NAME) then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in EVENTS do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	end
	for _, name in FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

function Remotes.event(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.func(name: string): RemoteFunction
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes
