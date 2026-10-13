--[[
	ConfigStore: the saved part of the game settings.

	  GameConfig.luau (Studio)   the defaults, always there
	  ConfigStore (this file)    values an admin changed LIVE in the Admin panel; saved in one DataStore key and re-applied
	                             (after validation) every time a server starts. "Reset" deletes the saved value again.

	Only the admin system writes here, only through these functions, and every value passes GameConfig.validate first.
	Writes are batched: many changes inside a few seconds are one DataStore request, and nothing is written when nothing changed.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local ShopConfig = require(ReplicatedStorage.Modules.ShopConfig)

local ConfigStore = {}

local STORE_NAME = "HamsterPlazaConfig_v1"
local KEY = "Overrides"
local SAVE_DELAY = 3

-- { Settings = { ["Section.Key"] = value }, Shop = { [shopItemId] = { Price = n?, Disabled = b? } } }
local state = { Settings = {} :: { [string]: any }, Shop = {} :: { [string]: any } }
local dirty = false
local saving = false
local store: any = nil
ConfigStore.Loaded = false

local function getStore(): any
	if store == nil then
		local ok, result = pcall(function()
			return DataStoreService:GetDataStore(STORE_NAME)
		end)
		store = if ok then result else false
	end
	return store or nil
end

local function publishShop()
	ShopConfig.applyOverrides(state.Shop)
	local ok, json = pcall(function()
		return HttpService:JSONEncode(state.Shop)
	end)
	if ok then
		ReplicatedStorage:SetAttribute("ShopOverrides", json)
	end
end

-- Reads the saved overrides and applies the valid ones. Never errors: a DataStore outage just means defaults.
function ConfigStore.load()
	local source = getStore()
	local saved = nil
	if source then
		local ok, result = pcall(function()
			return source:GetAsync(KEY)
		end)
		if ok then
			saved = result
		else
			warn("[ConfigStore] could not read saved settings, using the defaults: " .. tostring(result))
		end
	end
	if type(saved) == "table" then
		if type(saved.Settings) == "table" then
			for name, value in saved.Settings do
				local section, key = string.match(tostring(name), "^(%w+)%.(%w+)$")
				if section and key then
					local ok = GameConfig.validate(section, key, value)
					if ok then
						GameConfig.set(section, key, value, false)
						state.Settings[name] = value
					else
						warn(string.format("[ConfigStore] ignored invalid saved value for %s", tostring(name)))
					end
				end
			end
		end
		if type(saved.Shop) == "table" then
			for id, override in saved.Shop do
				if ShopConfig.ById[id] and type(override) == "table" then
					state.Shop[id] = { Price = if type(override.Price) == "number" then override.Price else nil, Disabled = if type(override.Disabled) == "boolean" then override.Disabled else nil }
				end
			end
		end
	end
	publishShop()
	ConfigStore.Loaded = true
end

local function flush()
	if not dirty or saving then
		return
	end
	local source = getStore()
	if not source then
		return
	end
	saving = true
	dirty = false
	local snapshot = { Settings = table.clone(state.Settings), Shop = table.clone(state.Shop) }
	local ok, err = pcall(function()
		source:SetAsync(KEY, snapshot)
	end)
	saving = false
	if not ok then
		dirty = true
		warn("[ConfigStore] save failed, will retry: " .. tostring(err))
	end
end

local function markDirty()
	if dirty then
		return
	end
	dirty = true
	task.delay(SAVE_DELAY, function()
		if dirty then
			flush()
		end
	end)
end

-- Saves immediately (server shutdown, tests).
function ConfigStore.flush()
	dirty = true
	flush()
end

-- Change a live setting. Returns (ok, message).
function ConfigStore.setSetting(section: any, key: any, value: any): (boolean, string)
	local ok, result = GameConfig.validate(section, key, value)
	if not ok then
		return false, tostring(result)
	end
	local setOk, message = GameConfig.set(section, key, value, true)
	if not setOk then
		return false, tostring(message)
	end
	local name = section .. "." .. key
	if value == GameConfig.default(section, key) then
		state.Settings[name] = nil
	else
		state.Settings[name] = value
	end
	markDirty()
	return true, string.format("%s = %s", name, tostring(value))
end

function ConfigStore.resetSetting(section: any, key: any): (boolean, string)
	local ok, message = GameConfig.reset(section, key, true)
	if not ok then
		return false, tostring(message)
	end
	state.Settings[section .. "." .. key] = nil
	markDirty()
	return true, string.format("%s.%s back to the default (%s)", section, key, tostring(GameConfig.default(section, key)))
end

-- Shop price / availability of one shop item (the id as listed in ShopConfig, e.g. "gear_slap_glove").
function ConfigStore.setShop(itemId: any, price: any, disabled: any): (boolean, string)
	local item = if type(itemId) == "string" then ShopConfig.ById[itemId] else nil
	if not item then
		return false, "unknown shop item"
	end
	if item.Currency ~= "Coins" and item.Currency ~= "Gems" then
		return false, "only cash / diamond items can be changed here (Robux prices come from Roblox)"
	end
	if price ~= nil and (type(price) ~= "number" or price ~= price or price < 1 or price > 1e12) then
		return false, "price must be a number from 1 to 1,000,000,000,000"
	end
	if disabled ~= nil and type(disabled) ~= "boolean" then
		return false, "disabled must be true or false"
	end
	local entry = state.Shop[itemId] or {}
	if price ~= nil then
		entry.Price = math.floor(price)
	end
	if disabled ~= nil then
		entry.Disabled = disabled
	end
	state.Shop[itemId] = entry
	publishShop()
	markDirty()
	return true, string.format("%s: price %s, %s", item.Name, tostring(item.Price), if item.Disabled then "disabled" else "enabled")
end

function ConfigStore.resetShop(itemId: any): (boolean, string)
	if type(itemId) ~= "string" or not ShopConfig.ById[itemId] then
		return false, "unknown shop item"
	end
	state.Shop[itemId] = nil
	publishShop()
	markDirty()
	return true, "back to the item file's price"
end

-- For the admin panel: which settings differ from the defaults.
function ConfigStore.changed(): { [string]: any }
	return table.clone(state.Settings)
end

function ConfigStore.start()
	ConfigStore.load()
	game:BindToClose(function()
		if not RunService:IsStudio() then
			ConfigStore.flush()
		end
	end)
end

return ConfigStore
