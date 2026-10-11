M.isServer = true
local HamsterDatabase = require(find("ReplicatedStorage.Modules.HamsterDatabase"))
local HamsterBuilder = require(find("ReplicatedStorage.Modules.HamsterBuilder"))
local count, failures, maxParts, totalParts = 0, 0, 0, 0
local sigs, dup = {}, 0
for _, species in HamsterDatabase.Species do
	local ok, model = pcall(HamsterBuilder.build, species, { Scale = 0.5, LowDetail = true, Particles = false })
	if not ok then
		failures += 1
		print("BUILD FAIL", species.Id, model)
	else
		local parts = 0
		for _, d in M.descendants(model) do if RawData[d].ClassName == "Part" then parts += 1 end end
		maxParts = math.max(maxParts, parts)
		totalParts += parts
		count += 1
	end
	local sig = HamsterBuilder.signature(species)
	if sigs[sig] then dup += 1 print("DUPLICATE LOOK", species.Id, sigs[sig]) end
	sigs[sig] = species.Id
	local problems = HamsterBuilder.validate(species)
	for _, p in problems do print("PROBLEM", p) end
end
print("species built:", count, "failures:", failures, "avg parts:", math.floor(totalParts / math.max(count, 1)), "max parts:", maxParts, "duplicate looks:", dup)
local wanted = { "Brownie", "Snowball", "Sleepy", "Chubby", "Cheesy", "Tiny", "Cookie", "Bread", "Caramel", "Nibbles", "Wizard", "Pirate", "Samurai", "Astronaut", "DJ", "Ninja", "Gamer", "Dragon", "Golden King", "Phoenix", "Galaxy", "Royal", "Ancient", "Dragon Lord" }
local names = {}
for _, species in HamsterDatabase.Species do names[species.Name] = species.Rarity end
for _, w in wanted do
	local found = nil
	for name, rarity in names do
		if string.find(name, w, 1, true) then found = name .. " (" .. rarity .. ")" break end
	end
	print(string.format("  %-14s %s", w, found or "MISSING"))
end
print("errors:", #M.Sim.errors)
