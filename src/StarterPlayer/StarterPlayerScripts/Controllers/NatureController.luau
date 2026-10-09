--[[
	NatureController: the world breathes. Purely local and cosmetic, nothing here touches gameplay.
	  - clouds (tag "Cloud", attribute Speed) drift slowly and wrap around the map
	  - a few flocks of birds circle over the plaza and the lakes (off in Low Graphics)
	  - trees (tag "TreeSway") that are close to the camera sway gently in the wind
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local DataController = require(script.Parent.DataController)

local NatureController = {}

local CLOUD_WRAP = 720
local TREE_DISTANCE = 95
local TREE_AMPLITUDE = math.rad(1.3)

type Cloud = { Model: Model, Speed: number }
type Tree = { Model: Model, Home: CFrame, Base: Vector3, Phase: number, Active: boolean }
type Bird = { Body: BasePart, WingL: BasePart, WingR: BasePart, Center: Vector3, Radius: number, Height: number, Speed: number, Phase: number, Bob: number }

local clouds: { [Model]: Cloud } = {}
local trees: { [Model]: Tree } = {}
local birds: { Bird } = {}
local birdFolder: Folder? = nil

local function buildBird(parent: Instance, center: Vector3, radius: number, height: number, speed: number, phase: number): Bird
	local function part(size: Vector3, color: Color3): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Size = size
		p.Color = color
		p.Material = Enum.Material.SmoothPlastic
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
		return p
	end
	local body = part(Vector3.new(0.9, 0.7, 2), Color3.fromRGB(250, 246, 238))
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = body
	local wingColor = Color3.fromRGB(236, 232, 226)
	return {
		Body = body,
		WingL = part(Vector3.new(2.6, 0.12, 1.1), wingColor),
		WingR = part(Vector3.new(2.6, 0.12, 1.1), wingColor),
		Center = center,
		Radius = radius,
		Height = height,
		Speed = speed,
		Phase = phase,
		Bob = math.random() * 6,
	}
end

local function spawnBirds()
	if birdFolder then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Birds"
	folder.Parent = Workspace
	birdFolder = folder
	local centers = { Vector3.new(0, 0, 0), Vector3.new(-120, 0, 70), Vector3.new(130, 0, -80), Vector3.new(-40, 0, -150) }
	local rng = Random.new(5)
	for flock, center in centers do
		for index = 1, 3 do
			table.insert(birds, buildBird(folder, center, 55 + flock * 14 + rng:NextNumber() * 25, 48 + rng:NextNumber() * 30, 0.22 + rng:NextNumber() * 0.12, index * 0.35 + flock))
		end
	end
end

local function clearBirds()
	if birdFolder then
		birdFolder:Destroy()
		birdFolder = nil
	end
	table.clear(birds)
end

local function onCloud(instance: Instance)
	if instance:IsA("Model") then
		clouds[instance] = { Model = instance, Speed = (instance:GetAttribute("Speed") :: number?) or 2 }
	end
end

local function onTree(instance: Instance)
	if instance:IsA("Model") then
		local cframe, size = instance:GetBoundingBox()
		trees[instance] = {
			Model = instance,
			Home = instance:GetPivot(),
			Base = cframe.Position - Vector3.new(0, size.Y / 2, 0),
			Phase = math.random() * 6.28,
			Active = false,
		}
	end
end

local function step(dt: number)
	for model, cloud in clouds do
		if model.Parent then
			local pivot = model:GetPivot()
			local x = pivot.Position.X + cloud.Speed * dt
			if x > CLOUD_WRAP then
				x -= CLOUD_WRAP * 2
			end
			model:PivotTo(pivot + Vector3.new(x - pivot.Position.X, 0, 0))
		end
	end

	local time = os.clock()
	for _, tree in trees do
		if tree.Active and tree.Model.Parent then
			local angle = math.sin(time * 1.1 + tree.Phase) * TREE_AMPLITUDE
			local tilt = CFrame.new(tree.Base) * CFrame.Angles(angle, 0, angle * 0.6) * CFrame.new(-tree.Base)
			tree.Model:PivotTo(tilt * tree.Home)
		end
	end

	for _, bird in birds do
		local angle = time * bird.Speed + bird.Phase
		local position = bird.Center + Vector3.new(math.cos(angle) * bird.Radius, bird.Height + math.sin(time * 0.7 + bird.Bob) * 2, math.sin(angle) * bird.Radius)
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local body = CFrame.lookAt(position, position + tangent)
		bird.Body.CFrame = body
		local flap = math.sin(time * 9 + bird.Bob) * math.rad(34)
		bird.WingL.CFrame = body * CFrame.new(-1.45, 0.05, 0) * CFrame.Angles(0, 0, -flap)
		bird.WingR.CFrame = body * CFrame.new(1.45, 0.05, 0) * CFrame.Angles(0, 0, flap)
	end
end

function NatureController.start()
	for _, cloud in CollectionService:GetTagged("Cloud") do
		onCloud(cloud)
	end
	CollectionService:GetInstanceAddedSignal("Cloud"):Connect(onCloud)
	CollectionService:GetInstanceRemovedSignal("Cloud"):Connect(function(instance)
		clouds[instance :: Model] = nil
	end)
	task.spawn(function()
		-- trees are registered in slices so joining never hitches
		local pending = CollectionService:GetTagged("TreeSway")
		for index, tree in pending do
			onTree(tree)
			if index % 40 == 0 then
				task.wait()
			end
		end
		CollectionService:GetInstanceAddedSignal("TreeSway"):Connect(onTree)
		CollectionService:GetInstanceRemovedSignal("TreeSway"):Connect(function(instance)
			trees[instance :: Model] = nil
		end)
	end)

	task.spawn(function()
		while true do
			local camera = Workspace.CurrentCamera
			if camera then
				local position = camera.CFrame.Position
				for _, tree in trees do
					tree.Active = (tree.Home.Position - position).Magnitude < TREE_DISTANCE
				end
			end
			local low = DataController.setting("LowGraphics") == true
			if low and birdFolder then
				clearBirds()
			elseif not low and not birdFolder then
				spawnBirds()
			end
			task.wait(0.5)
		end
	end)
	RunService.RenderStepped:Connect(step)
end

return NatureController
