-- Runs inside the mock Roblox runtime (see ../harness). For every asset in ModelLibrary it:
--   1. calls the asset's build-model.lua (which uses the game's REAL builder modules from src/),
--   2. validates the result,
--   3. prints it as JSON ("EXPORT|<name>|<json>") for export_models.py, which turns it into a genuine .rbxm.
-- Nothing here is specific to one asset: add a ModelLibrary/<Category>/<Asset>/ folder and it is picked up.

local CLASS_SKIP_PROPS = { Parent = true, Name = true, ClassName = true, Archivable = true }
local warnings = {}

---------------------------------------------------------------------------
-- instance -> json
---------------------------------------------------------------------------
local function numberText(n)
	if n ~= n or n == math.huge or n == -math.huge then
		return "0"
	end
	if n == math.floor(n) and math.abs(n) < 1e15 then
		return string.format("%d", n)
	end
	return string.format("%.9g", n)
end

local function jsonString(s)
	return '"' .. string.gsub(s, '[%c"\\]', function(c)
		if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" elseif c == "\n" then return "\\n" elseif c == "\t" then return "\\t" elseif c == "\r" then return "\\r" end
		return string.format("\\u%04x", string.byte(c))
	end) .. '"'
end

-- Returns json for a value Rojo understands, "REF" for instance references, or nil when unsupported.
local function encodeValue(v, forAttribute)
	local t = type(v)
	if t == "number" then
		return numberText(v)
	elseif t == "boolean" then
		return tostring(v)
	elseif t == "string" then
		return jsonString(v)
	end
	if RawData[v] then
		return "REF"
	end
	if t == "table" and rawget(v, "EnumType") ~= nil then
		return jsonString(v.Name)
	end
	local kind = typeof(v)
	local function wrap(name, body)
		return forAttribute and ('{"' .. name .. '":' .. body .. "}") or body
	end
	if kind == "CFrame" and forAttribute then
		local r = v.r
		return string.format(
			'{"CFrame":{"position":[%s,%s,%s],"orientation":[[%s,%s,%s],[%s,%s,%s],[%s,%s,%s]]}}',
			numberText(v.X), numberText(v.Y), numberText(v.Z), numberText(r[1]), numberText(r[2]), numberText(r[3]), numberText(r[4]), numberText(r[5]), numberText(r[6]), numberText(r[7]), numberText(r[8]), numberText(r[9])
		)
	elseif kind == "CFrame" then
		local r = v.r
		local parts = { numberText(v.X), numberText(v.Y), numberText(v.Z) }
		for i = 1, 9 do
			table.insert(parts, numberText(r[i]))
		end
		return "[" .. table.concat(parts, ",") .. "]"
	elseif kind == "Vector3" then
		return wrap("Vector3", string.format("[%s,%s,%s]", numberText(v.X), numberText(v.Y), numberText(v.Z)))
	elseif kind == "Vector2" then
		return wrap("Vector2", string.format("[%s,%s]", numberText(v.X), numberText(v.Y)))
	elseif kind == "Color3" then
		return wrap("Color3", string.format("[%s,%s,%s]", numberText(v.R), numberText(v.G), numberText(v.B)))
	elseif kind == "UDim2" then
		return string.format('{"UDim2":[[%s,%s],[%s,%s]]}', numberText(v.X.Scale), numberText(v.X.Offset), numberText(v.Y.Scale), numberText(v.Y.Offset))
	elseif kind == "UDim" then
		return string.format('{"UDim":[%s,%s]}', numberText(v.Scale), numberText(v.Offset))
	end
	return nil
end

local function sortedKeys(map)
	local keys = {}
	for key in map do
		table.insert(keys, key)
	end
	table.sort(keys)
	return keys
end

