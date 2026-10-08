--[[
	SecuritySystem: the gate of every house.

	  Active      laser gate on: strangers inside the lot (or walking in) get zapped out and drop what they carry
	  Recharging  switched off, the gate is still cooling down
	  Ready       switched off and ready: the owner presses E at the pylon to turn it on again

	While the gate is off ANYBODY can walk in - that's the window thieves watch for (the timer is shown above
	every gate). Secured hamsters can never be stolen; what you can steal inside a house is a ball that is
	still rolling / being carried to the arrival pad.

	Times use the server clock (Workspace:GetServerTimeNow) so clients can show exact countdowns from the
	house attributes SecState / SecUntil / SecReady.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage.Modules
local SecurityConfig = require(Modules.SecurityConfig)
local WorldLayout = require(Modules.WorldLayout)

local Remotes = require(ReplicatedStorage.Remotes)

local DataSystem = require(script.Parent.DataSystem)
local Events = require(script.Parent.Events)
local HamsterSystem = require(script.Parent.HamsterSystem)
local HouseBuilder = require(script.Parent.WorldBuilder.HouseBuilder)
local HouseSystem = require(script.Parent.HouseSystem)
local Notifier = require(script.Parent.Notifier)
local PlayerState = require(script.Parent.PlayerState)

local SecuritySystem = {}

type Timers = { Until: number, ReadyAt: number, Status: string, Tier: string }

local timers: { [number]: Timers } = {}
local lastZap: { [Player]: number } = {}

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function tierOf(house: HouseBuilder.House)
	local data = if house.Owner then DataSystem.get(house.Owner) else nil
	return SecurityConfig.tier(if data then data.Rebirths else 0)
end

local function timersOf(house: HouseBuilder.House): Timers
	local entry = timers[house.Index]
	if not entry then
		entry = { Until = 0, ReadyAt = 0, Status = "None", Tier = "" }
		timers[house.Index] = entry
	end
	return entry
end

function SecuritySystem.status(house: HouseBuilder.House): string
	if not house.Owner then
		return "None"
	end
	local entry = timersOf(house)
	local time = now()
	if time < entry.Until then
		return "Active"
	elseif time < entry.ReadyAt then
		return "Recharging"
	end
	return "Ready"
end

function SecuritySystem.isActive(house: HouseBuilder.House): boolean
	return SecuritySystem.status(house) == "Active"
end

local function publish(house: HouseBuilder.House)
	local entry = timersOf(house)
	local status = SecuritySystem.status(house)
	local tier = tierOf(house)
	local model = house.Model
	model:SetAttribute("SecUntil", entry.Until)
	model:SetAttribute("SecReady", entry.ReadyAt)
	model:SetAttribute("SecTier", tier.Name)
	model:SetAttribute("SecState", status)
	if status ~= entry.Status or tier.Name ~= entry.Tier then
		local before = entry.Status
		entry.Status = status
		entry.Tier = tier.Name
		HouseBuilder.setSecurity(house, status, tier)
		local owner = house.Owner
		if owner and before ~= status then
			if status == "Active" then
				Remotes.event("Fx"):FireAllClients("SecurityOn", "", house.GatePosition, house.Index)
			elseif before == "Active" then
				Remotes.event("Fx"):FireAllClients("SecurityOff", "", house.GatePosition, house.Index)
				Notifier.send(owner, "🔴 SECURITY OFF! Your gate is open.", "error")
			elseif status == "Ready" then
				Notifier.send(owner, "Security recharged. Press E at the gate panel to switch it on.", "info")
			end
		end
	end
end

function SecuritySystem.activate(house: HouseBuilder.House): boolean
	if not house.Owner then
		return false
	end
	local entry = timersOf(house)
	local tier = tierOf(house)
	local time = now()
	entry.Until = time + tier.Duration
	entry.ReadyAt = entry.Until + tier.Recharge
	publish(house)
	return true
end

local function zap(player: Player, house: HouseBuilder.House)
	local clock = os.clock()
	if (lastZap[player] or 0) + SecurityConfig.ZapCooldown > clock then
		return
	end
	lastZap[player] = clock
	local humanoid, root = PlayerState.character(player)
	if not humanoid or not root then
		return
	end
	local dropped = HamsterSystem.dropCarried(player, "Zap", 4)
	HamsterSystem.interrupt(player)
	PlayerState.stun(player, SecurityConfig.ZapStunSeconds, 1)

	-- throw them back to the street (or put them there if they're deep inside)
	local outward = house.CFrame:VectorToWorldSpace(Vector3.new(0, 0, -1))
	local localPosition = house.CFrame:PointToObjectSpace(root.Position)
	if localPosition.Z > 8 then
		local character = player.Character
		if character then
			character:PivotTo(house.CFrame * CFrame.new(0, 4, -5) * CFrame.Angles(0, math.pi, 0))
		end
	end
	Remotes.event("Knockback"):FireClient(player, outward * 46 + Vector3.new(0, 24, 0))
	Remotes.event("Fx"):FireAllClients("Zap", "", root.Position, house.Index)
	local ownerName = if house.Owner then house.Owner.DisplayName else "this"
	Notifier.send(player, string.format("🛡️ %s's security zapped you!%s", ownerName, if dropped then " You dropped your hamster." else ""), "error")
end

local function scanZaps(house: HouseBuilder.House)
	for _, player in Players:GetPlayers() do
		if player ~= house.Owner then
			local _, root = PlayerState.character(player)
			if root and WorldLayout.inLot(house.CFrame, root.Position, 0) then
				zap(player, house)
			end
		end
	end
end

function SecuritySystem.start()
	Events.HouseClaimed:Connect(function(house: HouseBuilder.House, _player: Player)
		local entry = timersOf(house)
		entry.Until = 0
		entry.ReadyAt = 0
		if SecurityConfig.StartActive then
			SecuritySystem.activate(house)
		else
			publish(house)
		end
	end)
	Events.HouseFreed:Connect(function(house: HouseBuilder.House)
		local entry = timersOf(house)
		entry.Until = 0
		entry.ReadyAt = 0
		publish(house)
	end)

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		local houseIndex = prompt:GetAttribute("SecurityHouse")
		if type(houseIndex) ~= "number" then
			return
		end
		local house = HouseSystem.getHouse(player)
		if not house or house.Index ~= houseIndex then
			Notifier.send(player, "Only the owner can use this panel.", "error")
			return
		end
		local status = SecuritySystem.status(house)
		if status == "Ready" then
			SecuritySystem.activate(house)
			Notifier.send(player, "🛡️ Security activated!", "success")
		elseif status == "Recharging" then
			Notifier.send(player, "The gate is still recharging.", "info")
		end
	end)

	for _, house in HouseSystem.all() do
		publish(house)
	end
	task.spawn(function()
		while true do
			task.wait(0.25)
			for _, house in HouseSystem.all() do
				local ok, err = pcall(function()
					publish(house)
					if SecuritySystem.status(house) == "Active" then
						scanZaps(house)
					end
				end)
				if not ok then
					warn("[SecuritySystem] " .. tostring(err))
				end
			end
		end
	end)
end

function SecuritySystem.forget(player: Player)
	lastZap[player] = nil
end

return SecuritySystem
