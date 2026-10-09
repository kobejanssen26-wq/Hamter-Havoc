--[[
	Exports every reusable visual asset of Hamster Plaza into the /Models library.

	Each asset is built from the game's own builder code (so the library always matches the game),
	moved so its footprint centre sits on the origin (bottom at Y = 0), and written as:
	  <Name>.rbxm          Roblox model (drag into Studio)
	  metadata.json        name, category, source function, size, part count, stats (hamsters), hash
	and its parts go to <work>/<Name>.json for tools/export_glb.py (which writes <Name>.glb).

	Identical models are stored once: the geometry hash decides (rounded positions, sizes, colours);
	a duplicate is listed in the manifest as an alias of the first asset.

	usage: lune run tools/lune/export_models.luau <projectRoot> <ModelsDir> <workDir>
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Runtime = require("./runtime")
local Dump = require("./dump")

local root = process.args[1] or "."
local outDir = process.args[2] or "Models"
local workDir = process.args[3] or "/tmp/models-work"

local game = Runtime.boot(root)
Runtime.quiet = true
local roblox = Runtime.roblox
local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local Vector2 = roblox.Vector2
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Random = Runtime.Random

local SSS = game:GetService("ServerScriptService")
local WB = SSS.Systems.WorldBuilder
local Decor = Runtime.require(WB.Decor)
local Palette = Runtime.require(WB.Palette)
local HouseBuilder = Runtime.require(WB.HouseBuilder)
local WorldBuilder = Runtime.require(WB)
local HamsterBuilder = Runtime.require(Runtime.modules().HamsterBuilder)
local HamsterDatabase = Runtime.mod("HamsterDatabase")
local RarityConfig = Runtime.mod("RarityConfig")
local FloorConfig = Runtime.mod("FloorConfig")

fs.writeDir(outDir)
fs.writeDir(workDir)

local manifest = { Assets = {}, Duplicates = {} }
local byHash: { [string]: string } = {}

local function round(value: number): number
	return math.floor(value * 100 + 0.5) / 100
end

local function parts(model)
	local list = {}
	local all = model:GetDescendants()
	if model:IsA("BasePart") then
		table.insert(all, 1, model)
	end
	for _, d in all do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

-- footprint centre on the origin, bottom at Y = 0 (visible parts decide the bounds)
local function normalize(model)
	local minV, maxV = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	local found = false
	for _, part in parts(model) do
		if part.Transparency < 0.98 then
			found = true
			local cf, size = part.CFrame, part.Size
			local mesh = part:FindFirstChildOfClass("SpecialMesh")
			if mesh and mesh.MeshType ~= roblox.Enum.MeshType.FileMesh then
				size = Vector3.new(size.X * mesh.Scale.X, size.Y * mesh.Scale.Y, size.Z * mesh.Scale.Z)
			end
			-- world-axis half extents of the rotated box
			local hx = math.abs(cf.XVector.X) * size.X / 2 + math.abs(cf.YVector.X) * size.Y / 2 + math.abs(cf.ZVector.X) * size.Z / 2
			local hy = math.abs(cf.XVector.Y) * size.X / 2 + math.abs(cf.YVector.Y) * size.Y / 2 + math.abs(cf.ZVector.Y) * size.Z / 2
			local hz = math.abs(cf.XVector.Z) * size.X / 2 + math.abs(cf.YVector.Z) * size.Y / 2 + math.abs(cf.ZVector.Z) * size.Z / 2
			local p = cf.Position
			minV = Vector3.new(math.min(minV.X, p.X - hx), math.min(minV.Y, p.Y - hy), math.min(minV.Z, p.Z - hz))
			maxV = Vector3.new(math.max(maxV.X, p.X + hx), math.max(maxV.Y, p.Y + hy), math.max(maxV.Z, p.Z + hz))
		end
	end
	if not found then
		return Vector3.zero
	end
	local offset = Vector3.new((minV.X + maxV.X) / 2, minV.Y, (minV.Z + maxV.Z) / 2)
	local shift = CFrame.new(-offset)
	for _, part in parts(model) do
		part.CFrame = shift * part.CFrame
	end
	-- keep CFrame attributes (e.g. the wheel hub's HomeCFrame) in the same space
	local all = model:GetDescendants()
	table.insert(all, model)
	for _, d in all do
		for name, value in d:GetAttributes() do
			if typeof(value) == "CFrame" then
				d:SetAttribute(name, shift * value)
			end
		end
	end
	pcall(function()
		model.WorldPivot = CFrame.new()
	end)
	return maxV - minV
end

local function geometryHash(list): string
	local rows = {}
	for _, p in list do
		local cf = {}
		for i, v in p.cf do
			cf[i] = round(v)
		end
		table.insert(rows, string.format("%s|%s|%s|%s|%s|%s", p.s, table.concat(cf, ","), round(p.sz[1]) .. "," .. round(p.sz[2]) .. "," .. round(p.sz[3]), round(p.c[1]) .. "," .. round(p.c[2]) .. "," .. round(p.c[3]), round(p.t), p.m))
	end
	table.sort(rows)
	return serde.hash("sha256", table.concat(rows, "\n"))
end

local scratch = Instance.new("Folder")
scratch.Name = "Scratch"
scratch.Parent = game:GetService("Workspace")

-- Saves one asset. `model` may be a Model, Folder or Part; it is wrapped in a Model when needed.
local function save(model, category: string, name: string, info: { [string]: any })
	if not model:IsA("Model") then
		local wrapper = Instance.new("Model")
		wrapper.Name = name
		wrapper.Parent = scratch
		if model:IsA("Folder") then
			for _, child in model:GetChildren() do
				child.Parent = wrapper
			end
			model:Destroy()
		else
			model.Parent = wrapper
		end
		model = wrapper
	end
	model.Name = name
	local size = normalize(model)
	local list = Dump.collect(model)
	local effectOnly = #list == 0
	assert(not effectOnly or info.EffectOnly, "asset has no visible parts: " .. name)
	local hash = if effectOnly then serde.hash("sha256", category .. "/" .. name) else geometryHash(list)
	if byHash[hash] then
		table.insert(manifest.Duplicates, { Name = name, Category = category, SameAs = byHash[hash] })
		model:Destroy()
		return
	end
	local path = category .. "/" .. name
	byHash[hash] = path
	local dir = outDir .. "/" .. path
	fs.writeDir(dir)
	Runtime.strip(model)
	-- Lune keeps `label.Font = Enum.Font.X` as an EnumItem under FontFace; the file format wants a Font
	for _, d in model:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
			pcall(function()
				d.FontFace = roblox.Font.fromEnum(d.Font)
			end)
		end
	end
	fs.writeFile(dir .. "/" .. name .. ".rbxm", roblox.serializeModel({ model }))
	if not effectOnly then
		fs.writeFile(workDir .. "/" .. string.gsub(path, "/", "__") .. ".json", serde.encode("json", list))
	end
	local meta = {
		Name = name,
		Category = category,
		Files = if effectOnly then { name .. ".rbxm" } else { name .. ".rbxm", name .. ".glb" },
		Parts = #list,
		SizeStuds = { round(size.X), round(size.Y), round(size.Z) },
		Hash = string.sub(hash, 1, 16),
	}
	for key, value in info do
		meta[key] = value
	end
	fs.writeFile(dir .. "/metadata.json", serde.encode("json", meta, true))
	table.insert(manifest.Assets, meta)
	model:Destroy()
end

local function fresh(): Instance
	local folder = Instance.new("Folder")
	folder.Parent = scratch
	return folder
end

-- the first Model child a builder made in `folder`
local function built(folder)
	return folder:FindFirstChildWhichIsA("Model") or folder:FindFirstChildWhichIsA("BasePart") or folder
end

local function rng(): any
	return Random.new(7)
end

---------------------------------------------------------------------------
-- Hamsters (by rarity)
---------------------------------------------------------------------------
local hamsterCount = 0
for _, species in HamsterDatabase.Species do
	local rarity = RarityConfig.ById[species.Rarity]
	local stats = HamsterDatabase.stats(species)
	local model = HamsterBuilder.build(species, { Particles = false })
	model.Parent = scratch
	local clean = string.gsub(species.Name, "[^%w]", "")
	-- folders use the rarity id (the Unknown rarity's display name is "???")
	save(model, "Hamsters/" .. rarity.Id, rarity.Id .. "Hamster" .. clean, {
		Source = "HamsterBuilder.build(HamsterDatabase.ById." .. species.Id .. ")",
		HamsterId = species.Id,
		DisplayName = species.Name,
		Rarity = stats.Rarity,
		PurchasePrice = stats.Price,
		IncomePerSecond = stats.Income,
		SpawnChance = stats.SpawnChance,
		MovementSpeed = stats.Speed,
		CollectionValue = stats.CollectionValue,
		MinRebirth = stats.MinRebirth,
		Signature = HamsterBuilder.signature(species),
	})
	hamsterCount += 1
end
print("hamsters:", hamsterCount)

---------------------------------------------------------------------------
-- Apartment modules + wheels (one apartment at the origin, all five floors)
---------------------------------------------------------------------------
do
	local houseParent = fresh()
	local house = HouseBuilder.build(houseParent, 1, CFrame.new(), rng())
	HouseBuilder.setFloors(house, #FloorConfig.Floors, false)
	for slot in house.Slots do
		HouseBuilder.setWheel(house, slot, true)
	end

	-- wheels: one per style (the hub turns around its X axis: Axis = "X")
	local seen = {}
	for _, slot in house.Slots do
		if not seen[slot.Style] and slot.Wheel then
			seen[slot.Style] = true
			local frame = slot.Frame
			frame.Parent = scratch
			save(frame, "HamsterWheel", slot.Style, {
				Source = "HouseBuilder (buildWheel) - style " .. slot.Style,
				UsedOn = "apartment floors using " .. slot.Style,
				Notes = "The child model 'Wheel' turns around the hub's X axis (attribute HomeCFrame, AmbientController SpinModel).",
			})
		end
	end

	local floorNames = {}
	for index, definition in FloorConfig.Floors do
		local model = house.FloorModels[index]
		model.Parent = scratch
		local name = string.format("Floor%02d", index)
		floorNames[index] = name
		save(model, "Buildings/Apartment", name, {
			Source = "HouseBuilder (buildFloor " .. index .. ")",
			FloorName = definition.Name,
			UnlocksAtRebirth = definition.MinRebirth,
			Purpose = definition.Purpose,
			Notes = "Modular storey: stack Floor01..Floor05, then Roof. Wheels are separate (HamsterWheel).",
		})
	end
	local roof = house.RoofFolder
	roof.Parent = scratch
	save(roof, "Buildings/Apartment", "Roof", { Source = "HouseBuilder (buildRoof)", Notes = "Sits on top of the highest floor." })
	local lift = house.Model:FindFirstChild("Lift")
	lift.Parent = scratch
	save(lift, "Buildings/Apartment", "Lift", { Source = "HouseBuilder (buildLift)", Notes = "Glass lift tower beside the building (shown at 5 floors)." })

	-- gate: everything of the yard on the street line (|z| < 5, |x| < 14)
	local yard = house.Model:FindFirstChild("Yard")
	local gate = Instance.new("Model")
	gate.Parent = scratch
	for _, part in yard:GetDescendants() do
		if part:IsA("BasePart") then
			local p = part.CFrame.Position
			if math.abs(p.Z) < 5 and math.abs(p.X) < 14 then
				local holder = part.Parent
				if holder == yard then
					part.Parent = gate
				end
			end
		end
	end
	save(gate, "Buildings/Apartment", "EntranceGate", { Source = "HouseBuilder (buildGate)", Notes = "Gate with name canopy, security lasers and the security kiosk." })
	yard.Parent = scratch
	save(yard, "Buildings/Apartment", "Lot", { Source = "HouseBuilder (buildYard)", Notes = "Garden lot: lawn, driveway, hedges, trees, patio (without the gate)." })

	-- scaffold for the next floor + prestige trims (built on a second apartment)
	local house2 = HouseBuilder.build(fresh(), 2, CFrame.new(), rng())
	HouseBuilder.setFloors(house2, 1, true)
	local scaffold = house2.Model:FindFirstChild("Scaffold")
	scaffold.Parent = scratch
	save(scaffold, "Buildings/Apartment", "Scaffold", { Source = "HouseBuilder (buildScaffold)", Notes = "Next floor under construction, with the 'unlocks at rebirth' sign." })
	local house3 = HouseBuilder.build(fresh(), 3, CFrame.new(), rng())
	HouseBuilder.setFloors(house3, 5, false)
	HouseBuilder.setPrestige(house3, 20)
	local prestige = house3.Model:FindFirstChild("Prestige")
	prestige.Parent = scratch
	save(prestige, "Buildings/Apartment", "PrestigeTrims", { Source = "HouseBuilder.setPrestige(20)", Notes = "Gold bands (R10), crown (R15) and light strips (R20) for a 5-floor apartment." })

	-- upgrade station props (level 100%)
	for id, builder in HouseBuilder.StationProps do
		local folder = fresh()
		builder(folder, CFrame.new(0, 0, 0), 1, 0)
		save(folder, "Props/Stations", id .. "Prop", { Source = "HouseBuilder.StationProps." .. id, Notes = "Shown on the upgrade pedestal, grows with the upgrade level." })
	end
end

---------------------------------------------------------------------------
-- Furniture
---------------------------------------------------------------------------
do
	local F = HouseBuilder.Furniture
	local f = fresh()
	F.Sofa(f, CFrame.new(), Palette.Peach or Color3.fromRGB(255, 180, 140))
	save(f, "Furniture", "Sofa", { Source = "HouseBuilder.Furniture.Sofa" })
	f = fresh()
	F.Plant(f, CFrame.new(), 1)
	save(f, "Plants", "PottedPlant", { Source = "HouseBuilder.Furniture.Plant" })
	f = fresh()
	F.Rug(f, CFrame.new(), Vector2.new(8, 6), Palette.Cream, Palette.Wood)
	save(f, "Furniture", "Rug", { Source = "HouseBuilder.Furniture.Rug" })
	f = fresh()
	F.CeilingLight(f, CFrame.new())
	save(f, "Furniture", "CeilingLight", { Source = "HouseBuilder.Furniture.CeilingLight" })
	f = fresh()
	F.Railing(f, CFrame.new(), 10, Palette.StoneDark)
	save(f, "Furniture", "GlassRailing", { Source = "HouseBuilder.Furniture.Railing" })
	f = fresh()
	save(Decor.bench(f, CFrame.new()), "Furniture", "Bench", { Source = "Decor.bench" })
end

---------------------------------------------------------------------------
-- Trees, plants, environment, decorations, props, animals, effects
---------------------------------------------------------------------------
local origin = Vector3.zero
local function decor(category: string, name: string, source: string, make: (Instance) -> Instance)
	local folder = fresh()
	local result = make(folder)
	save(if result then result else built(folder), category, name, { Source = source })
end

decor("Trees", "PineTree", "Decor.tree(pine)", function(p) return Decor.tree(p, origin, "pine", 1, rng()) end)
decor("Trees", "RoundTree", "Decor.tree(round)", function(p) return Decor.tree(p, origin, "round", 1, rng()) end)
decor("Trees", "CherryTree", "Decor.tree(cherry)", function(p) return Decor.tree(p, origin, "cherry", 1, rng()) end)
decor("Trees", "LargeGreenTree", "Decor.largeTree", function(p) return Decor.largeTree(p, origin, 1, rng()) end)
decor("Trees", "LargeDarkTree", "Decor.largeTree(LeafDark)", function(p) return Decor.largeTree(p, origin, 1, rng(), Palette.LeafDark) end)
decor("Trees", "LargeCherryTree", "Decor.largeTree(Cherry)", function(p) return Decor.largeTree(p, origin, 1, rng(), Palette.Cherry) end)
decor("Trees", "TreeStump", "Decor.stump", function(p) return Decor.stump(p, origin, 1) end)

decor("Plants", "Bush", "Decor.bush", function(p) return Decor.bush(p, origin, 1, rng(), false) end)
decor("Plants", "BerryBush", "Decor.bush(berries)", function(p) return Decor.bush(p, origin, 1, rng(), true) end)
decor("Plants", "FlowerPatch", "Decor.flowers", function(p) return Decor.flowers(p, origin, 2.5, 7, rng()) end)
decor("Plants", "Sunflower", "Decor.sunflower", function(p) return Decor.sunflower(p, origin, 1) end)
decor("Plants", "PinkFlowerBed", "Decor.flowerBed(pink)", function(p) return Decor.flowerBed(p, CFrame.new(), Vector2.new(6, 6), { Palette.Pink, Palette.Cream }, rng()) end)
decor("Plants", "LavenderFlowerBed", "Decor.flowerBed(lavender)", function(p) return Decor.flowerBed(p, CFrame.new(), Vector2.new(6, 6), { Palette.Lavender, Palette.Cream }, rng()) end)
decor("Plants", "Hedge", "Decor.hedgeRun", function(p) return Decor.hedgeRun(p, Vector3.new(-6, 0, 0), Vector3.new(6, 0, 0), rng()) end)
decor("Plants", "Mushrooms", "Decor.mushrooms", function(p) return Decor.mushrooms(p, origin, rng()) end)

decor("Environment", "Mountain", "Decor.mountain", function(p) return Decor.mountain(p, origin, 120, 90, rng(), 0, false) end)
decor("Environment", "SnowMountain", "Decor.mountain(snow)", function(p) return Decor.mountain(p, origin, 120, 110, rng(), 0, true) end)
decor("Environment", "Hill", "Decor.hill", function(p) return Decor.hill(p, origin, Vector3.new(60, 18, 50)) end)
decor("Environment", "Cloud", "Decor.cloud", function(p) return Decor.cloud(p, origin, 1, rng()) end)
decor("Environment", "Pond", "Decor.pond", function(p) return Decor.pond(p, origin, 8, rng()) end)
decor("Environment", "Rock", "Decor.rock", function(p) return Decor.rock(p, origin, 1, rng()) end)
decor("Environment", "Windmill", "Decor.windmill", function(p) return Decor.windmill(p, origin, 0) end)

decor("Decorations", "Balloon", "Decor.balloon", function(p) return Decor.balloon(p, origin, Palette.Pink) end)
decor("Decorations", "Flag", "Decor.flag", function(p) return Decor.flag(p, origin, Palette.Sky or Color3.fromRGB(120, 190, 255)) end)
decor("Decorations", "Signpost", "Decor.signpost", function(p) return Decor.signpost(p, CFrame.new(), "Hamster Plaza") end)
decor("Decorations", "PicketFence", "Decor.fenceRun", function(p) return Decor.fenceRun(p, Vector3.new(-8, 0, 0), Vector3.new(8, 0, 0)) end)
decor("Decorations", "GardenLamp", "Decor.lamp", function(p) return Decor.lamp(p, origin) end)
decor("Decorations", "StreetLamp", "Decor.streetLamp", function(p) return Decor.streetLamp(p, CFrame.new()) end)

decor("Props", "Barrel", "Decor.barrel", function(p) return Decor.barrel(p, origin) end)
decor("Props", "Crate", "Decor.crate", function(p) return Decor.crate(p, origin, 0) end)

decor("Animals", "Bird", "Decor.bird", function(p) return Decor.bird(p, origin, 0, rng()) end)
do
	local folder = fresh()
	save(Decor.fireflies(folder, origin, 6), "Effects", "Fireflies", { Source = "Decor.fireflies", EffectOnly = true, Notes = "Invisible part with a ParticleEmitter (no mesh)." })
end

---------------------------------------------------------------------------
-- Pieces of the generated world (plaza buildings, burrow, lake)
---------------------------------------------------------------------------
do
	local world = WorldBuilder.build()
	local workspace = game:GetService("Workspace")
	local plaza = workspace:FindFirstChild("HamsterPlaza")
	local plazaNames = {
		ShopStall = "ShopStall",
		HamsterLibrary = "HamsterLibrary",
		RecentFinds = "RecentFindsBoard",
		PlazaArch = "PlazaArch",
	}
	for source, name in plazaNames do
		local model = plaza and plaza:FindFirstChild(source, true)
		if model then
			model.Parent = scratch
			save(model, "Buildings/Plaza", name, { Source = "PlazaBuilder (" .. source .. ")" })
		else
			print("missing plaza model", source)
		end
	end
	local path = workspace:FindFirstChild("HamsterPath")
	local burrow = path and path:FindFirstChild("BurrowHill", true)
	if burrow then
		burrow.Parent = scratch
		save(burrow, "Environment", "BurrowHill", { Source = "PathBuilder (buildBurrow)", Notes = "Where the hamsters come out of the ground." })
	end
	local lake = workspace:FindFirstChild("Lake", true)
	if lake then
		lake.Parent = scratch
		save(lake, "Environment", "Lake", { Source = "EnvironmentBuilder (buildBackdrop)" })
	end
	local _ = world
end

table.sort(manifest.Assets, function(a, b)
	if a.Category ~= b.Category then
		return a.Category < b.Category
	end
	return a.Name < b.Name
end)
fs.writeFile(outDir .. "/manifest.json", serde.encode("json", manifest, true))
print("assets:", #manifest.Assets, "duplicates skipped:", #manifest.Duplicates)
