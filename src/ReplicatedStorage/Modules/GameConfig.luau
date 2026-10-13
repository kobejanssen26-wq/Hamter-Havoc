--[[
	GameConfig: THE place for ordinary game settings (cooldowns, durations, combat numbers, starting cash ...).
	Change a number here, press Play, done. You never need to search other scripts for these values.

	Every setting has:
	  Default   the value used when nothing else is set (this file)
	  Min / Max hard limits - a value outside them is rejected, so a typo can't break the game
	  Live      true  = an admin may change it while the game runs (Admin panel > Settings), it applies at once
	            false = only changeable here in Studio (needs a new server)
	  Doc       one line that explains it (also shown in the admin panel)

	Where things live (so you know where NOT to look):
	  this file ........ global rules: gate, combat, abilities, economy start, tutorial
	  Content/Items .... one file per weapon/equipment/boost: price, rebirth, range, cooldown, knockback, duration
	  Content/Hamsters . one file per hamster: rarity, income, price
	  RebirthConfig .... rebirth steps, requirements, rewards
	  GamepassConfig ... Game Passes / Robux products

	Live values changed by an admin are saved by the server (ConfigStore) and loaded on the next start. "Reset" in the admin
	panel returns a value to the Default written here.
]]

local GameConfig = {}

export type Setting = { Default: number | boolean, Min: number?, Max: number?, Live: boolean, Doc: string }

-- Order here = order in the admin panel.
GameConfig.Schema = {
	Security = {
		GateReopenCooldown = { Default = 7, Min = 1, Max = 120, Live = true, Doc = "Seconds after the gate switches off before its owner may switch it on again (basic gate)." },
		GateRechargeBonusPerTier = { Default = 1, Min = 0, Max = 10, Live = true, Doc = "Seconds the reopen cooldown gets shorter per better gate tier (rebirth 1, 3, 6)." },
		GateMinCooldown = { Default = 2, Min = 0, Max = 60, Live = true, Doc = "The reopen cooldown never gets shorter than this." },
		GateBaseDuration = { Default = 45, Min = 5, Max = 600, Live = true, Doc = "Seconds the gate stays on after switching it on (rebirth 0)." },
		GateSecondsPerRebirth = { Default = 10, Min = 0, Max = 120, Live = true, Doc = "Extra seconds the gate stays on for every rebirth." },
		ZapStunSeconds = { Default = 1.3, Min = 0, Max = 5, Live = true, Doc = "How long a stranger is stunned by the gate." },
		ZapCooldown = { Default = 2.2, Min = 0.5, Max = 30, Live = true, Doc = "Minimum seconds between two zaps of the same player." },
	},
	Combat = {
		PvpNeedsHamsterNearby = { Default = false, Live = true, Doc = "false = you can hit any player anywhere outside safe zones. true = old rule: only near a hamster that is rolling, carried or dropped." },
		SpawnProtectionSeconds = { Default = 4, Min = 0, Max = 30, Live = true, Doc = "A player who just (re)spawned can not be hit for this long." },
		HitImmunitySeconds = { Default = 0.9, Min = 0, Max = 5, Live = true, Doc = "After a hit lands, this player can not be hit again for this long (stops stun-lock and knockback stacking)." },
		LatencyGrace = { Default = 3, Min = 0, Max = 10, Live = true, Doc = "Extra studs of reach the server allows to forgive lag (a moving target is not missed because of ping)." },
		MaxKnockback = { Default = 60, Min = 10, Max = 150, Live = true, Doc = "Hard cap on horizontal knockback speed, whatever a weapon says." },
		MaxKnockbackLift = { Default = 28, Min = 0, Max = 80, Live = true, Doc = "Hard cap on the upwards part of a knockback." },
		MaxStunSeconds = { Default = 1.6, Min = 0.2, Max = 5, Live = true, Doc = "Hard cap on the stun of one hit." },
		WallCheck = { Default = true, Live = true, Doc = "true = an attack cannot pass through walls and solid objects." },
		MaxTargetsPerSwing = { Default = 1, Min = 1, Max = 5, Live = true, Doc = "How many different players one swing may hit." },
		PawRange = { Default = 8, Min = 3, Max = 20, Live = true, Doc = "Reach of the bare-paw slap (no weapon)." },
		PawArc = { Default = 0.15, Min = -1, Max = 1, Live = true, Doc = "How wide in front of you the slap reaches (1 = a thin line, 0 = half circle, -1 = all round)." },
		PawCooldown = { Default = 1.1, Min = 0.3, Max = 10, Live = true, Doc = "Seconds between two bare-paw slaps." },
		PawKnockback = { Default = 38, Min = 0, Max = 100, Live = true, Doc = "Knockback of the bare-paw slap." },
		PawStun = { Default = 0.9, Min = 0, Max = 3, Live = true, Doc = "Stun of the bare-paw slap." },
		PawDropChance = { Default = 0.7, Min = 0, Max = 1, Live = true, Doc = "Chance that a hit carrier drops the hamster (bare paws)." },
	},
	Abilities = {
		FreezeMaxSeconds = { Default = 3, Min = 0.5, Max = 6, Live = true, Doc = "Hard cap on any freeze, whatever an item file says." },
		FreezeImmunitySeconds = { Default = 6, Min = 0, Max = 60, Live = true, Doc = "After being frozen you can not be frozen again for this long." },
		GuardImmunityFromKnockback = { Default = true, Live = true, Doc = "true = an active shield blocks knockback and stun." },
	},
	Economy = {
		StartingCash = { Default = 250, Min = 0, Max = 1000000, Live = false, Doc = "Cash a brand-new player starts with." },
		StartingDiamonds = { Default = 25, Min = 0, Max = 100000, Live = false, Doc = "Diamonds a brand-new player starts with." },
	},
	Tutorial = {
		Enabled = { Default = true, Live = false, Doc = "false = new players do not get the tutorial." },
	},
}