local function serialize(root, assetName)
	local ordinal = {}
	local list = {}
	local function number(inst)
		ordinal[inst] = #list
		table.insert(list, inst)
		for _, child in RawData[inst].Children do
			number(child)
		end
	end
	number(root)

	local refs = {}
	local function node(inst)
		local data = RawData[inst]
		local props, attrs, tags, children = {}, {}, {}, {}
		for _, key in sortedKeys(data.Props) do
			if not CLASS_SKIP_PROPS[key] then
				local value = data.Props[key]
				local enc = encodeValue(value, false)
				if enc == "REF" then
					if ordinal[value] == nil then
						table.insert(warnings, string.format("%s: %s.%s points outside the exported model (dropped)", assetName, data.Name, key))
					else
						table.insert(refs, string.format('{"owner":%d,"prop":%s,"target":%d}', ordinal[inst], jsonString(key), ordinal[value]))
					end
				elseif enc then
					table.insert(props, jsonString(key) .. ":" .. enc)
				else
					table.insert(warnings, string.format("%s: property %s.%s of type %s not exported", assetName, data.Name, key, typeof(value)))
				end
			end
		end
		for _, key in sortedKeys(data.Attributes) do
			local enc = encodeValue(data.Attributes[key], true)
			if enc and enc ~= "REF" then
				table.insert(attrs, jsonString(key) .. ":" .. enc)
			else
				table.insert(warnings, string.format("%s: attribute %s.%s not exported", assetName, data.Name, key))
			end
		end
		for _, tag in sortedKeys(data.Tags) do
			table.insert(tags, jsonString(tag))
		end
		for _, child in data.Children do
			table.insert(children, node(child))
		end
		return string.format(
			'{"class":%s,"name":%s,"props":{%s},"attrs":{%s},"tags":[%s],"children":[%s]}',
			jsonString(data.ClassName), jsonString(data.Name), table.concat(props, ","), table.concat(attrs, ","), table.concat(tags, ","), table.concat(children, ",")
		)
	end
	local tree = node(root)
	return string.format('{"tree":%s,"refs":[%s],"count":%d}', tree, table.concat(refs, ","), #list), #list
end

---------------------------------------------------------------------------
-- validation
---------------------------------------------------------------------------
local function validate(asset, root)
	local problems = {}
	local config = asset.Config
	if not root or not RawData[root] then
		return { "build-model.lua returned no instance" }
	end
	local data = RawData[root]
	if config.RootClass and data.ClassName ~= config.RootClass then
		table.insert(problems, "root class is " .. data.ClassName .. ", expected " .. config.RootClass)
	end
	if data.Name ~= (config.RootName or config.Name) then
		table.insert(problems, "root name is " .. data.Name .. ", expected " .. (config.RootName or config.Name))
	end
	local parts, motors = 0, 0
	local function walk(inst)
		local d = RawData[inst]
		if d.ClassName == "Part" or d.ClassName == "WedgePart" or d.ClassName == "MeshPart" then
			parts += 1
			if d.Props.Size == nil then
				table.insert(problems, d.Name .. " has no Size")
			end
		elseif d.ClassName == "Motor6D" then
			motors += 1
			if d.Props.Part0 == nil or d.Props.Part1 == nil then
				table.insert(problems, "Motor6D " .. d.Name .. " is missing Part0/Part1")
			end
		end
		for _, child in d.Children do
			walk(child)
		end
	end
	walk(root)
	if config.MinParts and parts < config.MinParts then
		table.insert(problems, string.format("only %d parts, expected at least %d", parts, config.MinParts))
	end
	if config.PrimaryPart ~= false then
		-- the root (or, for a Folder pack, each item in it) must have a defined pivot; nested helper models need none
		local function checkPivot(inst)
			local d = RawData[inst]
			if d.ClassName == "Model" and d.Props.PrimaryPart == nil then
				table.insert(problems, "Model " .. d.Name .. " has no PrimaryPart (its pivot would be undefined)")
			end
		end
		checkPivot(root)
		if data.ClassName == "Folder" then
			for _, child in data.Children do
				checkPivot(child)
			end
		end
	end
	return problems, parts, motors
end

-- axis-aligned bounds of all parts, in the coordinate frame of the root's pivot
local function bounds(root)
	local pivot = RawData[root].ClassName == "Model" and root:GetPivot() or nil
	local min, max = nil, nil
	for _, inst in M.descendants(root) do
		local d = RawData[inst]
		local size, cf = d.Props.Size, d.Props.CFrame
		if size and cf and not (d.Props.Transparency == 1 and d.ClassName == "Part" and size.X < 0.5) then
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local p = cf:PointToWorldSpace(Vector3.new(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2))
						if pivot then
							p = pivot:PointToObjectSpace(p)
						end
						min = min and Vector3.new(math.min(min.X, p.X), math.min(min.Y, p.Y), math.min(min.Z, p.Z)) or p
						max = max and Vector3.new(math.max(max.X, p.X), math.max(max.Y, p.Y), math.max(max.Z, p.Z)) or p
					end
				end
			end
		end
	end
	return min, max
end

