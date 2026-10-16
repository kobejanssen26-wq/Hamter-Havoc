--[[
	LuckyWheel (standalone). Put the Lucky_Wheel model anywhere in Workspace.

	  * Walk up and press the prompt: the wheel spins, ends on a random slice and tells you which one.
	  * One free spin per player per hour. Change the time with the attribute CooldownSeconds on the model.
	  * The cooldown is saved (DataStore "LuckyWheel_v1"); without API access (Studio) it is kept per server only.
	  * Your own game hooks in with:  model.Won.Event:Connect(function(player, prizeId, prizeName) ... end)  (a server script)
	  * Slices: the parts Rotor/Slice_*. Rename, recolour or duplicate them; the first one is the 12 o'clock slice, then clockwise.
	  * Optional attribute Weight on a slice part (default 1) makes it more or less likely.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local model = script.Parent
local rotor = model:WaitForChild("Rotor") :: Model
local prompt = model:FindFirstChildWhichIsA("ProximityPrompt", true) :: ProximityPrompt
local status = model:FindFirstChild("Status", true) :: TextLabel?

local won = model:FindFirstChild("Won") or Instance.new("BindableEvent")
won.Name = "Won"
won.Parent = model

local base = rotor:GetPivot()
local rng = Random.new()

-- slices with their angle (degrees, clockwise seen from the front) measured from the geometry at start
local slices: { { Part: BasePart, Angle: number, Weight: number } } = {}
for _, part in rotor:GetChildren() do
	if part:IsA("BasePart") and string.sub(part.Name, 1, 6) == "Slice_" then
		local offset = base:PointToObjectSpace(part.Position)
		local angle = math.deg(math.atan2(-offset.X, offset.Y)) % 360
		local weight = part:GetAttribute("Weight")
		table.insert(slices, { Part = part, Angle = angle, Weight = if type(weight) == "number" and weight > 0 then weight else 1 })
	end
end
assert(#slices > 0, "LuckyWheel: no Rotor/Slice_* parts found")

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("LuckyWheel_v1")
end)
local nextFree: { [number]: number } = {}
local busy = false
local current = 0

local function cooldown(): number
	local value = model:GetAttribute("CooldownSeconds")
	return if type(value) == "number" and value >= 1 then value else 3600
end

local function load(player: Player)
	if store then
		local ok, value = pcall(function()
			return (store :: DataStore):GetAsync("p" .. player.UserId)
		end)
		if ok and type(value) == "number" then
			nextFree[player.UserId] = math.max(nextFree[player.UserId] or 0, value)
		end
	end
end

local function save(player: Player)
	if store and nextFree[player.UserId] then
		pcall(function()
			(store :: DataStore):SetAsync("p" .. player.UserId, nextFree[player.UserId])
		end)
	end
end

local function say(player: Player, text: string)
	player:SetAttribute("LuckyWheelMessage", text) -- any UI can show this; the wheel's sign shows it too
end

local function format(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function pick()
	local total = 0
	for _, slice in slices do
		total += slice.Weight
	end
	local roll = rng:NextNumber() * total
	for _, slice in slices do
		roll -= slice.Weight
		if roll <= 0 then
			return slice
		end
	end
	return slices[#slices]
end

local function spin(player: Player)
	if busy then
		return
	end
	local now = os.time()
	local free = nextFree[player.UserId] or 0
	if now < free then
		say(player, "Next free spin in " .. format(free - now))
		return
	end
	busy = true
	nextFree[player.UserId] = now + cooldown()
	local slice = pick()
	local from = current
	local target = from + 360 * 5 + ((360 - slice.Angle - from % 360) % 360)
	local duration = model:GetAttribute("SpinSeconds")
	local value = Instance.new("NumberValue")
	value.Value = from
	value.Changed:Connect(function(degrees)
		rotor:PivotTo(base * CFrame.Angles(0, 0, math.rad(degrees)))
	end)
	local tween = TweenService:Create(value, TweenInfo.new(if type(duration) == "number" then duration else 6, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Value = target })
	tween:Play()
	tween.Completed:Wait()
	value:Destroy()
	current = target % 360
	rotor:PivotTo(base * CFrame.Angles(0, 0, math.rad(current)))
	local prizeName = slice.Part.Name
	local label = slice.Part:FindFirstChildWhichIsA("SurfaceGui")
	local text = label and label:FindFirstChildWhichIsA("TextLabel")
	if text and text.Text ~= "" then
		prizeName = text.Text
	end
	model:SetAttribute("LastPrize", prizeName)
	model:SetAttribute("LastWinner", player.Name)
	say(player, "You won: " .. prizeName)
	won:Fire(player, string.sub(slice.Part.Name, 7), prizeName)
	busy = false
	task.spawn(save, player)
end

prompt.Triggered:Connect(spin)

Players.PlayerAdded:Connect(load)
for _, player in Players:GetPlayers() do
	task.spawn(load, player)
end
Players.PlayerRemoving:Connect(function(player)
	save(player)
	nextFree[player.UserId] = nil
end)

-- sign above the wheel: spinning or ready (each player gets the personal countdown through the prompt text)
task.spawn(function()
	while model.Parent do
		if status then
			status.Text = if busy then "SPINNING..." else "SPIN ME! (1 / hour)"
		end
		task.wait(1)
	end
end)

