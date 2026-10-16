-- The Studio workflow: what you save in the place is what Play uses. Edits survive, lost tags / emitters are restored,
-- a deleted folder is rebuilt from the code, and StudioOwned = false hands a folder back to the code.
local adv = M.Sim.advance
local results = { pass = 0, fail = 0 }
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end

task.spawn(function()
	M.isServer = true
	local CollectionService = game:GetService("CollectionService")
	local mainServer = find("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	adv(3)
	local WorldBuilder = require(find("ServerScriptService.Systems.WorldBuilder"))
	local Methods = M.InstanceMethods
	local function count(root, className)
		local n = 0
		for _, d in M.descendants(root) do if RawData[d].ClassName == className then n += 1 end end
		return n
	end

	for _, name in { "Environment", "HamsterPlaza", "LeaderboardHall", "HamsterPath", "SpawnLocations" } do
		local folder = workspace:FindFirstChild(name)
		check(name .. " is Studio-owned after the first start (StudioOwned = true)", folder ~= nil and folder:GetAttribute("StudioOwned") == true)
	end
	check("PlayerHouses are generated (not Studio-owned: they belong to the players)", workspace:FindFirstChild("PlayerHouses") ~= nil and workspace.PlayerHouses:GetAttribute("StudioOwned") ~= true)

	-- 1. a "Studio edit": a new part, a changed attribute, a recoloured shop wall; plus the damage a saved copy can have (lost tags / emitters)
	local plaza = workspace.HamsterPlaza
	local hall = workspace.LeaderboardHall
	local env = workspace.Environment
	local path = workspace.HamsterPath
	local mine = M.newInstance("Part", true)
	RawData[mine].Name = "MyOwnBench"
	M.setParent(mine, plaza)
	local sign = Methods.FindFirstChild(plaza.CoinsShop, "Sign")
	RawData[sign].Props.Color = Color3.fromRGB(10, 200, 10)
	plaza.CoinsShop:SetAttribute("MyNote", "hello")
	local wheel = CollectionService:GetTagged("LuckyWheel")[1]
	local kiosk = nil
	for _, d in M.descendants(hall) do if RawData[d].Name == "KioskBase" then kiosk = d end end
	local fireflies = nil
	for _, d in M.descendants(env) do if RawData[d].Name == "Fireflies" then fireflies = d break end end
	local glow = nil
	for _, d in M.descendants(path) do if RawData[d].Name == "BurrowGlow" then glow = d end end
	local safe = nil
	for _, d in M.descendants(hall) do if RawData[d].Name == "SafeZone" then safe = d end end
	check("the world has a wheel, a kiosk target, a burrow glow and a safe zone to test with", wheel and kiosk and glow and safe)
	local tree = nil
	for _, d in M.descendants(plaza) do if string.sub(RawData[d].Name, 1, 5) == "Tree_" then tree = d break end end
	wheel:RemoveTag("LuckyWheel"); kiosk:RemoveTag("TutorialTarget"); safe:RemoveTag("SafeZone"); tree:RemoveTag("TreeSway")
	for _, child in glow:GetChildren() do if RawData[child].ClassName == "ParticleEmitter" then child:Destroy() end end
	local emittersBefore = count(path, "ParticleEmitter")
	local housesBefore = workspace.PlayerHouses
	local plazaPartsBefore = #M.descendants(plaza)

	-- 2. the next Play (server start with this place)
	local world = WorldBuilder.build()
	check("a second start keeps the very same folders (your Studio edits are not rebuilt away)", workspace.HamsterPlaza == plaza and workspace.LeaderboardHall == hall and workspace.Environment == env and workspace.HamsterPath == path)
	check("...with your new part, your attribute and your recoloured sign", plaza:FindFirstChild("MyOwnBench") == mine and plaza.CoinsShop:GetAttribute("MyNote") == "hello" and RawData[sign].Props.Color.G > 0.7)
	check("...and nothing was duplicated (the plaza still has the same number of objects, plus the statue rebuilt)", math.abs(#M.descendants(plaza) - plazaPartsBefore) <= 2, #M.descendants(plaza) .. " vs " .. plazaPartsBefore)
	check("lost tags are restored: LuckyWheel, TutorialTarget, SafeZone, TreeSway", wheel:HasTag("LuckyWheel") and kiosk:HasTag("TutorialTarget") and safe:HasTag("SafeZone") and tree:HasTag("TreeSway"))
	check("the burrow sparkle emitter is restored", count(path, "ParticleEmitter") == emittersBefore + 0 or count(path, "ParticleEmitter") >= 1)
	local sparkle = false
	for _, child in glow:GetChildren() do if RawData[child].ClassName == "ParticleEmitter" then sparkle = true end end
	check("...on the burrow glow itself", sparkle)
	check("the players' houses are regenerated (8 of them) and the world table is complete", workspace.PlayerHouses ~= housesBefore and #world.Houses == 8 and #world.Boards == 3 and #world.Boards[1].Rows == 10)
	local statues = 0
	for _, d in plaza:GetChildren() do if RawData[d].Name == "PlazaStatue" then statues += 1 end end
	check("exactly one golden statue on the arch (rebuilt, with its joints)", statues == 1)
	check("the leaderboard boards are found again by name (labels can be restyled in Studio)", world.Boards[2].Metric == "Steals" and RawData[world.Boards[2].Title].Name == "Title")

	-- 3. deleting a folder hands it back to the code
	plaza:Destroy()
	WorldBuilder.build()
	local plaza2 = workspace.HamsterPlaza
	check("deleting HamsterPlaza rebuilds it from the code (both shops and the wheel are back, your part is gone)", plaza2 ~= nil and plaza2 ~= plaza and plaza2:FindFirstChild("CoinsShop") ~= nil and plaza2:FindFirstChild("RobuxShop") ~= nil and plaza2:FindFirstChild("LuckyWheel") ~= nil and plaza2:FindFirstChild("MyOwnBench") == nil)
	check("...and it is Studio-owned again", plaza2:GetAttribute("StudioOwned") == true)

	-- 4. StudioOwned = false hands the folder back
	local hall2 = workspace.LeaderboardHall
	local marker = M.newInstance("Part", true)
	RawData[marker].Name = "HallMarker"
	M.setParent(marker, hall2)
	hall2:SetAttribute("StudioOwned", false)
	WorldBuilder.build()
	check("StudioOwned = false makes the code rebuild that folder", workspace.LeaderboardHall ~= hall2 and workspace.LeaderboardHall:FindFirstChild("HallMarker") == nil and workspace.LeaderboardHall:GetAttribute("StudioOwned") == true)

	-- 5. a hall that lost its labels is rebuilt (with a warning) instead of breaking the leaderboards
	local hall3 = workspace.LeaderboardHall
	for _, d in M.descendants(hall3) do if RawData[d].Name == "Footer" then d:Destroy() break end end
	local world3 = WorldBuilder.build()
	check("a hall with missing board labels is rebuilt and the boards still work", workspace.LeaderboardHall ~= hall3 and #world3.Boards == 3)

	print(string.format("\nPASS %d  FAIL %d", results.pass, results.fail))
end)
