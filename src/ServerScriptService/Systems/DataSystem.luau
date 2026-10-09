--[[
	DataSystem: loads / autosaves / saves player profiles with DataStores.

	- UpdateAsync with a simple session lock (JobId + timestamp) so two servers can't overwrite each other.
	- Failed loads fall back to a TEMPORARY profile that is never saved (so a DataStore outage can't wipe
	  good data), and the player is told about it.
	- Autosave every minute for dirty profiles, save on leave, save everyone on server shutdown.
	Studio: enable "Game Settings > Security > Enable Studio Access to API Services" to test saving.
]]

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage.Modules
local ProfileTemplate = require(Modules.ProfileTemplate)
local Util = require(Modules.Util)

local STORE_NAME = "HamsterPlaza_Profiles_v1"
local LOCK_SECONDS = 120
local AUTOSAVE_SECONDS = 60

local DataSystem = {}

type Profile = {
	Data: any,
	Key: string,
	Temporary: boolean,
	Dirty: boolean,
	Saving: boolean,
	LastSave: number,
}

local profiles: { [Player]: Profile } = {}
local dataStore: DataStore? = nil
local storeResolved = false

local function getStore(): DataStore?
	if not storeResolved then
		storeResolved = true
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		if ok then
			dataStore = result
		end
	end
	return dataStore
end

local function lockedByOther(old: any): boolean
	return old ~= nil and old._Lock ~= nil and old._Lock.Id ~= game.JobId and os.time() - old._Lock.Time < LOCK_SECONDS
end

-- Yields until the profile is loaded (or a temporary one is created). Returns the data table.
function DataSystem.load(player: Player): any
	local profile: Profile = {
		Data = nil,
		Key = "P_" .. player.UserId,
		Temporary = false,
		Dirty = false,
		Saving = false,
		LastSave = os.clock(),
	}

	local loaded: any = nil
	local store = getStore()
	if store then
		local attempts = if RunService:IsStudio() then 2 else 6
		for attempt = 1, attempts do
			local locked = false
			local ok, result = pcall(function()
				return store:UpdateAsync(profile.Key, function(old)
					if lockedByOther(old) then
						locked = true
						return nil
					end
					local data = old or {}
					data._Lock = { Id = game.JobId, Time = os.time() }
					return data
				end)
			end)
			if ok and not locked and result then
				loaded = result
				break
			end
			if not ok then
				warn(string.format("[DataSystem] load attempt %d failed for %s: %s", attempt, player.Name, tostring(result)))
			end
			if player.Parent == nil then
				break
			end
			task.wait(if locked then 4 else 1.5)
		end
	end

	if loaded then
		loaded._Lock = nil
		if loaded.Tutorial == nil and (loaded.Sessions or 0) > 0 then
			loaded.Tutorial = { Step = 99, Done = true, Skipped = false } -- existing players never see the intro
		end
		profile.Data = Util.reconcile(loaded, ProfileTemplate)
	else
		profile.Data = Util.deepCopy(ProfileTemplate)
		profile.Temporary = true
		warn("[DataSystem] using a TEMPORARY profile for " .. player.Name .. " (progress will not be saved)")
	end

	local data = profile.Data
	if data.FirstJoin == 0 then
		data.FirstJoin = os.time()
	end
	data.LastLogin = os.time()
	data.Sessions += 1

	profiles[player] = profile
	return data
end

function DataSystem.get(player: Player): any
	local profile = profiles[player]
	return if profile then profile.Data else nil
end

function DataSystem.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataSystem.isTemporary(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.Temporary
end

function DataSystem.markDirty(player: Player)
	local profile = profiles[player]
	if profile then
		profile.Dirty = true
	end
end

-- Saves now. `release` also drops the session lock (used when the player leaves).
function DataSystem.save(player: Player, release: boolean?): boolean
	local profile = profiles[player]
	local store = getStore()
	if not profile or profile.Temporary or not store then
		return true
	end
	-- wait for an autosave that is already running
	local waited = 0
	while profile.Saving and waited < 10 do
		task.wait(0.2)
		waited += 0.2
	end

	profile.Saving = true
	local snapshot = Util.deepCopy(profile.Data)
	local ok, err = pcall(function()
		store:UpdateAsync(profile.Key, function(old)
			if lockedByOther(old) then
				return nil
			end
			snapshot._Lock = if release then nil else { Id = game.JobId, Time = os.time() }
			return snapshot
		end)
	end)
	profile.Saving = false
	if ok then
		profile.Dirty = false
		profile.LastSave = os.clock()
	else
		warn(string.format("[DataSystem] save failed for %s: %s", player.Name, tostring(err)))
	end
	return ok
end

function DataSystem.release(player: Player)
	if profiles[player] then
		DataSystem.save(player, true)
		profiles[player] = nil
	end
end

function DataSystem.start()
	task.spawn(function()
		while true do
			task.wait(15)
			for player, profile in profiles do
				if profile.Dirty and not profile.Temporary and os.clock() - profile.LastSave >= AUTOSAVE_SECONDS then
					task.spawn(DataSystem.save, player, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				DataSystem.release(player)
				pending -= 1
			end)
		end
		local waited = 0
		while pending > 0 and waited < 25 do
			task.wait(0.25)
			waited += 0.25
		end
	end)
end

return DataSystem
