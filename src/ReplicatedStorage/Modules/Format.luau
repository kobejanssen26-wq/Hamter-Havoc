--[[
	Number / time formatting shared by UI and world signs.
]]

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

-- 1234567 -> "1.23M"   (always rounds down so players never see more than they own)
function Format.short(value: number): string
	if value ~= value then
		return "0"
	end
	if value < 0 then
		return "-" .. Format.short(-value)
	end
	if value < 1000 then
		if value < 10 and value ~= math.floor(value) then
			return string.format("%.1f", math.floor(value * 10) / 10)
		end
		return tostring(math.floor(value))
	end
	local index = math.floor(math.log10(value) / 3)
	if index >= #SUFFIXES then
		return string.format("%.2e", value)
	end
	local scaled = value / (1000 ^ index)
	local text
	if scaled >= 100 then
		text = string.format("%d", math.floor(scaled))
	elseif scaled >= 10 then
		text = string.format("%.1f", math.floor(scaled * 10) / 10)
	else
		text = string.format("%.2f", math.floor(scaled * 100) / 100)
	end
	return text .. SUFFIXES[index + 1]
end

-- 250000 -> "250,000"
function Format.commas(value: number): string
	local digits = string.format("%.0f", math.floor(value))
	local reversed = string.reverse(digits)
	reversed = string.gsub(reversed, "(%d%d%d)", "%1,")
	local result = string.reverse(reversed)
	result = string.gsub(result, "^,", "")
	return result
end

function Format.coins(value: number): string
	return "$" .. Format.short(value)
end

-- 3.5 -> "x3.5"
function Format.multiplier(value: number): string
	if math.abs(value - math.floor(value)) < 0.005 then
		return string.format("x%d", math.floor(value))
	end
	return string.format("x%.2f", value):gsub("0+$", ""):gsub("%.$", "")
end

-- 125 -> "2:05"
function Format.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local minutes = math.floor(seconds / 60)
	local secs = seconds % 60
	if minutes >= 60 then
		return string.format("%d:%02d:%02d", math.floor(minutes / 60), minutes % 60, secs)
	end
	return string.format("%d:%02d", minutes, secs)
end

function Format.percent(fraction: number): string
	return string.format("%d%%", math.floor(fraction * 100 + 0.5))
end

-- Color3 -> "RRGGBB" for RichText
function Format.hex(color: Color3): string
	return color:ToHex()
end

function Format.rich(text: string, color: Color3, bold: boolean?): string
	local inner = bold and ("<b>" .. text .. "</b>") or text
	return string.format('<font color="#%s">%s</font>', color:ToHex(), inner)
end

return Format
