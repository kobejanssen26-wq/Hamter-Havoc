-- Hamster auras: rarity defaults, per-hamster overrides, validation, caps, building and cleanup
local adv = M.Sim.advance
local results = { pass = 0, fail = 0 }
local function section(t) print("\n== " .. t .. " ==") end
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end

task.spawn(function()
	adv(0.1)
	local MOD = "ReplicatedStorage.Modules."
	local AuraConfig = require(find(MOD .. "AuraConfig"))
	local RarityConfig = require(find(MOD .. "RarityConfig"))
	local HamsterDatabase = require(find(MOD .. "HamsterDatabase"))
	local HamsterBuilder = require(find(MOD .. "HamsterBuilder"))
	local ContentValidator = require(find(MOD .. "ContentValidator"))

	local function resolve(rarity, aura)
		local r = RarityConfig.ById[rarity]
		return AuraConfig.resolve({ Rarity = rarity, Aura = aura }, r.Color, r.Accent)
	end
	local function descendantsOf(model, class, name)
		local list = {}
		for _, d in model:GetDescendants() do
			if d:IsA(class) and (name == nil or d.Name == name) then table.insert(list, d) end
		end
		return list
	end
	local function firstOf(rarity)
		for _, s in HamsterDatabase.Spawnable[rarity] or {} do if s.Aura == nil then return s end end
		return HamsterDatabase.ByRarity[rarity][1]
	end

	section("1. rarity defaults")
	check("common rarities have no aura (Basic, Cute, Shiny)", resolve("Basic") == nil and resolve("Cute") == nil and resolve("Shiny") == nil)
	local rare, epic, legendary, secret = resolve("Rare"), resolve("Epic"), resolve("Legendary"), resolve("Secret")
	check("Rare is a subtle glow only (no particles, no ring)", rare and rare.Light > 0 and rare.Style == nil and rare.Ring == nil)
	check("Epic adds sparkles", epic and epic.Style == "sparkle" and epic.Rate > 0 and epic.Ring == nil)
	check("Legendary adds stars and a ground ring", legendary and legendary.Style == "stars" and legendary.Ring ~= nil)
	check("Secret has its own unique effect (glitch) and differs from Legendary", secret and secret.Style == "glitch" and secret.Style ~= legendary.Style)
	check("the aura colour follows the rarity colour", legendary.Color == RarityConfig.ById.Legendary.Color)

	section("2. per-hamster overrides + validation")
	check("Aura = false removes the aura of a Legendary", resolve("Legendary", false) == nil)
	local custom = resolve("Basic", { Style = "flame", Color = "FF8800", Rate = 6, Light = 1.2, Ring = "FFD866" })
	check("a Basic hamster can be given a custom aura", custom and custom.Style == "flame" and custom.Rate == 6 and custom.Ring ~= nil and math.abs(custom.Color.R - 1) < 0.01)
	local partial = resolve("Epic", { Rate = 2 })
	check("a partial override keeps the rest of the rarity default", partial.Style == "sparkle" and partial.Rate == 2)
	check("Ring = false removes just the ring", resolve("Legendary", { Ring = false }).Ring == nil)
	check("a rate above the cap is capped", resolve("Epic", { Rate = 999 }) == nil or resolve("Epic", { Rate = 999 }).Rate <= AuraConfig.MaxRate)
	check("a garbage style / colour does not crash and falls back safely", (function() local r = resolve("Epic", { Style = "lasers", Color = "zzz" }) return r == nil or (r.Style == nil and r.Color == RarityConfig.ById.Epic.Color) end)())
	check("the validator names the problem for a bad style", AuraConfig.problem({ Style = "lasers" }) ~= nil and AuraConfig.problem({ Rate = 99 }) ~= nil and AuraConfig.problem({ Color = "red" }) ~= nil and AuraConfig.problem("yes") ~= nil)
	check("the validator accepts false, nil and a good table", AuraConfig.problem(false) == nil and AuraConfig.problem(nil) == nil and AuraConfig.problem({ Style = "stars", Color = "FFD866", Rate = 5, Light = 1, Ring = "Accent" }) == nil)
	local issues = {}
	local okDef = { Id = "aura_test", DisplayName = "Aura Test", Rarity = "Epic", Look = { Aura = { Style = "lasers" } } }
	local found = ContentValidator.validateHamster(okDef, { Rarities = RarityConfig.ById }, {})
	local hasAuraError = false
	for _, issue in found or {} do if issue.Level == "error" and string.find(issue.Message, "Aura", 1, true) then hasAuraError = true end end
	check("a hamster file with a bad Look.Aura is reported as an error", hasAuraError)
	AuraConfig.Intensity = 0
	check("Intensity 0 switches every aura off", resolve("Legendary") == nil)
	AuraConfig.Intensity = 1
	AuraConfig.Enabled = false
	check("Enabled = false switches every aura off", resolve("Legendary") == nil)
	AuraConfig.Enabled = true
	AuraConfig.Intensity = 0.5
	check("Intensity scales rate and light", math.abs(resolve("Legendary").Rate - 3) < 0.01)
	AuraConfig.Intensity = 1

	section("3. built models")
	local epicHamster, legHamster, commonHamster = firstOf("Epic"), firstOf("Legendary"), firstOf("Basic")
	local m = HamsterBuilder.build(epicHamster, {})
	check("an Epic hamster has one Aura particle emitter and a glow, no ring", #descendantsOf(m, "ParticleEmitter", "Aura") == 1 and #descendantsOf(m, "PointLight", "BuilderGlow") >= 1 and #descendantsOf(m, "BasePart", "AuraRing") == 0)
	local ml = HamsterBuilder.build(legHamster, {})
	check("a Legendary hamster also has the ground ring (a flat neon disc that does not collide)", #descendantsOf(ml, "BasePart", "AuraRing") == 1 and descendantsOf(ml, "BasePart", "AuraRing")[1].CanCollide == false)
	local mc = HamsterBuilder.build(commonHamster, {})
	check("a Basic hamster has no aura parts", #descendantsOf(mc, "ParticleEmitter", "Aura") == 0 and #descendantsOf(mc, "BasePart", "AuraRing") == 0)
	local icon = HamsterBuilder.build(legHamster, { LowDetail = true, Particles = false, Aura = false })
	check("icons / previews (Aura = false) never get an aura", #descendantsOf(icon, "ParticleEmitter", "Aura") == 0 and #descendantsOf(icon, "BasePart", "AuraRing") == 0)
	local bench = HamsterBuilder.build(epicHamster, { LowDetail = true, Particles = false })
	local benchEmitter = descendantsOf(bench, "ParticleEmitter", "Aura")[1]
	check("bench hamsters (built on the server without particles) carry the aura emitter switched OFF until the client is close", benchEmitter ~= nil and benchEmitter.Enabled == false)
	local plain = HamsterBuilder.build(commonHamster, {})
	local extraInstances = #ml:GetDescendants() - #HamsterBuilder.build(legHamster, { Aura = false }):GetDescendants()
	check("an aura adds at most 4 instances (emitter, light, ring + its weld)", extraInstances >= 1 and extraInstances <= 4, extraInstances)
	m:Destroy(); ml:Destroy(); mc:Destroy(); icon:Destroy(); bench:Destroy(); plain:Destroy()

	section("4. the whole catalog")
	local counts, failures = {}, 0
	for _, species in HamsterDatabase.Species do
		local ok, result = pcall(function()
			local model = HamsterBuilder.build(species, { Particles = false })
			local n = #descendantsOf(model, "ParticleEmitter", "Aura") + #descendantsOf(model, "BasePart", "AuraRing")
			model:Destroy()
			return n
		end)
		if not ok then failures += 1 end
		counts[species.Rarity] = (counts[species.Rarity] or 0) + (if ok then result else 0)
	end
	check("all " .. #HamsterDatabase.Species .. " hamsters build with their aura without errors", failures == 0)
	check("no aura on the lowest rarities in the real catalog", (counts.Basic or 0) == 0 and (counts.Cute or 0) == 0 and (counts.Shiny or 0) == 0)

	print(string.format("\nPASS %d  FAIL %d", results.pass, results.fail))
end)
