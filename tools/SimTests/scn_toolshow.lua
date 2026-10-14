-- Exports every tool model (weapons and gadgets) for tools/WorldPreview. Run: tools/SimTests/run.sh scn_toolshow.lua
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

-- every weapon / gadget tool, built by the REAL ToolBuilder, laid out in a row: world/ToolShowcase (only used by tools/WorldPreview)
local ItemRegistry = require(find("ReplicatedStorage.Modules.ItemRegistry"))
local ToolBuilder = require(find("ServerScriptService.Systems.ToolBuilder"))
local root = M.newInstance("Folder", true)
RawData[root].Name = "ToolShowcase"
local index = 0
for _, def in ItemRegistry.List do
	if def.Equip.Kind == "Tool" then
		index += 1
		local tool = ToolBuilder.build(def)
		local model = M.newInstance("Model", true)
		RawData[model].Name = def.Id
		for _, child in M.descendants(tool) do
			local data = RawData[child]
			if data.Props and data.Props.CFrame and data.Props.Size then
				local cf = data.Props.CFrame
				data.Props.CFrame = CFrame.new(index * 14, 6, 0) * cf
				data.Props.Anchored = true
			end
		end
		for _, child in tool:GetChildren() do
			if M.InstanceMethods.IsA(child, "BasePart") then M.setParent(child, model) end
		end
		M.setParent(model, root)
	end
end
-- the open glider wing above a stand-in character
do
	local MobilitySystem = require(find("ServerScriptService.Systems.MobilitySystem"))
	local character = M.newInstance("Model", true)
	RawData[character].Name = "gliding_player"
	local rootPart = M.newInstance("Part", true)
	RawData[rootPart].Name = "HumanoidRootPart"
	RawData[rootPart].Props.Size = Vector3.new(2, 2, 1)
	RawData[rootPart].Props.CFrame = CFrame.new((index + 1) * 14, 8, 0)
	RawData[rootPart].Props.Anchored = true
	RawData[rootPart].Props.Color = Color3.fromRGB(255, 200, 120)
	M.setParent(rootPart, character)
	local head = M.newInstance("Part", true)
	RawData[head].Name = "Head"
	RawData[head].Props.Size = Vector3.new(1.4, 1.4, 1.4)
	RawData[head].Props.CFrame = CFrame.new((index + 1) * 14, 9.7, 0)
	RawData[head].Props.Anchored = true
	M.setParent(head, character)
	local legs = M.newInstance("Part", true)
	RawData[legs].Name = "Legs"
	RawData[legs].Props.Size = Vector3.new(1.6, 2, 1)
	RawData[legs].Props.CFrame = CFrame.new((index + 1) * 14, 6, 0)
	RawData[legs].Props.Anchored = true
	M.setParent(legs, character)
	M.setParent(character, root)
	local wingModel = MobilitySystem.buildWing(character, rootPart, ItemRegistry.get("sky_glider").Equip.Weapon.Look)
	for _, d in M.descendants(wingModel) do
		if RawData[d].Props and RawData[d].Props.Anchored ~= nil then RawData[d].Props.Anchored = true end
	end
end
print("BAKE|ToolShowcase|" .. export(root))
