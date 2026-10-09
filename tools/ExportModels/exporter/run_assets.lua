-- Exports every ModelLibrary asset (needs context.lua + serialize.lua before it).
---------------------------------------------------------------------------
-- run
---------------------------------------------------------------------------
local failures = 0
for _, asset in ASSETS do
	local config = asset.Config
	local ctx = newContext(asset)
	local ok, result = pcall(asset.Build, ctx)
	if not ok then
		failures += 1
		print("FAIL|" .. config.Name .. "|" .. tostring(result))
	else
		local problems, parts, motors = validate(asset, result)
		if #problems > 0 then
			failures += 1
			print("FAIL|" .. config.Name .. "|" .. table.concat(problems, "; "))
		else
			local json, count = serialize(result, config.Name)
			local meta = string.format(
				'{"name":%s,"title":%s,"category":%s,"file":%s,"dir":%s,"dependencies":%s,"reusable":%s,"instances":%d,"parts":%d,"motors":%d}',
				jsonString(config.Name), jsonString(config.Title or config.Name), jsonString(config.Category), jsonString(config.File or (config.Name .. ".rbxm")), jsonString(asset.Dir),
				jsonString(config.Dependencies or "None"), jsonString(config.Reusable or "Yes"), count, parts, motors
			)
			print("META|" .. config.Name .. "|" .. meta)
			local lo, hi = bounds(result)
			if lo then
				print(string.format("INFO|%s|bounds in pivot space: x %.2f..%.2f  y %.2f..%.2f  z %.2f..%.2f  (size %.2f x %.2f x %.2f)", config.Name, lo.X, hi.X, lo.Y, hi.Y, lo.Z, hi.Z, hi.X - lo.X, hi.Y - lo.Y, hi.Z - lo.Z))
			end
			print("EXPORT|" .. config.Name .. "|" .. json)
		end
	end
end
for _, warning in warnings do
	print("WARN|" .. warning)
end
print("DONE|" .. #ASSETS .. "|" .. failures)
