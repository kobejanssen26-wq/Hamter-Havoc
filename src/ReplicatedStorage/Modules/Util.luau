--[[
	Small shared helpers (pure functions, usable on server and client).
]]

local Util = {}

function Util.clamp(value: number, minimum: number, maximum: number): number
	return math.max(minimum, math.min(maximum, value))
end

function Util.lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

function Util.round(value: number, decimals: number?): number
	local factor = 10 ^ (decimals or 0)
	return math.floor(value * factor + 0.5) / factor
end

function Util.countKeys(tbl: { [any]: any }): number
	local count = 0
	for _ in tbl do
		count += 1
	end
	return count
end

function Util.deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value do
		copy[key] = Util.deepCopy(inner)
	end
	return copy
end

-- Fills in every key of `template` that `target` is missing (recursively). Returns `target`.
function Util.reconcile(target: { [any]: any }, template: { [any]: any }): { [any]: any }
	for key, defaultValue in template do
		if target[key] == nil then
			target[key] = Util.deepCopy(defaultValue)
		elseif type(target[key]) == "table" and type(defaultValue) == "table" then
			Util.reconcile(target[key], defaultValue)
		end
	end
	return target
end

-- weights: array of non-negative numbers. Returns the chosen index (or nil if all zero).
function Util.weightedIndex(weights: { number }, random: Random): number?
	local total = 0
	for _, weight in weights do
		total += weight
	end
	if total <= 0 then
		return nil
	end
	local roll = random:NextNumber() * total
	local accumulated = 0
	for index, weight in weights do
		accumulated += weight
		if roll <= accumulated and weight > 0 then
			return index
		end
	end
	for index = #weights, 1, -1 do
		if weights[index] > 0 then
			return index
		end
	end
	return nil
end

function Util.sortedKeys(tbl: { [string]: any }): { string }
	local keys = {}
	for key in tbl do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

return Util
