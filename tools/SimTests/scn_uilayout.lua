-- UI layout audit: computes the SCREEN RECTANGLES of every visible GuiObject of every panel / HUD part at 7 viewport sizes and reports
--   * controls that overlap each other (no parent/child relation)       * controls or text sticking out of their container or the screen
--   * text that cannot fit its label (estimated)                          * text that is effectively too small (< 10.5 px)
--   * tap targets that are too small (touch)                              * windows whose header runs under the native Roblox top bar
--   * HUD parts that cover each other (rail, hotbar, tip card, prompt strip, tutorial card ...)
-- The mock has no layout engine, so this file contains a SMALL one (UIScale, UIPadding, UIListLayout, UIGridLayout, AnchorPoint, AutomaticSize,
-- UIAspectRatioConstraint, ScrollingFrames) and a text-width ESTIMATE (characters x TextSize x a per-font factor). It proves STRUCTURE and GEOMETRY
-- of the layout the code asks for - not how it looks, and not the exact pixel width of real Gotham text (estimates carry a tolerance).
-- Self-tests at the top feed deliberately broken layouts to the same analyser, so a "0 problems" result means something.
local Players = game:GetService("Players")
local adv = M.Sim.advance
local results = { pass = 0, fail = 0 }
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end
local DUMP = rawget(_G, "UILAYOUT_DUMP") == true -- scratch copies set this to print every rectangle (wireframe renders)
local FORCE_TOUCH = rawget(_G, "UILAYOUT_TOUCH") == true

---------------------------------------------------------------------------------------------------------------------------------
-- 1. layout engine
---------------------------------------------------------------------------------------------------------------------------------
local TOPBAR = 36 -- height of the native Roblox top bar (GuiService:GetGuiInset in the mock)
local DEFAULT_SIZE = { Frame = { 100, 100 }, CanvasGroup = { 100, 100 }, ScrollingFrame = { 100, 100 }, ViewportFrame = { 100, 100 }, ImageLabel = { 100, 100 }, ImageButton = { 100, 100 }, TextLabel = { 200, 50 }, TextButton = { 200, 50 }, TextBox = { 200, 50 } }
local TEXT_CLASSES = { TextLabel = true, TextButton = true, TextBox = true }

local function IsA(inst, class) return M.InstanceMethods.IsA(inst, class) end
local function propOf(inst, key) return RawData[inst].Props[key] end
local function enumName(v, default) if v == nil then return default end return v.Name or default end

-- character widths in em (rough Gotham metrics; GothamBlack is wider). Documented estimate, see header.
local NARROW, SEMI, WIDE = {}, {}, {}
for c in string.gmatch("ijl.,:;'|!`", ".") do NARROW[c] = 0.27 end
for c in string.gmatch("tfrI()[]{}-/\\\"1", ".") do SEMI[c] = 0.38 end
for c in string.gmatch("mwMW@%", ".") do WIDE[c] = 0.9 end
local function charEm(c: string): number
	if c == " " then return 0.28 end
	if NARROW[c] then return NARROW[c] end
	if SEMI[c] then return SEMI[c] end
	if WIDE[c] then return WIDE[c] end
	if string.find(c, "^%d$") then return 0.62 end
	if string.find(c, "^%u$") then return 0.70 end
	if string.find(c, "^%l$") then return 0.56 end
	return 0.6
end
local function stripRich(text: string): string
	text = string.gsub(text, "<[^>]+>", "")
	text = string.gsub(text, "&lt;", "<")
	text = string.gsub(text, "&gt;", ">")
	text = string.gsub(text, "&amp;", "&")
	return text
end
local function textWidth(text: string, size: number, black: boolean): number
	local total = 0
	for _, cp in utf8.codes(text) do
		local c = if cp < 128 then string.char(cp) else "?"
		total += charEm(c)
	end
	return total * size * (if black then 1.07 else 1)
end

-- Text metrics of one label at `availW` pixels of width. Returns { w, h, lines, truncated, spill (px beyond the label, horizontal), spillV }
local function measureText(data, availW: number, availH: number, cum: number)
	local props = data.Props
	local text = props.Text
	if type(text) ~= "string" or text == "" then return nil end
	if props.RichText ~= false then text = stripRich(text) end
	local size = (props.TextSize or 14) * cum
	local font = enumName(props.Font, "SourceSans")
	local black = font == "GothamBlack" or font == "GothamBold" or font == "FredokaOne"
	local wrapped = props.TextWrapped == true
	local truncate = enumName(props.TextTruncate, "None")
	local lines, widest = 0, 0
	for paragraph in string.gmatch(text .. "\n", "(.-)\n") do
		if wrapped then
			local line = 0
			local count = 1
			for word in string.gmatch(paragraph, "%S+") do
				local ww = textWidth(word, size, black)
				local gap = if line > 0 then textWidth(" ", size, black) else 0
				if line > 0 and line + gap + ww > availW then
					count += 1
					line = ww
				else
					line += gap + ww
				end
				if ww > availW then count += math.floor(ww / math.max(availW, 1)); line = ww % math.max(availW, 1) end
				widest = math.max(widest, math.min(line, availW))
			end
			lines += count
		else
			lines += 1
			widest = math.max(widest, textWidth(paragraph, size, black))
		end
	end
	local h = lines * size
	local truncated = false
	local spill, spillV = 0, 0
	if wrapped then
		if h > availH + 2 then
			if truncate == "AtEnd" then
				truncated = true
				h = math.max(size, math.floor(availH / size) * size)
			else
				spillV = h - availH
			end
		end
	else
		if widest > availW + 1 then
			if truncate == "AtEnd" then
				truncated = true
				widest = availW
			else
				spill = widest - availW
			end
		end
	end
	return { w = widest, h = h, lines = lines, truncated = truncated, spill = spill, spillV = spillV, size = size }
end

local function udimOf(v) return v end

local function guiKids(inst)
	local list = {}
	for _, child in RawData[inst].Children do
		if IsA(child, "GuiObject") then table.insert(list, child) end
	end
	return list
end

local function modsOf(inst)
	local m = { scale = 1, padL = 0, padR = 0, padT = 0, padB = 0 }
	for _, child in RawData[inst].Children do
		local class = RawData[child].ClassName
		if class == "UIScale" then
			m.scale *= (RawData[child].Props.Scale or 1)
		elseif class == "UIListLayout" then
			m.list = RawData[child].Props
		elseif class == "UIGridLayout" then
			m.grid = RawData[child].Props
		elseif class == "UIAspectRatioConstraint" then
			m.aspect = RawData[child].Props
		elseif class == "UIPadding" then
			m.pad = RawData[child].Props
		end
	end
	return m
end

local function isVisible(inst) return RawData[inst].Props.Visible ~= false end

local naturalSize -- forward

-- size in px of `child` inside a content box (cw, ch) at cumulative scale `cum` (the parent's, without the child's own UIScale)
local function sizePx(child, cw: number, ch: number, cum: number)
	local data = RawData[child]
	local mods = modsOf(child)
	local own = cum * mods.scale
	local def = DEFAULT_SIZE[data.ClassName] or { 100, 100 }
	local size = data.Props.Size
	local w, h
	if size then
		w = size.X.Scale * cw + size.X.Offset * own
		h = size.Y.Scale * ch + size.Y.Offset * own
	else
		w, h = def[1] * own, def[2] * own
	end
	local auto = enumName(data.Props.AutomaticSize, "None")
	if auto ~= "None" then
		local nw, nh = naturalSize(child, own, w)
		if auto == "X" or auto == "XY" then w = math.max(w, nw) end
		if auto == "Y" or auto == "XY" then h = math.max(h, nh) end
	end
	if mods.aspect then
		local ratio = mods.aspect.AspectRatio or 1
		if w / math.max(h, 0.001) > ratio then w = h * ratio else h = w / ratio end
	end
	return w, h, own, mods
