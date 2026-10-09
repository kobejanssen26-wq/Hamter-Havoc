--[[
	Bakes the editor preview: builds the world exactly like the server does on Play and writes it to
	world/*.rbxm, plus world/HamsterShowcase.rbxm (all hamsters per rarity on a floating platform above
	the plaza). Studio shows these without pressing Play; on Play WorldBuilder deletes them and builds
	the real world.

	usage: lune run tools/lune/bake_world.luau <projectRoot> [outDir=world]
]]

local fs = require("@lune/fs")
local process = require("@lune/process")
local Runtime = require("./runtime")

local root = process.args[1] or "."
local outDir = process.args[2] or (root .. "/world")
local game = Runtime.boot(root)
Runtime.quiet = true
local roblox = Runtime.roblox
local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local Enum = roblox.Enum

local Workspace = game:GetService("Workspace")
local WorldBuilder = Runtime.require(game:GetService("ServerScriptService").Systems.WorldBuilder)
local HamsterBuilder = Runtime.require(Runtime.modules().HamsterBuilder)
local HamsterDatabase = Runtime.mod("HamsterDatabase")
local RarityConfig = Runtime.mod("RarityConfig")

WorldBuilder.build()

---------------------------------------------------------------------------
-- showcase: one row per rarity on a platform 110 studs above the plaza
---------------------------------------------------------------------------
local SPACING_X, SPACING_Z, HEIGHT = 7, 11, 110
local showcase = Instance.new("Folder")
showcase.Name = "HamsterShowcase"
showcase.Parent = Workspace

local rows = {}
for _, species in HamsterDatabase.Species do
	rows[species.Rarity] = rows[species.Rarity] or {}
	table.insert(rows[species.Rarity], species)
end
local widest = 0
for _, list in rows do
	widest = math.max(widest, #list)
end
local depth = #RarityConfig.Order * SPACING_Z
local width = widest * SPACING_X

local function part(parent, name, size, cframe, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local platform = Instance.new("Model")
platform.Name = "Platform"
platform.Parent = showcase
part(platform, "Floor", Vector3.new(width + 12, 1, depth + 8), CFrame.new(0, HEIGHT - 0.5, 0), Color3.fromRGB(255, 247, 233))
local sign = part(platform, "Sign", Vector3.new(40, 6, 0.6), CFrame.new(0, HEIGHT + 3, -depth / 2 - 3.5), Color3.fromRGB(255, 140, 90))
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Front
gui.Parent = sign
local text = Instance.new("TextLabel")
text.Size = roblox.UDim2.fromScale(1, 1)
text.BackgroundTransparency = 1
text.TextScaled = true
text.TextColor3 = Color3.new(1, 1, 1)
text.Text = "All hamsters - editor preview (removed on Play)"
text.FontFace = roblox.Font.fromEnum(Enum.Font.FredokaOne)
text.Parent = gui

local z0 = -depth / 2 + SPACING_Z / 2
for rowIndex, rarityId in RarityConfig.Order do
	local rarity = RarityConfig.ById[rarityId]
	local list = rows[rarityId] or {}
	local folder = Instance.new("Folder")
	folder.Name = string.format("%02d_%s", rowIndex, rarity.Id)
	folder.Parent = showcase
	local z = z0 + (rowIndex - 1) * SPACING_Z
	-- coloured stripe per rarity
	part(platform, "Stripe_" .. rarity.Id, Vector3.new(width + 8, 0.12, SPACING_Z - 3), CFrame.new(0, HEIGHT + 0.06, z), rarity.Color)
	for index, species in list do
		local model = HamsterBuilder.build(species, { Particles = false })
		local x = -width / 2 + (index - 0.5) * SPACING_X
		-- hamsters are built facing -Z: towards the sign and the plaza camera
		local place = CFrame.new(x, HEIGHT, z)
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame = place * d.CFrame
			end
		end
		pcall(function()
			model.WorldPivot = place
		end)
		model.Parent = folder
	end
end

---------------------------------------------------------------------------
-- write every top-level folder
---------------------------------------------------------------------------
local function fixFonts(rootInstance)
	-- Lune keeps `label.Font = Enum.Font.X` as an EnumItem under FontFace; the file format wants a Font
	for _, d in rootInstance:GetDescendants() do
		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
			pcall(function()
				d.FontFace = roblox.Font.fromEnum(d.Font)
			end)
		end
	end
end

fs.writeDir(outDir)
for _, name in { "HamsterPlaza", "HamsterPath", "PlayerHouses", "Environment", "SpawnLocations", "HamsterShowcase" } do
	local instance = Workspace:FindFirstChild(name)
	assert(instance, "missing " .. name)
	Runtime.strip(instance)
	fixFonts(instance)
	local count = 0
	for _, d in instance:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	fs.writeFile(outDir .. "/" .. name .. ".rbxm", roblox.serializeModel({ instance }))
	print(name, count, "parts")
end
