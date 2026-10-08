--[[
	Server entry point. Wires the services together; game rules live in the services.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

require(ReplicatedStorage.Shared.Remotes).init()

local Services = script.Parent.Services
local BaseService = require(Services.BaseService)
local DataService = require(Services.DataService)
local IncomeService = require(Services.IncomeService)
local MapService = require(Services.MapService)
local PurchaseService = require(Services.PurchaseService)
local RouteService = require(Services.RouteService)
local StealService = require(Services.StealService)

MapService.build()
BaseService.start()
RouteService.start()
PurchaseService.start()
IncomeService.start()
StealService.start()

local function onPlayerAdded(player: Player)
	DataService.create(player)
	BaseService.assign(player)
end

local function onPlayerRemoving(player: Player)
	-- Order matters: resolve active thefts first, then free the base, then drop the data.
	StealService.onPlayerLeaving(player)
	BaseService.release(player)
	DataService.remove(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end
