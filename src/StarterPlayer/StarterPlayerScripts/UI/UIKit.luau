--[[
	UIKit: the building blocks of the Hamster Plaza interface.
	Art direction: mature dark graphite (see Theme.luau) - flat graphite windows with a thin bronze edge, a header bar with
	a small close button, restrained rarity-coloured accents, high-contrast text, drawn icons (no emoji).
	Windows are designed at a fixed pixel size and scaled to fit any screen (phone to 4K).
	Function names such as `cartoon` / `vivid` are historical: they still exist so every panel keeps working, but they now draw the dark style.
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local HamsterBuilder = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("HamsterBuilder"))

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local CursorController = require(script.Parent.Parent.Controllers.CursorController)
local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)

local UIKit = {}

local player = Players.LocalPlayer

local T = Theme.Colors
UIKit.Colors = {
	-- surfaces (names kept from the first UI generation; the values come from Theme)
	Cream = T.Window, -- window background
	CreamDark = T.Inset, -- inset / inactive
	Card = T.Card, -- cards and rows
	CardHover = T.CardHover,
	Brown = T.Bronze, -- header / primary accent
	BrownDark = T.TextDark, -- outlines, text on bright colours
	BrownLight = T.Line,
	-- text
	Ink = T.Text,
	Muted = T.TextMuted,
	-- borders
	Line = T.Line,
	GoldLine = T.GoldDark,
	-- accents
	Peach = T.Bronze,
	Pink = T.Rose,
	Mint = T.Teal,
	Sky = T.Blue,
	Blue = T.Blue,
	Teal = T.Teal,
	Gold = T.Gold,
	GoldDark = T.GoldDark,
	Green = T.Green,
	Red = T.Red,
	Purple = T.Purple,
	Cash = T.Cash,
	White = Color3.new(1, 1, 1),
	Dim = T.Scrim,
}

UIKit.Fonts = Theme.Fonts
UIKit.Type = Theme.Type

local C = UIKit.Colors

---------------------------------------------------------------------------
-- tiny helpers
---------------------------------------------------------------------------

