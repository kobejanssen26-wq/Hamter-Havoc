--[[
	Boots the real server (Main.server) headless with a fake player and checks the apartment,
	rebirth and wheel integration: floors unlock with rebirths, hamsters work on wheels on the best
	floors, wheels turn the right way, kept hamsters survive a rebirth, the house resets when the owner leaves.
	usage: lune run tools/lune/server_test.luau [projectRoot]
]]

local process = require("@lune/process")
local task = require("@lune/task")
local Runtime = require("./runtime")
local Mocks = require("./servermocks")

local stdio = require("@lune/stdio")
local root = process.args[1] or "."
local game = Runtime.boot(root)
Runtime.quiet = process.env.VERBOSE == nil
Runtime.reportErrors = true
Mocks.install()

local failures, passes = 0, 0
local function check(ok: boolean, label: string, detail: any?)
	if ok then
		passes += 1
	else
		failures += 1
		print("FAIL  " .. label .. (if detail ~= nil then "  (" .. tostring(detail) .. ")" else ""))
	end
end

local function run()
	local ok, err = pcall(Mocks.runScript, game:GetService("ServerScriptService").Main)
	check(ok, "server boots", err)

	local Systems = game:GetService("ServerScriptService").Systems
	local DataSystem = Runtime.require(Systems.DataSystem)
	local HouseSystem = Runtime.require(Systems.HouseSystem)
	local RebirthSystem = Runtime.require(Systems.RebirthSystem)
	local CollectionSystem = Runtime.require(Systems.CollectionSystem)
	local UpgradeSystem = Runtime.require(Systems.UpgradeSystem)
	local Events = Runtime.require(Systems.Events)
	local HamsterDatabase = Runtime.mod("HamsterDatabase")
	local RebirthConfig = Runtime.mod("RebirthConfig")
	local FloorConfig = Runtime.mod("FloorConfig")
	local EconomyMath = Runtime.mod("EconomyMath")

	-- Lune's engine events (Players.PlayerAdded ...) are inert, so run Main's join flow by hand
	local EconomySystem = Runtime.require(Systems.EconomySystem)
	local ShopSystem = Runtime.require(Systems.ShopSystem)
	local player = Mocks.addPlayer("Alice", 101)
	DataSystem.load(player)
	EconomySystem.updateAttributes(player)
	ShopSystem.loadPasses(player)
	HouseSystem.assign(player)
	check(DataSystem.isTemporary(player) == false, "profile came from the (mock) data store")
	local data = DataSystem.get(player)
	check(data ~= nil, "profile loaded")
	local house = HouseSystem.getHouse(player)
	check(house ~= nil, "player got an apartment")
	check(house and house.FloorCount == 1, "starts with one floor", house and house.FloorCount)
	check(house and house.Model:FindFirstChild("Scaffold") and #house.Model.Scaffold:GetChildren() > 0, "next floor is shown as scaffolding")

	-- give hamsters: one of every rarity up to Ultra plus a few Basics
	local function give(rarity: string, count: number)
		local pool = HamsterDatabase.Spawnable[rarity]
		for index = 1, count do
			local species = pool[(index - 1) % #pool + 1]
			data.Inventory[species.Id] = (data.Inventory[species.Id] or 0) + 1
			data.Index[species.Id] = true
		end
	end
	give("Basic", 6)
	give("Rare", 1)
	give("Ultra", 1)
	CollectionSystem.equipBest(player)
	task.wait(0.1)
	local slots = EconomyMath.slots(data)
	local working = 0
	for slotIndex, entry in house.DisplayModels do
		working += 1
		local wheel = house.Slots[slotIndex].Wheel
		check(wheel ~= nil and (wheel:GetAttribute("Speed") or 0) ~= 0, "working hamster's wheel turns", slotIndex)
		check(entry.Model:GetAttribute("Income") > 0, "working hamster shows its income")
		check(house.Slots[slotIndex].Label ~= nil and string.find(house.Slots[slotIndex].Label.Text, "/s") ~= nil, "wheel label shows name and $/s")
	end
	check(working == slots, "every slot has a working hamster", string.format("%d/%d", working, slots))

	-- rebirth gate: not enough coins yet
	local done, message = RebirthSystem.perform(player)
	check(not done, "cannot rebirth without the requirements", message)

	-- run rebirths and watch the building grow
	local function meetRequirements()
		local req = RebirthConfig.requirements(data.Rebirths + 1)
		data.Coins = req.Coins
		give(req.Rarity, 1)
		give("Basic", req.Hamsters)
	end
	for n = 1, 14 do
		meetRequirements()
		local performed, why = RebirthSystem.perform(player)
		check(performed, "rebirth " .. n .. " works", why)
		-- read coins right away: the kept hamsters keep earning, so an income tick may land during the wait
		local coinsAfter = data.Coins
		task.wait(0.05)
		check(house.FloorCount == FloorConfig.unlocked(n), "apartment has the right floors after rebirth " .. n, house.FloorCount)
		check(data.Rebirths == n, "rebirth counter", data.Rebirths)
		local kept = 0
		for _, amount in data.Inventory do
			kept += amount
		end
		check(kept == RebirthConfig.keepBest(n), "keeps exactly the best hamsters after rebirth " .. n, kept)
		check(coinsAfter == RebirthConfig.startingCoins(n), "coins reset after rebirth " .. n, coinsAfter)
	end
	check(house.FloorCount == 5, "five floors at rebirth 14")
	check(house.Stations.TurboWheels ~= nil, "lab has the advanced station")
	check(house.Prompts.TurboWheels:GetAttribute("OwnerUserId") == player.UserId, "advanced station belongs to the owner")
	local lifts = 0
	for floor, prompt in house.ElevatorPrompts do
		lifts += 1
		check(string.find(prompt.ActionText, if floor == 5 then "lobby" else "Floor " .. (floor + 1)) ~= nil, "lift on floor " .. floor .. " says where it goes", prompt.ActionText)
	end
	check(lifts == 5, "a lift panel on every floor")

	-- fill the building and check that the best hamsters are on the penthouse
	give("Mythic", 1)
	give("Basic", 30)
	CollectionSystem.equipBest(player)
	task.wait(0.1)
	local mythicFloor = 0
	for slotIndex, entry in house.DisplayModels do
		if HamsterDatabase.ById[entry.SpeciesId].Rarity == "Mythic" then
			mythicFloor = house.Slots[slotIndex].Floor
		end
	end
	check(mythicFloor == 5, "the best hamster runs in the penthouse", mythicFloor)

	-- advanced upgrade can be bought now
	data.Coins = 1e15
	local bought = UpgradeSystem.buy(player, "TurboWheels")
	check(bought, "advanced upgrade can be bought with floor 3")

	-- owner leaves: the apartment goes back to one empty floor
	HouseSystem.release(player)
	DataSystem.release(player)
	Mocks.removePlayer(player)
	task.wait(0.1)
	check(house.Owner == nil and house.FloorCount == 1, "apartment resets when the owner leaves", house.FloorCount)
	local displays = 0
	for _ in house.DisplayModels do
		displays += 1
	end
	check(displays == 0, "no hamsters left on the wheels")


end

local okRun, runError = pcall(run)
if not okRun then
	failures += 1
	stdio.ewrite("ERROR " .. tostring(runError) .. "\n")
end
for _, message in Runtime.errors do
	failures += 1
	print("FAIL  background task error: " .. string.split(message, "\n")[1])
end
print(string.format("%d checks passed, %d failed", passes, failures))
process.exit(if failures > 0 then 1 else 0)
