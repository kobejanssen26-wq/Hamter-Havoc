--[[
	ContentValidator: checks content definitions (hamsters, emotes, animations) and returns a list of issues instead of
	letting a typo break the game. Pure functions: no side effects, easy to run in Studio's command bar:

	    local V = require(game.ReplicatedStorage.Modules.ContentValidator)
	    for _, issue in V.validateAll() do print(issue.Level, issue.Kind, issue.Id, issue.Message) end

	Level "error"  the definition is NOT loaded (the game skips it and warns)
	Level "warn"   loaded, but something is probably unintended
	Asset ids must be real: "rbxassetid://<number>" with a number > 0. Placeholders such as REPLACE_WITH_VALID_ASSET_ID
	or rbxassetid://0 are reported (an empty/missing Icon or AssetId is fine - it just means "not set up yet").
]]

local ContentValidator = {}

export type Issue = { Level: string, Kind: string, Id: string, Message: string }

local RIG_TYPES = { R15 = true, R6 = true, Hamster = true, Any = true }
local ANIMATION_USES = { Idle = true, Walk = true, Run = true, Emote = true, Action = true, Hamster = true, Cosmetic = true }
local PRIORITIES = { Core = true, Idle = true, Movement = true, Action = true, Action2 = true, Action3 = true, Action4 = true }

local function issue(list: { Issue }, level: string, kind: string, id: string, message: string)
	table.insert(list, { Level = level, Kind = kind, Id = id, Message = message })
end

-- true when `value` is a usable asset id; nil/"" count as "not set" (second return value false).
function ContentValidator.assetIdState(value: any): (boolean, boolean)
	if value == nil or value == "" then
		return true, false
	end
	if type(value) ~= "string" then
		return false, true
	end
	local digits = string.match(value, "^rbxassetid://(%d+)$")
	if not digits or tonumber(digits) == nil or tonumber(digits) <= 0 then
		return false, true
	end
	return true, true
end

local function checkAsset(list: { Issue }, kind: string, id: string, field: string, value: any)
	local ok = ContentValidator.assetIdState(value)
	if not ok then
		issue(list, "error", kind, id, string.format("%s '%s' is not a valid asset id (expected \"rbxassetid://<number>\")", field, tostring(value)))
	end
end

local function isStableId(id: any): boolean
	return type(id) == "string" and string.match(id, "^[a-z][a-z0-9_]*$") ~= nil and #id <= 40
end

-- context: { Rarities: {[string]: any}, ExistingIds: {[string]: any}?, ModelExists: ((string) -> boolean)? }
local PERSONAS = { hyper = true, smug = true, scheming = true, mischievous = true, screamer = true, dancer = true, sleepy = true, confused = true, rich = true, calm = true }

