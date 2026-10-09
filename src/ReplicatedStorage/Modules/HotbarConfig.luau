--[[
	Hotbar: the permanent bottom bar. Fully configuration driven; the server uses it to validate UseItem and the
	client only draws it.

	Kinds
	  Ability     always available, never consumed (Slap). Using it is done with the normal combat input.
	  Consumable  a counted item in profile.Items[itemId]. Bought in the shop, used from the hotbar (server checks
	              the count, applies the effect and removes one).

	There is deliberately NO weapon/tool system: only mechanics that really exist are listed. To add one later
	append an entry here (and handle its Kind in ItemSystem).
]]

local HotbarConfig = {}

export type Slot = {
	Id: string,
	Kind: string,
	Name: string,
	Desc: string,
	Icon: string,
	BoostId: string?,
	Seconds: number?,
	Minutes: number?,
	Effect: string?,
}

HotbarConfig.Slots = {
	{ Id = "slap", Kind = "Ability", Name = "Slap", Desc = "Knock thieves off your hamsters. Press Q or tap Slap.", Icon = "fist" },
	{ Id = "item_coins", Kind = "Consumable", Name = "2x Cash", Desc = "Doubles all cash you earn for 15 minutes.", Icon = "coin", Effect = "Boost", BoostId = "Coins2x", Seconds = 900 },
	{ Id = "item_luck", Kind = "Consumable", Name = "2x Luck", Desc = "Rarer hamsters appear more often for 10 minutes.", Icon = "clover", Effect = "Boost", BoostId = "Luck2x", Seconds = 600 },
	{ Id = "item_speed", Kind = "Consumable", Name = "Speed Tonic", Desc = "+6 walk speed for 10 minutes.", Icon = "bolt", Effect = "Boost", BoostId = "Speed2x", Seconds = 600 },
	{ Id = "item_auto", Kind = "Consumable", Name = "Auto Collector", Desc = "Grabs affordable hamsters in range for 10 minutes.", Icon = "bot", Effect = "Boost", BoostId = "AutoCollect", Seconds = 600 },
	{ Id = "item_pouch", Kind = "Consumable", Name = "Cash Pouch", Desc = "10 minutes of your current income, instantly.", Icon = "pouch", Effect = "Pouch", Minutes = 10 },
} :: { Slot }

HotbarConfig.ById = {} :: { [string]: Slot }
for _, slot in HotbarConfig.Slots do
	HotbarConfig.ById[slot.Id] = slot
end

return HotbarConfig
