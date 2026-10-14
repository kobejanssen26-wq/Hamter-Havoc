--[[
	StaffStore: the staff roles and who has them.

	Two sources, merged:
	  1. AdminConfig (the file): owners, CoOwner, the default roles and AdminConfig.Users. The file always wins for the people
	     and roles it names (Owner and CoOwner can ONLY come from the file).
	  2. The DataStore "Staff_v1": roles created or edited in the panel (Roles) and people given a role in the panel (Assign).

	Everything read from the DataStore is sanitised (names, levels, permission ids, limits), so a damaged or hand-edited
	record can never give anybody more than the permission catalogue allows. AdminConfig.IgnoreSavedRoles = true skips the saved
	data completely (recovery). Identity is the UserId only.

	This module only stores and validates; WHO may change what is decided in AdminSystem.
]]

local DataStoreService = game:GetService("DataStoreService")

local AdminConfig = require(script.Parent.Parent.Config.AdminConfig)

local StaffStore = {}

local STORE_NAME = "HamsterPlazaStaff_v1"
local KEY = "Staff"
local REFRESH_SECONDS = 90 -- other servers' changes arrive within this time (one read per refresh)
local PROTECTED = { Owner = true, CoOwner = true }
local LIMIT_CAPS = { MaxCash = 1e12, MaxDiamonds = 1e9, MaxRebirths = 25, MaxBanMinutes = 365 * 24 * 60 }
local MAX_ROLES = 30
local MAX_ASSIGNED = 300

type RoleDef = { Name: string, Level: number, Permissions: { string }, Limits: { [string]: number }, Custom: boolean?, Overridden: boolean? }

local known: { [string]: boolean } = {}
for _, entry in AdminConfig.PermissionCatalog do
	known[entry.Id] = true
end

local stored: { Roles: { [string]: any }, Assign: { [string]: any } } = { Roles = {}, Assign = {} }
local dataStore: any = nil
StaffStore.lastSaveOk = true

local function getStore(): any
	if dataStore == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		dataStore = if ok then result else false
	end
	return dataStore or nil
end

---------------------------------------------------------------------------
-- validation
---------------------------------------------------------------------------

function StaffStore.validName(name: any): (boolean, string?)
	if type(name) ~= "string" then
		return false, "Role name must be text"
	end
	if #name < 2 or #name > 24 or string.find(name, "^[%w][%w ]*[%w]$") == nil then
		return false, "Role name: 2-24 letters, digits or spaces"
	end
	if PROTECTED[name] or string.lower(name) == "owner" or string.lower(name) == "coowner" or string.lower(name) == "none" then
		return false, "That name is reserved"
	end
	return true, nil
end

-- A clean copy of a role definition, or nil when it is unusable. Never returns "*" or an unknown permission.
function StaffStore.sanitize(name: any, raw: any): RoleDef?
	if type(raw) ~= "table" or not StaffStore.validName(name) then
		return nil
	end
	local level = raw.Level
	if type(level) ~= "number" or level ~= level then
		return nil
	end
	level = math.clamp(math.floor(level * 10 + 0.5) / 10, 0.5, AdminConfig.MaxCustomLevel)
	local permissions, seen = {}, {}
	if type(raw.Permissions) == "table" then
		for _, id in raw.Permissions do
			if type(id) == "string" and known[id] and not seen[id] then
				seen[id] = true
				table.insert(permissions, id)
			end
		end
	end
	-- every working role can at least open the panel
	if not seen.Panel and #permissions > 0 then
		table.insert(permissions, 1, "Panel")
	end
	local limits = {}
	for key, cap in LIMIT_CAPS do
		local value = if type(raw.Limits) == "table" then raw.Limits[key] else nil
		limits[key] = if type(value) == "number" and value == value then math.clamp(value, 0, cap) else 0
	end
	return { Name = name, Level = level, Permissions = permissions, Limits = limits }
end

---------------------------------------------------------------------------
-- reading the merged view
---------------------------------------------------------------------------

function StaffStore.permissionKnown(id: string): boolean
	return known[id] == true
end

function StaffStore.isProtected(name: string): boolean
	return PROTECTED[name] == true
end

-- The role definition for a name (file default, or the saved version of it, or a custom role).
function StaffStore.def(name: any): RoleDef?
	if type(name) ~= "string" then
		return nil
	end
	if not AdminConfig.IgnoreSavedRoles and not PROTECTED[name] then
		local saved = stored.Roles[name]
		if saved then
			local clean = StaffStore.sanitize(name, saved)
			if clean then
				clean.Custom = AdminConfig.Roles[name] == nil
				clean.Overridden = AdminConfig.Roles[name] ~= nil
				return clean
			end
		end
	end
	local fileDef = AdminConfig.Roles[name]
	if fileDef then
		return { Name = name, Level = fileDef.Level, Permissions = fileDef.Permissions, Limits = fileDef.Limits or {}, Custom = false, Overridden = false }
	end
	return nil
end

