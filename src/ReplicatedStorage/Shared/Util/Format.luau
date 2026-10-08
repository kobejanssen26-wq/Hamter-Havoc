local Format = {}

-- 250000 -> "$250,000"
function Format.money(amount: number): string
	local digits = string.format("%.0f", math.floor(amount))
	local reversed = string.reverse(digits)
	reversed = string.gsub(reversed, "(%d%d%d)", "%1,")
	local result = string.reverse(reversed)
	result = string.gsub(result, "^,", "")
	return "$" .. result
end

return Format
