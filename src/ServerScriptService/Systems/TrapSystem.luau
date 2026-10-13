--[[
	TrapSystem: placeable traps (Spike Trap, Glue Puddle, Banana Peel). A trap is a weapon item with Weapon.Type = "Trap"
	(see Content/Items); using it puts the trap on the ground in front of you.

	Rules (all on the server):
	  * at most `MaxActive` traps per player; a trap lasts `Duration` seconds and is single use
	  * it is placed on the ground ahead of you, never inside a SafeZone, never while stunned or carrying a hamster
	  * it arms after `ArmSeconds` (visible to everybody, it is not invisible) and only affects OTHER players
	  * a victim must be hittable (no spawn protection / hit immunity); the effect uses the same caps as combat
	  * the OWNER of a hamster that a thief is carrying away makes that theft fail when the thief steps on a trap of theirs
	  * nothing here touches hamsters, data or currency except dropping / interrupting a carried hamster like a normal hit
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local HamsterStates = require(ReplicatedStorage.Modules.HamsterStates)

local Remotes = require(ReplicatedStorage.Remotes)

local AbilitySystem = require(script.Parent.AbilitySystem)
local CombatSystem = require(script.Parent.CombatSystem)
local HamsterSystem = require(script.Parent.HamsterSystem)
local Notifier = require(script.Parent.Notifier)
local PlayerState = require(script.Parent.PlayerState)
local TrapBuilder = require(script.Parent.TrapBuilder)

local TrapSystem = {}

local TRIGGER_RADIUS = 3.6
local MAX_HEIGHT = 5
local PLACE_DISTANCE = 5
local MAX_TOTAL = 60

type Trap = { Owner: Player, Model: Model, Position: Vector3, ArmedAt: number, ExpiresAt: number, Stats: any, Def: any }

local traps: { Trap } = {}
local random = Random.new()

local function folder(): Folder
	local existing = workspace:FindFirstChild("Traps")
	if existing then
		return existing :: Folder
	end
	local created = Instance.new("Folder")
	created.Name = "Traps"
	created.Parent = workspace
	return created
end

function TrapSystem.activeCount(player: Player): number
	local n = 0
	for _, trap in traps do
		if trap.Owner == player then
			n += 1
		end
	end
	return n
end

local function remove(trap: Trap)
	local index = table.find(traps, trap)
	if index then
		table.remove(traps, index)
	end
	if trap.Model.Parent then
		trap.Model:Destroy()
	end
end

-- Returns (ok, message). Called by CombatSystem when the held weapon is a Trap.
function TrapSystem.place(player: Player, def: any, stats: any): (boolean, string?)
	local humanoid, root = PlayerState.character(player)
	if not humanoid or not root then
		return false, "You can't place a trap right now"
	end
	if PlayerState.isStunned(player) then
		return false, "You can't place a trap while stunned"
	end
	if HamsterSystem.carriedBy(player) then
		return false, "You can't set a trap while carrying a hamster"
	end
	if TrapSystem.activeCount(player) >= stats.MaxActive then
		return false, string.format("You already have %d traps out", stats.MaxActive)
	end
	if #traps >= MAX_TOTAL then
		return false, "There are too many traps in this server right now"
	end
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
	local target = root.Position + look * PLACE_DISTANCE
	if CombatSystem.inSafeZone(target) or CombatSystem.inSafeZone(root.Position) then
		return false, "No traps in a safe zone"
	end
	-- on the ground: a ray down from above the spot; without a hit use the height of the player's feet
	local ground = root.Position.Y - humanoid.HipHeight - root.Size.Y / 2
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, folder() }
	local hit = workspace:Raycast(target + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), params)
	if hit and hit.Position then
		ground = hit.Position.Y
	end
	local position = Vector3.new(target.X, ground + 0.05, target.Z)
	local model = TrapBuilder.placed(stats.TrapKind, CFrame.lookAt(position, position + look), stats.Look)
	model:SetAttribute("TrapKind", stats.TrapKind)
	model:SetAttribute("OwnerUserId", player.UserId)
	model.Parent = folder()
	local now = os.clock()
	table.insert(traps, { Owner = player, Model = model, Position = position, ArmedAt = now + stats.ArmSeconds, ExpiresAt = now + stats.Duration, Stats = stats, Def = def })
	Remotes.event("Fx"):FireAllClients("TrapSet", stats.TrapKind, position, player.UserId)
	return true, nil
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- What a trap does to somebody who stepped on it.
local function trigger(trap: Trap, victim: Player, victimRoot: BasePart)
	local stats = trap.Stats
	local kind = stats.TrapKind
	local hitImmunity = GameConfig.get("Combat", "HitImmunitySeconds")
	remove(trap)
	AbilitySystem.reveal(victim)
	HamsterSystem.interrupt(victim)
	local guarded = AbilitySystem.isGuarding(victim)
	local velocity = flat(victimRoot.AssemblyLinearVelocity)
	local forward = if velocity.Magnitude > 2 then velocity.Unit else flat(victimRoot.CFrame.LookVector)
	local stun = math.min(stats.Stun or 0, GameConfig.get("Combat", "MaxStunSeconds"))
	if kind == "Glue" then
		PlayerState.slow(victim, stats.Slow or 0.4, stats.SlowSeconds or 4)
		PlayerState.grantImmunity(victim, hitImmunity)
	elseif guarded then
		PlayerState.grantImmunity(victim, hitImmunity) -- the shield soaks the stun and the shove (the theft rules below still apply)
	else
		PlayerState.stun(victim, stun, hitImmunity)
		local lift = math.min(stats.Lift or (if kind == "Banana" then 12 else 16), GameConfig.get("Combat", "MaxKnockbackLift"))
		local push = if kind == "Banana" then math.min(stats.Knockback or 44, GameConfig.get("Combat", "MaxKnockback")) else 0
		Remotes.event("Knockback"):FireClient(victim, forward * push + Vector3.new(0, lift, 0))
	end
	Remotes.event("Fx"):FireAllClients("TrapHit", kind, victimRoot.Position, victim.UserId)

	local carried = HamsterSystem.carriedBy(victim)
	local theft = carried and carried.Theft
	if theft and theft.Owner == trap.Owner and CombatSystem.theftHook then
		if CombatSystem.theftHook(trap.Owner, victim) then
			Notifier.send(trap.Owner, "Your trap stopped a theft!", "success")
		end
	elseif carried and (kind == "Spike" or kind == "Banana") and random:NextNumber() < (stats.DropChance or 0) then
		HamsterSystem.dropCarried(victim, "Trap", HamsterStates.Config.DropBanSeconds)
	end
	Notifier.send(victim, string.format("You stepped on %s's %s!", trap.Owner.DisplayName, string.lower(trap.Def.DisplayName)), "error")
	Notifier.send(trap.Owner, string.format("%s stepped on your trap", victim.DisplayName), "info")