-- All role names, strongest first.
function StaffStore.names(): { string }
	local seen, list = {}, {}
	local function add(name: string)
		if not seen[name] and StaffStore.def(name) then
			seen[name] = true
			table.insert(list, name)
		end
	end
	for name in AdminConfig.Roles do
		add(name)
	end
	if not AdminConfig.IgnoreSavedRoles then
		for name in stored.Roles do
			add(name)
		end
	end
	table.sort(list, function(a, b)
		local la, lb = (StaffStore.def(a) :: any).Level, (StaffStore.def(b) :: any).Level
		if la ~= lb then
			return la > lb
		end
		return a < b
	end)
	return list
end

-- The role a person was given in the FILE (Users) or in the panel (saved). The file wins.
function StaffStore.assignment(userId: number): string?
	local fileRole = AdminConfig.Users[userId]
	if type(fileRole) == "string" and fileRole ~= "Owner" and AdminConfig.Roles[fileRole] then
		return fileRole
	end
	if AdminConfig.IgnoreSavedRoles then
		return nil
	end
	local entry = stored.Assign[tostring(userId)]
	local role = if type(entry) == "table" then entry.Role else nil
	if type(role) == "string" and not PROTECTED[role] and StaffStore.def(role) then
		return role
	end
	return nil
end

function StaffStore.isFileAssigned(userId: number): boolean
	return AdminConfig.Users[userId] ~= nil
end

-- Everybody holding a role: { { UserId, Name?, Source = "file" | "panel" } }
function StaffStore.members(roleName: string): { any }
	local list = {}
	for id, role in AdminConfig.Users do
		if role == roleName then
			table.insert(list, { UserId = id, Name = nil, Source = "file" })
		end
	end
	if roleName ~= "Owner" and not AdminConfig.IgnoreSavedRoles then
		for key, entry in stored.Assign do
			local id = tonumber(key)
			if id and type(entry) == "table" and entry.Role == roleName and AdminConfig.Users[id] == nil then
				table.insert(list, { UserId = id, Name = if type(entry.Name) == "string" then entry.Name else nil, Source = "panel" })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.UserId < b.UserId
	end)
	return list
end

---------------------------------------------------------------------------
-- persistence
---------------------------------------------------------------------------

local function cleanStored(raw: any): any
	local result = { Roles = {}, Assign = {} }
	if type(raw) ~= "table" then
		return result
	end
	local roleCount = 0
	if type(raw.Roles) == "table" then
		for name, def in raw.Roles do
			local clean = StaffStore.sanitize(name, def)
			if clean and roleCount < MAX_ROLES then
				roleCount += 1
				result.Roles[name] = { Level = clean.Level, Permissions = clean.Permissions, Limits = clean.Limits }
			end
		end
	end
	local assigned = 0
	if type(raw.Assign) == "table" then
		for key, entry in raw.Assign do
			local id = tonumber(key)
			if id and id > 0 and type(entry) == "table" and type(entry.Role) == "string" and assigned < MAX_ASSIGNED then
				assigned += 1
				result.Assign[tostring(id)] = { Role = entry.Role, Name = if type(entry.Name) == "string" then string.sub(entry.Name, 1, 40) else nil }
			end
		end
	end
	return result
end

function StaffStore.reload(): boolean
	local source = getStore()
	if not source then
		return false
	end
	local ok, value = pcall(function()
		return source:GetAsync(KEY)
	end)
	if not ok then
		warn("[Staff] could not read the saved roles: " .. tostring(value))
		return false
	end
	stored = cleanStored(value)
	return true
end

-- Applies `change(data)` to the SAVED data atomically (UpdateAsync, so two servers never overwrite each other) and keeps
-- the result as the cache. Returns saved (false = DataStore unavailable: the change lives in this server only).
local function commit(change: (any) -> ()): boolean
	local source = getStore()
	if source then
		local ok, result = pcall(function()
			return source:UpdateAsync(KEY, function(old)
				local data = cleanStored(old)
				change(data)
				return data
			end)
		end)
		if ok and type(result) == "table" then
			stored = cleanStored(result)
			StaffStore.lastSaveOk = true
			return true
		end
		warn("[Staff] saving failed: " .. tostring(result))
	end
	StaffStore.lastSaveOk = false
	change(stored) -- keep it in memory so the panel stays consistent until the next reload
	return false
end

function StaffStore.saveRole(oldName: string?, name: string, def: RoleDef): boolean
	return commit(function(data)
		if oldName and oldName ~= name then
			data.Roles[oldName] = nil
			for _, entry in data.Assign do
				if entry.Role == oldName then
					entry.Role = name
				end
			end
		end
		data.Roles[name] = { Level = def.Level, Permissions = def.Permissions, Limits = def.Limits }
	end)
end

function StaffStore.deleteRole(name: string): boolean
	return commit(function(data)
		data.Roles[name] = nil
		for key, entry in data.Assign do
			if entry.Role == name then
				data.Assign[key] = nil
			end
		end
	end)
end

function StaffStore.assign(userId: number, role: string?, displayName: string?): boolean
	return commit(function(data)
		if role then
			data.Assign[tostring(userId)] = { Role = role, Name = displayName }
		else
			data.Assign[tostring(userId)] = nil
		end
	end)
end

function StaffStore.start()
	task.spawn(function()
		StaffStore.reload()
		while true do
			task.wait(REFRESH_SECONDS)
			StaffStore.reload()
		end
	end)
end

return StaffStore
