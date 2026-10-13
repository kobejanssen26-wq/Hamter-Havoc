--[[
	SpinSystem: the Lucky Wheel on the server. One free spin every SpinWheelConfig.FreeSpinEverySeconds, extra spins for
	diamonds. The prize is drawn HERE (the client only plays the animation of a result it was told), granted through the same
	Rewards.grant as quests and daily rewards, and the next-free-spin time is saved in profile.Wheel.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpinWheelConfig = require(ReplicatedStorage.Modules.SpinWheelConfig)

local DataSystem = require(script.Parent.DataSystem)
local EconomySystem = require(script.Parent.EconomySystem)
local Notifier = require(script.Parent.Notifier)
local ReplicationSystem = require(script.Parent.ReplicationSystem)
local Rewards = require(script.Parent.Rewards)

local SpinSystem = {}

local random = Random.new()
local busy: { [Player]: boolean } = {}

-- Returns (ok, message, { Index, Prize id, Free })
function SpinSystem.spin(player: Player, payWithGems: any): (boolean, string, any?)
	local data = DataSystem.get(player)
	if not data then
		return false, "No data"
	end
	if busy[player] then
		return false, "The wheel is already spinning"
	end
	local now = os.time()
	local free = now >= (data.Wheel.NextFreeAt or 0)
	if not free then
		if payWithGems ~= true or SpinWheelConfig.ExtraSpinGems <= 0 then
			return false, "Your next free spin is not ready yet"
		end
		if not EconomySystem.trySpendGems(player, SpinWheelConfig.ExtraSpinGems) then
			return false, "You need " .. SpinWheelConfig.ExtraSpinGems .. " diamonds for an extra spin"
		end
	end
	busy[player] = true
	if free then
		data.Wheel.NextFreeAt = now + SpinWheelConfig.FreeSpinEverySeconds
	end
	local index = SpinWheelConfig.pick(random:NextNumber())
	local prize = SpinWheelConfig.Prizes[index]
	local lines = Rewards.grant(player, SpinWheelConfig.reward(prize, data.Rebirths))
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

function SpinSystem.forget(player: Player)
	busy[player] = nil
end

return SpinSystem
