-- Shared by the export scene and the tests: the context object handed to every ModelLibrary build-model.lua.

local scratch = M.newInstance("Folder", true)
RawData[scratch].Name = "ModelLibraryScratch"
M.setParent(scratch, workspace)

---------------------------------------------------------------------------
-- context handed to build-model.lua
---------------------------------------------------------------------------
local newContext

local function assetByName(name)
	for _, candidate in ASSETS do
		if candidate.Config.Name == name then
			return candidate
		end
	end
	error("no ModelLibrary asset named " .. name)
end

newContext = function(asset, options)
	local ctx = {}
	ctx.Options = options or {}
	ctx.Dir = asset.Dir
	ctx.Config = asset.Config
	ctx.Scratch = scratch

	-- a module of the real game, e.g. ctx.module("ReplicatedStorage.Modules.HamsterBuilder")
	function ctx.module(path)
		return require(find(path))
	end

	function ctx.new(class, name, parent)
		local inst = M.newInstance(class, true)
		RawData[inst].Name = name
		if parent then
			M.setParent(inst, parent)
		end
		return inst
	end

	function ctx.set(inst, props)
		for key, value in props do
			RawData[inst].Props[key] = value
		end
		return inst
	end

	function ctx.attr(inst, attributes)
		for key, value in attributes do
			RawData[inst].Attributes[key] = value
		end
		return inst
	end

	local function makeScript(parent, class, name, source)
		local inst = ctx.new(class, name, parent)
		RawData[inst].Props.Source = source
		if class == "Script" then
			RawData[inst].Props.RunContext = Enum.RunContext.Client
		end
		return inst
	end

	-- library script: ModelLibrary/<asset>/scripts/<File>. *.client.luau -> Script (RunContext Client), *.server.luau -> Script, *.luau -> ModuleScript
	-- file names starting with "shared/" come from ModelLibrary/_shared/scripts/ (scripts used by several assets)
	function ctx.libraryScript(parent, fileSpec, nameOverride)
		local file = fileSpec
		local source
		local sharedName = string.match(fileSpec, "^shared/(.+)$")
		if sharedName then
			file = sharedName
			source = FILES["ModelLibrary/_shared/scripts/" .. sharedName]
		else
			source = FILES[asset.Dir .. "/scripts/" .. fileSpec]
		end
		assert(source, "missing library script " .. fileSpec .. " in " .. asset.Dir)
		local base, class = string.match(file, "^(.+)%.client%.luau$"), "Script"
		if not base then
			base = string.match(file, "^(.+)%.server%.luau$")
			if base then
				class = "Script"
			else
				base, class = string.match(file, "^(.+)%.luau$"), "ModuleScript"
			end
		end
		local inst = makeScript(parent, class, nameOverride or base, source)
		if string.find(file, "%.server%.luau$") then
			RawData[inst].Props.RunContext = Enum.RunContext.Server
		end
		return inst
	end

	-- the CURRENT source of a game file, packaged as a ModuleScript (so it can never drift from the game)
	function ctx.gameModule(parent, repoPath, name)
		local source = FILES[repoPath]
		assert(source, "game file not embedded (mention it as a string literal in build-model.lua): " .. repoPath)
		return makeScript(parent, "ModuleScript", name, source)
	end

	-- invisible anchored part that becomes the model's PrimaryPart, i.e. its pivot (usually the ground point of the asset)
	function ctx.pivotPart(model, cframe)
		local part = ctx.new("Part", "Pivot", model)
		ctx.set(part, { Size = Vector3.new(0.4, 0.2, 0.4), CFrame = cframe, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false, Transparency = 1 })
		model.PrimaryPart = part
		return part
	end

	-- builds another library asset (fresh copy) so assemblies are composed from the exact same definitions
	function ctx.buildAsset(name, buildOptions)
		local other = assetByName(name)
		return other.Build(newContext(other, buildOptions))
	end
	return ctx
end