local values: { [string]: { [string]: any } } = {}
local listeners: { (string, string, any) -> () } = {}

for section, settings in GameConfig.Schema do
	values[section] = {}
	for key, setting in settings do
		values[section][key] = setting.Default
	end
end

local function schemaOf(section: string, key: string): Setting?
	local s = GameConfig.Schema[section]
	return s and s[key]
end

-- Current value of a setting. Unknown names are a mistake in the calling script: they error loudly.
function GameConfig.get(section: string, key: string): any
	local v = values[section] and values[section][key]
	if v == nil then
		error(string.format("GameConfig: unknown setting %s.%s", tostring(section), tostring(key)), 2)
	end
	return v
end

function GameConfig.default(section: string, key: string): any
	local s = schemaOf(section, key)
	return s and s.Default
end

-- Validates a candidate value. Returns (ok, valueOrReason).
function GameConfig.validate(section: any, key: any, value: any): (boolean, any)
	if type(section) ~= "string" or type(key) ~= "string" then
		return false, "unknown setting"
	end
	local s = schemaOf(section, key)
	if not s then
		return false, "unknown setting"
	end
	if type(s.Default) == "boolean" then
		if type(value) ~= "boolean" then
			return false, "must be true or false"
		end
		return true, value
	end
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return false, "must be a number"
	end
	if value < (s.Min :: number) or value > (s.Max :: number) then
		return false, string.format("must be between %s and %s", tostring(s.Min), tostring(s.Max))
	end
	return true, value
end

-- Sets a value (server). `live` = the caller is an admin changing a running game (only Live settings qualify).
function GameConfig.set(section: string, key: string, value: any, live: boolean?): (boolean, string?)
	local ok, result = GameConfig.validate(section, key, value)
	if not ok then
		return false, tostring(result)
	end
	local s = schemaOf(section, key) :: Setting
	if live and not s.Live then
		return false, "this setting can only be changed in Studio (GameConfig.luau)"
	end
	values[section][key] = result
	for _, listener in listeners do
		listener(section, key, result)
	end
	return true, nil
end

function GameConfig.reset(section: string, key: string, live: boolean?): (boolean, string?)
	local s = schemaOf(section, key)
	if not s then
		return false, "unknown setting"
	end
	return GameConfig.set(section, key, s.Default, live)
end

function GameConfig.isDefault(section: string, key: string): boolean
	return values[section][key] == (schemaOf(section, key) :: Setting).Default
end

function GameConfig.onChanged(fn: (string, string, any) -> ())
	table.insert(listeners, fn)
end

-- Flat list for the admin panel: { Section, Key, Value, Default, Min, Max, Live, Doc }
function GameConfig.list(): { any }
	local result = {}
	local sections = {}
	for section in GameConfig.Schema do
		table.insert(sections, section)
	end
	table.sort(sections)
	for _, section in sections do
		local keys = {}
		for key in GameConfig.Schema[section] do
			table.insert(keys, key)
		end
		table.sort(keys)
		for _, key in keys do
			local s = GameConfig.Schema[section][key]
			table.insert(result, { Section = section, Key = key, Value = values[section][key], Default = s.Default, Min = s.Min, Max = s.Max, Live = s.Live, Doc = s.Doc })
		end
	end
	return result
end

-- Checks the file itself (defaults inside their own limits). Used by the tests.
function GameConfig.selfCheck(): { string }
	local problems = {}
	for section, settings in GameConfig.Schema do
		for key, s in settings do
			if type(s.Default) == "number" then
				if s.Min == nil or s.Max == nil or s.Default < s.Min or s.Default > s.Max then
					table.insert(problems, string.format("%s.%s: Default is outside Min/Max", section, key))
				end
			end
			if type(s.Doc) ~= "string" or s.Doc == "" then
				table.insert(problems, string.format("%s.%s: Doc is missing", section, key))
			end
		end
	end
	return problems
end

return GameConfig
