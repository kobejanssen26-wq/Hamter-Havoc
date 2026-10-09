--[[
	SecurityController: the countdown above every gate ("SECURE 00:47" while the gate is on, "OPEN" when it is off),
	so thieves can watch the timers and owners know when they are exposed.
	The server only publishes SecUntil / SecReady (server clock) and the owner on each house model;
	everything shown here is computed from those, so the numbers stay exact without any network traffic.
]]

local Workspace = game:GetService("Workspace")

local Format = require(game:GetService("ReplicatedStorage"):WaitForChild("Modules"):WaitForChild("Format"))

local SecurityController = {}

export type Status = { State: string, Seconds: number, Owned: boolean }

local labels: { [Model]: TextLabel } = {}

-- State of a house gate right now: "None" (nobody lives there), "Active", "Recharging" or "Ready".
function SecurityController.status(house: Model): Status
	local owned = (house:GetAttribute("OwnerUserId") or 0) ~= 0
	if not owned then
		return { State = "None", Seconds = 0, Owned = false }
	end
	local now = Workspace:GetServerTimeNow()
	local untilTime = (house:GetAttribute("SecUntil") :: number?) or 0
	local readyAt = (house:GetAttribute("SecReady") :: number?) or 0
	if now < untilTime then
		return { State = "Active", Seconds = untilTime - now, Owned = true }
	elseif now < readyAt then
		return { State = "Recharging", Seconds = readyAt - now, Owned = true }
	end
	return { State = "Ready", Seconds = 0, Owned = true }
end

function SecurityController.color(status: Status): Color3
	if status.State == "Active" then
		if status.Seconds <= 5 then
			return Color3.fromRGB(255, 90, 90)
		elseif status.Seconds <= 10 then
			return Color3.fromRGB(255, 200, 80)
		end
		return Color3.fromRGB(130, 255, 160)
	end
	return Color3.fromRGB(255, 100, 100)
end

local function attach(house: Model)
	if labels[house] then
		return
	end
	local yard = house:WaitForChild("Yard", 10)
	local anchor = yard and yard:WaitForChild("SecurityAnchor", 10)
	if not anchor or not anchor:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "SecurityTimer"
	gui.Size = UDim2.fromOffset(150, 34)
	gui.MaxDistance = 130
	gui.LightInfluence = 0
	gui.Adornee = anchor
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextStrokeTransparency = 0.35
	label.Text = ""
	label.Parent = gui
	labels[house] = label
end

local function refresh()
	for house, label in labels do
		if not house.Parent then
			labels[house] = nil
			continue
		end
		local status = SecurityController.status(house)
		local gui = label.Parent :: BillboardGui
		gui.Enabled = status.Owned
		if status.State == "Active" then
			label.Text = "SECURE " .. Format.clock(math.ceil(status.Seconds))
		elseif status.Owned then
			label.Text = "OPEN"
		end
		label.TextColor3 = SecurityController.color(status)
	end
end

function SecurityController.start()
	task.spawn(function()
		local houses = Workspace:WaitForChild("PlayerHouses")
		for _, house in houses:GetChildren() do
			if house:IsA("Model") then
				task.spawn(attach, house)
			end
		end
		houses.ChildAdded:Connect(function(house)
			if house:IsA("Model") then
				task.spawn(attach, house)
			end
		end)
		while true do
			refresh()
			task.wait(0.2)
		end
	end)
end

return SecurityController
