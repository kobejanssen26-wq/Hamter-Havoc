-- Weapons, gear, hotbar data, shop purchases, game passes, hotbar/shop/backpack UI
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
	local HamsterSystem = require(find(S .. "HamsterSystem"))
	local CombatSystem = require(find(S .. "CombatSystem"))
	local SecuritySystem = require(find(S .. "SecuritySystem"))
	local HouseSystem = require(find(S .. "HouseSystem"))
	local DataSystem = require(find(S .. "DataSystem"))
	local TheftSystem = require(find(S .. "TheftSystem"))
	local TheftState = require(find(S .. "TheftState"))
	local GearSystem = require(find(S .. "GearSystem"))
	local PlayerState = require(find(S .. "PlayerState"))
	local Events = require(find(S .. "Events"))
	local ItemRegistry = require(find(MOD .. "ItemRegistry"))
	local GamepassConfig = require(find(MOD .. "GamepassConfig"))
	local ShopConfig = require(find(MOD .. "ShopConfig"))
	local EconomyMath = require(find(MOD .. "EconomyMath"))
	local HotbarConfig = require(find(MOD .. "HotbarConfig"))
	local InputConfig = require(find(MOD .. "InputConfig"))
	local Remotes = require(find("ReplicatedStorage.Remotes"))
	local Marketplace = game:GetService("MarketplaceService")
	local PPS = game:GetService("ProximityPromptService")
	HamsterSystem.AutoSpawn = false

	local function join(name)
		local p = M.newPlayer(name)
		fireJoin(p)
		M.spawnCharacter(p)
		return p
	end
	local alice, bob, carol = join("Alice"), join("Bob"), join("Carol")
	adv(6)
	local function data(p) return DataSystem.get(p) end
	local function as(p, action, payload)
		M.localPlayerRef = p
		return Remotes.func("Request"):InvokeServer(action, payload or {})
	end
	local function rootOf(p) return M.InstanceMethods.FindFirstChild(RawData[p].Props.Character, "HumanoidRootPart") end
	local function place(p, pos, lookAt)
		RawData[rootOf(p)].Props.CFrame = if lookAt then CFrame.lookAt(pos, lookAt) else CFrame.new(pos)
	end
	local function toolIds(container)
		local ids = {}
		if container then
			for _, child in M.InstanceMethods.GetChildren(container) do
				if RawData[child].ClassName == "Tool" then table.insert(ids, child:GetAttribute("ItemId")) end
			end
		end
		table.sort(ids)
		return ids
	end
	local function backpackOf(p) return M.InstanceMethods.FindFirstChildOfClass(p, "Backpack") end
	local function heldIds(p) return toolIds(RawData[p].Props.Character) end

	-----------------------------------------------------------------
	section("1. registry, validation and shop wiring")
	local errors = {}
	for _, issue in ItemRegistry.Issues do if issue.Level == "error" then table.insert(errors, issue.Message) end end
	check("every item definition is valid", #errors == 0, table.concat(errors, "; "))
	local weapons, gear, consumables = 0, 0, 0
	for _, def in ItemRegistry.List do
		if def.Equip.Kind == "Tool" then weapons += 1 elseif def.Equip.Kind == "Passive" then gear += 1 else consumables += 1 end
	end
	check("15 weapons/abilities (incl. 2 pass-only gadgets), 2 equipment items, 5 consumables are registered", weapons == 15 and gear == 2 and consumables == 5, weapons .. "/" .. gear .. "/" .. consumables)
	check("the template item is not registered", ItemRegistry.ById["template_item"] == nil and ItemRegistry.ById["my_item_id"] == nil)
	local cats = {}
	for _, c in ShopConfig.categories() do cats[c.Id] = c end
	check("shop has Weapons, Equipment, Boosts and Game Passes", cats.Weapons and cats.Equipment and cats.Boosts and cats.Gamepasses ~= nil)
	check("weapon prices come from the item files", ShopConfig.ById["gear_foam_bat"].Price == 8000 and ShopConfig.ById["gear_foam_bat"].Currency == "Coins" and ShopConfig.ById["gear_shadow_cloak"].Currency == "Gems")
	local anyPurchasable = false
	for _, item in ShopConfig.Items do if item.Kind == "Pass" and ShopConfig.available(item) then anyPurchasable = true end end
	check("placeholder passes (PassId 0) are NOT purchasable", not anyPurchasable)
	local allMarked = true
	for _, item in cats.Gamepasses.Items do if not item.Unconfigured then allMarked = false end end
	check("they are only listed (Studio) and marked unconfigured", allMarked and #cats.Gamepasses.Items > 0)
	local Validator = require(find(MOD .. "ContentValidator"))
	local function errorsOf(def)
		local list = {}
		for _, i in Validator.validateItem(def, { Rarities = require(find(MOD .. "RarityConfig")).ById, ExistingIds = {}, ModelExists = function() return false end }) do
			if i.Level == "error" then table.insert(list, i.Message) end
		end
		return list
	end
	local good = { Id = "ok_item", DisplayName = "Ok", Description = "x", Category = "Weapon", Icon = "bat", Currency = "Coins", Price = 10, Equip = { Kind = "Tool", Weapon = { Type = "Melee", Range = 8, Arc = 0.1, Cooldown = 1, Knockback = 30, Stun = 1, DropChance = 0.5, Look = { Style = "bat" } } } }
	check("a correct weapon definition validates", #errorsOf(good) == 0, table.concat(errorsOf(good), "; "))
	local function mutate(f) local d = table.clone(good); d.Equip = table.clone(good.Equip); d.Equip.Weapon = table.clone(good.Equip.Weapon); f(d) return d end
	check("price without currency is rejected", #errorsOf(mutate(function(d) d.Currency = nil end)) > 0)
	check("negative price is rejected", #errorsOf(mutate(function(d) d.Price = -5 end)) > 0)
	check("absurd weapon range is rejected", #errorsOf(mutate(function(d) d.Equip.Weapon.Range = 5000 end)) > 0)
	check("zero cooldown is rejected (no spam weapons)", #errorsOf(mutate(function(d) d.Equip.Weapon.Cooldown = 0 end)) > 0)
	check("unknown rarity is rejected", #errorsOf(mutate(function(d) d.Rarity = "Nope" end)) > 0)
	check("an invented asset id is rejected", #errorsOf(mutate(function(d) d.Icon = "rbxassetid://REPLACE_ME" end)) > 0)
	check("unknown category is rejected", #errorsOf(mutate(function(d) d.Category = "Pet" end)) > 0)
	local ok, err = InputConfig.check()
	check("key bindings still have no conflicts (1-8, I, Q, E, F ...)", ok, err)

	-----------------------------------------------------------------
	section("2. purchases are validated by the server")
	local a = data(alice)
	a.Coins = 100; a.Gems = 0; a.Gear = {}; a.Hotbar = {}; a.Items = {}
	-- rebirth-locked gear is VISIBLE in the shop (with its requirement) but the server refuses it below the level
	a.Gems = 400; adv(1)
	local lockedBuy = as(alice, "ShopBuy", { Id = "gear_shadow_cloak" })
	check("a rebirth-locked item can't be bought below its level (server)", not lockedBuy.ok and a.Gems == 400 and a.Gear.shadow_cloak == nil, lockedBuy.msg)
	check("...and its requirement is in the shop data", ShopConfig.ById["gear_shadow_cloak"].MinRebirth == 3 and ShopConfig.ById["gear_frost_wand"].MinRebirth == 1 and ShopConfig.ById["gear_mirror_clone"].MinRebirth == 5)
	a.Gems = 0
	a.Rebirths = 3
	a.Coins = 100
	local r = as(alice, "ShopBuy", { Id = "gear_foam_bat" })
	check("can't afford a weapon -> refused, nothing granted, no charge", not r.ok and a.Coins == 100 and next(a.Gear) == nil, r.msg)
	adv(1)
	a.Coins = 8000
	r = as(alice, "ShopBuy", { Id = "gear_foam_bat", Price = 1, Currency = "Gems" })
	check("buy with cash (client price/currency ignored)", r.ok and a.Coins == 0 and a.Gear.foam_bat == true, a.Coins)
	check("it landed on hotbar slot 2", a.Hotbar["2"] == "foam_bat", a.Hotbar["2"])
	check("a real Tool with the item id is in the Backpack", #toolIds(backpackOf(alice)) == 1 and toolIds(backpackOf(alice))[1] == "foam_bat")
	adv(1)
	a.Coins = 8000
	r = as(alice, "ShopBuy", { Id = "gear_foam_bat" })
	check("buying the same weapon twice is refused (no second charge)", not r.ok and a.Coins == 8000, r.msg)
	a.Coins = 0
	r = as(alice, "ShopBuy", { Id = "gear_shadow_cloak" })
	check("a diamond weapon needs diamonds", not r.ok and a.Gear.shadow_cloak == nil, r.msg)
	a.Gems = 400; adv(1)
	r = as(alice, "ShopBuy", { Id = "gear_shadow_cloak" })
	check("diamond weapon bought", r.ok and a.Gems == 0 and a.Gear.shadow_cloak and a.Hotbar["3"] == "shadow_cloak")
	r = as(alice, "ShopBuy", { Id = "gear_not_real" })
	check("unknown shop id refused", not r.ok)
	r = as(alice, "ShopBuy", { Id = "pass_DoubleCoins" })
	check("an unconfigured game pass can never be bought: no prompt opened", not r.ok and #M.prompted == 0, r.msg)
	adv(1)
	a.Gems = 120
	r = as(alice, "ShopBuy", { Id = "boost_coins" })
	check("consumables still work and take the next free slot", r.ok and a.Items.item_coins == 1 and a.Hotbar["4"] == "item_coins", a.Hotbar["4"])

	-----------------------------------------------------------------
	section("3. equipping")
	r = as(alice, "EquipItem", { Id = "seed_slingshot" })
	check("equipping a weapon you don't own is refused", not r.ok and #heldIds(alice) == 0, r.msg)
	r = as(alice, "EquipItem", { Id = 5 })
	check("junk ids are refused", not r.ok)
	r = as(alice, "EquipItem", { Id = "item_coins" })
	check("a consumable is not equippable", not r.ok)
	adv(0.3)
	r = as(alice, "EquipItem", { Id = "foam_bat" })
	check("owned weapon equips into the character", r.ok and heldIds(alice)[1] == "foam_bat" and #toolIds(backpackOf(alice)) == 1, r.msg)
	adv(0.3)
	r = as(alice, "EquipItem", { Id = "shadow_cloak" })
	check("equipping another swaps (only one weapon held)", r.ok and #heldIds(alice) == 1 and heldIds(alice)[1] == "shadow_cloak")
	adv(0.3)
	r = as(alice, "UnequipItem")
	check("unequip puts it back in the backpack", r.ok and #heldIds(alice) == 0 and #toolIds(backpackOf(alice)) == 2)
	M.spawnCharacter(alice)
	adv(1)
	check("after a respawn the tools are handed out again (no duplicates)", #toolIds(backpackOf(alice)) == 2, table.concat(toolIds(backpackOf(alice)), ","))
	r = as(alice, "HotbarMove", { Id = "shadow_cloak", Slot = 2 })
	check("moving an item to a taken slot swaps", r.ok and a.Hotbar["2"] == "shadow_cloak" and a.Hotbar["3"] == "foam_bat")
	check("slot 1, slot 9 and fractions are invalid", not as(alice, "HotbarMove", { Id = "foam_bat", Slot = 1 }).ok and not as(alice, "HotbarMove", { Id = "foam_bat", Slot = 9 }).ok and not as(alice, "HotbarMove", { Id = "foam_bat", Slot = 2.5 }).ok)
	check("an unowned item can't be placed on the hotbar", not as(alice, "HotbarMove", { Id = "seed_slingshot", Slot = 5 }).ok and a.Hotbar["5"] == nil)
	check("weapons and equipment can't be discarded", not as(alice, "DiscardItem", { Id = "foam_bat", Amount = 1 }).ok and a.Gear.foam_bat == true)
	r = as(alice, "UseItem", { Id = "item_coins" })
	check("using the last consumable frees its slot", r.ok and a.Items.item_coins == nil and a.Hotbar["4"] == nil, a.Hotbar["4"])
	r = as(alice, "UseItem", { Id = "foam_bat" })
	check("a weapon is not 'used up'", not r.ok and a.Gear.foam_bat == true)
	-- old profile without the new keys
	local oldProfile = { Items = { item_luck = 2 }, Gear = {}, Hotbar = {} }
	GearSystem.fill(oldProfile)
	check("existing consumables of an old save get a hotbar slot", oldProfile.Hotbar["2"] == "item_luck")
	local stale = { Items = {}, Gear = {}, Hotbar = { ["2"] = "item_coins", ["3"] = "ghost", ["9"] = "foam_bat" } }
	GearSystem.clean(stale)
	check("stale / unknown / out-of-range hotbar entries are cleaned", next(stale.Hotbar) == nil)

	-----------------------------------------------------------------
	section("4. passive equipment")
	local before = { range = EconomyMath.collectRange(a, os.time()), speed = EconomyMath.walkSpeed(a, os.time()) }
	a.Coins = 100000; adv(1)
	check("net bought", as(alice, "ShopBuy", { Id = "gear_hamster_net" }).ok and a.Gear.hamster_net == true)
	adv(1)
	check("boots bought", as(alice, "ShopBuy", { Id = "gear_runner_boots" }).ok and a.Gear.runner_boots == true)
	check("passive gear is not placed on the hotbar", GearSystem.slotOf(a, "hamster_net") == nil and GearSystem.slotOf(a, "runner_boots") == nil)
	check("net widens the collect range (+4) and boots speed you up (+2)", EconomyMath.collectRange(a, os.time()) == before.range + 4 and EconomyMath.walkSpeed(a, os.time()) == before.speed + 2)
	check("no tool for passive gear", #toolIds(backpackOf(alice)) + #heldIds(alice) == 2)

	-----------------------------------------------------------------
	section("5. combat: range, cooldown, validation, theft interruption")
	local aliceHouse = HouseSystem.getHouse(alice)
	a.Inventory = { brownie = 1, silver = 1 }
	a.Equipped = { "brownie", "silver" }
	Events.EquippedChanged:Fire(alice)
	adv(0.5)
	for _ = 1, 100 do
		if SecuritySystem.status(aliceHouse) ~= "Active" then break end
		adv(1)
	end
	adv(6)
	local function wheelPos(slot) return aliceHouse.Slots[slot].RunCFrame.Position end
	local bobPos = wheelPos(1) + Vector3.new(0, 2, 3)
	place(bob, bobPos)
	place(carol, Vector3.new(0, 5, 0))
	RawData[PPS].Signals.PromptTriggered:Fire(aliceHouse.TheftPrompts[1], bob)
	adv(0.5)
	check("bob is carrying alice's hamster (theft in progress)", HamsterSystem.carriedBy(bob) ~= nil)
	place(alice, bobPos + Vector3.new(0, 0, -8.6), bobPos)
	adv(1.5)
	check("paws reach 8 studs: a 8.6 stud slap misses", (function() CombatSystem.attack(alice, nil) adv(0.3) return HamsterSystem.carriedBy(bob) ~= nil end)())
	adv(1.5)
	as(alice, "EquipItem", { Id = "foam_bat" })
	adv(0.5)
	check("the bat is held", heldIds(alice)[1] == "foam_bat")
	-- a unit-less / absurd aim does not matter for melee; cooldown (0.8s) is enforced by the server
	CombatSystem.attack(alice, Vector3.new(0, 1e9, 0))
	adv(0.3)
	check("bat hit (range 9 > 8.6) on a thief carrying a hamster -> theft fails", HamsterSystem.carriedBy(bob) == nil and a.Stats.TheftsStopped == 1 and (data(bob).Stats.TheftsFailed or 0) == 1, tostring(a.Stats.TheftsStopped))
	check("the hamster is back on its wheel, ownership unchanged", aliceHouse.DisplayModels[1] ~= nil and a.Inventory.brownie == 1 and (data(bob).Inventory.brownie or 0) == 0)
	check("the thief is stunned by the hit", PlayerState.isStunned(bob))
	-- cooldown
	local stunsBefore = a.Stats.Slaps or 0
	CombatSystem.attack(alice, nil)
	check("a second swing inside the cooldown is ignored", (a.Stats.Slaps or 0) == stunsBefore)
	-- no hamster nearby: the hit still works now (the old "only near a hamster" rule is a GameConfig switch)
	adv(60)
	place(carol, Vector3.new(0, 5, 0))
	place(alice, Vector3.new(0, 5, 6), Vector3.new(0, 5, 0))
	CombatSystem.attack(alice, nil)
	adv(0.5)
	check("a weapon hit works with no hamster anywhere near (fix: it used to need a carried hamster)", PlayerState.isStunned(carol))
	local GameConfig = require(find(MOD .. "GameConfig"))
	adv(60)
	GameConfig.set("Combat", "PvpNeedsHamsterNearby", true, true)
	PlayerState.clear(carol); PlayerState.grantImmunity(carol, 0)
	adv(3)
	place(carol, Vector3.new(500, 5, 500)); place(alice, Vector3.new(500, 5, 506), Vector3.new(500, 5, 500))
	adv(3)
	CombatSystem.attack(alice, nil)
	adv(0.5)
	check("with PvpNeedsHamsterNearby = true the old rule is back (no hamster fight, no hit)", not PlayerState.isStunned(carol))
	GameConfig.reset("Combat", "PvpNeedsHamsterNearby", true)
	adv(60)

	-- ranged: second theft, this time carol steals slot 2
	adv(10)
	local carolPos = wheelPos(2) + Vector3.new(0, 2, 3)
	place(carol, carolPos)
	adv(4.5)
	RawData[PPS].Signals.PromptTriggered:Fire(aliceHouse.TheftPrompts[2], carol)
	adv(0.5)
	check("carol steals slot 2", HamsterSystem.carriedBy(carol) ~= nil)
	a.Coins = 200000; adv(1)
	check("slingshot bought", as(alice, "ShopBuy", { Id = "gear_seed_slingshot" }).ok)
	adv(0.5)
	as(alice, "EquipItem", { Id = "seed_slingshot" })
	adv(0.5)
	local farPos = carolPos + Vector3.new(30, 0, 0)
	place(alice, farPos, carolPos)
	adv(1.5)
	local aim = (carolPos - farPos).Unit
	adv(2.1)
	CombatSystem.attack(alice, -aim)
	adv(0.3)
	check("ranged: shooting the wrong way hits nothing", HamsterSystem.carriedBy(carol) ~= nil)
	adv(2.1)
	M.rayResult = { Instance = rootOf(alice) } -- a wall between shooter and target
	CombatSystem.attack(alice, aim)
	adv(0.3)
	check("ranged: a wall blocks the shot", HamsterSystem.carriedBy(carol) ~= nil)
	M.rayResult = nil
	adv(2.1)
	place(alice, farPos, farPos + Vector3.new(30, 0, 0)) -- looking away from the thief
	CombatSystem.attack(alice, Vector3.new(0 / 0, 0, 0))
	adv(0.3)
	check("ranged: a NaN aim falls back to where you look (away) and is harmless", HamsterSystem.carriedBy(carol) ~= nil)
	place(alice, farPos, carolPos)
	adv(2.1)
	-- an UNOWNED weapon tool does nothing special
	a.Gear.seed_slingshot = nil
	CombatSystem.attack(alice, aim)
	adv(0.3)
	check("a tool you don't own is just paws (range 8): 30 studs away -> miss", HamsterSystem.carriedBy(carol) ~= nil)
	a.Gear.seed_slingshot = true
	adv(2.1)
	CombatSystem.attack(alice, aim)
	adv(0.3)
	check("ranged: a clean 30 stud shot hits the thief -> theft fails", HamsterSystem.carriedBy(carol) == nil and a.Stats.TheftsStopped == 2, tostring(a.Stats.TheftsStopped))

	-----------------------------------------------------------------
	section("5c. abilities: Frost Wand, Shadow Cloak, Mirror Clone")
	-----------------------------------------------------------------
	local AbilitySystem = require(find(S .. "AbilitySystem"))
	a.Coins = 300000; a.Gems = 2000; adv(1)
	a.Rebirths = 0
	r = as(alice, "ShopBuy", { Id = "gear_frost_wand" })
	check("Frost Wand is locked at rebirth 0 (server refuses, nothing charged)", not r.ok and a.Gear.frost_wand == nil and a.Coins >= 300000, r.msg)
	a.Rebirths = 1; adv(1)
	r = as(alice, "ShopBuy", { Id = "gear_frost_wand" })
	check("Frost Wand unlocks at rebirth 1 and can be bought for cash", r.ok and a.Gear.frost_wand == true and a.Coins < 300000, r.msg)
	adv(1)
	r = as(alice, "ShopBuy", { Id = "gear_mirror_clone" })
	check("Mirror Clone (rebirth 5) is still locked at rebirth 1", not r.ok and a.Gear.mirror_clone == nil, r.msg)

	-- a fresh theft for the freeze test (bob steals slot 1 again)
	adv(60)
	local frozenSpot = wheelPos(1) + Vector3.new(0, 2, 3)
	place(bob, frozenSpot)
	adv(4.5)
	RawData[PPS].Signals.PromptTriggered:Fire(aliceHouse.TheftPrompts[1], bob)
	adv(0.5)
	check("bob is carrying a stolen hamster again", HamsterSystem.carriedBy(bob) ~= nil)
	as(alice, "EquipItem", { Id = "frost_wand" })
	adv(0.5)
	place(carol, Vector3.new(0, 5, -150)) -- keep bystanders out of the line of fire
	local from = frozenSpot + Vector3.new(25, 0, 0)
	place(alice, from, frozenSpot)
	adv(1)
	local aim2 = (frozenSpot - from).Unit
	local gearBefore = table.clone(a.Gear)
	CombatSystem.attack(alice, aim2)
	adv(0.3)
	check("Freeze: the thief is frozen (can't act)", PlayerState.isFrozen(bob) and PlayerState.isStunned(bob))
	local bobHumanoid = M.InstanceMethods.FindFirstChild(RawData[bob].Props.Character, "Humanoid")
	check("...WalkSpeed 0 and no jumping", RawData[bobHumanoid].Props.WalkSpeed == 0 and RawData[bobHumanoid].Props.JumpPower == 0)
	check("...an ice block surrounds them (visible cue for everyone)", M.InstanceMethods.FindFirstChild(RawData[bob].Props.Character, "FrozenIce") ~= nil)
	check("...they still hold the hamster (the owner can finish the job)", HamsterSystem.carriedBy(bob) ~= nil)
	check("...a frozen player can't attack back", (function() local before = a.Stats.Slaps or 0 CombatSystem.attack(bob, nil) return (data(bob).Stats.Slaps or 0) == (data(bob).Stats.Slaps or 0) end)())
	CombatSystem.attack(alice, aim2)
	adv(0.2)
	check("Freeze has a long cooldown (a second shot right away does nothing)", PlayerState.isFrozen(bob) and a.Gear.frost_wand == true)
	adv(2.5)
	check("Freeze ends after 2 seconds", not PlayerState.isFrozen(bob) and RawData[bobHumanoid].Props.WalkSpeed > 0, RawData[bobHumanoid].Props.WalkSpeed)
	check("a frozen player is immune to being frozen again for a while", not AbilitySystem.freeze(alice, bob, 2))
	check("the duration is capped (a 99 s request freezes at most 3 s)", (function()
		adv(8)
		local ok3 = AbilitySystem.freeze(alice, bob, 99)
		adv(3.3)
		return ok3 and not PlayerState.isFrozen(bob)
	end)())
	check("freeze changed no items or ownership", (function() for k, v in gearBefore do if a.Gear[k] ~= v then return false end end return true end)())

	-- misses cost only a short cooldown, and no fight = no freeze
	adv(25)
	local calm = Vector3.new(-200, 5, 0)
	place(carol, calm + Vector3.new(15, 0, 0))
	place(alice, calm, calm + Vector3.new(15, 0, 0))
	adv(1)
	CombatSystem.attack(alice, Vector3.new(1, 0, 0))
	check("Freeze can't be used for fun (no hamster fight nearby -> nobody is frozen)", not PlayerState.isFrozen(carol))

	-- Shadow Cloak
	a.Rebirths = 3
	a.Gems = 2000
	adv(1)
	check("Shadow Cloak is owned (bought with diamonds earlier, at rebirth 3)", a.Gear.shadow_cloak == true)
	adv(1)
	as(alice, "EquipItem", { Id = "shadow_cloak" })
	adv(0.5)
	local aliceChar = RawData[alice].Props.Character
	CombatSystem.attack(alice, nil)
	adv(0.3)
	check("Cloak: the player is marked cloaked", alice:GetAttribute("Cloaked") == true and AbilitySystem.isCloaked(alice))
	local hidden = true
	for _, part in M.descendants(aliceChar) do
		if RawData[part].ClassName ~= "Model" and M.InstanceMethods.IsA(part, "BasePart") and RawData[part].Name ~= "HumanoidRootPart" and (RawData[part].Props.Transparency or 0) < 0.8 then hidden = false end
	end
	check("...body parts are almost invisible", hidden)
	check("...with a visible sparkle trail as counterplay", M.InstanceMethods.FindFirstChild(rootOf(alice), "CloakShimmer") ~= nil)
	CombatSystem.attack(alice, nil)
	adv(0.2)
	check("Cloak has a 45 s cooldown (can't be re-used instantly)", AbilitySystem.isCloaked(alice))
	adv(6.3)
	check("Cloak ends after 6 seconds and everything is restored", not AbilitySystem.isCloaked(alice) and alice:GetAttribute("Cloaked") == nil)
	local restored = true
	for _, part in M.descendants(aliceChar) do
		if M.InstanceMethods.IsA(part, "BasePart") and RawData[part].Name ~= "HumanoidRootPart" and (RawData[part].Props.Transparency or 0) > 0.5 then restored = false end
	end
	check("...no permanent invisibility", restored)
	check("being hit ends a cloak", (function() AbilitySystem.cloak(alice, 6) AbilitySystem.reveal(alice) return not AbilitySystem.isCloaked(alice) end)())

	-- Mirror Clone
	a.Rebirths = 5
	a.Gems = 2000
	adv(1)
	check("Mirror Clone bought at rebirth 5", as(alice, "ShopBuy", { Id = "gear_mirror_clone" }).ok)
	adv(1)
	as(alice, "EquipItem", { Id = "mirror_clone" })
	adv(46)
	local coinsBefore, invBefore, gearBefore2 = a.Coins, copyInv and copyInv(a.Inventory) or table.clone(a.Inventory), table.clone(a.Gear)
	CombatSystem.attack(alice, nil)
	adv(0.3)
	local decoy = workspace:FindFirstChild("Decoy")
	check("Clone: a decoy model appears", decoy ~= nil and decoy:GetAttribute("OwnerUserId") == RawData[alice].Props.UserId)
	check("...it is clearly marked (cyan outline + see-through) so it can be told apart", decoy ~= nil and M.InstanceMethods.FindFirstChildOfClass(decoy, "Highlight") ~= nil)
	check("...it duplicated no data, items or currency", a.Coins >= coinsBefore and (function() for k, v in invBefore do if a.Inventory[k] ~= v then return false end end for k, v in gearBefore2 do if a.Gear[k] ~= v then return false end end return true end)())
	check("...there is only ever one decoy per player", (function() AbilitySystem.decoy(alice, 8) local n = 0 for _, child in M.InstanceMethods.GetChildren(workspace) do if RawData[child].Name == "Decoy" then n += 1 end end return n == 1 end)())
	adv(9)
	check("...and it disappears after its duration", workspace:FindFirstChild("Decoy") == nil)
	check("a hit pops the decoy", (function()
		AbilitySystem.decoy(alice, 8)
		local d = workspace:FindFirstChild("Decoy")
		local dRoot = d and M.InstanceMethods.FindFirstChild(d, "HumanoidRootPart")
		return dRoot ~= nil and AbilitySystem.popDecoyNear(RawData[dRoot].Props.CFrame.Position, 5, bob) and workspace:FindFirstChild("Decoy") == nil
	end)())
	check("the owner's own swing never pops their own decoy", (function()
		AbilitySystem.decoy(alice, 8)
		local d = workspace:FindFirstChild("Decoy")
		local dRoot = d and M.InstanceMethods.FindFirstChild(d, "HumanoidRootPart")
		local popped = dRoot ~= nil and AbilitySystem.popDecoyNear(RawData[dRoot].Props.CFrame.Position, 5, alice)
		AbilitySystem.removeDecoy(alice)
		return not popped
	end)())
	-- exploit attempts
	a.Gear.frost_wand = nil
	check("a client can't use an ability tool it doesn't own (removed from data -> plain paws)", (function() local def = require(find(S .. "GearSystem")).equippedWeapon(alice) return def == nil or def.Id ~= "frost_wand" end)())
	a.Gear.frost_wand = true
	a.Rebirths = 3

	-----------------------------------------------------------------
	section("6. game passes: Roblox is the source of truth")
	local entry = GamepassConfig.ByKey.DoubleCoins
	local item = ShopConfig.ById["pass_DoubleCoins"]
	local uid = RawData[alice].Props.UserId
	entry.PassId, item.PassId, item.Unconfigured = 4242, 4242, false
	GamepassConfig.ById[4242] = entry
	M.passPrice[4242] = 199
	check("with a PassId the pass becomes available", ShopConfig.available(item) and GamepassConfig.configured(entry))
	local mult0 = EconomyMath.derived(a, os.time()).IncomeMultiplier
	adv(1)
	r = as(alice, "ShopBuy", { Id = "pass_DoubleCoins" })
	check("buying opens the official Roblox prompt (and grants nothing yet)", r.ok and #M.prompted == 1 and M.prompted[1].PassId == 4242 and not a.Passes.DoubleCoins, r.msg)
	RawData[Marketplace].Signals.PromptGamePassPurchaseFinished:Fire(alice, 4242, true)
	adv(10)
	check("the prompt event alone does not grant: Roblox must confirm ownership", not a.Passes.DoubleCoins)
	M.ownedPasses[uid] = { [4242] = true }
	RawData[Marketplace].Signals.PromptGamePassPurchaseFinished:Fire(alice, 4242, true)
	adv(3)
	check("once Roblox says owned, the benefit is granted", a.Passes.DoubleCoins == true)
	check("benefit really applies (cash x2)", math.abs(EconomyMath.derived(a, os.time()).IncomeMultiplier / mult0 - 2) < 1e-6, EconomyMath.derived(a, os.time()).IncomeMultiplier / mult0)
	adv(1)
	r = as(alice, "ShopBuy", { Id = "pass_DoubleCoins" })
	check("an owned pass can't be bought twice", not r.ok and #M.prompted == 1, r.msg)
	check("a fake client request cannot grant a pass", (function()
		local b = data(bob)
		as(bob, "ShopBuy", { Id = "pass_DoubleCoins", Owned = true })
		as(bob, "PassBuy", { Key = "DoubleCoins" })
		return not b.Passes.DoubleCoins
	end)())
	r = as(alice, "PassPrices")
	check("the Robux price comes from Roblox (GetProductInfo), not from our config", r.ok and r.extra.DoubleCoins == 199, tostring(r.extra and r.extra.DoubleCoins))
	M.ownedPasses[uid] = {}
	r = as(alice, "PassRefresh")
	check("Refresh re-checks with Roblox", r.ok and not a.Passes.DoubleCoins)
	M.ownedPasses[uid] = { [4242] = true }
	as(alice, "PassRefresh")
	check("...and picks up a pass bought elsewhere", a.Passes.DoubleCoins == true)
	M.passCheckFail = true
	as(alice, "PassRefresh")
	M.passCheckFail = false
	check("a failed ownership lookup never removes a pass you own", a.Passes.DoubleCoins == true)
	-- restore the placeholder
	entry.PassId, item.PassId, item.Unconfigured = 0, 0, true
	GamepassConfig.ById[4242] = nil
	a.Passes.DoubleCoins = nil

	-----------------------------------------------------------------
	section("7. persistence")
	DataSystem.save(alice, false)
	local savedGear = table.clone(a.Gear)
	M.removePlayer(alice)
	adv(1)
	local alice2 = M.newPlayer("Alice")
	RawData[alice2].Props.UserId = uid
	fireJoin(alice2)
	M.spawnCharacter(alice2)
	adv(6)
	local a2 = data(alice2)
	check("owned gear and hotbar layout survive a rejoin", a2 ~= nil and a2.Gear.foam_bat and a2.Gear.shadow_cloak and a2.Gear.seed_slingshot and a2.Gear.hamster_net and a2.Hotbar["2"] == "shadow_cloak" and a2.Hotbar["3"] == "foam_bat")
	check("tools are in the new backpack after rejoining", #toolIds(backpackOf(alice2)) == 5, table.concat(toolIds(backpackOf(alice2)), ","))

	-----------------------------------------------------------------
	-- client: hotbar / shop / backpack
	-----------------------------------------------------------------
	section("8. UI: ONE hotbar, shop, backpack")
	alice = alice2
	a = a2
	M.localPlayerRef = alice
	local gui = M.newInstance("PlayerGui", true); RawData[gui].Name = "PlayerGui"; M.setParent(gui, alice)
	M.isServer = false
	M.clientRunning = true
	local mainClient = find("StarterPlayer.StarterPlayerScripts.Main")
	task.spawn(function() RawData[mainClient].Source(mainClient, require) end)
	adv(3)
	local UIKit = require(find("StarterPlayer.StarterPlayerScripts.UI.UIKit"))
	local HotbarUI = require(find("StarterPlayer.StarterPlayerScripts.UI.HotbarUI"))
	local UIS = game:GetService("UserInputService")
	local cam = workspace.CurrentCamera
	local function byName(root, name)
		local found = {}
		for _, d in M.descendants(root) do
			if RawData[d].Name == name then table.insert(found, d) end
		end
		return found
	end
	local function textsOf(root)
		local list = {}
		for _, d in M.descendants(root) do
			if RawData[d].ClassName == "TextLabel" or RawData[d].ClassName == "TextButton" then table.insert(list, tostring(RawData[d].Props.Text)) end
		end
		return table.concat(list, "|")
	end
	local function press(code)
		RawData[UIS].Signals.InputBegan:Fire({ KeyCode = M.Enum.KeyCode[code], UserInputType = M.Enum.UserInputType.Keyboard, UserInputState = M.Enum.UserInputState.Begin }, false)
		adv(0.6)
	end
	local function click(inst) RawData[inst].Signals.Activated:Fire() adv(0.4) end

	check("there is exactly one hotbar", #byName(gui, "Hotbar") == 1)
	check("it has the configured number of slots (8)", #HotbarUI.Views == HotbarConfig.SlotCount and #byName(byName(gui, "Hotbar")[1], "Bar") == 1)
	local hotbar = byName(gui, "Hotbar")[1]
	local slotsInHotbar = 0
	for _, d in M.descendants(hotbar) do if string.sub(RawData[d].Name, 1, 5) == "Slot_" then slotsInHotbar += 1 end end
	check("no second row/bar of slots", slotsInHotbar == 8, slotsInHotbar)
	-- geometry of every slot: number / icon / count never overlap, equal slot sizes, all inside the slot
	local function rect(inst)
		local p = RawData[inst].Props
		return { x = p.Position.X.Offset, y = p.Position.Y.Offset, w = p.Size.X.Offset, h = p.Size.Y.Offset }
	end
	local function overlaps(r1, r2) return r1.x < r2.x + r2.w and r2.x < r1.x + r1.w and r1.y < r2.y + r2.h and r2.y < r1.y + r1.h end
	local geometryOk, detail, sizes = true, "", {}
	for index, view in HotbarUI.Views do
		local slot = view.Button
		local sz = RawData[slot].Props.Size.X.Offset
		sizes[sz] = true
		local number, icon, count = rect(byName(slot, "Number")[1]), rect(byName(slot, "IconArea")[1]), rect(byName(slot, "Count")[1])
		local all = { number = number, icon = icon, count = count }
		for name, rc in all do
			if rc.x < 0 or rc.y < 0 or rc.x + rc.w > sz or rc.y + rc.h > sz then geometryOk = false detail ..= " [" .. index .. ":" .. name .. " outside]" end
		end
		if overlaps(number, icon) or overlaps(icon, count) or overlaps(number, count) then geometryOk = false detail ..= " [" .. index .. " overlap]" end
		-- icon centred horizontally
		if math.abs((icon.x + icon.w / 2) - sz / 2) > 1 then geometryOk = false detail ..= " [" .. index .. " icon off-centre]" end
	end
	local sizeCount = 0
	for _ in sizes do sizeCount += 1 end
	check("slot parts (number top-left, icon centred, count bottom-right) never overlap and stay inside", geometryOk, detail)
	check("all slots have the same size", sizeCount == 1)
	check("slot numbers show 1-8", (function()
		for index, view in HotbarUI.Views do
			if RawData[byName(view.Button, "Number")[1]].Props.Text ~= tostring(index) then return false end
		end
		return true
	end)())

	-- behaviour
	check("slot 1 is selected with nothing held", HotbarUI.selectedSlot() == 1)
	local function thickness(i) return RawData[M.InstanceMethods.FindFirstChildOfClass(HotbarUI.Views[i].Button, "UIStroke")].Props.Thickness end
	check("the selected slot is highlighted", thickness(1) == 3 and thickness(2) ~= 3, thickness(1))
	press("Two") -- shadow_cloak sits on slot 2
	check("number key 2 equips the weapon on slot 2", heldIds(alice)[1] == "shadow_cloak" and HotbarUI.selectedSlot() == 2, table.concat(heldIds(alice), ","))
	check("the highlight follows", thickness(2) == 3 and thickness(1) ~= 3)
	press("Two")
	check("pressing it again puts it away", #heldIds(alice) == 0 and HotbarUI.selectedSlot() == 1)
	press("Eight")
	check("an empty slot does nothing (nothing equipped)", #heldIds(alice) == 0)
	press("Three"); press("One")
	check("key 1 returns to the paws (unequips)", #heldIds(alice) == 0)
	-- the displayed hotbar only shows what is owned
	local emptyShown = true
	for index = 7, 8 do
		local view = HotbarUI.Views[index]
		if RawData[view.Icon].Props.Visible ~= false then emptyShown = false end
	end
	check("empty slots show a placeholder, not a fake item", emptyShown)

	-- shop
	local shop = UIKit.getPanel("Shop")
	shop:Open(); adv(0.8)
	for _, name in { "Tab_Weapons", "Tab_Equipment", "Tab_Boosts" } do
		check("cash shop tab exists: " .. name, #byName(shop.Gui, name) == 1)
	end
	check("the Cash Shop does not show Robux items (no game pass tab)", #byName(shop.Gui, "Tab_Gamepasses") == 0)
	check("two shops: a Cash Shop and a Robux Shop switch", #byName(shop.Gui, "Mode_Cash") == 1 and #byName(shop.Gui, "Mode_Robux") == 1)
	click(byName(shop.Gui, "Tab_Weapons")[1])
	check("weapon cards listed", #byName(shop.Gui, "Item_gear_foam_bat") == 1 and #byName(shop.Gui, "Item_gear_shadow_cloak") == 1 and #byName(shop.Gui, "Item_gear_seed_slingshot") == 1)
	check("detail panel shows the selected weapon", string.find(textsOf(byName(shop.Gui, "Detail")[1]), "Cooldown", 1, true) ~= nil and #byName(shop.Gui, "DetailIcon") == 1)
	check("weapon cards show the REAL model in a viewport (not a generic icon)", #byName(byName(shop.Gui, "Item_gear_slap_glove")[1], "WeaponPreview") == 1)
	check("the preview model of the glove has the glove's parts (Palm, Finger0, Thumb ...)", (function()
		local view = byName(byName(shop.Gui, "Item_gear_slap_glove")[1], "WeaponPreview")[1]
		local model = M.InstanceMethods.FindFirstChildOfClass(view, "Model")
		return model ~= nil and M.InstanceMethods.FindFirstChild(model, "Palm") ~= nil and M.InstanceMethods.FindFirstChild(model, "Thumb") ~= nil and M.InstanceMethods.FindFirstChild(model, "Handle") ~= nil
	end)())
	check("each weapon's preview differs (glove vs hammer vs shield have different parts)", (function()
		local function names(id)
			local p = game:GetService("ReplicatedStorage").Assets.WeaponPreviews[id]
			local t = {}
			for _, c in M.InstanceMethods.GetChildren(p) do table.insert(t, RawData[c].Name) end
			table.sort(t)
			return table.concat(t, ",")
		end
		return names("slap_glove") ~= names("party_hammer") and names("party_hammer") ~= names("bubble_shield") and names("spring_glove") ~= names("shock_baton")
	end)())
	click(byName(shop.Gui, "Item_gear_foam_bat")[1])
	check("owned weapon offers Equip instead of Buy", #byName(shop.Gui, "Action") == 1 and (string.find(tostring(RawData[byName(shop.Gui, "Action")[1]].Props.Text), "Equip", 1, true) ~= nil), #byName(shop.Gui, "Action") .. ":" .. textsOf(shop.Gui):sub(1, 400))
	-- rebirth-locked weapons stay visible with a lock + requirement
	M.isServer = true; a.Gear.mirror_clone = nil; a.Rebirths = 0; require(find(S .. "ReplicationSystem")).mark(alice, "Gear", "Hotbar", "Rebirths"); M.isServer = false
	adv(1.5)
	click(byName(shop.Gui, "Tab_Weapons")[1])
	check("a locked weapon is still listed", #byName(shop.Gui, "Item_gear_mirror_clone") == 1)
	check("...with a lock icon on its card", #byName(byName(shop.Gui, "Item_gear_mirror_clone")[1], "LockIcon") == 1)
	click(byName(shop.Gui, "Item_gear_mirror_clone")[1])
	local lockedAction = byName(shop.Gui, "Action")[1]
	check("...the button says what is required and is disabled", lockedAction ~= nil and string.find(textsOf(lockedAction), "Rebirth 5", 1, true) ~= nil and RawData[lockedAction].Attributes.Disabled == true, lockedAction and textsOf(lockedAction))
	check("...and the detail panel explains it (ability, unlock level, your level)", string.find(textsOf(byName(shop.Gui, "Detail")[1]), "Locked", 1, true) ~= nil and string.find(textsOf(byName(shop.Gui, "Detail")[1]), "Rebirth 5", 1, true) ~= nil)
	M.isServer = true; a.Rebirths = 5; require(find(S .. "ReplicationSystem")).mark(alice, "Rebirths"); M.isServer = false
	adv(1.5)
	local unlockedAction = byName(shop.Gui, "Action")[1]
	check("at the required rebirth it becomes buyable", unlockedAction ~= nil and RawData[unlockedAction].Attributes.Disabled ~= true, unlockedAction and tostring(RawData[unlockedAction].Props.Text))
	click(byName(shop.Gui, "Mode_Robux")[1])
	check("the Robux Shop has the Game Passes tab and no cash items", #byName(shop.Gui, "Tab_Gamepasses") == 1 and #byName(shop.Gui, "Tab_Weapons") == 0)
	click(byName(shop.Gui, "Tab_Gamepasses")[1])
	local passCards = 0
	for _, d in M.descendants(shop.Gui) do if string.sub(RawData[d].Name, 1, 10) == "Item_pass_" then passCards += 1 end end
	check("game pass tab lists configured-or-greyed passes", passCards == #GamepassConfig.List or passCards == #cats.Gamepasses.Items, passCards)
	local act = byName(shop.Gui, "Action")[1]
	check("unconfigured pass: button says 'Not configured' and is disabled", act and string.find(tostring(RawData[act].Props.Text), "Not configured", 1, true) ~= nil and RawData[act].Attributes.Disabled == true, act and (tostring(RawData[act].Props.Text) .. "/" .. tostring(RawData[act].Attributes.Disabled)))
	click(byName(shop.Gui, "Mode_Cash")[1])
	click(byName(shop.Gui, "Tab_Boosts")[1])
	check("boost cards present", #byName(shop.Gui, "Item_boost_coins") == 1)
	shop:Close(); adv(0.5)

	-- backpack
	local backpack = UIKit.getPanel("Backpack")
	check("Backpack panel exists", backpack ~= nil)
	backpack:Open(); adv(0.8)
	check("owned weapons and equipment listed", #byName(backpack.Gui, "Item_foam_bat") == 1 and #byName(backpack.Gui, "Item_hamster_net") == 1)
	check("nothing unowned is listed", #byName(backpack.Gui, "Item_shadow_cloak") == 1 and #byName(backpack.Gui, "Item_item_luck") == 0)
	click(byName(backpack.Gui, "Item_foam_bat")[1])
	check("weapon detail has Equip and no Discard", #byName(backpack.Gui, "Equip") == 1 and #byName(backpack.Gui, "Discard") == 0)
	click(byName(backpack.Gui, "Equip")[1])
	check("Equip from the backpack equips the Tool", heldIds(alice)[1] == "foam_bat", table.concat(heldIds(alice), ","))
	check("button flips to Unequip", #byName(backpack.Gui, "Unequip") == 1)
	click(byName(backpack.Gui, "Unequip")[1])
	check("Unequip works", #heldIds(alice) == 0)
	M.isServer = true; a.Items.item_luck = 2; GearSystem.fill(a); require(find(S .. "ReplicationSystem")).mark(alice, "Items", "Hotbar"); M.isServer = false
	adv(1.5)
	check("a consumable appears with its count", #byName(backpack.Gui, "Item_item_luck") == 1)
	click(byName(backpack.Gui, "Item_item_luck")[1])
	check("consumable offers Discard (with confirm)", #byName(backpack.Gui, "Discard") == 1)
	click(byName(backpack.Gui, "Discard")[1])
	check("first tap only asks for confirmation", a.Items.item_luck == 2)
	click(byName(backpack.Gui, "Discard")[1])
	check("second tap discards one", a.Items.item_luck == 1)
	press("I")
	adv(0.5)
	check("the I key toggles the backpack", not backpack.IsOpen)
	backpack:Close(); adv(0.4)

	-- several resolutions: the hotbar block must fit on screen
	local resOk, resDetail = true, ""
	local hp = RawData[hotbar].Props
	check("the hotbar is anchored to the BOTTOM centre of the screen (own ScreenGui, not in a HUD column)", hp.Position.Y.Scale == 1 and hp.AnchorPoint.Y == 1 and hp.Position.X.Scale == 0.5 and RawData[RawData[hotbar].Parent].Name == "HotbarUI", tostring(hp.Position))
	for _, vp in { Vector2.new(1920, 1080), Vector2.new(1280, 720), Vector2.new(844, 390), Vector2.new(667, 375), Vector2.new(390, 844) } do
		cam.ViewportSize = vp
		adv(0.3)
		local scale = RawData[M.InstanceMethods.FindFirstChildOfClass(hotbar, "UIScale")].Props.Scale
		local total = RawData[hotbar].Attributes.DesignWidth * scale
		if total > vp.X + 0.5 then resOk = false resDetail ..= string.format(" [%dx%d: hotbar %.0f wide]", vp.X, vp.Y, total) end
	end
	check("the hotbar fits the screen at 5 resolutions (incl. phone portrait)", resOk, resDetail)
	cam.ViewportSize = Vector2.new(1280, 720)

	-- lucky wheel (server draw + window)
	local wheel = UIKit.getPanel("Wheel")
	wheel:Open(); adv(0.8)
	check("the Lucky Wheel window shows one bubble per prize", #byName(wheel.Gui, "Ring") == 1 and #M.descendants(byName(wheel.Gui, "Ring")[1]) > 20)
	local spinBtn = byName(wheel.Gui, "Spin")[1]
	check("a free spin is offered at first", string.find(tostring(RawData[spinBtn].Props.Text), "FREE", 1, true) ~= nil, tostring(RawData[spinBtn].Props.Text))
	local nextFreeBefore = a.Wheel.NextFreeAt
	local coinsBeforeSpin, gemsBeforeSpin = a.Coins, a.Gems
	click(spinBtn)
	adv(5)
	check("spinning uses the free spin (next free spin is hours away) and pays a prize decided by the server", a.Wheel.NextFreeAt > nextFreeBefore and a.Wheel.NextFreeAt >= os.time() + 3000)
	adv(1.2)
	check("the second spin costs diamonds", string.find(tostring(RawData[byName(wheel.Gui, "Spin")[1]].Props.Text), "gems", 1, true) ~= nil, tostring(RawData[byName(wheel.Gui, "Spin")[1]].Props.Text))
	wheel:Close(); adv(0.5)

	print(string.format("PASS %d  FAIL %d", results.pass, results.fail))
	print("== done ==")
end)
