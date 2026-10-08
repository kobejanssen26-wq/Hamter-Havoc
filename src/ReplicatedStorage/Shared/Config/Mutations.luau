--[[
	Mutation architecture. Hamsters already carry a `Mutation` field; only "Normal" exists now.
	Planned: Golden, Diamond, Rainbow, Fire, Ice, Electric, Toxic, Galaxy, Void, Corrupted.
]]

local Mutations = {}

Mutations.Default = "Normal"

Mutations.Definitions = {
	Normal = {
		Name = "Normal",
		IncomeMultiplier = 1,
		PriceMultiplier = 1,
	},
}

return Mutations
