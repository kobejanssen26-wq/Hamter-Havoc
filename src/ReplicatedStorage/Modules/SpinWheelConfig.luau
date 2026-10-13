--[[
	SpinWheelConfig: the Lucky Wheel. Edit the numbers here, press Play.

	  FreeSpinEverySeconds   one free spin becomes available this often (default 4 hours)
	  ExtraSpinGems          price of an extra spin with diamonds while the free one is not ready (0 = no paid spins)
	  Prizes                 the slices of the wheel, in order around the wheel. Weight = how likely (relative). A prize is a
	                         normal reward table: Coins, Gems, Tokens, Boost = { Id, Seconds }, Items = { "item_id" }, Hamster = "id".
	                         Label is what the slice shows; Color its colour; Icon a drawn icon id.

	The draw happens on the SERVER (SpinSystem); the client only animates a result the server already decided.
	Coins grow with rebirths (prizes with Scale = true: amount x (1 + rebirths), so a wheel prize stays worth spinning for).
]]

local SpinWheelConfig = {}

SpinWheelConfig.FreeSpinEverySeconds = 4 * 3600
SpinWheelConfig.ExtraSpinGems = 40

SpinWheelConfig.Prizes = {
	{ Id = "cash_small", Label = "1,000 Cash", Icon = "coin", Color = Color3.fromRGB(60, 214, 84), Weight = 26, Reward = { Coins = 1000 }, Scale = true },
	{ Id = "gems_small", Label = "30 Diamonds", Icon = "gem", Color = Color3.fromRGB(176, 98, 255), Weight = 18, Reward = { Gems = 30 } },
	{ Id = "speed", Label = "Speed Tonic", Icon = "bolt", Color = Color3.fromRGB(56, 160, 255), Weight = 12, Reward = { Items = { "item_speed" } } },
	{ Id = "cash_mid", Label = "5,000 Cash", Icon = "pouch", Color = Color3.fromRGB(255, 148, 28), Weight = 14, Reward = { Coins = 5000 }, Scale = true },
	{ Id = "luck", Label = "Lucky Boost 15 min", Icon = "clover", Color = Color3.fromRGB(26, 214, 190), Weight = 9, Reward = { Boost = { Id = "Luck2x", Seconds = 900 } } },
	{ Id = "banana", Label = "Banana Peel", Icon = "banana", Color = Color3.fromRGB(255, 214, 40), Weight = 8, Reward = { Items = { "banana_peel" } } },
	{ Id = "gems_big", Label = "120 Diamonds", Icon = "gem", Color = Color3.fromRGB(255, 84, 170), Weight = 6, Reward = { Gems = 120 } },
	{ Id = "cash_big", Label = "25,000 Cash", Icon = "crown", Color = Color3.fromRGB(255, 72, 88), Weight = 3, Reward = { Coins = 25000 }, Scale = true },
	{ Id = "jackpot", Label = "JACKPOT 500 Diamonds", Icon = "gift", Color = Color3.fromRGB(255, 214, 40), Weight = 1, Reward = { Gems = 500, Coins = 50000 }, Scale = true },
}

function SpinWheelConfig.totalWeight(): number
	local total = 0
	for _, prize in SpinWheelConfig.Prizes do
		total += prize.Weight
	end
	return total
end

-- Picks a prize index for a random number in [0, 1).
function SpinWheelConfig.pick(roll: number): number
	local target = roll * SpinWheelConfig.totalWeight()
	local running = 0
	for index, prize in SpinWheelConfig.Prizes do
		running += prize.Weight
		if target < running then
			return index
		end
	end
	return #SpinWheelConfig.Prizes
end

-- The reward table a prize pays out for a player with `rebirths` rebirths.
function SpinWheelConfig.reward(prize: any, rebirths: number): any
	local reward = table.clone(prize.Reward)
	if prize.Scale and reward.Coins then
		reward.Coins = reward.Coins * (1 + rebirths)
	end
	return reward
end

return SpinWheelConfig
