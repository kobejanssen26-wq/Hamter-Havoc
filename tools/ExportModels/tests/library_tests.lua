-- Behaviour tests for the library assets, run in the mock Roblox runtime. They run the REAL library scripts
-- (ModelLibrary/**/scripts) against the REAL built assets: nothing here is a re-implementation.
local results = { pass = 0, fail = 0 }
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end
local function near(a, b, eps) return math.abs(a - b) <= (eps or 1e-3) end

M.isServer = false
M.clientRunning = true
local function frames(count, dt)
	for _ = 1, count do
		M.Sim.fireFrame(dt)
	end
end
local function asset(name)
	for _, a in ASSETS do
		if a.Config.Name == name then return a end
	end
	error("no asset " .. name)
end
local function build(name, options)
	local a = asset(name)
	return a.Build(newContext(a, options))
end
-- Runs a Script / ModuleScript exactly as exported: its Source text is compiled and executed with `script` and `require` bound.
local gameRequire = require
local compiled = {}
local sandbox = { CFrame = CFrame, Vector3 = Vector3, Vector2 = Vector2, Color3 = Color3, UDim2 = UDim2, UDim = UDim, Instance = Instance, Enum = Enum, game = game, workspace = workspace, task = task, os = os, typeof = typeof, math = math, string = string, table = table, print = print, warn = warn, pairs = pairs, ipairs = ipairs, next = next, type = type, tostring = tostring, tonumber = tonumber, select = select, pcall = pcall, error = error, assert = assert, setmetatable = setmetatable, getmetatable = getmetatable, Random = Random, NumberRange = NumberRange, NumberSequence = NumberSequence, NumberSequenceKeypoint = NumberSequenceKeypoint, ColorSequence = ColorSequence, ColorSequenceKeypoint = ColorSequenceKeypoint, TweenInfo = TweenInfo, Rect = Rect }
local function libRequire(moduleInstance)
	local data = RawData[moduleInstance]
	if data.Source then
		return gameRequire(moduleInstance)
	end
	if compiled[moduleInstance] == nil then
		local env = setmetatable({ script = moduleInstance, require = libRequire }, { __index = sandbox })
		local fn = assert(loadstring(data.Props.Source, "=" .. data.Name))
		setfenv(fn, env)
		compiled[moduleInstance] = fn()
	end
	return compiled[moduleInstance]
end
local function runScript(scriptInstance)
	local env = setmetatable({ script = scriptInstance, require = libRequire }, { __index = sandbox })
	local fn = assert(loadstring(RawData[scriptInstance].Props.Source, "=" .. RawData[scriptInstance].Name))
	setfenv(fn, env)
	task.spawn(fn)
end
local function lowestY(model)
	local low = math.huge
	for _, d in M.descendants(model) do
		local data = RawData[d]
		local size, cf = data.Props.Size, data.Props.CFrame
		if size and cf then
			for _, sx in { -1, 1 } do for _, sy in { -1, 1 } do for _, sz in { -1, 1 } do
				low = math.min(low, cf:PointToWorldSpace(Vector3.new(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2)).Y)
			end end end
		end
	end
	return low
end

print("== Hamster_Wheel: spin direction, axle, pivot ==")
for _, yaw in { 0, 90, 200 } do
	local wheelAsset = build("Hamster_Wheel")
	wheelAsset:PivotTo(CFrame.new(40, 10, -25) * CFrame.Angles(0, math.rad(yaw), 0)) -- anywhere, any rotation
	local wheel = wheelAsset:FindFirstChild("Wheel")
	local controller = wheelAsset:FindFirstChild("WheelSpin")
	runScript(controller)
	frames(2, 1 / 60)
	local assemblyCF = wheelAsset:GetPivot()
	local hub = wheel.PrimaryPart
	local hubStart = hub.CFrame
	local bottom0 = wheel:GetPivot().Position + assemblyCF:VectorToWorldSpace(Vector3.new(0, -2.3, 0))
	local pivot0 = wheel:GetPivot()
	frames(6, 1 / 60)
	local pivot1 = wheel:GetPivot()
	local velocity = (pivot1 * pivot0:Inverse() * bottom0 - bottom0) / (6 / 60)
	local runWorld = assemblyCF:VectorToWorldSpace(wheel:GetAttribute("RunDirection"))
	check(string.format("yaw %d: the floor under the hamster moves AGAINST the run direction", yaw), velocity:Dot(runWorld) < -1, string.format("v.run = %.2f studs/s", velocity:Dot(runWorld)))
	check(string.format("yaw %d: axle stays fixed (hub position unchanged)", yaw), (pivot1.Position - pivot0.Position).Magnitude < 1e-3)
	local axleNow = pivot1:VectorToWorldSpace(Vector3.new(1, 0, 0))
	local axleBefore = pivot0:VectorToWorldSpace(Vector3.new(1, 0, 0))
	check(string.format("yaw %d: rotation about the hub axle (axle direction unchanged)", yaw), (axleNow - axleBefore).Magnitude < 1e-3)
	local zWorld = assemblyCF:VectorToWorldSpace(Vector3.new(0, 0, 1))
	check(string.format("yaw %d: axle is perpendicular to the run direction and horizontal", yaw), near(math.abs(axleNow:Dot(zWorld)), 1, 1e-3) and near(axleNow:Dot(runWorld), 0, 1e-3))
	wheelAsset:Destroy()
