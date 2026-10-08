--[[ Serializes a PlayerGui tree to plain data for tools/render_gui.py (UI screenshots without Studio). ]]
local roblox = require("@lune/roblox")

local GuiDump = {}

local function try(instance, key)
	local ok, value = pcall(function()
		return instance[key]
	end)
	return if ok then value else nil
end

local function udim2(value)
	return if value then { value.X.Scale, value.X.Offset, value.Y.Scale, value.Y.Offset } else nil
end

local function color(value)
	return if value then { value.R, value.G, value.B } else nil
end

local function enumName(value)
	return if value then value.Name else nil
end

local function node(instance)
	local class = instance.ClassName
	local entry: { [string]: any } = { c = class, n = instance.Name }
	if instance:IsA("GuiObject") then
		entry.pos = udim2(try(instance, "Position"))
		entry.size = udim2(try(instance, "Size"))
		local anchor = try(instance, "AnchorPoint")
		entry.anchor = if anchor then { anchor.X, anchor.Y } else { 0, 0 }
		entry.bg = color(try(instance, "BackgroundColor3"))
		entry.bgt = try(instance, "BackgroundTransparency")
		entry.vis = try(instance, "Visible")
		entry.z = try(instance, "ZIndex")
		entry.lo = try(instance, "LayoutOrder")
		entry.rot = try(instance, "Rotation")
		entry.auto = enumName(try(instance, "AutomaticSize"))
		entry.clip = try(instance, "ClipsDescendants")
		if instance:IsA("TextLabel") or instance:IsA("TextButton") or instance:IsA("TextBox") then
			entry.text = try(instance, "Text")
			if instance:IsA("TextBox") and (entry.text == nil or entry.text == "") then
				entry.text = try(instance, "PlaceholderText")
				entry.placeholder = true
			end
			entry.tc = color(try(instance, "TextColor3"))
			entry.tt = try(instance, "TextTransparency")
			entry.ts = try(instance, "TextSize")
			entry.font = enumName(try(instance, "Font"))
			entry.tx = enumName(try(instance, "TextXAlignment"))
			entry.ty = enumName(try(instance, "TextYAlignment"))
			entry.scaled = try(instance, "TextScaled")
			entry.wrap = try(instance, "TextWrapped")
			entry.rich = try(instance, "RichText")
		end
		if instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
			entry.image = try(instance, "Image")
		end
	elseif class == "UICorner" then
		local radius = try(instance, "CornerRadius")
		entry.r = if radius then { radius.Scale, radius.Offset } else { 0, 8 }
	elseif class == "UIStroke" then
		entry.col = color(try(instance, "Color"))
		entry.th = try(instance, "Thickness")
		entry.t = try(instance, "Transparency")
		entry.on = try(instance, "Enabled")
		entry.mode = enumName(try(instance, "ApplyStrokeMode"))
	elseif class == "UIGradient" then
		local sequence = try(instance, "Color")
		if sequence then
			local keys = sequence.Keypoints
			entry.from = color(keys[1].Value)
			entry.to = color(keys[#keys].Value)
		end
		entry.rot = try(instance, "Rotation")
		entry.on = try(instance, "Enabled")
	elseif class == "UIScale" then
		entry.s = try(instance, "Scale")
	elseif class == "UIListLayout" then
		entry.dir = enumName(try(instance, "FillDirection"))
		local padding = try(instance, "Padding")
		entry.pad = if padding then { padding.Scale, padding.Offset } else { 0, 0 }
		entry.ha = enumName(try(instance, "HorizontalAlignment"))
		entry.va = enumName(try(instance, "VerticalAlignment"))
		entry.wraps = try(instance, "Wraps")
	elseif class == "UIGridLayout" then
		entry.cell = udim2(try(instance, "CellSize"))
		entry.cpad = udim2(try(instance, "CellPadding"))
		entry.max = try(instance, "FillDirectionMaxCells")
		entry.ha = enumName(try(instance, "HorizontalAlignment"))
	elseif class == "UIPadding" then
		local function u(key)
			local value = try(instance, key)
			return if value then { value.Scale, value.Offset } else { 0, 0 }
		end
		entry.l, entry.r, entry.t, entry.b = u("PaddingLeft"), u("PaddingRight"), u("PaddingTop"), u("PaddingBottom")
	elseif class == "ScreenGui" then
		entry.on = try(instance, "Enabled")
		entry.order = try(instance, "DisplayOrder")
	else
		return nil
	end
	local children = {}
	for _, child in instance:GetChildren() do
		local childEntry = node(child)
		if childEntry then
			table.insert(children, childEntry)
		end
	end
	if #children > 0 then
		entry.k = children
	end
	return entry
end

function GuiDump.dump(playerGui)
	local guis = {}
	for _, child in playerGui:GetChildren() do
		if child:IsA("ScreenGui") then
			local entry = node(child)
			if entry and entry.on ~= false then
				table.insert(guis, entry)
			end
		end
	end
	table.sort(guis, function(a, b)
		return (a.order or 0) < (b.order or 0)
	end)
	return guis
end

return GuiDump
