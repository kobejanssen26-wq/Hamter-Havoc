--[[
	AnimateTaggedProps - small client script that brings the pack's decorations to life (Script.RunContext = Client).
	It animates only objects inside THIS pack, using the same tags the original game uses:
	  Sway       cloth / flowers swing left-right      attributes Amplitude (degrees), Speed, Axis ("Y" or "Z")
	  Bob        floats up and down                    attributes Amplitude (studs), Speed
	  SpinModel  turns a model around its pivot        attributes Speed (rad/s), Axis ("X", "Y" or "Z")
	  Ripple     water surface shimmers (Transparency)
	Delete this script if you want completely static props.
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local pack = script.Parent
local entries = {}

local function pivotOf(instance)
	if instance:IsA("Model") then
		return instance:GetPivot()
	elseif instance:IsA("BasePart") then
		return instance.CFrame
	end
	return nil
end

local function register(kind)
	for _, instance in CollectionService:GetTagged(kind) do
		if instance:IsDescendantOf(pack) then
			local home = pivotOf(instance)
			if home then
				table.insert(entries, { Kind = kind, Instance = instance, Home = home, Phase = math.random() * 6 })
			end
		end
	end
end
for _, kind in { "Sway", "Bob", "SpinModel" } do
	register(kind)
end

local ripples = {}
for _, descendant in pack:GetDescendants() do
	if descendant:IsA("BasePart") and descendant:GetAttribute("Ripple") then
		table.insert(ripples, { Part = descendant, Base = descendant.Transparency, Phase = math.random() * 6 })
	end
end

local function place(instance, cframe)
	if instance:IsA("Model") then
		instance:PivotTo(cframe)
	else
		instance.CFrame = cframe
	end
end

local connection
connection = RunService.RenderStepped:Connect(function()
	if not pack:IsDescendantOf(game) then
		connection:Disconnect()
		return
	end
	local now = os.clock()
	for _, entry in entries do
		local instance = entry.Instance
		if instance.Parent then
			local speed = instance:GetAttribute("Speed") or 1.2
			if entry.Kind == "Bob" then
				place(instance, entry.Home * CFrame.new(0, math.sin(now * speed + entry.Phase) * (instance:GetAttribute("Amplitude") or 0.4), 0))
			elseif entry.Kind == "Sway" then
				local angle = math.sin(now * speed + entry.Phase) * math.rad(instance:GetAttribute("Amplitude") or 3)
				place(instance, entry.Home * (if instance:GetAttribute("Axis") == "Y" then CFrame.Angles(0, angle, 0) else CFrame.Angles(0, 0, angle)))
			else
				local angle = now * speed
				local axis = instance:GetAttribute("Axis")
				place(instance, entry.Home * (if axis == "X" then CFrame.Angles(angle, 0, 0) elseif axis == "Y" then CFrame.Angles(0, angle, 0) else CFrame.Angles(0, 0, angle)))
			end
		end
	end
	for _, ripple in ripples do
		ripple.Part.Transparency = ripple.Base + math.sin(now * 1.6 + ripple.Phase) * 0.05
	end
end)
