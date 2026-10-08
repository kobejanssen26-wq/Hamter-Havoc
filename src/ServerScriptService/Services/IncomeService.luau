--[[
	Passive income: every tick, each player's wheel income flows into their collector (Stored).
	Collecting moves Stored into Cash. (Auto-collectors / collector pets come later.)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Util.Format)

local Services = script.Parent
local DataService = require(Services.DataService)
local Notifier = require(Services.Notifier)

local IncomeService = {}

function IncomeService.collect(player: Player)
	local amount = DataService.takeStored(player)
	if amount <= 0 then
		Notifier.send(player, "Collector is empty.", "info")
		return
	end
	DataService.addCash(player, amount)
	Notifier.send(player, "Collected " .. Format.money(amount), "success")
end

function IncomeService.start()
	task.spawn(function()
		local lastTick = os.clock()
		while true do
			task.wait(GameConfig.Economy.IncomeTickSeconds)
			local now = os.clock()
			local elapsed = now - lastTick
			lastTick = now
			for _, player in Players:GetPlayers() do
				local perSecond = DataService.getIncomePerSecond(player)
				if perSecond > 0 then
					DataService.addStored(player, perSecond * elapsed)
				end
			end
		end
	end)
end

return IncomeService
