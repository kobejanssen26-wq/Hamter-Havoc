--[[
	Remote registry. Network surface is deliberately tiny:

	Client -> Server
	  Request (RemoteFunction)  one validated entry point for every UI action: Request:InvokeServer(action, payload)
	  Collect (RemoteEvent)     "I want to grab hamster <id>"  (rate limited, fully validated)

	Server -> Client
	  DataUpdate     partial profile updates (+ derived numbers)
	  SpawnHamster   a hamster started running along the road for this player
	  RemoveHamster  it was collected / left the road
	  CollectResult  feedback for the collecting player (effects + sounds)
	  Announce       server-wide rare event banners
	  Notify         small toast messages
	  OpenUI         opens a menu (from world prompts)
	  Fx             one-off effects (rare spawn alert, rebirth burst ...)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "RemoteEvents"

local EVENTS = { "Collect", "DataUpdate", "SpawnHamster", "RemoveHamster", "CollectResult", "Announce", "Notify", "OpenUI", "Fx" }
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
