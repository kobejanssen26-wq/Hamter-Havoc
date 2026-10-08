--[[
	DataController: the client's read-only copy of the player profile.
	The server pushes partial updates; UI modules subscribe with `onChanged`.
	Every action goes through `request` (one RemoteFunction, validated server-side).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local SettingsConfig = require(Modules:WaitForChild("SettingsConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local DataController = {}

DataController.Data = {} :: { [string]: any }
DataController.Ready = false

local listeners: { (keys: { [string]: boolean }) -> () } = {}
local readyListeners: { () -> () } = {}

-- Called with a set of changed keys, e.g. { Inventory = true, Derived = true }.
function DataController.onChanged(callback: (keys: { [string]: boolean }) -> ())
	table.insert(listeners, callback)
end

function DataController.onReady(callback: () -> ())
	if DataController.Ready then
		task.spawn(callback)
	else
		table.insert(readyListeners, callback)
	end
end

function DataController.get(key: string): any
	return DataController.Data[key]
end

function DataController.derived(): { [string]: any }
	return DataController.Data.Derived or {}
end

function DataController.setting(key: string): any
	local settings = DataController.Data.Settings
	if settings and settings[key] ~= nil then
		return settings[key]
	end
	return SettingsConfig.Defaults[key]
end

-- Server time in seconds (use for boost / daily countdowns).
function DataController.now(): number
	return Workspace:GetServerTimeNow()
end

function DataController.coins(): number
	return game.Players.LocalPlayer:GetAttribute("Coins") or 0
end

function DataController.gems(): number
	return game.Players.LocalPlayer:GetAttribute("Gems") or 0
end

function DataController.tokens(): number
	return game.Players.LocalPlayer:GetAttribute("Tokens") or 0
end

-- Asks the server to do something. Returns { ok, msg, extra }. Never throws.
function DataController.request(action: string, payload: { [string]: any }?): { ok: boolean, msg: string, extra: any }
	local ok, response = pcall(function()
		return Remotes.func("Request"):InvokeServer(action, payload or {})
	end)
	if ok and type(response) == "table" then
		return response
	end
	return { ok = false, msg = "Couldn't reach the server", extra = nil }
end

function DataController.start()
	Remotes.event("DataUpdate").OnClientEvent:Connect(function(payload: { [string]: any }, full: boolean)
		local changed = {}
		for key, value in payload do
			DataController.Data[key] = value
			changed[key] = true
		end
		if not DataController.Ready and full then
			DataController.Ready = true
			for _, callback in readyListeners do
				task.spawn(callback)
			end
			readyListeners = {}
		end
		for _, callback in listeners do
			task.spawn(callback, changed)
		end
	end)

	-- the server sends the full profile once it's loaded; ask again in case we were too early
	task.spawn(function()
		while not DataController.Ready do
			DataController.request("Resync")
			task.wait(2)
		end
	end)
end

return DataController
