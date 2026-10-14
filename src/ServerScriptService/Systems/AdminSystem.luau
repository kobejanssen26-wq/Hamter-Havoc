--[[
	AdminSystem: the server side of the secret admin panel, and ALL of its rules.

	Who:    AdminConfig (server only): OwnerUserIds, Users[UserId] = role, CreatorIsOwner. Names never count, only UserIds.
	Door:   ONE RemoteFunction ("Admin"). The panel is opened by a key / the /admin chat command, but those only ASK:
	        Admin:InvokeServer("open") answers nothing at all to a normal player (no list of commands, no role names), and every
	        later call is checked again. Hiding the panel is cosmetic - the permission check below is the lock.
	What:   a fixed list of commands (Commands below), each with a permission and typed, range-checked parameters.
	        There is no "run this Lua" command and none can be added from the client.
	Safety: rank rule (you can not act on someone of an equal or higher role), per-role limits, confirmation for dangerous
	        actions (enforced here, not only in the UI), an audit log of every privileged action (name, UserId, action, target,
	        reason, time), and a ban list that is checked when somebody joins.

	Add a command: add one entry to Commands (permission, params, handler). The panel builds its form from that description.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage.Modules
local GameConfig = require(Modules.GameConfig)
local HamsterDatabase = require(Modules.HamsterDatabase)
local ItemRegistry = require(Modules.ItemRegistry)
local ShopConfig = require(Modules.ShopConfig)

local Remotes = require(ReplicatedStorage.Remotes)

local AdminConfig = require(script.Parent.Parent.Config.AdminConfig)
local CollectionSystem = require(script.Parent.CollectionSystem)
local ConfigStore = require(script.Parent.ConfigStore)
local DataSystem = require(script.Parent.DataSystem)
local EconomySystem = require(script.Parent.EconomySystem)
local Events = require(script.Parent.Events)
local GearSystem = require(script.Parent.GearSystem)
local Notifier = require(script.Parent.Notifier)
local PlayerState = require(script.Parent.PlayerState)
local ReplicationSystem = require(script.Parent.ReplicationSystem)

local AdminSystem = {}

local STORE_NAME = "HamsterPlazaModeration_v1"
local MAX_HISTORY = 40
local MAX_LOG = 300
local MAX_REASON = 120
local startedAt = os.time()

---------------------------------------------------------------------------
-- roles
---------------------------------------------------------------------------

local function ownerSet(): { [number]: boolean }
	local set = {}
	for _, id in AdminConfig.OwnerUserIds do
		if type(id) == "number" and id > 0 then
			set[id] = true
		end
	end
	return set
end

-- Is this the person who owns the experience (a user-owned experience)?
local function isCreator(userId: number): boolean
	if not AdminConfig.CreatorIsOwner then
		return false
	end
	local success, result = pcall(function()
		return game.CreatorType == Enum.CreatorType.User and game.CreatorId == userId
	end)
	return success and result == true
end

-- Staff made in the panel (command setStaff): { [userId] = role }. Loaded from the DataStore at start; AdminConfig.Users always wins.
local grantedRoles: { [number]: string? } = {}
local STAFF_KEY = "StaffRoles"
local GRANTABLE = { Admin = true, Moderator = true, Developer = true } -- Owner / CoOwner can only be set in AdminConfig

local function configuredRole(id: number): string?
	local role = AdminConfig.Users[id]
	if type(role) == "string" and AdminConfig.Roles[role] and role ~= "Owner" then
		return role
	end
	local granted = grantedRoles[id]
	if granted and AdminConfig.Roles[granted] and GRANTABLE[granted] then
		return granted
	end
	return nil
end

-- The role of a player: "Owner" | "Admin" | "Moderator" | "Developer" | nil. Decided from UserId only.
function AdminSystem.roleOf(player: Player): string?
	local isPlayer, result = pcall(function()
		return player:IsA("Player")
	end)
	if not isPlayer or result ~= true then
		return nil
	end
	local id = player.UserId
	if type(id) ~= "number" or id <= 0 then
		return nil -- Studio "Play Solo" fake players have negative ids
	end
	if ownerSet()[id] then
		return "Owner"
	end
	local role = configuredRole(id)
	if role then
		return role -- (an explicit entry wins over the creator rule below)
	end
	if isCreator(id) then
		return "Owner"
	end
	return nil
end

local function roleDef(role: string?): any?
	return if role then AdminConfig.Roles[role] else nil
end

function AdminSystem.can(player: Player, permission: string): boolean
	local def = roleDef(AdminSystem.roleOf(player))
	if not def then
		return false
	end
	return table.find(def.Permissions, "*") ~= nil or table.find(def.Permissions, permission) ~= nil
end

local function levelOf(userId: number): number
	-- level of somebody who may be offline: only owners and configured staff count
	if ownerSet()[userId] then
		return AdminConfig.Roles.Owner.Level
	end
	local def = roleDef(configuredRole(userId))
	if def then
		return def.Level
	end
	return if isCreator(userId) then AdminConfig.Roles.Owner.Level else 0
end

local function limit(player: Player, name: string): number
	local def = roleDef(AdminSystem.roleOf(player))
	return if def and def.Limits and def.Limits[name] then def.Limits[name] else 0
end

---------------------------------------------------------------------------
-- storage: bans, history, audit log
---------------------------------------------------------------------------

local store: any = nil
local function getStore(): any
	if store == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		store = if ok then result else false
	end
	return store or nil
end

local bans: { [number]: any } = {} -- cache of loaded bans
local histories: { [number]: { any } } = {}
local auditLog: { any } = {} -- newest last

local function read(key: string): any
	local source = getStore()
	if not source then
		return nil
	end
	local ok, result = pcall(function()
		return source:GetAsync(key)
	end)
	return if ok then result else nil
end

local function write(key: string, value: any): boolean
	local source = getStore()
	if not source then
		return false
	end
	local ok = pcall(function()
		source:SetAsync(key, value)
	end)
	return ok
end

local function clean(text: any): string
	if type(text) ~= "string" then
		return ""
	end
	return string.sub((string.gsub(text, "[%c]", " ")), 1, MAX_REASON)
end

function AdminSystem.history(userId: number): { any }
	local list = histories[userId]
	if not list then
		local saved = read("Hist_" .. userId)
		list = if type(saved) == "table" then saved else {}
		histories[userId] = list
	end
	return list
end

local function addHistory(userId: number, entry: any)
	local list = AdminSystem.history(userId)
	table.insert(list, entry)
	while #list > MAX_HISTORY do
		table.remove(list, 1)
	end
	write("Hist_" .. userId, list)
end

-- Every privileged action ends up here: who, what, on whom, why, when.
local function audit(admin: Player, action: string, target: any, detail: string, reason: string?)
	local entry = {
		At = os.time(),
		AdminId = admin.UserId,
		AdminName = admin.Name,
		Role = AdminSystem.roleOf(admin),
		Action = action,
		TargetId = if type(target) == "number" then target else nil,
		Detail = detail,
		Reason = reason or "",
	}
	table.insert(auditLog, entry)
	while #auditLog > MAX_LOG do
		table.remove(auditLog, 1)
	end
	print(string.format("[Admin] %s (%d, %s) %s %s %s", admin.Name, admin.UserId, tostring(entry.Role), action, detail, if reason and reason ~= "" then "- " .. reason else ""))
	-- one log key per day, appended with UpdateAsync so servers never overwrite each other
	local source = getStore()
	if source then
		local day = os.date("!%Y%m%d", entry.At)
		pcall(function()
			source:UpdateAsync("Audit_" .. day, function(old)
				local list = if type(old) == "table" then old else {}
				table.insert(list, entry)
				while #list > MAX_LOG do
					table.remove(list, 1)
				end
				return list
			end)
		end)
	end
end

function AdminSystem.auditLog(): { any }
	return auditLog
end

local function banOf(userId: number): any?
	local ban = bans[userId]
	if ban == nil then
		local saved = read("Ban_" .. userId)
		ban = if type(saved) == "table" then saved else false
		bans[userId] = ban
	end
	if ban and ban.Until and ban.Until > 0 and ban.Until <= os.time() then
		bans[userId] = false
		return nil -- a temporary ban that has run out
	end
	return if ban then ban else nil
end

local function banMessage(ban: any): string
	local text = "You are banned from this experience."
	if ban.Reason and ban.Reason ~= "" then
		text ..= " Reason: " .. ban.Reason .. "."
	end
	if ban.Until and ban.Until > 0 then
		local minutes = math.max(1, math.ceil((ban.Until - os.time()) / 60))
		text ..= string.format(" Ends in %d minute(s).", minutes)
	else
		text ..= " This ban is permanent."
	end
	return text
end

-- Called when a player joins (before their data is loaded). Kicks banned players.
function AdminSystem.checkJoin(player: Player): boolean
	local ban = banOf(player.UserId)
	if ban then
		pcall(function()
			player:Kick(banMessage(ban))
		end)
		return false
	end
	return true
end

---------------------------------------------------------------------------
-- parameter validation
---------------------------------------------------------------------------

type Param = { Name: string, Type: string, Label: string?, Min: number?, Max: number?, Optional: boolean?, Options: { string }? }

local function onlinePlayer(userId: any): Player?
	if type(userId) ~= "number" or userId ~= userId then
		return nil
	end
	return Players:GetPlayerByUserId(userId)
end

-- Returns (ok, value | message)
local function checkParam(param: Param, raw: any): (boolean, any)
	if raw == nil then
		if param.Optional then
			return true, nil
		end
		return false, (param.Label or param.Name) .. " is required"
	end
	local kind = param.Type
	if kind == "player" then
		local target = onlinePlayer(raw)
		if not target then
			return false, "that player is not in this server"
		end
		return true, target
	elseif kind == "userid" then
		if type(raw) ~= "number" or raw ~= raw or raw < 1 or raw % 1 ~= 0 or raw > 1e12 then
			return false, "UserId must be a whole number"
		end
		return true, raw
	elseif kind == "text" then
		if type(raw) ~= "string" then
			return false, (param.Label or param.Name) .. " must be text"
		end
		local text = string.sub((string.gsub(raw, "[%c]", " ")), 1, param.Max or MAX_REASON)
		if not param.Optional and #text:gsub("%s", "") == 0 then
			return false, (param.Label or param.Name) .. " is required"
		end
		return true, text
	elseif kind == "int" or kind == "number" then
		if type(raw) ~= "number" or raw ~= raw or raw == math.huge or raw == -math.huge then
			return false, (param.Label or param.Name) .. " must be a number"
		end
		if kind == "int" and raw % 1 ~= 0 then
			return false, (param.Label or param.Name) .. " must be a whole number"
		end
		if (param.Min and raw < param.Min) or (param.Max and raw > param.Max) then
			return false, string.format("%s must be between %s and %s", param.Label or param.Name, tostring(param.Min), tostring(param.Max))
		end
		return true, raw
	elseif kind == "bool" then
		if type(raw) ~= "boolean" then
			return false, (param.Label or param.Name) .. " must be true or false"
		end
		return true, raw
	elseif kind == "item" then
		if type(raw) ~= "string" or not ItemRegistry.get(raw) then
			return false, "unknown item"
		end
		return true, raw
	elseif kind == "hamster" then
		-- accepts the species id ("skyfather") or its display name ("Divine Empress"), any capitalisation
		if type(raw) ~= "string" then
			return false, "unknown hamster"
		end
		local wanted = string.lower((string.gsub(raw, "^%s*(.-)%s*$", "%1")))
		local wantedId = string.gsub(wanted, "%s+", "_")
		for _, species in HamsterDatabase.Species do
			if string.lower(species.Id) == wantedId or string.lower(species.Name) == wanted then
				return true, species.Id
			end
		end
		return false, "unknown hamster (use its id or its name, for example Divine Empress)"
	elseif kind == "shopitem" then
		if type(raw) ~= "string" or not ShopConfig.ById[raw] then
			return false, "unknown shop item"
		end
		return true, raw
	elseif kind == "setting" then
		-- "Section.Key"
		if type(raw) ~= "string" then
			return false, "unknown setting"
		end
		local section, key = string.match(raw, "^(%w+)%.(%w+)$")
		if not section or not GameConfig.Schema[section] or not GameConfig.Schema[section][key] then
			return false, "unknown setting"
		end
		return true, { Section = section, Key = key }
	elseif kind == "any" then
		if type(raw) == "number" or type(raw) == "boolean" then
			return true, raw
		end
		return false, "value must be a number or true/false"
	end
	return false, "unsupported parameter"
end

---------------------------------------------------------------------------
-- commands
---------------------------------------------------------------------------

type Context = { Admin: Player, Params: { [string]: any }, Confirmed: boolean }
type Result = { ok: boolean, msg: string, data: any? }

local function ok(message: string, data: any?): Result
	return { ok = true, msg = message, data = data }
end
local function fail(message: string): Result
	return { ok = false, msg = message }
end

-- You can only act on somebody whose role is LOWER than yours (the Owner can act on anybody but themselves for kicks / bans).
local function mayActOn(admin: Player, targetUserId: number): (boolean, string?)
	if targetUserId == admin.UserId then
		return false, "You can not do this to yourself"
	end
	local mine = roleDef(AdminSystem.roleOf(admin))
	local theirs = levelOf(targetUserId)
	if mine and theirs >= mine.Level then
		return false, "That person has an equal or higher staff role"
	end
	return true, nil
end

local function profile(target: Player): any
	return DataSystem.get(target)
end

local Commands: { [string]: any } = {}
local commandOrder: { string } = {}

local function define(name: string, spec: any)
	spec.Name = name
	Commands[name] = spec
	table.insert(commandOrder, name)
end

-- ---- moderation ---------------------------------------------------------
define("warn", {
	Category = "Moderation", Label = "Warn player", Permission = "Warn",
	Params = { { Name = "target", Type = "player", Label = "Player" }, { Name = "reason", Type = "text", Label = "Reason" } },
	Run = function(c: Context): Result
		local target = c.Params.target :: Player
		local allowed, why = mayActOn(c.Admin, target.UserId)
		if not allowed then return fail(why :: string) end
		addHistory(target.UserId, { At = os.time(), Action = "Warn", By = c.Admin.UserId, ByName = c.Admin.Name, Reason = c.Params.reason })
		Notifier.send(target, "Warning from staff: " .. c.Params.reason, "error")
		audit(c.Admin, "warn", target.UserId, target.Name, c.Params.reason)
		return ok("Warned " .. target.Name)
	end,
})

define("kick", {
	Category = "Moderation", Label = "Kick player", Permission = "Kick", Confirm = true,
	Params = { { Name = "target", Type = "player", Label = "Player" }, { Name = "reason", Type = "text", Label = "Reason" } },
	Run = function(c: Context): Result
		local target = c.Params.target :: Player
		local allowed, why = mayActOn(c.Admin, target.UserId)
		if not allowed then return fail(why :: string) end
		addHistory(target.UserId, { At = os.time(), Action = "Kick", By = c.Admin.UserId, ByName = c.Admin.Name, Reason = c.Params.reason })
		audit(c.Admin, "kick", target.UserId, target.Name, c.Params.reason)
		local name = target.Name
		pcall(function()
			target:Kick("Kicked by staff. Reason: " .. c.Params.reason)
		end)
		return ok("Kicked " .. name)
	end,
})

define("ban", {
	Category = "Moderation", Label = "Ban player (0 minutes = permanent)", Permission = "BanTemp", Confirm = true,
	Params = {
		{ Name = "userId", Type = "userid", Label = "UserId" },
		{ Name = "minutes", Type = "int", Label = "Minutes (0 = permanent)", Min = 0, Max = 525600 },
		{ Name = "reason", Type = "text", Label = "Reason" },
	},
	Run = function(c: Context): Result
		local userId = c.Params.userId :: number
		local minutes = c.Params.minutes :: number
		local allowed, why = mayActOn(c.Admin, userId)
		if not allowed then return fail(why :: string) end
		if minutes == 0 and not AdminSystem.can(c.Admin, "BanPerm") then
			return fail("Only higher staff roles can ban permanently")
		end
		if minutes > limit(c.Admin, "MaxBanMinutes") then
			return fail(string.format("Your role may ban for at most %d minutes", limit(c.Admin, "MaxBanMinutes")))
		end
		local ban = { At = os.time(), Until = if minutes == 0 then 0 else os.time() + minutes * 60, Reason = c.Params.reason, By = c.Admin.UserId, ByName = c.Admin.Name }
		if not write("Ban_" .. userId, ban) then
			return fail("The ban could not be saved (DataStore unavailable) - nothing was changed")
		end
		bans[userId] = ban
		addHistory(userId, { At = os.time(), Action = if minutes == 0 then "Ban (permanent)" else string.format("Ban (%d min)", minutes), By = c.Admin.UserId, ByName = c.Admin.Name, Reason = c.Params.reason })
		audit(c.Admin, "ban", userId, if minutes == 0 then "permanent" else minutes .. " min", c.Params.reason)
		local online = Players:GetPlayerByUserId(userId)
		if online then
			pcall(function()
				online:Kick(banMessage(ban))
			end)
		end
		return ok(string.format("Banned %d (%s)", userId, if minutes == 0 then "permanent" else minutes .. " min"))
	end,
})

define("unban", {
	Category = "Moderation", Label = "Unban player", Permission = "Unban", Confirm = true,
	Params = { { Name = "userId", Type = "userid", Label = "UserId" }, { Name = "reason", Type = "text", Label = "Reason" } },
	Run = function(c: Context): Result
		local userId = c.Params.userId :: number
		if not banOf(userId) then
			return fail("That player is not banned")
		end
		if not write("Ban_" .. userId, false) then
			return fail("The unban could not be saved (DataStore unavailable)")
		end
		bans[userId] = false
		addHistory(userId, { At = os.time(), Action = "Unban", By = c.Admin.UserId, ByName = c.Admin.Name, Reason = c.Params.reason })
		audit(c.Admin, "unban", userId, tostring(userId), c.Params.reason)
		return ok("Unbanned " .. userId)
	end,
})

define("history", {
	Category = "Moderation", Label = "Moderation history", Permission = "History",
	Params = { { Name = "userId", Type = "userid", Label = "UserId" } },
	Run = function(c: Context): Result
		local list = AdminSystem.history(c.Params.userId)
		local lines = {}
		for i = #list, math.max(1, #list - 14), -1 do
			local e = list[i]
			table.insert(lines, string.format("%s  %s by %s: %s", os.date("!%Y-%m-%d %H:%M", e.At), tostring(e.Action), tostring(e.ByName), tostring(e.Reason)))
		end
		local ban = banOf(c.Params.userId)
		if ban then
			table.insert(lines, 1, "CURRENTLY BANNED: " .. banMessage(ban))
		end
		return ok(if #lines == 0 then "No entries" else table.concat(lines, "\n"))
	end,
})

-- ---- economy / progression ------------------------------------------------
local function needsMoneyConfirm(amount: number): boolean
	return amount < 0 or math.abs(amount) >= AdminConfig.ConfirmCashAbove
end

define("giveCash", {
	Category = "Economy", Label = "Give / remove cash", Permission = "Cash",
	Confirm = function(params: any) return needsMoneyConfirm(params.amount) end,
	Params = { { Name = "target", Type = "player", Label = "Player" }, { Name = "amount", Type = "int", Label = "Amount (negative removes)", Min = -1e12, Max = 1e12 }, { Name = "reason", Type = "text", Label = "Reason", Optional = true } },
	Run = function(c: Context): Result
		local target, amount = c.Params.target :: Player, c.Params.amount :: number
		local data = profile(target)
		if not data then return fail("Player data is not loaded") end
		if amount == 0 or math.abs(amount) > limit(c.Admin, "MaxCash") then
			return fail(string.format("Amount must be between 1 and %s for your role", tostring(limit(c.Admin, "MaxCash"))))
		end
		if amount > 0 then
			EconomySystem.addCoins(target, amount, false)
		else
			EconomySystem.setCoins(target, math.max(0, data.Coins + amount))
		end
		audit(c.Admin, "cash", target.UserId, string.format("%s %+d (now %d)", target.Name, amount, data.Coins), c.Params.reason)
		return ok(string.format("%s now has %d cash", target.Name, math.floor(data.Coins)))
	end,
})

define("giveDiamonds", {
	Category = "Economy", Label = "Give / remove diamonds", Permission = "Diamonds",
	Confirm = function(params: any) return needsMoneyConfirm(params.amount) end,
	Params = { { Name = "target", Type = "player", Label = "Player" }, { Name = "amount", Type = "int", Label = "Amount (negative removes)", Min = -1e9, Max = 1e9 }, { Name = "reason", Type = "text", Label = "Reason", Optional = true } },
	Run = function(c: Context): Result
		local target, amount = c.Params.target :: Player, c.Params.amount :: number
		local data = profile(target)
		if not data then return fail("Player data is not loaded") end
		if amount == 0 or math.abs(amount) > limit(c.Admin, "MaxDiamonds") then
			return fail(string.format("Amount must be between 1 and %s for your role", tostring(limit(c.Admin, "MaxDiamonds"))))
		end
		if amount > 0 then
			EconomySystem.addGems(target, amount, false)
		else
			data.Gems = math.max(0, data.Gems + amount)
			DataSystem.markDirty(target)
			EconomySystem.updateAttributes(target)
		end
		audit(c.Admin, "diamonds", target.UserId, string.format("%s %+d (now %d)", target.Name, amount, data.Gems), c.Params.reason)
		return ok(string.format("%s now has %d diamonds", target.Name, math.floor(data.Gems)))
	end,
})

define("setRebirths", {
	Category = "Economy", Label = "Set rebirth count", Permission = "Rebirth", Confirm = true,
	Params = { { Name = "target", Type = "player", Label = "Player" }, { Name = "count", Type = "int", Label = "Rebirths", Min = 0, Max = 25 }, { Name = "reason", Type = "text", Label = "Reason", Optional = true } },
	Run = function(c: Context): Result
		local target, count = c.Params.target :: Player, c.Params.count :: number
		local data = profile(target)
		if not data then return fail("Player data is not loaded") end
		if count > limit(c.Admin, "MaxRebirths") then return fail("Above your limit") end
		-- only sets the level (what it unlocks follows from it); no rebirth rewards are handed out
		data.Rebirths = count
		DataSystem.markDirty(target)
		EconomySystem.updateAttributes(target)
		ReplicationSystem.mark(target, "Rebirths")
		Events.EquippedChanged:Fire(target)
		-- the same notification a real rebirth sends: the tower grows (floors, trim, stations), slots and the gate follow
		Events.Rebirthed:Fire(target, count)
		audit(c.Admin, "rebirths", target.UserId, string.format("%s -> %d", target.Name, count), c.Params.reason)
		return ok(string.format("%s is now rebirth %d", target.Name, count))
	end,
})

define("grantItem", {
	Category = "Economy", Label = "Give item (weapon / gear / boost)", Permission = "Items",
	Params = { { Name = "target", Type = "player", Label = "Player" }, { Name = "item", Type = "item", Label = "Item id" }, { Name = "reason", Type = "text", Label = "Reason", Optional = true } },
	Run = function(c: Context): Result
		local target, itemId = c.Params.target :: Player, c.Params.item :: string
		local success, message = GearSystem.grant(target, itemId)
		if not success then return fail(message) end
		audit(c.Admin, "grantItem", target.UserId, target.Name .. " <- " .. itemId, c.Params.reason)
		return ok(string.format("Gave %s to %s", itemId, target.Name))
	end,
})

define("setStaff", {
	Category = "Staff", Label = "Make / remove staff (by UserId)", Permission = "Staff", Confirm = true,
	Params = {
		{ Name = "userId", Type = "userid", Label = "UserId of the person" },
		{ Name = "role", Type = "text", Label = "Role: Admin, Moderator, Developer, or None to remove", Max = 20 },
		{ Name = "reason", Type = "text", Label = "Reason", Optional = true },
	},
	Run = function(c: Context): Result
		local userId = c.Params.userId :: number
		local typed = string.lower((string.gsub(c.Params.role :: string, "%s", "")))
		local named = string.upper(string.sub(typed, 1, 1)) .. string.sub(typed, 2)
		local role: string? = named
		if named == "None" then
			role = nil
		elseif not GRANTABLE[named] then
			return fail("Role must be Admin, Moderator, Developer or None (Owner and CoOwner are set in AdminConfig)")
		end
		local allowed, why = mayActOn(c.Admin, userId)
		if not allowed then return fail(why or "Not allowed") end
		local mine = roleDef(AdminSystem.roleOf(c.Admin))
		if role and mine and AdminConfig.Roles[named].Level >= mine.Level then
			return fail("You can only give roles below your own")
		end
		if AdminConfig.Users[userId] ~= nil then
			return fail("That person is set in AdminConfig.Users: change them there (the file always wins)")
		end
		grantedRoles[userId] = role
		-- save just this one entry so servers never overwrite each other's changes
		local saved = false
		local source = getStore()
		if source then
			saved = pcall(function()
				source:UpdateAsync(STAFF_KEY, function(old)
					local map = if type(old) == "table" then old else {}
					map[tostring(userId)] = role
					return map
				end)
			end)
		end
		audit(c.Admin, "setStaff", userId, string.format("%d -> %s", userId, role or "none"), c.Params.reason)
		return ok(string.format("%d is now %s%s", userId, role or "no staff", if saved then "" else " (NOT saved: enable Studio API access / DataStore)"))
	end,
})

define("giveHamster", {
	Category = "Economy", Label = "Give hamster", Permission = "Items",
	Params = { { Name = "target", Type = "player", Label = "Player" }, { Name = "hamster", Type = "hamster", Label = "Hamster (id or name)" }, { Name = "amount", Type = "int", Label = "How many", Min = 1, Max = 10 }, { Name = "reason", Type = "text", Label = "Reason", Optional = true } },
	Run = function(c: Context): Result
		local target, speciesId, amount = c.Params.target :: Player, c.Params.hamster :: string, c.Params.amount :: number
		if not profile(target) then return fail("Player data is not loaded") end
		for _ = 1, amount do
			-- source "Reward": never auto-sold by the player's auto-delete setting
			if not CollectionSystem.grant(target, speciesId, "Reward") then return fail("Could not give that hamster") end
		end
		local species = HamsterDatabase.ById[speciesId]
		audit(c.Admin, "giveHamster", target.UserId, string.format("%s <- %dx %s", target.Name, amount, speciesId), c.Params.reason)
		return ok(string.format("Gave %dx %s (%s) to %s", amount, species.Name, species.Rarity, target.Name))
	end,
})

define("revokeItem", {
	Category = "Economy", Label = "Remove owned weapon / gear", Permission = "Items", Confirm = true,
	Params = { { Name = "target", Type = "player", Label = "Player" }, { Name = "item", Type = "item", Label = "Item id" }, { Name = "reason", Type = "text", Label = "Reason", Optional = true } },
	Run = function(c: Context): Result
		local target, itemId = c.Params.target :: Player, c.Params.item :: string
		local data = profile(target)
		if not data then return fail("Player data is not loaded") end
		local def = ItemRegistry.get(itemId)
		if not def or def.Equip.Kind == "Consume" then return fail("Only owned weapons / equipment can be removed here") end
		if not data.Gear[itemId] then return fail("They do not own that") end
		data.Gear[itemId] = nil
		GearSystem.clean(data)
		GearSystem.giveTools(target)
		ReplicationSystem.mark(target, "Gear", "Hotbar")
		DataSystem.markDirty(target)
		audit(c.Admin, "revokeItem", target.UserId, target.Name .. " -> " .. itemId, c.Params.reason)
		return ok(string.format("Removed %s from %s", itemId, target.Name))
	end,
})

define("inspect", {
	Category = "Economy", Label = "Inspect progress", Permission = "Inspect",
	Params = { { Name = "target", Type = "player", Label = "Player" } },
	Run = function(c: Context): Result
		local target = c.Params.target :: Player
		local data = profile(target)
		if not data then return fail("Player data is not loaded") end
		local hamsters, kinds = 0, 0
		for _, count in data.Inventory do
			hamsters += count
			kinds += 1
		end
		local gear = {}
		for id, owned in data.Gear do if owned then table.insert(gear, id) end end
		table.sort(gear)
		return ok(string.format("%s (%d)\nCash %d  Diamonds %d  Rebirths %d\nHamsters %d (%d kinds), on the bench %d\nGear: %s\nSlaps %d  Account age %d days",
			target.Name, target.UserId, math.floor(data.Coins), math.floor(data.Gems), data.Rebirths, hamsters, kinds, #data.Equipped,
			if #gear == 0 then "none" else table.concat(gear, ", "), data.Stats.Slaps or 0, target.AccountAge))
	end,
})

-- ---- game -----------------------------------------------------------------
define("announce", {
	Category = "Game", Label = "Announce to everyone", Permission = "Announce", Confirm = true,
	Params = { { Name = "text", Type = "text", Label = "Message", Max = 120 } },
	Run = function(c: Context): Result
		Remotes.event("Announce"):FireAllClients({ Kind = "Staff", Text = c.Params.text, RarityId = "Basic", UserId = 0, PlayerName = "" })
		audit(c.Admin, "announce", nil, c.Params.text)
		return ok("Announced")
	end,
})

define("serverInfo", {
	Category = "Game", Label = "Server info", Permission = "ServerInfo", Params = {},
	Run = function(): Result
		local changed = 0
		for _ in ConfigStore.changed() do changed += 1 end
		return ok(string.format("Players %d / %d\nServer uptime %d s\nSettings changed from default: %d\nStudio: %s", #Players:GetPlayers(), Players.MaxPlayers, os.time() - startedAt, changed, tostring(RunService:IsStudio())))
	end,
})

define("clearStatus", {
	Category = "Game", Label = "Clear stun / freeze (safe test tool)", Permission = "SafeTools",
	Params = { { Name = "target", Type = "player", Label = "Player" } },
	Run = function(c: Context): Result
		local target = c.Params.target :: Player
		PlayerState.clear(target)
		PlayerState.grantImmunity(target, 0.5)
		audit(c.Admin, "clearStatus", target.UserId, target.Name)
		return ok("Cleared status of " .. target.Name)
	end,
})

-- ---- settings (GameConfig + shop) -----------------------------------------
define("setSetting", {
	Category = "Settings", Label = "Change a setting (live)", Permission = "Settings",
	Confirm = function(_params: any) return false end,
	Params = { { Name = "setting", Type = "setting", Label = "Setting" }, { Name = "value", Type = "any", Label = "Value" }, { Name = "reason", Type = "text", Label = "Reason", Optional = true } },
	Run = function(c: Context): Result
		local s = c.Params.setting
		local success, message = ConfigStore.setSetting(s.Section, s.Key, c.Params.value)
		if not success then return fail(message) end
		audit(c.Admin, "setSetting", nil, message, c.Params.reason)
		return ok("Saved " .. message)
	end,
})

define("resetSetting", {
	Category = "Settings", Label = "Reset a setting to its default", Permission = "Settings",
	Params = { { Name = "setting", Type = "setting", Label = "Setting" } },
	Run = function(c: Context): Result
		local s = c.Params.setting
		local success, message = ConfigStore.resetSetting(s.Section, s.Key)
		if not success then return fail(message) end
		audit(c.Admin, "resetSetting", nil, message)
		return ok(message)
	end,
})

define("setShopItem", {
	Category = "Settings", Label = "Shop price / availability", Permission = "Settings", Confirm = true,
	Params = {
		{ Name = "item", Type = "shopitem", Label = "Shop item id (e.g. gear_slap_glove)" },
		{ Name = "price", Type = "number", Label = "New price (blank = keep)", Min = 1, Max = 1e12, Optional = true },
		{ Name = "disabled", Type = "bool", Label = "Disabled (true hides it)", Optional = true },
	},
	Run = function(c: Context): Result
		local success, message = ConfigStore.setShop(c.Params.item, c.Params.price, c.Params.disabled)
		if not success then return fail(message) end
		audit(c.Admin, "setShopItem", nil, c.Params.item .. ": " .. message)
		return ok(message)
	end,
})

define("resetShopItem", {
	Category = "Settings", Label = "Reset shop item to its file values", Permission = "Settings",
	Params = { { Name = "item", Type = "shopitem", Label = "Shop item id" } },
	Run = function(c: Context): Result
		local success, message = ConfigStore.resetShop(c.Params.item)
		if not success then return fail(message) end
		audit(c.Admin, "resetShopItem", nil, c.Params.item)
		return ok(message)
	end,
})

define("auditLog", {
	Category = "Game", Label = "Show admin action log", Permission = "AuditLog", Params = {},
	Run = function(): Result
		local lines = {}
		for i = #auditLog, math.max(1, #auditLog - 24), -1 do
			local e = auditLog[i]
			table.insert(lines, string.format("%s  %s(%d) %s %s %s", os.date("!%H:%M:%S", e.At), tostring(e.AdminName), e.AdminId, e.Action, e.Detail, if e.Reason ~= "" then "- " .. e.Reason else ""))
		end
		return ok(if #lines == 0 then "Nothing logged yet" else table.concat(lines, "\n"))
	end,
})

---------------------------------------------------------------------------
-- running a command
---------------------------------------------------------------------------

local lastRequest: { [Player]: number } = {}
local suspicious: { [Player]: number } = {}

-- Runs a command for `admin` after EVERY check. Returns { ok, msg, needsConfirm? }.
function AdminSystem.execute(admin: Player, name: any, rawParams: any, confirmed: any): any
	local role = AdminSystem.roleOf(admin)
	if not role then
		return { ok = false, msg = "" }
	end
	local spec = if type(name) == "string" then Commands[name] else nil
	if not spec then
		return { ok = false, msg = "Unknown command" }
	end
	if not AdminSystem.can(admin, spec.Permission) then
		audit(admin, "DENIED", nil, spec.Name .. " (needs " .. spec.Permission .. ")")
		return { ok = false, msg = "Your role may not do that" }
	end
	local given = if type(rawParams) == "table" then rawParams else {}
	local params: { [string]: any } = {}
	for _, param in spec.Params do
		local valid, value = checkParam(param, given[param.Name])
		if not valid then
			return { ok = false, msg = tostring(value) }
		end
		params[param.Name] = value
	end
	if params.reason ~= nil then
		params.reason = clean(params.reason)
	end
	local needsConfirm = spec.Confirm
	if type(needsConfirm) == "function" then
		needsConfirm = needsConfirm(params)
	end
	if needsConfirm and confirmed ~= true then
		return { ok = false, needsConfirm = true, msg = "Please confirm: " .. spec.Label }
	end
	local success, result = pcall(spec.Run, { Admin = admin, Params = params, Confirmed = confirmed == true })
	if not success then
		warn("[Admin] command " .. spec.Name .. " errored: " .. tostring(result))
		return { ok = false, msg = "That command failed" }
	end
	return result
end

-- What the panel needs to build itself: only for staff, only the commands their role may run.
local function panelData(admin: Player): any
	local role = AdminSystem.roleOf(admin)
	local commands = {}
	for _, name in commandOrder do
		local spec = Commands[name]
		if AdminSystem.can(admin, spec.Permission) then
			table.insert(commands, { Name = name, Category = spec.Category, Label = spec.Label, Params = spec.Params, Confirm = spec.Confirm ~= nil and spec.Confirm ~= false })
		end
	end
	local list = {}
	for _, other in Players:GetPlayers() do
		table.insert(list, { UserId = other.UserId, Name = other.Name, DisplayName = other.DisplayName, Role = AdminSystem.roleOf(other) })
	end
	local settings = if AdminSystem.can(admin, "Settings") then GameConfig.list() else nil
	local shop = nil
	if AdminSystem.can(admin, "Settings") then
		shop = {}
		for _, item in ShopConfig.Items do
			if item.Currency == "Coins" or item.Currency == "Gems" then
				table.insert(shop, { Id = item.Id, Name = item.Name, Price = item.Price, Currency = item.Currency, Disabled = item.Disabled == true })
			end
		end
	end
	return { Role = role, Commands = commands, Players = list, Settings = settings, Shop = shop }
end

function AdminSystem.handle(player: Player, action: any, a: any, b: any, c: any): any
	local clock = os.clock()
	if (lastRequest[player] or 0) + AdminConfig.MinSecondsBetweenRequests > clock then
		return nil
	end
	lastRequest[player] = clock
	if not AdminSystem.roleOf(player) then
		-- an ordinary player gets NO information, only a (rate limited) note in the server log
		if (suspicious[player] or 0) + 60 < clock then
			suspicious[player] = clock
			warn(string.format("[Admin] %s (%d) tried to use the admin remote without a staff role", player.Name, player.UserId))
		end
		return nil
	end
	if action == "open" then
		return { ok = true, data = panelData(player) }
	elseif action == "run" then
		return AdminSystem.execute(player, a, b, c)
	end
	return { ok = false, msg = "Unknown request" }
end

function AdminSystem.start()
	Remotes.func("Admin").OnServerInvoke = function(player: Player, action: any, a: any, b: any, c: any)
		local success, result = pcall(AdminSystem.handle, player, action, a, b, c)
		if success then
			return result
		end
		warn("[Admin] request failed: " .. tostring(result))
		return nil
	end
	task.spawn(function()
		local map = read(STAFF_KEY)
		if type(map) == "table" then
			for key, role in map do
				local id = tonumber(key)
				if id and type(role) == "string" and GRANTABLE[role] then
					grantedRoles[id] = role
				end
			end
		end
	end)
	if next(ownerSet()) == nil and not AdminConfig.CreatorIsOwner then
		warn("[Admin] no owner is configured: set your Roblox UserId in ServerScriptService/Config/AdminConfig.luau")
	end
end

function AdminSystem.forget(player: Player)
	lastRequest[player] = nil
	suspicious[player] = nil
end

AdminSystem.Commands = Commands

return AdminSystem
