-- UI smoke test + first-person cursor sequence + label anchors
local Players = game:GetService("Players")
local adv = M.Sim.advance
local results = { pass = 0, fail = 0 }
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end
task.spawn(function()
	M.isServer = true
	local mainServer = find("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	adv(1)
	local p = M.newPlayer("Ui")
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

	local UIKit = require(find("StarterPlayer.StarterPlayerScripts.UI.UIKit"))
	local Icons = require(find("StarterPlayer.StarterPlayerScripts.UI.Icons"))
	local UIS = game:GetService("UserInputService")
	local cam = workspace.CurrentCamera
	local Default, LockCenter = M.Enum.MouseBehavior.Default, M.Enum.MouseBehavior.LockCenter
	RawData[UIS].Props.MouseBehavior = Default

	-- stand-in for Roblox's camera script (runs before our step): first person locks the mouse every frame
	local firstPerson = false
	M.renderSteps["FakeCameraScript"] = { Priority = 200, Fn = function()
		if firstPerson then RawData[UIS].Props.MouseBehavior = LockCenter else RawData[UIS].Props.MouseBehavior = Default end
	end }
	local function setFirstPerson(on)
		firstPerson = on
		local pos = Vector3.new(0, 5, 0)
		RawData[cam].Props.CFrame = CFrame.new(pos + (if on then Vector3.new(0, 0, 0.1) else Vector3.new(0, 6, 14)))
		RawData[cam].Props.Focus = CFrame.new(pos)
		adv(0.4)
	end
	local function mouse() return RawData[UIS].Props.MouseBehavior end

	-- icons
	local allOk, count = true, 0
	for _, name in Icons.names() do
		local frame = Icons.create(nil, name, { Size = UDim2.fromOffset(32, 32) })
		count += 1
		if not frame then allOk = false end
	end
	check("every icon draws", allOk and count >= 40, count .. " icons")
	check("config icon ids resolve to drawn icons", Icons.has("coin") and Icons.has("slot") and Icons.has("floor") and Icons.has("upgrade") and Icons.has("hamster"))
	local ShopConfig = require(find("ReplicatedStorage.Modules.ShopConfig"))
	local missingIcon = 0
	for _, item in ShopConfig.Items do if not Icons.has(item.Icon) then missingIcon += 1 end end
	check("every shop item has a drawn icon", missingIcon == 0, missingIcon .. " missing")

	-- every panel opens and closes
	for _, name in { "Backpack", "Index", "Rebirth", "Upgrades", "Daily", "Quests", "Shop", "RobuxShop", "Settings", "Codes", "Wheel", "Playtime", "Social" } do
		local panel = UIKit.getPanel(name)
		check("panel exists: " .. name, panel ~= nil)
		if panel then
			panel:Open(); adv(0.4)
			check("panel opens: " .. name, panel.IsOpen and panel.Gui.Enabled)
			panel:Close(); adv(0.4)
			check("panel closes: " .. name, not panel.IsOpen and not panel.Gui.Enabled)
		end
	end

	-- Community window: four separate honest actions, only Invite has a real button
	do
		local SocialConfig = require(find("ReplicatedStorage.Modules.SocialConfig"))
		local panel = UIKit.getPanel("Social")
		panel:Open(); adv(0.4)
		local function named(name)
			local found = {}
			for _, d in M.descendants(panel.Gui) do if RawData[d].Name == name then table.insert(found, d) end end
			return found
		end
		check("the Community window has Invite, Like and Favorite rows", #named("Row_invite") == 1 and #named("Row_like") == 1 and #named("Row_favorite") == 1)
		check("the Group row is hidden until SocialConfig.GroupId is filled in", (SocialConfig.GroupId == 0) == (#named("Row_group") == 0))
		check("only the Invite row has a button; Like and Favorite are plain explanations", #named("InviteButton") == 1 and (function()
			for _, name in { "Row_like", "Row_favorite" } do
				for _, d in M.descendants(named(name)[1]) do if RawData[d].ClassName == "TextButton" then return false end end
			end
			return true
		end)())
		local savedId = SocialConfig.GroupId
		SocialConfig.GroupId = 4242
		local shown = #SocialConfig.actions()
		SocialConfig.GroupId = 0
		local hidden = #SocialConfig.actions()
		SocialConfig.GroupId = savedId
		check("SocialConfig adds the Group action once a GroupId exists", shown == hidden + 1)
		check("nothing in the window claims success", (function()
			for _, d in M.descendants(panel.Gui) do
				local text = RawData[d].Props.Text
				if type(text) == "string" and (string.find(string.lower(text), "thank", 1, true) or string.find(string.lower(text), "liked!", 1, true) or string.find(string.lower(text), "reward", 1, true)) then return false end
			end
			return true
		end)())
		panel:Close(); adv(0.3)
		local settings = UIKit.getPanel("Settings")
		settings:Open(); adv(0.4)
		local open
		for _, d in M.descendants(settings.Gui) do if RawData[d].Name == "OpenCommunity" then open = d end end
		check("Settings has a Community button that opens the window", open ~= nil)
		if open then
			RawData[open].Signals.Activated:Fire(); adv(0.6)
			check("...and it does", panel.IsOpen)
			panel:Close(); adv(0.3)
		end
		settings:Close(); adv(0.3)
	end

	-- text sizes: nothing a player has to read is tiny on a normal 1280x720 screen (effective size = TextSize x every UIScale above it)
	do
		local tiny, examples = 0, {}
		for _, name in { "Backpack", "Index", "Rebirth", "Upgrades", "Daily", "Quests", "Shop", "RobuxShop", "Settings", "Wheel", "Playtime", "Social", "Leaderboards" } do
			local panel = UIKit.getPanel(name)
			if panel then
				panel:Open(); adv(0.5)
				for _, d in M.descendants(panel.Gui) do
					local data = RawData[d]
					if (data.ClassName == "TextLabel" or data.ClassName == "TextButton") and tostring(data.Props.Text or "") ~= "" and data.Props.Visible ~= false and (data.Props.TextTransparency or 0) < 0.9 then
						local effective = data.Props.TextSize or 14
						local node = RawData[d].Parent
						while node do
							for _, child in RawData[node].Children do
								if RawData[child].ClassName == "UIScale" then effective *= RawData[child].Props.Scale or 1 end
							end
							node = RawData[node].Parent
						end
						if effective < 10.5 then
							tiny += 1
							if #examples < 8 then table.insert(examples, string.format("%s/%s %.1fpx '%s'", name, data.Name, effective, string.sub(tostring(data.Props.Text), 1, 18))) end
						end
					end
				end
				panel:Close(); adv(0.3)
			end
		end
		for _, e in examples do print("   SMALL", e) end
		check("no text in any window is smaller than about 10.5 px on a 1280x720 screen", tiny == 0, tiny)
	end

	-- every window fits on every screen size we support (phone landscape + portrait, tablet, laptop, desktop)
	do
		local cam2 = workspace.CurrentCamera
		local sizes = { Vector2.new(1920, 1080), Vector2.new(1366, 768), Vector2.new(1024, 768), Vector2.new(844, 390), Vector2.new(667, 375), Vector2.new(390, 844), Vector2.new(360, 640) }
		local tooBig, detail, measured, shopPhone, minScale = 0, "", 0, nil, 9
		for _, name in { "Backpack", "Index", "Rebirth", "Upgrades", "Daily", "Quests", "Shop", "RobuxShop", "Settings", "Codes", "Wheel", "Playtime", "Social", "Leaderboards" } do
			local panel = UIKit.getPanel(name)
			if panel then
				for _, vp in sizes do
					cam2.ViewportSize = vp
					panel:Open(); adv(0.35)
					local window = panel.Window
					-- the window sits in `motion` inside `outer` (design size) which carries the fit UIScale
					local outer = RawData[RawData[window].Parent].Parent
					local scale = 1
					for _, child in M.descendants(outer) do
						if RawData[child].ClassName == "UIScale" and RawData[child].Parent == outer then scale = RawData[child].Props.Scale end
					end
					local w = RawData[outer].Props.Size.X.Offset * scale
					local h = RawData[outer].Props.Size.Y.Offset * scale
					minScale = math.min(minScale, scale)
					measured += 1
					if name == "Shop" and vp.X == 390 then shopPhone = w end
					if w > vp.X + 1 or h > vp.Y + 1 then
						tooBig += 1
						detail ..= string.format(" [%s %dx%d on %dx%d]", name, w, h, vp.X, vp.Y)
					end
					panel:Close(); adv(0.2)
				end
			end
		end
		check("every window fits the screen on 7 sizes (desktop, laptop, tablet, phone landscape and portrait)", tooBig == 0 and measured >= 70 and shopPhone ~= nil and shopPhone < 390, detail .. string.format(" measured %d, shop on a 390 px phone: %.0f px wide, smallest window scale %.2f", measured, shopPhone or -1, minScale))
		cam2.ViewportSize = Vector2.new(1280, 720)
		adv(0.3)
	end

	-- first person cursor
	setFirstPerson(false)
	check("third person: mouse free", mouse() == Default)
	setFirstPerson(true)
	check("first person: mouse locked, no menu", mouse() == LockCenter)
	UIKit.getPanel("Settings"):Open(); adv(0.4)
	check("first person + Settings open: mouse FREE", mouse() == Default)
	UIKit.getPanel("Settings"):Close(); adv(0.4)
	check("Settings closed: first person mouse locked again", mouse() == LockCenter)
	UIKit.getPanel("Index"):Open(); adv(0.4)
	check("first person + Index open: mouse FREE", mouse() == Default)
	UIKit.getPanel("Index"):Close(); adv(0.4)
	check("Index closed: mouse locked again", mouse() == LockCenter)
	-- switching panel A -> B while open
	UIKit.getPanel("Settings"):Open(); adv(0.2)
	UIKit.getPanel("Rebirth"):Open(); adv(0.4)
	check("panel A -> panel B keeps the mouse free", mouse() == Default)
	UIKit.getPanel("Rebirth"):Close(); adv(0.4)
	check("last panel closed: locked again", mouse() == LockCenter)
	M.keysDown[tostring(M.Enum.KeyCode.LeftAlt)] = true; adv(0.2)
	check("holding ALT in first person frees the mouse", mouse() == Default)
	M.keysDown[tostring(M.Enum.KeyCode.LeftAlt)] = nil; adv(0.2)
	check("releasing ALT locks again", mouse() == LockCenter)
	setFirstPerson(false)
	check("back to third person", mouse() == Default)

	-- rebirth panel content
	local rebirth = UIKit.getPanel("Rebirth")
	rebirth:Open(); adv(0.5)
	local texts = {}
	for _, d in M.descendants(rebirth.Gui) do
		if RawData[d].ClassName == "TextLabel" then table.insert(texts, tostring(RawData[d].Props.Text)) end
	end
	local joined = table.concat(texts, "|")
	check("Rebirth UI shows requirements + rewards + slots + tower", string.find(joined, "Requirements", 1, true) and string.find(joined, "Hamster slots", 1, true) and string.find(joined, "Your tower", 1, true) and string.find(joined, "slot", 1, true), nil)
	rebirth:Close(); adv(0.4)

	-----------------------------------------------------------------
	-- master overhaul checks: HUD, hotbar, shop, banner, tutorial, nameplates
	-----------------------------------------------------------------
	local playerGui = RawData[p].Children and gui
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
	do
		local UIRegistry = require(find("StarterPlayer.StarterPlayerScripts.UI.UIRegistry"))
		local ids = {}
		for _, def in UIRegistry.list("RightRail") do table.insert(ids, def.Id) end
		check("the right rail holds ONLY Quests, Lucky Wheel, Playtime, Backpack, Coins Shop, Robux Shop, Leaderboards, Settings", table.concat(ids, ",") == "Quests,Wheel,Playtime,Backpack,Shop,RobuxShop,Leaderboards,Settings", table.concat(ids, ","))
		local backpack = UIKit.getPanel("Backpack")
		check("Hamsters, Hamster Index and Emotes moved into the Backpack", #byName(backpack.Gui, "Tab_Hamsters") == 1 and #byName(backpack.Gui, "OpenIndex") == 1 and #byName(backpack.Gui, "OpenEmotes") == 1)
		check("the old 'My Hamsters' window is gone (alias opens the Backpack tab)", UIKit.getPanel("Inventory") == nil)
	end
	check("old left sidebar is gone", #byName(gui, "Sidebar") == 0)
	for _, name in { "QuestsButton", "BackpackButton", "ShopButton", "LeaderboardsButton", "SettingsButton" } do
		check("HUD shortcut exists: " .. name, #byName(gui, name) == 1)
	end
	for _, name in { "InventoryButton", "EmotesButton", "UpgradesButton", "RebirthButton", "IndexButton", "DailyButton" } do
		check("no redundant HUD button: " .. name, #byName(gui, name) == 0)
	end
	local topBar = byName(gui, "TopBar")[1]
	local pillCount = 0
	for _, child in M.InstanceMethods.GetChildren(topBar) do
		if RawData[child].ClassName == "Frame" then pillCount += 1 end
	end
	check("top HUD has exactly four indicators", pillCount == 4, pillCount)
	local hud = textsOf(topBar)
	local rebirthIcon = false
	for _, d in M.descendants(workspace) do end
	for _, d in M.descendants(RawData[p].Children[#RawData[p].Children]) do if RawData[d].Name == "Icon_rebirth" then rebirthIcon = true end end
	check("rebirth indicator: the rebirth icon with the count (a short number; the tooltip says what it is)", rebirthIcon and string.find(hud, "|0", 1, true) ~= nil, hud)
	check("no stray 'R0' badge", string.find(hud, "|R0", 1, true) == nil)

	-- hotbar
	local HotbarConfig = require(find("ReplicatedStorage.Modules.HotbarConfig"))
	local slots = 0
	for _, d in M.descendants(byName(gui, "Hotbar")[1]) do if string.sub(RawData[d].Name, 1, 5) == "Slot_" then slots += 1 end end
	check("hotbar has every configured slot", slots == HotbarConfig.SlotCount, slots)
	local DataSystem = require(find("ServerScriptService.Systems.DataSystem"))
	local ReplicationSystem = require(find("ServerScriptService.Systems.ReplicationSystem"))
	local GearSystem = require(find("ServerScriptService.Systems.GearSystem"))
	local data = DataSystem.get(p)
	local function pressKey(code)
		local input = { KeyCode = M.Enum.KeyCode[code], UserInputType = M.Enum.UserInputType.Keyboard, UserInputState = M.Enum.UserInputState.Begin }
		RawData[UIS].Signals.InputBegan:Fire(input, false)
		adv(0.5)
	end
	data.Items = {}; data.Gear = {}; data.Hotbar = {}
	M.isServer = true; ReplicationSystem.mark(p, "Items", "Gear", "Hotbar"); M.isServer = false
	adv(1.5)
	pressKey("Two"); pressKey("Two")
	check("empty slot cannot be used", data.Items.item_coins == nil and (data.Boosts.Coins2x or 0) <= os.time())
	data.Items.item_coins = 2
	M.isServer = true; GearSystem.fill(data); ReplicationSystem.mark(p, "Items", "Hotbar"); M.isServer = false
	adv(1.5)
	check("owned consumable got hotbar slot 2", data.Hotbar["2"] == "item_coins", data.Hotbar["2"])
	pressKey("Three") -- moves the selection elsewhere
	pressKey("Two") -- select
	check("first press only selects", data.Items.item_coins == 2, data.Items.item_coins)
	pressKey("Two") -- use
	adv(0.5)
	check("second press uses the item on the server", data.Items.item_coins == 1 and (data.Boosts.Coins2x or 0) > os.time(), data.Items.item_coins)

	-- shop
	local shop = UIKit.getPanel("Shop")
	shop:Open(); adv(0.6)
	check("cash shop has category tabs: Weapons / Equipment / Boosts / Hamsters / Cosmetics (and nothing that leads to the Robux Shop)", #byName(shop.Gui, "Tab_Weapons") == 1 and #byName(shop.Gui, "Tab_Equipment") == 1 and #byName(shop.Gui, "Tab_Boosts") == 1 and #byName(shop.Gui, "Tab_Hamsters") == 1 and #byName(shop.Gui, "Tab_Cosmetics") == 1 and #byName(shop.Gui, "Mode_Robux") == 0 and #byName(shop.Gui, "Tab_Gamepasses") == 0)
	check("empty categories are not shown", #byName(shop.Gui, "Tab_Limited") == 0 and #byName(shop.Gui, "Tab_Diamonds") == 0)
	shop:Close(); adv(0.4)

	-----------------------------------------------------------------
	-- HUD geometry: regions never overlap, stay on screen, top HUD is at the top centre (6 screen sizes)
	-----------------------------------------------------------------
	local mainGui = byName(gui, "MainUI")[1] or gui
	local regionNames = { "TopColumn", "Rail", "LeftColumn", "BottomColumn" }
	local function rectOf(wrapper, viewport, inset)
		local props = RawData[wrapper].Props
		local pos, size, anchor = props.Position, props.Size, props.AnchorPoint
		local areaH = viewport.Y - inset
		local w, h = size.X.Offset + size.X.Scale * viewport.X, size.Y.Offset + size.Y.Scale * areaH
		local x = pos.X.Scale * viewport.X + pos.X.Offset - anchor.X * w
		local y = inset + pos.Y.Scale * areaH + pos.Y.Offset - anchor.Y * h
		return { x = x, y = y, w = w, h = h }
	end
	local function overlaps(a, b)
		return a.x < b.x + b.w and b.x < a.x + a.w and a.y < b.y + b.h and b.y < a.y + a.h
	end
	local viewports = { Vector2.new(1920, 1080), Vector2.new(1280, 720), Vector2.new(1024, 768), Vector2.new(800, 400), Vector2.new(667, 375), Vector2.new(844, 390) }
	local geometryOk, geometryDetail = true, ""
	local topOk = true
	for _, vp in viewports do
		cam.ViewportSize = vp
		adv(0.2)
		local rects = {}
		for _, name in regionNames do
			local wrapper = byName(mainGui, name)[1]
			rects[name] = rectOf(wrapper, vp, 36)
			local r = rects[name]
			if r.x < -0.5 or r.y < 35.5 or r.x + r.w > vp.X + 0.5 or r.y + r.h > vp.Y + 0.5 then
				geometryOk = false
				geometryDetail ..= string.format(" [%s off-screen @%dx%d: x%.0f y%.0f w%.0f h%.0f]", name, vp.X, vp.Y, r.x, r.y, r.w, r.h)
			end
		end
		for i = 1, #regionNames do
			for j = i + 1, #regionNames do
				if overlaps(rects[regionNames[i]], rects[regionNames[j]]) then
					geometryOk = false
					geometryDetail ..= string.format(" [%s x %s overlap @%dx%d]", regionNames[i], regionNames[j], vp.X, vp.Y)
				end
			end
		end
		local top = rects.TopColumn
		if math.abs((top.x + top.w / 2) - vp.X / 2) > 1 or top.y > 36 + 12 or top.y < 36 then topOk = false end
	end
	check("HUD regions stay on screen and never overlap (6 screen sizes)", geometryOk, geometryDetail)
	check("top HUD is horizontally centred and starts right below the top bar", topOk)
	cam.ViewportSize = Vector2.new(1280, 720)
	adv(0.2)

	-- inside every region the children (plus list gaps) fit the design size
	local fitOk, fitDetail = true, ""
	for _, name in regionNames do
		local wrapper = byName(mainGui, name)[1]
		local content = M.InstanceMethods.FindFirstChild(wrapper, "Content")
		local designH, designW = RawData[content].Props.Size.Y.Offset, RawData[content].Props.Size.X.Offset
		local sum, count, gap, widest = 0, 0, 0, 0
		for _, child in M.InstanceMethods.GetChildren(content) do
			local cd = RawData[child]
			if cd.ClassName == "UIListLayout" then gap = cd.Props.Padding.Offset end
			if cd.ClassName == "Frame" or cd.ClassName == "TextLabel" or cd.ClassName == "TextButton" then
				sum += cd.Props.Size.Y.Offset; count += 1; widest = math.max(widest, cd.Props.Size.X.Offset)
			end
		end
		local total = sum + gap * math.max(0, count - 1)
		if total > designH + 0.5 or widest > designW + 0.5 then
			fitOk = false
			fitDetail ..= string.format(" [%s needs %dx%d but has %dx%d]", name, widest, total, designW, designH)
		end
	end
	check("region children fit their region even with everything visible", fitOk, fitDetail)

	-- screen layering: explicit order, panels in front of the HUD, tooltips on top
	local function orderOf(name) local g = byName(RawData[p].Props.PlayerGui or gui, name)[1]; return g and RawData[g].Props.DisplayOrder end
	check("ScreenGui layers follow Theme.Layers (HUD < panels < tooltips)", (orderOf("MainUI") or 99) < (orderOf("ShopUI") or -1) and (orderOf("ShopUI") or 99) < (orderOf("Tooltips") or -1), tostring(orderOf("MainUI")) .. "/" .. tostring(orderOf("ShopUI")) .. "/" .. tostring(orderOf("Tooltips")))
	check("HUD ScreenGui is below the Roblox top bar (TopbarSafeInsets)", RawData[mainGui].Props.IgnoreGuiInset == false)

	-- registry rules
	local UIRegistry = require(find("StarterPlayer.StarterPlayerScripts.UI.UIRegistry"))
	check("registry: core entries cannot be replaced", not pcall(UIRegistry.register, { Id = "Shop", Kind = "IconButton", Slot = "RightRail", Order = 31, Icon = "bag", Panel = "Shop" }))
	check("registry: conflicting Order refused", not pcall(UIRegistry.register, { Id = "X1", Kind = "IconButton", Slot = "RightRail", Order = 30, Icon = "bag", Panel = "Shop" }))
	check("registry: unknown icon refused", not pcall(UIRegistry.register, { Id = "X2", Kind = "IconButton", Slot = "RightRail", Order = 33, Icon = "nope_nope", Panel = "Shop" }))
	check("registry: button without action refused", not pcall(UIRegistry.register, { Id = "X3", Kind = "IconButton", Slot = "RightRail", Order = 34, Icon = "bag" }))
	check("registry: unknown slot refused", not pcall(UIRegistry.register, { Id = "X4", Kind = "IconButton", Slot = "Nowhere", Order = 1, Icon = "bag", Panel = "Shop" }))
	local before = #UIRegistry.list("RightRail")
	check("registry: a valid new button is accepted and shown", UIRegistry.tryRegister({ Id = "TestButton", Kind = "IconButton", Slot = "RightRail", Order = 35, Icon = "star", Tooltip = "Test", OnActivate = function() end }) and #UIRegistry.list("RightRail") == before + 1)
	adv(0.3)
	check("registry: the new button appears in the rail", #byName(mainGui, "TestButtonButton") == 1)
	check("registry: duplicate Id refused", not pcall(UIRegistry.register, { Id = "TestButton", Kind = "IconButton", Slot = "RightRail", Order = 36, Icon = "star", OnActivate = function() end }))

	-----------------------------------------------------------------
	-- leaderboard screen: periods, rows, states
	-----------------------------------------------------------------
	local LBConfig = require(find("ReplicatedStorage.Modules.LeaderboardConfig"))
	local LBService = require(find("ServerScriptService.Systems.LeaderboardService"))
	local nowT = LBService.clock()
	local function setScore(metric, periodName, userId, value)
		local name = LBConfig.storeName(metric, periodName, nowT)
		M.orderedStores[name] = M.orderedStores[name] or {}
		M.orderedStores[name][tostring(userId)] = value
	end
	local myId = RawData[p].Props.UserId
	setScore("Money", "Weekly", 111, 90000); setScore("Money", "Weekly", 222, 50000); setScore("Money", "Weekly", myId, 1234)
	setScore("Money", "AllTime", 111, 900000)
	LBService.fetch("Money", "Weekly", true); LBService.fetch("Money", "AllTime", true)
	local board = UIKit.getPanel("Leaderboards")
	check("leaderboard panel + rail button exist", board ~= nil and #byName(gui, "LeaderboardsButton") == 1)
	adv(1.2)
	board:Open(); adv(1.5)
	check("period selector has Weekly / Monthly / Yearly / All-time", #byName(board.Gui, "Period_Weekly") == 1 and #byName(board.Gui, "Period_Monthly") == 1 and #byName(board.Gui, "Period_Yearly") == 1 and #byName(board.Gui, "Period_AllTime") == 1)
	local function rowTexts()
		local list = {}
		for _, d in M.descendants(board.Gui) do
			local rd = RawData[d]
			if rd.ClassName == "TextLabel" and rd.Props.Text and rd.Props.Text ~= "" then table.insert(list, tostring(rd.Props.Text)) end
		end
		return table.concat(list, "|")
	end
	local text = rowTexts()
	check("rankings show real names and scores (top three + me)", string.find(text, "User111", 1, true) ~= nil and string.find(text, "90.0K", 1, true) ~= nil and string.find(text, "(you)", 1, true) ~= nil, text:sub(1, 160))
	check("footer shows my rank", string.find(text, "Your rank: #3", 1, true) ~= nil)
	adv(1.2)
	RawData[byName(board.Gui, "Period_AllTime")[1]].Signals.Activated:Fire()
	adv(2)
	text = rowTexts()
	check("switching to All-time shows different data", string.find(text, "900", 1, true) ~= nil and string.find(text, "90.0K", 1, true) == nil, text:sub(1, 120))
	adv(1.2)
	RawData[byName(board.Gui, "Period_Yearly")[1]].Signals.Activated:Fire()
	adv(2)
	check("an empty ranking says so", string.find(rowTexts(), "No scores yet", 1, true) ~= nil)
	M.orderedFail = true
	LBService.fetch("Money", "Monthly", true)
	adv(1.2)
	RawData[byName(board.Gui, "Period_Monthly")[1]].Signals.Activated:Fire()
	adv(2)
	local retry = byName(board.Gui, "Retry")[1]
	check("an outage shows an error with a retry button (no crash)", string.find(rowTexts(), "could not be loaded", 1, true) ~= nil and RawData[retry].Props.Visible == true)
	M.orderedFail = false
	board:Close(); adv(0.4)
	check("boards in the hall are filled by the server", (function()
		local hall = workspace:FindFirstChild("LeaderboardHall")
		return hall ~= nil and #byName(hall, "BoardGui") == 3
	end)())

	-- the big base banner is gone: the remote must not exist any more
	local remoteFolder = game:GetService("ReplicatedStorage"):FindFirstChild("RemoteEvents")
	check("no 'base open/locked' banner remote or screen", remoteFolder ~= nil and remoteFolder:FindFirstChild("Banner") == nil and #byName(gui, "BannerUI") == 0)

	-- tutorial
	local card = byName(gui, "TutorialCard")[1]
	data.Tutorial = { Step = 1, Done = false, Skipped = false }
	M.isServer = true; ReplicationSystem.mark(p, "Tutorial"); M.isServer = false
	adv(1.5)
	check("tutorial card shows for a new player", card ~= nil and RawData[card].Props.Visible == true and string.find(textsOf(card), "Your base", 1, true) ~= nil)
	RawData[byName(card, "Next")[1]].Signals.Activated:Fire()
	adv(1.5)
	check("pressing the button advances the SERVER step", data.Tutorial.Step == 2, data.Tutorial.Step)
	RawData[byName(card, "Skip")[1]].Signals.Activated:Fire()
	adv(1.5)
	check("skip completes and hides it", data.Tutorial.Done == true and RawData[card].Props.Visible == false)

	-- nameplate size / distance
	local plates = 0
	local fixed = true
	for _, d in M.descendants(RawData[p].Props.PlayerGui or gui) do
		local rd = RawData[d]
		if rd.ClassName == "BillboardGui" and string.sub(rd.Name, 1, 8) == "BallTag_" then
			plates += 1
			local size = rd.Props.Size
			if size.X.Scale ~= 0 or size.X.Offset ~= 158 or size.Y.Offset ~= 66 or rd.Props.MaxDistance ~= 120 then fixed = false end
		end
	end
	check("nameplates use fixed pixel size + max distance", plates > 0 and fixed, plates)
	local plateText = {}
	for _, d in M.descendants(RawData[p].Props.PlayerGui or gui) do
		local rd = RawData[d]
		if rd.ClassName == "TextLabel" and rd.Props.Text and string.find(tostring(rd.Props.Text), "/s", 1, true) then table.insert(plateText, tostring(rd.Props.Text)) end
	end
	check("nameplates show income per second", #plateText > 0, plateText[1])

	-- no emoji text anywhere in the UI
	local emojiFound = 0
	for _, d in M.descendants(gui) do
		local text = RawData[d].Props.Text
		if type(text) == "string" and string.find(text, "[\240-\244]") then emojiFound += 1 end
	end
	check("no emoji in any UI text", emojiFound == 0, emojiFound)

	-- ball labels hang on a non-rotating anchor
	local HamsterSystem = require(find("ServerScriptService.Systems.HamsterSystem"))
	local HamsterDatabase = require(find("ReplicatedStorage.Modules.HamsterDatabase"))
	M.isServer = true
	local e = HamsterSystem.spawn(HamsterDatabase.Spawnable["Legendary"][1], p)
	M.isServer = false
	adv(3)
	local anchors, wrongRot = 0, 0
	for _, d in M.descendants(workspace) do
		local data = RawData[d]
		if data.ClassName == "Part" and string.sub(data.Name, 1, 12) == "LabelAnchor_" then
			anchors += 1
			local cf = data.Props.CFrame
			if math.abs(cf.r[1] - 1) > 1e-3 or math.abs(cf.r[5] - 1) > 1e-3 then wrongRot += 1 end
		end
	end
	check("ball tags hang on a ball anchor part", anchors >= 1, anchors)
	check("anchors never rotate (identity rotation) while the ball rolls", wrongRot == 0, wrongRot)

	print(string.format("PASS %d FAIL %d errors %d", results.pass, results.fail, #M.Sim.errors))
	for i, err in M.Sim.errors do if i <= 8 then print(err) end end
end)
M.Sim.advance(0)
