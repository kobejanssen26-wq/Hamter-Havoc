--[[
	Very basic HUD: cash, income, collector balance, "current base" label and toast messages.
	All numbers come from player attributes set by the server.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared:WaitForChild("Util"):WaitForChild("Format"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local player = Players.LocalPlayer

local HudController = {}

local TOAST_COLORS = {
	info = Color3.fromRGB(255, 255, 255),
	success = Color3.fromRGB(130, 255, 150),
	error = Color3.fromRGB(255, 120, 120),
}

local function create(className: string, props: { [string]: any }, parent: Instance): any
	local instance = Instance.new(className)
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function createLabel(parent: Instance, props: { [string]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
	}
	for key, value in props do
		defaults[key] = value
	end
	return create("TextLabel", defaults, parent)
end

function HudController.start()
	local gui = create("ScreenGui", { Name = "HamsterHud", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

	-- Cash / income / collector panel (top centre)
	local panel = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 10),
		Size = UDim2.fromOffset(300, 98),
		BackgroundColor3 = Color3.fromRGB(25, 20, 35),
		BackgroundTransparency = 0.2,
	}, gui)
	create("UICorner", { CornerRadius = UDim.new(0, 12) }, panel)

	local cashLabel = createLabel(panel, {
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 44),
		TextSize = 34,
		TextColor3 = Color3.fromRGB(120, 255, 140),
	})
	local incomeLabel = createLabel(panel, {
		Position = UDim2.fromOffset(0, 48),
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 18,
		TextColor3 = Color3.fromRGB(255, 215, 100),
	})
	local collectorLabel = createLabel(panel, {
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 22),
		TextSize = 15,
		TextColor3 = Color3.fromRGB(210, 210, 225),
	})

	-- Current base label (bottom left)
	local basePanel = create("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(260, 40),
		BackgroundColor3 = Color3.fromRGB(25, 20, 35),
		BackgroundTransparency = 0.25,
	}, gui)
	create("UICorner", { CornerRadius = UDim.new(0, 10) }, basePanel)
	local baseLabel = createLabel(basePanel, { Size = UDim2.fromScale(1, 1), TextSize = 16 })

	-- Toast (centre, lower third)
	local toast = createLabel(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.78),
		Size = UDim2.fromOffset(460, 40),
		BackgroundTransparency = 0.35,
		BackgroundColor3 = Color3.fromRGB(20, 20, 30),
		TextSize = 20,
		Visible = false,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 10) }, toast)

	local function refresh()
		cashLabel.Text = Format.money(player:GetAttribute("Cash") or 0)
		incomeLabel.Text = "+" .. Format.money(player:GetAttribute("IncomePerSecond") or 0) .. " / sec"
		collectorLabel.Text = "Collector: " .. Format.money(player:GetAttribute("Stored") or 0)
	end
	for _, attribute in { "Cash", "IncomePerSecond", "Stored" } do
		player:GetAttributeChangedSignal(attribute):Connect(refresh)
	end
	refresh()

	local toastToken = 0
	Remotes.get("Notify").OnClientEvent:Connect(function(text: string, kind: string)
		if type(text) ~= "string" or text == "" then
			return
		end
		toastToken += 1
		local token = toastToken
		toast.Text = text
		toast.TextColor3 = TOAST_COLORS[kind] or TOAST_COLORS.info
		toast.Visible = true
		task.delay(3, function()
			if token == toastToken then
				toast.Visible = false
			end
		end)
	end)

	-- Which base am I standing in?
	local basesFolder = Workspace:WaitForChild("Bases")
	local elapsed = 0
	RunService.Heartbeat:Connect(function(deltaTime)
		elapsed += deltaTime
		if elapsed < 0.25 then
			return
		end
		elapsed = 0

		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local text = "Outside bases"
		if root then
			for _, base in basesFolder:GetChildren() do
				local cframe = base:GetAttribute("BaseCFrame")
				local size = base:GetAttribute("BaseSize")
				if cframe and size then
					local relative = cframe:PointToObjectSpace(root.Position)
					if math.abs(relative.X) <= size.X / 2 and math.abs(relative.Z) <= size.Z / 2 then
						local ownerUserId = base:GetAttribute("OwnerUserId")
						if ownerUserId == player.UserId then
							text = "Your base (#" .. base:GetAttribute("BaseId") .. ")"
						elseif ownerUserId and ownerUserId ~= 0 then
							text = base:GetAttribute("OwnerName") .. "'s base"
						else
							text = "Unclaimed base"
						end
						break
					end
				end
			end
		end
		baseLabel.Text = text
	end)
end

return HudController
