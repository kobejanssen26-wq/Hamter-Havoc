--[[
	UIRegistry: the documented way to add a button / indicator to the HUD without touching MainUI.

	  UIRegistry.register({
	      Id = "Trophies",                 -- unique, stable
	      Kind = "IconButton",             -- "IconButton" (right rail) | "Indicator" (top bar)
	      Slot = "RightRail",              -- see UIRegistry.Slots
	      Order = 70,                      -- sort position inside the slot; must be unique per slot
	      Icon = "trophy",                 -- an id from UI/Icons.luau
	      Tooltip = "Trophies",
	      Label = "Trophies",           -- short word printed under the icon: players should never have to guess what an icon does
	      Panel = "Trophies",              -- name of a UIKit.panel to toggle ...
	      -- OnActivate = function() end,  -- ... or any function (one of the two is required for buttons)
	      Visible = function() return true end,   -- optional: show only when true (re-evaluated about twice a second)
	      Badge = function() return false end,    -- optional: red dot
	  })

	Rules (enforced, a bad definition throws a clear error and nothing is registered):
	  - Id is unique; registering twice is an error. Core entries (Core = true) can never be replaced.
	  - Slot must exist and has a capacity, so the rail can never grow past the screen.
	  - Order must not collide with another entry in the same slot (that would be two things in one place).
	  - IconButtons need a drawn icon and an action.
	MainUI listens with `onChanged` and rebuilds the slot, so registering later (from any script) works.
]]

local Icons = require(script.Parent.Icons)

local UIRegistry = {}

export type Definition = {
	Id: string,
	Kind: string,
	Slot: string,
	Order: number,
	Icon: string?,
	Tooltip: string?,
	Label: string?, -- the short word printed under the icon of a rail button (max ~9 letters)
	Panel: string?,
	Focus: string?,
	OnActivate: (() -> ())?,
	Visible: (() -> boolean)?,
	Badge: (() -> boolean)?,
	Core: boolean?,
}

UIRegistry.Slots = {
	RightRail = { Capacity = 9, Kinds = { IconButton = true } },
	TopBar = { Capacity = 4, Kinds = { Indicator = true } },
}

local entries: { [string]: Definition } = {}
local listeners: { () -> () } = {}

local function fail(message: string)
	error("[UIRegistry] " .. message, 3)
end

local function validate(def: any)
	if type(def) ~= "table" then
		fail("definition must be a table")
	end
	if type(def.Id) ~= "string" or def.Id == "" then
		fail("Id must be a non-empty string")
	end
	if entries[def.Id] then
		fail(string.format("'%s' is already registered%s", def.Id, if entries[def.Id].Core then " (core UI cannot be replaced)" else ""))
	end
	local slot = UIRegistry.Slots[def.Slot]
	if not slot then
		fail(string.format("'%s': unknown Slot '%s'", def.Id, tostring(def.Slot)))
	end
	if not slot.Kinds[def.Kind] then
		fail(string.format("'%s': Kind '%s' is not allowed in slot %s", def.Id, tostring(def.Kind), def.Slot))
	end
	if type(def.Order) ~= "number" then
		fail(string.format("'%s': Order must be a number", def.Id))
	end
	local count = 0
	for _, other in entries do
		if other.Slot == def.Slot then
			count += 1
			if other.Order == def.Order then
				fail(string.format("'%s' and '%s' both use Order %d in slot %s (conflicting position)", def.Id, other.Id, def.Order, def.Slot))
			end
		end
	end
	if count >= slot.Capacity then
		fail(string.format("slot %s is full (%d entries)", def.Slot, slot.Capacity))
	end
	if def.Kind == "IconButton" then
		if type(def.Icon) ~= "string" or not Icons.has(def.Icon) then
			fail(string.format("'%s': Icon '%s' is not a drawn icon (see UI/Icons.luau)", def.Id, tostring(def.Icon)))
		end
		if type(def.Panel) ~= "string" and type(def.OnActivate) ~= "function" then
			fail(string.format("'%s': needs Panel or OnActivate", def.Id))
		end
	end
	if def.Label ~= nil and (type(def.Label) ~= "string" or #def.Label > 12) then
		fail(string.format("'%s': Label must be short text (12 letters at most)", def.Id))
	end
	if def.Visible ~= nil and type(def.Visible) ~= "function" then
		fail(string.format("'%s': Visible must be a function", def.Id))
	end
	if def.Badge ~= nil and type(def.Badge) ~= "function" then
		fail(string.format("'%s': Badge must be a function", def.Id))
	end
end

function UIRegistry.register(def: Definition)
	validate(def)
	entries[def.Id] = def
	for _, listener in listeners do
		task.spawn(listener)
	end
end

-- Non-throwing variant for content scripts that should not break the game when a definition is wrong.
function UIRegistry.tryRegister(def: Definition): (boolean, string?)
	local ok, err = pcall(UIRegistry.register, def)
	if not ok then
		warn(tostring(err))
		return false, tostring(err)
	end
	return true, nil
end

function UIRegistry.get(id: string): Definition?
	return entries[id]
end

-- Entries of a slot, sorted by Order.
function UIRegistry.list(slot: string): { Definition }
	local result = {}
	for _, def in entries do
		if def.Slot == slot then
			table.insert(result, def)
		end
	end
	table.sort(result, function(a, b)
		return a.Order < b.Order
	end)
	return result
end

function UIRegistry.onChanged(listener: () -> ())
	table.insert(listeners, listener)
end

return UIRegistry
