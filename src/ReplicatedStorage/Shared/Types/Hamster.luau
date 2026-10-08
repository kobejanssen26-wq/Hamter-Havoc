--[[
	Hamster data record. Lives on the server; the client only sees models/attributes.

	State: "OnRoute" (in a ball) | "Owned" (belongs to OwnerUserId, in a wheel) | "Stolen" (being carried)
]]

export type Hamster = {
	UniqueId: string,
	Name: string,
	Rarity: string,
	Mutation: string,
	Size: number,
	IncomePerSecond: number,
	PurchasePrice: number,
	OwnerUserId: number,
	IsLimited: boolean,
	SerialNumber: number?,
	State: string,
	SlotIndex: number?,
	CarrierUserId: number?,
	OriginalOwnerUserId: number?,
}

return {}
