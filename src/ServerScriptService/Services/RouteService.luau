--[[
	Spawns hamster balls at the start of the route, rolls them along it (server controlled),
	removes them at the end. Each ball has a "BUY" ProximityPrompt; what happens on trigger
	is decided by PurchaseService through setBuyHandler (the client never sends a purchase).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Util.Format)
local RouteMath = require(Shared.Util.RouteMath)

local Services = script.Parent
local HamsterFactory = require(Services.HamsterFactory)
local HamsterModel = require(Services.HamsterModel)

local RouteService = {}

local routeConfig = GameConfig.Route
local totalLength = RouteMath.totalLength()
local ballHeight = GameConfig.Map.GroundY + GameConfig.Map.RouteThickness + routeConfig.BallDiameter / 2

local balls = {} -- [UniqueId] = ball
local ballsFolder: Folder
local buyHandler: ((Player, string) -> ())? = nil

function RouteService.setBuyHandler(handler: (Player, string) -> ())
	buyHandler = handler
end

function RouteService.getBall(id: string)
	return balls[id]
end

-- Atomically takes a ball off the route. Returns the hamster record, or nil if it is already gone.
function RouteService.claimBall(id: string)
	local ball = balls[id]
	if not ball or ball.Claimed then
		return nil
	end
	ball.Claimed = true
	balls[id] = nil
	ball.Model:Destroy()
	return ball.Hamster
end

local function countBalls(): number
	local count = 0
	for _ in balls do
		count += 1
	end
	return count
end

local function createBuyPrompt(carrier: BasePart, hamster)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ObjectText = string.upper(hamster.Rarity) .. " HAMSTER - " .. hamster.Name
	prompt.ActionText = "BUY  " .. Format.money(hamster.PurchasePrice)
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		if buyHandler then
			buyHandler(player, hamster.UniqueId)
		end
	end)
	prompt.Parent = carrier
end

local function spawnBall()
	if countBalls() >= routeConfig.MaxBalls then
		return
	end

	local hamster = HamsterFactory.create()
	local position, tangent = RouteMath.pointAt(0)
	local center = position + Vector3.new(0, ballHeight, 0)
	local model, carrier, hull = HamsterModel.buildBall(hamster, CFrame.lookAt(center, center + tangent))

	HamsterModel.createBillboard(
		carrier,
		HamsterModel.richDescription(hamster, true),
		Vector3.new(0, routeConfig.BallDiameter / 2 + 3, 0)
	)
	createBuyPrompt(carrier, hamster)

	model.Parent = ballsFolder
	balls[hamster.UniqueId] = {
		Hamster = hamster,
		Model = model,
		Carrier = carrier,
		Hull = hull,
		Distance = 0,
		Roll = 0,
		Claimed = false,
	}
end

local function stepBalls(deltaTime: number)
	local speed = routeConfig.BallSpeed
	local radius = routeConfig.BallDiameter / 2
	for id, ball in balls do
		ball.Distance += speed * deltaTime
		if ball.Distance >= totalLength then
			balls[id] = nil
			ball.Model:Destroy()
		else
			local position, tangent = RouteMath.pointAt(ball.Distance)
			local center = position + Vector3.new(0, ballHeight, 0)
			local cframe = CFrame.lookAt(center, center + tangent)
			ball.Model:PivotTo(cframe)
			ball.Roll += speed * deltaTime / radius
			ball.Hull.CFrame = cframe * CFrame.Angles(-ball.Roll, 0, 0)
		end
	end
end

function RouteService.start()
	ballsFolder = Instance.new("Folder")
	ballsFolder.Name = "HamsterBalls"
	ballsFolder.Parent = Workspace

	RunService.Heartbeat:Connect(stepBalls)

	task.spawn(function()
		while true do
			spawnBall()
			task.wait(GameConfig.Debug.SpawnIntervalOverride or routeConfig.SpawnIntervalSeconds)
		end
	end)
end

return RouteService
