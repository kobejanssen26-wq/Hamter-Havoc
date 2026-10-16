-- Exports the generated world (and a showcase of every hamster) as Rojo .model.json lines on stdout.
M.isServer = true
local mainServer = find("ServerScriptService.Main")
task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
M.Sim.advance(1)

local SKIP_PROPS = { Parent = true, Name = true, PrimaryPart = true, Adornee = true, Attachment0 = true, Attachment1 = true, Archivable = true, ClassName = true }
local SKIP_CLASSES = { ParticleEmitter = true, Motor6D = true, Highlight = true, Beam = true, Trail = true, Sound = true, Script = true, LocalScript = true, ModuleScript = true, Weld = true, WeldConstraint = true }

local function esc(s)
	return '"' .. string.gsub(s, '[%c"\\]', function(c)
		if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" elseif c == "\n" then return "\\n" elseif c == "\t" then return "\\t" end
		return string.format("\\u%04x", string.byte(c))
	end) .. '"'
end
local function num(n)
	if n ~= n or n == math.huge or n == -math.huge then return "0" end
	return string.format("%.5g", n)
end
local function field(v, k)
	local ok, r = pcall(function() return v[k] end)
	if ok then return r end
	return nil
end

-- returns json text or nil when the value can't be represented
local function encode(v)
	local t = type(v)
	if t == "number" then return num(v) end
	if t == "boolean" then return tostring(v) end
	if t == "string" then return esc(v) end
	if t ~= "table" and t ~= "userdata" then return nil end
	if RawData[v] then return nil end -- an Instance reference
	if t == "table" and rawget(v, "EnumType") ~= nil then return esc(v.Name) end
	local r = field(v, "r")
	if type(r) == "table" then
		return string.format("[%s,%s,%s,%s]", num(v.X), num(v.Y), num(v.Z), table.concat((function() local o = {} for i = 1, 9 do o[i] = num(r[i]) end return o end)(), ","))
	end
	local R, G, B = field(v, "R"), field(v, "G"), field(v, "B")
	if type(R) == "number" and type(G) == "number" and type(B) == "number" then
		return string.format("[%s,%s,%s]", num(R), num(G), num(B))
	end
	local X, Y, Z = field(v, "X"), field(v, "Y"), field(v, "Z")
	if type(X) == "number" and type(Y) == "number" and type(Z) == "number" then
		return string.format("[%s,%s,%s]", num(X), num(Y), num(Z))
	end
	if type(X) == "number" and type(Y) == "number" then
		return string.format("[%s,%s]", num(X), num(Y))
	end
	-- UDim2: X.Scale, X.Offset
	local xs, xo = field(X, "Scale"), field(X, "Offset")
	local ys, yo = field(Y, "Scale"), field(Y, "Offset")
	if type(xs) == "number" and type(ys) == "number" then
		return string.format('{"UDim2":[[%s,%s],[%s,%s]]}', num(xs), num(xo), num(ys), num(yo))
	end
	return nil
end

local function export(inst, out)
	local data = RawData[inst]
	if SKIP_CLASSES[data.ClassName] then return nil end
	local props = {}
	local names = {}
	for k in data.Props do table.insert(names, k) end
	table.sort(names)
	for _, k in names do
		if not SKIP_PROPS[k] then
			local enc = encode(data.Props[k])
			if enc then table.insert(props, esc(k) .. ":" .. enc) end
		end
	end
	local tagNames = {}
	for tag in data.Tags do table.insert(tagNames, tag) end
	table.sort(tagNames)
	if #tagNames > 0 then
		local quoted = {}
		for _, tag in tagNames do table.insert(quoted, esc(tag)) end
		table.insert(props, '"Tags":[' .. table.concat(quoted, ",") .. "]")
	end
	local attrs = {}
	local anames = {}
	for k in data.Attributes do table.insert(anames, k) end
	table.sort(anames)
	for _, k in anames do
		local v = data.Attributes[k]
		if type(v) == "number" or type(v) == "string" or type(v) == "boolean" then
			table.insert(attrs, esc(k) .. ":" .. encode(v))
		end
	end
	local children = {}
	for _, child in data.Children do
		local enc = export(child)
		if enc then table.insert(children, enc) end
	end
	local parts = { '"ClassName":' .. esc(data.ClassName), '"Name":' .. esc(data.Name) }
	if #props > 0 then table.insert(parts, '"Properties":{' .. table.concat(props, ",") .. "}") end
	if #attrs > 0 then table.insert(parts, '"Attributes":{' .. table.concat(attrs, ",") .. "}") end
	if #children > 0 then table.insert(parts, '"Children":[' .. table.concat(children, ",") .. "]") end
	return "{" .. table.concat(parts, ",") .. "}"
end

-- preview: show towers with 1..5 floors so the editor shows how the building grows with rebirths
do
	local HouseSystem = require(find("ServerScriptService.Systems.HouseSystem"))
	local HouseBuilder = require(find("ServerScriptService.Systems.WorldBuilder.HouseBuilder"))
	local FloorConfig = require(find("ReplicatedStorage.Modules.FloorConfig"))
	local previewFloors = { 1, 2, 3, 4, 5, 3, 2, 1 }
	local rng = Random.new(3)
	for index, house in HouseSystem.all() do
		HouseBuilder.setFloors(house, previewFloors[index] or 1, rng)
		house.Labels.Roof.Text = string.format("Preview: %d floor%s", previewFloors[index] or 1, if (previewFloors[index] or 1) > 1 then "s" else "")
	end
end

for _, name in { "HamsterPlaza", "LeaderboardHall", "HamsterPath", "PlayerHouses", "Environment", "SpawnLocations" } do
	local folder = workspace:FindFirstChild(name)
	if folder then print("BAKE|" .. name .. "|" .. export(folder)) end
end

-- showcase: every hamster, grouped by rarity, laid out in rows south of the map
local HamsterDatabase = require(find("ReplicatedStorage.Modules.HamsterDatabase"))
local HamsterBuilder = require(find("ReplicatedStorage.Modules.HamsterBuilder"))
local RarityConfig = require(find("ReplicatedStorage.Modules.RarityConfig"))
local root = M.newInstance("Folder", true)
RawData[root].Name = "HamsterShowcase"
for rowIndex, rarityId in RarityConfig.Order do
	local rarityFolder = M.newInstance("Folder", true)
	RawData[rarityFolder].Name = string.format("%02d_%s", rowIndex, RarityConfig.ById[rarityId].Name)
	M.setParent(rarityFolder, root)
	for index, species in HamsterDatabase.ByRarity[rarityId] do
		local model = HamsterBuilder.build(species, { Scale = 1, LowDetail = false, Particles = false })
		RawData[model].Name = species.Name .. (if species.Exclusive then " (exclusive)" else "")
		model:PivotTo(CFrame.new(-190 + (index - 1) * 8, 0.5, -250 - (rowIndex - 1) * 14) * CFrame.Angles(0, math.rad(180), 0))
		M.setParent(model, rarityFolder)
	end
end
print("BAKE|HamsterShowcase|" .. export(root))