---------------------------------------------------------------------------
-- Studio-editable HUD: "templates" (StarterGui) and how the code adopts them
--
-- The HUD ScreenGuis (MainUI, HotbarUI) exist as real instances in StarterGui (src/StarterGui/*.model.json, produced by
-- tools/SimTests/bake_hud.sh from this very code). When a template exists in PlayerGui, UIKit.new does NOT create a second
-- copy: it hands back the template instance and applies the code's properties ONLY to the properties you have not changed.
--   * you moved / resized / recoloured / retexted something in Studio  -> your value stays
--   * you did not touch a property                                      -> the code still sets it (touch sizes, theme, state colours)
-- Every baked instance carries the attribute CodeProps = the values the code gave it when baked; "you changed it" simply means
-- the current value no longer equals that baked value. (Do not rename or delete template instances: hide them with Visible = false.)
---------------------------------------------------------------------------

local adopting: { [ScreenGui]: boolean } = {}
local consumed: { [Instance]: boolean } = {}

-- A text fingerprint of a property value, to find out whether it was changed since baking.
local function whole(n: number): number
	return if n >= 0 then math.floor(n) else math.ceil(n) -- UDim offsets are whole numbers in Roblox
end

local function fingerprint(value: any): string
	local kind = typeof(value)
	if kind == "number" then
		return string.format("%.3f", value)
	elseif kind == "string" or kind == "boolean" then
		return tostring(value)
	elseif kind == "UDim2" then
		return string.format("u2:%.3f,%d,%.3f,%d", value.X.Scale, whole(value.X.Offset), value.Y.Scale, whole(value.Y.Offset))
	elseif kind == "Vector2" then
		return string.format("v2:%.3f,%.3f", value.X, value.Y)
	elseif kind == "Color3" then
		return string.format("c3:%.3f,%.3f,%.3f", value.R, value.G, value.B)
	elseif kind == "EnumItem" then
		return "e:" .. value.Name
	elseif kind == "table" or kind == "userdata" or kind == "UDim" then
		if value.Scale ~= nil and value.Offset ~= nil then
			return string.format("u:%.3f,%d", value.Scale, whole(value.Offset))
		elseif value.EnumType ~= nil and value.Name ~= nil then
			return "e:" .. value.Name
		elseif value.Keypoints ~= nil then
			local parts = {}
			for _, key in value.Keypoints do
				local inner = key.Value
				table.insert(parts, string.format("%.3f=%s", key.Time, if typeof(inner) == "Color3" then fingerprint(inner) else tostring(inner)))
			end
			return "seq:" .. table.concat(parts, "|")
		end
	elseif kind == "ColorSequence" then
		local parts = {}
		for _, key in value.Keypoints do
			table.insert(parts, string.format("%.3f=%s", key.Time, fingerprint(key.Value)))
		end
		return "seq:" .. table.concat(parts, "|")
	end
	return tostring(value)
end

local function isBaking(): boolean
	return ReplicatedStorage:GetAttribute("HudBake") == true
end

local function adoptionRoot(parent: Instance?): ScreenGui?
	local node = parent
	while node do
		if node:IsA("ScreenGui") then
			return if adopting[node] then node else nil
		end
		node = node.Parent
	end
	return nil
end

-- The first template child of `parent` that fits (same class, and the same Name when the code names it) and was not used yet.
local function findTemplate(parent: Instance, className: string, name: string?): Instance?
	for _, child in parent:GetChildren() do
		if not consumed[child] and child.ClassName == className and (name == nil or child.Name == name) then
			return child
		end
	end
	return nil
end

local function parseCodeProps(instance: Instance): { [string]: string }
	local text = instance:GetAttribute("CodeProps")
	local result = {}
	if type(text) == "string" then
		for line in string.gmatch(text, "[^\n]+") do
			local key, value = string.match(line, "^([%w_]+)=(.*)$")
			if key then
				result[key] = value
			end
		end
	end
	return result
end

-- Applies the code's properties to a template instance, keeping everything the user changed in Studio.
local function mergeProps(instance: Instance, props: { [string]: any }?)
	if not props then
		return
	end
	local baked = parseCodeProps(instance)
	for key, value in props do
		if key ~= "Name" then
			local ok, current = pcall(function()
				return (instance :: any)[key]
			end)
			local original = baked[key]
			if ok and (original == nil or fingerprint(current) == original) then
				pcall(function()
					(instance :: any)[key] = value
				end)
			end
		end
	end
end

-- Baking, step 1: remember WHICH properties the code sets on this instance (their values are fingerprinted at the end, see sealBake).
local function recordCodeProps(instance: Instance, props: { [string]: any }?)
	if not props then
		return
	end
	local keys = {}
	for key in props do
		if key ~= "Name" and key ~= "Parent" then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	if #keys > 0 then
		instance:SetAttribute("CodeKeys", table.concat(keys, ","))
	end
end

-- Baking, step 2 (tools/SimTests/bake_hud.sh): turn the recorded keys into CodeProps = the value each of those properties has
-- NOW, after the code finished building (responsive sizes, state colours ...). "Unchanged by the user" means "still equal to this".
function UIKit.sealBake(root: Instance)
	local function seal(instance: Instance)
		local keys = instance:GetAttribute("CodeKeys")
		if type(keys) == "string" then
			local lines = {}
			for key in string.gmatch(keys, "[^,]+") do
				local ok, current = pcall(function()
					return (instance :: any)[key]
				end)
				if ok then
					table.insert(lines, key .. "=" .. fingerprint(current))
				end
			end
			instance:SetAttribute("CodeProps", table.concat(lines, "\n"))
			instance:SetAttribute("CodeKeys", nil)
		end
	end
	seal(root)
	for _, descendant in root:GetDescendants() do
		seal(descendant)
	end
end

function UIKit.new(className: string, props: { [string]: any }?, parent: Instance?): any
	if parent then
		local root = adoptionRoot(parent)
		if root then
			local template = findTemplate(parent, className, if props then props.Name else nil)
			if template then
				consumed[template] = true
				mergeProps(template, props)
				return template
			end
		end
	end
	local instance = Instance.new(className)
	if props then
		for key, value in props do
			(instance :: any)[key] = value
		end
	end
	if isBaking() then
		recordCodeProps(instance, props)
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

-- Called once, after every HUD module has built what it builds at start-up. From now on elements are created normally, and baked
-- template instances nobody claimed (leftovers of an older version of the HUD) are removed so they can not show up twice.
function UIKit.finishAdoptAll()
	for gui in adopting do
		local orphans = {}
		for _, descendant in gui:GetDescendants() do
			if not consumed[descendant] and descendant:GetAttribute("CodeProps") ~= nil and descendant:IsA("GuiObject") then
				table.insert(orphans, descendant) -- (layout / corner / stroke helpers are left alone: they cannot show up twice)
			end
		end
		for _, orphan in orphans do
			orphan:Destroy()
		end
		if #orphans > 0 then
			warn(string.format("[UIKit] %s: removed %d template instance(s) that the code does not use any more. Re-run tools/SimTests/bake_hud.sh to refresh the templates.", gui.Name, #orphans))
		end
		gui:SetAttribute("Adopted", true)
	end
	table.clear(adopting)
	table.clear(consumed)
end

-- One restrained corner language: everything is 6-8 px; only true circles / pills (radius >= 50) stay round.
function UIKit.corner(parent: Instance, radius: number?): UICorner
	local r = radius or Theme.Radius.Card
	if r < 50 then
		r = math.clamp(r, 4, Theme.Radius.Window)
	end
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end

function UIKit.stroke(parent: Instance, color: Color3, thickness: number?, transparency: number?): UIStroke
	return UIKit.new("UIStroke", {
		Color = color,
		Thickness = math.min(thickness or 1, 1.5), -- hairlines only: thick outlines are what made every panel look the same
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

function UIKit.padding(parent: Instance, all: number, vertical: number?): UIPadding
	return UIKit.new("UIPadding", {
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, all),
		PaddingTop = UDim.new(0, vertical or all),
		PaddingBottom = UDim.new(0, vertical or all),
	}, parent)
end

function UIKit.list(parent: Instance, direction: Enum.FillDirection?, gap: number?, horizontal: Enum.HorizontalAlignment?, vertical: Enum.VerticalAlignment?): UIListLayout
	return UIKit.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, gap or 6),
		HorizontalAlignment = horizontal or Enum.HorizontalAlignment.Left,
		VerticalAlignment = vertical or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, parent)
end

function UIKit.gradient(parent: Instance, top: Color3, bottom: Color3, rotation: number?): UIGradient
	return UIKit.new("UIGradient", { Color = ColorSequence.new(top, bottom), Rotation = rotation or 90 }, parent)
end

function UIKit.tween(instance: Instance, duration: number, props: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(instance, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), props)
	tween:Play()
	return tween
end

-- Drawn icon (no emoji): UIKit.icon(parent, "coin", { Size = UDim2.fromOffset(28, 28) })
function UIKit.icon(parent: Instance?, id: string, props: { Size: UDim2?, Position: UDim2?, AnchorPoint: Vector2?, Color: Color3?, ZIndex: number?, LayoutOrder: number?, Name: string? }?): Frame
	if parent and adoptionRoot(parent) then
		-- a template keeps the icon's root frame (position, size ...); the artwork is always drawn by the code
		local template = findTemplate(parent, "Frame", (props and props.Name) or ("Icon_" .. id))
		if template and template:GetAttribute("IconId") == id then
			consumed[template] = true
			local opts = props or {}
			mergeProps(template, { Size = opts.Size or UDim2.fromOffset(28, 28), Position = opts.Position or UDim2.new(), AnchorPoint = opts.AnchorPoint or Vector2.zero, LayoutOrder = opts.LayoutOrder or 0, ZIndex = opts.ZIndex or 1 })
			template:ClearAllChildren()
			local ratio = Instance.new("UIAspectRatioConstraint")
			ratio.AspectRatio = 1
			ratio.Parent = template
			local size = opts.Size or UDim2.fromOffset(28, 28)
			Icons.fill(template :: Frame, id, opts.Color, if size.X.Offset > 0 then size.X.Offset else 28)
			return template :: Frame
		end
	end
	local icon = Icons.create(parent, id, props)
	if isBaking() then
		local opts = props or {}
		recordCodeProps(icon, { Size = opts.Size or UDim2.fromOffset(28, 28), Position = opts.Position or UDim2.new(), AnchorPoint = opts.AnchorPoint or Vector2.zero, LayoutOrder = opts.LayoutOrder or 0, ZIndex = opts.ZIndex or 1 })
	end
	return icon
end

-- A drawn icon followed by text on one line (replaces "coin 12K" emoji strings).
export type IconText = { Frame: Frame, Label: TextLabel, Icon: Frame?, Set: (text: string, iconId: string?) -> () }

function UIKit.iconText(parent: Instance?, props: { Icon: string?, Text: string?, Size: UDim2?, Position: UDim2?, AnchorPoint: Vector2?, TextSize: number?, TextColor: Color3?, Font: Enum.Font?, Align: Enum.HorizontalAlignment?, LayoutOrder: number?, ZIndex: number? }): IconText
	local textSize = props.TextSize or 16
	local frame = UIKit.frame(parent, {
		Size = props.Size or UDim2.fromOffset(120, textSize + 8),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundTransparency = 1,
		LayoutOrder = props.LayoutOrder or 0,
		ZIndex = props.ZIndex or 1,
	})
	UIKit.list(frame, Enum.FillDirection.Horizontal, 5, props.Align or Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center)
	local label = UIKit.label(frame, {
		Size = UDim2.fromOffset(0, textSize + 6),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = props.Text or "",
		TextSize = textSize,
		TextColor3 = props.TextColor or C.Ink,
		Font = props.Font or UIKit.Fonts.Title,
		LayoutOrder = 2,
		ZIndex = props.ZIndex or 1,
	})
	local result: IconText = { Frame = frame, Label = label, Icon = nil, Set = nil :: any }
	local function setIcon(id: string?)
		if result.Icon then
			result.Icon:Destroy()
			result.Icon = nil
		end
		if id then
			result.Icon = UIKit.icon(frame, id, { Size = UDim2.fromOffset(textSize + 6, textSize + 6), LayoutOrder = 1, ZIndex = props.ZIndex })
		end
	end
	setIcon(props.Icon)
	result.Set = function(text: string, iconId: string?)
		label.Text = text
		if iconId then
			setIcon(iconId)
		end
	end
	return result
end

-- Puts "icon + text" in the middle of a button (the button's own Text stays empty).
function UIKit.setButtonContent(button: TextButton, iconId: string?, text: string, textColor: Color3?)
	button.Text = ""
	local content = button:FindFirstChild("Content") :: Frame?
	if content then
		content:Destroy()
	end
	local row = UIKit.iconText(button, { Icon = iconId, Text = text, Size = UDim2.fromScale(1, 1), TextSize = (button.TextSize or 18), TextColor = textColor or button.TextColor3, Align = Enum.HorizontalAlignment.Center, ZIndex = 3 })
	row.Frame.Name = "Content"
end

-- Kept for compatibility: UI text is no longer outlined (the old "cartoon" look). Text stays legible through contrast.
function UIKit.cartoon(label: TextLabel | TextButton, _thickness: number?, _color: Color3?)
	local outline = label:FindFirstChild("TextOutline")
	if outline then
		outline:Destroy()
	end
end

local function mix(a: Color3, b: Color3, t: number): Color3
	return a:Lerp(b, t)
end

-- Card with a thin accent edge (flat: no gradient). Call it right after creating the frame (before adding content).
function UIKit.vivid(frame: GuiObject, color: Color3, options: { Outline: number?, Corner: number? }?)
	local opts = options or {}
	frame.BackgroundColor3 = mix(C.Card, color, 0.08)
	frame.BackgroundTransparency = 0
	frame.ClipsDescendants = true
	local existingCorner = frame:FindFirstChildOfClass("UICorner")
	if existingCorner then
		consumed[existingCorner] = true -- (a template already has it)
	else
		UIKit.corner(frame, math.min(opts.Corner or Theme.Radius.Card, 8))
	end
	local edge = UIKit.stroke(frame, mix(color, C.Line, 0.5), math.min(opts.Outline or 1, 2))
	edge.Name = "AccentEdge"
end

function UIKit.frame(parent: Instance?, props: { [string]: any }?): Frame
	local defaults: { [string]: any } = { BackgroundColor3 = C.Card, BorderSizePixel = 0 }
	if props then
		for key, value in props do
			defaults[key] = value
		end
	end
	return UIKit.new("Frame", defaults, parent)
end

function UIKit.label(parent: Instance?, props: { [string]: any }?): TextLabel
	local defaults: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = UIKit.Fonts.Body,
		TextColor3 = C.Ink,
		TextSize = 16,
		Text = "",
		TextXAlignment = Enum.TextXAlignment.Left,
		RichText = true,
		BorderSizePixel = 0,
	}
	if props then
		for key, value in props do
			defaults[key] = value
		end
	end
	return UIKit.new("TextLabel", defaults, parent)
end

function UIKit.isTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

-- Scale factor that fits a fixed design size into the current screen.
function UIKit.fitScale(designSize: Vector2, margin: number?): number
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
	local available = viewport * (margin or 0.94)
	return math.clamp(math.min(available.X / designSize.X, available.Y / designSize.Y), 0.35, 1.25)
end

---------------------------------------------------------------------------
-- screens, safe areas and responsive boxes
---------------------------------------------------------------------------

-- The one way to create a HUD / panel ScreenGui, so every screen follows the same rules:
--   Insets "Topbar"  content starts BELOW the Roblox top bar (and phone notches): HUD, status, toasts
--   Insets "Device"  only the hardware safe area (notch, home indicator): hotbar, bottom prompts
--   Insets "None"    the full screen: modal panels and dimmers
-- `Layer` is a key of Theme.Layers (explicit front-to-back order).
function UIKit.screenGui(name: string, options: { Layer: string?, Insets: string?, Enabled: boolean? }?): ScreenGui
	local opts = options or {}
	local insets = opts.Insets or "None"
	local playerGui = player:WaitForChild("PlayerGui")
	local props: { [string]: any } = {
		Name = name,
		ResetOnSpawn = false,
		DisplayOrder = Theme.Layers[opts.Layer or "Hud"] or Theme.Layers.Hud,
		IgnoreGuiInset = insets ~= "Topbar",
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Enabled = opts.Enabled ~= false,
	}
	-- a Studio template (StarterGui/<name>) is adopted instead of creating a second ScreenGui
	local template = playerGui:FindFirstChild(name)
	if not template and game:GetService("StarterGui"):FindFirstChild(name) then
		template = playerGui:WaitForChild(name, 5)
	end
	local gui: ScreenGui
	if template and template:IsA("ScreenGui") and template:GetAttribute("CodeProps") ~= nil and not isBaking() then
		gui = template
		mergeProps(gui, props)
		consumed[gui] = true
		adopting[gui] = true
	else
		gui = UIKit.new("ScreenGui", props, playerGui)
		if isBaking() then
			recordCodeProps(gui, props)
		end
	end
	gui:SetAttribute("Insets", insets)
	local mode = if insets == "Topbar" then Enum.ScreenInsets.TopbarSafeInsets elseif insets == "Device" then Enum.ScreenInsets.DeviceSafeInsets else Enum.ScreenInsets.None
	pcall(function()
		gui.ScreenInsets = mode
	end)
	return gui
end

-- A positioned, sized element whose CONTENT is scaled with a UIScale.
-- The UIScale lives on an inner frame, never on the positioned one, so the position is exactly what you wrote
-- (a UIScale on a positioned frame also scales its position offset, which is how HUD pieces drift on other
-- resolutions). The wrapper's size is kept equal to design size * scale, so layout and hit-testing stay correct.
--   wrapper  anchored/positioned by you (any UDim2)
--   content  fixed design-size frame; build your UI in here
export type Responsive = { Wrapper: Frame, Content: Frame, Scale: UIScale, Refit: () -> () }
function UIKit.responsive(parent: Instance, props: { Name: string?, Design: Vector2, Position: UDim2?, AnchorPoint: Vector2?, Min: number?, Max: number?, Reference: Vector2?, Visible: boolean?, ZIndex: number? }): Responsive
	local reference = props.Reference or Vector2.new(1180, 660)
	local wrapper = UIKit.new("Frame", {
		Name = props.Name or "Responsive",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		Size = UDim2.fromOffset(props.Design.X, props.Design.Y),
		Visible = props.Visible ~= false,
		ZIndex = props.ZIndex or 1,
	}, parent)
	local content = UIKit.new("Frame", { Name = "Content", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromOffset(props.Design.X, props.Design.Y) }, wrapper)
	local scale = UIKit.new("UIScale", { Scale = 1 }, content)
	local function refit()
		local camera = Workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(1280, 720)
		local value = math.clamp(math.min(viewport.X / reference.X, viewport.Y / reference.Y), props.Min or 0.5, props.Max or 1.1)
		value = math.min(value, viewport.X * 0.96 / props.Design.X) -- never wider than the screen
		scale.Scale = value
		wrapper.Size = UDim2.fromOffset(math.ceil(props.Design.X * value), math.ceil(props.Design.Y * value))
	end
	refit()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(refit)
	end
	wrapper:SetAttribute("Responsive", true)
	return { Wrapper = wrapper, Content = content, Scale = scale, Refit = refit }
end

---------------------------------------------------------------------------
-- buttons
---------------------------------------------------------------------------

export type ButtonProps = {
	Text: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	TextColor: Color3?,
	Font: Enum.Font?,
	TextSize: number?,
	OnClick: (() -> ())?,
	LayoutOrder: number?,
	Name: string?,
	Corner: number?,
	Silent: boolean?,
}

-- Flat button with a subtle gradient, hover (brighten) and press (squash) states and sounds.
function UIKit.button(parent: Instance?, props: ButtonProps): TextButton
	local color = props.Color or C.Peach
	local button = UIKit.new("TextButton", {
		Name = props.Name or "Button",
		AutoButtonColor = false,
		Text = props.Text or "",
		RichText = true,
		Font = props.Font or UIKit.Fonts.Title,
		TextSize = props.TextSize or 16,
		TextColor3 = props.TextColor or C.White,
		BackgroundColor3 = color,
		Size = props.Size or UDim2.fromOffset(120, 40),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		BorderSizePixel = 0,
	}, parent)
	color = button.BackgroundColor3 -- (a Studio-edited template keeps its own colour: hover and press build on that one)
	UIKit.corner(button, props.Corner or Theme.Radius.Button)
	-- flat surface, one hairline edge, no gradient and no outlined text: the hover/press feedback does the talking
	local stroke = UIKit.stroke(button, mix(color, Color3.new(0, 0, 0), 0.45), 1)
	local scale = UIKit.new("UIScale", { Scale = 1 }, button)
	button:SetAttribute("BaseColor", color)

	local hovering = false
	button.MouseEnter:Connect(function()
		if button:GetAttribute("Disabled") then
			return
		end
		hovering = true
		UIKit.tween(scale, Theme.Motion.Hover, { Scale = 1.02 })
		UIKit.tween(button, Theme.Motion.Hover, { BackgroundColor3 = mix(button:GetAttribute("BaseColor") or color, Color3.new(1, 1, 1), 0.12) })
		if not props.Silent then
			AudioController.play("Hover")
		end
	end)
	button.MouseLeave:Connect(function()
		hovering = false
		UIKit.tween(scale, Theme.Motion.Hover, { Scale = 1 })
		if not button:GetAttribute("Disabled") then
			UIKit.tween(button, Theme.Motion.Hover, { BackgroundColor3 = button:GetAttribute("BaseColor") or color })
		end
	end)
	button.MouseButton1Down:Connect(function()
		if not button:GetAttribute("Disabled") then
			UIKit.tween(scale, 0.06, { Scale = 0.97 })
		end
	end)
	button.MouseButton1Up:Connect(function()
		UIKit.tween(scale, 0.1, { Scale = if hovering then 1.02 else 1 })
	end)
	button.Activated:Connect(function()
		if button:GetAttribute("Disabled") then
			AudioController.play("Error")
			return
		end
		if not props.Silent then
			AudioController.play("Click")
		end
		if props.OnClick then
			props.OnClick()
		end
	end)
	stroke.Name = "Edge"
	return button
end

function UIKit.setEnabled(button: TextButton, enabled: boolean)
	button:SetAttribute("Disabled", not enabled)
	local base = button:GetAttribute("BaseColor") or C.Peach
	button.BackgroundColor3 = if enabled then base else Color3.fromRGB(64, 67, 77)
	button.TextTransparency = if enabled then 0 else 0.35
	local edge = button:FindFirstChild("Edge") :: UIStroke?
	if edge then
		edge.Color = if enabled then mix(base, Color3.new(0, 0, 0), 0.55) else Color3.fromRGB(44, 46, 54)
	end
end

function UIKit.setButtonColor(button: TextButton, color: Color3)
	button:SetAttribute("BaseColor", color)
	if not button:GetAttribute("Disabled") then
		button.BackgroundColor3 = color
		local edge = button:FindFirstChild("Edge") :: UIStroke?
		if edge then
			edge.Color = mix(color, Color3.new(0, 0, 0), 0.55)
		end
	end
end

---------------------------------------------------------------------------
-- progress bar, toggle, slider, tabs, scroll
---------------------------------------------------------------------------

function UIKit.progress(parent: Instance, props: { Size: UDim2?, Position: UDim2?, Color: Color3?, Back: Color3?, AnchorPoint: Vector2?, LayoutOrder: number? }): { Frame: Frame, Fill: Frame, Label: TextLabel, Set: (fraction: number, text: string?) -> () }
	local frame = UIKit.frame(parent, {
		Size = props.Size or UDim2.new(1, 0, 0, 16),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		BackgroundColor3 = props.Back or C.CreamDark,
		LayoutOrder = props.LayoutOrder or 0,
	})
	UIKit.corner(frame, 99)
	UIKit.stroke(frame, C.Line, 1.5)
	local fill = UIKit.frame(frame, { Size = UDim2.fromScale(0, 1), BackgroundColor3 = props.Color or C.Mint })
	UIKit.corner(fill, 99)
	UIKit.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 190, 190)), Rotation = 90 }, fill)
	local label = UIKit.label(frame, {
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextSize = 12,
		TextColor3 = C.White,
		Font = UIKit.Fonts.Body,
		ZIndex = 3,
	})
	UIKit.cartoon(label, 1)
	local function set(fraction: number, text: string?)
		UIKit.tween(fill, 0.25, { Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1) })
		label.Text = text or ""
	end
	return { Frame = frame, Fill = fill, Label = label, Set = set }
end

function UIKit.toggle(parent: Instance, props: { Value: boolean, OnChanged: (boolean) -> (), Position: UDim2?, AnchorPoint: Vector2?, LayoutOrder: number? }): { Button: TextButton, Set: (boolean) -> () }
	local value = props.Value
	local track = UIKit.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Size = UDim2.fromOffset(62, 30),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		BackgroundColor3 = C.CreamDark,
		BorderSizePixel = 0,
	}, parent)
	UIKit.corner(track, 99)
	UIKit.stroke(track, C.Line, 1.5)
	local knob = UIKit.frame(track, { Size = UDim2.fromOffset(22, 22), Position = UDim2.fromOffset(4, 4), BackgroundColor3 = C.White })
	UIKit.corner(knob, 99)
	local function render(animate: boolean)
		local target = if value then UDim2.fromOffset(36, 4) else UDim2.fromOffset(4, 4)
		local color = if value then C.Green else C.CreamDark
		if animate then
			UIKit.tween(knob, 0.14, { Position = target }, Enum.EasingStyle.Back)
			UIKit.tween(track, 0.14, { BackgroundColor3 = color })
		else
			knob.Position = target
			track.BackgroundColor3 = color
		end
	end
	render(false)
	track.Activated:Connect(function()
		value = not value
		AudioController.play("Click")
		render(true)
		props.OnChanged(value)
	end)
	return {
		Button = track,
		Set = function(newValue: boolean)
			value = newValue
			render(true)
		end,
	}
end

function UIKit.slider(parent: Instance, props: { Min: number, Max: number, Value: number, OnChanged: (number) -> (), Size: UDim2?, Position: UDim2?, AnchorPoint: Vector2?, LayoutOrder: number? }): { Frame: Frame, Set: (number) -> () }
	local frame = UIKit.frame(parent, {
		Size = props.Size or UDim2.fromOffset(180, 14),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		LayoutOrder = props.LayoutOrder or 0,
		BackgroundColor3 = C.CreamDark,
	})
	UIKit.corner(frame, 99)
	UIKit.stroke(frame, C.Line, 1.5)
	local fill = UIKit.frame(frame, { BackgroundColor3 = C.Gold, Size = UDim2.fromScale(0, 1) })
	UIKit.corner(fill, 99)
	local knob = UIKit.frame(frame, { Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = C.White, ZIndex = 3 })
	UIKit.corner(knob, 99)
	UIKit.stroke(knob, C.GoldDark, 2)
	local hit = UIKit.new("TextButton", { Text = "", BackgroundTransparency = 1, Size = UDim2.new(1, 20, 0, 40), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) }, frame)

	local value = props.Value
	local function render()
		local fraction = (value - props.Min) / (props.Max - props.Min)
		fill.Size = UDim2.fromScale(fraction, 1)
		knob.Position = UDim2.fromScale(fraction, 0.5)
	end
	render()

	local dragging = false
	local function update(x: number)
		local fraction = math.clamp((x - frame.AbsolutePosition.X) / math.max(frame.AbsoluteSize.X, 1), 0, 1)
		value = props.Min + (props.Max - props.Min) * fraction
		render()
	end
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			update(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			update(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
			dragging = false
			AudioController.play("Click")
			props.OnChanged(value)
		end
	end)
	return {
		Frame = frame,
		Set = function(newValue: number)
			value = newValue
			render()
		end,
	}
end

export type TabDef = { Id: string, Text: string, Color: Color3? }

function UIKit.tabs(parent: Instance, defs: { TabDef }, onSelect: (string) -> (), options: { Size: UDim2?, Position: UDim2?, ButtonSize: UDim2?, Vertical: boolean? }?): { Frame: Frame, Select: (string) -> (), Buttons: { [string]: TextButton }, SetText: (string, string) -> () }
	local opts = options or {}
	local frame = UIKit.frame(parent, {
		Size = opts.Size or UDim2.new(1, 0, 0, 40),
		Position = opts.Position or UDim2.new(),
		BackgroundTransparency = 1,
	})
	UIKit.list(frame, if opts.Vertical then Enum.FillDirection.Vertical else Enum.FillDirection.Horizontal, 6)
	local buttons: { [string]: TextButton } = {}
	local function select(id: string, silent: boolean?)
		for tabId, button in buttons do
			if tabId == id then
				UIKit.setButtonColor(button, C.Peach)
			else
				UIKit.setButtonColor(button, C.Card)
			end
			button.TextColor3 = C.White
		end
		if not silent then
			onSelect(id)
		end
	end

	for index, def in defs do
		local button = UIKit.button(frame, {
			Text = def.Text,
			Size = opts.ButtonSize or UDim2.fromOffset(110, 36),
			Color = C.Card,
			TextColor = C.White,
			TextSize = 14,
			LayoutOrder = index,
			Name = "Tab_" .. def.Id,
			OnClick = function()
				select(def.Id)
			end,
		})
		button:SetAttribute("TabColor", def.Color or C.Brown)
		buttons[def.Id] = button
	end
	return {
		Frame = frame,
		Select = select,
		Buttons = buttons,
		SetText = function(id: string, text: string)
			if buttons[id] then
				buttons[id].Text = text
			end
		end,
	}
end

function UIKit.scroll(parent: Instance, props: { Size: UDim2?, Position: UDim2?, Direction: Enum.FillDirection?, Gap: number? }?): ScrollingFrame
	local opts = props or {}
	local scroll = UIKit.new("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = opts.Size or UDim2.fromScale(1, 1),
		Position = opts.Position or UDim2.new(),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 5,
		ScrollBarImageColor3 = C.Line,
		ScrollingDirection = Enum.ScrollingDirection.Y,
	}, parent)
	return scroll
end

---------------------------------------------------------------------------
-- hamster icons (ViewportFrame snapshots of the real 3D models)
---------------------------------------------------------------------------

function UIKit.hamsterIcon(parent: Instance, species: any, props: { Size: UDim2?, Position: UDim2?, Silhouette: boolean?, AnchorPoint: Vector2?, ZIndex: number?, Spin: boolean? }?): ViewportFrame
	local opts = props or {}
	local viewport = UIKit.new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = opts.Size or UDim2.fromOffset(110, 110),
		Position = opts.Position or UDim2.new(),
		AnchorPoint = opts.AnchorPoint or Vector2.zero,
		LightColor = Color3.fromRGB(255, 244, 224),
		Ambient = Color3.fromRGB(165, 155, 170),
		LightDirection = Vector3.new(-0.5, -1, 0.6),
		ImageColor3 = if opts.Silhouette then Color3.new(0, 0, 0) else Color3.new(1, 1, 1),
		ZIndex = opts.ZIndex or 1,
	}, parent)

	-- a hamster with its own uploaded icon (Content/Hamsters Icon) shows that image instead of a 3D snapshot
	if type(species.Icon) == "string" and species.Icon ~= "" and not opts.Spin then
		local image = UIKit.new("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = species.Icon, ImageColor3 = if opts.Silhouette then Color3.new(0, 0, 0) else Color3.new(1, 1, 1), ScaleType = Enum.ScaleType.Fit }, viewport)
		image.ZIndex = opts.ZIndex or 1
		return viewport
	end

	local model = HamsterBuilder.build(species, { LowDetail = true, Particles = false })
	model:PivotTo(CFrame.new(0, 0, 0))
	model.Parent = viewport
	local camera = Instance.new("Camera")
	local cameraCFrame, fieldOfView = HamsterBuilder.frameCamera(model, 32)
	camera.CFrame = cameraCFrame
	camera.FieldOfView = fieldOfView
	camera.Parent = viewport
	viewport.CurrentCamera = camera

	if opts.Spin then
		local connection
		local angle = 0
		connection = RunService.RenderStepped:Connect(function(dt)
			if not viewport.Parent then
				connection:Disconnect()
				return
			end
			angle += dt * 0.9
			model:PivotTo(CFrame.Angles(0, math.sin(angle) * 0.7, 0))
		end)
	end
	return viewport
end

-- The REAL model of a weapon (the one players hold; published by the server in Assets/WeaponPreviews) in a ViewportFrame.
-- Falls back to the flat icon when no preview exists (for example while the server is still starting).
function UIKit.weaponIcon(parent: Instance, itemId: string, fallbackIcon: string, props: { Size: UDim2?, Position: UDim2?, AnchorPoint: Vector2?, ZIndex: number?, Spin: boolean?, Name: string? }?): GuiObject
	local opts = props or {}
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local previews = assets and assets:FindFirstChild("WeaponPreviews")
	local source = previews and previews:FindFirstChild(itemId)
	if not source or not source:IsA("Model") then
		return UIKit.icon(parent, fallbackIcon, { Size = opts.Size, Position = opts.Position, AnchorPoint = opts.AnchorPoint, ZIndex = opts.ZIndex, Name = opts.Name })
	end
	local viewport = UIKit.new("ViewportFrame", {
		Name = opts.Name or "WeaponPreview",
		BackgroundTransparency = 1,
		Size = opts.Size or UDim2.fromOffset(110, 110),
		Position = opts.Position or UDim2.new(),
		AnchorPoint = opts.AnchorPoint or Vector2.zero,
		LightColor = Color3.fromRGB(255, 244, 224),
		Ambient = Color3.fromRGB(165, 155, 170),
		LightDirection = Vector3.new(-0.5, -1, 0.6),
		ZIndex = opts.ZIndex or 1,
	}, parent)
	viewport:SetAttribute("ItemId", itemId)
	local model = source:Clone()
	model.Parent = viewport
	local boxCFrame, size = model:GetBoundingBox()
	local center = boxCFrame.Position
	local camera = Instance.new("Camera")
	local fov = 30
	local radius = math.max(size.X, size.Y, size.Z) * 0.5
	local distance = radius / math.tan(math.rad(fov / 2)) * 1.2
	camera.FieldOfView = fov
	camera.CFrame = CFrame.lookAt(center + Vector3.new(0.75, 0.45, -1).Unit * distance, center)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	if opts.Spin then
		local base = model:GetPivot()
		local connection
		local angle = 0
		connection = RunService.RenderStepped:Connect(function(dt)
			if not viewport.Parent then
				connection:Disconnect()
				return
			end
			angle += dt * 0.8
			model:PivotTo(CFrame.new(center) * CFrame.Angles(0, math.sin(angle) * 0.9, 0) * CFrame.new(-center) * base)
		end)
	end
	return viewport
end

---------------------------------------------------------------------------
-- panels (windows)
---------------------------------------------------------------------------

export type Panel = {
	Name: string,
	Gui: ScreenGui,
	Window: GuiObject,
	Body: Frame,
	Title: TextLabel,
	IsOpen: boolean,
	Open: (self: Panel) -> (),
	Close: (self: Panel) -> (),
	Toggle: (self: Panel) -> (),
	OnOpen: { () -> () },
	OnClose: { () -> () },
	Focus: string?,
}

local panels: { [string]: Panel } = {}

local OPEN_SECONDS = Theme.Motion.Open
local CLOSE_SECONDS = Theme.Motion.Close

function UIKit.getPanel(name: string): Panel?
	return panels[name]
end

function UIKit.closeAll(except: string?)
	for name, panel in panels do
		if name ~= except and panel.IsOpen then
			panel:Close()
		end
	end
end

-- `Icon` is an Icons id ("book", "gear", ...), never an emoji.
local SUBTITLES = {
	Inventory = "Collect, equip and sell your hamsters",
	Index = "Discover every hamster and earn permanent bonuses",
	Rebirth = "Start over stronger - and grow your tower",
	Upgrades = "Make your hamsters and production stronger",
	Daily = "Come back every day for bigger rewards",
	Quests = "Complete goals to earn rewards",
	Shop = "Boosts, hamsters and exclusive items",
	Settings = "Sound, graphics and gameplay options",
	Codes = "Redeem a code for free rewards",
}

function UIKit.panel(options: { Name: string, Title: string, Subtitle: string?, Icon: string?, Design: Vector2?, Accent: Color3? }): Panel
	local design = options.Design or Vector2.new(860, 560)
	local accent = options.Accent or C.Peach

	local gui = UIKit.screenGui(options.Name .. "UI", { Layer = "Panels", Insets = "None", Enabled = false })

	-- Modal = true frees the mouse in first person so the buttons can be clicked
	local dim = UIKit.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		Modal = true,
		BackgroundColor3 = C.Dim,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		BorderSizePixel = 0,
	}, gui)

	-- outer frame: design size + fit scale; inner parts: shadow + window (open/close animation)
	local outer = UIKit.frame(gui, {
		Size = UDim2.fromOffset(design.X, design.Y),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundTransparency = 1,
	})
	local fit = UIKit.new("UIScale", { Scale = UIKit.fitScale(design) }, outer)
	local motion = UIKit.frame(outer, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
	local anim = UIKit.new("UIScale", { Scale = 0.94 }, motion)

	local shadow = UIKit.frame(motion, { Size = UDim2.new(1, 12, 1, 14), Position = UDim2.fromOffset(-6, 2), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.7 })
	UIKit.corner(shadow, Theme.Radius.Window + 4)
	local window = UIKit.new("CanvasGroup", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = C.Cream,
		BorderSizePixel = 0,
		GroupTransparency = 1,
	}, motion)
	UIKit.corner(window, Theme.Radius.Window)
	local outline = UIKit.frame(motion, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20 })
	UIKit.corner(outline, Theme.Radius.Window)
	UIKit.stroke(outline, C.Line, 1)

	-- header bar: icon, title, subtitle, close button
	local header = UIKit.frame(window, { Name = "Header", Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = Theme.Colors.Header, ZIndex = 5 })
	UIKit.frame(header, { Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1), BackgroundColor3 = C.Line, ZIndex = 6 })
	UIKit.frame(header, { Size = UDim2.fromOffset(3, 22), Position = UDim2.fromOffset(0, 15), BackgroundColor3 = accent, ZIndex = 7 }) -- the panel's one accent mark
	local titleOffset = 20
	if options.Icon then
		UIKit.icon(header, options.Icon, { Size = UDim2.fromOffset(26, 26), Position = UDim2.fromOffset(18, 13), ZIndex = 7 })
		titleOffset = 54
	end
	local title = UIKit.label(header, {
		Size = UDim2.new(0.55, -titleOffset, 0, 26),
		Position = UDim2.fromOffset(titleOffset, 6),
		Font = UIKit.Fonts.Title,
		TextSize = Theme.Type.Title,
		TextColor3 = C.Ink,
		Text = options.Title,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 7,
	})
	UIKit.label(header, {
		Size = UDim2.new(0.7, -titleOffset, 0, 16),
		Position = UDim2.fromOffset(titleOffset, 30),
		Font = UIKit.Fonts.Soft,
		TextSize = 12,
		TextColor3 = C.Muted,
		Text = options.Subtitle or SUBTITLES[options.Name] or "",
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 7,
	})

	local body = UIKit.frame(window, {
		Size = UDim2.new(1, -44, 1, -76),
		Position = UDim2.fromOffset(22, 64),
		BackgroundTransparency = 1,
	})

	local panel: Panel = {
		Name = options.Name,
		Gui = gui,
		Window = window,
		Body = body,
		Title = title,
		IsOpen = false,
		Open = nil :: any,
		Close = nil :: any,
		Toggle = nil :: any,
		OnOpen = {},
		OnClose = {},
		Focus = nil,
	}

	local closing = false
	panel.Open = function(self)
		if self.IsOpen then
			return
		end
		UIKit.closeAll(self.Name)
		self.IsOpen = true
		closing = false
		CursorController.hold("Panel_" .. self.Name, true)
		fit.Scale = UIKit.fitScale(design)
		gui.Enabled = true
		-- slide up + fade + grow
		anim.Scale = 0.94
		motion.Position = UDim2.fromOffset(0, 14)
		window.GroupTransparency = 1
		dim.BackgroundTransparency = 1
		UIKit.tween(anim, OPEN_SECONDS, { Scale = 1 }, Enum.EasingStyle.Quad)
		UIKit.tween(motion, OPEN_SECONDS, { Position = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quad)
		UIKit.tween(window, OPEN_SECONDS * 0.8, { GroupTransparency = 0 })
		UIKit.tween(dim, OPEN_SECONDS, { BackgroundTransparency = 0.45 })
		AudioController.play("Open")
		for _, callback in self.OnOpen do
			task.spawn(callback)
		end
	end
	panel.Close = function(self)
		if not self.IsOpen then
			return
		end
		self.IsOpen = false
		closing = true
		CursorController.hold("Panel_" .. self.Name, false)
		UIKit.tween(anim, CLOSE_SECONDS, { Scale = 0.92 })
		UIKit.tween(motion, CLOSE_SECONDS, { Position = UDim2.fromOffset(0, 14) })
		UIKit.tween(window, CLOSE_SECONDS, { GroupTransparency = 1 })
		UIKit.tween(dim, CLOSE_SECONDS, { BackgroundTransparency = 1 })
		AudioController.play("Close")
		task.delay(CLOSE_SECONDS + 0.02, function()
			if closing and not self.IsOpen then
				gui.Enabled = false
			end
		end)
		for _, callback in self.OnClose do
			task.spawn(callback)
		end
	end
	panel.Toggle = function(self)
		if self.IsOpen then
			self:Close()
		else
			self:Open()
		end
	end

	local closeButton = UIKit.button(header, {
		Text = "",
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.new(1, -12, 0, 9),
		AnchorPoint = Vector2.new(1, 0),
		Color = C.Card,
		Name = "Close",
		Silent = true,
		Corner = 8,
		OnClick = function()
			panel:Close()
		end,
	})
	closeButton.ZIndex = 8
	UIKit.icon(closeButton, "x", { Size = UDim2.fromOffset(16, 16), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 9 })
	dim.Activated:Connect(function()
		panel:Close()
	end)

	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			fit.Scale = UIKit.fitScale(design)
		end)
	end

	panels[options.Name] = panel
	return panel
end

---------------------------------------------------------------------------
-- misc widgets
---------------------------------------------------------------------------

-- A compact HUD indicator: dark capsule, drawn icon, value text. `Color` tints the value and the thin edge.
function UIKit.pill(parent: Instance, props: { Icon: string, Color: Color3?, Size: UDim2?, LayoutOrder: number?, OnPlus: (() -> ())?, Label: string?, Big: boolean? }): { Frame: Frame, Value: TextLabel }
	local accent = props.Color or C.Gold
	-- HUD indicator: a solid dark plate, a coloured edge on the left (the colour says what it is), a large drawn icon and a
	-- bold value. `Big` is for the main balance (cash): larger text.
	local frame = UIKit.frame(parent, {
		Size = props.Size or UDim2.fromOffset(130, Theme.Size.Pill),
		LayoutOrder = props.LayoutOrder or 0,
		BackgroundColor3 = C.Inset,
		BackgroundTransparency = 0.05,
		ClipsDescendants = true,
	})
	UIKit.corner(frame, Theme.Radius.Button + 2)
	UIKit.stroke(frame, mix(accent, C.Line, 0.6), 1)
	UIKit.frame(frame, { Name = "AccentEdge", Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = accent, ZIndex = 2 })
	UIKit.icon(frame, props.Icon, { Size = UDim2.fromOffset(if props.Big then 30 else 26, if props.Big then 30 else 26), Position = UDim2.new(0, 12, 0.5, 0), AnchorPoint = Vector2.new(0, 0.5), ZIndex = 3 })
	local value = UIKit.label(frame, {
		Size = UDim2.new(1, if props.OnPlus then -84 else -52, 1, 0),
		Position = UDim2.fromOffset(if props.Big then 48 else 44, 0),
		Font = UIKit.Fonts.Title,
		TextSize = if props.Big then Theme.Type.Title + 2 else Theme.Type.Heading + 1,
		TextColor3 = C.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
	})
	if props.OnPlus then
		local plus = UIKit.button(frame, {
			Text = "",
			Size = UDim2.fromOffset(24, 24),
			Position = UDim2.new(1, -6, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Color = C.Green,
			Corner = 99,
			Name = "Plus",
			OnClick = props.OnPlus,
		})
		plus.ZIndex = 4
		for _, rotation in { 0, 90 } do
			local bar = UIKit.frame(plus, { Size = UDim2.fromOffset(12, 3), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Rotation = rotation, BackgroundColor3 = C.White, ZIndex = 5 })
			UIKit.corner(bar, 2)
		end
	end
	return { Frame = frame, Value = value }
end

-- Hover tooltip for any GuiObject (PC). `side` is where the tip appears relative to the target: "Left", "Above" or "Below".
local tipGui: ScreenGui? = nil
local tipFrame: Frame? = nil
local tipLabel: TextLabel? = nil
function UIKit.tooltip(target: GuiObject, text: string | (() -> string), side: string?)
	if not tipGui then
		local gui = UIKit.screenGui("Tooltips", { Layer = "Tooltip", Insets = "None" })
		local frame = UIKit.frame(gui, { Name = "Tip", AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.fromOffset(0, 28), Visible = false, BackgroundColor3 = C.CreamDark })
		UIKit.corner(frame, 6)
		UIKit.stroke(frame, C.GoldLine, 1)
		UIKit.padding(frame, 10, 0)
		local label = UIKit.label(frame, { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), TextSize = 13, TextColor3 = C.Ink, Font = UIKit.Fonts.Body, TextXAlignment = Enum.TextXAlignment.Center })
		tipGui, tipFrame, tipLabel = gui, frame, label
	end
	target.MouseEnter:Connect(function()
		if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
			return
		end
		local frame, label = tipFrame :: Frame, tipLabel :: TextLabel
		label.Text = if type(text) == "function" then text() else text
		local position, size = target.AbsolutePosition, target.AbsoluteSize
		if side == "Left" then
			frame.AnchorPoint = Vector2.new(1, 0.5)
			frame.Position = UDim2.fromOffset(position.X - 8, position.Y + size.Y / 2)
		elseif side == "Below" then
			frame.AnchorPoint = Vector2.new(0.5, 0)
			frame.Position = UDim2.fromOffset(position.X + size.X / 2, position.Y + size.Y + 8)
		else
			frame.AnchorPoint = Vector2.new(0.5, 1)
			frame.Position = UDim2.fromOffset(position.X + size.X / 2, position.Y - 8)
		end
		frame.Visible = true
	end)
	target.MouseLeave:Connect(function()
		if tipFrame then
			tipFrame.Visible = false
		end
	end)
end

-- Small red dot used to show "something to claim".
function UIKit.notifyDot(parent: GuiObject): Frame
	local dot = UIKit.frame(parent, {
		Name = "NotifyDot",
		Size = UDim2.fromOffset(14, 14),
		Position = UDim2.new(1, -1, 0, 1),
		AnchorPoint = Vector2.new(1, 0),
		BackgroundColor3 = C.Red,
		Visible = false,
		ZIndex = 10,
	})
	UIKit.corner(dot, 99)
	UIKit.stroke(dot, C.Cream, 2)
	return dot
end

-- Floating text that rises and fades (e.g. "+$50").
function UIKit.floatText(parent: Instance, text: string, color: Color3, position: UDim2)
	local label = UIKit.label(parent, {
		Text = text,
		Position = position,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(200, 30),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = UIKit.Fonts.Title,
		TextSize = 24,
		TextColor3 = color,
		ZIndex = 20,
	})
	UIKit.new("UIStroke", { Color = C.Dim, Thickness = 2 }, label)
	UIKit.tween(label, 1, { Position = position - UDim2.fromOffset(0, 40), TextTransparency = 1 })
	task.delay(1.05, function()
		label:Destroy()
	end)
end

function UIKit.rarityColor(definition: any): Color3
	if definition.Hidden then
		return definition.Accent
	end
	return definition.Color
end

-- Text on a dark chip, readable on any background.
function UIKit.chip(parent: Instance, text: string, color: Color3, size: UDim2?): TextLabel
	local label = UIKit.label(parent, {
		Text = text,
		Size = size or UDim2.fromOffset(90, 22),
		BackgroundTransparency = 0,
		BackgroundColor3 = color,
		TextColor3 = C.White,
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = UIKit.Fonts.Body,
		TextSize = 12,
	})
	label.BackgroundColor3 = mix(C.Card, color, 0.55)
	UIKit.corner(label, 99)
	UIKit.stroke(label, mix(color, C.Line, 0.3), 1)
	return label
end

UIKit.GuiService = GuiService

return UIKit
