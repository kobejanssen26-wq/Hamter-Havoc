--[[
	NavController: subtle guidance, only when it is needed.
	While you carry a hamster ball a thin golden beam and a "Home 42 studs" marker lead to your arrival pad.
	Nothing is shown otherwise.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local WorldLayout = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("WorldLayout"))

local WorldController = require(script.Parent.WorldController)

local NavController = {}

local player = Players.LocalPlayer

function NavController.start()
	local target = Instance.new("Part")
	target.Name = "HomeMarker"
	target.Anchored = true
	target.CanCollide = false
	target.CanQuery = false
	target.CanTouch = false
	target.Transparency = 1
	target.Size = Vector3.one * 0.4
	target.Parent = Workspace

	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = target

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(170, 34)
	gui.AlwaysOnTop = true
	gui.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	gui.MaxDistance = 1000
	gui.LightInfluence = 0
	gui.Enabled = false
	gui.Adornee = target
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 226, 120)
	label.TextStrokeTransparency = 0.35
	label.Parent = gui

	local beam = Instance.new("Beam")
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 214, 90))
	beam.Width0 = 0.35
	beam.Width1 = 0.35
	beam.Transparency = NumberSequence.new(0.45)
	beam.LightEmission = 0.6
	beam.FaceCamera = true
	beam.Enabled = false
	beam.Attachment1 = targetAttachment
	beam.Parent = target

	local playerAttachment: Attachment? = nil

	task.spawn(function()
		while true do
			task.wait(0.2)
			local houseId = player:GetAttribute("HouseId")
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local show = type(houseId) == "number" and root ~= nil and root:IsA("BasePart") and WorldController.isCarrying()
			if show and type(houseId) == "number" and root and root:IsA("BasePart") then
				local pad = WorldLayout.padPosition(WorldLayout.houseCFrame(houseId))
				target.Position = pad + Vector3.new(0, 1, 0)
				label.Text = string.format("Home  %d studs", math.floor((root.Position - pad).Magnitude + 0.5))
				if not playerAttachment or playerAttachment.Parent ~= root then
					if playerAttachment then
						playerAttachment:Destroy()
					end
					local attachment = Instance.new("Attachment")
					attachment.Parent = root
					playerAttachment = attachment
					beam.Attachment0 = attachment
				end
			end
			gui.Enabled = show
			beam.Enabled = show
		end
	end)
end

return NavController
