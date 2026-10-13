--[[
	AdminUI: the staff panel. There is NO button for it anywhere on the HUD.

	How it opens: the key in InputConfig.Bindings.Admin (default F10) or the chat command /admin. Both only ask the server
	(Remotes "Admin" -> "open"). A normal player gets no answer at all, so nothing happens and nothing is revealed. The server
	answers staff with the list of commands THEIR role may run; this file builds its forms from that list, so it never needs
	to know a UserId, a role name or a permission. Every button press is checked again on the server.

	This panel is a developer tool and is generated in code on purpose (it is not part of the player HUD you restyle in Studio).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local InputConfig = require(Modules:WaitForChild("InputConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local AdminUI = {}

local C = UIKit.Colors
local panel: any = nil
local data: any = nil
local selected: { UserId: number?, Name: string? } = {}
local selectedLabel: TextLabel? = nil
local resultLabel: TextLabel? = nil
local content: Frame? = nil
local userIdBoxes: { TextBox } = {}
local category = "Moderation"
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
	if name == "Settings" then
		settingsView(content)
		return
	end
	local order = 0
	for _, command in data.Commands do
		if command.Category == name then
			order += 1
			commandCard(content, command, order)
		end
	end
end

local function choose(userId: number?, name: string?)
	selected.UserId, selected.Name = userId, name
	if selectedLabel then
		selectedLabel.Text = if name then string.format("Selected: <b>%s</b> (%d)", name, userId :: number) else "Selected: nobody"
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

local function build()
	local body = panel.Body
	for _, child in body:GetChildren() do
		child:Destroy()
	end
	-- left: online players
	UIKit.label(body, { Size = UDim2.fromOffset(210, 22), Text = "ONLINE PLAYERS", Font = UIKit.Fonts.Title, TextSize = UIKit.Type.Caption, TextColor3 = C.Muted })
	local list = UIKit.scroll(body, { Size = UDim2.fromOffset(210, 330), Position = UDim2.fromOffset(0, 24) })
	UIKit.list(list, Enum.FillDirection.Vertical, 4)
	for _, entry in data.Players do
		UIKit.button(list, {
			Text = entry.Name .. (if entry.Role then "  [" .. entry.Role .. "]" else ""),
			Size = UDim2.new(1, -8, 0, 30),
			Color = C.Card,
			TextColor = C.Ink,
			TextSize = UIKit.Type.Caption,
			OnClick = function() choose(entry.UserId, entry.Name) end,
		})
	end
	selectedLabel = UIKit.label(body, { Position = UDim2.fromOffset(0, 360), Size = UDim2.fromOffset(210, 22), Text = "Selected: nobody", TextSize = UIKit.Type.Caption })
	local idBox = textBox(body, "or type a UserId", UDim2.fromOffset(210, 28))
	idBox.Position = UDim2.fromOffset(0, 386)
	idBox.FocusLost:Connect(function()
		local id = tonumber(idBox.Text)
		if id then
			choose(id, "UserId " .. id)
		end
	end)
	UIKit.button(body, { Text = "Refresh", Size = UDim2.fromOffset(210, 28), Position = UDim2.fromOffset(0, 422), Color = C.Muted, TextSize = UIKit.Type.Caption, OnClick = function() AdminUI.open(true) end })
	UIKit.label(body, { Position = UDim2.fromOffset(0, 456), Size = UDim2.fromOffset(210, 40), Text = "Role: " .. tostring(data.Role), TextSize = UIKit.Type.Caption, TextColor3 = C.Muted })

	-- right: categories
	local categories, seen = {}, {}
	for _, command in data.Commands do
		if not seen[command.Category] then
			seen[command.Category] = true
			table.insert(categories, { Id = command.Category, Text = command.Category })
		end
	end
	local right = UIKit.frame(body, { Position = UDim2.fromOffset(226, 0), Size = UDim2.new(1, -226, 1, 0), BackgroundTransparency = 1 })
	local first = if seen[category] then category else (categories[1] and categories[1].Id) or "Moderation"
	local tabs = UIKit.tabs(right, categories, showCategory, { Size = UDim2.new(1, 0, 0, 36) })
	local scroll = UIKit.scroll(right, { Size = UDim2.new(1, 0, 1, -84), Position = UDim2.fromOffset(0, 42) })
	content = scroll :: any
	UIKit.list(scroll, Enum.FillDirection.Vertical, 8)
	resultLabel = UIKit.label(right, { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.new(0, 0, 1, -40), Text = "", TextWrapped = true, TextSize = UIKit.Type.Caption, TextYAlignment = Enum.TextYAlignment.Top })
	tabs.Select(first)
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
		panel = UIKit.panel({ Name = "Admin", Title = "Staff Panel", Icon = "gear", Design = Vector2.new(860, 560), Accent = Theme.Accents.Admin })
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