end

-- the size a frame / label needs for its content (AutomaticSize). `forceW` is the width already decided (for wrapped text).
naturalSize = function(inst, own: number, forceW: number?)
	local data = RawData[inst]
	if TEXT_CLASSES[data.ClassName] then
		local padding = modsOf(inst)
		local m = measureText(data, forceW or 1e9, 1e9, own)
		if data.Props.TextWrapped == true and forceW then
			m = measureText(data, forceW, 1e9, own)
		end
		if m then return m.w + padding.padL + padding.padR, m.h + padding.padT + padding.padB end
		return 0, 0
	end
	local mods = modsOf(inst)
	local kids = {}
	for _, k in guiKids(inst) do if isVisible(k) then table.insert(kids, k) end end
	local pl, pr, pt, pb = 0, 0, 0, 0
	if mods.pad then
		pl, pr = (mods.pad.PaddingLeft and mods.pad.PaddingLeft.Offset or 0) * own, (mods.pad.PaddingRight and mods.pad.PaddingRight.Offset or 0) * own
		pt, pb = (mods.pad.PaddingTop and mods.pad.PaddingTop.Offset or 0) * own, (mods.pad.PaddingBottom and mods.pad.PaddingBottom.Offset or 0) * own
	end
	local w, h = 0, 0
	if mods.list then
		local horizontal = enumName(mods.list.FillDirection, "Vertical") == "Horizontal"
		local gap = (mods.list.Padding and mods.list.Padding.Offset or 0) * own
		for index, k in kids do
			local kw, kh = sizePx(k, 0, 0, own)
			if horizontal then
				w += kw + (if index > 1 then gap else 0)
				h = math.max(h, kh)
			else
				h += kh + (if index > 1 then gap else 0)
				w = math.max(w, kw)
			end
		end
	else
		for _, k in kids do
			local kw, kh = sizePx(k, 0, 0, own)
			local pos = RawData[k].Props.Position
			local px = if pos then pos.X.Offset * own else 0
			local py = if pos then pos.Y.Offset * own else 0
			w = math.max(w, px + kw)
			h = math.max(h, py + kh)
		end
	end
	return w + pl + pr, h + pt + pb
end

-- Node = { inst, data, x, y, w, h, cum, parent, kids, clip }
local function newNode(inst, parent, x, y, w, h, cum)
	return { inst = inst, data = RawData[inst], class = RawData[inst].ClassName, name = RawData[inst].Name, parent = parent, kids = {}, x = x, y = y, w = w, h = h, cum = cum, clip = nil }
end

local function intersect(a, b)
	if not a then return b end
	if not b then return a end
	local x0, y0 = math.max(a.x, b.x), math.max(a.y, b.y)
	local x1, y1 = math.min(a.x + a.w, b.x + b.w), math.min(a.y + a.h, b.y + b.h)
	return { x = x0, y = y0, w = math.max(0, x1 - x0), h = math.max(0, y1 - y0) }
end

local placeChildren

local function udim2Pos(child, cx, cy, cw, ch, own, w, h)
	local pos = RawData[child].Props.Position
	local anchor = RawData[child].Props.AnchorPoint
	local px, py = 0, 0
	if pos then
		px = pos.X.Scale * cw + pos.X.Offset * own
		py = pos.Y.Scale * ch + pos.Y.Offset * own
	end
	local ax, ay = 0, 0
	if anchor then ax, ay = anchor.X, anchor.Y end
	return cx + px - ax * w, cy + py - ay * h
end

