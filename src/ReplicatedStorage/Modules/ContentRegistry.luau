--[[
	ContentRegistry: finds the content files you drop into  Modules/Content/<Kind>/  (one ModuleScript per item).
	  Content/Hamsters/    one file per custom hamster       (see _Template.luau in that folder)
	  Content/Emotes/      one file per emote
	  Content/Animations/  one file per registered animation
	A file whose definition has  Enabled = false  (the _Template files) is ignored. A file that errors is reported and
	skipped; it never stops the game from starting. Files are loaded in name order so results are deterministic.
]]

local ContentRegistry = {}

export type Loaded = { File: string, Def: any }

function ContentRegistry.load(kind: string): ({ Loaded }, { string })
	local results: { Loaded } = {}
	local problems: { string } = {}
	local content = script.Parent:FindFirstChild("Content")
	local folder = content and content:FindFirstChild(kind)
	if not folder then
		return results, problems
	end
	local files = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			table.insert(files, child)
		end
	end
	table.sort(files, function(a, b)
		return a.Name < b.Name
	end)
	for _, file in files do
		local ok, def = pcall(require, file)
		if not ok then
			table.insert(problems, string.format("%s/%s failed to load: %s", kind, file.Name, tostring(def)))
		elseif type(def) ~= "table" then
			table.insert(problems, string.format("%s/%s must return a table", kind, file.Name))
		elseif def.Enabled ~= false then
			table.insert(results, { File = file.Name, Def = def })
		end
	end
	return results, problems
end

return ContentRegistry
