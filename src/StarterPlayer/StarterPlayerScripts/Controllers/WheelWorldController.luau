--[[
	WheelWorldController: animates the physical Lucky Wheel in the plaza, draws the prize pictures on its slices and keeps its
	status sign up to date.

	  * When the server starts a spin (attribute SpinId changes on the wheel model) the rotor turns from SpinFrom to SpinTo: it speeds
	    up, then slows down to a stop (SpinWheelConfig.ease), the direction is the one the server chose (SpinWheelConfig.clockwise).
	    The time comes from the server clock, so everybody sees the same angle at the same moment, also when you walk up in the middle
	    of a spin. The result itself was decided by the server; the pointer is not part of the rotor and never moves.
	  * Every slice has an IconPlate with a SurfaceGui "PrizeIcon": here it gets its PICTURE - the prize's Image (an uploaded asset,
	    SpinWheelConfig) or else its drawn Icon (UI/Icons), on a round backdrop, never stretched.
	  * The sign above the wheel says FREE SPIN! (green) when YOUR free spin is ready, or a countdown (grey) when it is not.
	    This is a purely local text; the server still decides eligibility.
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Format = require(Modules:WaitForChild("Format"))
local SpinWheelConfig = require(Modules:WaitForChild("SpinWheelConfig"))
local DataController = require(script.Parent.DataController)
local Icons = require(script.Parent.Parent.UI.Icons)

local WheelWorldController = {}

type Wheel = { Model: Model, Active: boolean }
local wheels: { [Model]: Wheel } = {}

local function setAngle(model: Model, degrees: number)
	local rotor = model:FindFirstChild("Rotor")
	local base = model:GetAttribute("BaseCFrame")
	if rotor and rotor:IsA("Model") and typeof(base) == "CFrame" then
		rotor:PivotTo(SpinWheelConfig.rotorCFrame(base, degrees))
	end
end

-- Draws the picture of every slice (once per wheel).
local function drawIcons(model: Model)
	for _, plate in model:GetDescendants() do
		if plate:IsA("BasePart") and plate.Name == "IconPlate" then
			local gui = plate:FindFirstChild("PrizeIcon")
			if gui and gui:IsA("SurfaceGui") and not gui:FindFirstChild("Picture") then
				local backdropColor = plate:GetAttribute("Backdrop")
				local picture = Instance.new("Frame")
				picture.Name = "Picture"
				picture.Size = UDim2.fromScale(1, 1)
				picture.BackgroundTransparency = 1
				picture.Parent = gui
				local disc = Instance.new("Frame")
				disc.Name = "Backdrop"
				disc.AnchorPoint = Vector2.new(0.5, 0.5)
				disc.Position = UDim2.fromScale(0.5, 0.5)
				disc.Size = UDim2.fromScale(0.96, 0.96)
				disc.BackgroundColor3 = Color3.new(1, 1, 1)
				disc.BackgroundTransparency = 0.08
				disc.BorderSizePixel = 0
				disc.Parent = picture
				local corner = Instance.new("UICorner")
				corner.CornerRadius = UDim.new(0.5, 0)
				corner.Parent = disc
				local ring = Instance.new("UIStroke")
				ring.Thickness = 5
				ring.Color = if typeof(backdropColor) == "Color3" then backdropColor:Lerp(Color3.new(0, 0, 0), 0.25) else Color3.fromRGB(70, 60, 50)
				ring.Parent = disc
				local image = plate:GetAttribute("Image")
				if type(image) == "string" and image ~= "" then
					local label = Instance.new("ImageLabel")
					label.Name = "PrizeImage"
					label.AnchorPoint = Vector2.new(0.5, 0.5)
					label.Position = UDim2.fromScale(0.5, 0.5)
					label.Size = UDim2.fromScale(0.78, 0.78)
					label.BackgroundTransparency = 1
					label.Image = image
					label.ScaleType = Enum.ScaleType.Fit -- never stretched
					label.Parent = disc
				else
					local icon = Icons.create(disc, tostring(plate:GetAttribute("IconName") or "gift"), { Name = "PrizeIconArt", Size = UDim2.fromOffset(120, 120), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
					icon.Size = UDim2.fromScale(0.74, 0.74)
				end
			end
		end
	end
end

local function onWheel(instance: Instance)
	if not instance:IsA("Model") or wheels[instance] then
		return
	end
	wheels[instance] = { Model = instance, Active = false }
	instance:GetAttributeChangedSignal("SpinId"):Connect(function()
		wheels[instance].Active = true
	end)
	if instance:GetAttribute("SpinId") then
		wheels[instance].Active = true -- joined in the middle of a spin
	end
	task.spawn(drawIcons, instance)
	instance.DescendantAdded:Connect(function(descendant)
		if descendant.Name == "PrizeIcon" then
			task.defer(drawIcons, instance)
		end
	end)
end

local function step()
	for model, wheel in wheels do
		if wheel.Active and model.Parent then
			local from = model:GetAttribute("SpinFrom") :: number?
			local to = model:GetAttribute("SpinTo") :: number?
			local started = model:GetAttribute("SpinStart") :: number?
			local duration = (model:GetAttribute("SpinDuration") :: number?) or 6
			if from and to and started then
				local t = math.clamp((Workspace:GetServerTimeNow() - started) / duration, 0, 1)
				setAngle(model, from + (to - from) * SpinWheelConfig.ease(t))
				if t >= 1 then
					wheel.Active = false
				end
			else
				wheel.Active = false
			end
		end
	end
end

local function updateStatus()
	local data = DataController.Data
	for model in wheels do
		local sign = model:FindFirstChild("Sign")
		local label = sign and sign:FindFirstChild("WheelStatus") and sign.WheelStatus:FindFirstChild("Status")
		if label and label:IsA("TextLabel") then
			local nextFree = if data and data.Wheel then data.Wheel.NextFreeAt or 0 else 0
			local now = DataController.now()
			if not DataController.Ready then
				label.Text = "LUCKY WHEEL"
			elseif now >= nextFree then
				label.Text = "FREE SPIN!"
				label.TextColor3 = Color3.fromRGB(110, 255, 140)
			else
				label.Text = "Next spin " .. Format.clock(nextFree - now)
				label.TextColor3 = Color3.fromRGB(230, 220, 255)
			end
		end
	end
end

function WheelWorldController.start()
	for _, instance in CollectionService:GetTagged("LuckyWheel") do
		onWheel(instance)
	end
	CollectionService:GetInstanceAddedSignal("LuckyWheel"):Connect(onWheel)
	CollectionService:GetInstanceRemovedSignal("LuckyWheel"):Connect(function(instance)
		wheels[instance :: Model] = nil
	end)
	RunService.RenderStepped:Connect(step)
	task.spawn(function()
		while true do
			updateStatus()
			task.wait(1)
		end
	end)
end

return WheelWorldController
