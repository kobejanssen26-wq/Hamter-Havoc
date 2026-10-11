local function section(t) print("\n== " .. t .. " ==") end
local function report()
	print("errors:", #M.Sim.errors)
	for i, e in M.Sim.errors do if i <= 8 then print(e) end end
end
local Players = game:GetService("Players")
local function fireJoin(p)
	M.Sim.advance(0.01)
	RawData[Players].Signals.PlayerAdded:Fire(p)
end

local function countClasses(root)
	local counts = {}
	for _, d in M.descendants(root) do
		local c = RawData[d].ClassName
		counts[c] = (counts[c] or 0) + 1
	end
	return counts
end

task.spawn(function()
	section("boot server")
	M.isServer = true
	local mainServer = find("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	M.Sim.advance(1)
	local c = countClasses(workspace)
	local parts = (c.Part or 0) + (c.WedgePart or 0) + (c.SpawnLocation or 0)
	print("BaseParts in workspace:", parts, " lights:", c.PointLight or 0, " emitters:", c.ParticleEmitter or 0, " billboards:", c.BillboardGui or 0, " prompts:", c.ProximityPrompt or 0)
	report()

	section("player Alice joins")
	local alice = M.newPlayer("Alice")
	fireJoin(alice)
	M.spawnCharacter(alice)
	M.Sim.advance(6)
	print("DataLoaded:", alice:GetAttribute("DataLoaded"), "Coins:", alice:GetAttribute("Coins"), "Gems:", alice:GetAttribute("Gems"), "HouseId:", alice:GetAttribute("HouseId"))
	report()

	section("client starts for Alice")
	M.localPlayerRef = alice
	local gui = M.newInstance("PlayerGui", true); RawData[gui].Name = "PlayerGui"; M.setParent(gui, alice)
	M.isServer = false
	M.clientRunning = true
	local mainClient = find("StarterPlayer.StarterPlayerScripts.Main")
	task.spawn(function() RawData[mainClient].Source(mainClient, require) end)
	M.Sim.advance(4)
	print("ClientReady:", alice:GetAttribute("ClientReady"))
	local cg = countClasses(gui)
	print("PlayerGui instances:", #M.descendants(gui), " ScreenGuis:", cg.ScreenGui or 0)
	report()

	section("seed some hamsters through the real grant path")
	local DataSystem = require(find("ServerScriptService.Systems.DataSystem"))
	local CollectionSystem = require(find("ServerScriptService.Systems.CollectionSystem"))
	local HamsterDatabase = require(find("ReplicatedStorage.Modules.HamsterDatabase"))
	local data = DataSystem.get(alice)
	data.Coins = 100000
	alice:SetAttribute("Coins", 100000)
	for i = 1, 4 do CollectionSystem.grant(alice, HamsterDatabase.Spawnable.Basic[i].Id, "Collect") end
	CollectionSystem.grant(alice, HamsterDatabase.Spawnable.Basic[1].Id, "Collect")
	M.Sim.advance(1)
	local n = 0
	for _, v in data.Inventory do n += v end
	print("hamsters in collection:", n, " equipped:", #data.Equipped)
	report()

	section("requests: upgrade / equip / sell / quests / daily / code / settings / shop")
	local Remotes = require(find("ReplicatedStorage.Remotes"))
	local function request(action, payload)
		local r = Remotes.func("Request").OnServerInvoke
		return Remotes.func("Request"):InvokeServer(action, payload)
	end
	local function show(name, r) print(string.format("  %-22s ok=%s msg=%s", name, tostring(r.ok), tostring(r.msg))) end
	data.Coins = 1e9; alice:SetAttribute("Coins", 1e9)
	show("BuyUpgrade luck", request("BuyUpgrade", { Id = "SpawnLuck" }))
	show("BuyUpgrade range", request("BuyUpgrade", { Id = "CollectionRange" }))
	show("BuyUpgrade storage", request("BuyUpgrade", { Id = "ExtraStorage" }))
	show("BuyUpgrade tokens(no)", request("BuyUpgrade", { Id = "RebirthBoost" }))
	show("BuyUpgrade bad id", request("BuyUpgrade", { Id = "Nope" }))
	show("EquipBest", request("EquipBest"))
	show("ClaimQuest collect10", request("ClaimQuest", { Id = "collect10" }))
	show("ClaimDaily", request("ClaimDaily"))
	show("ClaimDaily again", request("ClaimDaily"))
	show("RedeemCode WELCOME", request("RedeemCode", { Code = " welcome " }))
	show("RedeemCode WELCOME again", request("RedeemCode", { Code = "WELCOME" }))
	show("RedeemCode junk", request("RedeemCode", { Code = "zzz" }))
	show("UpdateSetting SFXVolume", request("UpdateSetting", { Key = "SFXVolume", Value = 0.3 }))
	show("UpdateSetting bad", request("UpdateSetting", { Key = "Hack", Value = true }))
	show("UpdateSetting bad type", request("UpdateSetting", { Key = "Music", Value = "yes" }))
	show("ShopBuy capsule", request("ShopBuy", { Id = "capsule_cozy" }))
	show("ShopBuy boost", request("ShopBuy", { Id = "boost_luck" }))
	show("ShopBuy roof", request("ShopBuy", { Id = "roof_rose" }))
	show("ShopBuy pass (soon)", request("ShopBuy", { Id = "pass_coins" }))
	show("SellDuplicates", request("SellDuplicates", {}))
	show("Resync", request("Resync"))
	M.Sim.advance(2)
	report()

	section("rebirth")
	data.Coins = 20000; alice:SetAttribute("Coins", 20000)
	show("Rebirth", request("Rebirth"))
	M.Sim.advance(2)
	print("rebirths:", data.Rebirths, "coins:", math.floor(data.Coins), "gems:", data.Gems, "tokens:", data.Tokens, "unique kept:", (function() local n=0 for _ in data.Index do n+=1 end return n end)())
	report()

	section("second player joins and leaves")
	local bob = M.newPlayer("Bob")
	fireJoin(bob)
	M.spawnCharacter(bob)
	M.Sim.advance(6)
	print("Bob loaded:", bob:GetAttribute("DataLoaded"), "House:", bob:GetAttribute("HouseId"))
	M.removePlayer(bob)
	M.Sim.advance(4)
	print("saved profiles in store:", (function() local n=0 for _ in M.dataStoreData do n+=1 end return n end)())
	report()

	section("12 players (more than 8 houses)")
	local extra = {}
	for i = 1, 12 do
		local p = M.newPlayer("P" .. i)
		fireJoin(p)
		M.spawnCharacter(p)
		table.insert(extra, p)
	end
	M.Sim.advance(10)
	local housed, waiting = 0, 0
	for _, p in extra do if p:GetAttribute("HouseId") then housed += 1 else waiting += 1 end end
	print("housed:", housed, "waiting:", waiting)
	M.removePlayer(extra[1])
	M.Sim.advance(3)
	local housedAfter = 0
	for _, p in extra do if p:GetAttribute("HouseId") then housedAfter += 1 end end
	print("housed after one leaves:", housedAfter)
	report()

	section("done")
	print("TOTAL ERRORS:", #M.Sim.errors)
end)
M.Sim.advance(0)
