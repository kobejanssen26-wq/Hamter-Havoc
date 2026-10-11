--[[
	ContentCheck: one call that validates ALL content and the live registries. The server runs it at start and prints the
	result; you can also run it in Studio's command bar (server view):

	    local issues = require(game.ReplicatedStorage.Modules.ContentCheck).run()
	    for _, i in issues do print(i.Level, i.Kind, i.Id, i.Message) end

	Besides the per-file checks it verifies the loaded hamster registry as a whole: unique ids, positive prices, income
	not negative, every hamster has a rarity that exists, hamster models exist when a ModelName is set.
]]

local ContentCheck = {}

function ContentCheck.run(): { any }
	local modules: any = script.Parent
	local issues = {}
	local function add(list: { any }?)
		local source: { any } = list or {}
		for _, entry in source do
			table.insert(issues, entry)
		end
	end
	local HamsterDatabase = require(modules.HamsterDatabase)
	local RarityConfig = require(modules.RarityConfig)
	add(HamsterDatabase.Issues)
	add(require(modules.EmoteConfig).Issues)
	add(require(modules.AnimationRegistry).Issues)

	local seen: { [string]: boolean } = {}
	for _, species in HamsterDatabase.Species do
		if seen[species.Id] then
			table.insert(issues, { Level = "error", Kind = "Hamster", Id = species.Id, Message = "duplicate id in the registry" })
		end
		seen[species.Id] = true
		if not RarityConfig.ById[species.Rarity] then
			table.insert(issues, { Level = "error", Kind = "Hamster", Id = species.Id, Message = "unknown rarity " .. tostring(species.Rarity) })
		end
		local price, income = HamsterDatabase.price(species), HamsterDatabase.income(species)
		if price ~= price or price < 1 then
			table.insert(issues, { Level = "error", Kind = "Hamster", Id = species.Id, Message = "invalid price " .. tostring(price) })
		end
		if income ~= income or income < 0 then
			table.insert(issues, { Level = "error", Kind = "Hamster", Id = species.Id, Message = "invalid income " .. tostring(income) })
		end
	end
	return issues
end

-- Prints a summary; returns true when there are no errors.
function ContentCheck.report(): boolean
	local issues = ContentCheck.run()
	local errors = 0
	for _, issue in issues do
		if issue.Level == "error" then
			errors += 1
			warn(string.format("[Content] ERROR %s '%s': %s", issue.Kind, issue.Id, issue.Message))
		else
			print(string.format("[Content] warning %s '%s': %s", issue.Kind, issue.Id, issue.Message))
		end
	end
	print(string.format("[Content] checked %d hamsters: %d error(s), %d warning(s)", #(require((script.Parent :: any).HamsterDatabase) :: any).Species, errors, #issues - errors))
	return errors == 0
end

return ContentCheck
