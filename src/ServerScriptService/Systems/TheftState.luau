--[[
	TheftState: tiny shared runtime state of rack thefts (never saved). Kept in its own module so the low-level
	systems (collection, security, house display) can ask "is this locked / trapped?" without requiring TheftSystem.
]]

local TheftState = {}

-- Slots whose hamster is currently being stolen: locks[ownerUserId][slotIndex] = speciesId
TheftState.locks = {} :: { [number]: { [number]: string } }
-- Thieves held inside a base by a closed gate: trapped[thief] = { HouseIndex, Until, LastInside }
TheftState.trapped = {} :: { [Player]: { HouseIndex: number, Until: number, LastInside: CFrame?, NextNotice: number } }

function TheftState.slotLocked(ownerUserId: number, slot: number): boolean
	local locks = TheftState.locks[ownerUserId]
	return locks ~= nil and locks[slot] ~= nil
end

-- How many copies of `speciesId` of this player are locked by running thefts.
function TheftState.lockedCount(ownerUserId: number, speciesId: string): number
	local count = 0
	for _, locked in TheftState.locks[ownerUserId] or {} do
		if locked == speciesId then
			count += 1
		end
	end
	return count
end

function TheftState.anyLocked(ownerUserId: number): boolean
	return next(TheftState.locks[ownerUserId] or {}) ~= nil
end

function TheftState.isTrapped(player: Player, houseIndex: number?): boolean
	local entry = TheftState.trapped[player]
	return entry ~= nil and (houseIndex == nil or entry.HouseIndex == houseIndex)
end

return TheftState
