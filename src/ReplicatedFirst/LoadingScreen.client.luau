--[[
	Cozy loading screen: shown until the world is loaded, the server has loaded your save,
	and the client UI is ready (or 30 seconds have passed so nobody is ever stuck).
]]

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

ReplicatedFirst:RemoveDefaultLoadingScreen()

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CREAM = Color3.fromRGB(255, 247, 233)
local BROWN = Color3.fromRGB(126, 84, 58)
local PEACH = Color3.fromRGB(255, 176, 122)

local gui = Instance.new("ScreenGui")
gui.Name = "LoadingScreen"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.DisplayOrder = 100
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local background = Instance.new("Frame")
background.Size = UDim2.fromScale(1, 1)
background.BackgroundColor3 = CREAM
background.BorderSizePixel = 0
background.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Color = ColorSequence.new(Color3.fromRGB(255, 236, 206), Color3.fromRGB(255, 214, 200))
gradient.Rotation = 90
gradient.Parent = background

local hamster = Instance.new("TextLabel")
hamster.BackgroundTransparency = 1
hamster.Size = UDim2.fromOffset(160, 160)
hamster.Position = UDim2.fromScale(0.5, 0.36)
hamster.AnchorPoint = Vector2.new(0.5, 0.5)
hamster.Text = "🐹"
hamster.TextSize = 120
hamster.Parent = background

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Size = UDim2.fromOffset(700, 80)
title.Position = UDim2.fromScale(0.5, 0.55)
title.AnchorPoint = Vector2.new(0.5, 0.5)
title.Font = Enum.Font.FredokaOne
title.TextSize = 64
title.TextColor3 = BROWN
title.Text = "Hamster Plaza"
title.Parent = background
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.new(1, 1, 1)
stroke.Thickness = 4
stroke.Parent = title

local status = Instance.new("TextLabel")
status.BackgroundTransparency = 1
status.Size = UDim2.fromOffset(600, 30)
status.Position = UDim2.fromScale(0.5, 0.65)
status.AnchorPoint = Vector2.new(0.5, 0.5)
status.Font = Enum.Font.GothamBold
status.TextSize = 20
status.TextColor3 = Color3.fromRGB(150, 124, 108)
status.Text = "Waking up the hamsters..."
status.Parent = background

local barBack = Instance.new("Frame")
barBack.Size = UDim2.fromOffset(360, 18)
barBack.Position = UDim2.fromScale(0.5, 0.72)
barBack.AnchorPoint = Vector2.new(0.5, 0.5)
barBack.BackgroundColor3 = Color3.fromRGB(246, 232, 208)
barBack.Parent = background
Instance.new("UICorner", barBack).CornerRadius = UDim.new(1, 0)
local barStroke = Instance.new("UIStroke")
barStroke.Color = Color3.fromRGB(214, 194, 164)
barStroke.Thickness = 2
barStroke.Parent = barBack
local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0.05, 1)
barFill.BackgroundColor3 = PEACH
barFill.Parent = barBack
Instance.new("UICorner", barFill).CornerRadius = UDim.new(1, 0)

-- bouncing hamster
local start = os.clock()
local connection = RunService.RenderStepped:Connect(function()
	local t = os.clock() - start
	hamster.Position = UDim2.new(0.5, 0, 0.36, math.abs(math.sin(t * 3.2)) * -26)
	hamster.Rotation = math.sin(t * 3.2) * 6
end)

local function setProgress(fraction: number, text: string)
	TweenService:Create(barFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(fraction, 1) }):Play()
	status.Text = text
end

if not game:IsLoaded() then
	setProgress(0.15, "Building the plaza...")
	game.Loaded:Wait()
end
setProgress(0.4, "Loading your hamsters...")

local deadline = os.clock() + 30
while os.clock() < deadline and not player:GetAttribute("DataLoaded") do
	task.wait(0.1)
end
setProgress(0.75, "Decorating your house...")
while os.clock() < deadline and not player:GetAttribute("ClientReady") do
	task.wait(0.1)
end
setProgress(1, "Welcome!")
task.wait(0.5)

for _, descendant in background:GetDescendants() do
	if descendant:IsA("TextLabel") then
		TweenService:Create(descendant, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
	elseif descendant:IsA("Frame") then
		TweenService:Create(descendant, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	end
end
TweenService:Create(background, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
task.wait(0.6)
connection:Disconnect()
gui:Destroy()
