--[[
	MobilitySystem: the server side of the premium gadgets Sky Glider and Rocket Booster (Content/Items, Weapon.Type "Glider" / "Rocket").

	Who decides what
	  * The SERVER decides whether a use is allowed: the player must own and hold the item (CombatSystem only calls us for the held,
	    owned weapon), be alive, not stunned or frozen, and the gadget must not be recharging. A glide also needs the player to be
	    in the air. The server also ends a glide: when its time is up, on landing, on death, when the glider is put away, or when
	    the player leaves.
	  * The CLIENT owns its own character physics in Roblox, so the movement itself is applied by MobilityController from the
	    numbers the server sends (never numbers the client sends). A modified client could ignore them: like every movement
	    exploit, that can not be fully stopped from the server; what a modified client can NOT do is get the gadget itself,
	    its cooldown reset or its visuals without the server's say-so.
	  * Everybody sees a wing above a gliding player and flames at the rocket: both are made here, on the server.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Remotes)

local Build = require(script.Parent.WorldBuilder.Build)
local CombatSystem = require(script.Parent.CombatSystem)
local GearSystem = require(script.Parent.GearSystem)
local Notifier = require(script.Parent.Notifier)
local PlayerState = require(script.Parent.PlayerState)

local MobilitySystem = {}

type State = { Gliding: boolean, Until: number, Def: any?, Stats: any?, Wing: Model?, RechargeUntil: number, Grounded: number }

local states: { [Player]: State } = {}

local function stateOf(player: Player): State
	local state = states[player]
	if not state then
		state = { Gliding = false, Until = 0, Def = nil, Stats = nil, Wing = nil, RechargeUntil = 0, Grounded = 0 }
		states[player] = state
	end
	return state
end

local function color(hex: any, fallback: Color3): Color3
	if type(hex) == "string" and #hex == 6 then
		return Color3.fromHex(hex)
	end
	return fallback
end

-- The open wing above a gliding player (welded to the character, light, no collisions): a delta sail on a keel with struts.
local function buildWing(character: Model, root: BasePart, look: any): Model
	local wing = Instance.new("Model")
	wing.Name = "GliderWing"
	local sail = color(look.Color, Color3.fromRGB(255, 92, 168))
	local trim = color(look.Accent, Color3.fromRGB(255, 214, 92))
	local props = { Anchored = false, CanCollide = false, CanTouch = false, CanQuery = false, Massless = true, CastShadow = false }
	local function weld(part: BasePart)
		local joint = Instance.new("WeldConstraint")
		joint.Part0 = root
		joint.Part1 = part
		joint.Parent = part
	end
	local base = root.CFrame
	local function world(x: number, y: number, z: number): Vector3
		return (base * CFrame.new(x, y, z)).Position
	end
	-- sail: nose -> left tip -> tail, nose -> right tip -> tail (two big triangles, each made of two wedges)
	local nose, tail = world(0, 3.7, -3.6), world(0, 3.7, 3.4)
	local left, right = world(-5.8, 3.4, 3.0), world(5.8, 3.4, 3.0)
	Build.triangle(wing, nose, left, tail, sail, Enum.Material.Fabric, props, 0.25)
	Build.triangle(wing, nose, right, tail, sail, Enum.Material.Fabric, props, 0.25)
	Build.triangle(wing, nose, world(-1.6, 3.62, 1.2), tail, trim, Enum.Material.Fabric, props, 0.3)
	Build.triangle(wing, nose, world(1.6, 3.62, 1.2), tail, trim, Enum.Material.Fabric, props, 0.3)
	-- keel + two struts down to the shoulders
	local keel = Instance.new("Part")
	keel.Name = "Keel"
	keel.Size = Vector3.new(0.35, 0.35, 7.2)
	keel.CFrame = base * CFrame.new(0, 3.55, -0.1)
	keel.Color = trim
	keel.Material = Enum.Material.Metal
	for key, value in props do
		(keel :: any)[key] = value
	end
	keel.Parent = wing
	for _, side in { -1, 1 } do
		local strut = Instance.new("Part")
		strut.Name = "Strut"
		local from, to = world(side * 0.9, 1.8, 0), world(side * 0.2, 3.5, 0)
		strut.Size = Vector3.new(0.22, 0.22, (to - from).Magnitude)
		strut.CFrame = CFrame.lookAt((from + to) / 2, to)
		strut.Color = Color3.fromRGB(70, 74, 92)
		strut.Material = Enum.Material.Metal
		for key, value in props do
			(strut :: any)[key] = value
		end
		strut.Parent = wing
	end
	for _, descendant in wing:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			weld(descendant)
		end
	end
	wing.Parent = character
	return wing
end

MobilitySystem.buildWing = buildWing -- (also used by tools/WorldPreview to draw the wing)

local function stopGlide(player: Player, silent: boolean?)
	local state = states[player]
	if not state or not state.Gliding then
		return
	end
	state.Gliding = false
	local cooldown = if state.Stats then state.Stats.Cooldown else 5
	state.RechargeUntil = os.clock() + cooldown
	if state.Wing then
		state.Wing:Destroy()
		state.Wing = nil
	end
	state.Def, state.Stats = nil, nil
	if player.Parent then
		Remotes.event("Mobility"):FireClient(player, "GlideEnd")
		if not silent then
			Notifier.send(player, string.format("Glider recharging: %d s", math.ceil(cooldown)), "info")
		end
	end
end

local function useGlider(player: Player, def: any, stats: any, humanoid: Humanoid, root: BasePart): (boolean, string?)
	local state = stateOf(player)
	local clock = os.clock()
	if state.Gliding then
		return false, nil
	end
	if clock < state.RechargeUntil then
		return false, string.format("Glider recharging: %d s", math.ceil(state.RechargeUntil - clock))
	end
	if humanoid.FloorMaterial ~= Enum.Material.Air or humanoid.Sit then
		return false, "Jump first, then click to open the glider"
	end
	state.Gliding, state.Until, state.Def, state.Stats, state.Grounded = true, clock + stats.Duration, def, stats, 0
	local character = player.Character
	if character then
		state.Wing = buildWing(character, root, def.Equip.Weapon.Look or {})
	end
	Remotes.event("Mobility"):FireClient(player, "Glide", { Seconds = stats.Duration, Speed = stats.Speed, Fall = stats.FallSpeed })
	Notifier.send(player, string.format("Gliding! Click again to land (%d s)", stats.Duration), "success")
	return true, nil
end

local function useRocket(player: Player, def: any, stats: any): (boolean, string?)
	Remotes.event("Mobility"):FireClient(player, "Boost", { Up = stats.Boost, Forward = stats.Forward })
	-- the flames of the rocket in the player's hand light up for everybody
	local _, tool = GearSystem.equippedWeapon(player)
	local flame = if tool then tool:FindFirstChild("Flame", true) else nil
	if flame and flame:IsA("ParticleEmitter") then
		flame.Enabled = true
		task.delay(1.4, function()
			if flame.Parent then
				flame.Enabled = false
			end
		end)
	end
	return true, nil
end

-- CombatSystem calls this for the held Glider / Rocket (after its own cooldown check).
function MobilitySystem.use(player: Player, def: any, stats: any): (boolean, string?)
	local humanoid, root = PlayerState.character(player)
	if not humanoid or not root or humanoid.Health <= 0 then
		return false, nil
	end
	if PlayerState.isStunned(player) then
		return false, "You can't use that right now"
	end
	if stats.Type == "Glider" then
		return useGlider(player, def, stats, humanoid, root)
	elseif stats.Type == "Rocket" then
		return useRocket(player, def, stats)
	end
	return false, nil
end

function MobilitySystem.isGliding(player: Player): boolean
	local state = states[player]
	return state ~= nil and state.Gliding
end

function MobilitySystem.stop(player: Player)
	stopGlide(player)
end

function MobilitySystem.forget(player: Player)
	stopGlide(player, true)
	states[player] = nil
end

local function watch(dt: number)
	for player, state in states do
		if state.Gliding then
			local humanoid = PlayerState.character(player)
			local def = GearSystem.equippedWeapon(player)
			if not humanoid or humanoid.Health <= 0 or PlayerState.isStunned(player) then
				stopGlide(player)
			elseif os.clock() >= state.Until or not def or def.Id ~= (state.Def :: any).Id then
				stopGlide(player) -- time is up, or the glider was put away
			else
				state.Grounded = if humanoid.FloorMaterial ~= Enum.Material.Air then state.Grounded + dt else 0
				if state.Grounded > 0.5 then
					stopGlide(player) -- landed
				end
			end
		end
	end
end

function MobilitySystem.start()
	CombatSystem.gadget = {
		use = MobilitySystem.use,
		active = MobilitySystem.isGliding,
		stop = MobilitySystem.stop,
	}
	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated >= 0.2 then
			watch(accumulated)
			accumulated = 0
		end
	end)
	local function track(player: Player)
		player.CharacterRemoving:Connect(function()
			stopGlide(player, true)
		end)
	end
	Players.PlayerAdded:Connect(track)
	for _, player in Players:GetPlayers() do
		track(player)
	end
end

return MobilitySystem
