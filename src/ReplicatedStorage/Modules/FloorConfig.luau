--[[
	The apartment tower. Floors are the big visible milestones of rebirth: the building physically grows.
	Every floor has real gameplay value:
	  - 8 more hamster wheel stations (capacity for slots; slots themselves come from rebirths / upgrades)
	  - a permanent income bonus (stacks)
	  - floor specific extras (storage lounge, upgrade console, luck bonus ...)
	Add a floor by appending to Floors (and give HouseBuilder a look for it).
]]

local FloorConfig = {}

FloorConfig.StationsPerFloor = 8

export type Floor = {
	Index: number,
	Name: string,
	MinRebirth: number,
	IncomeBonus: number, -- +x income (0.10 = +10%)
	LuckBonus: number, -- +x luck
	Perk: string, -- one-line description shown in the Rebirth UI
	Feature: string?, -- "Storage" | "Console" | nil
	Elevator: { Visible: boolean?, Up: boolean?, Down: boolean? }?, -- optional per-floor elevator switches (default: all true)
}

FloorConfig.Floors = {
	{ Index = 1, Name = "Hamster Hall", MinRebirth = 0, IncomeBonus = 0, LuckBonus = 0, Perk = "Main wheel hall, upgrade pedestals and the arrival pad", Feature = nil },
	{ Index = 2, Name = "Wheel Gallery", MinRebirth = 3, IncomeBonus = 0.10, LuckBonus = 0, Perk = "+8 wheel stations, +10% income, storage lounge", Feature = "Storage" },
	{ Index = 3, Name = "Upgrade Lab", MinRebirth = 6, IncomeBonus = 0.10, LuckBonus = 0, Perk = "+8 wheel stations, +10% income, upgrade console", Feature = "Console" },
	{ Index = 4, Name = "Premium Suite", MinRebirth = 10, IncomeBonus = 0.10, LuckBonus = 0.10, Perk = "+8 wheel stations, +10% income, +10% luck", Feature = nil },
	{ Index = 5, Name = "Penthouse", MinRebirth = 15, IncomeBonus = 0.10, LuckBonus = 0.10, Perk = "+8 wheel stations, +10% income, +10% luck, rooftop garden", Feature = nil },
} :: { Floor }

FloorConfig.MaxFloors = #FloorConfig.Floors

-- State of the elevator on floor `index` in a building with `built` floors (all configuration-driven):
--   Visible  the shaft and doors exist (never in a one-floor building)
--   Up       an UP call button exists (only when the next floor is really unlocked)
--   Down     a DOWN call button exists (every floor above the first)
-- A floor can opt out through its own `Elevator = { Visible = false }` / `{ Up = false }` / `{ Down = false }` entry.
function FloorConfig.elevator(index: number, built: number): { Visible: boolean, Up: boolean, Down: boolean, UpTo: number?, DownTo: number? }
	local floor = FloorConfig.Floors[index]
	if not floor or index > built or built < 2 then
		return { Visible = false, Up = false, Down = false }
	end
	local config = floor.Elevator or {}
	local up = config.Up ~= false and index < built
	local down = config.Down ~= false and index > 1
	local visible = config.Visible ~= false and (up or down)
	if not visible then
		return { Visible = false, Up = false, Down = false }
	end
	return { Visible = true, Up = up, Down = down, UpTo = if up then index + 1 else nil, DownTo = if down then index - 1 else nil }
end

-- How many floors the player's building has after `rebirths` rebirths.
function FloorConfig.count(rebirths: number): number
	local count = 1
	for _, floor in FloorConfig.Floors do
		if rebirths >= floor.MinRebirth then
			count = math.max(count, floor.Index)
		end
	end
	return count
end

-- Wheel stations the building offers (an upper bound for hamster slots).
function FloorConfig.capacity(rebirths: number): number
	return FloorConfig.count(rebirths) * FloorConfig.StationsPerFloor
end

function FloorConfig.floorOfSlot(slotIndex: number): number
	return (slotIndex - 1) // FloorConfig.StationsPerFloor + 1
end

-- Sum of the permanent bonuses of every floor the building has.
function FloorConfig.incomeBonus(rebirths: number): number
	local total = 0
	for index = 1, FloorConfig.count(rebirths) do
		total += FloorConfig.Floors[index].IncomeBonus
	end
	return total
end

function FloorConfig.luckBonus(rebirths: number): number
	local total = 0
	for index = 1, FloorConfig.count(rebirths) do
		total += FloorConfig.Floors[index].LuckBonus
	end
	return total
end

-- The floor that the NEXT unlock adds (nil when the tower is complete).
function FloorConfig.nextFloor(rebirths: number): Floor?
	local count = FloorConfig.count(rebirths)
	return FloorConfig.Floors[count + 1]
end

-- Floor unlocked by exactly this rebirth number (nil if none).
function FloorConfig.unlockedAt(rebirth: number): Floor?
	for _, floor in FloorConfig.Floors do
		if floor.MinRebirth == rebirth and floor.Index > 1 then
			return floor
		end
	end
	return nil
end

return FloorConfig
