--[[
	Headless Roblox runtime for Lune. Loads a Rojo-built place and runs its ModuleScripts with the
	Roblox globals they expect, plus the engine methods Lune doesn't have (Model pivots, ScaleTo,
	bounding boxes, Random, CollectionService, signals).

	It is NOT a physics or rendering engine: it is good for code that builds instances (the world,
	houses, hamster models), pure logic (economy, configs) and geometry checks.
]]

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")

local Instance = roblox.Instance
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Enum = roblox.Enum

local Runtime = {}

---------------------------------------------------------------------------
-- Random (deterministic, Roblox-compatible surface)
---------------------------------------------------------------------------

local RandomClass = {}
RandomClass.__index = RandomClass

local function nextRaw(self): number
	-- xorshift32
	local x = self._state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self._state = x
	return x / 4294967296
end

local Random = {}
function Random.new(seed: number?)
	local s = math.floor(seed or (os.clock() * 1e6)) % 4294967295
	if s == 0 then
		s = 2463534242
	end
	return setmetatable({ _state = s }, RandomClass)
end
function RandomClass:NextNumber(min: number?, max: number?): number
	local a, b = min or 0, max or 1
	return a + (b - a) * nextRaw(self)
end
function RandomClass:NextInteger(min: number, max: number): number
	return min + math.floor(nextRaw(self) * (max - min + 1))
end
function RandomClass:NextUnitVector()
	local z = self:NextNumber(-1, 1)
	local t = self:NextNumber(0, math.pi * 2)
	local r = math.sqrt(1 - z * z)
	return Vector3.new(r * math.cos(t), r * math.sin(t), z)
end
function RandomClass:Shuffle(list)
	for i = #list, 2, -1 do
		local j = self:NextInteger(1, i)
		list[i], list[j] = list[j], list[i]
	end
end
function RandomClass:Clone()
	return setmetatable({ _state = self._state }, RandomClass)
end
Runtime.Random = Random

---------------------------------------------------------------------------
-- signals
---------------------------------------------------------------------------

local function newSignal()
	local signal = { _handlers = {} }
	function signal:Connect(fn)
		table.insert(self._handlers, fn)
		local connection = { Connected = true }
		function connection.Disconnect()
			connection.Connected = false
			local index = table.find(signal._handlers, fn)
			if index then
				table.remove(signal._handlers, index)
			end
		end
		return connection
	end
	signal.Once = signal.Connect
	function signal:Fire(...)
		for _, handler in table.clone(self._handlers) do
			handler(...)
		end
	end
	function signal:Wait()
		return nil
	end
	return signal
end
Runtime.newSignal = newSignal

---------------------------------------------------------------------------
-- engine methods
---------------------------------------------------------------------------

