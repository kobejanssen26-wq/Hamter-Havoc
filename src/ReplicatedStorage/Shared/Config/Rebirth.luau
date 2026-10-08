--[[
	Rebirth architecture (NOT implemented yet - only tier 0 exists).
	Later tiers can raise slot count, income multiplier, unlock zones / rarities and expand bases.
]]

local Rebirth = {}

Rebirth.Tiers = {
	[0] = {
		SlotCount = 4,
		IncomeMultiplier = 1,
		UnlockedZones = { "Starter" },
		BaseExpansion = 0,
	},
}

function Rebirth.getTier(rebirthCount: number)
	local bestKey = 0
	for key in Rebirth.Tiers do
		if key <= rebirthCount and key > bestKey then
			bestKey = key
		end
	end
	return Rebirth.Tiers[bestKey]
end

return Rebirth
