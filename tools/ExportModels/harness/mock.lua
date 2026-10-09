-- A small Roblox runtime mock: enough to EXECUTE the game's server + client code in plain Luau.
-- Property / member names are validated against the official API definitions (classes.lua).
local classes = require("./classes")
local M = {}
local workspace_ref = nil

---------------------------------------------------------------------------
-- virtual time + scheduler
---------------------------------------------------------------------------
local Sim = { now = 1000, errors = {}, threads = {}, deferred = {} }
M.Sim = Sim

local function logError(where, err)
	table.insert(Sim.errors, where .. ": " .. tostring(err))
	print("  !! ERROR in " .. where .. ": " .. tostring(err))
end
Sim.logError = logError

local function runThread(co, ...)
	local ok, err = coroutine.resume(co, ...)
	if not ok then
		logError("thread", err .. "\n" .. debug.traceback(co))
	end
end

local task = {}
function task.spawn(fn, ...)
	local co = coroutine.create(fn)
	runThread(co, ...)
	return co
end
function task.defer(fn, ...)
	local args = table.pack(...)
	table.insert(Sim.deferred, function()
		task.spawn(fn, table.unpack(args, 1, args.n))
	end)
end
function task.wait(t)
	t = t or 0.03
	local co = coroutine.running()
	table.insert(Sim.threads, { co = co, at = Sim.now + t })
	coroutine.yield()
	return t
end
function task.delay(t, fn, ...)
	local args = table.pack(...)
	local co = coroutine.create(function()
		task.wait(t)
		fn(table.unpack(args, 1, args.n))
	end)
	runThread(co)
	return co
end
function task.cancel(co) end
M.task = task

local realClock = os.clock
M.os = setmetatable({
	clock = function() return Sim.now end,
	time = function() return math.floor(Sim.unix or 1790000000) + math.floor(Sim.now - 1000) end,
	date = os.date,
}, { __index = os })

local function drainDeferred()
	while #Sim.deferred > 0 do
		local list = Sim.deferred
		Sim.deferred = {}
		for _, fn in list do
			fn()
		end
	end
end

-- Advance virtual time by `dt` (fires Heartbeat/RenderStepped on the way).
function Sim.advance(dt, hooks)
	local step = 0.05
	local remaining = dt
	while remaining > 1e-9 do
		local d = math.min(step, remaining)
		remaining -= d
		Sim.now += d
		local due = {}
		local rest = {}
		for _, entry in Sim.threads do
			if entry.at <= Sim.now + 1e-9 then
				table.insert(due, entry)
			else
				table.insert(rest, entry)
			end
		end
		Sim.threads = rest
		table.sort(due, function(a, b) return a.at < b.at end)
		for _, entry in due do
			runThread(entry.co)
		end
		if hooks and hooks.beforeFrame then hooks.beforeFrame(d) end
		if Sim.fireFrame then Sim.fireFrame(d) end
		drainDeferred()
	end
end

---------------------------------------------------------------------------
-- signals
---------------------------------------------------------------------------
local Signal = {}
Signal.__index = Signal
local function newSignal()
	return setmetatable({ handlers = {} }, Signal)
end
function Signal:Connect(fn)
	local conn = { Connected = true }
	local entry = { fn = fn, conn = conn }
	table.insert(self.handlers, entry)
	function conn:Disconnect()
		conn.Connected = false
		for i, e in self.handlers or {} do end
	end
	conn.Disconnect = function()
		conn.Connected = false
		for i, e in self.handlers do
			if e == entry then
				table.remove(self.handlers, i)
				break
			end
		end
	end
	return conn
end
function Signal:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn:Disconnect()
		fn(...)
	end)
	return conn
end
function Signal:Wait()
	local co = coroutine.running()
	self:Once(function(...)
		runThread(co, ...)
	end)
	return coroutine.yield()
end
function Signal:Fire(...)
	local list = table.clone(self.handlers)
	for _, e in list do
		if e.conn.Connected then
			local args = table.pack(...)
			task.spawn(function()
				e.fn(table.unpack(args, 1, args.n))
			end)
		end
	end
end
M.newSignal = newSignal

---------------------------------------------------------------------------
-- datatypes
---------------------------------------------------------------------------
local Vector3 = {}
local V3mt = { __type = "Vector3" }
local function v3(x, y, z) return setmetatable({ X = x, Y = y, Z = z }, V3mt) end
V3mt.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z) end
	if k == "Unit" then
		local m = math.sqrt(t.X * t.X + t.Y * t.Y + t.Z * t.Z)
		if m == 0 then return v3(0, 0, 0) end
		return v3(t.X / m, t.Y / m, t.Z / m)
	end
	local f = Vector3[k]
	if f ~= nil then return f end
	error("Vector3: invalid member " .. tostring(k))
