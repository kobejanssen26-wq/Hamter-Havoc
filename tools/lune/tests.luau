--[[
	Headless checks for the world, the apartments, the hamster wheels and the economy.
	usage: lune run tools/lune/tests.luau [projectRoot]
	Exits with code 1 when a check fails.
]]

local process = require("@lune/process")
local Runtime = require("./runtime")
local roblox = Runtime.roblox
local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

local root = process.args[1] or "."
local game = Runtime.boot(root)
Runtime.quiet = true

local failures, passes = 0, 0
local function check(ok: boolean, label: string, detail: string?)
	if ok then
		passes += 1
	else
		failures += 1
		print("FAIL  " .. label .. (if detail then "  (" .. detail .. ")" else ""))
	end
end

local Systems = game:GetService("ServerScriptService").Systems
local WorldBuilder = Runtime.require(Systems.WorldBuilder)
local HouseBuilder = Runtime.require(Systems.WorldBuilder.HouseBuilder)
local WorldLayout = Runtime.mod("WorldLayout")
local PathConfig = Runtime.mod("PathConfig")
local FloorConfig = Runtime.mod("FloorConfig")
local RarityConfig = Runtime.mod("RarityConfig")
local HamsterDatabase = Runtime.mod("HamsterDatabase")
local RebirthConfig = Runtime.mod("RebirthConfig")
local EconomyMath = Runtime.mod("EconomyMath")
local UpgradeConfig = Runtime.mod("UpgradeConfig")
local Template = Runtime.mod("ProfileTemplate")

local world = WorldBuilder.build()

