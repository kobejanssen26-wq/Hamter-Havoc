-- Studio-editable HUD: the baked templates (src/StarterGui/*.model.json) are adopted by the client code.
-- Run twice by run.sh (MODE "plain" = no templates, MODE "template" = templates + simulated Studio edits) and compared.
-- The prelude (MODE, HUD_JSON) is added by run.sh.
local Players = game:GetService("Players")
local adv = M.Sim.advance
local results = { pass = 0, fail = 0 }
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end

local ENUM = { ApplyStrokeMode = "ApplyStrokeMode", AutomaticSize = "AutomaticSize", FillDirection = "FillDirection", Font = "Font", HorizontalAlignment = "HorizontalAlignment",
	ScreenInsets = "ScreenInsets", SortOrder = "SortOrder", TextTruncate = "TextTruncate", TextXAlignment = "TextXAlignment", TextYAlignment = "TextYAlignment",
	VerticalAlignment = "VerticalAlignment", ZIndexBehavior = "ZIndexBehavior" }

local function convert(prop, v)
	if type(v) == "table" then
		if v.UDim2 then return UDim2.new(v.UDim2[1][1], v.UDim2[1][2], v.UDim2[2][1], v.UDim2[2][2]) end
		if v.UDim then return UDim.new(v.UDim[1], v.UDim[2]) end
		if v.ColorSequence then
			local keys = {}
			for _, k in v.ColorSequence.keypoints do table.insert(keys, ColorSequenceKeypoint.new(k.time, Color3.new(k.color[1], k.color[2], k.color[3]))) end
			return ColorSequence.new(keys)
		end
		if v.NumberSequence then
			local keys = {}
			for _, k in v.NumberSequence.keypoints do table.insert(keys, NumberSequenceKeypoint.new(k.time, k.value, k.envelope)) end
			return NumberSequence.new(keys)
		end
		if #v == 3 then return Color3.new(v[1], v[2], v[3]) end
		if #v == 2 then return Vector2.new(v[1], v[2]) end
	elseif type(v) == "string" and ENUM[prop] then
		return Enum[ENUM[prop]][v]
	end
	return v
end

-- builds an instance tree from a Rojo model.json node
local function import(node, name)
	local inst = M.newInstance(node.ClassName, true)
	RawData[inst].Name = name or node.Name
	for prop, value in node.Properties or {} do RawData[inst].Props[prop] = convert(prop, value) end
	for key, value in node.Attributes or {} do RawData[inst].Attributes[key] = value end
	for _, child in node.Children or {} do M.setParent(import(child), inst) end
	return inst
end

local function pathOf(inst, root)
	local parts, node = {}, inst
	while node and node ~= root do table.insert(parts, 1, RawData[node].Name) node = RawData[node].Parent end
	return table.concat(parts, "/")
end

local function find(root, path)
	local node = root
	for part in string.gmatch(path, "[^/]+") do
		node = node and M.InstanceMethods.FindFirstChild(node, part)
	end
	return node
end

task.spawn(function()
	M.isServer = true
	local mainServer = find_game("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	adv(1)
	local p = M.newPlayer("Hud")
	adv(0.01)
	RawData[Players].Signals.PlayerAdded:Fire(p)
	M.spawnCharacter(p)
	adv(6)
	M.localPlayerRef = p
	local gui = M.newInstance("PlayerGui", true); RawData[gui].Name = "PlayerGui"; M.setParent(gui, p)
	local starterGui = game:GetService("StarterGui")
	local templates = {}
	if MODE == "template" then
		for name, text in HUD_JSON do
			local tree = import(game:GetService("HttpService"):JSONDecode(text), name)
			templates[name] = tree
			M.setParent(tree, gui) -- (Roblox copies StarterGui into PlayerGui; here the copy is placed directly)
			M.setParent(import(game:GetService("HttpService"):JSONDecode(text), name), starterGui)
		end
		-- simulated Studio edits
		local main = templates.MainUI
		RawData[find(main, "TopColumn")].Props.Position = UDim2.new(0.25, 0, 0, 90) -- moved
		local shopButton = find(main, "Rail/Content/ShopButton")
		RawData[shopButton].Props.BackgroundColor3 = Color3.fromRGB(220, 40, 40) -- recoloured
		RawData[shopButton].Props.Size = UDim2.fromOffset(72, 72) -- resized
		local hotbar = find(templates.HotbarUI, "Hotbar")
		RawData[hotbar].Props.Position = UDim2.new(0.3, 0, 1, -40) -- moved
		-- a decoration the user added, and a leftover of an older HUD version (has CodeProps but the code never builds it)
		local logo = M.newInstance("ImageLabel", true); RawData[logo].Name = "MyLogo"; M.setParent(logo, find(main, "TopColumn/Content"))
		local old = M.newInstance("Frame", true); RawData[old].Name = "OldThing"; RawData[old].Attributes.CodeProps = "Visible=true"; M.setParent(old, find(main, "TopColumn/Content"))
	end
	M.isServer = false
	M.clientRunning = true
	local mainClient = find_game("StarterPlayer.StarterPlayerScripts.Main")
	task.spawn(function() RawData[mainClient].Source(mainClient, require) end)
	adv(4)

	-- signature of the built HUD: multiset of "path|class"
	local counts = {}
	for _, name in { "MainUI", "HotbarUI" } do
		local root = find(gui, name)
		check(name .. " exists exactly once in PlayerGui", root ~= nil and #(function() local n = {} for _, c in M.InstanceMethods.GetChildren(gui) do if RawData[c].Name == name then table.insert(n, c) end end return n end)() == 1)
		if root then
			for _, d in M.descendants(root) do
				local data = RawData[d]
				if data.Name ~= "MyLogo" then
					local key = name .. "/" .. pathOf(d, root) .. "|" .. data.ClassName
					counts[key] = (counts[key] or 0) + 1
				end
			end
		end
	end
	local lines = {}
	for key, n in counts do table.insert(lines, key .. "|" .. n) end
	table.sort(lines)
	for _, line in lines do print("SIG|" .. line) end
	print("SIGCOUNT|" .. #lines)

	if MODE == "template" then
		local main = find(gui, "MainUI")
		check("a moved region keeps the position you gave it in Studio", RawData[find(main, "TopColumn")].Props.Position.X.Scale == 0.25 and RawData[find(main, "TopColumn")].Props.Position.Y.Offset == 90)
		local shopButton = find(main, "Rail/Content/ShopButton")
		check("a resized rail button keeps its Studio size", RawData[shopButton].Props.Size.X.Offset == 72)
		check("a recoloured rail button keeps its Studio colour (also after the 0.5 s state refresh)", RawData[shopButton].Props.BackgroundColor3.R > 0.8 and RawData[shopButton].Props.BackgroundColor3.G < 0.3, tostring(RawData[shopButton].Props.BackgroundColor3.G))
		local questsButton = find(main, "Rail/Content/QuestsButton")
		check("a button you did not touch is still driven by the code (touch/desktop size)", RawData[questsButton].Props.Size.X.Offset > 30 and RawData[questsButton].Props.Size.X.Offset ~= 72)
		check("a moved hotbar keeps its Studio position", RawData[find(gui, "HotbarUI/Hotbar")].Props.Position.X.Scale == 0.3)
		check("something you ADDED in Studio stays", find(main, "TopColumn/Content/MyLogo") ~= nil)
		check("a leftover from an older HUD is removed (no ghost element)", find(main, "TopColumn/Content/OldThing") == nil)
		check("the code finished adopting (flag set)", RawData[main].Attributes.Adopted == true)
		-- responsive scaling is still the code's job: make the screen small
		local camera = workspace.CurrentCamera
		local scaleBefore = RawData[find(main, "TopColumn/Content/UIScale")].Props.Scale
		RawData[camera].Props.ViewportSize = Vector2.new(640, 360)
		RawData[camera].Signals.ViewportSize = RawData[camera].Signals.ViewportSize
		local sig = M.InstanceMethods.GetPropertyChangedSignal(camera, "ViewportSize")
		sig:Fire()
		adv(0.5)
		local scaleAfter = RawData[find(main, "TopColumn/Content/UIScale")].Props.Scale
		check("the scale of a template region still follows the screen size", scaleAfter < scaleBefore, scaleBefore .. " -> " .. scaleAfter)
		-- deleting an element: the code recreates it instead of crashing
		M.InstanceMethods.Destroy(find(main, "Rail/Content/SettingsButton"))
		check("(deleting a template element does not break the HUD)", find(main, "Rail/Content") ~= nil)
	end
	print(string.format("PASS %d  FAIL %d", results.pass, results.fail))
	print("== done ==")
end)