end
V3mt.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3mt.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3mt.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3mt.__mul = function(a, b)
	if type(a) == "number" then return v3(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3mt.__div = function(a, b)
	if type(b) == "number" then return v3(a.X / b, a.Y / b, a.Z / b) end
	return v3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
V3mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
V3mt.__tostring = function(a) return string.format("%g, %g, %g", a.X, a.Y, a.Z) end
Vector3.new = function(x, y, z) return v3(x or 0, y or 0, z or 0) end
Vector3.zero = v3(0, 0, 0)
Vector3.one = v3(1, 1, 1)
Vector3.xAxis = v3(1, 0, 0)
Vector3.yAxis = v3(0, 1, 0)
Vector3.zAxis = v3(0, 0, 1)
function Vector3.Dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
function Vector3.Cross(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
function Vector3.Lerp(a, b, t) return v3(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t) end
function Vector3.FuzzyEq(a, b, e) return (a - b).Magnitude <= (e or 1e-5) end
M.Vector3 = Vector3

local Vector2 = {}
local V2mt = { __type = "Vector2" }
local function v2(x, y) return setmetatable({ X = x, Y = y }, V2mt) end
V2mt.__index = function(t, k)
	if k == "Magnitude" then return math.sqrt(t.X * t.X + t.Y * t.Y) end
	local f = Vector2[k]
	if f ~= nil then return f end
	error("Vector2: invalid member " .. tostring(k))
end
V2mt.__add = function(a, b) return v2(a.X + b.X, a.Y + b.Y) end
V2mt.__sub = function(a, b) return v2(a.X - b.X, a.Y - b.Y) end
V2mt.__unm = function(a) return v2(-a.X, -a.Y) end
V2mt.__mul = function(a, b)
	if type(a) == "number" then return v2(a * b.X, a * b.Y) end
	if type(b) == "number" then return v2(a.X * b, a.Y * b) end
	return v2(a.X * b.X, a.Y * b.Y)
end
V2mt.__div = function(a, b)
	if type(b) == "number" then return v2(a.X / b, a.Y / b) end
	return v2(a.X / b.X, a.Y / b.Y)
end
V2mt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y end
Vector2.new = function(x, y) return v2(x or 0, y or 0) end
Vector2.zero = v2(0, 0)
Vector2.one = v2(1, 1)
M.Vector2 = Vector2

-- CFrame: translation + 3x3 rotation (row-major r11..r33)
local CFrame = {}
local CFmt = { __type = "CFrame" }
local function cf(x, y, z, r) -- r = {r11,r12,r13,r21,...}
	return setmetatable({ X = x, Y = y, Z = z, r = r or { 1, 0, 0, 0, 1, 0, 0, 0, 1 } }, CFmt)
end
local IDENT = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function matmul(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			r[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[j + 4] + a[i * 3 + 3] * b[j + 7]
		end
	end
	return r
end
local function transpose(a)
	return { a[1], a[4], a[7], a[2], a[5], a[8], a[3], a[6], a[9] }
end
CFmt.__index = function(t, k)
	if k == "Position" then return v3(t.X, t.Y, t.Z) end
	if k == "LookVector" then return v3(-t.r[3], -t.r[6], -t.r[9]) end
	if k == "RightVector" then return v3(t.r[1], t.r[4], t.r[7]) end
	if k == "UpVector" then return v3(t.r[2], t.r[5], t.r[8]) end
	if k == "Rotation" then return cf(0, 0, 0, t.r) end
	local f = CFrame[k]
	if f ~= nil then return f end
	error("CFrame: invalid member " .. tostring(k))
end
CFmt.__mul = function(a, b)
	if getmetatable(b) == CFmt then
		local p = a.r
		return cf(
			a.X + p[1] * b.X + p[2] * b.Y + p[3] * b.Z,
			a.Y + p[4] * b.X + p[5] * b.Y + p[6] * b.Z,
			a.Z + p[7] * b.X + p[8] * b.Y + p[9] * b.Z,
			matmul(a.r, b.r)
		)
	end
	-- Vector3
	local p = a.r
	return v3(a.X + p[1] * b.X + p[2] * b.Y + p[3] * b.Z, a.Y + p[4] * b.X + p[5] * b.Y + p[6] * b.Z, a.Z + p[7] * b.X + p[8] * b.Y + p[9] * b.Z)
end
CFmt.__add = function(a, b) return cf(a.X + b.X, a.Y + b.Y, a.Z + b.Z, a.r) end
CFmt.__sub = function(a, b) return cf(a.X - b.X, a.Y - b.Y, a.Z - b.Z, a.r) end
CFmt.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
CFrame.identity = cf(0, 0, 0)
CFrame.new = function(a, b, c)
	if a == nil then return cf(0, 0, 0) end
	if type(a) == "number" then return cf(a, b, c) end
	if b ~= nil and getmetatable(b) == V3mt then return CFrame.lookAt(a, b) end
	return cf(a.X, a.Y, a.Z)
end
CFrame.Angles = function(rx, ry, rz)
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local Rx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local Ry = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local Rz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return cf(0, 0, 0, matmul(matmul(Rx, Ry), Rz))
end
CFrame.lookAt = function(at, look)
	local z = (at - look)
	if z.Magnitude < 1e-9 then return cf(at.X, at.Y, at.Z) end
	z = z.Unit
	local up = v3(0, 1, 0)
	local x = Vector3.Cross(up, z)
	if x.Magnitude < 1e-6 then x = v3(1, 0, 0) else x = x.Unit end
	local y = Vector3.Cross(z, x)
	return cf(at.X, at.Y, at.Z, { x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z })
end
function CFrame.Inverse(a)
	local rt = transpose(a.r)
	local x = -(rt[1] * a.X + rt[2] * a.Y + rt[3] * a.Z)
	local y = -(rt[4] * a.X + rt[5] * a.Y + rt[6] * a.Z)
	local z = -(rt[7] * a.X + rt[8] * a.Y + rt[9] * a.Z)
	return cf(x, y, z, rt)
end
function CFrame.ToObjectSpace(a, b) return CFrame.Inverse(a) * b end
function CFrame.ToWorldSpace(a, b) return a * b end
function CFrame.PointToObjectSpace(a, p) return CFrame.Inverse(a) * p end
function CFrame.PointToWorldSpace(a, p) return a * p end
function CFrame.VectorToObjectSpace(a, v) return (CFrame.Inverse(a) - CFrame.Inverse(a).Position) * v end
function CFrame.VectorToWorldSpace(a, v) return (a - a.Position) * v end
function CFrame.Lerp(a, b, t) return cf(a.X + (b.X - a.X) * t, a.Y + (b.Y - a.Y) * t, a.Z + (b.Z - a.Z) * t, a.r) end
function CFrame.GetComponents(a) return a.X, a.Y, a.Z end
CFrame.fromAxisAngle = function(axis, angle)
	local u = axis.Unit
	local c, sn = math.cos(angle), math.sin(angle)
	local t = 1 - c
	local x, y, z = u.X, u.Y, u.Z
	return cf(0, 0, 0, {
		t * x * x + c, t * x * y - sn * z, t * x * z + sn * y,
		t * x * y + sn * z, t * y * y + c, t * y * z - sn * x,
		t * x * z - sn * y, t * y * z + sn * x, t * z * z + c,
	})
end
M.CFrame = CFrame

local Color3 = {}
local C3mt = { __type = "Color3" }
local function c3(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3mt) end
C3mt.__index = function(t, k)
	local f = Color3[k]
	if f ~= nil then return f end
	error("Color3: invalid member " .. tostring(k))
end
C3mt.__eq = function(a, b) return a.R == b.R and a.G == b.G and a.B == b.B end
Color3.new = function(r, g, b) return c3(r or 0, g or 0, b or 0) end
Color3.fromRGB = function(r, g, b) return c3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end
Color3.fromHex = function(h)
	assert(type(h) == "string" and #h == 6, "bad hex " .. tostring(h))
	return c3(tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255)
end
Color3.fromHSV = function(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	i = i % 6
	if i == 0 then return c3(v, t, p) elseif i == 1 then return c3(q, v, p) elseif i == 2 then return c3(p, v, t) elseif i == 3 then return c3(p, q, v) elseif i == 4 then return c3(t, p, v) else return c3(v, p, q) end
end
function Color3.ToHex(c) return string.format("%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)) end
function Color3.Lerp(a, b, t) return c3(a.R + (b.R - a.R) * t, a.G + (b.G - a.G) * t, a.B + (b.B - a.B) * t) end
M.Color3 = Color3

local UDim = {}
local UDmt = {}
UDmt.__index = function(t, k) return UDim[k] end
UDim.new = function(s, o) return setmetatable({ Scale = s or 0, Offset = o or 0 }, UDmt) end
M.UDim = UDim

local UDim2 = {}
local U2mt = { __type = "UDim2" }
local function u2(sx, ox, sy, oy) return setmetatable({ X = UDim.new(sx, ox), Y = UDim.new(sy, oy) }, U2mt) end
U2mt.__index = function(t, k) return UDim2[k] end
U2mt.__add = function(a, b) return u2(a.X.Scale + b.X.Scale, a.X.Offset + b.X.Offset, a.Y.Scale + b.Y.Scale, a.Y.Offset + b.Y.Offset) end
U2mt.__sub = function(a, b) return u2(a.X.Scale - b.X.Scale, a.X.Offset - b.X.Offset, a.Y.Scale - b.Y.Scale, a.Y.Offset - b.Y.Offset) end
UDim2.new = function(a, b, c, d)
	if getmetatable(a) == UDmt then return u2(a.Scale, a.Offset, b.Scale, b.Offset) end
	return u2(a or 0, b or 0, c or 0, d or 0)
end
UDim2.fromOffset = function(x, y) return u2(0, x, 0, y) end
UDim2.fromScale = function(x, y) return u2(x, 0, y, 0) end
M.UDim2 = UDim2

M.NumberRange = { new = function(a, b) return { Min = a, Max = b or a } end }
M.NumberSequenceKeypoint = { new = function(t, v, e) return { Time = t, Value = v, Envelope = e or 0 } end }
M.NumberSequence = { new = function(a, b)
	if type(a) == "table" then assert(#a >= 2, "NumberSequence needs 2+ keypoints"); return { Keypoints = a } end
	return { Keypoints = { { Time = 0, Value = a }, { Time = 1, Value = b or a } } }
end }
M.ColorSequenceKeypoint = { new = function(t, c) return { Time = t, Value = c } end }
M.ColorSequence = { new = function(a, b)
	if type(a) == "table" and rawget(a, "Keypoints") == nil and rawget(a, 1) ~= nil and rawget(a[1], "Time") ~= nil then assert(#a >= 2, "ColorSequence needs 2+ keypoints"); return { Keypoints = a } end
	return { Keypoints = { { Time = 0, Value = a }, { Time = 1, Value = b or a } } }
end }
M.TweenInfo = { new = function(t, s, d) return { Time = t, EasingStyle = s, EasingDirection = d } end }
M.Rect = { new = function() return {} end }

-- Enum: any Enum.X.Y resolves to a stable item
local enumTypes = {}
M.Enum = setmetatable({}, { __index = function(_, typeName)
	if not enumTypes[typeName] then
		local items = {}
		enumTypes[typeName] = setmetatable({ Name = typeName }, { __index = function(t, itemName)
			if itemName == "GetEnumItems" then return function() return {} end end
			if not items[itemName] then items[itemName] = { Name = itemName, Value = 0, EnumType = typeName } end
			return items[itemName]
		end })
	end
	return enumTypes[typeName]
end })

M.Enum.RenderPriority.Camera.Value = 200
M.Enum.RenderPriority.Last.Value = 2000

-- Random (LCG)
M.Random = { new = function(seed)
	local s = (seed or 12345) % 2147483647
	if s <= 0 then s = 1 end
	local function nextf()
		s = (s * 48271) % 2147483647
		return s / 2147483647
	end
	local r = {}
	function r:NextNumber(a, b)
		local v = nextf()
		if a then return a + (b - a) * v end
		return v
	end
	function r:NextInteger(a, b) return a + math.floor(nextf() * (b - a + 1)) end
	return r
end }

---------------------------------------------------------------------------
-- Instances
---------------------------------------------------------------------------
local RawData = setmetatable({}, { __mode = "k" })
local tagRegistry = {} -- tag -> { [inst]=true }
local tagSignals = { added = {}, removed = {} }
local gameRoot

local function classChain(className)
	local chain = {}
	local c = className
	while c do
		table.insert(chain, c)
		c = classes[c] and classes[c].extends
	end
	return chain
end

local function memberType(className, key)
	local c = className
	while c do
		local info = classes[c]
		if not info then return nil end
		local t = info.members[key]
		if t then return t end
		c = info.extends
	end
	return nil
end

local function isInGame(inst)
	local cur = inst
	while cur do
		if cur == gameRoot then return true end
		cur = RawData[cur].Parent
	end
	return false
end

local function defaultFor(typeName)
	if typeName == "number" then return 0 end
	if typeName == "boolean" then return false end
	if typeName == "string" then return "" end
	if typeName == "Vector3" then return Vector3.zero end
	if typeName == "Vector2" then return Vector2.zero end
	if typeName == "CFrame" then return CFrame.identity end
	if typeName == "Color3" then return Color3.new(0, 0, 0) end
	if typeName == "UDim2" then return UDim2.new() end
	if typeName == "UDim" then return UDim.new(0, 0) end
	if typeName:sub(1, 4) == "Enum" and #typeName > 4 then return M.Enum[typeName:sub(5)].Default end
	return nil
end

local InstanceMethods = {}
local newInstance

local function fireTagAdded(inst)
	for tag in RawData[inst].Tags do
		local sig = tagSignals.added[tag]
		if sig then sig:Fire(inst) end
	end
end

local function fireDescendantsEntered(inst)
	fireTagAdded(inst)
	for _, child in RawData[inst].Children do
		fireDescendantsEntered(child)
	end
end

local function setParent(inst, newParent)
	local data = RawData[inst]
	if data.Destroyed then error("The Parent property of " .. data.Name .. " is locked (destroyed)") end
	local old = data.Parent
	if old == newParent then return end
	local wasIn = isInGame(inst)
	if old then
		local list = RawData[old].Children
		for i, c in list do
			if c == inst then
				table.remove(list, i)
				break
			end
		end
	end
	data.Parent = newParent
	if newParent then
		table.insert(RawData[newParent].Children, inst)
	end
	local nowIn = isInGame(inst)
	if nowIn and not wasIn then
		fireDescendantsEntered(inst)
	end
	if wasIn and not nowIn then
		local function removed(i)
			for tag in RawData[i].Tags do
				local sig = tagSignals.removed[tag]
				if sig then sig:Fire(i) end
			end
			for _, c in RawData[i].Children do removed(c) end
		end
		removed(inst)
	end
	if data.Signals.AncestryChanged then data.Signals.AncestryChanged:Fire(inst, newParent) end
end

local function isA(className, target)
	for _, c in classChain(className) do
		if c == target then return true end
	end
	return target == "Instance"
end

local function descendants(inst, out)
	out = out or {}
	for _, child in RawData[inst].Children do
		table.insert(out, child)
		descendants(child, out)
	end
	return out
end

function InstanceMethods.IsA(self, target) return isA(RawData[self].ClassName, target) end
function InstanceMethods.GetChildren(self) return table.clone(RawData[self].Children) end
function InstanceMethods.GetDescendants(self) return descendants(self, {}) end
function InstanceMethods.FindFirstChild(self, name, recursive)
	for _, c in RawData[self].Children do
		if RawData[c].Name == name then return c end
	end
	if recursive then
		for _, c in RawData[self].Children do
			local f = InstanceMethods.FindFirstChild(c, name, true)
			if f then return f end
		end
	end
	return nil
end
function InstanceMethods.FindFirstChildOfClass(self, className)
	for _, c in RawData[self].Children do
		if isA(RawData[c].ClassName, className) and RawData[c].ClassName == className then return c end
	end
	return nil
end
function InstanceMethods.FindFirstChildWhichIsA(self, className)
	for _, c in RawData[self].Children do
		if isA(RawData[c].ClassName, className) then return c end
	end
	return nil
end
function InstanceMethods.FindFirstAncestorOfClass(self, className)
	local cur = RawData[self].Parent
	while cur do
		if RawData[cur].ClassName == className then return cur end
		cur = RawData[cur].Parent
	end
	return nil
end
function InstanceMethods.WaitForChild(self, name, timeout)
	local c = InstanceMethods.FindFirstChild(self, name)
	if c then return c end
	error("Infinite yield: WaitForChild('" .. name .. "') on " .. InstanceMethods.GetFullName(self) .. " (child never appears in mock)")
end
function InstanceMethods.GetFullName(self)
	local parts = {}
	local cur = self
	while cur and cur ~= gameRoot do
		table.insert(parts, 1, RawData[cur].Name)
		cur = RawData[cur].Parent
	end
	return table.concat(parts, ".")
end
function InstanceMethods.IsDescendantOf(self, other)
	local cur = RawData[self].Parent
	while cur do
		if cur == other then return true end
		cur = RawData[cur].Parent
	end
	return false
end
function InstanceMethods.Destroy(self)
	local data = RawData[self]
	if data.Destroyed then return end
	for _, c in table.clone(data.Children) do InstanceMethods.Destroy(c) end
	setParent(self, nil)
	data.Destroyed = true
	if data.Signals.Destroying then data.Signals.Destroying:Fire() end
end
function InstanceMethods.ClearAllChildren(self)
	for _, c in table.clone(RawData[self].Children) do InstanceMethods.Destroy(c) end
end
function InstanceMethods.SetAttribute(self, key, value)
	local data = RawData[self]
	local old = data.Attributes[key]
	data.Attributes[key] = value
	if old ~= value then
		if data.AttrSignals[key] then data.AttrSignals[key]:Fire() end
		if data.Signals.AttributeChanged then data.Signals.AttributeChanged:Fire(key) end
	end
end
function InstanceMethods.GetAttribute(self, key) return RawData[self].Attributes[key] end
function InstanceMethods.GetAttributes(self) return table.clone(RawData[self].Attributes) end
function InstanceMethods.GetAttributeChangedSignal(self, key)
	local data = RawData[self]
	data.AttrSignals[key] = data.AttrSignals[key] or newSignal()
	return data.AttrSignals[key]
end
function InstanceMethods.GetPropertyChangedSignal(self, key)
	local data = RawData[self]
	data.PropSignals[key] = data.PropSignals[key] or newSignal()
	return data.PropSignals[key]
end
function InstanceMethods.AddTag(self, tag)
	local data = RawData[self]
	if data.Tags[tag] then return end
	data.Tags[tag] = true
	tagRegistry[tag] = tagRegistry[tag] or {}
	tagRegistry[tag][self] = true
	if isInGame(self) and tagSignals.added[tag] then tagSignals.added[tag]:Fire(self) end
end
function InstanceMethods.RemoveTag(self, tag)
	local data = RawData[self]
	if not data.Tags[tag] then return end
	data.Tags[tag] = nil
	if tagRegistry[tag] then tagRegistry[tag][self] = nil end
	if tagSignals.removed[tag] then tagSignals.removed[tag]:Fire(self) end
end
function InstanceMethods.HasTag(self, tag) return RawData[self].Tags[tag] == true end
function InstanceMethods.GetTags(self)
	local out = {}
	for t in RawData[self].Tags do table.insert(out, t) end
	return out
end
function InstanceMethods.Clone(self)
	local data = RawData[self]
	local copy = newInstance(data.ClassName, true)
	for k, v in data.Props do RawData[copy].Props[k] = v end
	RawData[copy].Name = data.Name
	for k, v in data.Attributes do RawData[copy].Attributes[k] = v end
	for _, c in data.Children do
		setParent(InstanceMethods.Clone(c), copy)
	end
	return copy
end

-- Model / PVInstance
local function partsOf(model)
	local parts = {}
	for _, d in descendants(model, {}) do
		if isA(RawData[d].ClassName, "BasePart") then table.insert(parts, d) end
	end
	return parts
end
function InstanceMethods.GetPivot(self)
	local data = RawData[self]
	if isA(data.ClassName, "BasePart") then return data.Props.CFrame or CFrame.identity end
	local primary = data.Props.PrimaryPart
	if primary then return RawData[primary].Props.CFrame or CFrame.identity end
	local parts = partsOf(self)
	if #parts == 0 then return CFrame.identity end
	local sx, sy, sz = 0, 0, 0
	for _, p in parts do
		local pos = (RawData[p].Props.CFrame or CFrame.identity).Position
		sx += pos.X sy += pos.Y sz += pos.Z
	end
	return CFrame.new(sx / #parts, sy / #parts, sz / #parts)
end
function InstanceMethods.PivotTo(self, target)
	local data = RawData[self]
	if isA(data.ClassName, "BasePart") then
		data.Props.CFrame = target
		return
	end
	local pivot = InstanceMethods.GetPivot(self)
	local delta = target * pivot:Inverse()
	for _, p in partsOf(self) do
		local pd = RawData[p]
		local moved = delta * (pd.Props.CFrame or CFrame.identity)
		-- keep the rotation orthonormal (Gram-Schmidt) so repeated pivots never drift
		local r = moved.r
		local function norm(x, y, z) local m = math.sqrt(x * x + y * y + z * z) if m < 1e-12 then return 1, 0, 0 end return x / m, y / m, z / m end
		local c1x, c1y, c1z = norm(r[1], r[4], r[7])
		local dot = r[2] * c1x + r[5] * c1y + r[8] * c1z
		local c2x, c2y, c2z = norm(r[2] - dot * c1x, r[5] - dot * c1y, r[8] - dot * c1z)
		local c3x, c3y, c3z = c1y * c2z - c1z * c2y, c1z * c2x - c1x * c2z, c1x * c2y - c1y * c2x
		pd.Props.CFrame = cf(moved.X, moved.Y, moved.Z, { c1x, c2x, c3x, c1y, c2y, c3y, c1z, c2z, c3z })
	end
end
function InstanceMethods.ScaleTo(self, scale)
	assert(type(scale) == "number" and scale > 0, "ScaleTo needs a positive number, got " .. tostring(scale))
	RawData[self].Scale = scale
end
function InstanceMethods.GetScale(self) return RawData[self].Scale or 1 end
function InstanceMethods.GetBoundingBox(self)
	local parts = partsOf(self)
	if #parts == 0 then return CFrame.identity, Vector3.zero end
	local min = v3(math.huge, math.huge, math.huge)
	local max = v3(-math.huge, -math.huge, -math.huge)
	for _, p in parts do
		local pd = RawData[p]
		local pos = (pd.Props.CFrame or CFrame.identity).Position
		local size = pd.Props.Size or Vector3.one
		local scale = 1
		min = v3(math.min(min.X, pos.X - size.X / 2), math.min(min.Y, pos.Y - size.Y / 2), math.min(min.Z, pos.Z - size.Z / 2))
		max = v3(math.max(max.X, pos.X + size.X / 2), math.max(max.Y, pos.Y + size.Y / 2), math.max(max.Z, pos.Z + size.Z / 2))
	end
	return CFrame.new((min + max) / 2), max - min
end

local ownMethods = {}
for k, v in InstanceMethods do ownMethods[k] = v end

local Instance = {}
local instanceMeta = {}

local function resolve(inst, key)
	local data = RawData[inst]
	if key == "Parent" then return data.Parent end
	if key == "Name" then return data.Name end
	if key == "ClassName" then return data.ClassName end
	if key == "Position" and isA(data.ClassName, "BasePart") then return (data.Props.CFrame or CFrame.identity).Position end
	if key == "PrimaryPart" and isA(data.ClassName, "Model") then return data.Props.PrimaryPart end
	local mt = memberType(data.ClassName, key)
	if mt then
		if mt:sub(1, 12) == "RBXScriptSig" then
			data.Signals[key] = data.Signals[key] or newSignal()
			return data.Signals[key]
		end
		if data.Methods and data.Methods[key] then return data.Methods[key] end
		if mt == "function" or mt:sub(1, 8) == "function" then
			if ownMethods[key] then return ownMethods[key] end
			return function() return nil end
		end
		local v = data.Props[key]
		if v == nil then return defaultFor(mt) end
		return v
	end
	-- not a declared member: instance methods / children
	if ownMethods[key] then return ownMethods[key] end
	if data.Methods and data.Methods[key] then return data.Methods[key] end
	for _, c in data.Children do
		if RawData[c].Name == key then return c end
	end
	error(key .. " is not a valid member of " .. data.ClassName .. " \"" .. InstanceMethods.GetFullName(inst) .. "\"")
end

instanceMeta.__index = function(inst, key) return resolve(inst, key) end
instanceMeta.__newindex = function(inst, key, value)
	local data = RawData[inst]
	if key == "Parent" then
		if value ~= nil and RawData[value] == nil then error("Parent must be an Instance") end
		setParent(inst, value)
		return
	end
	if key == "Name" then
		assert(type(value) == "string", "Name must be a string")
		data.Name = value
		return
	end
	if key == "PrimaryPart" and isA(data.ClassName, "Model") then
		data.Props.PrimaryPart = value
		return
	end
	local mt = memberType(data.ClassName, key)
	if not mt then
		error(key .. " is not a valid member of " .. data.ClassName)
	end
	if mt:sub(1, 12) == "RBXScriptSig" or mt:sub(1, 8) == "function" then
		error("cannot assign to " .. key)
	end
	-- basic type checks that catch typical mistakes
	if mt == "number" and type(value) ~= "number" then error("invalid argument for " .. data.ClassName .. "." .. key .. " (number expected, got " .. type(value) .. ")") end
	if mt == "boolean" and type(value) ~= "boolean" then error("invalid argument for " .. data.ClassName .. "." .. key .. " (boolean expected, got " .. type(value) .. ")") end
	if mt == "string" and type(value) ~= "string" then error("invalid argument for " .. data.ClassName .. "." .. key .. " (string expected, got " .. type(value) .. ")") end
	if mt == "Vector3" and (type(value) ~= "table" or getmetatable(value) ~= V3mt) then error("invalid argument for " .. data.ClassName .. "." .. key .. " (Vector3 expected)") end
	if mt == "Color3" and (type(value) ~= "table" or getmetatable(value) ~= C3mt) then error("invalid argument for " .. data.ClassName .. "." .. key .. " (Color3 expected)") end
	if mt == "CFrame" and (type(value) ~= "table" or getmetatable(value) ~= CFmt) then error("invalid argument for " .. data.ClassName .. "." .. key .. " (CFrame expected)") end
	if mt == "UDim2" and (type(value) ~= "table" or getmetatable(value) ~= U2mt) then error("invalid argument for " .. data.ClassName .. "." .. key .. " (UDim2 expected)") end
	if mt:sub(1, 4) == "Enum" and #mt > 4 and (type(value) ~= "table" or value.EnumType == nil) then error("invalid argument for " .. data.ClassName .. "." .. key .. " (Enum expected)") end
	if mt == "Vector2" and (type(value) ~= "table" or getmetatable(value) ~= V2mt) then error("invalid argument for " .. data.ClassName .. "." .. key .. " (Vector2 expected)") end
	if key == "Size" and mt == "Vector3" then
		assert(value.X >= 0 and value.Y >= 0 and value.Z >= 0, "negative size")
	end
	data.Props[key] = value
	if key == "Position" and isA(data.ClassName, "BasePart") then
		data.Props.CFrame = CFrame.new(value) * (data.Props.CFrame or CFrame.identity).Rotation
	end
	if data.PropSignals[key] then data.PropSignals[key]:Fire() end
end
instanceMeta.__tostring = function(inst) return RawData[inst].Name end

newInstance = function(className, internal)
	if not classes[className] then
		error("Unable to create an Instance of type \"" .. tostring(className) .. "\"")
	end
	if not internal then
		local notCreatable = { Player = true, Players = true, Workspace = true, Camera = false }
		if notCreatable[className] then error("Unable to create an Instance of type \"" .. className .. "\"") end
	end
	local inst = setmetatable({}, instanceMeta)
	RawData[inst] = {
		ClassName = className, Name = className, Parent = nil, Children = {}, Props = {}, Attributes = {}, Tags = {},
		Signals = {}, AttrSignals = {}, PropSignals = {}, Methods = nil,
	}
	-- sensible defaults used by the game
	local d = RawData[inst].Props
	if isA(className, "BasePart") then
		d.Size = v3(2, 1, 4)
		d.CFrame = CFrame.identity
		d.Anchored = false
	end
	if (className == "RemoteEvent" or className == "RemoteFunction") and M.patchRemote then
		M.patchRemote(inst)
	end
	return inst
end
Instance.new = function(className, parent)
	local inst = newInstance(className, false)
	if parent then setParent(inst, parent) end
	return inst
end
M.Instance = Instance
M.RawData = RawData
M.newInstance = newInstance
M.setParent = setParent
M.InstanceMethods = InstanceMethods
M.isInGame = isInGame
M.descendants = descendants

local function setMethods(inst, methods)
	RawData[inst].Methods = methods
end
M.setMethods = setMethods

-- game root
gameRoot = newInstance("DataModel", true)
M.game = gameRoot
RawData[gameRoot].Name = "game"

local services = {}
local function service(name)
	if services[name] then return services[name] end
	local inst = newInstance(name, true)
	RawData[inst].Name = name
	setParent(inst, gameRoot)
	services[name] = inst
	return inst
end
M.service = service

---------------------------------------------------------------------------
-- services with behaviour
---------------------------------------------------------------------------
local Players = service("Players")
local players = {}
setMethods(Players, {
	GetPlayers = function() return table.clone(players) end,
	GetPlayerByUserId = function(_, id)
		for _, p in players do if RawData[p].Props.UserId == id then return p end end
		return nil
	end,
	GetPlayerFromCharacter = function(_, character)
		for _, p in players do if RawData[p].Props.Character == character then return p end end
		return nil
	end,
})
M.players = players

local nextUserId = 1000
function M.newPlayer(name)
	local player = newInstance("Player", true)
	nextUserId += 1
	local data = RawData[player]
	data.Name = name
	data.Props.UserId = nextUserId
	data.Props.DisplayName = name
	data.Props.Character = nil
	setMethods(player, {
		LoadCharacter = function(self)
			return M.spawnCharacter(self)
		end,
	})
	setParent(player, Players)
	table.insert(players, player)
	return player
end
function M.removePlayer(player)
	for i, p in players do
		if p == player then table.remove(players, i) break end
	end
	-- PlayerRemoving fires while the player is still a child in Roblox
	RawData[Players].Signals.PlayerRemoving = RawData[Players].Signals.PlayerRemoving or newSignal()
	RawData[Players].Signals.PlayerRemoving:Fire(player)
	task.spawn(function() end)
	setParent(player, nil)
end
function M.spawnCharacter(player)
	local character = newInstance("Model", true)
	RawData[character].Name = RawData[player].Name
	local root = newInstance("Part", true)
	RawData[root].Name = "HumanoidRootPart"
	RawData[root].Props.CFrame = CFrame.new(0, 5, -13)
	RawData[root].Props.Size = v3(2, 2, 1)
	setParent(root, character)
	local humanoid = newInstance("Humanoid", true)
	RawData[humanoid].Props.Health = 100
	RawData[humanoid].Props.MaxHealth = 100
	RawData[humanoid].Props.WalkSpeed = 16
	RawData[humanoid].Props.HipHeight = 2
	RawData[humanoid].Props.PlatformStand = false
	RawData[root].Props.AssemblyLinearVelocity = v3(0, 0, 0)
	setParent(humanoid, character)
	RawData[character].Props.PrimaryPart = root
	setParent(character, workspace_ref)
	RawData[player].Props.Character = character
	local sig = RawData[player].Signals.CharacterAdded
	if not sig then sig = newSignal() RawData[player].Signals.CharacterAdded = sig end
	sig:Fire(character)
	return character
end
RawData[service("Players")].Signals.PlayerAdded = newSignal()

local Workspace = service("Workspace")
workspace_ref = Workspace
M.workspace = Workspace
setMethods(Workspace, {
	GetServerTimeNow = function() return Sim.now end,
})
local camera = newInstance("Camera", true)
RawData[camera].Props.ViewportSize = v2(1280, 720)
RawData[camera].Props.CFrame = CFrame.new(0, 30, -60)
setParent(camera, Workspace)
RawData[Workspace].Props.CurrentCamera = camera

-- local player (the "client" in the single-process sim)
M.localPlayerRef = nil
local playersMethods = RawData[Players].Methods
local oldIndexPlayers
RawData[Players].LocalPlayerGetter = function() return M.localPlayerRef end

-- RunService
local RunService = service("RunService")
RawData[RunService].Signals.Heartbeat = newSignal()
RawData[RunService].Signals.RenderStepped = newSignal()
RawData[RunService].Signals.Stepped = newSignal()
setMethods(RunService, {
	IsStudio = function() return true end,
	IsServer = function() return M.isServer end,
	IsClient = function() return not M.isServer end,
	BindToRenderStep = function(_, name, priority, fn) M.renderSteps[name] = { Priority = priority, Fn = fn } end,
	UnbindFromRenderStep = function(_, name) M.renderSteps[name] = nil end,
})
M.isServer = true
M.renderSteps = {}
Sim.fireFrame = function(dt)
	RawData[RunService].Signals.Heartbeat:Fire(dt)
	if not M.isServer or M.clientRunning then
		RawData[RunService].Signals.RenderStepped:Fire(dt)
		local ordered = {}
		for _, entry in M.renderSteps do table.insert(ordered, entry) end
		table.sort(ordered, function(a, b) return a.Priority < b.Priority end)
		for _, entry in ordered do entry.Fn(dt) end
	end
end

-- CollectionService
local CollectionService = service("CollectionService")
setMethods(CollectionService, {
	GetTagged = function(_, tag)
		local out = {}
		for inst in tagRegistry[tag] or {} do
			if not RawData[inst].Destroyed and isInGame(inst) then table.insert(out, inst) end
		end
		return out
	end,
	GetInstanceAddedSignal = function(_, tag)
		tagSignals.added[tag] = tagSignals.added[tag] or newSignal()
		return tagSignals.added[tag]
	end,
	GetInstanceRemovedSignal = function(_, tag)
		tagSignals.removed[tag] = tagSignals.removed[tag] or newSignal()
		return tagSignals.removed[tag]
	end,
	AddTag = function(_, inst, tag) InstanceMethods.AddTag(inst, tag) end,
	RemoveTag = function(_, inst, tag) InstanceMethods.RemoveTag(inst, tag) end,
	HasTag = function(_, inst, tag) return InstanceMethods.HasTag(inst, tag) end,
})

-- TweenService / Debris
local TweenService = service("TweenService")
setMethods(TweenService, {
	Create = function(_, instance, info, props)
		return {
			Play = function()
				for k, v in props do
					local ok, err = pcall(function() instance[k] = v end)
					if not ok then logError("Tween property " .. tostring(k), err) end
				end
			end,
			Cancel = function() end,
		}
	end,
})
local Debris = service("Debris")
setMethods(Debris, { AddItem = function(_, inst, t)
	task.delay(t or 10, function() if RawData[inst] then InstanceMethods.Destroy(inst) end end)
end })

-- ReplicatedFirst / SoundService / misc
local ReplicatedFirst = service("ReplicatedFirst")
setMethods(ReplicatedFirst, { RemoveDefaultLoadingScreen = function() end })

local ProximityPromptService = service("ProximityPromptService")
RawData[ProximityPromptService].Signals.PromptTriggered = newSignal()

local UserInputService = service("UserInputService")
RawData[UserInputService].Props.TouchEnabled = false
RawData[UserInputService].Props.KeyboardEnabled = true
RawData[UserInputService].Signals.InputChanged = newSignal()
RawData[UserInputService].Signals.InputEnded = newSignal()
RawData[UserInputService].Signals.InputBegan = newSignal()
RawData[UserInputService].Props.MouseBehavior = "Default"
RawData[UserInputService].Props.MouseIconEnabled = true
M.keysDown = {}
setMethods(UserInputService, { IsKeyDown = function(_, key) return M.keysDown[tostring(key)] == true end })

local ContextActionService = service("ContextActionService")
M.boundActions = {}
setMethods(ContextActionService, {
	BindAction = function(_, name, fn) M.boundActions[name] = fn end,
	UnbindAction = function(_, name) M.boundActions[name] = nil end,
	SetTitle = function() end, SetPosition = function() end,
})
service("GuiService")
service("SoundService")
service("Lighting")
service("ReplicatedStorage")
service("ServerScriptService")
service("ServerStorage")
service("StarterGui")
service("StarterPlayer")
service("HttpService")
setMethods(service("HttpService"), { GenerateGUID = function() Sim.guid = (Sim.guid or 0) + 1 return "guid-" .. Sim.guid end })

-- DataStore + Marketplace
local store = {}
M.dataStoreData = store
local DataStoreService = service("DataStoreService")
setMethods(DataStoreService, {
	GetDataStore = function()
		return {
			UpdateAsync = function(_, key, fn)
				local old = store[key]
				local copy = old and table.clone(old) or nil
				local new = fn(copy)
				if new == nil then return nil end
				store[key] = new
				return new
			end,
		}
	end,
})
local MarketplaceService = service("MarketplaceService")
setMethods(MarketplaceService, {
	UserOwnsGamePassAsync = function() return false end,
	PromptGamePassPurchase = function() end,
	PromptProductPurchase = function() end,
})
RawData[MarketplaceService].Signals.PromptGamePassPurchaseFinished = newSignal()

-- bindToClose
setMethods(gameRoot, {
	GetService = function(_, name) return service(name) end,
	BindToClose = function(_, fn) M.closeHandlers = M.closeHandlers or {} table.insert(M.closeHandlers, fn) end,
	IsLoaded = function() return true end,
})
RawData[gameRoot].Props.JobId = "job-1"
RawData[gameRoot].Signals.Loaded = newSignal()

-- make `Players.LocalPlayer` work (read)
do
	local oldResolve = resolve
	local mt = getmetatable(Players)
	local idx = mt.__index
	-- LocalPlayer is a declared member of Players; patch via Props lookup
	RawData[Players].Props.LocalPlayer = nil
	setmetatable(RawData[Players].Props, { __index = function(_, k)
		if k == "LocalPlayer" then return M.localPlayerRef end
		return nil
	end })
end

-- Remote objects: wire client <-> server inside one process
local function wireRemotes()
	local function patch(inst)
		local data = RawData[inst]
		if data.ClassName == "RemoteEvent" then
			data.Signals.OnServerEvent = data.Signals.OnServerEvent or newSignal()
			data.Signals.OnClientEvent = data.Signals.OnClientEvent or newSignal()
			data.Methods = {
				FireClient = function(_, player, ...)
					if player == M.localPlayerRef and M.clientRunning then data.Signals.OnClientEvent:Fire(...) end
					M.remoteLog = M.remoteLog or {}
					table.insert(M.remoteLog, { data.Name, RawData[player].Name, ... })
				end,
				FireAllClients = function(_, ...)
					if M.clientRunning then data.Signals.OnClientEvent:Fire(...) end
					M.remoteLog = M.remoteLog or {}
					table.insert(M.remoteLog, { data.Name, "ALL", ... })
				end,
				FireServer = function(_, ...) data.Signals.OnServerEvent:Fire(M.localPlayerRef, ...) end,
			}
		elseif data.ClassName == "RemoteFunction" then
			data.Methods = {
				InvokeServer = function(_, ...)
					local handler = data.Props.OnServerInvoke
					if not handler then error("no OnServerInvoke") end
					return handler(M.localPlayerRef, ...)
				end,
			}
		end
	end
	M.patchRemote = patch
end
wireRemotes()
-- RemoteFunction.OnServerInvoke is a callback member; allow assignment
classes.RemoteFunction.members.OnServerInvoke = "any"

return M