---------------------------------------------------------------------------
-- layout
---------------------------------------------------------------------------
check(#world.Houses == WorldLayout.HouseCount, "all houses built")
local half = WorldLayout.LotHalfWidth
for i = 1, #WorldLayout.HouseColumns - 1 do
	local gap = (WorldLayout.HouseColumns[i + 1] - WorldLayout.HouseColumns[i]) - 2 * half
	check(gap >= 15, "plots have room between them", "gap " .. gap)
end
check(WorldLayout.HouseColumns[3] - half >= WorldLayout.PlazaHalfWidth + 5, "plaza square stays clear of the plots")
check(PathConfig.Width >= 20, "road is wide", tostring(PathConfig.Width))
check(WorldLayout.PromenadeZ + WorldLayout.PromenadeHalfWidth < WorldLayout.GateDistance, "promenade ends before the gates")
check(WorldLayout.GateDistance + WorldLayout.LotDepth < WorldLayout.GroundHalfZ, "lots fit on the ground")
check(PathConfig.Length / 2 < WorldLayout.GroundHalfX, "road fits on the ground")
check(math.abs(PathConfig.LaneOffsets[1]) + 3.6 <= PathConfig.HalfWidth, "lanes leave room for the biggest ball")

---------------------------------------------------------------------------
-- apartments: floors grow and shrink, slots follow, the lift has a prompt per floor
---------------------------------------------------------------------------
local house = world.Houses[1]
check(house.FloorCount == 1, "a new apartment has one floor")
for floors = 1, FloorConfig.Count do
	HouseBuilder.setFloors(house, floors, true)
	local slots = 0
	for _ in house.Slots do
		slots += 1
	end
	local lifts = 0
	for _ in house.ElevatorPrompts do
		lifts += 1
	end
	check(slots == floors * FloorConfig.WheelsPerFloor, "slots for " .. floors .. " floors", tostring(slots))
	check(lifts == floors, "lift panel on every floor", tostring(lifts))
	check(house.Model.Floors:FindFirstChild("Floor" .. floors) ~= nil, "floor model " .. floors)
end
check(house.Stations.TurboWheels ~= nil, "advanced upgrades live in the lab (floor 3)")
HouseBuilder.setFloors(house, 2, true)
check(house.Stations.TurboWheels == nil and house.Slots[13] == nil, "removing floors removes their slots and stations")
check(house.Model.Floors:FindFirstChild("Floor3") == nil, "floor 3 model removed")
local roofY = house.RoofAnchor.CFrame.Position.Y
HouseBuilder.setFloors(house, 4, true)
check(house.RoofAnchor.CFrame.Position.Y > roofY + 15, "roof sign moves up with the building")
for floor = 1, 4 do
	local landing = HouseBuilder.landingCFrame(house, floor)
	local localPos = house.CFrame:PointToObjectSpace(landing.Position)
	check(math.abs(localPos.X) < 26 and localPos.Z > 32 and localPos.Z < 74, "lift landing is inside the building on floor " .. floor)
end

---------------------------------------------------------------------------
-- wheels: turn around the axle, and the right way for the running hamster
---------------------------------------------------------------------------
local wheelChecks = 0
for _, h in world.Houses do
	HouseBuilder.setFloors(h, FloorConfig.Count, true)
	for index, slot in h.Slots do
		HouseBuilder.setWheel(h, index, true)
		HouseBuilder.setWheelSpeed(slot, 2.6)
		local wheel = slot.Wheel
		local speed = wheel:GetAttribute("Speed")
		local home = wheel:GetAttribute("HomeCFrame")
		check(wheel:GetAttribute("Axis") == "X", "wheel spins around the hub's X axis (the axle)")
		-- the axle of the stand runs along the slot centre's Z axis; the hub's X axis must be the same line
		local axle = slot.Center.ZVector
		check(math.abs(math.abs(home.XVector:Dot(axle)) - 1) < 1e-4, "hub X axis is the axle", tostring(home.XVector:Dot(axle)))
		-- move a point on the bottom of the wheel the way AmbientController does (Home * Angles(angle, 0, 0))
		local radius = 3
		local bottomWorld = slot.Center.Position - Vector3.yAxis * radius
		local bottomLocal = home:PointToObjectSpace(bottomWorld)
		local dt = 0.05
		local after = (home * CFrame.Angles(speed * dt, 0, 0)):PointToWorldSpace(bottomLocal)
		local motion = after - bottomWorld
		local forward = slot.RunCFrame.LookVector
		check(motion:Dot(forward) < 0, "wheel floor moves backwards under the running hamster", string.format("house %d slot %d", h.Index, index))
		-- no wobble: every rung stays on the circle around the axle while turning
		local maxDrift = 0
		for _, part in wheel:GetDescendants() do
			if part:IsA("BasePart") and part.Name == "Rung" then
				local position = part.CFrame.Position
				local p0 = home:PointToObjectSpace(position)
				local p1 = (home * CFrame.Angles(1.1, 0, 0)):PointToWorldSpace(p0)
				local r0 = (position - slot.Center.Position):Cross(axle).Magnitude
				local r1 = (p1 - slot.Center.Position):Cross(axle).Magnitude
				local a0 = (position - slot.Center.Position):Dot(axle)
				local a1 = (p1 - slot.Center.Position):Dot(axle)
				maxDrift = math.max(maxDrift, math.abs(r1 - r0), math.abs(a1 - a0))
			end
		end
		check(maxDrift < 1e-3, "rungs stay on their circle (no wobble)", tostring(maxDrift))
		-- the hamster stands on the bottom of the wheel, inside it
		local runLocal = slot.Center:PointToObjectSpace(slot.RunCFrame.Position)
		check(math.abs(runLocal.X) < 1e-3 and math.abs(runLocal.Z) < 1e-3 and runLocal.Y < -radius + 0.3 and runLocal.Y > -radius, "hamster stands inside at the bottom")
		check(math.abs(forward:Dot(axle)) < 1e-4, "hamster runs across the axle")
		wheelChecks += 1
	end
end
check(wheelChecks == #world.Houses * FloorConfig.MaxWheels, "every wheel checked", tostring(wheelChecks))

---------------------------------------------------------------------------
-- economy
---------------------------------------------------------------------------
local prevMaxPrice, prevMaxIncome = 0, 0
for _, id in RarityConfig.Order do
	local minPrice, maxPrice, minIncome, maxIncome = math.huge, 0, math.huge, 0
	for _, species in HamsterDatabase.ByRarity[id] do
		local price, income = HamsterDatabase.price(species), HamsterDatabase.income(species)
		minPrice, maxPrice = math.min(minPrice, price), math.max(maxPrice, price)
		minIncome, maxIncome = math.min(minIncome, income), math.max(maxIncome, income)
	end
	check(minPrice > prevMaxPrice, id .. " is always pricier than every lower rarity")
	check(minIncome > prevMaxIncome, id .. " always earns more than every lower rarity")
	prevMaxPrice, prevMaxIncome = maxPrice, maxIncome
end
-- every hamster looks different (the /Models library stores each look once)
do
	local HamsterBuilder = Runtime.require(Runtime.modules().HamsterBuilder)
	local seen: { [string]: string } = {}
	local clashes = {}
	for _, species in HamsterDatabase.Species do
		local signature = HamsterBuilder.signature(species)
		if seen[signature] then
			table.insert(clashes, seen[signature] .. " = " .. species.Id)
		end
		seen[signature] = species.Id
	end
	check(#clashes == 0, "no two hamsters share a look", table.concat(clashes, ", "))
end
local previousWeight = math.huge
for _, id in RarityConfig.Order do
	check(RarityConfig.ById[id].Weight < previousWeight, id .. " is rarer than the rarity below")
	previousWeight = RarityConfig.ById[id].Weight
end
for n = 2, RebirthConfig.MaxRebirths do
	local a, b = RebirthConfig.requirements(n - 1), RebirthConfig.requirements(n)
	check(b.Coins > a.Coins and b.Hamsters >= a.Hamsters and RarityConfig.rank(b.Rarity) >= RarityConfig.rank(a.Rarity), "rebirth " .. n .. " needs more than " .. (n - 1))
	check(RarityConfig.ById[b.Rarity].MinRebirth <= n - 1, "rebirth " .. n .. " only asks for a rarity that can spawn")
	check(RebirthConfig.multiplier(n, 0) > RebirthConfig.multiplier(n - 1, 0), "rebirth " .. n .. " raises the multiplier")
	check(RebirthConfig.slots(n) > RebirthConfig.slots(n - 1), "rebirth " .. n .. " adds a slot")
end

local function profile(rebirths: number)
	local data = table.clone(Template)
	data.Rebirths = rebirths
	data.Upgrades = {}
	data.Boosts = {}
	data.Passes = {}
	data.Index = {}
	data.Inventory = {}
	data.Equipped = {}
	return data
end
for rebirths = 0, RebirthConfig.MaxRebirths do
	local data = profile(rebirths)
	data.Upgrades.ExtraStorage = 3
	check(EconomyMath.slots(data) <= FloorConfig.capacity(rebirths), "slots never exceed the wheels on your floors (R" .. rebirths .. ")")
end
-- the best hamster runs on the best floor
local data = profile(14)
local cheap = HamsterDatabase.ByRarity.Basic[1].Id
local best = HamsterDatabase.ByRarity.Mythic[1].Id
data.Equipped = { cheap, cheap, cheap, best }
local assignment = EconomyMath.assignment(data)
local topFloor = 0
for _, entry in assignment do
	if entry.SpeciesId == best then
		topFloor = entry.Floor
	end
end
check(topFloor == FloorConfig.Count, "best hamster gets the penthouse wheel", tostring(topFloor))
check(UpgradeConfig.cost("CoinMultiplier", 0, 3) > UpgradeConfig.cost("CoinMultiplier", 0, 0), "coin upgrades scale with rebirths")
check(UpgradeConfig.cost("RebirthBoost", 0, 3) == UpgradeConfig.cost("RebirthBoost", 0, 0), "token upgrades don't scale")
check(not UpgradeConfig.available("TurboWheels", 2) and UpgradeConfig.available("TurboWheels", 3), "advanced upgrades need floor 3")

print(string.format("%d checks passed, %d failed", passes, failures))
if failures > 0 then
	process.exit(1)
end
