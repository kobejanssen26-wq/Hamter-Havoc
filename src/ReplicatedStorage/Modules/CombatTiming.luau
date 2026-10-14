--[[
	CombatTiming: the three phases of every attack, shared by the server (decides WHEN a hit can land) and the clients
	(play the animation in sync):

	  WindUp    the weapon is drawn back. Nothing can be hit yet.
	  Active    the weapon is moving through its hit area. ONLY now can the swing hit someone (server checks every frame).
	  Recovery  follow-through and return to idle. The weapon cannot hit, and cannot be swung again until Cooldown has passed.

	Cooldown counts from the START of the swing, so  Cooldown >= WindUp + Active  (the validator enforces this).
	An item file can override WindUp / Active in its Weapon table; otherwise the defaults for its Type below are used.
]]

local CombatTiming = {}

CombatTiming.Defaults = {
	Melee = { WindUp = 0.12, Active = 0.2 },
	Ranged = { WindUp = 0.1, Active = 0.05 },
	Freeze = { WindUp = 0.2, Active = 0.05 },
	Cloak = { WindUp = 0.1, Active = 0 },
	Decoy = { WindUp = 0.1, Active = 0 },
	Guard = { WindUp = 0.08, Active = 0 },
	Trap = { WindUp = 0.12, Active = 0 },
	Glider = { WindUp = 0.05, Active = 0 },
	Rocket = { WindUp = 0.05, Active = 0 },
}

-- (windUp, active, recovery) in seconds for a Weapon table (or the bare-paw table).
function CombatTiming.of(weapon: any): (number, number, number)
	local defaults = CombatTiming.Defaults[weapon.Type] or CombatTiming.Defaults.Melee
	local windUp = if type(weapon.WindUp) == "number" then weapon.WindUp else defaults.WindUp
	local active = if type(weapon.Active) == "number" then weapon.Active else defaults.Active
	local recovery = math.max(0, (weapon.Cooldown or 1) - windUp - active)
	return windUp, active, recovery
end

return CombatTiming
