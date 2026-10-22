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

-- The width model is an ESTIMATE (+-10 %): text is only reported as too wide / cut off when it is more than OVER times the label size.
local OVER = 1.12
local ICON_MIN = 14 -- px: below this a drawn icon is a smudge
local TAP_MIN = 36 -- px: smallest comfortable touch target (Roblox's own touch buttons are ~50, platform guidelines say 44)

-- Text metrics of one label at `availW` pixels of width. Returns { w, h, lines, truncated, spill (px beyond the label, horizontal), spillV }
local function measureText(data, availW: number, availH: number, cum: number)
	local props = data.Props
	local text = props.Text
	if type(text) ~= "string" or text == "" then return nil end
	if props.RichText == true then text = stripRich(text) end -- (Roblox default is RichText = false; UIKit.label turns it on)
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
	local spill, spillV, ratio = 0, 0, 0
	if wrapped then
		ratio = h / math.max(availH, 1)
		if h > availH + 2 then
			if truncate == "AtEnd" then
				truncated = ratio > OVER
				h = math.max(size, math.floor(availH / size) * size)
			else
				spillV = h - availH
			end
		end
	else
		ratio = widest / math.max(availW, 1)
		if widest > availW + 1 then
			if truncate == "AtEnd" then
				truncated = ratio > OVER
				widest = availW
			else
				spill = widest - availW
			end
		end
	end
	return { w = widest, h = h, lines = lines, truncated = truncated, spill = spill, spillV = spillV, size = size, ratio = ratio }
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
		kid.sib = entry.index -- (draw order among siblings = creation order)
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
		if horizontal and l.Wraps == true then
			-- wrapping row layout (UIListLayout.Wraps): a child that no longer fits on the row starts the next row
			local rows, current, used = {}, {}, 0
			for index in kids do
				local s = sized[index]
				if #current > 0 and used + gap + s.w > cw + 0.01 then
					table.insert(rows, { items = current, w = used })
					current, used = {}, 0
				end
				used += (if #current > 0 then gap else 0) + s.w
				table.insert(current, index)
			end
			if #current > 0 then table.insert(rows, { items = current, w = used }) end
			local y = cy
			for _, row in rows do
				local rowH = 0
				for _, index in row.items do rowH = math.max(rowH, sized[index].h) end
				local x = cx
				if halign == "Center" then x = cx + (cw - row.w) / 2 elseif halign == "Right" then x = cx + cw - row.w end
				for _, index in row.items do
					local s = sized[index]
					make(kids[index], x, y, s.w, s.h, s.own)
					x += s.w + gap
				end
				y += rowH + gap
			end
			node.listTotal = y - cy - gap
			node.wrapRows = #rows
			return
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
				local xa = enumName(data.Props.TextXAlignment, "Center") -- (Roblox default for TextLabel / TextButton / TextBox is Center; UIKit.label sets Left explicitly)
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

	-- (a) text that does not fit / is too small; icons too small to recognise
	for _, c in items do
		local node = c.node
		if c.kind == "icon" and math.min(node.w, node.h) < ICON_MIN then
			add("tiny-icon", node, string.format("icon %s is %.0fx%.0f px effective (< %d px)", node.name, node.w, node.h, ICON_MIN))
		end
		if c.kind == "text" then
			local m = c.metrics
			local label = string.sub(c.text, 1, 28)
			if m.spill > 2 and m.ratio > OVER then add("text-spill", node, string.format("'%s' needs ~%.0f px, label is %.0f px wide (spills %.0f)", label, m.w, node.w, m.spill)) end
			if m.spill > 2 and m.ratio <= OVER then add("text-borderline", node, string.format("'%s' needs ~%.0f px, label is %.0f px wide (estimate within %.0f%%: check in Studio)", label, m.w, node.w, (m.ratio - 1) * 100)) end
			if m.spillV > 3 and m.ratio > OVER then add("text-spill-v", node, string.format("'%s' needs ~%.0f px height (%d lines), label is %.0f px high", label, m.h, m.lines, node.h)) end
			if m.truncated and not (opts.allowTruncate and opts.allowTruncate[node.name]) then add("text-truncated", node, string.format("'%s' (%d lines, size %.1f) is cut off at %.0fx%.0f", label, m.lines, m.size, node.w, node.h)) end
			if m.size < 10.5 then add("tiny-text", node, string.format("'%s' is %.1f px effective", label, m.size)) end
		end
		-- (b) beyond the screen
		local r = c.rect
		-- only the part that is actually DRAWN counts (scroll frames / canvas groups clip the rest away)
		local clip = c.node.clip
		local visibleRect = if clip then inter(r, clip) else r
		if visibleRect.w > 1 and visibleRect.h > 1 and (visibleRect.x < screen.x - 1 or visibleRect.y < screen.y - 1 or visibleRect.x + visibleRect.w > screen.x + screen.w + 1 or visibleRect.y + visibleRect.h > screen.y + screen.h + 1) then
			add("off-screen", node, string.format("rect x%.0f y%.0f w%.0f h%.0f on a %dx%d screen", r.x, r.y, r.w, r.h, viewport.X, viewport.Y))
		end
	end

	-- (c) children sticking out of their container (the nearest ancestor that clips or has a visible fill), scroll axis excluded
	for _, c in items do
		local node = c.node
		local r = c.rect
		local cur = node.parent
		local depth = 0
		if c.kind == "hit" then cur = nil end -- (an invisible tap area may be bigger than its control on purpose, e.g. the slider handle)
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
							-- a text CHIP (solid background) lying on a picture is a badge on a picture; text on text / icon on text is a collision
							local function isChip(c) return c.kind == "text" and (c.node.data.Props.BackgroundTransparency or 0) < 0.5 end
							local function isPicture(c) return c.kind == "icon" or c.kind == "image" end
							local kind = if (isChip(a) and isPicture(b)) or (isChip(b) and isPicture(a)) then "overlap-badge" else "overlap"
							add(kind, a.node, string.format("%s x %s overlap %.0fx%.0f px (%s | %s)", da, db, vis.w, vis.h, pathOf(a.node), pathOf(b.node)))
						end
					end
				end
			end
		end
	end
	-- (e) solid boxes (cards, chips, windows with a fill) that cover each other without being parent / child, and tappable controls whose
	--     boxes overlap (the one on top steals the taps of the one below, e.g. a tab hidden behind a list)
	local boxes, controls = {}, {}
	walk(root, function(node)
		if node.isRoot or isBackdrop(node) or node.data.Attributes.IconId then return end
		if node.w < 1 or node.h < 1 then return end
		local p = node.data.Props
		local visibleRect = { x = node.x, y = node.y, w = node.w, h = node.h }
		if node.clip then visibleRect = inter(visibleRect, node.clip) end
		if visibleRect.w < 1 or visibleRect.h < 1 then return end
		local item = { node = node, rect = visibleRect }
		if node.class == "TextButton" or node.class == "ImageButton" then table.insert(controls, item) end
		local solidClass = node.class == "Frame" or node.class == "TextLabel" or node.class == "TextButton" or node.class == "CanvasGroup" or node.class == "ImageLabel" or node.class == "ImageButton"
		if solidClass and (p.BackgroundTransparency or 0) <= 0.5 and node.w >= 16 and node.h >= 16 then table.insert(boxes, item) end
	end)
	local function pairsOverlap(list, kind, label, fraction)
		table.sort(list, function(a, b) return a.rect.x < b.rect.x end)
		for i = 1, #list do
			local a = list[i]
			for j = i + 1, #list do
				local b = list[j]
				if b.rect.x >= a.rect.x + a.rect.w then break end
				-- (siblings of one parent are layered on purpose for BOXES - slider knob on its fill, accent edge, stripes -; buttons are still compared)
				local layered = kind == "overlap-box" and a.node.parent == b.node.parent
				if not layered and not isAncestor(a.node, b.node) and not isAncestor(b.node, a.node) and not (opts.allow and (opts.allow[a.node.name] or opts.allow[b.node.name])) then
					local x = inter(a.rect, b.rect)
					if x.w >= 4 and x.h >= 4 then
						local smaller = math.min(area(a.rect), area(b.rect))
						if smaller > 0 and area(x) >= fraction * smaller then
							add(kind, a.node, string.format("%s %s x %s overlap %.0fx%.0f px = %.0f%% of the smaller (%s | %s)", label, a.node.name, b.node.name, x.w, x.h, 100 * area(x) / smaller, pathOf(a.node), pathOf(b.node)))
						end
					end
				end
			end
		end
	end
	-- (g) text lying UNDER a solid box that is drawn later (a later sibling / higher ZIndex): the player cannot read it
	local function chain(node)
		local list = {}
		local cur = node
		while cur and not cur.isRoot do
			table.insert(list, 1, cur)
			cur = cur.parent
		end
		return list
	end
	local function drawnAbove(a, b)
		local ca, cb = chain(a), chain(b)
		for i = 1, math.min(#ca, #cb) do
			local x, y = ca[i], cb[i]
			if x ~= y then
				local zx, zy = x.data.Props.ZIndex or 1, y.data.Props.ZIndex or 1
				if zx ~= zy then return zx > zy end
				return (x.sib or 0) > (y.sib or 0)
			end
		end
		return #ca > #cb
	end
	for _, c in items do
		if c.kind == "text" and (c.node.data.Props.TextTransparency or 0) < 0.5 then
			local t = c.rect
			local tClip = c.node.clip
			local tVisible = if tClip then inter(t, tClip) else t
			if tVisible.w > 2 and tVisible.h > 2 then
				for _, b in boxes do
					local bn = b.node
					if bn ~= c.node and not isAncestor(bn, c.node) and not isAncestor(c.node, bn) and not (opts.allow and (opts.allow[bn.name] or opts.allow[c.node.name])) then
						local x = inter(tVisible, b.rect)
						if x.w > 2 and x.h > 2 and area(x) >= 0.25 * area(tVisible) and drawnAbove(bn, c.node) then
							add("text-covered", c.node, string.format("'%s' is %.0f%% covered by %s drawn on top of it (%s)", string.sub(c.text, 1, 20), 100 * area(x) / area(tVisible), bn.name, pathOf(bn)))
							break
						end
					end
				end
			end
		end
	end
	pairsOverlap(boxes, "overlap-box", "boxes", 0.25)
	pairsOverlap(controls, "overlap-controls", "buttons", 0.25)
	-- (f) tap targets: a button smaller than TAP_MIN px (effective, after every UIScale) is hard to hit with a finger
	for _, c in controls do
		local n = c.node
		if math.min(n.w, n.h) < TAP_MIN and not (opts.allow and opts.allow[n.name]) then
			add("tap-small", n, string.format("button %s is %.0fx%.0f px effective (< %d px)", n.name, n.w, n.h, TAP_MIN))
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
			local present = false
			for _, existing in seen[key].vps do if existing == vp then present = true end end
			if not present then table.insert(seen[key].vps, vp) end
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
	-- model (the one UIKit.responsive documents): a UIScale multiplies the Size AND Position offsets of its parent object and of everything inside it.
		-- H: position (10,20) -> (20,40); size 100 -> 200. I: 0.5*200 + 10*2 = 120 wide, 20*2 = 40 high, offset (5,5)*2 = (10,10) from H.
		check("self-test: UIScale doubles size and position offsets (outer 100x100 -> 200x200 at 20,40; inner 120x40 at 30,50)", H.w == 200 and H.h == 200 and H.x == 20 and H.y == 40 and I.w == 120 and I.h == 40 and I.x == 30 and I.y == 50, string.format("%s %s %s %s %s", H.w, I.w, I.h, I.x, I.y))
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
	local _, root11 = gui(function(g)
		local row = mk("Frame", { Size = UDim2.fromOffset(214, 62), Position = UDim2.fromOffset(100, 100), BackgroundTransparency = 1, Name = "W" }, g)
		mk("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), Wraps = true }, row)
		for _ = 1, 3 do mk("Frame", { Size = UDim2.fromOffset(69, 28) }, row) end
		mk("Frame", { Size = UDim2.fromOffset(214, 28) }, row)
	end)
	local W = root11.kids[1]
	check("self-test: a wrapping list breaks 3x69 px + 2 gaps (215 px) out of a 214 px row, and the 214 px child gets its own row (3 rows, 92 px tall)", W.wrapRows == 3 and W.kids[3].y == 100 + 32 and W.kids[4].y == 100 + 64 and W.listTotal == 92, tostring(W.wrapRows) .. " rows, total " .. tostring(W.listTotal))
	local R = root10.kids[1]
	check("self-test: a centred horizontal list puts two 50 px children + a 10 px gap in the middle of 300 px", R.kids[1].x == 100 + 95 and R.kids[2].x == 100 + 155 and R.kids[1].y == 110, string.format("%s %s %s", R.kids[1].x, R.kids[2].x, R.kids[1].y))
	-- solid boxes / buttons that cover each other, chips on pictures, small tap targets
	local f12 = gui(function(g)
		local left = mk("Frame", { Size = UDim2.fromOffset(300, 200), Position = UDim2.fromOffset(100, 100), BackgroundTransparency = 1 }, g)
		local right = mk("Frame", { Size = UDim2.fromOffset(300, 200), Position = UDim2.fromOffset(140, 120), BackgroundTransparency = 1 }, g)
		mk("Frame", { Size = UDim2.fromOffset(100, 60), BackgroundColor3 = Color3.new(0.2, 0.2, 0.2) }, left)
		mk("Frame", { Size = UDim2.fromOffset(100, 60), BackgroundColor3 = Color3.new(0.3, 0.3, 0.3) }, right)
	end)
	check("self-test: two solid boxes of different containers covering each other are reported", countOf(f12, { ["overlap-box"] = true }) == 1)
	local f12b = gui(function(g)
		local bar = mk("Frame", { Size = UDim2.fromOffset(200, 20), Position = UDim2.fromOffset(100, 100), BackgroundColor3 = Color3.new(0.2, 0.2, 0.2) }, g)
		mk("Frame", { Size = UDim2.fromOffset(120, 20), BackgroundColor3 = Color3.new(1, 1, 0) }, bar) -- fill
		mk("Frame", { Size = UDim2.fromOffset(24, 24), Position = UDim2.fromOffset(110, -2), BackgroundColor3 = Color3.new(1, 1, 1) }, bar) -- knob: layered on purpose
	end)
	check("self-test: a slider knob on its fill (siblings layered on purpose) is NOT an overlap", countOf(f12b, { ["overlap-box"] = true }) == 0)
	local f13 = gui(function(g)
		local card = mk("Frame", { Size = UDim2.fromOffset(100, 60), Position = UDim2.fromOffset(100, 100), BackgroundColor3 = Color3.new(0.2, 0.2, 0.2) }, g)
		mk("Frame", { Size = UDim2.fromOffset(20, 60), BackgroundColor3 = Color3.new(1, 0, 0) }, card) -- an accent edge inside its card
		mk("Frame", { Size = UDim2.fromOffset(100, 60), Position = UDim2.fromOffset(200, 100), BackgroundColor3 = Color3.new(0.3, 0.3, 0.3) }, g) -- a neighbour that only touches
	end)
	check("self-test: a child inside its card and a touching neighbour are NOT overlaps", countOf(f13, { ["overlap-box"] = true }) == 0)
	local f14 = gui(function(g)
		mk("TextButton", { Size = UDim2.fromOffset(120, 40), Position = UDim2.fromOffset(100, 100), Text = "Rewards", TextSize = 14, Font = text }, g)
		mk("TextButton", { Size = UDim2.fromOffset(120, 44), Position = UDim2.fromOffset(100, 104), Text = "", BackgroundTransparency = 0.2 }, g)
	end)
	check("self-test: a button lying under another button is reported (overlap-controls)", countOf(f14, { ["overlap-controls"] = true }) == 1)
	local f15 = gui(function(g)
		mk("ImageLabel", { Size = UDim2.fromOffset(80, 60), Position = UDim2.fromOffset(100, 100), Image = "rbxassetid://1" }, g)
		mk("TextLabel", { Size = UDim2.fromOffset(60, 18), Position = UDim2.fromOffset(100, 100), Text = "OWNED", TextSize = 12, Font = text, BackgroundColor3 = Color3.new(0, 0.8, 0.2), TextXAlignment = Enum.TextXAlignment.Center }, g)
	end)
	check("self-test: a status chip lying on a picture is an overlap-badge (not a text collision)", countOf(f15, { ["overlap-badge"] = true }) == 1 and countOf(f15, { overlap = true }) == 0)
	local f16 = gui(function(g)
		mk("TextButton", { Size = UDim2.fromOffset(20, 20), Position = UDim2.fromOffset(100, 100), Text = "x", TextSize = 14, Font = text }, g)
		mk("TextButton", { Size = UDim2.fromOffset(44, 44), Position = UDim2.fromOffset(200, 100), Text = "OK", TextSize = 14, Font = text }, g)
	end)
	check("self-test: a 20 px button is a small tap target, a 44 px button is not", countOf(f16, { ["tap-small"] = true }) == 1)
	local f18 = gui(function(g)
		local row = mk("Frame", { Size = UDim2.fromOffset(300, 120), Position = UDim2.fromOffset(100, 100), BackgroundTransparency = 1 }, g)
		mk("TextButton", { Size = UDim2.fromOffset(214, 28), Position = UDim2.fromOffset(0, 0), Text = "Rewards", TextSize = 14, Font = text }, row)
		local list = mk("Frame", { Size = UDim2.fromOffset(214, 90), Position = UDim2.fromOffset(0, 10), BackgroundTransparency = 1 }, row) -- created later = drawn on top
		mk("Frame", { Size = UDim2.fromOffset(210, 40), BackgroundColor3 = Color3.new(0.2, 0.2, 0.2) }, list)
	end)
	check("self-test: text hidden under a later-drawn solid box is reported (text-covered)", countOf(f18, { ["text-covered"] = true }) == 1)
	local f19 = gui(function(g)
		local row = mk("Frame", { Size = UDim2.fromOffset(300, 120), Position = UDim2.fromOffset(100, 100), BackgroundTransparency = 1 }, g)
		mk("Frame", { Size = UDim2.fromOffset(210, 40), BackgroundColor3 = Color3.new(0.2, 0.2, 0.2), Position = UDim2.fromOffset(0, 5) }, row)
		mk("TextLabel", { Size = UDim2.fromOffset(200, 28), Position = UDim2.fromOffset(0, 10), Text = "On top", TextSize = 14, Font = text, BackgroundTransparency = 1 }, row)
	end)
	check("self-test: text drawn ABOVE a box (the normal card + label) is not reported", countOf(f19, { ["text-covered"] = true }) == 0)
	-- a text that is only slightly wider than the estimate must NOT fail (the width model is an estimate), a clearly wider one must
	local f17 = gui(function(g)
		mk("TextLabel", { Size = UDim2.fromOffset(100, 24), Position = UDim2.fromOffset(100, 100), Text = "Hello world abc", TextSize = 14, Font = Enum.Font.GothamMedium }, g)
	end)
	check("self-test: a label only a few percent too narrow is 'borderline', not a failure", countOf(f17, { ["text-spill"] = true }) == 0)
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
		local order = 0
		walk(root, function(node)
			if node.isRoot then return end
			order += 1
			local d = node.data.Props
			local bg = d.BackgroundColor3
			local tc = d.TextColor3
			local text = d.Text
			local clip = node.clip
			local line = string.format('{"tag":%q,"vp":[%d,%d],"n":%q,"c":%q,"x":%.1f,"y":%.1f,"w":%.1f,"h":%.1f,"bg":[%.2f,%.2f,%.2f],"bt":%.2f,"t":%q,"ts":%.1f,"tc":[%.2f,%.2f,%.2f],"z":%d,"o":%d,"clip":[%.1f,%.1f,%.1f,%.1f],"icon":%q}', tag, vp.X, vp.Y, node.name, node.class, node.x, node.y, node.w, node.h,
				bg and bg.R or 0, bg and bg.G or 0, bg and bg.B or 0, d.BackgroundTransparency or 0, if type(text) == "string" then stripRich(text) else "", (d.TextSize or 0) * node.cum, tc and tc.R or 1, tc and tc.G or 1, tc and tc.B or 1, d.ZIndex or 1, order,
				clip and clip.x or -1, clip and clip.y or -1, clip and clip.w or -1, clip and clip.h or -1, node.data.Attributes.IconId or "")
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
		for _, d in byName(screenGui("HotbarUI"), "Tip") do
			RawData[d].Props.Visible = true
			-- the hotbar tip card of a selected consumable: longest realistic name + description
			local longestName, longestDesc = "", ""
			for _, def in ItemRegistry.List do
				if #def.DisplayName > #longestName then longestName = def.DisplayName end
				if #(def.Description or "") > #longestDesc then longestDesc = def.Description end
			end
			for _, label in M.InstanceMethods.GetChildren(d) do
				if RawData[label].ClassName == "TextLabel" then
					RawData[label].Props.Text = if RawData[label].Props.TextSize == 15 then longestName .. "  x99" else "Press again to use. " .. longestDesc
				end
			end
		end
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
	-- realistic COMBINATIONS (what a player really sees): a weapon is held (the hotbar tip card stays up) while a prompt, the steal bar or a hint shows
	local function realisticTip()
		for _, d in byName(screenGui("HotbarUI"), "Tip") do
			RawData[d].Props.Visible = true
			for _, label in M.InstanceMethods.GetChildren(d) do
				if RawData[label].ClassName == "TextLabel" then
					RawData[label].Props.Text = if RawData[label].Props.TextSize == 15 then "Mega Slap Glove" else "Your first weapon. Fast, wide slaps."
				end
			end
		end
	end
	local function only(visibleNames)
		for _, name in { "GateChip", "FirstPersonHint", "Strip", "GrabPrompt", "ChannelBar", "TutorialCard", "PriceChip" } do
			for _, d in byName(mainGui, name) do RawData[d].Props.Visible = table.find(visibleNames, name) ~= nil end
		end
		realisticTip()
	end
	local passes = {
		{ name = "normal" },
		{ name = "combo-claim", setup = function() only({ "GrabPrompt", "PriceChip" }) end }, -- weapon in hand + "Claim <hamster>" prompt (the everyday case)
		{ name = "combo-steal", setup = function() only({ "ChannelBar" }) end }, -- weapon in hand + the steal / pick-up progress bar
		{ name = "combo-hint", setup = function() only({ "Strip" }) end }, -- weapon in hand + a hint strip
		{ name = "worst", setup = forceWorstCase },
	}
	local hudAll = {}
	local hudCoverage = {}
	for _, pass in passes do
		if pass.setup then
			pass.setup()
			adv(0.2)
		end
		for _, vp in viewports do
			setViewport(vp)
			-- all HUD screens together: cross-screen overlaps (hotbar tip x prompt strip ...) are real overlaps
			local combined = newNode(mainGui, nil, 0, 0, vp.X, vp.Y, 1)
			combined.isRoot = true
			combined.screen = { x = 0, y = 0, w = vp.X, h = vp.Y }
			local mainRoot = layoutGui(mainGui, vp)
			local hotRoot = layoutGui(screenGui("HotbarUI"), vp)
			for rootIndex, r in { mainRoot, hotRoot } do
				for _, k in r.kids do
					k.parent = combined
					k.sib = (k.sib or 0) + rootIndex * 1000 -- (the hotbar ScreenGui has the higher DisplayOrder: it is drawn above the main HUD)
					table.insert(combined.kids, k)
				end
			end
			local findings = analyse(combined, vp, { allowTruncate = { Toasts = true } })
			hudAll[pass.name .. " " .. vp.X .. "x" .. vp.Y] = findings
			if pass.name == "normal" or pass.name == "combo-claim" then
				-- how much of the screen do the solid HUD boxes cover (6 px grid)?  normal = with the tutorial card, combo-claim = without it but with the prompt + tip
				local cell, covered, total = 6, {}, 0
				walk(combined, function(n)
					if n.isRoot or n.data.Attributes.IconId then return end
					local p = n.data.Props
					if (n.class == "Frame" or n.class == "TextButton" or n.class == "TextLabel" or n.class == "CanvasGroup") and (p.BackgroundTransparency or 0) <= 0.6 and n.w >= 6 and n.h >= 6 then
						for gx = math.max(0, n.x // cell), math.min(vp.X // cell, (n.x + n.w) // cell) do
							for gy = math.max(0, n.y // cell), math.min(vp.Y // cell, (n.y + n.h) // cell) do covered[gx * 10000 + gy] = true end
						end
					end
				end)
				for _ in covered do total += 1 end
				hudCoverage[pass.name .. " " .. vp.X .. "x" .. vp.Y] = total * cell * cell / (vp.X * vp.Y)
			end
			dumpRects("hud-" .. pass.name, vp, combined)
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
	local censusLines = {}
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
						local outer = root.kids[#root.kids] -- (kids = [dim button], outer frame; a docked panel hides its dim button)
						windowTops[name] = windowTops[name] or {}
						if outer then windowTops[name][vp.X .. "x" .. vp.Y] = { x = outer.x, y = outer.y, w = outer.w, h = outer.h, docked = panel.Gui and RawData[outer.inst].Props.AnchorPoint and RawData[outer.inst].Props.AnchorPoint.X == 1 } end
					end
					dumpRects("panel-" .. key, vp, root)
					if state == "" and vp.X == 1366 then
						-- design-system census (info): how many surfaces carry an outline / rounded corners / a gradient
						local boxesN, strokesN, cornersN, gradientsN, instancesN = 0, 0, 0, 0, 0
						for _, d in M.descendants(panel.Gui) do
							local dd = RawData[d]
							instancesN += 1
							if dd.ClassName == "UIStroke" then strokesN += 1 elseif dd.ClassName == "UICorner" then cornersN += 1 elseif dd.ClassName == "UIGradient" then gradientsN += 1
							elseif (dd.ClassName == "Frame" or dd.ClassName == "TextButton" or dd.ClassName == "CanvasGroup") and (dd.Props.BackgroundTransparency or 0) < 0.95 then boxesN += 1 end
						end
						censusLines[name] = string.format("%s: %d instances, %d filled boxes, %d outlines (%.0f%% of boxes), %d rounded corners, %d gradients", name, instancesN, boxesN, strokesN, 100 * strokesN / math.max(1, boxesN), cornersN, gradientsN)
					end
				end
				panel:Close(); adv(0.3)
			end
		end
	end

	---------------------------------------------------------------------------------------------------------------------
	-- report
	---------------------------------------------------------------------------------------------------------------------
	-- LAYOUT = something is hidden, cut off, unreachable or unreadable. Reported per root cause (the same finding at several viewports is one line).
	local LAYOUT = { overlap = true, ["text-covered"] = true, ["overlap-box"] = true, ["overlap-controls"] = true, ["outside-parent"] = true, ["off-screen"] = true, ["zero-size"] = true, ["text-spill"] = true, ["text-spill-v"] = true }
	local function isPhoneKey(key: string): boolean
		local x, y = string.match(key, "(%d+)x(%d+)$")
		return math.min(tonumber(x) or 9999, tonumber(y) or 9999) <= 480
	end
	local function subset(byKey, phone: boolean)
		local out = {}
		for key, list in byKey do
			if isPhoneKey(key) == phone then out[key] = list end
		end
		return out
	end
	local function report(byKey, kinds, limit)
		local total, lines = 0, {}
		local seen, order = unique(byKey)
		for _, key in order do
			local entry = seen[key]
			if kinds[entry.f.kind] then
				total += 1
				if #lines < (limit or 30) then
					local vps = entry.vps
					local shown = table.concat(vps, ",", 1, math.min(#vps, 2)) .. (if #vps > 2 then " (+" .. (#vps - 2) .. " more)" else "")
					table.insert(lines, string.format("   %s | %s | %s | at %s", entry.f.kind, entry.f.where, entry.f.detail, shown))
				end
			end
		end
		return total, lines
	end
	local function checkGroup(label, byKey, kinds, extra)
		local total, lines = report(byKey, kinds)
		check(label, total == 0, if total > 0 then total .. " distinct problem(s) - see list" else extra)
		for _, line in lines do print(line) end
	end

	local hudNormal, hudWorst, hudCombo = {}, {}, {}
	for key, list in hudAll do
		if string.sub(key, 1, 6) == "normal" then hudNormal[key] = list elseif string.sub(key, 1, 5) == "combo" then hudCombo[key] = list else hudWorst[key] = list end
	end
	local panelProblems = {}
	for key, byVp in panelFindings do
		for vp, list in byVp do
			panelProblems[key .. "@" .. vp] = list
		end
	end

	-- three viewport classes: desktop + tablet, phone LANDSCAPE (the default on Roblox phones) and phone PORTRAIT (only reachable when the
	-- experience allows it: StarterGui.ScreenOrientation = Sensor / Portrait; the project does not set it, Roblox's default is landscape)
	local function classOf(key: string): string
		local x, y = string.match(key, "(%d+)x(%d+)$")
		x, y = tonumber(x) or 9999, tonumber(y) or 9999
		if math.min(x, y) > 480 then return "desk" end
		return if x > y then "land" else "port"
	end
	local CLASSES = {
		{ id = "desk", label = "desktop + tablet (1920x1080, 1366x768, 1024x768)" },
		{ id = "land", label = "phone LANDSCAPE (844x390, 667x375)" },
		{ id = "port", label = "phone PORTRAIT (390x844, 360x640)" },
	}
	local function bucket(byKey, class: string)
		local out = {}
		for key, list in byKey do
			if classOf(key) == class then out[key] = list end
		end
		return out
	end
	local function perClass(title: string, byKey, kinds, skipDesk: boolean?)
		for _, class in CLASSES do
			if not (skipDesk and class.id == "desk") then
				checkGroup(title .. " - " .. class.label, bucket(byKey, class.id), kinds)
			end
		end
	end

	print("  -- HUD")
	perClass("HUD (normal state): no overlap, nothing outside its box or the screen", hudNormal, LAYOUT)
	perClass("HUD (a weapon in hand + claim prompt / steal bar / hint strip - the everyday combinations): nothing covers anything", hudCombo, LAYOUT)
	perClass("HUD (worst case: every optional element visible, longest names, 4 toasts)", hudWorst, LAYOUT)
	perClass("HUD: no text smaller than 10.5 px effective", hudNormal, { ["tiny-text"] = true })
	perClass("HUD: every button is at least " .. TAP_MIN .. " px wide and high (finger taps)", hudNormal, { ["tap-small"] = true }, true)
	perClass("HUD: every icon is at least " .. ICON_MIN .. " px", hudNormal, { ["tiny-icon"] = true })
	do
		for _, which in { "normal", "combo-claim" } do
			local parts = {}
			for _, vp in viewports do table.insert(parts, string.format("%dx%d %.0f%%", vp.X, vp.Y, 100 * hudCoverage[which .. " " .. vp.X .. "x" .. vp.Y])) end
			print("  [info] share of the screen covered by solid HUD boxes (" .. (if which == "normal" then "tutorial card + 4 toasts showing" else "weapon tip + claim prompt showing, no tutorial") .. "): " .. table.concat(parts, ", "))
		end
		print("  [info] (coverage is advisory - how much of the world a HUD may hide is a taste call; it is not counted as pass/fail)")
	end

	print("  -- PANELS (14 windows, every tab)")
	for _, entry in panelPlan do if censusLines[entry[1]] then print("  [info] census " .. censusLines[entry[1]]) end end
	perClass("PANELS: no overlap, nothing outside its box / the screen / unreadable", panelProblems, LAYOUT)
	perClass("PANELS: no text smaller than 10.5 px effective", panelProblems, { ["tiny-text"] = true })
	perClass("PANELS: every button is at least " .. TAP_MIN .. " px wide and high (finger taps)", panelProblems, { ["tap-small"] = true }, true)
	perClass("PANELS: every icon is at least " .. ICON_MIN .. " px", panelProblems, { ["tiny-icon"] = true })
	checkGroup("PANELS: no static text is cut off with '...' (estimate: only when more than 12 % too wide)", panelProblems, { ["text-truncated"] = true })
	checkGroup("PANELS: status chips (OWNED, SHINY ...) do not cover the picture they belong to", panelProblems, { ["overlap-badge"] = true })
	do
		local n, lines = report({ hud = (function() local all = {} for _, l in hudNormal do for _, f in l do table.insert(all, f) end end return all end)() }, { ["text-borderline"] = true }, 1)
		local m, more = report(panelProblems, { ["text-borderline"] = true }, 14)
		print(string.format("  [info] %d HUD + %d panel labels are within 12%% of the estimated text width (they MAY clip in real Gotham text; check in Studio, not counted as a failure)", n, m))
		for _, line in more do print(line) end
	end

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

	-- docked panels (Dock = "Right") must not cover the right rail
	do
		local covered, cases = 0, {}
		for _, name in { "Wheel" } do
			local docked = UIKit.getPanel(name)
			for _, vp in viewports do
				setViewport(vp)
				docked:Open(); adv(0.5)
				local rootW = layoutGui(docked.Gui, vp)
				local rootM = layoutGui(mainGui, vp)
				local win = rootW.kids[#rootW.kids]
				local rail
				walk(rootM, function(n) if n.name == "Rail" then rail = n end end)
				local railButtons = {}
				if rail then walk(rail, function(n) if string.sub(n.name, -6) == "Button" and n.class == "TextButton" and n.data.Props.Visible ~= false then table.insert(railButtons, n) end end) end
				for _, b in railButtons do
					local x = inter({ x = win.x, y = win.y, w = win.w, h = win.h }, { x = b.x, y = b.y, w = b.w, h = b.h })
					if x.w > 2 and x.h > 2 then covered += 1; table.insert(cases, name .. "@" .. vp.X .. "x" .. vp.Y .. ":" .. b.name) end
				end
				docked:Close(); adv(0.3)
			end
		end
		check("the docked Lucky Wheel window does not hide any right-rail button (7 viewports)", covered == 0, if covered > 0 then covered .. " rail buttons covered, e.g. " .. table.concat(cases, ", ", 1, math.min(#cases, 6)) else nil)
		setViewport(Vector2.new(1280, 720))
	end

	---------------------------------------------------------------------------------------------------------------------
	-- C. transient screens: server banner, hamster reveal card, emote wheel
	---------------------------------------------------------------------------------------------------------------------
	do
		local Remotes = require(find("ReplicatedStorage.Remotes"))
		local announce = Remotes.event("Announce")
		local AnnouncementUI = require(find(UI .. "AnnouncementUI"))
		local EmoteUI = require(find(UI .. "EmoteUI"))
		local TRANSIENT = { overlap = true, ["text-covered"] = true, ["overlap-box"] = true, ["overlap-controls"] = true, ["outside-parent"] = true, ["off-screen"] = true, ["zero-size"] = true, ["text-spill"] = true, ["text-spill-v"] = true, ["tiny-text"] = true }
		local screens = { banner = {}, reveal = {}, emotes = {} }
		for _, vp in viewports do
			setViewport(vp)
			local function take(which, root)
				local findings = analyse(root, vp, {})
				screens[which][vp.X .. "x" .. vp.Y] = findings
				dumpRects(which, vp, root)
			end
			-- banner
			RawData[announce].Signals.OnClientEvent:Fire({ Kind = "Spawn", RarityId = RarityConfig.Order[#RarityConfig.Order - 1], Text = "A LEGENDARY " .. string.upper(longestSpecies) .. " HAS APPEARED!", PlayerName = "Averyverylongname", UserId = 1 })
			adv(0.8)
			local ann = screenGui("AnnouncementUI")
			take("banner", layoutGui(ann, vp))
			adv(5)
			-- reveal card
			AnnouncementUI.reveal(HamsterDatabase.Species[#HamsterDatabase.Species].Id, true)
			adv(0.8)
			take("reveal", layoutGui(ann, vp))
			adv(3.6)
			-- emote wheel
			EmoteUI.toggle(); adv(0.5)
			take("emotes", layoutGui(screenGui("EmoteWheel"), vp))
			EmoteUI.toggle(); adv(0.4)
		end
		checkGroup("server banner (\"A LEGENDARY ... HAS APPEARED\") fits every viewport", screens.banner, TRANSIENT)
		checkGroup("hamster reveal card (NEW HAMSTER) fits every viewport", screens.reveal, TRANSIENT)
		checkGroup("emote wheel fits every viewport", screens.emotes, TRANSIENT)
		setViewport(Vector2.new(1280, 720))
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
	-- D2. navigation consistency: icons and words must tell the same story on the rail, in the window and on the HUD
	---------------------------------------------------------------------------------------------------------------------
	do
		-- the window opened by a rail button wears the SAME icon as the button (a bag on the rail and a coin on the window is two meanings)
		local mismatch, noHeader = {}, {}
		for _, def in UIRegistry.list("RightRail") do
			local panel = def.Panel and UIKit.getPanel(def.Panel)
			if panel then
				local header = byName(panel.Gui, "Header")[1]
				local iconId
				if header then
					for _, kid in M.InstanceMethods.GetChildren(header) do
						local id = RawData[kid].Attributes.IconId
						if id then iconId = id end
					end
				end
				if not iconId then table.insert(noHeader, def.Id) elseif iconId ~= def.Icon then table.insert(mismatch, string.format("%s: rail '%s' vs window '%s'", def.Id, def.Icon, iconId)) end
			end
		end
		check("every rail button and the window it opens show the SAME icon", #mismatch == 0 and #noHeader == 0, table.concat(mismatch, "; ") .. table.concat(noHeader, ","))

		-- the word under a rail icon names the window it opens (Roblox phones have no hover tooltips: the label is all a touch player sees)
		local synonyms = { Ranking = "leaderboards" } -- (the rail tile only fits ~9 letters; 'Ranking' for 'Leaderboards' is an accepted short form)
		local wrongWord = {}
		for _, def in UIRegistry.list("RightRail") do
			local panel = def.Panel and UIKit.getPanel(def.Panel)
			local title = panel and string.lower(RawData[panel.Title].Props.Text or "") or ""
			local label = string.lower(def.Label or def.Id)
			if panel and not string.find(title, label, 1, true) and not (synonyms[def.Label or ""] and string.find(title, synonyms[def.Label], 1, true)) then
				table.insert(wrongWord, string.format("'%s' opens '%s'", def.Label or def.Id, RawData[panel.Title].Props.Text))
			end
		end
		check("the word under each rail icon appears in the title of the window it opens", #wrongWord == 0, table.concat(wrongWord, "; "))

		-- base security: the order asks for a LOCK. The gate chip is the only security indicator on the HUD.
		local gate = byName(mainGui, "GateChip")[1]
		local gateIcon
		if gate then
			for _, kid in M.InstanceMethods.GetChildren(gate) do if RawData[kid].Attributes.IconId then gateIcon = RawData[kid].Attributes.IconId end end
		end
		check("the base-security gate chip uses the lock icon", gateIcon == "lock", tostring(gateIcon))

		-- inventory of every ScreenGui (info) and the insets rule: HUD under the top bar, hotbar inside the device safe area, windows full screen
		local rows = {}
		local guis = M.InstanceMethods.GetChildren(playerGui)
		table.sort(guis, function(a, b) return (RawData[a].Props.DisplayOrder or 0) < (RawData[b].Props.DisplayOrder or 0) end)
		local duplicates = {}
		local seenNames = {}
		for _, g in guis do
			if RawData[g].ClassName == "ScreenGui" then
				local name = RawData[g].Name
				if seenNames[name] then table.insert(duplicates, name) end
				seenNames[name] = true
				table.insert(rows, string.format("%s(order %s%s, insets %s)", name, tostring(RawData[g].Props.DisplayOrder), if RawData[g].Props.Enabled == false then ", hidden" else "", tostring(RawData[g].Attributes.Insets)))
			end
		end
		print("  [info] ScreenGuis (" .. #rows .. "): " .. table.concat(rows, " | "))
		check("no ScreenGui exists twice (no second HUD, no second hotbar)", #duplicates == 0, table.concat(duplicates, ","))
		local main, hotbarGui = screenGui("MainUI"), screenGui("HotbarUI")
		local insetsOk = RawData[main].Props.ScreenInsets == Enum.ScreenInsets.TopbarSafeInsets and RawData[hotbarGui].Props.ScreenInsets == Enum.ScreenInsets.DeviceSafeInsets
		check("MainUI uses TopbarSafeInsets (starts below the native top bar), HotbarUI uses DeviceSafeInsets (above the home indicator)", insetsOk, tostring(RawData[main].Props.ScreenInsets and RawData[main].Props.ScreenInsets.Name) .. " / " .. tostring(RawData[hotbarGui].Props.ScreenInsets and RawData[hotbarGui].Props.ScreenInsets.Name))
	end

	---------------------------------------------------------------------------------------------------------------------
	-- F. text that comes from DATA fits its label: every item's stat rows and description, every item name on its card
	---------------------------------------------------------------------------------------------------------------------
	do
		local ItemView = require(find(UI .. "ItemView"))
		local function ratioOf(text, size, font, w, h, wrapped)
			local m = measureText({ Props = { Text = text, TextSize = size, Font = font, TextWrapped = wrapped, RichText = false } }, w, h, 1)
			return m and (if wrapped then m.ratio else m.ratio) or 0, m
		end
		local VALUE_W, DESC_W, DESC_H, NAME_W = 144, 286, 54, 138 -- design px of the Shop / Backpack detail card (314 wide) and the Shop card (150 wide)
		local badValues, badDescs, badNames = {}, {}, {}
		for _, def in ItemRegistry.List do
			for _, row in ItemView.stats(def) do
				local ratio = ratioOf(row[2], 13, Enum.Font.GothamBlack, VALUE_W, 18, false)
				if ratio > OVER then table.insert(badValues, string.format("%s / %s: '%s' (%.0f%% of the %d px column)", def.DisplayName, row[1], row[2], ratio * 100, VALUE_W)) end
			end
			local ratio = ratioOf(def.Description or "", 14, Enum.Font.GothamMedium, DESC_W, DESC_H, true)
			if ratio > OVER then table.insert(badDescs, string.format("%s (%.0f%% of the %d px high description box)", def.DisplayName, ratio * 100, DESC_H)) end
		end
		for _, item in ShopConfig.Items do
			local ratio = ratioOf(item.Desc or "", 14, Enum.Font.GothamMedium, DESC_W, DESC_H, true)
			if ratio > OVER then table.insert(badDescs, string.format("shop item %s (%.0f%%)", item.Id, ratio * 100)) end
			local nameRatio = ratioOf(item.Name or "", 14, Enum.Font.GothamBlack, NAME_W, 20, false)
			if nameRatio > OVER then table.insert(badNames, string.format("%s (%.0f%%)", item.Name, nameRatio * 100)) end
		end
		for _, def in ItemRegistry.List do
			local nameRatio = ratioOf(def.DisplayName, 14, Enum.Font.GothamBlack, NAME_W, 20, false)
			if nameRatio > OVER then table.insert(badNames, string.format("%s (%.0f%%)", def.DisplayName, nameRatio * 100)) end
		end
		check("every item stat value fits the 144 px value column of the detail card (no text running over its row name)", #badValues == 0, if #badValues > 0 then #badValues .. " too wide, e.g. " .. table.concat(badValues, " ;; ", 1, math.min(#badValues, 6)) else nil)
		check("every item description fits the 3-line description box of the detail card", #badDescs == 0, if #badDescs > 0 then #badDescs .. " too long, e.g. " .. table.concat(badDescs, " ;; ", 1, math.min(#badDescs, 6)) else nil)
		check("every item name fits the 138 px name label of its shop card", #badNames == 0, if #badNames > 0 then #badNames .. " too wide, e.g. " .. table.concat(badNames, " ;; ", 1, math.min(#badNames, 6)) else nil)
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
		-- pressed: the button squashes while the finger / mouse is down and springs back
		local scaleObj
		for _, kid in M.InstanceMethods.GetChildren(b) do if RawData[kid].ClassName == "UIScale" then scaleObj = kid end end
		UIKit.setEnabled(b, true)
		RawData[b].Signals.MouseButton1Down:Fire(); adv(0.2)
		local pressedScale = RawData[scaleObj].Props.Scale
		RawData[b].Signals.MouseButton1Up:Fire(); adv(0.3)
		local releasedScale = RawData[scaleObj].Props.Scale
		check("button states: pressed squashes the button (scale < 1) and releasing restores it", pressedScale < 0.99 and releasedScale >= 0.99, string.format("%.2f -> %.2f", pressedScale, releasedScale))
		-- a disabled button does not run its action (and says so with the error sound)
		local ran = 0
		local d = UIKit.button(holder, { Text = "Disabled", Size = UDim2.fromOffset(120, 40), OnClick = function() ran += 1 end })
		UIKit.setEnabled(d, false)
		RawData[d].Signals.Activated:Fire(); adv(0.1)
		check("a disabled button does not run its action", ran == 0)
		M.InstanceMethods.Destroy(holder)

		-- the rail: the button of the OPEN window is highlighted, the badge dot lights up when something can be claimed
		local shopButton = byName(mainGui, "ShopButton")[1]
		local baseColor = RawData[shopButton].Props.BackgroundColor3
		UIKit.getPanel("Shop"):Open(); adv(0.8)
		local openColor = RawData[shopButton].Props.BackgroundColor3
		UIKit.getPanel("Shop"):Close(); adv(0.8)
		local closedColor = RawData[shopButton].Props.BackgroundColor3
		check("rail: the button of the open window is highlighted and goes back when it closes", (math.abs(openColor.R - baseColor.R) + math.abs(openColor.G - baseColor.G)) > 0.1 and math.abs(closedColor.R - baseColor.R) < 0.02, string.format("closed %.2f open %.2f", baseColor.R, openColor.R))
		local wheelDot = byName(byName(mainGui, "WheelButton")[1], "NotifyDot")[1]
		check("rail: the Lucky Wheel icon shows the red dot while a free spin is ready", wheelDot ~= nil and RawData[wheelDot].Props.Visible == true)

		-- hover tooltips (PC): every rail tooltip fits to the left of its button on desktop / tablet screens (phones show no tooltips)
		local longest, longestId = 0, ""
		for _, def in UIRegistry.list("RightRail") do
			local width = textWidth(def.Tooltip or def.Id, 13, false) + 20
			if width > longest then longest, longestId = width, def.Id end
		end
		local cut = {}
		for _, vp in viewports do
			if not isPhoneKey(vp.X .. "x" .. vp.Y) then
				setViewport(vp)
				local rail
				walk(layoutGui(mainGui, vp), function(n) if n.name == "Rail" then rail = n end end)
				local leftEdge = 1e9
				if rail then walk(rail, function(n) if n.class == "TextButton" and string.sub(n.name, -6) == "Button" then leftEdge = math.min(leftEdge, n.x) end end) end
				if leftEdge - 8 - longest < 0 then table.insert(cut, string.format("%dx%d (tooltip of %s needs %.0f px, only %.0f free)", vp.X, vp.Y, longestId, longest, leftEdge - 8)) end
			end
		end
		setViewport(Vector2.new(1280, 720))
		check("rail tooltips (hover, PC) fit on screen to the left of the rail at desktop + tablet sizes", #cut == 0, table.concat(cut, "; "))
	end

	---------------------------------------------------------------------------------------------------------------------
	-- G. a brand-new player: no window is an empty box (every empty list explains itself)
	---------------------------------------------------------------------------------------------------------------------
	do
		M.isServer = true
		data.Items = {}; data.Gear = {}; data.Hotbar = {}; data.Inventory = {}; data.Equipped = {}
		ReplicationSystem.mark(p, "Items", "Gear", "Hotbar", "Inventory", "Equipped")
		M.isServer = false
		adv(2)
		local backpack = UIKit.getPanel("Backpack")
		backpack:Open(); adv(0.6)
		local function visibleTextWith(root, needle)
			for _, d in M.descendants(root) do
				local dd = RawData[d]
				if dd.ClassName == "TextLabel" and dd.Props.Visible ~= false and type(dd.Props.Text) == "string" and string.find(dd.Props.Text, needle, 1, true) then
					-- every ancestor up to the window must be visible too
					local node, shown = dd.Parent, true
					while node and node ~= root do
						if RawData[node].Props.Visible == false then shown = false end
						node = RawData[node].Parent
					end
					if shown then return true end
				end
			end
			return false
		end
		press(byName(backpack.Gui, "Tab_Items")[1]); adv(0.4)
		check("a new player's Backpack > Items tab says it is empty and where to get items", visibleTextWith(backpack.Gui, "Your backpack is empty"))
		press(byName(backpack.Gui, "Tab_Hamsters")[1]); adv(0.4)
		check("a new player's Backpack > Hamsters tab says there are no hamsters yet", visibleTextWith(backpack.Gui, "No hamsters yet"))
		backpack:Close(); adv(0.3)
	end

	print(string.format("PASS %d FAIL %d errors %d", results.pass, results.fail, #M.Sim.errors))
	for i, err in M.Sim.errors do if i <= 8 then print(err) end end
end)
M.Sim.advance(0)