-- Pivot / scale bookkeeping lives in attributes (Lune gives a new userdata per access, so tables
-- keyed by instances don't work). Runtime.strip removes them before anything is saved.
local function getStored(instance, key)
	return instance:GetAttribute(key)
end

local function parts(model)
	local list = {}
	if model:IsA("BasePart") then
		table.insert(list, model)
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(list, descendant)
		end
	end
	return list
end

local function corners(part)
	local half = part.Size / 2
	local list = {}
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(list, part.CFrame:PointToWorldSpace(Vector3.new(half.X * sx, half.Y * sy, half.Z * sz)))
			end
		end
	end
	return list
end

local function boundsIn(model, frame)
	local minV, maxV = nil, nil
	for _, part in parts(model) do
		for _, corner in corners(part) do
			local p = frame:PointToObjectSpace(corner)
			minV = if minV then minV:Min(p) else p
			maxV = if maxV then maxV:Max(p) else p
		end
	end
	if not minV then
		return frame, Vector3.zero
	end
	local center = (minV + maxV) / 2
	return frame * CFrame.new(center), maxV - minV
end

local function getPivot(model)
	if model:IsA("BasePart") then
		return model.CFrame
	end
	local primary = model.PrimaryPart
	if primary then
		return primary.CFrame
	end
	local stored = getStored(model, "__pivot")
	if stored then
		return stored
	end
	local box = boundsIn(model, CFrame.new())
	return CFrame.new(box.Position)
end

local function pivotTo(model, target)
	local delta = target * getPivot(model):Inverse()
	if model:IsA("BasePart") then
		model.CFrame = target
	end
	for _, part in parts(model) do
		if part ~= model then
			part.CFrame = delta * part.CFrame
		end
	end
	if not model:IsA("BasePart") then
		model:SetAttribute("__pivot", target)
	end
end

for _, className in { "Model", "Workspace", "WorldModel" } do
	roblox.implementMethod(className, "GetPivot", getPivot)
	roblox.implementMethod(className, "PivotTo", pivotTo)
	roblox.implementMethod(className, "GetBoundingBox", function(model)
		local frame = getPivot(model)
		return boundsIn(model, CFrame.new(frame.Position) * frame.Rotation)
	end)
	roblox.implementMethod(className, "GetExtentsSize", function(model)
		local _, size = boundsIn(model, getPivot(model))
		return size
	end)
	roblox.implementMethod(className, "MoveTo", function(model, position)
		pivotTo(model, getPivot(model).Rotation + position)
	end)
	roblox.implementMethod(className, "GetScale", function(model)
		return getStored(model, "__scale") or 1
	end)
	roblox.implementMethod(className, "ScaleTo", function(model, scale)
		local factor = scale / (getStored(model, "__scale") or 1)
		model:SetAttribute("__scale", scale)
		local origin = getPivot(model)
		for _, part in parts(model) do
			local relative = origin:ToObjectSpace(part.CFrame)
			part.Size *= factor
			part.CFrame = origin * (relative.Rotation + relative.Position * factor)
		end
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("JointInstance") then
				descendant.C0 = descendant.C0.Rotation + descendant.C0.Position * factor
				descendant.C1 = descendant.C1.Rotation + descendant.C1.Position * factor
			elseif descendant:IsA("Attachment") then
				descendant.Position *= factor
			elseif descendant:IsA("SpecialMesh") then
				descendant.Offset *= factor
				if descendant.MeshType == Enum.MeshType.FileMesh then
					descendant.Scale *= factor
				end
			elseif descendant:IsA("Light") then
				(descendant :: any).Range *= factor
			end
		end
	end)
end
for _, className in { "BasePart", "Part", "WedgePart", "MeshPart", "CornerWedgePart", "TrussPart", "SpawnLocation", "Seat" } do
	pcall(roblox.implementMethod, className, "GetPivot", getPivot)
	pcall(roblox.implementMethod, className, "PivotTo", pivotTo)
end

-- Lune hands out a fresh userdata for every access to the same Instance, so signals are keyed by
-- an id stored on the instance itself.
local signalsById = {}
local nextSignalId = 0
local function signalFor(instance, key)
	local id = instance:GetAttribute("__runtimeId")
	if not id then
		nextSignalId += 1
		id = nextSignalId
		instance:SetAttribute("__runtimeId", id)
	end
	signalsById[id] = signalsById[id] or {}
	local bucket = signalsById[id]
	bucket[key] = bucket[key] or newSignal()
	return bucket[key]
end
Runtime.signalFor = signalFor

roblox.implementMethod("Instance", "WaitForChild", function(self, name)
	return self:FindFirstChild(name)
end)
roblox.implementMethod("Instance", "GetPropertyChangedSignal", function(self, property)
	return signalFor(self, "Changed:" .. property)
end)
roblox.implementMethod("Instance", "GetAttributeChangedSignal", function(self, attribute)
	return signalFor(self, "Attr:" .. attribute)
end)
for _, name in { "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "AncestryChanged", "Changed", "AttributeChanged", "Destroying" } do
	pcall(roblox.implementProperty, "Instance", name, function(self)
		return signalFor(self, name)
	end)
end

roblox.implementMethod("CollectionService", "GetTagged", function(self, tag)
	local list = {}
	for _, descendant in Runtime.game:GetDescendants() do
		if descendant:HasTag(tag) then
			table.insert(list, descendant)
		end
	end
	return list
end)
roblox.implementMethod("CollectionService", "GetInstanceAddedSignal", function(self, tag)
	return signalFor(self, "Added:" .. tag)
end)
roblox.implementMethod("CollectionService", "GetInstanceRemovedSignal", function(self, tag)
	return signalFor(self, "Removed:" .. tag)
end)
roblox.implementMethod("CollectionService", "AddTag", function(self, instance, tag)
	instance:AddTag(tag)
end)
roblox.implementMethod("CollectionService", "HasTag", function(self, instance, tag)
	return instance:HasTag(tag)
end)

---------------------------------------------------------------------------
-- module loader
---------------------------------------------------------------------------

local loaded = {}

-- task library whose spawned functions report their errors (Lune would swallow them)
Runtime.errors = {}
local function guarded(fn)
	if type(fn) ~= "function" then
		return fn
	end
	return function(...)
		local ok, err = xpcall(fn, function(e)
			return tostring(e) .. "\n" .. debug.traceback()
		end, ...)
		if not ok then
			table.insert(Runtime.errors, tostring(err))
			if not Runtime.quiet or Runtime.reportErrors then
				require("@lune/stdio").ewrite("[task error] " .. tostring(err) .. "\n")
			end
		end
	end
end
local guardedTask = setmetatable({
	spawn = function(fn, ...)
		return task.spawn(guarded(fn), ...)
	end,
	defer = function(fn, ...)
		return task.defer(guarded(fn), ...)
	end,
	delay = function(seconds, fn, ...)
		return task.delay(seconds, guarded(fn), ...)
	end,
}, { __index = task })

local function baseEnvironment(scriptInstance)
	local env = {
		script = scriptInstance,
		game = Runtime.game,
		workspace = Runtime.game and Runtime.game:GetService("Workspace"),
		Instance = Instance,
		Vector3 = Vector3,
		Vector2 = roblox.Vector2,
		Vector3int16 = roblox.Vector3int16,
		Vector2int16 = roblox.Vector2int16,
		CFrame = CFrame,
		Color3 = roblox.Color3,
		BrickColor = roblox.BrickColor,
		ColorSequence = roblox.ColorSequence,
		ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
		NumberSequence = roblox.NumberSequence,
		NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
		NumberRange = roblox.NumberRange,
		UDim = roblox.UDim,
		UDim2 = roblox.UDim2,
		Rect = roblox.Rect,
		Ray = roblox.Ray,
		Region3 = roblox.Region3,
		Font = roblox.Font,
		Faces = roblox.Faces,
		Axes = roblox.Axes,
		PhysicalProperties = roblox.PhysicalProperties,
		Enum = Enum,
		Random = Random,
		TweenInfo = { new = function(time, style, direction, repeats, reverses, delayTime)
			return { Time = time or 1, EasingStyle = style, EasingDirection = direction, RepeatCount = repeats or 0, Reverses = reverses or false, DelayTime = delayTime or 0 }
		end },
		task = guardedTask,
		tick = os.clock,
		time = os.clock,
		wait = task.wait,
		delay = guardedTask.delay,
		spawn = guardedTask.spawn,
		typeof = typeof,
		warn = function(...)
			if not Runtime.quiet then
				print("[warn]", ...)
			end
		end,
		print = function(...)
			if not Runtime.quiet then
				print(...)
			end
		end,
		require = Runtime.require,
	}
	return setmetatable(env, { __index = function(_, key)
		return (getfenv(0) :: any)[key]
	end })
end

function Runtime.environmentFor(scriptInstance)
	return baseEnvironment(scriptInstance)
end

function Runtime.require(target)
	if type(target) == "string" then
		return require(target)
	end
	-- cache by path: Lune returns a new userdata for every access to the same ModuleScript
	local key = target:GetFullName()
	if loaded[key] ~= nil then
		return loaded[key]
	end
	assert(target:IsA("ModuleScript"), "require: not a ModuleScript: " .. target:GetFullName())
	local chunk = luau.load(luau.compile(target.Source), {
		debugName = target:GetFullName(),
		environment = baseEnvironment(target),
		injectGlobals = false,
	})
	local result = chunk()
	loaded[key] = result
	return result
end

-- Builds the place from the project (rojo) and loads it.
function Runtime.boot(projectRoot: string)
	local out = "/tmp/hamsterplaza-runtime.rbxl"
	local rojo = process.env.ROJO or "rojo"
	local result = process.exec(rojo, { "build", projectRoot .. "/default.project.json", "-o", out })
	assert(result.ok, "rojo build failed: " .. result.stderr)
	Runtime.game = roblox.deserializePlace(fs.readFile(out))
	return Runtime.game
end

function Runtime.modules()
	return Runtime.game:GetService("ReplicatedStorage").Modules
end

function Runtime.mod(name: string)
	return Runtime.require(Runtime.modules()[name])
end

-- Removes the runtime's bookkeeping attributes (call before serializing anything).
function Runtime.strip(root)
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, instance in list do
		for name in instance:GetAttributes() do
			if string.sub(name, 1, 2) == "__" then
				instance:SetAttribute(name, nil)
			end
		end
	end
end

Runtime.roblox = roblox
return Runtime
