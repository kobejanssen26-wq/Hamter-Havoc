--[[
	AdminUI: the staff panel. There is NO button for it anywhere on the HUD.

	How it opens: the key in InputConfig.Bindings.Admin (default F10) or the chat command /admin. Both only ask the server
	(Remotes "Admin" -> "open"). A normal player gets no answer at all, so nothing happens and nothing is revealed. The server
	answers staff with the list of commands THEIR role may run; this file builds its forms from that list, so it never needs
	to know a UserId, a role name or a permission. Every button press is checked again on the server.

	This panel is a developer tool and is generated in code on purpose (it is not part of the player HUD you restyle in Studio).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local InputConfig = require(Modules:WaitForChild("InputConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))
local HamsterDatabase = require(Modules:WaitForChild("HamsterDatabase"))
local ItemRegistry = require(Modules:WaitForChild("ItemRegistry"))
local RarityConfig = require(Modules:WaitForChild("RarityConfig"))

local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local AdminUI = {}

local C = UIKit.Colors
local panel: any = nil
local data: any = nil
local selected: { UserId: number?, Name: string?, DisplayName: string?, Role: string? } = {}
local playerList: ScrollingFrame? = nil
local selectedCard: Frame? = nil
local searchText = ""
local editingRole: string? = nil -- role open in the role editor ("" = a new role)
local tabsApi: any = nil
local resultLabel: TextLabel? = nil
local content: Frame? = nil
local userIdBoxes: { TextBox } = {}
local category = "Dashboard"
local opening = false

local function say(text: string, good: boolean)
	if resultLabel then
		resultLabel.Text = string.format('<font color="%s">%s</font>', if good then "#60c47e" else "#f06262", text)
	end
end

local function call(...): any
	local ok, result = pcall(function(...)
		return Remotes.func("Admin"):InvokeServer(...)
	end, ...)
	return if ok then result else nil
end

local function textBox(parent: Instance, placeholder: string, size: UDim2, text: string?): TextBox
	local box = UIKit.new("TextBox", {
		Size = size,
		BackgroundColor3 = C.CreamDark,
		Font = UIKit.Fonts.Body,
		TextSize = UIKit.Type.Body,
		TextColor3 = C.Ink,
		PlaceholderText = placeholder,
		PlaceholderColor3 = C.Muted,
		Text = text or "",
		ClearTextOnFocus = false,
		TextXAlignment = Enum.TextXAlignment.Left,
		BorderSizePixel = 0,
	}, parent)
	UIKit.corner(box, 6)
	UIKit.padding(box, 6, 0)
	return box
end

-- Reads a field's text as the type the server wants. nil = empty.
local function parse(param: any, text: string): any
	if text == "" then
		return nil
	end
	if param.Type == "int" or param.Type == "number" or param.Type == "userid" then
		return tonumber(text)
	elseif param.Type == "bool" then
		return if text == "true" then true elseif text == "false" then false else nil
	elseif param.Type == "any" then
		if text == "true" then
			return true
		elseif text == "false" then
			return false
		end
		return tonumber(text)
	end
	return text
end

local function runCommand(name: string, params: { [string]: any }, confirmed: boolean?): any
	local result = call("run", name, params, confirmed == true)
	if result == nil then
		say("No answer from the server (not allowed?)", false)
		return { ok = false }
	end
	if result.needsConfirm then
		return result
	end
	say(result.msg or "", result.ok == true)
	return result
end

-- One command as a card with its fields and a Run button.
local function commandCard(parent: Instance, command: any, order: number)
	local fields = #command.Params
	local card = UIKit.frame(parent, { Size = UDim2.new(1, -8, 0, 44 + fields * 34 + 6), LayoutOrder = order, BackgroundColor3 = C.Card })
	UIKit.corner(card, 6)
	UIKit.label(card, { Position = UDim2.fromOffset(10, 6), Size = UDim2.new(1, -20, 0, 26), Text = command.Label, Font = UIKit.Fonts.Title, TextSize = UIKit.Type.Heading })
	local inputs: { [string]: TextBox } = {}
	local y = 36
	for _, param in command.Params do
		if param.Type == "player" then
			local label = UIKit.label(card, { Position = UDim2.fromOffset(10, y), Size = UDim2.new(1, -20, 0, 28), Text = "", TextColor3 = C.Muted, TextSize = UIKit.Type.Caption })
			label:SetAttribute("PlayerField", true)
			task.defer(function()
				label.Text = "Player: " .. (selected.Name or "(pick one on the left)")
			end)
			table.insert(userIdBoxes, label :: any)
		else
			local placeholder = param.Label or param.Name
			local box = textBox(card, placeholder, UDim2.new(1, -20, 0, 28), if param.Type == "userid" and selected.UserId then tostring(selected.UserId) else nil)
			box.Position = UDim2.fromOffset(10, y)
			inputs[param.Name] = box
			if param.Type == "userid" then
				table.insert(userIdBoxes, box)
			end
		end
		y += 34
	end
	local run: TextButton
	local pending = 0
	run = UIKit.button(card, {
		Text = "Run",
		Size = UDim2.fromOffset(110, 28),
		Position = UDim2.new(1, -10, 0, 6),
		AnchorPoint = Vector2.new(1, 0),
		Color = C.Blue,
		TextSize = UIKit.Type.Body,
		OnClick = function()
			local params: { [string]: any } = {}
			for _, param in command.Params do
				if param.Type == "player" then
					params[param.Name] = selected.UserId
				elseif inputs[param.Name] then
					params[param.Name] = parse(param, inputs[param.Name].Text)
				end
			end
			local confirming = pending > os.clock()
			local result = runCommand(command.Name, params, confirming)
			if result.needsConfirm then
				pending = os.clock() + 6
				run.Text = "Confirm?"
				UIKit.setButtonColor(run, C.Red)
				say(result.msg, false)
				task.delay(6, function()
					if pending <= os.clock() and run.Parent then
						run.Text = "Run"
						UIKit.setButtonColor(run, C.Blue)
					end
				end)
			else
				pending = 0
				run.Text = "Run"
				UIKit.setButtonColor(run, C.Blue)
			end
		end,
	})
end

-- Settings tab: every GameConfig value with its explanation, live/Studio-only flag, Save and Reset.
local function settingsView(parent: Instance)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	UIKit.label(parent, { Size = UDim2.new(1, -8, 0, 26), LayoutOrder = nextOrder(), Text = "GAME SETTINGS  (live = changes at once and is saved)", Font = UIKit.Fonts.Title, TextSize = UIKit.Type.Caption, TextColor3 = C.Muted })
	for _, setting in data.Settings or {} do
		local row = UIKit.frame(parent, { Size = UDim2.new(1, -8, 0, 62), LayoutOrder = nextOrder(), BackgroundColor3 = C.Card })
		UIKit.corner(row, 6)
		local changed = setting.Value ~= setting.Default
		UIKit.label(row, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -250, 0, 22), Text = string.format("%s.%s%s", setting.Section, setting.Key, if changed then "  *" else ""), Font = UIKit.Fonts.Title, TextSize = UIKit.Type.Body, TextColor3 = if changed then C.Gold else C.Ink })
		UIKit.label(row, { Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -250, 0, 34), Text = string.format("%s  [default %s%s]", setting.Doc, tostring(setting.Default), if setting.Live then ", live" else ", Studio only"), TextSize = 12, TextColor3 = C.Muted, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top })
		if setting.Live then
			local box = textBox(row, "value", UDim2.fromOffset(80, 28), tostring(setting.Value))
			box.Position = UDim2.new(1, -230, 0.5, 0)
			box.AnchorPoint = Vector2.new(0, 0.5)
			UIKit.button(row, {
				Text = "Save", Size = UDim2.fromOffset(60, 28), Position = UDim2.new(1, -144, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Color = C.Green, TextSize = UIKit.Type.Caption,
				OnClick = function()
					local value: any = tonumber(box.Text)
					if box.Text == "true" then value = true elseif box.Text == "false" then value = false end
					runCommand("setSetting", { setting = setting.Section .. "." .. setting.Key, value = value })
				end,
			})
			UIKit.button(row, {
				Text = "Reset", Size = UDim2.fromOffset(66, 28), Position = UDim2.new(1, -76, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Color = C.Muted, TextSize = UIKit.Type.Caption,
				OnClick = function()
					local result = runCommand("resetSetting", { setting = setting.Section .. "." .. setting.Key })
					if result.ok then
						box.Text = tostring(setting.Default)
					end
				end,
			})
		end
	end
	UIKit.label(parent, { Size = UDim2.new(1, -8, 0, 30), LayoutOrder = nextOrder(), Text = "SHOP PRICES  (cash / diamond items)", Font = UIKit.Fonts.Title, TextSize = UIKit.Type.Caption, TextColor3 = C.Muted })
	for _, item in data.Shop or {} do
		local row = UIKit.frame(parent, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = nextOrder(), BackgroundColor3 = C.Card })
		UIKit.corner(row, 6)
		UIKit.label(row, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -330, 1, 0), Text = string.format("%s  (%s)%s", item.Name, item.Id, if item.Disabled then "  DISABLED" else ""), TextSize = UIKit.Type.Caption })
		local box = textBox(row, "price", UDim2.fromOffset(100, 26), tostring(item.Price))
		box.Position = UDim2.new(1, -310, 0.5, 0)
		box.AnchorPoint = Vector2.new(0, 0.5)
		UIKit.button(row, { Text = "Set price", Size = UDim2.fromOffset(76, 26), Position = UDim2.new(1, -204, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Color = C.Green, TextSize = UIKit.Type.Caption,
			OnClick = function() runCommand("setShopItem", { item = item.Id, price = tonumber(box.Text) }, true) end })
		UIKit.button(row, { Text = if item.Disabled then "Enable" else "Disable", Size = UDim2.fromOffset(66, 26), Position = UDim2.new(1, -124, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Color = C.Blue, TextSize = UIKit.Type.Caption,
			OnClick = function() runCommand("setShopItem", { item = item.Id, disabled = not item.Disabled }, true) end })
		UIKit.button(row, { Text = "Reset", Size = UDim2.fromOffset(50, 26), Position = UDim2.new(1, -54, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), Color = C.Muted, TextSize = UIKit.Type.Caption,
			OnClick = function() runCommand("resetShopItem", { item = item.Id }) end })
	end
end

---------------------------------------------------------------------------
-- shared pieces
---------------------------------------------------------------------------

local function avatarUrl(userId: number): string
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48", userId)
end

local function sectionTitle(parent: Instance, text: string, order: number)
	UIKit.label(parent, { Size = UDim2.new(1, -8, 0, 26), LayoutOrder = order, Text = text, Font = UIKit.Fonts.Title, TextSize = UIKit.Type.Caption, TextColor3 = C.Muted })
end

-- A button that asks "Confirm?" on the first click when the server wants a confirmation (same flow as the command cards).
local function runButton(parent: Instance, props: { Text: string, Size: UDim2, Position: UDim2?, AnchorPoint: Vector2?, Color: Color3?, LayoutOrder: number? }, build: () -> (string?, { [string]: any }?), after: ((any) -> ())?): TextButton
	local pending = 0
	local baseColor = props.Color or C.Blue
	local button: TextButton
	button = UIKit.button(parent, {
		Text = props.Text, Size = props.Size, Position = props.Position, AnchorPoint = props.AnchorPoint, Color = baseColor, TextSize = UIKit.Type.Caption, LayoutOrder = props.LayoutOrder,
		OnClick = function()
			local name, params = build()
			if not name or not params then
				return
			end
			local result = runCommand(name, params, pending > os.clock())
			if result.needsConfirm then
				pending = os.clock() + 6
				button.Text = "Confirm?"
				UIKit.setButtonColor(button, C.Red)
				say(result.msg, false)
				task.delay(6, function()
					if pending <= os.clock() and button.Parent then
						button.Text = props.Text
						UIKit.setButtonColor(button, baseColor)
					end
				end)
				return
			end
			pending = 0
			button.Text = props.Text
			UIKit.setButtonColor(button, baseColor)
			if after then
				after(result)
			end
		end,
	})
	return button
end

local function needPlayer(): number?
	if not selected.UserId then
		say("Pick a player on the left first.", false)
		return nil
	end
	return selected.UserId
end

local function reopen()
	-- fetch fresh data (roles, members, players) and rebuild the current tab without losing it
	-- (the server drops requests that come faster than AdminConfig.MinSecondsBetweenRequests, so wait a moment first)
	task.wait(0.25)
	local result = call("open")
	if result and result.ok then
		data = result.data
		AdminUI.rebuild()
	end
end

---------------------------------------------------------------------------
-- selected player card + player list
---------------------------------------------------------------------------

local function renderSelected()
	if not selectedCard then
		return
	end
	for _, child in selectedCard:GetChildren() do
		child:Destroy()
	end
	if not selected.UserId then
		UIKit.label(selectedCard, { Size = UDim2.fromScale(1, 1), Text = "No player selected", TextColor3 = C.Muted, TextSize = UIKit.Type.Caption })
		return
	end
	UIKit.new("ImageLabel", { Size = UDim2.fromOffset(48, 48), Position = UDim2.fromOffset(6, 6), BackgroundColor3 = C.CreamDark, Image = avatarUrl(selected.UserId), BorderSizePixel = 0 }, selectedCard)
	UIKit.label(selectedCard, { Position = UDim2.fromOffset(60, 4), Size = UDim2.new(1, -64, 0, 20), Text = selected.DisplayName or selected.Name or "?", Font = UIKit.Fonts.Title, TextSize = UIKit.Type.Body })
	UIKit.label(selectedCard, { Position = UDim2.fromOffset(60, 24), Size = UDim2.new(1, -64, 0, 16), Text = "@" .. tostring(selected.Name) .. "   " .. tostring(selected.UserId), TextColor3 = C.Muted, TextSize = 11 })
	UIKit.label(selectedCard, { Position = UDim2.fromOffset(60, 40), Size = UDim2.new(1, -64, 0, 16), Text = "Role: " .. tostring(selected.Role or "none") .. (if Players:GetPlayerByUserId(selected.UserId) then "" else "  (offline)"), TextColor3 = C.Muted, TextSize = 11 })
end

local function choose(userId: number?, name: string?, displayName: string?, role: string?)
	selected.UserId, selected.Name, selected.DisplayName, selected.Role = userId, name, displayName, role
	renderSelected()
	if category == "Bases" and content then
		AdminUI.rebuild()
	end
	for _, element in userIdBoxes do
		if element:IsA("TextBox") then
			if userId then
				element.Text = tostring(userId)
			end
		elseif element:IsA("TextLabel") then
			element.Text = "Player: " .. (name or "(pick one on the left)")
		end
	end
end

local function fillPlayers()
	if not playerList then
		return
	end
	for _, child in playerList:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local needle = string.lower(searchText)
	local order = 0
	for _, entry in data.Players do
		if needle == "" or string.find(string.lower(entry.Name), needle, 1, true) or string.find(string.lower(entry.DisplayName or ""), needle, 1, true) then
			order += 1
			local isSelected = selected.UserId == entry.UserId
			local row = UIKit.button(playerList, {
				Text = "", Size = UDim2.new(1, -8, 0, 40), Color = if isSelected then C.Blue else C.Card, LayoutOrder = order, Name = "Player_" .. entry.Name,
				OnClick = function()
					choose(entry.UserId, entry.Name, entry.DisplayName, entry.Role)
					fillPlayers()
				end,
			})
			UIKit.new("ImageLabel", { Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = C.CreamDark, Image = avatarUrl(entry.UserId), BorderSizePixel = 0 }, row)
			UIKit.label(row, { Position = UDim2.fromOffset(42, 2), Size = UDim2.new(1, -46, 0, 18), Text = entry.DisplayName or entry.Name, Font = UIKit.Fonts.Title, TextSize = 13 })
			UIKit.label(row, { Position = UDim2.fromOffset(42, 20), Size = UDim2.new(1, -46, 0, 16), Text = "@" .. entry.Name .. (if entry.Role then "  [" .. entry.Role .. "]" else ""), TextColor3 = if isSelected then C.White else C.Muted, TextSize = 11 })
		end
	end
	if order == 0 then
		UIKit.label(playerList, { Size = UDim2.new(1, -8, 0, 30), Text = "No players match", TextColor3 = C.Muted, TextSize = UIKit.Type.Caption })
	end
end

---------------------------------------------------------------------------
-- tabs
---------------------------------------------------------------------------

local function dashboardView(parent: Instance)
	local d = data.Dashboard or {}
	local order = 0
	local function line(title: string, value: string)
		order += 1
		local row = UIKit.frame(parent, { Size = UDim2.new(1, -8, 0, 34), LayoutOrder = order, BackgroundColor3 = C.Card })
		UIKit.corner(row, 6)
		UIKit.label(row, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0.5, -10, 1, 0), Text = title, TextColor3 = C.Muted, TextSize = UIKit.Type.Caption })
		UIKit.label(row, { Position = UDim2.new(0.5, 0, 0, 0), Size = UDim2.new(0.5, -10, 1, 0), Text = value, Font = UIKit.Fonts.Title, TextSize = UIKit.Type.Body, TextXAlignment = Enum.TextXAlignment.Right })
	end
	sectionTitle(parent, "DASHBOARD", 0)
	line("Your role", tostring(d.Role or data.Role))
	line("Players in this server", tostring(d.Players or #data.Players))
	line("Staff online", tostring(d.StaffOnline or 0))
	line("Server running for", string.format("%d min", math.floor((d.Uptime or 0) / 60)))
	line("Roles saved", if d.RolesSaved == false then "NO - DataStore unavailable (changes last until the server closes)" else "yes")
	local sections = {}
	for _, tab in AdminUI.tabList() do
		table.insert(sections, tab.Text)
	end
	line("Sections you may use", table.concat(sections, ", "))
	order += 1
	UIKit.label(parent, { Size = UDim2.new(1, -8, 0, 60), LayoutOrder = order, TextWrapped = true, TextColor3 = C.Muted, TextSize = UIKit.Type.Caption, TextYAlignment = Enum.TextYAlignment.Top,
		Text = "Pick a player on the left (or type a username), then choose a section. Everything you do is checked again by the server and written to the staff log." })
end

local PERM_ORDER = { "General", "Moderation", "Economy", "Staff" }

local function rolesView(parent: Instance)
	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	sectionTitle(parent, "ROLES  (strongest first)", nextOrder())
	local editingDef: any = nil
	for _, role in data.Roles or {} do
		if role.Name == editingRole then
			editingDef = role
		end
		local row = UIKit.frame(parent, { Size = UDim2.new(1, -8, 0, 44), LayoutOrder = nextOrder(), BackgroundColor3 = if role.Name == editingRole then C.CardHover else C.Card })
		UIKit.corner(row, 6)
		UIKit.label(row, { Position = UDim2.fromOffset(10, 2), Size = UDim2.new(1, -220, 0, 22), Text = role.Name .. (if role.Custom then "  (custom)" elseif role.Overridden then "  (edited)" else ""), Font = UIKit.Fonts.Title, TextSize = UIKit.Type.Body })
		UIKit.label(row, { Position = UDim2.fromOffset(10, 24), Size = UDim2.new(1, -220, 0, 18), Text = string.format("priority %s  -  %d permissions  -  %d members", tostring(role.Level), #role.Permissions, #role.Members), TextColor3 = C.Muted, TextSize = 11 })
		if role.Editable then
			UIKit.button(row, { Text = "Edit", Size = UDim2.fromOffset(70, 28), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Color = C.Blue, TextSize = UIKit.Type.Caption,
				OnClick = function() editingRole = role.Name; AdminUI.rebuild() end })
		else
			UIKit.chip(row, if role.Protected then "PROTECTED" else "LOCKED", C.Muted, UDim2.fromOffset(90, 22)).Position = UDim2.new(1, -100, 0.5, -11)
		end
	end
	UIKit.button(parent, { Text = "+ New role", Size = UDim2.fromOffset(140, 32), LayoutOrder = nextOrder(), Color = C.Green, TextSize = UIKit.Type.Caption,
		OnClick = function() editingRole = ""; AdminUI.rebuild() end })

	if editingRole == nil then
		return
	end
	-- the editor
	local isNew = editingRole == ""
	local def = editingDef or { Name = "", Level = 1.5, Permissions = { "Panel" }, Limits = {}, Members = {} }
	sectionTitle(parent, if isNew then "NEW ROLE" else "EDIT ROLE: " .. editingRole, nextOrder())
	local card = UIKit.frame(parent, { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder(), BackgroundColor3 = C.Card })
	UIKit.corner(card, 6)
	UIKit.list(card, Enum.FillDirection.Vertical, 6)
	UIKit.padding(card, 10, 10)
	local nameBox = textBox(card, "Role name (2-24 letters / digits)", UDim2.new(1, 0, 0, 28), def.Name)
	local levelBox = textBox(card, "Priority 0.5 - 3.9 (higher = stronger)", UDim2.new(1, 0, 0, 28), tostring(def.Level))
	local chosen: { [string]: boolean } = {}
	for _, id in def.Permissions do
		chosen[id] = true
	end
	local byGroup: { [string]: { any } } = {}
	for _, permission in data.Permissions or {} do
		byGroup[permission.Group] = byGroup[permission.Group] or {}
		table.insert(byGroup[permission.Group], permission)
	end
	for _, group in PERM_ORDER do
		if byGroup[group] then
			UIKit.label(card, { Size = UDim2.new(1, 0, 0, 20), Text = string.upper(group), Font = UIKit.Fonts.Title, TextSize = 11, TextColor3 = C.Muted })
			for _, permission in byGroup[group] do
				local row = UIKit.frame(card, { Size = UDim2.new(1, 0, 0, 28), BackgroundTransparency = 1, Name = "Perm_" .. permission.Id })
				UIKit.toggle(row, { Value = chosen[permission.Id] == true, Position = UDim2.fromOffset(0, 2), OnChanged = function(value) chosen[permission.Id] = value end })
				UIKit.label(row, { Position = UDim2.fromOffset(70, 0), Size = UDim2.new(1, -70, 1, 0), Text = permission.Label, TextSize = UIKit.Type.Caption })
			end
		end
	end
	UIKit.label(card, { Size = UDim2.new(1, 0, 0, 20), Text = "LIMITS (never above your own)", Font = UIKit.Fonts.Title, TextSize = 11, TextColor3 = C.Muted })
	local limitBoxes: { [string]: TextBox } = {}
	for _, key in { "MaxCash", "MaxDiamonds", "MaxRebirths", "MaxBanMinutes" } do
		limitBoxes[key] = textBox(card, key, UDim2.new(1, 0, 0, 28), tostring((def.Limits or {})[key] or 0))
		limitBoxes[key].Name = "Limit_" .. key
	end
	local buttons = UIKit.frame(card, { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1 })
	UIKit.list(buttons, Enum.FillDirection.Horizontal, 8)
	local function collect(): (string?, { [string]: any }?)
		local permissions = {}
		for _, permission in data.Permissions or {} do
			if chosen[permission.Id] then
				table.insert(permissions, permission.Id)
			end
		end
		local limits = {}
		for key, box in limitBoxes do
			limits[key] = tonumber(box.Text) or 0
		end
		return "saveRole", { oldName = if isNew then "" else editingRole, name = nameBox.Text, level = tonumber(levelBox.Text) or 0, permissions = permissions, limits = limits }
	end
	runButton(buttons, { Text = "Save role", Size = UDim2.fromOffset(110, 30), Color = C.Green }, collect, function(result)
		if result.ok then
			editingRole = string.gsub(nameBox.Text, "^%s*(.-)%s*$", "%1")
			reopen()
		end
	end)
	if not isNew then
		runButton(buttons, { Text = if def.Custom then "Delete role" else "Reset to file", Size = UDim2.fromOffset(120, 30), Color = C.Red }, function()
			return "deleteRole", { name = editingRole }
		end, function(result)
			if result.ok then
				editingRole = nil
				reopen()
			end
		end)
		UIKit.button(buttons, { Text = "Give to selected player", Size = UDim2.fromOffset(170, 30), Color = C.Blue, TextSize = UIKit.Type.Caption,
			OnClick = function()
				local id = needPlayer()
				if id then
					-- a role gets assigned with the same confirm flow
					local result = runCommand("setStaff", { userId = id, role = editingRole, name = selected.Name }, false)
					if result.needsConfirm then
						task.wait(0.25)
						result = runCommand("setStaff", { userId = id, role = editingRole, name = selected.Name }, true)
					end
					if result.ok then reopen() end
				end
			end })
	end
	UIKit.button(buttons, { Text = "Close", Size = UDim2.fromOffset(80, 30), Color = C.Muted, TextSize = UIKit.Type.Caption, OnClick = function() editingRole = nil; AdminUI.rebuild() end })

	if not isNew then
		sectionTitle(parent, "MEMBERS OF " .. string.upper(editingRole :: string), nextOrder())
		if #def.Members == 0 then
			UIKit.label(parent, { Size = UDim2.new(1, -8, 0, 24), LayoutOrder = nextOrder(), Text = "Nobody has this role yet.", TextColor3 = C.Muted, TextSize = UIKit.Type.Caption })
		end
		for _, member in def.Members do
			local row = UIKit.frame(parent, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = nextOrder(), BackgroundColor3 = C.Card })
			UIKit.corner(row, 6)
			UIKit.new("ImageLabel", { Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = C.CreamDark, Image = avatarUrl(member.UserId), BorderSizePixel = 0 }, row)
			UIKit.label(row, { Position = UDim2.fromOffset(44, 0), Size = UDim2.new(1, -170, 1, 0), Text = string.format("%s  (%d)  %s", member.Name or "?", member.UserId, if member.Source == "file" then "set in AdminConfig" else ""), TextSize = UIKit.Type.Caption })
			if member.Source == "panel" then
				runButton(row, { Text = "Remove", Size = UDim2.fromOffset(80, 26), Position = UDim2.new(1, -8, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Color = C.Red }, function()
					return "setStaff", { userId = member.UserId, role = "None" }
				end, function(result)
					if result.ok then reopen() end
				end)
			end
		end
	end
end

-- Visual hamster picker: the SAME catalog as the game (HamsterDatabase), so new hamsters show up by themselves.
local hamsterState = { Page = 1, Rarity = "All", Search = "", Picked = nil :: any }
local PAGE_SIZE = 12

local function hamsterView(parent: Instance)
	local rarityNames = { "All" }
	for _, id in RarityConfig.Order do
		table.insert(rarityNames, id)
	end
	local top = UIKit.frame(parent, { Size = UDim2.new(1, -8, 0, 34), LayoutOrder = 1, BackgroundTransparency = 1 })
	UIKit.list(top, Enum.FillDirection.Horizontal, 6)
	local search = textBox(top, "Search hamsters", UDim2.fromOffset(200, 30), hamsterState.Search)
	search.Name = "HamsterSearch"
	local rarityButton = UIKit.button(top, { Text = "Rarity: " .. hamsterState.Rarity, Size = UDim2.fromOffset(150, 30), Color = C.Purple, TextSize = UIKit.Type.Caption,
		OnClick = function()
			local index = table.find(rarityNames, hamsterState.Rarity) or 1
			hamsterState.Rarity = rarityNames[index % #rarityNames + 1]
			hamsterState.Page = 1
			AdminUI.rebuild()
		end })
	rarityButton.Name = "RarityFilter"
	search.FocusLost:Connect(function()
		hamsterState.Search = search.Text
		hamsterState.Page = 1
		AdminUI.rebuild()
	end)

	local matches = {}
	local needle = string.lower(hamsterState.Search)
	for _, species in HamsterDatabase.Species do
		if (hamsterState.Rarity == "All" or species.Rarity == hamsterState.Rarity) and (needle == "" or string.find(string.lower(species.Name), needle, 1, true) or string.find(string.lower(species.Id), needle, 1, true)) then
			table.insert(matches, species)
		end
	end
	local pages = math.max(1, math.ceil(#matches / PAGE_SIZE))
	hamsterState.Page = math.clamp(hamsterState.Page, 1, pages)

	local grid = UIKit.frame(parent, { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, BackgroundTransparency = 1, Name = "HamsterGrid" })
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(112, 150)
	layout.CellPadding = UDim2.fromOffset(6, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = grid
	for index = (hamsterState.Page - 1) * PAGE_SIZE + 1, math.min(#matches, hamsterState.Page * PAGE_SIZE) do
		local species = matches[index]
		local picked = hamsterState.Picked == species.Id
		local cell = UIKit.button(grid, { Text = "", Size = UDim2.fromOffset(112, 150), Color = if picked then C.Blue else C.Card, Name = "Hamster_" .. species.Id, LayoutOrder = index,
			OnClick = function() hamsterState.Picked = species.Id; AdminUI.rebuild() end })
		UIKit.hamsterIcon(cell, species, { Size = UDim2.fromOffset(84, 70), Position = UDim2.new(0.5, 0, 0, 4), AnchorPoint = Vector2.new(0.5, 0) })
		UIKit.label(cell, { Position = UDim2.fromOffset(2, 76), Size = UDim2.new(1, -4, 0, 32), Text = species.Name, Font = UIKit.Fonts.Title, TextSize = 12, TextWrapped = true })
		local rarity = RarityConfig.ById[species.Rarity]
		UIKit.label(cell, { Position = UDim2.fromOffset(2, 108), Size = UDim2.new(1, -4, 0, 16), Text = rarity.Name, TextColor3 = rarity.Color, TextSize = 11 })
		UIKit.label(cell, { Position = UDim2.fromOffset(2, 126), Size = UDim2.new(1, -4, 0, 16), Text = string.format("+%s/s", tostring(math.floor(HamsterDatabase.income(species) * 10) / 10)), TextColor3 = C.Muted, TextSize = 11 })
	end

	local bar = UIKit.frame(parent, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 3, BackgroundTransparency = 1 })
	UIKit.list(bar, Enum.FillDirection.Horizontal, 8)
	UIKit.button(bar, { Text = "<", Size = UDim2.fromOffset(40, 30), Color = C.Muted, OnClick = function() hamsterState.Page -= 1; AdminUI.rebuild() end })
	UIKit.label(bar, { Size = UDim2.fromOffset(120, 30), Text = string.format("Page %d / %d  (%d)", hamsterState.Page, pages, #matches), TextSize = UIKit.Type.Caption })
	UIKit.button(bar, { Text = ">", Size = UDim2.fromOffset(40, 30), Color = C.Muted, OnClick = function() hamsterState.Page += 1; AdminUI.rebuild() end })

	local picked = if hamsterState.Picked then HamsterDatabase.ById[hamsterState.Picked] else nil
	local grant = UIKit.frame(parent, { Size = UDim2.new(1, -8, 0, 56), LayoutOrder = 4, BackgroundColor3 = C.Card })
	UIKit.corner(grant, 6)
	UIKit.label(grant, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -300, 1, 0), TextWrapped = true, TextSize = UIKit.Type.Caption,
		Text = string.format("%s  ->  %s", if picked then picked.Name else "(click a hamster)", selected.Name or "(pick a player)") })
	local amount = textBox(grant, "How many", UDim2.fromOffset(70, 30), "1")
	amount.Name = "HamsterAmount"
	amount.Position = UDim2.new(1, -270, 0.5, -15)
	local button = runButton(grant, { Text = "Grant", Size = UDim2.fromOffset(110, 32), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Color = C.Green }, function()
		local id = needPlayer()
		if not id or not picked then
			if id then say("Click a hamster first.", false) end
			return nil, nil
		end
		return "giveHamster", { target = id, hamster = picked.Id, amount = tonumber(amount.Text) or 1 }
	end)
	button.Name = "GrantHamster"
end

local itemState = { Search = "", Picked = nil :: any }

local function itemView(parent: Instance)
	local search = textBox(parent, "Search weapons / gear", UDim2.new(1, -8, 0, 30), itemState.Search)
	search.Name = "ItemSearch"
	search.LayoutOrder = 1
	search.FocusLost:Connect(function()
		itemState.Search = search.Text
		AdminUI.rebuild()
	end)
	local list = UIKit.frame(parent, { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, BackgroundTransparency = 1, Name = "ItemList" })
	UIKit.list(list, Enum.FillDirection.Vertical, 4)
	local needle = string.lower(itemState.Search)
	local order = 0
	for _, def in ItemRegistry.List do
		if needle == "" or string.find(string.lower(def.DisplayName), needle, 1, true) or string.find(string.lower(def.Id), needle, 1, true) then
			order += 1
			local picked = itemState.Picked == def.Id
			local row = UIKit.button(list, { Text = "", Size = UDim2.new(1, 0, 0, 44), Color = if picked then C.Blue else C.Card, LayoutOrder = order, Name = "Item_" .. def.Id,
				OnClick = function() itemState.Picked = def.Id; AdminUI.rebuild() end })
			UIKit.icon(row, def.Icon or "star", { Size = UDim2.fromOffset(32, 32), Position = UDim2.fromOffset(6, 6) })
			UIKit.label(row, { Position = UDim2.fromOffset(46, 2), Size = UDim2.new(1, -56, 0, 20), Text = def.DisplayName, Font = UIKit.Fonts.Title, TextSize = UIKit.Type.Body })
			UIKit.label(row, { Position = UDim2.fromOffset(46, 22), Size = UDim2.new(1, -56, 0, 18), TextColor3 = if picked then C.White else C.Muted, TextSize = 11,
				Text = string.format("%s  -  %s  -  rebirth %d", tostring(def.Category), tostring(def.Equip and def.Equip.Kind or ""), def.MinRebirth or 0) })
		end
	end
	local pickedDef = if itemState.Picked then ItemRegistry.get(itemState.Picked) else nil
	local grant = UIKit.frame(parent, { Size = UDim2.new(1, -8, 0, 56), LayoutOrder = 3, BackgroundColor3 = C.Card })
	UIKit.corner(grant, 6)
	UIKit.label(grant, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -150, 1, 0), TextWrapped = true, TextSize = UIKit.Type.Caption,
		Text = string.format("%s  ->  %s", if pickedDef then pickedDef.DisplayName else "(click an item)", selected.Name or "(pick a player)") })
	local button = runButton(grant, { Text = "Grant", Size = UDim2.fromOffset(110, 32), Position = UDim2.new(1, -10, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Color = C.Green }, function()
		local id = needPlayer()
		if not id or not pickedDef then
			if id then say("Click an item first.", false) end
			return nil, nil
		end
		return "grantItem", { target = id, item = pickedDef.Id }
	end)
	button.Name = "GrantItem"
end

-- Bases tab: the selected player's gate (lasers), the hamsters placed on the bench and everything they own.
local baseState = { UserId = nil :: number?, Snapshot = nil :: any, Reason = "" }

local function basesView(parent: Instance)
	if not selected.UserId then
		UIKit.label(parent, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 1, Text = "Pick a player on the left to inspect their base.", TextColor3 = C.Muted, TextSize = UIKit.Type.Caption, TextWrapped = true })
		return
	end
	if baseState.UserId ~= selected.UserId then
		baseState.UserId, baseState.Snapshot = selected.UserId, nil
		local result = call("run", "baseInfo", { target = selected.UserId }, false)
		if result and result.ok then
			baseState.Snapshot = result.data
		else
			say(if result then result.msg or "Could not load that base" else "No answer from the server", false)
		end
	end
	local snapshot = baseState.Snapshot
	if not snapshot then
		UIKit.label(parent, { Size = UDim2.new(1, -8, 0, 40), LayoutOrder = 1, Text = "That base could not be loaded (is the player still in this server?).", TextColor3 = C.Muted, TextSize = UIKit.Type.Caption, TextWrapped = true })
		return
	end
	-- the server only sends the commands this role may run, so a missing command means a hidden button
	local function have(commandName: string): boolean
		for _, command in data.Commands do
			if command.Name == commandName then
				return true
			end
		end
		return false
	end
	local function after(result: any)
		if result and result.ok and result.data then
			baseState.Snapshot = result.data
			AdminUI.rebuild()
		end
	end

	local gate = snapshot.Gate
	local head = UIKit.frame(parent, { Size = UDim2.new(1, -8, 0, 92), LayoutOrder = 1, BackgroundColor3 = C.Card, Name = "BaseHeader" })
	UIKit.corner(head, 6)
	UIKit.label(head, { Position = UDim2.fromOffset(10, 4), Size = UDim2.new(1, -20, 0, 20), Font = UIKit.Fonts.Title, TextSize = UIKit.Type.Body,
		Text = string.format("%s  -  rebirth %d  -  %d slots  -  $%d  -  %d diamonds", snapshot.DisplayName or snapshot.Name, snapshot.Rebirths, snapshot.Slots, snapshot.Coins, snapshot.Gems) })
	UIKit.label(head, { Position = UDim2.fromOffset(10, 26), Size = UDim2.new(1, -20, 0, 18), TextSize = UIKit.Type.Caption, Name = "GateLine", TextColor3 = C.Muted,
		Text = if gate.State == "None" then "Gate: no base right now" else string.format("Gate / lasers: %s%s%s", gate.State,
			if gate.ActiveFor > 0 then string.format("  (on for %ds)", gate.ActiveFor) else "", if gate.ReadyIn > 0 then string.format("  (ready in %ds)", gate.ReadyIn) else "") })
	local reason = textBox(head, "Reason (required for actions)", UDim2.new(1, -20, 0, 26), baseState.Reason)
	reason.Name = "BaseReason"
	reason.Position = UDim2.fromOffset(10, 62)
	reason.FocusLost:Connect(function()
		baseState.Reason = reason.Text
	end)

	local controls = UIKit.frame(parent, { Size = UDim2.new(1, -8, 0, 36), LayoutOrder = 2, BackgroundTransparency = 1, Name = "LaserButtons" })
	UIKit.list(controls, Enum.FillDirection.Horizontal, 6)
	if have("baseSecurity") then
		for _, mode in { { "on", "Lasers ON", C.Green }, { "off", "Lasers OFF", C.Red }, { "reset", "Reset timers", C.Purple } } do
			local button = runButton(controls, { Text = mode[2], Size = UDim2.fromOffset(130, 32), Color = mode[3] }, function()
				return "baseSecurity", { target = selected.UserId, mode = mode[1], reason = reason.Text }
			end, after)
			button.Name = "Lasers_" .. mode[1]
		end
	end

	sectionTitle(parent, string.format("PLACED ON THE BENCH (%d of %d slots)", #snapshot.Bench, snapshot.Slots), 3)
	local bench = UIKit.frame(parent, { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 4, BackgroundTransparency = 1, Name = "BenchList" })
	UIKit.list(bench, Enum.FillDirection.Vertical, 4)
	if #snapshot.Bench == 0 then
		UIKit.label(bench, { Size = UDim2.new(1, 0, 0, 24), Text = "Nothing is placed.", TextColor3 = C.Muted, TextSize = UIKit.Type.Caption })
	end
	for index, row in snapshot.Bench do
		local line = UIKit.frame(bench, { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = index, BackgroundColor3 = C.Card, Name = "Bench_" .. row.Id })
		UIKit.corner(line, 6)
		UIKit.label(line, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -160, 1, 0), TextSize = UIKit.Type.Caption, TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format("%s  (%s)  +%s/s  -  %d placed, %d owned%s", row.Name, row.Rarity, tostring(math.floor(row.Income * 10) / 10), row.Placed, row.Owned, if row.Locked > 0 then "  - being stolen" else "") })
		if have("benchRemove") then
			local button = runButton(line, { Text = "Take off bench", Size = UDim2.fromOffset(130, 28), Position = UDim2.new(1, -6, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Color = C.Blue }, function()
				return "benchRemove", { target = selected.UserId, hamster = row.Id, reason = reason.Text }
			end, after)
			button.Name = "TakeOff_" .. row.Id
		end
	end

	sectionTitle(parent, string.format("OWNED (%d kinds)", #snapshot.Owned), 5)
	local owned = UIKit.frame(parent, { Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 6, BackgroundTransparency = 1, Name = "OwnedList" })
	UIKit.list(owned, Enum.FillDirection.Vertical, 4)
	for index, row in snapshot.Owned do
		local line = UIKit.frame(owned, { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = index, BackgroundColor3 = C.Card, Name = "Owned_" .. row.Id })
		UIKit.corner(line, 6)
		UIKit.label(line, { Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -160, 1, 0), TextSize = UIKit.Type.Caption, TextXAlignment = Enum.TextXAlignment.Left,
			Text = string.format("%s  (%s)  x%d  -  %d placed", row.Name, row.Rarity, row.Owned, row.Placed) })
		if have("hamsterRemove") then
			local button = runButton(line, { Text = "Delete 1", Size = UDim2.fromOffset(130, 28), Position = UDim2.new(1, -6, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Color = C.Red }, function()
				return "hamsterRemove", { target = selected.UserId, hamster = row.Id, amount = 1, reason = reason.Text }
			end, after)
			button.Name = "Delete_" .. row.Id
		end
	end
end

-- tabs this person may use (computed from what the server sent)
function AdminUI.tabList(): { any }
	local tabs = { { Id = "Dashboard", Text = "Dashboard" } }
	local have: { [string]: boolean } = {}
	for _, command in data.Commands do
		have[command.Category] = true
	end
	local function add(id: string, text: string?, condition: boolean?)
		if condition ~= false then
			table.insert(tabs, { Id = id, Text = text or id })
		end
	end
	add("Players", "Players", have.Players)
	add("Roles", "Roles", data.Roles ~= nil)
	add("Moderation", "Moderation", have.Moderation)
	add("Economy", "Economy", have.Economy)
	add("Bases", "Bases", have.Bases)
	add("Hamsters", "Hamsters", have.Hamsters)
	add("Items", "Weapons & gear", have.Items)
	add("Game", "Game", have.Game)
	add("Settings", "Settings", have.Settings)
	add("Logs", "Logs", have.Logs)
	return tabs
end

local SKIP_CARDS = { Bases = { baseInfo = true, baseSecurity = true, benchRemove = true, hamsterRemove = true }, Hamsters = { giveHamster = true }, Items = { grantItem = true }, Roles = { setStaff = true, saveRole = true, deleteRole = true } }

local function showCategory(name: string)
	category = name
	if not content then
		return
	end
	for _, child in content:GetChildren() do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
	userIdBoxes = {}
	if name == "Dashboard" then
		dashboardView(content)
		return
	elseif name == "Settings" then
		settingsView(content)
		return
	elseif name == "Roles" then
		rolesView(content)
		return
	elseif name == "Bases" then
		basesView(content)
		return
	elseif name == "Hamsters" then
		hamsterView(content)
	elseif name == "Items" then
		itemView(content)
	end
	local order = 10
	for _, command in data.Commands do
		if command.Category == name and not (SKIP_CARDS[name] and SKIP_CARDS[name][command.Name]) then
			order += 1
			commandCard(content, command, order)
		end
	end
end

function AdminUI.rebuild()
	if content and data then
		showCategory(category)
	end
end

local function build()
	local body = panel.Body
	for _, child in body:GetChildren() do
		child:Destroy()
	end
	-- left column: search, list, selected player, username lookup
	UIKit.label(body, { Size = UDim2.fromOffset(230, 20), Text = "PLAYERS IN THIS SERVER", Font = UIKit.Fonts.Title, TextSize = UIKit.Type.Caption, TextColor3 = C.Muted })
	local search = textBox(body, "Search name or display name", UDim2.fromOffset(230, 28), searchText)
	search.Name = "PlayerSearch"
	search.Position = UDim2.fromOffset(0, 22)
	search:GetPropertyChangedSignal("Text"):Connect(function()
		searchText = search.Text
		fillPlayers()
	end)
	local list = UIKit.scroll(body, { Size = UDim2.fromOffset(230, 230), Position = UDim2.fromOffset(0, 54) })
	UIKit.list(list, Enum.FillDirection.Vertical, 4)
	playerList = list
	local card = UIKit.frame(body, { Position = UDim2.fromOffset(0, 290), Size = UDim2.fromOffset(230, 62), BackgroundColor3 = C.Card, Name = "SelectedPlayer" })
	UIKit.corner(card, 6)
	selectedCard = card
	local nameBox = textBox(body, "or find a username (offline too)", UDim2.fromOffset(230, 28))
	nameBox.Name = "UsernameLookup"
	nameBox.Position = UDim2.fromOffset(0, 360)
	UIKit.button(body, { Text = "Find username", Size = UDim2.fromOffset(230, 28), Position = UDim2.fromOffset(0, 392), Color = C.Blue, TextSize = UIKit.Type.Caption,
		OnClick = function()
			local result = call("lookup", nameBox.Text)
			if result and result.ok then
				choose(result.UserId, result.Name, result.Name, nil)
				fillPlayers()
				say("Found " .. result.Name .. " (" .. result.UserId .. ")", true)
			else
				say(if result then result.msg or "Not found" else "No answer from the server", false)
			end
		end })
	UIKit.button(body, { Text = "Refresh players", Size = UDim2.fromOffset(230, 28), Position = UDim2.fromOffset(0, 424), Color = C.Muted, TextSize = UIKit.Type.Caption, OnClick = function() reopen() end })
	UIKit.label(body, { Position = UDim2.fromOffset(0, 458), Size = UDim2.fromOffset(230, 40), Text = "You are: " .. tostring(data.Role), TextSize = UIKit.Type.Caption, TextColor3 = C.Muted })
	fillPlayers()
	renderSelected()

	-- middle: sections (only the ones this role may use)
	local tabs = AdminUI.tabList()
	local ids = {}
	for _, tab in tabs do
		ids[tab.Id] = true
	end
	if not ids[category] then
		category = "Dashboard"
	end
	tabsApi = UIKit.tabs(body, tabs, showCategory, { Position = UDim2.fromOffset(242, 0), Size = UDim2.fromOffset(130, 460), ButtonSize = UDim2.fromOffset(130, 34), Vertical = true })

	-- right: content + result line
	local right = UIKit.frame(body, { Position = UDim2.fromOffset(384, 0), Size = UDim2.new(1, -384, 1, 0), BackgroundTransparency = 1 })
	local scroll = UIKit.scroll(right, { Size = UDim2.new(1, 0, 1, -44), Position = UDim2.fromOffset(0, 0) })
	content = scroll :: any
	UIKit.list(scroll, Enum.FillDirection.Vertical, 8)
	resultLabel = UIKit.label(right, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 1, -40), Text = "", TextWrapped = true, TextSize = UIKit.Type.Caption, TextYAlignment = Enum.TextYAlignment.Top })
	tabsApi.Select(category)
end

-- Asks the server to open the panel. Silent for everybody who is not staff.
function AdminUI.open(refresh: boolean?)
	if opening then
		return
	end
	opening = true
	local result = call("open")
	opening = false
	if not result or not result.ok then
		return -- not staff (or server busy): no message, no sound, no hint that a panel exists
	end
	data = result.data
	if not panel then
		panel = UIKit.panel({ Name = "Admin", Title = "Staff Panel", Icon = "gear", Design = Vector2.new(1100, 600), Accent = Theme.Accents.Admin })
	end
	build()
	if not panel.IsOpen then
		UIKit.closeAll("Admin")
		panel:Open()
	end
end

function AdminUI.toggle()
	if panel and panel.IsOpen then
		panel:Close()
	else
		AdminUI.open()
	end
end

function AdminUI.start()
	-- the player list follows joins and leaves while the panel is open
	local function playersChanged()
		if panel and panel.IsOpen and data then
			task.delay(0.4, function()
				if panel.IsOpen then
					local result = call("open")
					if result and result.ok then
						data = result.data
						fillPlayers()
					end
				end
			end)
		end
	end
	Players.PlayerAdded:Connect(playersChanged)
	Players.PlayerRemoving:Connect(playersChanged)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		if input.KeyCode == Enum.KeyCode[InputConfig.Bindings.Admin] then
			AdminUI.toggle()
		end
	end)
	-- /admin in the chat (TextChatService). Only asks the server, like the key.
	pcall(function()
		local command = Instance.new("TextChatCommand")
		command.Name = "AdminPanelCommand"
		command.PrimaryAlias = "/admin"
		command.Parent = TextChatService
		command.Triggered:Connect(function()
			AdminUI.toggle()
		end)
	end)
end

return AdminUI
