--[[
	Builds the static test map out of simple Parts: ground, central plaza and the curved route
	(road plates + start/end gates). Bases are built by BaseService.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local PartUtil = require(Shared.Util.PartUtil)
local RouteMath = require(Shared.Util.RouteMath)

local Services = script.Parent
local HamsterModel = require(Services.HamsterModel)

local MapService = {}

local mapConfig = GameConfig.Map
local routeConfig = GameConfig.Route

local function buildGate(parent: Instance, distance: number, text: string, color: Color3)
	local position, tangent = RouteMath.pointAt(distance)
	local base = CFrame.lookAt(position + Vector3.new(0, mapConfig.GroundY, 0), position + tangent)
	local half = routeConfig.Width / 2 + 1.5
	local height = 16

	for _, side in { -1, 1 } do
		PartUtil.create("GatePillar", Vector3.new(1.5, height, 1.5), base * CFrame.new(side * half, height / 2, 0), {
			Color = Color3.fromRGB(50, 50, 60),
			Material = Enum.Material.Metal,
		}).Parent = parent
	end
	local beam = PartUtil.create("GateBeam", Vector3.new(half * 2 + 1.5, 1.5, 1.5), base * CFrame.new(0, height, 0), {
		Color = color,
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	beam.Parent = parent
	HamsterModel.createBillboard(beam, string.format("<b>%s</b>", text), Vector3.new(0, 3, 0), Vector2.new(200, 40)).TextSize = 28
end

function MapService.build()
	Lighting.ClockTime = 14

	local map = Instance.new("Folder")
	map.Name = "Map"

	PartUtil.create("Ground", Vector3.new(mapConfig.GroundSize, 1, mapConfig.GroundSize), CFrame.new(0, mapConfig.GroundY - 0.5, 0), {
		Color = Color3.fromRGB(88, 140, 76),
		Material = Enum.Material.Grass,
	}).Parent = map

	-- Central plaza (disc) with the guest spawn.
	local plazaTop = mapConfig.GroundY + 0.4
	PartUtil.create("Plaza", Vector3.new(0.4, mapConfig.PlazaRadius * 2, mapConfig.PlazaRadius * 2), CFrame.new(0, mapConfig.GroundY + 0.2, 0) * CFrame.Angles(0, 0, math.pi / 2), {
		Shape = Enum.PartType.Cylinder,
		Color = Color3.fromRGB(225, 215, 190),
		Material = Enum.Material.Cobblestone,
	}).Parent = map

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "PlazaSpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.Position = Vector3.new(0, plazaTop + 0.5, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Transparency = 0.6
	spawn.Color = Color3.fromRGB(255, 220, 140)
	spawn.Parent = map
	HamsterModel.createBillboard(spawn, "<b>HAMSTER PLAZA</b>", Vector3.new(0, 7, 0), Vector2.new(240, 40)).TextSize = 26

	-- Route: a chain of road plates following RouteMath, with glowing edge lines.
	local routeFolder = Instance.new("Folder")
	routeFolder.Name = "Route"
	local totalLength = RouteMath.totalLength()
	local segments = routeConfig.PlateSegments
	local thickness = mapConfig.RouteThickness
	local edgeX = routeConfig.Width / 2 - 0.4

	for i = 1, segments do
		local startDistance = (i - 1) / segments * totalLength
		local endDistance = i / segments * totalLength
		local position, tangent = RouteMath.pointAt((startDistance + endDistance) / 2)
		local length = (endDistance - startDistance) + 0.6
		local center = position + Vector3.new(0, mapConfig.GroundY + thickness / 2, 0)
		local cframe = CFrame.lookAt(center, center + tangent)

		PartUtil.create("RoutePlate", Vector3.new(routeConfig.Width, thickness, length), cframe, {
			Color = Color3.fromRGB(60, 62, 72),
			Material = Enum.Material.Asphalt,
		}).Parent = routeFolder

		for _, side in { -1, 1 } do
			PartUtil.create("RouteEdge", Vector3.new(0.5, 0.15, length), cframe * CFrame.new(side * edgeX, thickness / 2 + 0.05, 0), {
				Color = Color3.fromRGB(255, 200, 80),
				Material = Enum.Material.Neon,
				CanCollide = false,
			}).Parent = routeFolder
		end
	end
	routeFolder.Parent = map

	buildGate(map, 0, "HAMSTER ROUTE START", Color3.fromRGB(90, 255, 140))
	buildGate(map, totalLength, "ROUTE END", Color3.fromRGB(255, 90, 90))

	map.Parent = Workspace
end

return MapService