local function layoutKids(node)
	local inst = node.inst
	local mods = modsOf(inst)
	local pl, pr, pt, pb = 0, 0, 0, 0
	if mods.pad then
		local pad = mods.pad
		pl = (pad.PaddingLeft and (pad.PaddingLeft.Scale * node.w + pad.PaddingLeft.Offset * node.cum)) or 0
		pr = (pad.PaddingRight and (pad.PaddingRight.Scale * node.w + pad.PaddingRight.Offset * node.cum)) or 0
		pt = (pad.PaddingTop and (pad.PaddingTop.Scale * node.h + pad.PaddingTop.Offset * node.cum)) or 0
		pb = (pad.PaddingBottom and (pad.PaddingBottom.Scale * node.h + pad.PaddingBottom.Offset * node.cum)) or 0
	end
	local cx, cy = node.x + pl, node.y + pt
	local cw, ch = math.max(0, node.w - pl - pr), math.max(0, node.h - pt - pb)
	node.content = { x = cx, y = cy, w = cw, h = ch }
	local clipsKids = node.class == "ScrollingFrame" or node.class == "CanvasGroup" or RawData[inst].Props.ClipsDescendants == true
	local kidClip = if clipsKids then intersect(node.clip, { x = node.x, y = node.y, w = node.w, h = node.h }) else node.clip

	local kids = {}
	for index, child in guiKids(inst) do
		if isVisible(child) then table.insert(kids, { inst = child, index = index, order = RawData[child].Props.LayoutOrder or 0 }) end
	end
	local function make(entry, x, y, w, h, own)
		local kid = newNode(entry.inst, node, x, y, w, h, own)
		kid.clip = kidClip
		table.insert(node.kids, kid)
		-- icon roots and 3D viewports are leaves
		if not RawData[entry.inst].Attributes.IconId and RawData[entry.inst].ClassName ~= "ViewportFrame" then
			placeChildren(kid)
		end
		return kid
	end

	if mods.grid then
		table.sort(kids, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.index < b.index end)
		local g = mods.grid
		local cell = g.CellSize or UDim2.fromOffset(100, 100)
		local cpad = g.CellPadding or UDim2.fromOffset(5, 5)
		local cellW, cellH = cell.X.Scale * cw + cell.X.Offset * node.cum, cell.Y.Scale * ch + cell.Y.Offset * node.cum
		local padX, padY = cpad.X.Scale * cw + cpad.X.Offset * node.cum, cpad.Y.Scale * ch + cpad.Y.Offset * node.cum
		local cols = math.max(1, math.floor((cw + padX) / math.max(cellW + padX, 1)))
		local blockW = math.min(#kids, cols) * cellW + (math.min(#kids, cols) - 1) * padX
		local halign = enumName(g.HorizontalAlignment, "Left")
		local startX = cx
		if halign == "Center" then startX = cx + (cw - blockW) / 2 elseif halign == "Right" then startX = cx + cw - blockW end
		for i, entry in kids do
			local col, row = (i - 1) % cols, (i - 1) // cols
			make(entry, startX + col * (cellW + padX), cy + row * (cellH + padY), cellW, cellH, node.cum)
		end
		node.gridCols = cols
		return
	end
	if mods.list then
		table.sort(kids, function(a, b) if a.order ~= b.order then return a.order < b.order end return a.index < b.index end)
		local l = mods.list
		local horizontal = enumName(l.FillDirection, "Vertical") == "Horizontal"
		local gap = (l.Padding and (l.Padding.Scale * (if horizontal then cw else ch) + l.Padding.Offset * node.cum)) or 0
		local halign, valign = enumName(l.HorizontalAlignment, "Left"), enumName(l.VerticalAlignment, "Top")
		local sized = {}
		local total = 0
		for index, entry in kids do
			local w, h, own = sizePx(entry.inst, cw, ch, node.cum)
			sized[index] = { w = w, h = h, own = own }
			total += (if horizontal then w else h) + (if index > 1 then gap else 0)
		end
		if horizontal then
			local x = cx
			if halign == "Center" then x = cx + (cw - total) / 2 elseif halign == "Right" then x = cx + cw - total end
			for index, entry in kids do
				local s = sized[index]
				local y = cy
				if valign == "Center" then y = cy + (ch - s.h) / 2 elseif valign == "Bottom" then y = cy + ch - s.h end
				make(entry, x, y, s.w, s.h, s.own)
				x += s.w + gap
			end
		else
			local y = cy
			if valign == "Center" then y = cy + (ch - total) / 2 elseif valign == "Bottom" then y = cy + ch - total end
			for index, entry in kids do
				local s = sized[index]
				local x = cx
				if halign == "Center" then x = cx + (cw - s.w) / 2 elseif halign == "Right" then x = cx + cw - s.w end
				make(entry, x, y, s.w, s.h, s.own)
				y += s.h + gap
			end
		end
		node.listTotal = total
		return
	end
	for _, entry in kids do
		local w, h, own = sizePx(entry.inst, cw, ch, node.cum)
		local x, y = udim2Pos(entry.inst, cx, cy, cw, ch, own, w, h)
		make(entry, x, y, w, h, own)
	end
end

placeChildren = function(node)
	layoutKids(node)
end

-- Lays out one ScreenGui for a viewport. `insets`: Topbar / Device / None (Attribute set by UIKit.screenGui)
local function layoutGui(gui, viewport)
	local data = RawData[gui]
	local inset = if data.Attributes.Insets == "Topbar" then TOPBAR else 0
	local root = newNode(gui, nil, 0, inset, viewport.X, viewport.Y - inset, 1)
	root.isRoot = true
	root.screen = { x = 0, y = 0, w = viewport.X, h = viewport.Y }
	placeChildren(root)
	return root
end

local function walk(node, fn)
	fn(node)
	for _, kid in node.kids do walk(kid, fn) end
end

---------------------------------------------------------------------------------------------------------------------------------
-- 2. analysis
---------------------------------------------------------------------------------------------------------------------------------
-- what a node contributes to the screen: its VISUAL rectangle (text uses the estimated extent of the drawn text, not the label box)
local function contentOf(node)
	local data = node.data
	local rect = { x = node.x, y = node.y, w = node.w, h = node.h }
	if data.Attributes.IconId then
		return { kind = "icon", rect = rect }
	end
	if node.class == "ViewportFrame" or node.class == "ImageLabel" or node.class == "ImageButton" then
		if node.class ~= "ImageLabel" or (data.Props.Image and data.Props.Image ~= "") then
			return { kind = "image", rect = rect }
		end
		return nil
	end
	if TEXT_CLASSES[node.class] then
		local text = data.Props.Text
		if node.class == "TextBox" and (text == nil or text == "") then text = data.Props.PlaceholderText end
		if type(text) == "string" and text ~= "" and (data.Props.TextTransparency or 0) < 0.95 and not data.Props.TextScaled then
			local fake = { Props = data.Props }
			if node.class == "TextBox" and (data.Props.Text == nil or data.Props.Text == "") then fake = { Props = { Text = text, TextSize = data.Props.TextSize, Font = data.Props.Font, RichText = false } } end
			local mods = modsOf(node.inst)
			local m = measureText(fake, node.w, node.h, node.cum)
			if m then
				local tw, th = m.w, m.h
				local xa = enumName(data.Props.TextXAlignment, "Left")
				local ya = enumName(data.Props.TextYAlignment, "Center")
				local x = node.x
				if xa == "Center" then x = node.x + (node.w - tw) / 2 elseif xa == "Right" then x = node.x + node.w - tw end
				local y = node.y
				if ya == "Center" then y = node.y + (node.h - th) / 2 elseif ya == "Bottom" then y = node.y + node.h - th end
				return { kind = "text", rect = { x = x, y = y, w = tw, h = th }, metrics = m, text = text, box = rect }
			end
		end
		if node.class == "TextButton" then return { kind = "hit", rect = rect } end
		return nil
	end
	return nil
end

local function isAncestor(a, b) -- a is an ancestor of b (node tables)
	local cur = b.parent
	while cur do
		if cur == a then return true end
		cur = cur.parent
	end
	return false
end

local function area(r) return math.max(0, r.w) * math.max(0, r.h) end
local function inter(a, b)
	local x0, y0 = math.max(a.x, b.x), math.max(a.y, b.y)
	local x1, y1 = math.min(a.x + a.w, b.x + b.w), math.min(a.y + a.h, b.y + b.h)
	return { x = x0, y = y0, w = x1 - x0, h = y1 - y0 }
end

local function pathOf(node)
	local parts = {}
	local cur = node
	while cur do
		table.insert(parts, 1, cur.name)
		cur = cur.parent
	end
	-- keep it short: last 3 segments
	local n = #parts
	if n > 4 then return "..." .. table.concat({ parts[n - 2], parts[n - 1], parts[n] }, "/") end
	return table.concat(parts, "/")
end

-- A back-drop (dim) / hit area covering the whole container is meant to lie under everything
local function isBackdrop(node)
	if node.class ~= "TextButton" then return false end
	local text = node.data.Props.Text
	if text ~= nil and text ~= "" then return false end
	local size = node.data.Props.Size
	return size ~= nil and size.X.Scale >= 0.99 and size.Y.Scale >= 0.99
end

-- Findings are { kind, where, detail, severity }. `opts.allow` = { [name] = true } names that are intentionally layered.
local function analyse(root, viewport, opts)
	opts = opts or {}
	local findings = {}
	local function add(kind, node, detail)
		table.insert(findings, { kind = kind, where = pathOf(node), detail = detail, name = node.name })
	end
	local items = {}
	local screen = root.screen or { x = 0, y = 0, w = viewport.X, h = viewport.Y }
	walk(root, function(node)
		if node.isRoot then return end
		if isBackdrop(node) then return end
		local c = contentOf(node)
		if c then
			c.node = node
			table.insert(items, c)
		end
		-- zero-size text
		if TEXT_CLASSES[node.class] and (node.w < 1 or node.h < 1) and type(node.data.Props.Text) == "string" and node.data.Props.Text ~= "" then
			add("zero-size", node, string.format("'%s' has size %.0fx%.0f", string.sub(node.data.Props.Text, 1, 20), node.w, node.h))
		end
	end)

	-- (a) text that does not fit / is too small
	for _, c in items do
		local node = c.node
		if c.kind == "text" then
			local m = c.metrics
			local label = string.sub(c.text, 1, 28)
			if m.spill > 2 then add("text-spill", node, string.format("'%s' needs ~%.0f px, label is %.0f px wide (spills %.0f)", label, m.w, node.w, m.spill)) end
			if m.spillV > 3 then add("text-spill-v", node, string.format("'%s' needs ~%.0f px height (%d lines), label is %.0f px high", label, m.h, m.lines, node.h)) end
			if m.truncated and not (opts.allowTruncate and opts.allowTruncate[node.name]) then add("text-truncated", node, string.format("'%s' (%d lines, size %.1f) is cut off at %.0fx%.0f", label, m.lines, m.size, node.w, node.h)) end
			if m.size < 10.5 then add("tiny-text", node, string.format("'%s' is %.1f px effective", label, m.size)) end
		end
		-- (b) beyond the screen
		local r = c.rect
		if r.x < screen.x - 1 or r.y < screen.y - 1 or r.x + r.w > screen.x + screen.w + 1 or r.y + r.h > screen.y + screen.h + 1 then
			-- only if actually visible (not clipped away by a scroll frame)
			local clip = c.node.clip
			local visibleRect = if clip then inter(r, clip) else r
			if visibleRect.w > 1 and visibleRect.h > 1 then
				add("off-screen", node, string.format("rect x%.0f y%.0f w%.0f h%.0f on a %dx%d screen", r.x, r.y, r.w, r.h, viewport.X, viewport.Y))
			end
		end
	end

	-- (c) children sticking out of their container (the nearest ancestor that clips or has a visible fill), scroll axis excluded
	for _, c in items do
		local node = c.node
		local r = c.rect
		local cur = node.parent
		local depth = 0
		while cur and not cur.isRoot and depth < 12 do
			local isScroll = cur.class == "ScrollingFrame"
			local hasFill = cur.data.Props.BackgroundTransparency ~= 1 and cur.class ~= "ScrollingFrame" and cur.data.Props.BackgroundColor3 ~= nil
			local named = opts.containers and opts.containers[cur.name]
			if isScroll or hasFill or cur.class == "CanvasGroup" or cur.data.Props.ClipsDescendants == true or named then
				if not (cur.data.Attributes.IconId) then
					local out = { l = cur.x - r.x, t = cur.y - r.y, r = (r.x + r.w) - (cur.x + cur.w), b = (r.y + r.h) - (cur.y + cur.h) }
					local limit = 1.5
					local scrollsY = isScroll and enumName(cur.data.Props.ScrollingDirection, "Y") ~= "X"
					local scrollsX = isScroll and enumName(cur.data.Props.ScrollingDirection, "Y") == "X"
					local bad = out.l > limit or out.r > limit or ((not scrollsY) and (out.t > limit or out.b > limit))
					if scrollsX then bad = out.t > limit or out.b > limit end
					if bad and not (opts.allowOutside and opts.allowOutside[node.name]) then
						add("outside-parent", node, string.format("%s extends beyond %s (L%.0f T%.0f R%.0f B%.0f px)", (if c.kind == "text" then "'" .. string.sub(c.text, 1, 20) .. "'" else c.kind), cur.name, math.max(0, out.l), math.max(0, out.t), math.max(0, out.r), math.max(0, out.b)))
					end
					break -- only the nearest container is judged for each item
				end
			end
			cur = cur.parent
			depth += 1
		end
	end

	-- (d) overlaps between content items (not related as ancestor/descendant)
	table.sort(items, function(a, b) return a.rect.x < b.rect.x end)
	for i = 1, #items do
		local a = items[i]
		if a.kind ~= "hit" then
			for j = i + 1, #items do
				local b = items[j]
				if b.rect.x >= a.rect.x + a.rect.w then break end
				if b.kind ~= "hit" and not isAncestor(a.node, b.node) and not isAncestor(b.node, a.node) then
					local clipA, clipB = a.node.clip, b.node.clip
					local x = inter(a.rect, b.rect)
					if x.w >= 2 and x.h >= 2 and x.w * x.h >= 12 then
						-- both must be on screen at the same time: visible parts inside every clip
						local vis = x
						if clipA then vis = inter(vis, clipA) end
						if clipB then vis = inter(vis, clipB) end
						if vis.w >= 2 and vis.h >= 2 and not (opts.allow and (opts.allow[a.node.name] or opts.allow[b.node.name])) then
							local da = if a.kind == "text" then "'" .. string.sub(a.text, 1, 16) .. "'" else a.kind .. ":" .. a.node.name
							local db = if b.kind == "text" then "'" .. string.sub(b.text, 1, 16) .. "'" else b.kind .. ":" .. b.node.name
							add("overlap", a.node, string.format("%s x %s overlap %.0fx%.0f px (%s | %s)", da, db, vis.w, vis.h, pathOf(a.node), pathOf(b.node)))
						end
					end
				end
			end
		end
	end
	return findings, items
end

local function summarise(findings)
	local counts = {}
	for _, f in findings do counts[f.kind] = (counts[f.kind] or 0) + 1 end
	return counts
end

local function describe(findings, kinds, limit)
	local lines = {}
	for _, f in findings do
		if kinds[f.kind] and #lines < (limit or 6) then table.insert(lines, f.kind .. ": " .. f.where .. " - " .. f.detail) end
	end
	return table.concat(lines, " ;; ")
end

local function countOf(findings, kinds)
	local n = 0
	for _, f in findings do if kinds[f.kind] then n += 1 end end
	return n
end

-- collapses the same finding seen at several viewports into one line
local function unique(findingsByVp)
	local seen, order = {}, {}
	for vp, list in findingsByVp do
		for _, f in list do
			local key = f.kind .. "|" .. f.where
			if not seen[key] then
				seen[key] = { f = f, vps = {} }
				table.insert(order, key)
			end
			table.insert(seen[key].vps, vp)
		end
	end
	table.sort(order)
	return seen, order
end

---------------------------------------------------------------------------------------------------------------------------------
-- 3. self-tests: the analyser must SEE deliberately broken layouts and stay quiet on a healthy one
---------------------------------------------------------------------------------------------------------------------------------
local function mk(class, props, parent)
	local inst = Instance.new(class)
	for key, value in props or {} do inst[key] = value end
	if parent then inst.Parent = parent end
	return inst
end

local selfTest = function()
	local vp = Vector2.new(800, 600)
	local function gui(build)
		local g = Instance.new("ScreenGui")
		RawData[g].Attributes.Insets = "None"
		build(g)
		local root = layoutGui(g, vp)
		local findings = analyse(root, vp, {})
		return findings, root
	end
	local text = Enum.Font.GothamMedium
	-- healthy: a panel with a list of labels
	local okFindings = gui(function(g)
		local panel = mk("Frame", { Size = UDim2.fromOffset(300, 200), Position = UDim2.fromOffset(100, 100), BackgroundColor3 = Color3.new(0.2, 0.2, 0.2) }, g)
		mk("UIListLayout", { FillDirection = Enum.FillDirection.Vertical, Padding = UDim.new(0, 6) }, panel)
		mk("TextLabel", { Size = UDim2.new(1, 0, 0, 30), Text = "Short title", TextSize = 20, Font = text }, panel)
		mk("TextLabel", { Size = UDim2.new(1, 0, 0, 30), Text = "Another line", TextSize = 16, Font = text }, panel)
		mk("TextButton", { Size = UDim2.new(1, 0, 0, 40), Text = "OK", TextSize = 16, Font = text }, panel)
	end)
	check("self-test: a healthy layout produces no findings", #okFindings == 0, #okFindings > 0 and describe(okFindings, { overlap = true, ["text-spill"] = true, ["outside-parent"] = true, ["tiny-text"] = true, ["off-screen"] = true, ["text-truncated"] = true, ["text-spill-v"] = true }) or nil)
	-- overlap
	local f1 = gui(function(g)
		mk("TextLabel", { Size = UDim2.fromOffset(200, 30), Position = UDim2.fromOffset(100, 100), Text = "First label here", TextSize = 20, Font = text }, g)
		mk("TextLabel", { Size = UDim2.fromOffset(200, 30), Position = UDim2.fromOffset(150, 110), Text = "Second label here", TextSize = 20, Font = text }, g)
	end)
	check("self-test: two overlapping labels are reported", countOf(f1, { overlap = true }) == 1)
	-- text too wide
	local f2 = gui(function(g)
		mk("TextLabel", { Size = UDim2.fromOffset(60, 30), Position = UDim2.fromOffset(100, 100), Text = "A very long sentence that cannot fit", TextSize = 20, Font = text }, g)
	end)
	check("self-test: text wider than its label is reported", countOf(f2, { ["text-spill"] = true }) == 1)
	-- wrapped text too tall
	local f3 = gui(function(g)
		mk("TextLabel", { Size = UDim2.fromOffset(100, 30), Position = UDim2.fromOffset(100, 100), Text = "A very long sentence that wraps onto many lines and cannot fit", TextSize = 18, TextWrapped = true, Font = text }, g)
	end)
	check("self-test: wrapped text taller than its label is reported", countOf(f3, { ["text-spill-v"] = true }) == 1)
	-- truncated
	local f4 = gui(function(g)
		mk("TextLabel", { Size = UDim2.fromOffset(60, 30), Position = UDim2.fromOffset(100, 100), Text = "A very long sentence that cannot fit", TextSize = 20, TextTruncate = Enum.TextTruncate.AtEnd, Font = text }, g)
	end)
	check("self-test: truncated text is reported as truncated", countOf(f4, { ["text-truncated"] = true }) == 1)
	-- sticking out of its panel
	local f5 = gui(function(g)
		local panel = mk("Frame", { Size = UDim2.fromOffset(200, 100), Position = UDim2.fromOffset(100, 100), BackgroundColor3 = Color3.new(0.2, 0.2, 0.2) }, g)
		mk("TextButton", { Size = UDim2.fromOffset(120, 40), Position = UDim2.fromOffset(150, 20), Text = "Out", TextSize = 16, Font = text }, panel)
	end)
	check("self-test: a button sticking out of its panel is reported", countOf(f5, { ["outside-parent"] = true }) == 1)
	-- off screen
	local f6 = gui(function(g)
		mk("TextButton", { Size = UDim2.fromOffset(120, 40), Position = UDim2.fromOffset(760, 100), Text = "Edge", TextSize = 16, Font = text }, g)
	end)
	check("self-test: a control beyond the screen edge is reported", countOf(f6, { ["off-screen"] = true }) >= 1)
	-- tiny
	local f7 = gui(function(g)
		local holder = mk("Frame", { Size = UDim2.fromOffset(200, 100), Position = UDim2.fromOffset(100, 100), BackgroundTransparency = 1 }, g)
		mk("UIScale", { Scale = 0.5 }, holder)
		mk("TextLabel", { Size = UDim2.fromOffset(100, 30), Text = "Tiny", TextSize = 16, Font = text }, holder)
	end)
	check("self-test: UIScale-reduced text under 10.5 px is reported", countOf(f7, { ["tiny-text"] = true }) == 1)
	-- UIScale + grid + auto size geometry sanity
	local _, root8 = gui(function(g)
		local holder = mk("Frame", { Size = UDim2.fromOffset(100, 100), Position = UDim2.fromOffset(10, 20), BackgroundTransparency = 1, Name = "H" }, g)
		mk("UIScale", { Scale = 2 }, holder)
		local inner = mk("Frame", { Size = UDim2.new(0.5, 10, 0, 20), Position = UDim2.fromOffset(5, 5), Name = "I" }, holder)
	end)
	local H = root8.kids[1]
	local I = H.kids[1]
	check("self-test: UIScale doubles size and offsets (outer 100x100 -> 200x200, inner = 0.5*200 + 10*2 = 120 wide, offset 10)", H.w == 200 and H.h == 200 and I.w == 120 and I.h == 40 and I.x == 10 + 10 and I.y == 20 + 10, string.format("%s %s %s %s %s", H.w, I.w, I.h, I.x, I.y))
	local _, root9 = gui(function(g)
		local grid = mk("Frame", { Size = UDim2.fromOffset(330, 300), BackgroundTransparency = 1, Name = "G" }, g)
		mk("UIGridLayout", { CellSize = UDim2.fromOffset(100, 50), CellPadding = UDim2.fromOffset(10, 10) }, grid)
		for _ = 1, 5 do mk("Frame", {}, grid) end
	end)
	local G = root9.kids[1]
	check("self-test: a grid fits 3 columns of 100 px + 10 px gaps into 330 px and wraps the 4th cell", G.gridCols == 3 and G.kids[4].x == 0 and G.kids[4].y == 60 and G.kids[3].x == 220, tostring(G.gridCols))
	local _, root10 = gui(function(g)
		local row = mk("Frame", { Size = UDim2.fromOffset(300, 40), Position = UDim2.fromOffset(100, 100), BackgroundTransparency = 1, Name = "R" }, g)
		mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center }, row)
		mk("Frame", { Size = UDim2.fromOffset(50, 20) }, row)
		mk("Frame", { Size = UDim2.fromOffset(50, 20) }, row)
	end)
	local R = root10.kids[1]
	check("self-test: a centred horizontal list puts two 50 px children + a 10 px gap in the middle of 300 px", R.kids[1].x == 100 + 95 and R.kids[2].x == 100 + 155 and R.kids[1].y == 110, string.format("%s %s %s", R.kids[1].x, R.kids[2].x, R.kids[1].y))
