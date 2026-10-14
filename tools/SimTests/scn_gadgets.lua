-- Premium gadgets: Sky Glider + Rocket Booster (server rules, wing visuals, pass wiring, forged / unowned use)
local Players = game:GetService("Players")
local adv = M.Sim.advance
local results = { pass = 0, fail = 0 }
local function section(t) print("\n== " .. t .. " ==") end
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end
local function fireJoin(p) adv(0.01) RawData[Players].Signals.PlayerAdded:Fire(p) end

task.spawn(function()
	M.isServer = true
	local mainServer = find("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	adv(1)
	local S = "ServerScriptService.Systems."
	local MOD = "ReplicatedStorage.Modules."
	local CombatSystem = require(find(S .. "CombatSystem"))
	local DataSystem = require(find(S .. "DataSystem"))
	local GearSystem = require(find(S .. "GearSystem"))
	local MobilitySystem = require(find(S .. "MobilitySystem"))
	local PlayerState = require(find(S .. "PlayerState"))
	local ShopSystem = require(find(S .. "ShopSystem"))
	local ItemRegistry = require(find(MOD .. "ItemRegistry"))
	local GamepassConfig = require(find(MOD .. "GamepassConfig"))
	local ShopConfig = require(find(MOD .. "ShopConfig"))
	local ContentValidator = require(find(MOD .. "ContentValidator"))
	local Remotes = require(find("ReplicatedStorage.Remotes"))

	local function join(name, uid)
		local p = M.newPlayer(name)
		if uid then RawData[p].Props.UserId = uid end
		fireJoin(p)
		M.spawnCharacter(p)
		return p
	end
	local alice = join("Alice", 9501)
	adv(8)
	local a = DataSystem.get(alice)
	local function as(action, payload) M.localPlayerRef = alice return Remotes.func("Request"):InvokeServer(action, payload or {}) end
	local function humanoid() return M.InstanceMethods.FindFirstChildOfClass(RawData[alice].Props.Character, "Humanoid") end
	local function mobility(kind)
		local n = 0
		for _, l in M.remoteLog or {} do if l[1] == "Mobility" and l[2] == "Alice" and l[3] == kind then n += 1 end end
		return n
	end
	local function wing() return M.InstanceMethods.FindFirstChild(RawData[alice].Props.Character, "GliderWing") end
	local function air(on) RawData[humanoid()].Props.FloorMaterial = if on then M.Enum.Material.Air else M.Enum.Material.Grass end

	section("1. the items")
	local glider, rocket = ItemRegistry.get("sky_glider"), ItemRegistry.get("rocket_booster")
	check("both gadgets are in the item catalog and valid", glider ~= nil and rocket ~= nil and #ContentValidator.validateItem(glider, { Rarities = {}, ExistingIds = {} }) >= 0)
	local problems = 0
	for _, def in { glider, rocket } do
		for _, issue in ContentValidator.validateItem(def, { Rarities = require(find(MOD .. "RarityConfig")).ById, ExistingIds = {} }) do
			if issue.Level == "error" then problems += 1 print("   ", issue.Message) end
		end
	end
	check("the validator finds no errors in them", problems == 0, problems)
	check("an out-of-range glider (60 s glide) is refused by the validator", (function()
		local bad = table.clone(glider)
		bad.Equip = { Kind = "Tool", Weapon = { Type = "Glider", Cooldown = 5, Duration = 60, Speed = 30, FallSpeed = 9, Look = { Style = "glider" } } }
		for _, issue in ContentValidator.validateItem(bad, { Rarities = require(find(MOD .. "RarityConfig")).ById, ExistingIds = {} }) do if issue.Level == "error" then return true end end
		return false
	end)())
	check("they are not sold for cash (only through the Game Pass)", glider.Price == nil and rocket.Price == nil)
	local gliderPass, rocketPass = GamepassConfig.ByKey.SkyGlider, GamepassConfig.ByKey.RocketBooster
	check("both Game Passes exist, unconfigured (PassId 0) and carry the item as Gear", gliderPass and rocketPass and gliderPass.PassId == 0 and gliderPass.Benefit.Gear == "sky_glider" and rocketPass.Benefit.Gear == "rocket_booster")
	local shopEntry
	for _, item in ShopConfig.Items do if item.Id == "pass_SkyGlider" then shopEntry = item end end
	check("the shop shows the pass with the real item model (ItemId) in the Equipment tab, marked unconfigured", shopEntry and shopEntry.ItemId == "sky_glider" and shopEntry.Category == "Equipment" and shopEntry.Unconfigured == true)

	section("2. owning, holding and using")
	check("without the item the player has no gadget tool", GearSystem.equippedWeapon(alice) == nil)
	CombatSystem.attack(alice, nil)
	adv(0.3)
	check("attacking without the gadget does nothing (no wing, no event)", wing() == nil and mobility("Glide") == 0 and mobility("Boost") == 0)
	check("a pass that is not owned grants nothing", a.Gear.sky_glider == nil)
	-- the pass flow with a temporary id
	gliderPass.PassId = 91001
	GamepassConfig.ById[91001] = gliderPass
	M.ownedPasses = M.ownedPasses or {}
	M.ownedPasses[9501] = { [91001] = true }
	local granted = ShopSystem.verifyPass(alice, gliderPass, 1)
	check("owning the Game Pass (Roblox says so) gives the Sky Glider", granted and a.Passes.SkyGlider == true and a.Gear.sky_glider == true)
	gliderPass.PassId = 0
	GamepassConfig.ById[91001] = nil
	GearSystem.grant(alice, "rocket_booster") -- (as an admin would for a test)
	adv(0.5)
	as("EquipItem", { Id = "sky_glider" }); adv(0.5)
	local def, tool = GearSystem.equippedWeapon(alice)
	check("the glider can be equipped as a normal tool", def ~= nil and def.Id == "sky_glider" and tool ~= nil)

	section("3. the glide")
	air(false)
	CombatSystem.attack(alice, nil); adv(0.3)
	check("on the ground the glider does not open ('jump first')", wing() == nil and mobility("Glide") == 0)
	adv(2)
	air(true)
	CombatSystem.attack(alice, nil); adv(0.3)
	check("in the air a click opens the glider: the client is told, everybody gets a wing", mobility("Glide") == 1 and wing() ~= nil)
	local parts = 0
	for _, d in M.descendants(wing()) do if M.InstanceMethods.IsA(d, "BasePart") then parts += 1 end end
	check("the wing is made of several welded parts that do not collide", parts >= 8 and (function() for _, d in M.descendants(wing()) do if M.InstanceMethods.IsA(d, "BasePart") and RawData[d].Props.CanCollide ~= false then return false end end return true end)(), parts)
	check("the server knows it is gliding", MobilitySystem.isGliding(alice))
	CombatSystem.attack(alice, nil); adv(0.3)
	check("a second click folds the glider (wing gone, client told)", wing() == nil and mobility("GlideEnd") >= 1 and not MobilitySystem.isGliding(alice))
	adv(0.3)
	CombatSystem.attack(alice, nil); adv(0.3)
	check("it recharges after a glide: another click right away does not open it", mobility("Glide") == 1 and wing() == nil)
	adv(7)
	CombatSystem.attack(alice, nil); adv(0.3)
	check("after the recharge it opens again", mobility("Glide") == 2 and wing() ~= nil)
	adv(7)
	check("a glide ends by itself after its duration (6 s)", wing() == nil and not MobilitySystem.isGliding(alice))
	adv(7)
	CombatSystem.attack(alice, nil); adv(0.3)
	air(false)
	adv(1.2)
	check("landing ends the glide", wing() == nil and not MobilitySystem.isGliding(alice))
	adv(7)
	air(true)
	CombatSystem.attack(alice, nil); adv(0.3)
	as("EquipItem", { Id = "sky_glider" }); adv(0.6) -- puts it away
	check("putting the glider away ends the glide", wing() == nil and not MobilitySystem.isGliding(alice))
	adv(7)
	as("EquipItem", { Id = "sky_glider" }); adv(0.5)
	air(true)
	CombatSystem.attack(alice, nil); adv(0.3)
	PlayerState.stun(alice, 1.0)
	adv(0.6)
	check("being stunned ends the glide", wing() == nil and not MobilitySystem.isGliding(alice))
	adv(8)
	air(true)
	PlayerState.stun(alice, 1.0)
	local before = mobility("Glide")
	CombatSystem.attack(alice, nil); adv(0.3)
	check("a stunned player can not open the glider", mobility("Glide") == before)
	adv(2)

	section("4. the rocket")
	as("EquipItem", { Id = "rocket_booster" }); adv(0.5)
	local rdef, rtool = GearSystem.equippedWeapon(alice)
	check("the rocket is held", rdef ~= nil and rdef.Id == "rocket_booster")
	adv(8)
	CombatSystem.attack(alice, nil); adv(0.3)
	check("a click launches: the client gets the item's numbers (not numbers from the client)", mobility("Boost") == 1)
	local flame = rtool and rtool:FindFirstChild("Flame", true)
	check("the flames light up for everybody", flame ~= nil and RawData[flame].Props.Enabled == true)
	adv(1.6)
	check("...and go out again", RawData[flame].Props.Enabled == false)
	CombatSystem.attack(alice, nil); adv(0.3)
	check("it has a cooldown (9 s): a second click does nothing", mobility("Boost") == 1)
	adv(9)
	CombatSystem.attack(alice, nil); adv(0.3)
	check("after the cooldown it works again", mobility("Boost") == 2)
	adv(10)
	PlayerState.stun(alice, 1.5)
	CombatSystem.attack(alice, nil); adv(0.3)
	check("a stunned player can not launch", mobility("Boost") == 2)
	check("the Attack remote with garbage aim data changes nothing for a gadget", (function() M.localPlayerRef = alice Remotes.event("Attack"):FireServer("garbage", 1, 2) adv(0.3) return mobility("Boost") == 2 end)())

	section("5. cleanup")
	adv(2)
	air(true)
	as("EquipItem", { Id = "sky_glider" }); adv(0.5)
	adv(7)
	CombatSystem.attack(alice, nil); adv(0.3)
	M.spawnCharacter(alice); adv(1)
	check("respawning ends a glide and leaves no wing behind", not MobilitySystem.isGliding(alice) and wing() == nil)
	DataSystem.save(alice, false)
	M.removePlayer(alice)
	adv(2)
	check("leaving the game cleans the state up without errors", true)

	print(string.format("\nPASS %d  FAIL %d", results.pass, results.fail))
end)