end

local function step()
	local clock = os.clock()
	for index = #traps, 1, -1 do
		local trap = traps[index]
		if not trap or not trap.Model.Parent or trap.Owner.Parent ~= Players or clock >= trap.ExpiresAt then
			if trap then
				remove(trap)
			end
		elseif clock >= trap.ArmedAt then
			for _, other in Players:GetPlayers() do
				if other ~= trap.Owner then
					local ok, root = CombatSystem.canBeHit(other)
					if ok and root and flat(root.Position - trap.Position).Magnitude <= TRIGGER_RADIUS and math.abs(root.Position.Y - trap.Position.Y) <= MAX_HEIGHT then
						trigger(trap, other, root)
						break
					end
				end
			end
		end
	end
end

function TrapSystem.start()
	CombatSystem.trapPlacer = TrapSystem.place
	CombatSystem.trapCount = TrapSystem.activeCount
	local accumulated = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulated += dt
		if accumulated >= 0.1 and #traps > 0 then
			accumulated = 0
			step()
		end
	end)
end

function TrapSystem.forget(player: Player)
	for index = #traps, 1, -1 do
		if traps[index].Owner == player then
			remove(traps[index])
		end
	end
end

-- For tests / admin tools.
function TrapSystem.all(): { Trap }
	return traps
end

return TrapSystem