end

local wheelModel = build("Hamster_Wheel")
check("wheel pivot = bottom centre of the stand (lowest point at y = 0)", near(lowestY(wheelModel), 0, 0.01), lowestY(wheelModel))
check("wheel PrimaryPart is WheelBase, hub is the inner wheel's PrimaryPart", wheelModel.PrimaryPart.Name == "WheelBase" and wheelModel:FindFirstChild("Wheel").PrimaryPart.Name == "Hub")

print("== Hamster_Default: joints, pivot, animation ==")
local hamster = build("Hamster_Default")
check("hamster pivot at its feet (lowest point near y = 0)", math.abs(lowestY(hamster)) < 0.2, lowestY(hamster))
local motors = 0
for _, d in M.descendants(hamster) do
	if RawData[d].ClassName == "Motor6D" then
		motors += 1
		check("Motor6D " .. RawData[d].Name .. " has both parts inside the model", RawData[d].Props.Part0 ~= nil and RawData[d].Props.Part1 ~= nil and RawData[d].Props.Part0:IsDescendantOf(hamster) and RawData[d].Props.Part1:IsDescendantOf(hamster))
	end
end
check("hamster has the 9 animated joints", motors == 9, motors)
local controller = hamster:FindFirstChild("HamsterAutoAnimate")
hamster:SetAttribute("MoveSpeed", 7)
runScript(controller)
local head = hamster:FindFirstChild("HeadJ", true)
local paw = hamster:FindFirstChild("PawFLJ", true)
local seen = {}
for step = 1, 40 do
	frames(1, 1 / 30)
	table.insert(seen, paw.Transform.Y + paw.Transform.X * 3 + paw.Transform.Z * 7)
end
local changes = 0
for i = 2, #seen do
	if math.abs(seen[i] - seen[i - 1]) > 1e-6 then changes += 1 end
end
check("bundled controller animates the paws while MoveSpeed > 0", changes > 20, changes .. " changing frames of 39")

print("== Hamster_Wheel_Complete: hamster inside the wheel ==")
local complete = build("Hamster_Wheel_Complete")
local inner = complete:FindFirstChild("Hamster")
local wheelPart = complete:FindFirstChild("Wheel")
check("assembly contains Wheel + Hamster + WheelSpin", inner ~= nil and wheelPart ~= nil and complete:FindFirstChild("WheelSpin") ~= nil)
local floorY = complete:GetPivot().Position.Y + 2.7 - 2.3
check("hamster stands on the wheel floor", near(inner:GetPivot().Position.Y, floorY + 0.1, 0.05), inner:GetPivot().Position.Y)
local runDir = complete:GetPivot():VectorToWorldSpace(wheelPart:GetAttribute("RunDirection"))
check("hamster faces the run direction", inner:GetPivot().LookVector:Dot(runDir) > 0.99, inner:GetPivot().LookVector:Dot(runDir))
local maxHeight = 0
for _, d in M.descendants(inner) do
	local data = RawData[d]
	if data.Props.Size and data.Props.CFrame then
		maxHeight = math.max(maxHeight, data.Props.CFrame.Position.Y + data.Props.Size.Y / 2)
	end
end
check("hamster fits inside the wheel (below the hub + radius)", maxHeight < complete:GetPivot().Position.Y + 2.7 + 2.3, maxHeight)

print("== standalone packages work without the game ==")
do
	local package = build("HamsterBuilder_Package")
	local builder = libRequire(package:FindFirstChild("HamsterBuilder"))
	local database = libRequire(package:FindFirstChild("HamsterDatabase"))
	check("package: HamsterDatabase has all 172 species", database.Total == 172, database.Total)
	local built, jointsOk = 0, true
	for index = 1, database.Total, 6 do
		local model = builder.build(database.Species[index], { Scale = 1, LowDetail = false, Particles = false })
		built += 1
		if model.PrimaryPart == nil then jointsOk = false end
		model:Destroy()
	end
	check("package: builds species from every part of the database with a PrimaryPart", built >= 28 and jointsOk, built .. " built")
	local icons = libRequire(build("Hamster_Icons"))
	local frame = icons.create(nil, "coin", { Size = UDim2.fromOffset(32, 32) })
	check("icons module: create() draws an icon (no emoji, no assets)", frame ~= nil and #frame:GetChildren() > 2)
end

print("== library hygiene ==")
for _, a in ASSETS do
	local problems = 0
	for _, d in M.descendants(a.Build(newContext(a))) do
		local data = RawData[d]
		for key, value in data.Props do
			if type(value) == "string" and (string.find(value, "rbxassetid://", 1, true) or string.find(value, "rbxthumb://", 1, true)) and key ~= "Source" then problems += 1 end
		end
	end
	check(a.Config.Name .. ": no external asset ids", problems == 0, problems)
end

print(string.format("PASS %d FAIL %d", results.pass, results.fail))