function ContentValidator.validateHamster(def: any, context: any): { Issue }
	local list: { Issue } = {}
	local id = if type(def) == "table" and type(def.Id) == "string" then def.Id else "?"
	local function err(message: string)
		issue(list, "error", "Hamster", id, message)
	end
	if type(def) ~= "table" then
		err("definition must be a table")
		return list
	end
	if not isStableId(def.Id) then
		err("Id must be lowercase letters, digits and underscores, starting with a letter (e.g. \"silver_hamster\")")
	elseif context.ExistingIds and context.ExistingIds[def.Id] then
		err("duplicate hamster Id (already used by another hamster)")
	end
	if type(def.DisplayName) ~= "string" or def.DisplayName == "" or #def.DisplayName > 28 then
		err("DisplayName must be a text of 1-28 characters")
	end
	if type(def.Rarity) ~= "string" or not context.Rarities[def.Rarity] then
		err(string.format("Rarity '%s' does not exist", tostring(def.Rarity)))
	end
	if def.Price ~= nil and (type(def.Price) ~= "number" or def.Price ~= def.Price or def.Price < 1 or def.Price > 1e15) then
		err("Price must be a number >= 1 (leave it out to use the rarity formula)")
	end
	if def.IncomePerSecond ~= nil and (type(def.IncomePerSecond) ~= "number" or def.IncomePerSecond ~= def.IncomePerSecond or def.IncomePerSecond < 0 or def.IncomePerSecond > 1e15) then
		err("IncomePerSecond must be a number >= 0 (leave it out to use the rarity formula)")
	end
	if def.ModelName ~= nil then
		if type(def.ModelName) ~= "string" or def.ModelName == "" then
			err("ModelName must be the name of a model in ReplicatedStorage/Assets/HamsterModels")
		elseif context.ModelExists and not context.ModelExists(def.ModelName) then
			issue(list, "warn", "Hamster", id, string.format("model '%s' not found in ReplicatedStorage/Assets/HamsterModels - the procedural hamster is used instead", def.ModelName))
		end
	end
	checkAsset(list, "Hamster", id, "Icon", def.Icon)
	if def.Description ~= nil and (type(def.Description) ~= "string" or #def.Description > 140) then
		err("Description must be a text of at most 140 characters (shown in the Hamster Index)")
	end
	if type(def.Look) == "table" and def.Look.Shape ~= nil then
		local shapes = { standard = true, chonk = true, lanky = true, long = true, bean = true, tiny = true, giant = true }
		if not shapes[def.Look.Shape] then
			err("Look.Shape must be one of: standard, chonk, lanky, long, bean, tiny, giant")
		end
	end
	if type(def.Look) == "table" and def.Look.Aura ~= nil then
		local problem = require(script.Parent.AuraConfig).problem(def.Look.Aura)
		if problem then
			err(problem)
		end
	end
	if def.Persona ~= nil and not PERSONAS[def.Persona] then
		err("Persona must be one of: hyper, smug, scheming, mischievous, screamer, dancer, sleepy, confused, rich, calm")
	end
	if def.Inspiration ~= nil and (type(def.Inspiration) ~= "string" or #def.Inspiration > 400) then
		err("Inspiration must be a text (who/what the joke is about and why it is recognisable), at most 400 characters")
	end
	if def.LicensedName ~= nil then
		if type(def.LicensedName) ~= "string" or #def.LicensedName > 28 then
			err("LicensedName must be a text of at most 28 characters")
		elseif def.Licensed ~= true then
			issue(list, "warn", "Hamster", id, "LicensedName is ignored until you set Licensed = true (only do that if you hold written permission / the rights)")
		else
			issue(list, "warn", "Hamster", id, "Licensed = true: the real name is shown. You are responsible for holding the rights (Roblox IP guidelines)")
		end
	end
	if def.Limited ~= nil then
		if type(def.Limited) ~= "table" or type(def.Limited.EndsAt) ~= "number" or def.Limited.EndsAt ~= def.Limited.EndsAt then
			err("Limited must be a table like { EndsAt = <unix time> } (optionally StartsAt)")
		elseif def.Limited.StartsAt ~= nil and (type(def.Limited.StartsAt) ~= "number" or def.Limited.StartsAt >= def.Limited.EndsAt) then
			err("Limited.StartsAt must be a unix time before EndsAt")
		end
	end
	if def.Animation ~= nil and type(def.Animation) ~= "table" then
		err("Animation must be a table like { Idle = \"name\", Walk = \"name\" } (names from Content/Animations)")
	end
	if def.Sound ~= nil and type(def.Sound) ~= "table" then
		err("Sound must be a table like { Spawn = \"SoundName\" } (names from AudioConfig.Sfx)")
	end
	if def.Unlock ~= nil then
		if type(def.Unlock) ~= "table" then
			err("Unlock must be a table like { MinRebirth = 2 }")
		elseif def.Unlock.MinRebirth ~= nil and (type(def.Unlock.MinRebirth) ~= "number" or def.Unlock.MinRebirth < 0) then
			err("Unlock.MinRebirth must be a number >= 0")
		end
	end
	return list
end

-- context: { Animations: {[string]: any}?, Builtin: {[string]: boolean} }
function ContentValidator.validateEmote(def: any, context: any, seen: { [string]: boolean }?): { Issue }
	local list: { Issue } = {}
	local id = if type(def) == "table" and type(def.Id) == "string" then def.Id else "?"
	local function err(message: string)
		issue(list, "error", "Emote", id, message)
	end
	if type(def) ~= "table" then
		err("definition must be a table")
		return list
	end
	if not isStableId(def.Id) then
		err("Id must be lowercase letters, digits and underscores")
	elseif seen and seen[def.Id] then
		err("duplicate emote Id")
	end
	if type(def.DisplayName) ~= "string" or def.DisplayName == "" or #def.DisplayName > 20 then
		err("DisplayName must be a text of 1-20 characters")
	end
	if type(def.Icon) ~= "string" or def.Icon == "" then
		err("Icon must be a drawn icon id from UI/Icons.luau")
	end
	local hasBuiltin = def.Builtin ~= nil
	local hasAnimation = def.AnimationId ~= nil or def.Animation ~= nil
	if hasBuiltin == hasAnimation then
		err("set exactly one of Builtin (Roblox default emote name), AnimationId (rbxassetid) or Animation (registry name)")
	end
	if hasBuiltin and (type(def.Builtin) ~= "string" or not context.Builtin[def.Builtin]) then
		err(string.format("Builtin '%s' is not a Roblox default emote (wave, point, dance, dance2, dance3, laugh, cheer)", tostring(def.Builtin)))
	end
	if def.AnimationId ~= nil then
		local ok, set = ContentValidator.assetIdState(def.AnimationId)
		if not ok or not set then
			err("AnimationId must be \"rbxassetid://<number>\"")
		end
	end
	if def.Animation ~= nil and (type(def.Animation) ~= "string" or (context.Animations and not context.Animations[def.Animation])) then
		err(string.format("Animation '%s' is not in Content/Animations", tostring(def.Animation)))
	end
	if def.Unlock ~= nil and (type(def.Unlock) ~= "table" or (def.Unlock.MinRebirth ~= nil and type(def.Unlock.MinRebirth) ~= "number")) then
		err("Unlock must be a table like { MinRebirth = 1 }")
	end
	if def.Default ~= nil and type(def.Default) ~= "boolean" then
		err("Default must be true or false")
	end
	return list
end

function ContentValidator.validateAnimation(def: any, seen: { [string]: boolean }?): { Issue }
	local list: { Issue } = {}
	local id = if type(def) == "table" and type(def.Name) == "string" then def.Name else "?"
	local function err(message: string)
		issue(list, "error", "Animation", id, message)
	end
	if type(def) ~= "table" then
		err("definition must be a table")
		return list
	end
	if type(def.Name) ~= "string" or string.match(def.Name, "^[%w_]+$") == nil then
		err("Name must be letters, digits and underscores")
	elseif seen and seen[def.Name] then
		err("duplicate animation Name")
	end
	local ok, set = ContentValidator.assetIdState(def.AssetId)
	if not ok then
		err(string.format("AssetId '%s' is not valid (expected \"rbxassetid://<number>\")", tostring(def.AssetId)))
	elseif not set then
		issue(list, "warn", "Animation", id, "AssetId is not set - the animation is skipped until you upload it and paste the id")
	end
	if not RIG_TYPES[def.Rig] then
		err("Rig must be R15, R6, Hamster or Any")
	end
	if not ANIMATION_USES[def.Use] then
		err("Use must be Idle, Walk, Run, Emote, Action, Hamster or Cosmetic")
	end
	if def.Priority ~= nil and not PRIORITIES[def.Priority] then
		err("Priority must be a name of Enum.AnimationPriority (Core, Idle, Movement, Action, Action2 ...)")
	end
	if def.Speed ~= nil and (type(def.Speed) ~= "number" or def.Speed <= 0 or def.Speed > 5) then
		err("Speed must be a number between 0 and 5")
	end
	return list
end

local ITEM_CATEGORIES = { Weapon = true, Equipment = true, Consumable = true }
local PASSIVE_STATS = { CollectRange = true, WalkSpeed = true }
local WEAPON_LIMITS = { Range = { 3, 80 }, Cooldown = { 0.3, 10 }, Knockback = { 0, 100 }, Stun = { 0, 3 }, DropChance = { 0, 1 }, Arc = { -1, 1 } }
-- optional numbers every attack may set (otherwise CombatTiming / GameConfig defaults apply)
local OPTIONAL_WEAPON_LIMITS = { WindUp = { 0, 1 }, Active = { 0, 0.6 }, Lift = { 0, 40 }, Slow = { 0.2, 0.9 }, SlowSeconds = { 0.5, 8 }, Stun = { 0, 3 }, Knockback = { 0, 100 }, DropChance = { 0, 1 } }
local TRAP_KINDS = { Spike = true, Glue = true, Banana = true }
-- Ability weapons: their own stat sets and hard caps, so no item file can make an unbounded power.
local ABILITY_LIMITS = {
	Freeze = { Range = { 5, 60 }, Cooldown = { 8, 120 }, Duration = { 0.5, 3 } },
	Cloak = { Cooldown = { 15, 180 }, Duration = { 2, 10 } },
	Decoy = { Cooldown = { 15, 180 }, Duration = { 2, 10 } },
	Guard = { Cooldown = { 10, 120 }, Duration = { 1, 6 } },
	Trap = { Cooldown = { 2, 120 }, Duration = { 8, 120 }, MaxActive = { 1, 6 }, ArmSeconds = { 0.3, 3 } },
}
local BOOST_IDS = { Coins2x = true, Luck2x = true, Speed2x = true, AutoCollect = true }

-- context: { Rarities, ExistingIds, ModelExists: ((string) -> boolean)? }
function ContentValidator.validateItem(def: any, context: any): { Issue }
	local list: { Issue } = {}
	local id = if type(def) == "table" and type(def.Id) == "string" then def.Id else "?"
	local function err(message: string)
		issue(list, "error", "Item", id, message)
	end
	if type(def) ~= "table" then
		err("definition must be a table")
		return list
	end
	if not isStableId(def.Id) then
		err("Id must be lowercase letters, digits and underscores, starting with a letter")
	elseif context.ExistingIds and context.ExistingIds[def.Id] then
		err("duplicate item Id")
	end
	if type(def.DisplayName) ~= "string" or def.DisplayName == "" or #def.DisplayName > 28 then
		err("DisplayName must be a text of 1-28 characters")
	end
	if def.Description ~= nil and (type(def.Description) ~= "string" or #def.Description > 160) then
		err("Description must be a text of at most 160 characters")
	end
	if not ITEM_CATEGORIES[def.Category] then
		err("Category must be Weapon, Equipment or Consumable")
	end
	if type(def.Icon) ~= "string" or def.Icon == "" then
		err("Icon must be a drawn icon id (UI/Icons.luau) or \"rbxassetid://<number>\"")
	elseif string.sub(def.Icon, 1, 4) == "rbxa" then
		checkAsset(list, "Item", id, "Icon", def.Icon)
	end
	if def.Rarity ~= nil and not context.Rarities[def.Rarity] then
		err("Rarity '" .. tostring(def.Rarity) .. "' does not exist")
	end
	if def.MinRebirth ~= nil and (type(def.MinRebirth) ~= "number" or def.MinRebirth % 1 ~= 0 or def.MinRebirth < 0 or def.MinRebirth > 25) then
		err("MinRebirth must be a whole number from 0 to 25 (the rebirth level that unlocks buying it)")
	end
	if (def.Price == nil) ~= (def.Currency == nil) then
		err("Price and Currency must be set together (or both left out for items that are not sold)")
	elseif def.Price ~= nil then
		if def.Currency ~= "Coins" and def.Currency ~= "Gems" then
			err("Currency must be \"Coins\" (cash) or \"Gems\" (diamonds) - Robux items are Game Passes")
		end
		if type(def.Price) ~= "number" or def.Price ~= def.Price or def.Price < 1 or def.Price > 1e12 then
			err("Price must be a number >= 1")
		end
	end
	local equip = def.Equip
	if type(equip) ~= "table" then
		err("Equip must be a table")
		return list
	end
	if equip.Kind == "Tool" then
		if def.Category ~= "Weapon" then
			err("a Tool item must have Category = \"Weapon\"")
		end
		local weapon = equip.Weapon
		if type(weapon) ~= "table" then
			err("Equip.Weapon is missing")
		else
			local limitsFor = if weapon.Type == "Melee" or weapon.Type == "Ranged" then WEAPON_LIMITS else ABILITY_LIMITS[weapon.Type]
			if not limitsFor then
				err("Weapon.Type must be Melee, Ranged, Freeze, Cloak, Decoy, Guard or Trap")
			else
				for stat, limits in limitsFor do
					local value = weapon[stat]
					if type(value) ~= "number" or value ~= value or value < limits[1] or value > limits[2] then
						err(string.format("Weapon.%s must be a number between %s and %s", stat, limits[1], limits[2]))
					end
				end
				for stat, limits in OPTIONAL_WEAPON_LIMITS do
					local value = weapon[stat]
					if value ~= nil and (type(value) ~= "number" or value ~= value or value < limits[1] or value > limits[2]) then
						err(string.format("Weapon.%s must be a number between %s and %s", stat, limits[1], limits[2]))
					end
				end
				if type(weapon.Cooldown) == "number" and (weapon.Cooldown < (weapon.WindUp or 0) + (weapon.Active or 0)) then
					err("Weapon.Cooldown must be at least WindUp + Active (the swing has to finish before the next one)")
				end
				if weapon.Type == "Trap" and not TRAP_KINDS[weapon.TrapKind] then
					err("a Trap needs Weapon.TrapKind = \"Spike\", \"Glue\" or \"Banana\"")
				end
				if weapon.Animation ~= nil and type(weapon.Animation) ~= "string" then
					err("Weapon.Animation must be the Name of an animation in Content/Animations")
				end
			end
		end
		if def.ModelName ~= nil and context.ModelExists and not context.ModelExists(def.ModelName) then
			issue(list, "warn", "Item", id, string.format("tool model '%s' not found in ReplicatedStorage/Assets/Tools - the built-in weapon model is used", def.ModelName))
		end
	elseif equip.Kind == "Passive" then
		if def.Category ~= "Equipment" then
			err("a Passive item must have Category = \"Equipment\"")
		end
		if type(equip.Stats) ~= "table" or next(equip.Stats) == nil then
			err("Equip.Stats is missing")
		else
			for stat, value in equip.Stats do
				if not PASSIVE_STATS[stat] then
					err("unsupported stat '" .. tostring(stat) .. "' (supported: CollectRange, WalkSpeed)")
				elseif type(value) ~= "number" or value ~= value or value < 0 or value > 100 then
					err("stat " .. tostring(stat) .. " must be a number between 0 and 100")
				end
			end
		end
	elseif equip.Kind == "Consume" then
		if def.Category ~= "Consumable" then
			err("a Consume item must have Category = \"Consumable\"")
		end
		if equip.Effect == "Boost" then
			if not BOOST_IDS[equip.BoostId] or type(equip.Seconds) ~= "number" or equip.Seconds < 10 or equip.Seconds > 86400 then
				err("Boost needs a known BoostId (Coins2x, Luck2x, Speed2x, AutoCollect) and Seconds between 10 and 86400")
			end
		elseif equip.Effect == "Pouch" then
			if type(equip.Minutes) ~= "number" or equip.Minutes <= 0 or equip.Minutes > 600 then
				err("Pouch needs Minutes between 0 and 600")
			end
		else
			err("Effect must be Boost or Pouch")
		end
	else
		err("Equip.Kind must be Tool, Passive or Consume")
	end
	return list
end

return ContentValidator
