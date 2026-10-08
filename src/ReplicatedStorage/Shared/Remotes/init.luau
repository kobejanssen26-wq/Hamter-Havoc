--[[
	Remote registry. The game is almost entirely server driven (ProximityPrompts + attributes),
	so the only remote is a server -> client notification. Clients can never send gameplay requests.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"
local EVENT_NAMES = { "Notify" } -- Notify(text: string, kind: "info" | "success" | "error")

local Remotes = {}

-- Server: call once at startup.
function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init is server only")
	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	for _, name in EVENT_NAMES do
		local event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

function Remotes.get(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	return folder:WaitForChild(name) :: RemoteEvent
end

return Remotes
