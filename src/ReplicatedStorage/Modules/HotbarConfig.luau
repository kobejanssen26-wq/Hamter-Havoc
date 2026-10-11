--[[
	Hotbar layout rules. WHAT can be on the hotbar comes from ItemRegistry (weapons and consumables the player owns);
	this module only holds the layout:
	  Slot 1      the built-in Slap (an ability everybody has; also used when no weapon is equipped)
	  Slots 2..N  owned weapons / consumables, assigned by the server in the order you got them (profile.Hotbar),
	              re-orderable in the Backpack. Empty slots stay empty placeholders.
	There is deliberately no fake item: a slot is filled only by an item the server says you own.
]]

local HotbarConfig = {}

HotbarConfig.SlotCount = 8 -- number keys 1-8
HotbarConfig.Ability = { Id = "slap", Name = "Paws", Desc = "Slap thieves away. Press Q, tap Slap, or click while it is selected.", Icon = "fist" }

-- Valid slot keys are the strings "2".."SlotCount".
function HotbarConfig.validSlot(slot: any): boolean
	return type(slot) == "number" and slot % 1 == 0 and slot >= 2 and slot <= HotbarConfig.SlotCount
end

-- Inside one slot of `size` pixels, three areas that never overlap (the number top-left, the icon centred in the
-- middle band, the stack count bottom-right). The UI builds from this and the tests assert it. Rects: { x, y, w, h }.
function HotbarConfig.layout(size: number): { Number: { number }, Icon: { number }, Count: { number } }
	local band = size - 30 -- height of the icon band between the number row (15 px) and the count row (15 px)
	return {
		Number = { 4, 3, 18, 12 },
		Icon = { math.floor((size - band) / 2), 15, band, band },
		Count = { size - 30, size - 14, 27, 12 },
	}
end

return HotbarConfig
