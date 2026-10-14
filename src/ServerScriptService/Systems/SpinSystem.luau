--[[
	SpinSystem: the Lucky Wheel on the server. One free spin every Wheel.FreeSpinSeconds (GameConfig, default 2 hours), extra
	spins for diamonds. The prize is drawn HERE (the client only plays the animation of a result it was told), scaled to the
	player's progress by SpinWheelConfig, granted through the same Rewards.grant as quests and daily rewards, and the
	next-free-spin time is saved in profile.Wheel.NextFreeAt (a server timestamp: rejoining, switching servers, respawning or
	changing the PC clock can not skip it).

	Exactly once: a spin is accepted only while no other spin of this player is running (busy), the time stamp / diamonds are
	taken BEFORE anything is paid, and if paying fails half way the spin is given back instead of being paid twice.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local SpinWheelConfig = require(ReplicatedStorage.Modules.SpinWheelConfig)

local DataSystem = require(script.Parent.DataSystem)
local EconomySystem = require(script.Parent.EconomySystem)
local Notifier = require(script.Parent.Notifier)
local ReplicationSystem = require(script.Parent.ReplicationSystem)
local Rewards = require(script.Parent.Rewards)

local SpinSystem = {}

local random = Random.new()
local busy: { [Player]: boolean } = {}
local lastRequest: { [Player]: number } = {}
local MIN_GAP = 0.5 -- seconds between two requests of one player (button mashing)

-- Returns (ok, message, { Index, Prize id, Free, Lines })
function SpinSystem.spin(player: Player, payWithGems: any): (boolean, string, any?)
	local data = DataSystem.get(player)
	if not data then
		return false, "No data"
	end
	local clock = os.clock()
	if busy[player] or clock - (lastRequest[player] or -10) < MIN_GAP then
		return false, "The wheel is already spinning"
	end
	lastRequest[player] = clock
	local now = os.time()
	local ctx = SpinWheelConfig.context(data, now)
	local index = SpinWheelConfig.pick(random:NextNumber(), ctx)
	if not index then
		return false, "The wheel is not available right now"
	end

	local free = now >= (data.Wheel.NextFreeAt or 0)
	local price = SpinWheelConfig.extraSpinGems()
	if not free then
		if payWithGems ~= true or price <= 0 then
			return false, "Your next free spin is not ready yet"
		end
		if not EconomySystem.trySpendGems(player, price) then
			return false, "You need " .. price .. " diamonds for an extra spin"
		end
	end
	busy[player] = true
	local previousNext = data.Wheel.NextFreeAt
	if free then
		data.Wheel.NextFreeAt = now + SpinWheelConfig.freeSpinSeconds()
	end
	local prize = SpinWheelConfig.Prizes[index]
	local paid, lines = pcall(function()
		return Rewards.grant(player, SpinWheelConfig.reward(prize, ctx, { Amount = random:NextNumber(), Pick = random:NextNumber() }))
	end)
	if not paid then
		-- paying failed: give the spin back (never pay twice for one spin)
		warn("[Wheel] paying prize " .. prize.Id .. " failed: " .. tostring(lines))
		data.Wheel.NextFreeAt = previousNext
		if not free then
			EconomySystem.addGems(player, price, false)
		end
		busy[player] = nil
		ReplicationSystem.mark(player, "Wheel")
		return false, "Something went wrong, your spin was kept"
	end
	DataSystem.markDirty(player)
	ReplicationSystem.mark(player, "Wheel")
	-- the reward message waits until the client's animation is over (it takes about 4 seconds)
	task.delay(4.4, function()
		busy[player] = nil
		if player.Parent ~= nil then
			Notifier.send(player, "Lucky Wheel: " .. Rewards.describe(lines), "reward")
		end
	end)
	return true, prize.Label, { Index = index, Free = free, Lines = lines }
end

-- Tells the clients the live settings (the window shows the real price) and checks the prize list.
local function publish()
	for _, key in SpinWheelConfig.Settings do
		ReplicatedStorage:SetAttribute("Wheel_" .. key, GameConfig.get("Wheel", key))
	end
end

function SpinSystem.start()
	for _, issue in SpinWheelConfig.validate() do
		warn("[Wheel] " .. issue .. " (this prize is skipped)")
	end
	publish()
	GameConfig.onChanged(function(section)
		if section == "Wheel" then
			publish()
		end
	end)
end

function SpinSystem.forget(player: Player)
	busy[player] = nil
	lastRequest[player] = nil
end

return SpinSystem
