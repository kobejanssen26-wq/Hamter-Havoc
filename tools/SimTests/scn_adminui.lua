-- Admin panel UI: player list/search, role editor, hamster + item pickers, all talking to the real server code
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
	local DataSystem = require(find(S .. "DataSystem"))
	local AdminSystem = require(find(S .. "AdminSystem"))

	local function join(name, userId)
		local p = M.newPlayer(name)
		if userId then RawData[p].Props.UserId = userId end
		fireJoin(p)
		M.spawnCharacter(p)
		return p
	end
	local owner = join("Boss", 8247768664)
	local friend = join("Friendly", 4242)
	local other = join("Zed", 4343)
	adv(8)

	M.localPlayerRef = owner
	local gui = M.newInstance("PlayerGui", true); RawData[gui].Name = "PlayerGui"; M.setParent(gui, owner)
	M.isServer = false
	M.clientRunning = true
	local mainClient = find("StarterPlayer.StarterPlayerScripts.Main")
	task.spawn(function() RawData[mainClient].Source(mainClient, require) end)
	adv(3)
	local UIKit = require(find("StarterPlayer.StarterPlayerScripts.UI.UIKit"))
	local AdminUI = require(find("StarterPlayer.StarterPlayerScripts.UI.AdminUI"))
	local HamsterDatabase = require(find("ReplicatedStorage.Modules.HamsterDatabase"))
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
	local function click(inst) RawData[inst].Signals.Activated:Fire() adv(0.5) end
	local function type_(box, text) RawData[box].Props.Text = text RawData[box].Signals.FocusLost:Fire(true) adv(0.5) end

	section("1. opening the panel, player list")
	AdminUI.open()
	adv(0.5)
	local panel = UIKit.getPanel("Admin")
	check("the owner's panel opens", panel and panel.IsOpen)
	local all = textsOf(panel.Gui)
	check("the player list shows every player in the server by display name", string.find(all, "Boss", 1, true) and string.find(all, "Friendly", 1, true) and string.find(all, "Zed", 1, true))
	check("the sections are there: Dashboard, Roles, Hamsters, Weapons & gear, Logs", string.find(all, "Dashboard", 1, true) and string.find(all, "Roles", 1, true) and string.find(all, "Hamsters", 1, true) and string.find(all, "Weapons & gear", 1, true) and string.find(all, "Logs", 1, true))
	local search = byName(panel.Gui, "PlayerSearch")[1]
	RawData[search].Props.Text = "zed"
	RawData[search].Signals.PropertyChanged = RawData[search].Signals.PropertyChanged
	adv(0.3)
	click(byName(panel.Gui, "Player_Zed")[1])
	check("clicking a player selects them (shown in the details card with the UserId)", string.find(textsOf(byName(panel.Gui, "SelectedPlayer")[1]), "4343", 1, true) ~= nil)

	section("2. role editor")
	click(RawData[panel.Gui] and (function() for _, b in byName(panel.Gui, "Tab_Roles") do return b end end)())
	local rolesText = textsOf(panel.Gui)
	check("the Roles section lists the built-in roles", string.find(rolesText, "Admin", 1, true) and string.find(rolesText, "Moderator", 1, true) and string.find(rolesText, "Owner", 1, true) and string.find(rolesText, "PROTECTED", 1, true))
	local newRole
	for _, d in M.descendants(panel.Gui) do
		if RawData[d].ClassName == "TextButton" and RawData[d].Props.Text == "+ New role" then newRole = d end
	end
	click(newRole)
	check("a permission checklist appears with a toggle per permission", #byName(panel.Gui, "Perm_Kick") == 1 and #byName(panel.Gui, "Perm_Cash") == 1 and #byName(panel.Gui, "Perm_ManageAdmins") == 1)
	local boxes = {}
	for _, d in M.descendants(panel.Gui) do
		if RawData[d].ClassName == "TextBox" then table.insert(boxes, d) end
	end
	local nameBox
	for _, d in boxes do if RawData[d].Props.PlaceholderText == "Role name (2-24 letters / digits)" then nameBox = d end end
	RawData[nameBox].Props.Text = "Trial Mod"
	-- toggle Kick + Warn on
	local function toggleOn(permission)
		local row = byName(panel.Gui, "Perm_" .. permission)[1]
		for _, d in M.descendants(row) do
			if RawData[d].ClassName == "TextButton" then click(d) return true end
		end
	end
	toggleOn("Warn")
	toggleOn("Kick")
	local save
	for _, d in M.descendants(panel.Gui) do
		if RawData[d].ClassName == "TextButton" and RawData[d].Props.Text == "Save role" then save = d end
	end
	click(save)
	click(save) -- confirm
	adv(1)
	local saved = M.dataStoreData.Staff and M.dataStoreData.Staff.Roles and M.dataStoreData.Staff.Roles["Trial Mod"]
	check("saving creates the role on the server with exactly the ticked permissions", saved and table.find(saved.Permissions, "Kick") and table.find(saved.Permissions, "Warn") and not table.find(saved.Permissions, "Cash"), saved and table.concat(saved.Permissions, ","))

	section("3. assigning through the panel")
	local give
	for _, d in M.descendants(panel.Gui) do
		if RawData[d].ClassName == "TextButton" and RawData[d].Props.Text == "Give to selected player" then give = d end
	end
	check("an existing role has a 'Give to selected player' button", give ~= nil)
	click(give)
	adv(1)
	check("the selected player (Zed) now holds that role, decided by the server", AdminSystem.roleOf(other) == "Trial Mod", AdminSystem.roleOf(other))
	check("the role has the Kick permission but not Cash", AdminSystem.can(other, "Kick") and not AdminSystem.can(other, "Cash"))

	section("4. hamster picker")
	click(byName(panel.Gui, "Tab_Hamsters")[1])
	local cells = 0
	for _, d in M.descendants(byName(panel.Gui, "HamsterGrid")[1]) do
		if string.sub(RawData[d].Name, 1, 8) == "Hamster_" then cells += 1 end
	end
	check("the hamster grid shows 12 per page from the game's own catalog", cells == 12, cells)
	local divine
	for _, species in HamsterDatabase.Species do if species.Rarity == "Divine" then divine = species break end end
	local sBox = byName(panel.Gui, "HamsterSearch")[1]
	type_(sBox, string.sub(divine.Name, 1, 5))
	local cell = byName(panel.Gui, "Hamster_" .. divine.Id)[1]
	check("searching finds a hamster by its name", cell ~= nil)
	click(cell)
	click(byName(panel.Gui, "Player_Zed")[1])
	local before = (DataSystem.get(other).Inventory[divine.Id] or 0)
	click(byName(panel.Gui, "GrantHamster")[1])
	adv(0.5)
	check("Grant adds the hamster to the selected player's real inventory", (DataSystem.get(other).Inventory[divine.Id] or 0) == before + 1, DataSystem.get(other).Inventory[divine.Id])

	section("5. item picker + logs")
	click(byName(panel.Gui, "Tab_Items")[1])
	check("the item picker lists the game's weapons", #byName(panel.Gui, "Item_slap_glove") == 1)
	click(byName(panel.Gui, "Item_slap_glove")[1])
	click(byName(panel.Gui, "GrantItem")[1])
	adv(0.5)
	check("granting an item through the picker works", DataSystem.get(other).Gear.slap_glove == true)

	section("5b. bases tab")
	M.localPlayerRef = owner
	click(byName(panel.Gui, "Tab_Bases")[1])
	click(byName(panel.Gui, "Player_Zed")[1])
	adv(0.5)
	check("the Bases tab shows the selected player's gate line and lists", #byName(panel.Gui, "GateLine") == 1 and #byName(panel.Gui, "BenchList") == 1 and #byName(panel.Gui, "OwnedList") == 1)
	check("it has the three laser buttons", #byName(panel.Gui, "Lasers_on") == 1 and #byName(panel.Gui, "Lasers_off") == 1 and #byName(panel.Gui, "Lasers_reset") == 1)
	local zedHouse = require(find("ServerScriptService.Systems.HouseSystem")).getHouse(other)
	type_(byName(panel.Gui, "BaseReason")[1], "ui test")
	click(byName(panel.Gui, "Lasers_on")[1])
	click(byName(panel.Gui, "Lasers_on")[1]) -- confirm
	adv(0.5)
	check("pressing Lasers ON (with a reason, after confirming) switches the real gate", zedHouse and require(find("ServerScriptService.Systems.SecuritySystem")).status(zedHouse) == "Active")

	section("6. a role with fewer rights sees fewer sections")
	M.localPlayerRef = other
	local opened = AdminSystem.handle(other, "open")
	adv(1)
	local names = {}
	for _, c in opened.data.Commands do names[c.Category] = true end
	check("Zed (Trial Mod) only gets moderation commands, no economy / hamsters / roles", names.Moderation and not names.Economy and not names.Hamsters and opened.data.Roles == nil)

	print(string.format("\nPASS %d  FAIL %d", results.pass, results.fail))
end)
