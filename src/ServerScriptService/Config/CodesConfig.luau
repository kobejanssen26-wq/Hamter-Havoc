--[[
	Promo codes. Add a new code by adding one entry here (codes are case-insensitive, one use per player).
	Reward: { Coins, Gems, Tokens, Boost = { Id, Seconds }, Hamster = speciesId }
	Optional: ExpiresAt = unix timestamp.
	This module lives on the SERVER only, so players can't read the list.
]]

return {
	HAMSTER = { Reward = { Coins = 500, Gems = 50 }, Note = "Starter gift" },
	WELCOME = { Reward = { Coins = 1000, Gems = 100 }, Note = "Welcome to Hamster Plaza" },
	PLAZA = { Reward = { Gems = 100, Boost = { Id = "Luck2x", Seconds = 600 } }, Note = "Plaza luck" },
	RELEASE = { Reward = { Gems = 200, Hamster = "founder_fuzz" }, Note = "Release celebration (exclusive hamster)" },
}