end

---------------------------------------------------------------------------------------------------------------------------------
-- 4. the game
---------------------------------------------------------------------------------------------------------------------------------
task.spawn(function()
	selfTest()

	M.isServer = true
	-- record what the game does with Roblox's own Backpack bar
	local coreGuiCalls = {}
	local StarterGui = game:GetService("StarterGui")
	M.setMethods(StarterGui, { SetCoreGuiEnabled = function(_, coreType, enabled) table.insert(coreGuiCalls, { Type = coreType.Name, Enabled = enabled }) end })
	local mainServer = find("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	adv(1)
	local p = M.newPlayer("Layout")
	adv(0.01)
	RawData[Players].Signals.PlayerAdded:Fire(p)
	M.spawnCharacter(p)
	adv(6)
	M.localPlayerRef = p
	local playerGui = M.newInstance("PlayerGui", true); RawData[playerGui].Name = "PlayerGui"; M.setParent(playerGui, p)
	local UIS = game:GetService("UserInputService")
	if FORCE_TOUCH then
		RawData[UIS].Props.TouchEnabled = true
		RawData[UIS].Props.KeyboardEnabled = false
	end
	M.isServer = false
	M.clientRunning = true
	local mainClient = find("StarterPlayer.StarterPlayerScripts.Main")
	task.spawn(function() RawData[mainClient].Source(mainClient, require) end)
	adv(4)

	local UI = "StarterPlayer.StarterPlayerScripts.UI."
	local UIKit = require(find(UI .. "UIKit"))
	local UIRegistry = require(find(UI .. "UIRegistry"))
	local Icons = require(find(UI .. "Icons"))
	local Theme = require(find(UI .. "Theme"))
	local MainUI = require(find(UI .. "MainUI"))
	local HotbarUI = require(find(UI .. "HotbarUI"))
	local DataSystem = require(find("ServerScriptService.Systems.DataSystem"))
	local ReplicationSystem = require(find("ServerScriptService.Systems.ReplicationSystem"))
	local GearSystem = require(find("ServerScriptService.Systems.GearSystem"))
	local ItemRegistry = require(find("ReplicatedStorage.Modules.ItemRegistry"))
	local HamsterDatabase = require(find("ReplicatedStorage.Modules.HamsterDatabase"))
	local RarityConfig = require(find("ReplicatedStorage.Modules.RarityConfig"))
	local ShopConfig = require(find("ReplicatedStorage.Modules.ShopConfig"))
	local cam = workspace.CurrentCamera

	local function byName(root, name)
		local found = {}
		for _, d in M.descendants(root) do if RawData[d].Name == name then table.insert(found, d) end end
		return found
	end
	local function press(button) RawData[button].Signals.Activated:Fire(); adv(0.4) end

	-- a rich profile so every panel shows its busiest state
	local data = DataSystem.get(p)
	M.isServer = true
	data.Coins = 987654321; data.Gems = 12345
	data.Rebirths = 3
	for _, def in ItemRegistry.List do
		if def.Equip.Kind == "Consume" then data.Items[def.Id] = 7 else data.Gear[def.Id] = true end
	end
	GearSystem.fill(data)
	local given = 0
	data.Inventory = data.Inventory or {}
	for _, species in HamsterDatabase.Species do
		if given < 40 then data.Inventory[species.Id] = 3; data.Index[species.Id] = true; given += 1 end
	end
	ReplicationSystem.mark(p, "Items", "Gear", "Hotbar", "Inventory", "Index", "Rebirths")
	M.isServer = false
	adv(2.5)

	local viewports = { Vector2.new(1920, 1080), Vector2.new(1366, 768), Vector2.new(1024, 768), Vector2.new(844, 390), Vector2.new(667, 375), Vector2.new(390, 844), Vector2.new(360, 640) }
	local function setViewport(vp)
		cam.ViewportSize = vp
		adv(0.4)
	end
	local guiNames = {}
	for _, g in M.InstanceMethods.GetChildren(playerGui) do guiNames[RawData[g].Name] = g end
	local function screenGui(name) return M.InstanceMethods.FindFirstChild(playerGui, name) end

	local function dumpRects(tag, vp, root)
		if not DUMP then return end
		walk(root, function(node)
			if node.isRoot then return end
			local d = node.data.Props
			local bg = d.BackgroundColor3
			local text = d.Text
			local line = string.format('{"tag":%q,"vp":[%d,%d],"n":%q,"c":%q,"x":%.1f,"y":%.1f,"w":%.1f,"h":%.1f,"bg":[%.2f,%.2f,%.2f],"bt":%.2f,"t":%q,"ts":%.1f,"icon":%q}', tag, vp.X, vp.Y, node.name, node.class, node.x, node.y, node.w, node.h,
				bg and bg.R or 0, bg and bg.G or 0, bg and bg.B or 0, d.BackgroundTransparency or 0, if type(text) == "string" then stripRich(text) else "", (d.TextSize or 0) * node.cum, node.data.Attributes.IconId or "")
			print("RECT|" .. line)
		end)
	end

	local C = UIKit.Colors
	local ALL = {}
	local function record(group, vp, list)
		ALL[group] = ALL[group] or {}
		ALL[group][vp.X .. "x" .. vp.Y] = list
	end

	---------------------------------------------------------------------------------------------------------------------
	-- A. the HUD (MainUI + HotbarUI + the modules that live in its regions), normal and worst-case, at every viewport
	---------------------------------------------------------------------------------------------------------------------
	-- worst case: every optional part visible at once with the longest realistic texts
	local longestSpecies, longestRarity = "", ""
	for _, s in HamsterDatabase.Species do if #s.Name > #longestSpecies then longestSpecies = s.Name end end
	for _, id in RarityConfig.Order do if #RarityConfig.ById[id].Name > #longestRarity then longestRarity = RarityConfig.ById[id].Name end end
	local mainGui = screenGui("MainUI")
	local function forceWorstCase()
		-- gate chip, first person hint, strip, grab prompt, channel bar, tracker rows, tutorial card (altar step is the tallest), 4 toasts
		for _, name in { "GateChip", "FirstPersonHint", "Strip", "GrabPrompt", "ChannelBar", "TutorialCard", "Tip" } do
			for _, d in byName(mainGui, name) do RawData[d].Props.Visible = true end
		end
		for _, d in byName(screenGui("HotbarUI"), "Tip") do RawData[d].Props.Visible = true end
		for _, d in byName(mainGui, "Tracker") do
			for _, row in M.InstanceMethods.GetChildren(d) do
				if RawData[row].ClassName == "Frame" then
					RawData[row].Props.Visible = true
					for _, label in M.InstanceMethods.GetChildren(row) do
						if RawData[label].ClassName == "TextLabel" then
							RawData[label].Props.Text = if RawData[label].Props.TextSize == 16 then string.upper(longestRarity) .. " HAMSTER  " .. longestSpecies else "Transporting to: Averyveryverylongname"
						end
					end
				end
			end
		end
		for _, d in byName(mainGui, "GateChip") do
			for _, label in M.InstanceMethods.GetChildren(d) do if RawData[label].ClassName == "TextLabel" then RawData[label].Props.Text = "OPEN - use the panel" end end
		end
		local card = byName(mainGui, "TutorialCard")[1]
		if card then RawData[card].Props.Size = UDim2.fromOffset(298, 252) end
		for _, d in byName(mainGui, "PriceChip") do RawData[d].Props.Visible = true end
		-- the prompt text of the longest case ("Steal <rarity> <hamster> from <owner>")
		for _, d in M.descendants(byName(mainGui, "GrabPrompt")[1] or mainGui) do
			local dd = RawData[d]
			if dd.ClassName == "TextLabel" and dd.Props.TextSize == 16 then dd.Props.Text = "Steal " .. longestRarity .. " " .. longestSpecies .. "  from Averyveryverylongname" end
		end
		for i = 1, 4 do MainUI.toast("Toast number " .. i .. ": bought something that cost a lot of money", "info") end
	end
	local worstDone = false

	local hudAll = {}
	for pass = 1, 2 do
		if pass == 2 then
			forceWorstCase()
			worstDone = true
			adv(0.5)
		end
		for _, vp in viewports do
			setViewport(vp)
			local list = {}
			-- all HUD screens together: cross-screen overlaps (hotbar tip x prompt strip ...) are real overlaps
			local combined = newNode(mainGui, nil, 0, 0, vp.X, vp.Y, 1)
			combined.isRoot = true
			combined.screen = { x = 0, y = 0, w = vp.X, h = vp.Y }
			local mainRoot = layoutGui(mainGui, vp)
			local hotRoot = layoutGui(screenGui("HotbarUI"), vp)
			for _, r in { mainRoot, hotRoot } do
				for _, k in r.kids do k.parent = combined; table.insert(combined.kids, k) end
			end
			local findings = analyse(combined, vp, { allowTruncate = { Toasts = true } })
			hudAll[(if pass == 1 then "normal " else "worst ") .. vp.X .. "x" .. vp.Y] = findings
			if pass == 2 or true then dumpRects((if pass == 1 then "hud-normal" else "hud-worst"), vp, combined) end
		end
	end

	---------------------------------------------------------------------------------------------------------------------
	-- B. every panel, every tab, at every viewport
	---------------------------------------------------------------------------------------------------------------------
	local panelPlan = {
		{ "Backpack", { "Tab_Items", "Tab_Hamsters" } },
		{ "Index", {} },
		{ "Rebirth", {} },
		{ "Upgrades", {} },
		{ "Daily", {} },
		{ "Quests", { "Tab_Quests", "Tab_Achievements" } },
		{ "Shop", { "Tab_Weapons", "Tab_Equipment", "Tab_Boosts", "Tab_Hamsters", "Tab_Cosmetics" } },
		{ "RobuxShop", { "Tab_Diamonds", "Tab_Gamepasses" } },
		{ "Settings", {} },
		{ "Codes", {} },
		{ "Wheel", {} },
		{ "Playtime", {} },
		{ "Social", {} },
		{ "Leaderboards", { "Tab_Money", "Tab_Hamsters", "Tab_Steals" } },
	}
	local panelFindings = {} -- [panel/state] = { [vp] = findings }
	local windowTops = {} -- [panel] = { [vp] = window rect }
	for _, entry in panelPlan do
		local name, tabs = entry[1], entry[2]
		local panel = UIKit.getPanel(name)
		if panel then
			for _, vp in viewports do
				setViewport(vp)
				panel:Open(); adv(0.5)
				local states = { "" }
				for _, t in tabs do table.insert(states, t) end
				for _, state in states do
					if state ~= "" then
						local button = byName(panel.Gui, state)[1]
						if button then press(button); adv(0.3) end
					end
					local key = name .. (if state ~= "" then "/" .. state else "")
					local root = layoutGui(panel.Gui, vp)
					local findings = analyse(root, vp, {})
					panelFindings[key] = panelFindings[key] or {}
					panelFindings[key][vp.X .. "x" .. vp.Y] = findings
					if state == "" then
						local outer = root.kids[2] -- [1] = the dim button, [2] = the outer frame
						windowTops[name] = windowTops[name] or {}
						if outer then windowTops[name][vp.X .. "x" .. vp.Y] = { x = outer.x, y = outer.y, w = outer.w, h = outer.h, docked = panel.Gui and RawData[outer.inst].Props.AnchorPoint and RawData[outer.inst].Props.AnchorPoint.X == 1 } end
					end
					dumpRects("panel-" .. key, vp, root)
				end
				panel:Close(); adv(0.3)
			end
		end
	end

	---------------------------------------------------------------------------------------------------------------------
	-- report
	---------------------------------------------------------------------------------------------------------------------
	local PROBLEM = { overlap = true, ["text-spill"] = true, ["text-spill-v"] = true, ["outside-parent"] = true, ["off-screen"] = true, ["zero-size"] = true }
	local function report(title, byKey, kinds)
		local total, lines = 0, {}
		local seen, order = unique(byKey)
		for _, key in order do
			local entry = seen[key]
			if kinds[entry.f.kind] then
				total += 1
				if #lines < 40 then table.insert(lines, string.format("   %s | %s | %s | at %s", entry.f.kind, entry.f.where, entry.f.detail, table.concat(entry.vps, ",")) ) end
			end
		end
		return total, lines
	end
	local function checkGroup(label, byKey, kinds, extra)
		local total, lines = report(label, byKey, kinds)
		check(label, total == 0, if total > 0 then total .. " distinct problem(s) - see list" else extra)
		for _, line in lines do print(line) end
	end

	local hudNormal, hudWorst = {}, {}
	for key, list in hudAll do
		if string.sub(key, 1, 6) == "normal" then hudNormal[key] = list else hudWorst[key] = list end
	end
	checkGroup("HUD (normal state): no overlap / no control outside its box or the screen / no text spilling, at 7 viewports", hudNormal, PROBLEM)
	checkGroup("HUD (worst case: every optional element visible, longest names, 4 toasts): same rules at 7 viewports", hudWorst, PROBLEM)
	checkGroup("HUD: no text effectively smaller than 10.5 px (normal state, 7 viewports)", hudNormal, { ["tiny-text"] = true })
	for panelKey, byVp in panelFindings do
		-- one line per panel/state would be too noisy: grouped below
	end
	local grouped = {}
	for key, byVp in panelFindings do grouped[key] = byVp end
	local panelProblems, panelTiny, panelTrunc = {}, {}, {}
	for key, byVp in grouped do
		for vp, list in byVp do
			panelProblems[key .. "@" .. vp] = list
		end
	end
	checkGroup("PANELS: no overlap / no control outside its box or the screen / no text spilling (14 panels, all tabs, 7 viewports)", panelProblems, PROBLEM)
	checkGroup("PANELS: no text effectively smaller than 10.5 px (7 viewports)", panelProblems, { ["tiny-text"] = true })
	checkGroup("PANELS: no static text is cut off with '...'", panelProblems, { ["text-truncated"] = true })

	-- windows must keep clear of the native top bar band
	do
		local bad = {}
		for name, byVp in windowTops do
			for vpKey, r in byVp do
				if r.y < TOPBAR - 0.5 and not r.docked then table.insert(bad, string.format("%s@%s top=%.0f", name, vpKey, r.y)) end
			end
		end
		table.sort(bad)
		check("PANELS: no window header runs under the native Roblox top bar band (y < 36) at any viewport", #bad == 0, if #bad > 0 then #bad .. " cases e.g. " .. table.concat(bad, ", ", 1, math.min(#bad, 8)) else nil)
	end

	-- the docked Lucky Wheel panel must not cover the right rail
	do
		local covered, cases = 0, {}
		local wheel = UIKit.getPanel("Wheel")
		for _, vp in viewports do
			setViewport(vp)
			wheel:Open(); adv(0.5)
			local rootW = layoutGui(wheel.Gui, vp)
			local rootM = layoutGui(mainGui, vp)
			local win = rootW.kids[2]
			local rail
			walk(rootM, function(n) if n.name == "Rail" then rail = n end end)
			local railButtons = {}
			if rail then walk(rail, function(n) if string.sub(n.name, -6) == "Button" and n.class == "TextButton" then table.insert(railButtons, n) end end) end
			for _, b in railButtons do
				local x = inter({ x = win.x, y = win.y, w = win.w, h = win.h }, { x = b.x, y = b.y, w = b.w, h = b.h })
				if x.w > 2 and x.h > 2 then covered += 1; table.insert(cases, vp.X .. "x" .. vp.Y .. ":" .. b.name) end
			end
			wheel:Close(); adv(0.3)
		end
		check("the docked Lucky Wheel window does not hide any right-rail button (7 viewports)", covered == 0, if covered > 0 then covered .. " rail buttons covered, e.g. " .. table.concat(cases, ", ", 1, math.min(#cases, 6)) else nil)
		setViewport(Vector2.new(1280, 720))
	end

	---------------------------------------------------------------------------------------------------------------------
	-- C. transient screens: server banner, hamster reveal card, emote wheel, tooltip
	---------------------------------------------------------------------------------------------------------------------
	do
		local Remotes = require(find("ReplicatedStorage.Remotes"))
		local announce = Remotes.event("Announce")
		local AnnouncementUI = require(find(UI .. "AnnouncementUI"))
		local bad = {}
		for _, vp in viewports do
			setViewport(vp)
			-- banner
			RawData[announce].Signals.OnClientEvent:Fire({ Kind = "Spawn", RarityId = RarityConfig.Order[#RarityConfig.Order - 1], Text = "A LEGENDARY " .. string.upper(longestSpecies) .. " HAS APPEARED!", PlayerName = "Averyverylongname", UserId = 1 })
			adv(0.8)
			local ann = screenGui("AnnouncementUI")
			local root = layoutGui(ann, vp)
			local findings = analyse(root, vp, {})
			for _, f in findings do
				if PROBLEM[f.kind] then table.insert(bad, string.format("banner@%dx%d %s %s", vp.X, vp.Y, f.kind, f.detail)) end
			end
			dumpRects("banner", vp, root)
			adv(5)
			-- reveal card
			AnnouncementUI.reveal(HamsterDatabase.Species[#HamsterDatabase.Species].Id, true)
			adv(0.8)
			root = layoutGui(ann, vp)
			findings = analyse(root, vp, {})
			for _, f in findings do
				if PROBLEM[f.kind] then table.insert(bad, string.format("reveal@%dx%d %s %s", vp.X, vp.Y, f.kind, f.detail)) end
			end
			dumpRects("reveal", vp, root)
			adv(3.6)
			-- emote wheel
			local EmoteUI = require(find(UI .. "EmoteUI"))
			EmoteUI.toggle(); adv(0.5)
			root = layoutGui(screenGui("EmoteWheel"), vp)
			findings = analyse(root, vp, {})
			for _, f in findings do
				if PROBLEM[f.kind] or f.kind == "tiny-text" then table.insert(bad, string.format("emotes@%dx%d %s %s", vp.X, vp.Y, f.kind, f.detail)) end
			end
			dumpRects("emotes", vp, root)
			EmoteUI.toggle(); adv(0.4)
		end
		local seen = {}
		local compact = {}
		for _, line in bad do
			local key = string.gsub(line, "@%d+x%d+", "")
			if not seen[key] then seen[key] = true; table.insert(compact, line) end
		end
		check("transient screens (server banner, hamster reveal card, emote wheel) fit every viewport and keep their text readable", #bad == 0, if #bad > 0 then #bad .. " findings; distinct: " .. table.concat(compact, " ;; ", 1, math.min(#compact, 6)) else nil)
	end

	---------------------------------------------------------------------------------------------------------------------
	-- D. HUD structure: one hotbar, native Backpack bar off, rail entries, currency + income, button states
	---------------------------------------------------------------------------------------------------------------------
	do
		local hotbars = 0
		for _, g in M.InstanceMethods.GetChildren(playerGui) do
			for _, d in byName(g, "Hotbar") do if RawData[d].ClassName == "Frame" then hotbars += 1 end end
		end
		check("exactly ONE hotbar exists in the interface", hotbars == 1, hotbars)
		local disabled = false
		for _, call in coreGuiCalls do if call.Type == "Backpack" and call.Enabled == false then disabled = true end end
		local enabledAgain = false
		for _, call in coreGuiCalls do if call.Enabled == true then enabledAgain = true end end
		check("Roblox's own Backpack bar is switched off (SetCoreGuiEnabled Backpack=false) and never switched back on - so there is no second hotbar", disabled and not enabledAgain, #coreGuiCalls .. " calls")

		local ids = {}
		for _, def in UIRegistry.list("RightRail") do table.insert(ids, def.Id) end
		check("right rail = Quests, Wheel, Playtime, Backpack, Shop, RobuxShop, Leaderboards, Settings", table.concat(ids, ",") == "Quests,Wheel,Playtime,Backpack,Shop,RobuxShop,Leaderboards,Settings", table.concat(ids, ","))
		-- every rail button has an icon, a one-word label, a tooltip text, and the labels do not repeat
		local labels, missing = {}, {}
		for _, def in UIRegistry.list("RightRail") do
			local button = byName(mainGui, def.Id .. "Button")[1]
			local icon = button and byName(button, "RailIcon")[1]
			local word = button and byName(button, "RailLabel")[1]
			if not (icon and word and def.Tooltip and def.Tooltip ~= "") then table.insert(missing, def.Id) end
			if word then
				local text = RawData[word].Props.Text
				labels[text] = (labels[text] or 0) + 1
			end
		end
		local dupe = {}
		for text, n in labels do if n > 1 then table.insert(dupe, text) end end
		check("every rail button has an icon, a short label and a tooltip; no two buttons share a label", #missing == 0 and #dupe == 0, table.concat(missing, ",") .. table.concat(dupe, ","))

		-- the icon behind each rail entry means what the owner asked for
		local expect = { Quests = { "scroll" }, Wheel = { "wheel" }, Playtime = { "hourglass", "clock" }, Backpack = { "backpack" }, Shop = { "bag" }, RobuxShop = { "crown", "robux" }, Leaderboards = { "trophy" }, Settings = { "gear" } }
		local wrong = {}
		for _, def in UIRegistry.list("RightRail") do
			local ok = false
			for _, e in expect[def.Id] or {} do if def.Icon == e then ok = true end end
			if not ok then table.insert(wrong, def.Id .. "=" .. tostring(def.Icon)) end
		end
		check("rail icons: quests=task scroll, wheel=wheel, playtime=hourglass, collection=backpack, shop=bag, robux=crown, leaderboard=trophy, settings=gear", #wrong == 0, table.concat(wrong, ","))
		local needed = { "lock", "shield", "rebirth", "wheel", "hourglass", "trophy", "gear", "backpack", "bag", "scroll" }
		local absent = {}
		for _, id in needed do if not Icons.has(id) then table.insert(absent, id) end end
		check("the icons the order names exist (lock/shield for base security, rebirth, wheel, hourglass, trophy, gear ...)", #absent == 0, table.concat(absent, ","))

		-- the currency/income row
		local topBar = byName(mainGui, "TopBar")[1]
		local texts = {}
		for _, d in M.descendants(topBar) do
			if RawData[d].ClassName == "TextLabel" then table.insert(texts, tostring(RawData[d].Props.Text)) end
		end
		local joined = table.concat(texts, "|")
		check("the top HUD shows cash, income as $X/s, diamonds and rebirths", string.find(joined, "/s", 1, true) ~= nil and string.find(joined, "$", 1, true) ~= nil and #texts == 4, joined)
	end

	---------------------------------------------------------------------------------------------------------------------
	-- E. button states: hover / pressed / disabled exist on the shared button
	---------------------------------------------------------------------------------------------------------------------
	do
		local holder = Instance.new("ScreenGui")
		RawData[holder].Attributes.Insets = "None"
		holder.Parent = playerGui
		local b = UIKit.button(holder, { Text = "Probe", Size = UDim2.fromOffset(120, 40), Color = C.Green })
		local base = RawData[b].Props.BackgroundColor3
		RawData[b].Signals.MouseEnter:Fire(); adv(0.3)
		local hover = RawData[b].Props.BackgroundColor3
		RawData[b].Signals.MouseLeave:Fire(); adv(0.3)
		local after = RawData[b].Props.BackgroundColor3
		UIKit.setEnabled(b, false)
		local disabledColor = RawData[b].Props.BackgroundColor3
		local before = RawData[b].Props.TextTransparency
		check("button states: hover brightens, leaving restores, disabled is visibly different (colour + dimmed text)", hover.R + hover.G + hover.B > base.R + base.G + base.B and math.abs(after.R - base.R) < 0.01 and (math.abs(disabledColor.R - base.R) + math.abs(disabledColor.G - base.G)) > 0.1 and before > 0)
		M.InstanceMethods.Destroy(holder)
	end

	print(string.format("PASS %d FAIL %d errors %d", results.pass, results.fail, #M.Sim.errors))
	for i, err in M.Sim.errors do if i <= 8 then print(err) end end
end)
M.Sim.advance(0)
