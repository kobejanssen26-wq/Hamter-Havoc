--!nocheck
--[[
	Export To Model Library - a Roblox Studio plugin.

	Install:   Studio -> Plugins -> Plugins Folder, copy this file in (it must be a *.lua / *.luau plugin script), restart Studio.
	           (or: right-click this Script in Explorer -> "Save as Local Plugin...")
	Use:       select ONE model (or folder / script) in Explorer, press the "Export to Library" button.

	What it does
	  1. validates the selection (exactly one instance, Models have a pivot, no secrets / server-only systems / external asset ids in scripts)
	  2. prints a report (instances, parts, scripts, dependencies it found) in the Output window
	  3. opens Studio's save dialog with the library file name  <Category>__<Name>.rbxm  (Category comes from the attribute
	     `LibraryCategory` on the selected instance, default "Misc"); save it into  ModelLibrary/<Category>/  and name it  <Name>.rbxm
	  4. never overwrites silently: Studio's own dialog asks before replacing a file, and git shows the change

	Afterwards run   python3 tools/ExportModels/export_models.py   to refresh the catalog (README.md) and commit.
	Studio can only save through its dialog - a plugin cannot write into your repository folder directly.
]]

local Selection = game:GetService("Selection")

local toolbar = plugin:CreateToolbar("Model Library")
local button = toolbar:CreateButton("Export to Library", "Validate the selected model and save it as .rbxm", "")

local FORBIDDEN_IN_SCRIPTS = {
	{ "DataStoreService", "uses DataStores (game-specific, server only)" },
	{ "HttpService", "uses HttpService (check it contains no URLs or secrets)" },
	{ "MessagingService", "uses MessagingService (game-specific)" },
	{ "MarketplaceService", "uses MarketplaceService (product ids are game-specific)" },
	{ "ServerStorage", "references ServerStorage (not available to a standalone model)" },
	{ "ServerScriptService", "references ServerScriptService (not available to a standalone model)" },
}

local function report(lines)
	for _, line in lines do
		print("[ModelLibrary] " .. line)
	end
end

local function validate(instance)
	local problems, notes = {}, {}
	local parts, scripts, motors = 0, 0, 0
	for _, descendant in instance:GetDescendants() do
		if descendant:IsA("BasePart") then
			parts += 1
		elseif descendant:IsA("Motor6D") then
			motors += 1
			if not descendant.Part0 or not descendant.Part1 then
				table.insert(problems, "Motor6D " .. descendant:GetFullName() .. " is missing Part0/Part1")
			end
		elseif descendant:IsA("LuaSourceContainer") then
			scripts += 1
			local source = descendant.Source
			for _, rule in FORBIDDEN_IN_SCRIPTS do
				if string.find(source, rule[1], 1, true) then
					table.insert(problems, descendant:GetFullName() .. " " .. rule[2])
				end
			end
			if string.find(source, "rbxassetid://", 1, true) then
				table.insert(notes, descendant:GetFullName() .. " mentions rbxassetid:// - document those ids in the asset README")
			end
			if string.find(string.lower(source), "api[_-]?key") or string.find(string.lower(source), "secret") then
				table.insert(problems, descendant:GetFullName() .. " looks like it contains a key or secret")
			end
		end
		for _, property in { "Texture", "TextureID", "MeshId", "SoundId", "Image" } do
			local ok, value = pcall(function()
				return (descendant :: any)[property]
			end)
			if ok and type(value) == "string" and value ~= "" then
				table.insert(notes, descendant:GetFullName() .. "." .. property .. " = " .. value .. " (external asset - document it)")
			end
		end
	end
	if instance:IsA("Model") and not instance.PrimaryPart then
		table.insert(notes, "Model has no PrimaryPart: its pivot is the bounding box centre. Consider setting PrimaryPart / PivotOffset")
	end
	return problems, notes, { Parts = parts, Scripts = scripts, Motors = motors }
end

button.Click:Connect(function()
	local selected = Selection:Get()
	if #selected ~= 1 then
		warn("[ModelLibrary] select exactly ONE model, folder or script (selected: " .. #selected .. ")")
		return
	end
	local instance = selected[1]
	local problems, notes, counts = validate(instance)
	local category = instance:GetAttribute("LibraryCategory")
	if type(category) ~= "string" or category == "" then
		category = "Misc"
	end
	report({
		string.format("%s (%s): %d parts, %d joints, %d scripts", instance.Name, instance.ClassName, counts.Parts, counts.Motors, counts.Scripts),
		"category: " .. category .. "  (set attribute LibraryCategory to change it)",
	})
	for _, note in notes do
		report({ "note: " .. note })
	end
	if #problems > 0 then
		for _, problem in problems do
			warn("[ModelLibrary] PROBLEM: " .. problem)
		end
		warn("[ModelLibrary] export cancelled - fix the problems above (or remove the offending code) and try again")
		return
	end
	-- Studio shows its normal save dialog; replacing an existing file asks for confirmation there.
	local ok, err = pcall(function()
		plugin:PromptSaveSelection(category .. "__" .. instance.Name)
	end)
	if not ok then
		warn("[ModelLibrary] could not open the save dialog: " .. tostring(err) .. "\nFallback: right-click the instance in Explorer -> Save to File... -> choose .rbxm")
	end
end)
