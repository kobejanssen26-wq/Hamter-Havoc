--[[
	SpinSystem: the Lucky Wheel on the server. ONE free spin every Wheel.FreeSpinSeconds (GameConfig, default 3 hours); there is no
	way to pay for another one. The player stands at the physical wheel in the plaza and presses [F] (prompt attribute SpinWheel).
	The prize is drawn HERE (the client only plays the animation of a result it was told), scaled to the player's progress by
	SpinWheelConfig, granted through the same Rewards.grant as quests and daily rewards, and the next-free-spin time is saved in
	profile.Wheel.NextFreeAt (a server timestamp: rejoining, switching servers, respawning or changing the PC clock can not skip it).

	Exactly once: a spin is accepted only while the player is at the wheel, no other spin is running (busy) and the time is reached;
	the time stamp is taken BEFORE anything is paid, and if paying fails half way the spin is given back instead of being paid twice.
]]

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local SpinWheelConfig = require(ReplicatedStorage.Modules.SpinWheelConfig)

local DataSystem = require(script.Parent.DataSystem)
local DiscordLog = require(script.Parent.DiscordLog)
local Notifier = require(script.Parent.Notifier)
local ReplicationSystem = require(script.Parent.ReplicationSystem)
local Rewards = require(script.Parent.Rewards)
local WheelWorld = require(script.Parent.WheelWorld)

local SpinSystem = {}

local random = Random.new()
local busy: { [Player]: boolean } = {}
local lastRequest: { [Player]: number } = {}
local MIN_GAP = 0.5 -- seconds between two requests of one player (button mashing)

-- Returns (ok, message, { Index, Prize id, Lines }). ONE free spin per Wheel.FreeSpinSeconds, nothing can be paid for another one.
function SpinSystem.spin(player: Player): (boolean, string, any?)
	local data = DataSystem.get(player)
	if not data then
		return false, "No data"
	end
	if not WheelWorld.isNear(player) then
		return false, "Walk to the Lucky Wheel behind the shops to spin it"
	end
	if WheelWorld.busy() then
		return false, "Somebody else is spinning the wheel, try again in a moment"
	end
	local clock = os.clock()
	if busy[player] or clock - (lastRequest[player] or -10) < MIN_GAP then
		return false, "The wheel is already spinning"
	end
	lastRequest[player] = clock
	local now = os.time()
	if now < (data.Wheel.NextFreeAt or 0) then
		return false, "Your next free spin is not ready yet"
	end
	local ctx = SpinWheelConfig.context(data, now)
	local index = SpinWheelConfig.pick(random:NextNumber(), ctx)
	if not index then
		return false, "The wheel is not available right now"
	end

	busy[player] = true
	local previousNext = data.Wheel.NextFreeAt
	data.Wheel.NextFreeAt = now + SpinWheelConfig.freeSpinSeconds() -- taken BEFORE anything is paid
	local prize = SpinWheelConfig.Prizes[index]
	local paid, lines = pcall(function()
		return Rewards.grant(player, SpinWheelConfig.reward(prize, ctx, { Amount = random:NextNumber(), Pick = random:NextNumber() }))
	end)
	if not paid then
		-- paying failed: give the spin back (never pay twice for one spin)
		warn("[Wheel] paying prize " .. prize.Id .. " failed: " .. tostring(lines))
		data.Wheel.NextFreeAt = previousNext
		busy[player] = nil
		ReplicationSystem.mark(player, "Wheel")
		return false, "Something went wrong, your spin was kept"
	end
	DataSystem.markDirty(player)
	ReplicationSystem.mark(player, "Wheel")
	pcall(DiscordLog.wheel, player, prize.Id, lines)
	WheelWorld.spin(index) -- the physical wheel in the plaza turns to the SAME prize (every client animates it)
	-- the reward message waits until the animation is over
	task.delay(WheelWorld.duration() + 0.4, function()
		busy[player] = nil
		if player.Parent ~= nil then
			Notifier.send(player, "Lucky Wheel: " .. Rewards.describe(lines), "reward")
		end
	end)
	return true, prize.Label, { Index = index, Lines = lines }
end

-- Tells the clients the live settings (the info panel shows the real cooldown) and checks the prize list.
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
	WheelWorld.prepare()
	GameConfig.onChanged(function(section)
		if section == "Wheel" then
			publish()
		end
	end)
	-- the [F] prompt on the physical wheel: the server decides everything, a refusal is told to the player as a small message
	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if prompt:GetAttribute("SpinWheel") ~= true then
			return
		end
		local ok, message = SpinSystem.spin(player)
		if not ok then
			Notifier.send(player, message, "error")
		end
	end)
end

function SpinSystem.forget(player: Player)
	busy[player] = nil
	lastRequest[player] = nil
end

return SpinSystem
