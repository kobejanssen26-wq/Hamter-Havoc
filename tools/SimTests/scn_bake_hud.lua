-- Exports the HUD ScreenGuis (MainUI, HotbarUI) exactly as the client code builds them, as Rojo .model.json lines on stdout.
-- Used by bake_hud.sh to write src/StarterGui/*.model.json: the Studio-editable HUD templates (see docs/STUDIO_GUIDE.md).
local Players = game:GetService("Players")
local adv = M.Sim.advance

local SKIP_PROPS = { Parent = true, Name = true, PrimaryPart = true, Adornee = true, Archivable = true, ClassName = true, CurrentCamera = true, Text = false }
local SKIP_CLASSES = { Script = true, LocalScript = true, ModuleScript = true, Camera = true, ViewportFrame = false }

local function esc(s)
	return '"' .. string.gsub(s, '[%c"\\]', function(c)
		if c == '"' then return '\\"' elseif c == "\\" then return "\\\\" elseif c == "\n" then return "\\n" elseif c == "\t" then return "\\t" end
		return string.format("\\u%04x", string.byte(c))
	end) .. '"'
end
local function int(n) -- UDim offsets are whole numbers in Roblox (Rojo refuses fractions); the engine truncates toward zero
	if n >= 0 then return math.floor(n) else return math.ceil(n) end
end
local function num(n)
	if n ~= n or n == math.huge or n == -math.huge then return "0" end
	return string.format("%.6g", n)
end
local function field(v, k)
	local ok, r = pcall(function() return v[k] end)
	if ok then return r end
	return nil
end
local function encode(v)
	local t = type(v)
	if t == "number" then return num(v) end
	if t == "boolean" then return tostring(v) end
	if t == "string" then return esc(v) end
	if t ~= "table" and t ~= "userdata" then return nil end
	if RawData[v] then return nil end
	if t == "table" and rawget(v, "EnumType") ~= nil then return esc(v.Name) end
	local keypoints = rawget(v, "Keypoints")
	if keypoints then
		local out = {}
		for _, key in keypoints do
			if type(key.Value) == "number" then
				table.insert(out, string.format('{"time":%s,"value":%s,"envelope":%s}', num(key.Time), num(key.Value), num(key.Envelope or 0)))
			else
				table.insert(out, string.format('{"time":%s,"color":[%s,%s,%s]}', num(key.Time), num(key.Value.R), num(key.Value.G), num(key.Value.B)))
			end
		end
		local first = keypoints[1] and keypoints[1].Value
		local name = if type(first) == "number" then "NumberSequence" else "ColorSequence"
		return string.format('{"%s":{"keypoints":[%s]}}', name, table.concat(out, ","))
	end
	local R, G, B = field(v, "R"), field(v, "G"), field(v, "B")
	if type(R) == "number" and type(G) == "number" and type(B) == "number" then
		return string.format("[%s,%s,%s]", num(R), num(G), num(B))
	end
	local X, Y = field(v, "X"), field(v, "Y")
	if type(X) == "number" and type(Y) == "number" then
		return string.format("[%s,%s]", num(X), num(Y))
	end
	local xs, xo = field(X, "Scale"), field(X, "Offset")
	local ys, yo = field(Y, "Scale"), field(Y, "Offset")
	if type(xs) == "number" and type(ys) == "number" then
		return string.format('{"UDim2":[[%s,%s],[%s,%s]]}', num(xs), int(xo), num(ys), int(yo))
	end
	local scale, offset = field(v, "Scale"), field(v, "Offset")
	if type(scale) == "number" and type(offset) == "number" then
		return string.format('{"UDim":[%s,%s]}', num(scale), int(offset))
	end
	return nil
end

local function export(inst)
	local data = RawData[inst]
	if SKIP_CLASSES[data.ClassName] then return nil end
	if data.Attributes.IconId ~= nil then return nil end -- icons are drawn by the code, not part of the templates
	local props, names = {}, {}
	for k in data.Props do table.insert(names, k) end
	table.sort(names)
	for _, k in names do
		if not SKIP_PROPS[k] then
			local enc = encode(data.Props[k])
			if enc then table.insert(props, esc(k) .. ":" .. enc) end
		end
	end
	local attrs, anames = {}, {}
	for k in data.Attributes do table.insert(anames, k) end
	table.sort(anames)
	for _, k in anames do
		local v = data.Attributes[k]
		if (type(v) == "number" or type(v) == "string" or type(v) == "boolean") and k ~= "BaseAlpha" then
			table.insert(attrs, esc(k) .. ":" .. encode(v))
		end
	end
	local children = {}
	-- icon artwork is drawn by the code at runtime: the template keeps only the (empty) root frame
	if data.Attributes.IconId == nil then
		for _, child in data.Children do
			local enc = export(child)
			if enc then table.insert(children, enc) end
		end
	end
	local parts = { '"ClassName":' .. esc(data.ClassName), '"Name":' .. esc(data.Name) }
	if #props > 0 then table.insert(parts, '"Properties":{' .. table.concat(props, ",") .. "}") end
	if #attrs > 0 then table.insert(parts, '"Attributes":{' .. table.concat(attrs, ",") .. "}") end
	if #children > 0 then table.insert(parts, '"Children":[' .. table.concat(children, ",") .. "]") end
	return "{" .. table.concat(parts, ",") .. "}"
end

task.spawn(function()
	M.isServer = true
	game:GetService("ReplicatedStorage"):SetAttribute("HudBake", true)
	local mainServer = find("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	adv(1)
	local p = M.newPlayer("Baker")
	adv(0.01)
	RawData[Players].Signals.PlayerAdded:Fire(p)
	M.spawnCharacter(p)
	adv(6)
	M.localPlayerRef = p
	local gui = M.newInstance("PlayerGui", true); RawData[gui].Name = "PlayerGui"; M.setParent(gui, p)
	M.isServer = false
	M.clientRunning = true
	local mainClient = find("StarterPlayer.StarterPlayerScripts.Main")
	task.spawn(function() RawData[mainClient].Source(mainClient, require) end)
	adv(4)
	for _, name in { "MainUI", "HotbarUI" } do
		local screen = M.InstanceMethods.FindFirstChild(gui, name)
		if screen then require(find("StarterPlayer.StarterPlayerScripts.UI.UIKit")).sealBake(screen) end
		if screen then print("BAKE|" .. name .. "|" .. export(screen)) end
	end
end)
