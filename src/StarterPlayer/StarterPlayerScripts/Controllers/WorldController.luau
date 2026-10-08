--[[
	WorldController: renders the shared hamster balls the server simulates and lets you interact with them.

	The server sends (a) the list of balls when they appear, (b) a state packet when one changes
	(claimed / stolen / carried / dropped ...), (c) position snapshots 10 times a second.
	Here every ball is a glass sphere that ROLLS (beads on the shell show the rotation) with the hamster
	running upright inside it. Positions are smoothed + extrapolated so movement looks continuous.

	Interaction ([E] / tap / click on the name tag) only SENDS "interact with ball X": the server decides
	whether that means claim, steal, carry or pick up, and whether it worked.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Format = require(Modules:WaitForChild("Format"))
local HamsterBuilder = require(Modules:WaitForChild("HamsterBuilder"))
local HamsterDatabase = require(Modules:WaitForChild("HamsterDatabase"))
local HamsterStates = require(Modules:WaitForChild("HamsterStates"))
local RarityConfig = require(Modules:WaitForChild("RarityConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local AudioController = require(script.Parent.AudioController)
local DataController = require(script.Parent.DataController)
local FxController = require(script.Parent.FxController)
local HamsterAnimator = require(script.Parent.HamsterAnimator)

local WorldController = {}

local player = Players.LocalPlayer
local S = HamsterStates
local Config = HamsterStates.Config

export type Ball = {
	Id: string,
	Species: any,
	State: string,
	Price: number,
	Radius: number,
	PayerUserId: number,
	PayerName: string,
	HolderUserId: number,
	HolderName: string,
	Shell: Model,
	Hamster: Model,
	Animator: HamsterAnimator.Animator,
	BaseScale: number,
	Gui: BillboardGui,
	Frame: Frame,
	Stroke: UIStroke,
	RarityLabel: TextLabel,
	NameLabel: TextLabel,
	InfoLabel: TextLabel,
	Pos: Vector3,
	PrevPos: Vector3,
	Target: Vector3,
	Yaw: number,
	RenderYaw: number,
	Speed: number,
	SnapAt: number,
	Roll: CFrame,
	Pop: number,
	Scale: number,
	Hop: number,
	Removing: number?,
}

local balls: { [string]: Ball } = {}
local container: Folder
local currentTarget: string? = nil
local targetListeners: { (info: TargetInfo?) -> () } = {}
local ballListeners: { () -> () } = {}
local channelListeners: { (info: ChannelInfo?) -> () } = {}
local channelInfo: ChannelInfo? = nil
local lastStepSound = 0
local lastRefresh = 0
local lastInteract = 0

export type TargetInfo = { Id: string, Species: any, Price: number, Affordable: boolean, Action: string, State: string, OwnerName: string }
export type ChannelInfo = { Id: string, Start: number, Duration: number, Kind: string }

local function notifyBalls()
	for _, listener in ballListeners do
		task.spawn(listener)
	end
end

local function rarityColor(species: any): Color3
	local definition = RarityConfig.ById[species.Rarity]
	return if definition.Hidden then definition.Accent else definition.Color
end

local function displayName(species: any): string
	local definition = RarityConfig.ById[species.Rarity]
	local index = DataController.get("Index") or {}
	if definition.Hidden and not index[species.Id] then
		return "???"
	end
	return species.Name
end

---------------------------------------------------------------------------
-- building a ball
---------------------------------------------------------------------------

local function makeShell(radius: number, color: Color3, rank: number): Model
	local model = Instance.new("Model")
	model.Name = "Shell"

	local shell = Instance.new("Part")
	shell.Name = "Glass"
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.one * radius * 2
	shell.Anchored = true
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.CastShadow = false
	shell.Material = Enum.Material.Glass
	shell.Color = color:Lerp(Color3.new(1, 1, 1), 0.55)
	shell.Transparency = 0.7
	shell.Reflectance = 0.08
	shell.Parent = model
	model.PrimaryPart = shell

	-- six beads on the shell: they show how the ball rolls
	local beadSize = radius * (0.2 + rank * 0.005)
	for _, direction in { Vector3.xAxis, -Vector3.xAxis, Vector3.yAxis, -Vector3.yAxis, Vector3.zAxis, -Vector3.zAxis } do
		local bead = Instance.new("Part")
		bead.Name = "Bead"
		bead.Shape = Enum.PartType.Ball
		bead.Size = Vector3.one * beadSize
		bead.Anchored = true
		bead.CanCollide = false
		bead.CanQuery = false
		bead.CanTouch = false
		bead.CastShadow = false
		bead.Material = Enum.Material.Neon
		bead.Color = color
		bead.CFrame = CFrame.new(direction * (radius - beadSize * 0.3))
		bead.Parent = model
	end
	return model
end

local function createTag(species: any, ball: Model, id: string, radius: number): (BillboardGui, Frame, UIStroke, TextLabel, TextLabel, TextLabel)
	local color = rarityColor(species)
	local definition = RarityConfig.ById[species.Rarity]

	local gui = Instance.new("BillboardGui")
	gui.Name = "BallTag_" .. id
	gui.Adornee = ball.PrimaryPart
	gui.Size = UDim2.fromOffset(190, 78)
	gui.StudsOffsetWorldSpace = Vector3.new(0, radius + 1.8, 0)
	gui.MaxDistance = 170
	gui.LightInfluence = 0
	gui.Active = true
	gui.ResetOnSpawn = false

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(38, 28, 40)
	frame.BackgroundTransparency = 0.2
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = 2
	stroke.Parent = frame

	local function label(y: number, height: number, font: Enum.Font, size: number, textColor: Color3, text: string): TextLabel
		local textLabel = Instance.new("TextLabel")
		textLabel.BackgroundTransparency = 1
		textLabel.Position = UDim2.fromOffset(0, y)
		textLabel.Size = UDim2.new(1, 0, 0, height)
		textLabel.Font = font
		textLabel.TextSize = size
		textLabel.TextColor3 = textColor
		textLabel.RichText = true
		textLabel.Text = text
		textLabel.Parent = frame
		return textLabel
	end
	local rarityLabel = label(5, 16, Enum.Font.GothamBold, 13, color, string.upper(definition.Name))
	local nameLabel = label(21, 24, Enum.Font.FredokaOne, 20, Color3.new(1, 1, 1), displayName(species))
	local infoLabel = label(47, 22, Enum.Font.GothamBold, 15, Color3.fromRGB(255, 220, 110), "")

	local button = Instance.new("TextButton")
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromScale(1, 1)
	button.Text = ""
	button.Parent = frame
	button.Activated:Connect(function()
		WorldController.interact(id)
	end)

	gui.Parent = player:WaitForChild("PlayerGui")
	return gui, frame, stroke, rarityLabel, nameLabel, infoLabel
end

local function destroyBall(id: string)
	local ball = balls[id]
	if not ball then
		return
	end
	balls[id] = nil
	ball.Gui:Destroy()
	ball.Shell:Destroy()
	ball.Hamster:Destroy()
	if currentTarget == id then
		currentTarget = nil
	end
	notifyBalls()
end

local function forwardOf(yaw: number): Vector3
	return Vector3.new(-math.sin(yaw), 0, -math.cos(yaw))
end

local function addBall(data: { [string]: any })
	local id = data.Id
	local species = HamsterDatabase.ById[data.SpeciesId]
	if not species or balls[id] then
		return
	end
	local radius = data.Radius
	local definition = RarityConfig.ById[species.Rarity]
	local color = rarityColor(species)

	local shell = makeShell(radius, color, definition.Rank)
	shell.Parent = container

	local baseScale = math.clamp(1.2 * radius / (3.4 * (species.Size or 1)), 0.2, 1.1)
	local hamster = HamsterBuilder.build(species, {
		Scale = baseScale,
		LowDetail = DataController.setting("LowGraphics") == true,
		Particles = DataController.setting("Particles") == true,
	})
	hamster.Name = "Run_" .. id
	local hamsterScale = hamster:GetScale()
	hamster.Parent = container
	FxController.attach(hamster, species.Rarity)

	local gui, frame, stroke, rarityLabel, nameLabel, infoLabel = createTag(species, shell, id, radius)
	local animator = HamsterAnimator.new(hamster)
	animator.OnStep = function()
		local now = os.clock()
		if now - lastStepSound < 0.12 then
			return
		end
		local camera = Workspace.CurrentCamera
		if camera and (camera.CFrame.Position - hamster:GetPivot().Position).Magnitude < 45 then
			lastStepSound = now
			AudioController.play("Footstep", { Position = hamster:GetPivot().Position, Pitch = 0.85 + math.random() * 0.4 })
		end
	end

	local position = Vector3.new(data.X, data.Y, data.Z)
	balls[id] = {
		Id = id,
		Species = species,
		State = data.State,
		Price = data.Price,
		Radius = radius,
		PayerUserId = data.PayerUserId or 0,
		PayerName = data.PayerName or "",
		HolderUserId = data.HolderUserId or 0,
		HolderName = data.HolderName or "",
		Shell = shell,
		Hamster = hamster,
		Animator = animator,
		BaseScale = hamsterScale,
		Gui = gui,
		Frame = frame,
		Stroke = stroke,
		RarityLabel = rarityLabel,
		NameLabel = nameLabel,
		InfoLabel = infoLabel,
		Pos = position,
		PrevPos = position,
		Target = position,
		Yaw = data.Yaw,
		RenderYaw = data.Yaw,
		Speed = data.Speed,
		SnapAt = os.clock(),
		Roll = CFrame.identity,
		Pop = 0,
		Scale = 0.2,
		Hop = math.max(0, definition.Rank - 8) * 0.12,
		Removing = nil,
	}
	shell:ScaleTo(0.2)
	hamster:ScaleTo(hamsterScale * 0.2)
	notifyBalls()
end

---------------------------------------------------------------------------
-- server events
---------------------------------------------------------------------------

local function applyState(data: { [string]: any })
	local ball = balls[data.Id]
	if not ball then
		return
	end
	ball.State = data.State
	ball.PayerUserId = data.PayerUserId or 0
	ball.PayerName = data.PayerName or ""
	ball.HolderUserId = data.HolderUserId or 0
	ball.HolderName = data.HolderName or ""
	ball.Target = Vector3.new(data.X, data.Y, data.Z)
	ball.Yaw = data.Yaw
	ball.Speed = data.Speed
	ball.SnapAt = os.clock()
	notifyBalls()
end

local function applySnap(rows: { { any } })
	local now = os.clock()
	for _, row in rows do
		local ball = balls[row[1]]
		if ball then
			ball.Target = Vector3.new(row[2], row[3], row[4])
			ball.Yaw = row[5]
			ball.Speed = row[6]
			ball.SnapAt = now
		end
	end
end

local function removeBall(id: string, reason: string, extra: any)
	local ball = balls[id]
	if not ball then
		return
	end
	local position = ball.Pos + Vector3.new(0, ball.Radius, 0)
	if reason == "Secured" then
		-- the reveal / fanfare for the owner comes from CollectResult; everybody else just sees a pop
		if extra ~= player.UserId then
			FxController.burst(position, rarityColor(ball.Species), RarityConfig.rank(ball.Species.Rarity))
		end
	elseif reason == "Lost" or reason == "PayerLeft" then
		FxController.burst(position, Color3.fromRGB(200, 200, 215), 2)
	end
	ball.Gui.Enabled = false
	ball.Removing = os.clock()
	if reason == "Exit" then
		ball.Speed = math.max(ball.Speed, 6)
	end
end

---------------------------------------------------------------------------
-- targeting
---------------------------------------------------------------------------

local function notifyTarget(info: TargetInfo?)
	for _, listener in targetListeners do
		task.spawn(listener, info)
	end
end

function WorldController.onTargetChanged(callback: (info: TargetInfo?) -> ())
	table.insert(targetListeners, callback)
end

function WorldController.onBallsChanged(callback: () -> ())
	table.insert(ballListeners, callback)
end

function WorldController.onChannel(callback: (info: ChannelInfo?) -> ())
	table.insert(channelListeners, callback)
end

function WorldController.getTarget(): string?
	return currentTarget
end

function WorldController.getBalls(): { [string]: Ball }
	return balls
end

-- Balls I paid for or am carrying right now (HUD tracker + navigation).
function WorldController.myBalls(): { Ball }
	local list = {}
	for _, ball in balls do
		if (ball.PayerUserId == player.UserId and ball.State ~= S.Travelling and ball.State ~= S.Spawning) or ball.HolderUserId == player.UserId then
			table.insert(list, ball)
		end
	end
	table.sort(list, function(a, b)
		return a.Id < b.Id
	end)
	return list
end

function WorldController.isCarrying(): boolean
	for _, ball in balls do
		if ball.HolderUserId == player.UserId then
			return true
		end
	end
	return false
end

-- Asks the server to interact with `id` (or the current target). The server validates everything.
function WorldController.interact(id: string?)
	local targetId = id or currentTarget
	if not targetId or not balls[targetId] then
		return
	end
	local now = os.clock()
	if now - lastInteract < 0.15 then
		return
	end
	lastInteract = now
	local ball = balls[targetId]
	if ball.State == S.Travelling and DataController.coins() < ball.Price then
		AudioController.play("Error")
	end
	Remotes.event("Interact"):FireServer(targetId)
end
WorldController.collect = WorldController.interact

local function actionFor(ball: Ball): string?
	if ball.State == S.Travelling then
		return "Claim"
	elseif ball.State == S.InTransit then
		return if ball.PayerUserId == player.UserId then "Carry" else "Steal"
	elseif ball.State == S.Recoverable then
		return "Pick up"
	end
	return nil
end

local function infoText(ball: Ball, coins: number): string
	local me = player.UserId
	if ball.State == S.Travelling or ball.State == S.Spawning then
		local color = if coins >= ball.Price then "#FFDC6E" else "#FF7878"
		return string.format('<font color="%s">🪙 %s</font>', color, Format.short(ball.Price))
	elseif ball.State == S.InTransit then
		if ball.PayerUserId == me then
			return '<font color="#8CFFAA">Yours - rolling home</font>'
		end
		return string.format('<font color="#FF8C8C">%s\'s - STEAL IT!</font>', ball.PayerName)
	elseif ball.State == S.Carried then
		if ball.PayerUserId == me and ball.HolderUserId ~= me then
			return string.format('<font color="#FF6060">🚨 STOLEN by %s!</font>', ball.HolderName)
		end
		return string.format('<font color="#FFDC6E">🏃 %s</font>', ball.HolderName)
	elseif ball.State == S.Dropped or ball.State == S.Recoverable then
		return '<font color="#FFA860">💥 DROPPED!</font>'
	end
	return ""
end

---------------------------------------------------------------------------
-- frame update
---------------------------------------------------------------------------

local function easeOutBack(t: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
end

local function step(dt: number)
	local clock = os.clock()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local rootPosition = if root and root:IsA("BasePart") then root.Position else nil
	local derived = DataController.derived()
	local collectRange = (derived.CollectRange or 16) + Config.ClaimRange
	local coins = DataController.coins()
	local carrying = WorldController.isCarrying()

	local bestId: string? = nil
	local bestDistance = math.huge
	local up = Vector3.yAxis

	for id, ball in balls do
		-- smoothing + extrapolation of the server position
		local age = math.min(clock - ball.SnapAt, 0.2)
		local forward = forwardOf(ball.Yaw)
		local goal = ball.Target + forward * (ball.Speed * age)
		ball.PrevPos = ball.Pos
		ball.Pos = ball.Pos:Lerp(goal, math.min(1, dt * 14))
		local yawDelta = (ball.Yaw - ball.RenderYaw + math.pi) % (2 * math.pi) - math.pi
		ball.RenderYaw += yawDelta * math.min(1, dt * 10)

		-- grow in / shrink out (carried balls are smaller)
		local wanted = if ball.State == S.Carried then 0.75 else 1
		if ball.Removing then
			local fade = (clock - ball.Removing) / 0.35
			if fade >= 1 then
				destroyBall(id)
				continue
			end
			wanted = 1 - fade
		end
		if ball.Pop < 1 then
			ball.Pop = math.min(1, ball.Pop + dt / 0.5)
			wanted *= math.max(0.2 + 0.8 * easeOutBack(ball.Pop), 0.05)
		end
		wanted = math.max(wanted, 0.05)
		if math.abs(wanted - ball.Scale) > 0.004 then
			ball.Scale += (wanted - ball.Scale) * math.min(1, dt * 12)
			ball.Shell:ScaleTo(ball.Scale)
			ball.Hamster:ScaleTo(ball.BaseScale * ball.Scale)
		end

		-- rolling: rotate the shell around the axis perpendicular to the movement
		local delta = ball.Pos - ball.PrevPos
		local flatMove = Vector3.new(delta.X, 0, delta.Z)
		local distance = flatMove.Magnitude
		if distance > 1e-4 then
			local axis = up:Cross(flatMove.Unit)
			ball.Roll = CFrame.fromAxisAngle(axis, distance / (ball.Radius * ball.Scale)) * ball.Roll
		end
		local radius = ball.Radius * ball.Scale
		local center = Vector3.new(ball.Pos.X, ball.Pos.Y + radius, ball.Pos.Z)
		ball.Shell:PivotTo(CFrame.new(center + Vector3.new(0, if ball.Hop > 0 and ball.Speed > 1 then math.abs(math.sin(clock * 5 + ball.Id:len())) * ball.Hop * ball.Scale else 0, 0)) * ball.Roll)

		-- Divine and above bounce along (visual only: the server position is untouched)
		local hop = 0
		if ball.Hop > 0 and ball.Speed > 1 then
			hop = math.abs(math.sin(clock * 5 + ball.Id:len())) * ball.Hop * ball.Scale
		end
		local hamsterCFrame = CFrame.new(ball.Pos.X, ball.Pos.Y + 0.2 * ball.Scale + hop, ball.Pos.Z) * CFrame.Angles(0, ball.RenderYaw, 0)
		ball.Hamster:PivotTo(hamsterCFrame)
		local moving = ball.Speed > 0.6 or distance / math.max(dt, 1e-3) > 0.6
		ball.Animator:Update(dt, if moving then math.max(ball.Speed, 6) else 0)

		-- who can I interact with right now?
		if rootPosition and not ball.Removing and not carrying then
			local action = actionFor(ball)
			if action then
				local d = (rootPosition - center).Magnitude - radius
				local range = if ball.State == S.Travelling then collectRange + ball.Speed * 0.3 else Config.InteractRange + 1
				if d <= range and d < bestDistance then
					bestDistance = d
					bestId = id
				end
			end
		end
	end

	-- tag styling (throttled)
	if clock - lastRefresh > 0.1 then
		lastRefresh = clock
		for id, ball in balls do
			if not ball.Removing then
				local isTarget = id == bestId
				local baseColor = rarityColor(ball.Species)
				local stroke = baseColor
				if ball.State ~= S.Travelling and ball.State ~= S.Spawning then
					if ball.PayerUserId == player.UserId or ball.HolderUserId == player.UserId then
						stroke = Color3.fromRGB(255, 214, 90)
					else
						stroke = Color3.fromRGB(255, 110, 110)
					end
				end
				ball.Stroke.Thickness = if isTarget then 4 else 2
				ball.Stroke.Color = if isTarget then Color3.new(1, 1, 1) else stroke
				ball.NameLabel.Text = displayName(ball.Species)
				ball.InfoLabel.Text = infoText(ball, coins)
				ball.InfoLabel.Visible = ball.State ~= S.Travelling or DataController.setting("ShowValues") == true
				ball.Frame.BackgroundTransparency = if isTarget then 0.05 else 0.25
				-- my own stolen / dropped hamsters stay visible from far away
				ball.Gui.AlwaysOnTop = ball.PayerUserId == player.UserId and (ball.State == S.Carried or ball.State == S.Dropped or ball.State == S.Recoverable) and ball.HolderUserId ~= player.UserId
			end
		end
	end

	if bestId ~= currentTarget then
		currentTarget = bestId
		if bestId then
			local ball = balls[bestId]
			notifyTarget({
				Id = bestId,
				Species = ball.Species,
				Price = ball.Price,
				Affordable = coins >= ball.Price,
				Action = actionFor(ball) or "Grab",
				State = ball.State,
				OwnerName = ball.PayerName,
			})
		else
			notifyTarget(nil)
		end
	end
end

function WorldController.start()
	container = Instance.new("Folder")
	container.Name = "ClientHamsters"
	container.Parent = Workspace

	Remotes.event("HamsterAdd").OnClientEvent:Connect(function(list: { { [string]: any } })
		for _, data in list do
			addBall(data)
		end
	end)
	Remotes.event("HamsterState").OnClientEvent:Connect(applyState)
	Remotes.event("HamsterSnap").OnClientEvent:Connect(applySnap)
	Remotes.event("HamsterRemove").OnClientEvent:Connect(removeBall)
	Remotes.event("Channel").OnClientEvent:Connect(function(id: string, duration: number, kind: string)
		if id == "" then
			channelInfo = nil
		else
			channelInfo = { Id = id, Start = os.clock(), Duration = duration, Kind = kind }
		end
		for _, listener in channelListeners do
			task.spawn(listener, channelInfo)
		end
	end)
	Remotes.event("CollectResult").OnClientEvent:Connect(function(success: boolean, id: string, speciesId: string, isNew: boolean, note: string)
		WorldController.OnCollectResult(success, speciesId, isNew, note)
	end)

	RunService.RenderStepped:Connect(step)

	-- balls that rolled out before this client was ready
	task.spawn(function()
		DataController.request("SyncHamsters")
	end)
end

-- UI modules replace this to show reveals (set after require to avoid cycles)
WorldController.OnCollectResult = function(_success: boolean, _speciesId: string, _isNew: boolean, _note: string) end

return WorldController
