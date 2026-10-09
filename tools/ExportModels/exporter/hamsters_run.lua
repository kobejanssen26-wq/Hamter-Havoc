-- Exports EVERY hamster species as its own model (used by `export_models.py --hamsters-zip`).
-- Each model = the game's HamsterBuilder output + the bundled animator, exactly like ModelLibrary/Hamsters/Hamster_Default.
local HamsterBuilder = require(find("ReplicatedStorage.Modules.HamsterBuilder"))
local HamsterDatabase = require(find("ReplicatedStorage.Modules.HamsterDatabase"))
local RarityConfig = require(find("ReplicatedStorage.Modules.RarityConfig"))

local base
for _, candidate in ASSETS do
	if candidate.Config.Name == "Hamster_Default" then base = candidate end
end
assert(base, "ModelLibrary/Hamsters/Hamster_Default is required (it provides the bundled scripts)")
local ANIMATOR = "src/StarterPlayer/StarterPlayerScripts/Controllers/HamsterAnimator.luau"
assert(FILES[ANIMATOR])

local rankIndex = {}
for index, id in RarityConfig.Order do rankIndex[id] = index end

local count, failures = 0, 0
for _, species in HamsterDatabase.Species do
	local ok, err = pcall(function()
		local ctx = newContext(base)
		local model = HamsterBuilder.build(species, { Scale = 1, LowDetail = false, Particles = false })
		model.Name = species.Name
		model:PivotTo(CFrame.new(0, 0, 0))
		model.Parent = scratch
		ctx.attr(model, { ModelScale = model:GetScale(), MoveSpeed = 0, SpeciesId = species.Id, Rarity = species.Rarity })
		ctx.gameModule(model, ANIMATOR, "HamsterAnimator")
		ctx.libraryScript(model, "HamsterAutoAnimate.client.luau")
		assert(model.PrimaryPart, "no PrimaryPart")
		local json, instances = serialize(model, species.Id)
		local folder = string.format("%02d_%s", rankIndex[species.Rarity], RarityConfig.ById[species.Rarity].Name)
		print(string.format('META|%s|{"name":%s,"title":%s,"category":%s,"file":%s,"instances":%d}', species.Id, jsonString(species.Id), jsonString(species.Name), jsonString(folder), jsonString(species.Id .. ".rbxm"), instances))
		print("EXPORT|" .. species.Id .. "|" .. json)
		model:Destroy()
	end)
	if ok then count += 1 else failures += 1 print("FAIL|" .. species.Id .. "|" .. tostring(err)) end
end
for _, warning in warnings do print("WARN|" .. warning) end
print("DONE|" .. count .. "|" .. failures)
