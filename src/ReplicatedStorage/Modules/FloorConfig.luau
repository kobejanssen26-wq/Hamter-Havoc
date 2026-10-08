--[[
	Apartment floors. Every player's building grows upward with Rebirths and every floor has a job.
	To add a floor later: append an entry here (HouseBuilder builds floors from this list, HouseSystem
	and EconomyMath read the wheel count and bonuses from it).

	  WheelBonus  extra income for hamsters running on THIS floor's wheels
	  Luck        permanent luck bonus while the floor is unlocked
	  Features    what the floor adds (shown in the Rebirth screen and on the floor's sign)

	Slots fill the ground floor first, then from the top floor down; the best hamsters always run on
	the wheels with the biggest bonus (see EconomyMath.assignment).
]]

local FloorConfig = {}

FloorConfig.WheelsPerFloor = 6

export type Floor = {
	Index: number,
	Name: string,
	Purpose: string,
	MinRebirth: number,
	WheelBonus: number,
	Luck: number,
	WheelStyle: string,
	Accent: Color3,
	Features: { string },
}

FloorConfig.Floors = {
	{
		Index = 1, Name = "Workshop", Purpose = "Main hamster production", MinRebirth = 0,
		WheelBonus = 0, Luck = 0, WheelStyle = "BasicWheel", Accent = Color3.fromRGB(255, 176, 92),
		Features = { "6 hamster wheels", "Arrival pad", "Coin upgrade stations", "Hamster chest" },
	},
	{
		Index = 2, Name = "Hamster Lofts", Purpose = "More hamster slots", MinRebirth = 2,
		WheelBonus = 0.10, Luck = 0, WheelStyle = "BasicWheel", Accent = Color3.fromRGB(120, 200, 255),
		Features = { "6 more hamster wheels", "+10% income on this floor" },
	},
	{
		Index = 3, Name = "Research Lab", Purpose = "Advanced upgrades", MinRebirth = 5,
		WheelBonus = 0.20, Luck = 0, WheelStyle = "AdvancedWheel", Accent = Color3.fromRGB(150, 230, 170),
		Features = { "6 advanced wheels (+20%)", "Advanced upgrade lab" },
	},
	{
		Index = 4, Name = "Golden Suites", Purpose = "High-tier hamster production", MinRebirth = 9,
		WheelBonus = 0.40, Luck = 0.05, WheelStyle = "PremiumWheel", Accent = Color3.fromRGB(255, 205, 90),
		Features = { "6 golden wheels (+40%)", "+5% luck" },
	},
	{
		Index = 5, Name = "Penthouse", Purpose = "Prestige hamster area", MinRebirth = 14,
		WheelBonus = 0.75, Luck = 0.10, WheelStyle = "PremiumWheel", Accent = Color3.fromRGB(200, 150, 255),
		Features = { "6 diamond wheels (+75%)", "+10% luck", "Rooftop terrace" },
	},
} :: { Floor }

FloorConfig.Count = #FloorConfig.Floors
FloorConfig.MaxWheels = FloorConfig.Count * FloorConfig.WheelsPerFloor

-- Number of unlocked floors for a rebirth count.
function FloorConfig.unlocked(rebirths: number): number
	local count = 0
	for _, floor in FloorConfig.Floors do
		if rebirths >= floor.MinRebirth then
			count = floor.Index
		end
	end
	return math.max(1, count)
end

-- The floor that rebirth number `n` unlocks (nil if none).
function FloorConfig.unlockedAt(n: number): Floor?
	for _, floor in FloorConfig.Floors do
		if floor.MinRebirth == n and n > 0 then
			return floor
		end
	end
	return nil
end

-- The next floor still locked for this rebirth count (nil when the building is complete).
function FloorConfig.nextFloor(rebirths: number): Floor?
	for _, floor in FloorConfig.Floors do
		if rebirths < floor.MinRebirth then
			return floor
		end
	end
	return nil
end

function FloorConfig.capacity(rebirths: number): number
	return FloorConfig.unlocked(rebirths) * FloorConfig.WheelsPerFloor
end

-- Floor index of a global slot index (1-based, 6 slots per floor).
function FloorConfig.floorOfSlot(slot: number): number
	return math.ceil(slot / FloorConfig.WheelsPerFloor)
end

-- Global slot indices in the order they get used: ground floor first, then from the top floor down.
function FloorConfig.fillOrder(floors: number): { number }
	local order = {}
	local per = FloorConfig.WheelsPerFloor
	local sequence = { 1 }
	for floor = floors, 2, -1 do
		table.insert(sequence, floor)
	end
	for _, floor in sequence do
		for wheel = 1, per do
			table.insert(order, (floor - 1) * per + wheel)
		end
	end
	return order
end

function FloorConfig.luck(rebirths: number): number
	local total = 0
	for _, floor in FloorConfig.Floors do
		if rebirths >= floor.MinRebirth then
			total += floor.Luck
		end
	end
	return total
end

return FloorConfig
