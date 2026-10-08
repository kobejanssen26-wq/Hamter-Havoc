local Runtime = require("./runtime")
Runtime.boot(".")
local R = Runtime.mod("RarityConfig")
local D = Runtime.mod("HamsterDatabase")
local prevMaxP, prevMaxI = 0, 0
for _, id in R.Order do
	local pool = D.ByRarity[id]
	local minP, maxP, minI, maxI = math.huge, 0, math.huge, 0
	for _, s in pool do
		local p, i = D.price(s), D.income(s)
		minP = math.min(minP, p); maxP = math.max(maxP, p); minI = math.min(minI, i); maxI = math.max(maxI, i)
	end
	print(string.format("%-10s n=%2d price %14.0f..%14.0f  income %12.2f..%12.2f  ok=%s", id, #pool, minP, maxP, minI, maxI, tostring(minP > prevMaxP and minI > prevMaxI)))
	prevMaxP, prevMaxI = maxP, maxI
end
