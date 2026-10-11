-- Content registry (hamsters / emotes / animations), validator, emote wheel + server rules, input bindings
local Players = game:GetService("Players")
local adv = M.Sim.advance
local results = { pass = 0, fail = 0 }
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end
local function issuesFor(list, id)
	local found = {}
	for _, i in list do if i.Id == id then table.insert(found, i) end end
	return found
end
task.spawn(function()
	M.isServer = true
	local mainServer = find("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	adv(1)
	local p = M.newPlayer("Emo")
	adv(0.01)
	RawData[Players].Signals.PlayerAdded:Fire(p)
	M.spawnCharacter(p)
	adv(6)
	M.localPlayerRef = p
	local gui = M.newInstance("PlayerGui", true); RawData[gui].Name = "PlayerGui"; M.setParent(gui, p)
	M.isServer = false
	M.clientRunning = true
	local mainClient = find("StarterPlayer.StarterPlayerScripts.Main")
	task.spawn(function() RawData[mainClient].Source(mainClient, require) end)
	adv(3)

	local Modules = "ReplicatedStorage.Modules."
	local V = require(find(Modules .. "ContentValidator"))
	local HD = require(find(Modules .. "HamsterDatabase"))
	local RC = require(find(Modules .. "RarityConfig"))
	local EmoteConfig = require(find(Modules .. "EmoteConfig"))
	local AnimationRegistry = require(find(Modules .. "AnimationRegistry"))
	local InputConfig = require(find(Modules .. "InputConfig"))
	local Check = require(find(Modules .. "ContentCheck"))

	-- ---- validator (pure) ----
	local ctx = { Rarities = RC.ById, ExistingIds = { taken = true }, ModelExists = function(n) return n == "Real" end }
	local function errors(list) local n = 0 for _, i in list do if i.Level == "error" then n += 1 end end return n end
	check("valid hamster definition passes", errors(V.validateHamster({ Id = "ok_one", DisplayName = "Ok", Rarity = "Rare", Price = 100 }, ctx)) == 0)
	check("duplicate hamster id is an error", errors(V.validateHamster({ Id = "taken", DisplayName = "X", Rarity = "Rare" }, ctx)) == 1)
	check("unknown rarity is an error", errors(V.validateHamster({ Id = "a1", DisplayName = "X", Rarity = "Mega" }, ctx)) == 1)
	check("invalid price is an error", errors(V.validateHamster({ Id = "a2", DisplayName = "X", Rarity = "Rare", Price = -5 }, ctx)) == 1 and errors(V.validateHamster({ Id = "a3", DisplayName = "X", Rarity = "Rare", Price = 0/0 }, ctx)) == 1)
	check("bad id format is an error", errors(V.validateHamster({ Id = "Bad Id!", DisplayName = "X", Rarity = "Rare" }, ctx)) >= 1)
	check("placeholder icon id is an error", errors(V.validateHamster({ Id = "a4", DisplayName = "X", Rarity = "Rare", Icon = "rbxassetid://REPLACE_WITH_VALID_ASSET_ID" }, ctx)) == 1 and errors(V.validateHamster({ Id = "a5", DisplayName = "X", Rarity = "Rare", Icon = "rbxassetid://0" }, ctx)) == 1)
	check("missing model is only a warning", #V.validateHamster({ Id = "a6", DisplayName = "X", Rarity = "Rare", ModelName = "Nope" }, ctx) == 1 and errors(V.validateHamster({ Id = "a6", DisplayName = "X", Rarity = "Rare", ModelName = "Nope" }, ctx)) == 0 and #V.validateHamster({ Id = "a7", DisplayName = "X", Rarity = "Rare", ModelName = "Real" }, ctx) == 0)
	check("animation without AssetId is a warning, fake id an error", errors(V.validateAnimation({ Name = "A_One", AssetId = "", Rig = "R15", Use = "Emote" })) == 0 and #V.validateAnimation({ Name = "A_One", AssetId = "", Rig = "R15", Use = "Emote" }) == 1 and errors(V.validateAnimation({ Name = "A_Two", AssetId = "rbxassetid://PLACEHOLDER", Rig = "R15", Use = "Emote" })) == 1)
	check("emote needs exactly one animation source", errors(V.validateEmote({ Id = "e1", DisplayName = "E", Icon = "star" }, { Builtin = EmoteConfig.BuiltinEmotes })) == 1 and errors(V.validateEmote({ Id = "e2", DisplayName = "E", Icon = "star", Builtin = "wave", AnimationId = "rbxassetid://5" }, { Builtin = EmoteConfig.BuiltinEmotes })) == 1 and errors(V.validateEmote({ Id = "e3", DisplayName = "E", Icon = "star", Builtin = "wave" }, { Builtin = EmoteConfig.BuiltinEmotes })) == 0)

	-- ---- custom content files (the sim wrapper wrote them into Content/) ----
	local nib = HD.ById.test_nibbler
	check("custom hamster is registered", nib ~= nil and nib.Name == "Testy Nibbler" and nib.Custom == true)
	if nib then
		check("custom hamster: price + income overrides", HD.price(nib) == 12345 and HD.income(nib) == 77, HD.price(nib) .. "/" .. HD.income(nib))
		local inSpawn = false
		for _, s in HD.Spawnable.Rare do if s == nib then inSpawn = true end end
		check("custom hamster rolls in the world and is in the Index lists", inSpawn and table.find(HD.ByRarity.Rare, nib) ~= nil)
		check("custom hamster keeps a stable id", HD.get("test_nibbler") == nib)
		local HB = require(find(Modules .. "HamsterBuilder"))
		local model = HB.build(nib, { Scale = 1 })
		check("custom hamster without a usable model falls back to the procedural builder", model ~= nil and model.PrimaryPart ~= nil)
	end
	check("duplicate id file is skipped (original untouched)", HD.ById.brownie.Name ~= "Dup Brownie" and #issuesFor(HD.Issues, "brownie") >= 1)
	check("bad rarity file is skipped", HD.ById.test_badrarity == nil and #issuesFor(HD.Issues, "test_badrarity") >= 1)
	check("fake icon id file is skipped", HD.ById.test_fakeicon == nil)
	check("missing model hamster still loads (warning only)", HD.ById.test_nomodel ~= nil and #issuesFor(HD.Issues, "test_nomodel") == 1 and issuesFor(HD.Issues, "test_nomodel")[1].Level == "warn")
	check("built-in 172 hamsters untouched", (function() local n = 0 for _, s in HD.Species do if not s.Custom then n += 1 end end return n end)() == 172)
	local all = Check.run()
	local errs = 0 for _, i in all do if i.Level == "error" then errs += 1 end end
	check("ContentCheck reports the deliberately broken test files", errs >= 4, errs)

	-- the custom hamster works through the real systems
	local DataSystem = require(find("ServerScriptService.Systems.DataSystem"))
	local CollectionSystem = require(find("ServerScriptService.Systems.CollectionSystem"))
	local EconomyMath = require(find(Modules .. "EconomyMath"))
	local data = DataSystem.get(p)
	M.isServer = true
	CollectionSystem.grant(p, "test_nibbler", "Reward")
	data.Equipped = {}
	local before = EconomyMath.incomePerSecond(data, os.time())
	CollectionSystem.equip(p, "test_nibbler")
	local after = EconomyMath.incomePerSecond(data, os.time())
	M.isServer = false
	check("custom hamster: inventory, index and income use the registry", data.Inventory.test_nibbler == 1 and data.Index.test_nibbler == true and after - before > 70, after - before)

	-- animations registry
	check("animation without asset id is registered but not playable", AnimationRegistry.ByName.Test_Anim ~= nil and AnimationRegistry.playable("Test_Anim") == nil and AnimationRegistry.ByName.Test_BadAnim == nil)
	local AnimationController = require(find("StarterPlayer.StarterPlayerScripts.Controllers.AnimationController"))
	local humanoid = M.InstanceMethods.FindFirstChild(RawData[p].Props.Character, "Humanoid")
	check("playing an unavailable animation fails gracefully", AnimationController.play(humanoid, "Test_Anim") == nil and AnimationController.play(humanoid, "does_not_exist") == nil and AnimationController.playAsset(humanoid, "rbxassetid://REPLACE") == nil)

	-- ---- input bindings ----
	check("no key conflicts between game actions", InputConfig.check())
	check("emote key defaults to B", InputConfig.emoteKey(nil) == "B" and InputConfig.emoteKey("G") == "G")
	check("emote key cannot be an in-use or unknown key", InputConfig.emoteKey("E") == "B" and InputConfig.emoteKey("Q") == "B" and InputConfig.emoteKey("Escape") == "B" and InputConfig.emoteKey(5) == "B")
	check("a conflicting rebinding is detected", not InputConfig.check({ A = "E", B = "E" }))

	-- ---- emote server rules ----
	local Req = require(find("ReplicatedStorage.Remotes")).func("Request")
	local function req(action, payload) return Req:InvokeServer(action, payload or {}) end
	local r1 = req("Emote", { Id = "wave" })
	check("server accepts an unlocked emote", r1.ok and r1.extra.Builtin == "wave", r1.msg)
	check("emote cooldown enforced", not req("Emote", { Id = "wave" }).ok)
	adv(1.6)
	check("unknown emote refused", not req("Emote", { Id = "moonwalk" }).ok and not req("Emote", { Id = 5 }).ok)
	local r2 = req("Emote", { Id = "dance2" })
	check("locked emote refused (needs a rebirth)", not r2.ok and string.find(r2.msg, "Rebirth", 1, true) ~= nil, r2.msg)
	data.Rebirths = 1
	adv(1.6)
	check("emote unlocks with the rebirth", req("Emote", { Id = "dance2" }).ok)
	adv(1.6)

	-- ---- emote wheel UI (client) ----
	local UIS = game:GetService("UserInputService")
	local played = {}
	M.setMethods(humanoid, { PlayEmote = function(_, name) table.insert(played, name) return true end, GetPlayingAnimationTracks = function() return {} end })
	local function key(code)
		RawData[UIS].Signals.InputBegan:Fire({ KeyCode = M.Enum.KeyCode[code], UserInputType = M.Enum.UserInputType.Keyboard, UserInputState = M.Enum.UserInputState.Begin }, false)
		adv(0.4)
	end
	local function byName(root, name)
		local found = {}
		for _, d in M.descendants(root) do if RawData[d].Name == name then table.insert(found, d) end end
		return found
	end
	local wheel = byName(gui, "EmoteWheel")[1]
	check("emote wheel exists and starts closed", wheel ~= nil and RawData[wheel].Props.Enabled == false)
	key("B")
	check("B opens the wheel", RawData[wheel].Props.Enabled == true)
	check("wheel shows one slot per emote", #byName(wheel, "Emote_wave") == 1 and #byName(wheel, "Emote_dance2") == 1)
	key("B")
	adv(0.3)
	check("B again closes it", RawData[wheel].Props.Enabled == false)
	key("B")
	key("Escape")
	adv(0.3)
	check("Esc closes it", RawData[wheel].Props.Enabled == false)
	key("B")
	RawData[byName(wheel, "Dim")[1]].Signals.Activated:Fire()
	adv(0.3)
	check("clicking outside closes it", RawData[wheel].Props.Enabled == false)
	key("B")
	RawData[byName(wheel, "Emote_wave")[1]].Signals.Activated:Fire()
	adv(0.6)
	check("choosing an emote plays it and closes the wheel", played[#played] == "wave" and RawData[wheel].Props.Enabled == false, tostring(played[#played]))
	check("the Emotes button exists in the HUD rail (mobile access)", #byName(gui, "EmotesButton") == 1)
	data.Rebirths = 0
	local EmoteController = require(find("StarterPlayer.StarterPlayerScripts.Controllers.EmoteController"))
	adv(1.6)
	local ok, msg = EmoteController.play("dance2")
	check("locked emote cannot be played from the client either", not ok, msg)
	EmoteController.stop()
	check("stop() clears the running emote", not EmoteController.isPlaying())

	print(string.format("PASS %d FAIL %d errors %d", results.pass, results.fail, #M.Sim.errors))
	for i, e in M.Sim.errors do if i <= 5 then print("  err:", e) end end
end)
M.Sim.advance(0)
