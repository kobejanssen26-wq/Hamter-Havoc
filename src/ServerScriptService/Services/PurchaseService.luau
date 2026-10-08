--[[
	Server-side purchase validation. Triggered only by a ball's ProximityPrompt (via RouteService).
	Order: validate -> claim ball off the route -> remove money -> give hamster -> send to base.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Util.Format)

local Services = script.Parent
local BaseService = require(Services.BaseService)
local DataService = require(Services.DataService)
local Notifier = require(Services.Notifier)
local RouteService = require(Services.RouteService)

local PurchaseService = {}

function PurchaseService.onBuyRequested(player: Player, ballId: string)
	if type(ballId) ~= "string" or not DataService.get(player) then
		return
	end

	local ball = RouteService.getBall(ballId)
	if not ball or ball.Claimed then
		return -- somebody else was faster
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	if (root.Position - ball.Carrier.Position).Magnitude > GameConfig.Purchase.MaxDistance then
		return
	end

	if not BaseService.getBaseOf(player) then
		Notifier.send(player, "You don't have a base yet - all bases are taken.", "error")
		return
	end
	if not BaseService.hasFreeSlot(player) then
		Notifier.send(player, "All your hamster wheels are full!", "error")
		return
	end

	local hamster = ball.Hamster
	local state = DataService.get(player)
	if state.Cash < hamster.PurchasePrice then
		Notifier.send(player, "Not enough cash! Need " .. Format.money(hamster.PurchasePrice), "error")
		return
	end

	-- No yields below this point, so the sequence is atomic.
	if not RouteService.claimBall(ballId) then
		return
	end
	DataService.trySpend(player, hamster.PurchasePrice)
	DataService.addHamster(player, hamster)
	BaseService.placeHamster(player, hamster)

	Notifier.send(
		player,
		string.format("Bought %s %s for %s!", hamster.Rarity, hamster.Name, Format.money(hamster.PurchasePrice)),
		"success"
	)
end

function PurchaseService.start()
	RouteService.setBuyHandler(PurchaseService.onBuyRequested)
end

return PurchaseService
