--[[
	Rack theft: stealing a hamster that is running on a wheel in somebody else's OPEN base.

	Flow (all decided by the server, see TheftSystem):
	  1. a thief holds the prompt on a wheel (gate must be off, hamster eligible)
	  2. the hamster leaves the wheel and becomes a carried ball (the same carry system as stolen balls)
	  3. thief runs it to the arrival pad of their OWN house -> theft complete, the hamster changes owner
	     the owner hits the thief (slap) -> theft failed, the hamster is back on its wheel
	  4. gate switched on while a thief is inside -> the thief is trapped until: the owner hits them, the gate switches off,
	     or EscapeTimeout runs out (then the theft fails and the thief is put outside). Nobody is trapped for ever.
	Nothing about an unfinished theft is ever saved: the hamster stays in its owner's data until the theft completes.
]]

local TheftConfig = {}

TheftConfig.StealableFloors = { 1 } -- a thief can only reach the ground floor (the elevator belongs to the owner)
TheftConfig.HoldSeconds = 1.2 -- how long the thief holds the prompt
TheftConfig.PromptDistance = 8
TheftConfig.MaxDistance = 14 -- server check: thief must be this close to the wheel when the hold completes
TheftConfig.ThiefCooldown = 4 -- seconds between two theft attempts of one thief
TheftConfig.EscapeTimeout = 60 -- seconds a thief stays trapped by a closed gate before the theft fails
TheftConfig.OwnerProtectionSeconds = 45 -- a player who just joined cannot be robbed during this time
TheftConfig.LeashMargin = 2 -- studs inside the gate line a trapped thief is held at
TheftConfig.MinRank = 1 -- minimum rarity rank of an eligible hamster (1 = every hamster)

-- Is this hamster eligible for rack theft? (extra rules can be added here)
function TheftConfig.eligible(species: any): boolean
	if not species then
		return false
	end
	local RarityConfig = require(script.Parent.RarityConfig)
	return RarityConfig.rank(species.Rarity) >= TheftConfig.MinRank
end

function TheftConfig.floorStealable(floor: number): boolean
	return table.find(TheftConfig.StealableFloors, floor) ~= nil
end

return TheftConfig
