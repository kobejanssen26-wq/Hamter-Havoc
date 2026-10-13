--[[
	AbilitySystem: the special tools (Frost Wand, Shadow Cloak, Mirror Clone). Item files (Content/Items) only choose the
	numbers; ALL rules live here and are enforced on the server:

	  Freeze   hits the first player on the aim ray (CombatSystem finds the target), freezes them for Duration (capped by GameConfig > Abilities > FreezeMaxSeconds),
	           cancels their steal/pick-up channel, and makes them immune to being frozen again for a while (no chain-freezing).
	  Cloak    the user turns almost invisible for Duration. Counterplay: a faint sparkle trail stays visible, it ends the moment
	           the user attacks, is hit, is frozen, picks up or carries a hamster, or dies, and it has a long cooldown.
	  Decoy    a see-through cyan look-alike walks away for Duration. It is only a model: no data, items or currency are copied,
	           it can't steal or be stolen from, only one exists per player, and any hit pops it.

	Guard    a raised shield: no stun / knockback while it is up (not while carrying a hamster; theft rules still apply).

	Cooldowns are the weapon's Cooldown (CombatSystem). Ownership of the tool is checked by GearSystem.equippedWeapon.
]]

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Modules.GameConfig)
local Remotes = require(ReplicatedStorage.Remotes)

local HamsterSystem = require(script.Parent.HamsterSystem)
local Notifier = require(script.Parent.Notifier)
local PlayerState = require(script.Parent.PlayerState)

local AbilitySystem = {}

local CLOAK_ALPHA = 0.88

local cloaks: { [Player]: { Until: number, Original: { [BasePart]: number }, Trail: Instance? } } = {}
local decoys: { [Player]: Model } = {}

---------------------------------------------------------------------------
-- Freeze
---------------------------------------------------------------------------

-- Returns true when the target was frozen.
function AbilitySystem.freeze(attacker: Player, target: Player, seconds: number): boolean
	if PlayerState.isImmune(target) or PlayerState.isFrozen(target) then
		return false
	end
	local _, targetRoot = PlayerState.character(target)
	if not targetRoot then
		return false
	end
	seconds = math.clamp(seconds, 0.5, GameConfig.get("Abilities", "FreezeMaxSeconds"))
	PlayerState.freeze(target, seconds, GameConfig.get("Abilities", "FreezeImmunitySeconds"))
	HamsterSystem.interrupt(target)
	AbilitySystem.endCloak(target) -- being frozen reveals you
	-- an ice block around the target, visible to everybody, removed when the freeze ends
	local ice = Instance.new("Part")
	ice.Name = "FrozenIce"
	ice.Size = Vector3.new(5, 7, 5)
	ice.Material = Enum.Material.Ice
	ice.Color = Color3.fromRGB(150, 214, 255)
	ice.Transparency = 0.45
	ice.CanCollide = false
	ice.CanTouch = false
	ice.CanQuery = false
	ice.Massless = true
	ice.CFrame = targetRoot.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = targetRoot
	weld.Part1 = ice
	weld.Parent = ice
	ice.Parent = targetRoot.Parent
	Debris:AddItem(ice, seconds)
	Remotes.event("Fx"):FireAllClients("Freeze", "", targetRoot.Position, target.UserId)
	Notifier.send(target, string.format("%s froze you for %.0f seconds!", attacker.DisplayName, seconds), "error")
	return true
end

---------------------------------------------------------------------------
-- Cloak
---------------------------------------------------------------------------

function AbilitySystem.isCloaked(player: Player): boolean
	local cloak = cloaks[player]
	return cloak ~= nil and cloak.Until > os.clock()
end

function AbilitySystem.endCloak(player: Player)
	local cloak = cloaks[player]
	if not cloak then
		return
	end
	cloaks[player] = nil
	for part, original in cloak.Original do
		if part.Parent then
			part.Transparency = original
		end
	end
	if cloak.Trail then
		cloak.Trail:Destroy()
	end
	player:SetAttribute("Cloaked", nil)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	end
end

-- Returns (ok, message).
function AbilitySystem.cloak(player: Player, seconds: number): (boolean, string?)
	if AbilitySystem.isCloaked(player) then
		return false, "You are already cloaked"
	end
	if HamsterSystem.carriedBy(player) then
		return false, "You can't cloak while carrying a hamster"
	end
	local humanoid, root = PlayerState.character(player)
	if not humanoid or not root then
		return false, "You can't cloak right now"
	end
	local original: { [BasePart]: number } = {}
	for _, descendant in (player.Character :: Model):GetDescendants() do
		if descendant:IsA("BasePart") and descendant.Name ~= "HumanoidRootPart" then
			original[descendant] = descendant.Transparency
			descendant.Transparency = math.max(descendant.Transparency, CLOAK_ALPHA)
		end
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	-- the counterplay cue: a faint sparkle trail anyone can follow
	local trail = Instance.new("ParticleEmitter")
	trail.Name = "CloakShimmer"
	trail.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	trail.Color = ColorSequence.new(Color3.fromRGB(190, 230, 255))
	trail.Rate = 6
	trail.Lifetime = NumberRange.new(0.8, 1.2)
	trail.Speed = NumberRange.new(0.5, 1.5)
	trail.Size = NumberSequence.new(0.5)
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	trail.LightEmission = 0.6
	trail.Parent = root
	local entry = { Until = os.clock() + seconds, Original = original, Trail = trail :: Instance? }
	cloaks[player] = entry
	player:SetAttribute("Cloaked", true)
	task.delay(seconds, function()
		if cloaks[player] == entry then
			AbilitySystem.endCloak(player)
		end
	end)
	return true, nil
end

---------------------------------------------------------------------------
-- Decoy
---------------------------------------------------------------------------

function AbilitySystem.removeDecoy(player: Player)
	local decoy = decoys[player]
	if decoy then
		decoys[player] = nil
		decoy:Destroy()
	end
end

-- Returns (ok, message).
function AbilitySystem.decoy(player: Player, seconds: number): (boolean, string?)
	local humanoid, root = PlayerState.character(player)
	local character = player.Character
	if not humanoid or not root or not character then
		return false, "You can't clone yourself right now"
	end
	AbilitySystem.removeDecoy(player)
	character.Archivable = true
	local clone = character:Clone()
	if not clone then
		return false, "Cloning failed"
	end
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("Script") or descendant:IsA("LocalScript") or descendant:IsA("Tool") or descendant:IsA("BillboardGui") or descendant:IsA("ParticleEmitter") then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.CanTouch = false
			descendant.CanQuery = false
			if descendant.Name ~= "HumanoidRootPart" then
				descendant.Transparency = math.max(descendant.Transparency, 0.45) -- a see-through look-alike
			end
		end
	end
	clone.Name = "Decoy"
	clone:SetAttribute("Decoy", true)
	clone:SetAttribute("OwnerUserId", player.UserId)
	local decoyHumanoid = clone:FindFirstChildOfClass("Humanoid")
	if not decoyHumanoid then
		clone:Destroy()
		return false, "Cloning failed"
	end
	decoyHumanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	decoyHumanoid.WalkSpeed = 16
	local glow = Instance.new("Highlight") -- the fair cue: a cyan outline nobody can miss up close
	glow.FillColor = Color3.fromRGB(120, 220, 255)
	glow.FillTransparency = 0.8
	glow.OutlineColor = Color3.fromRGB(120, 220, 255)
	glow.OutlineTransparency = 0.2
	glow.Parent = clone
	local look = root.CFrame.LookVector
	clone:PivotTo(root.CFrame * CFrame.new(0, 0, -3))
	clone.Parent = workspace
	decoys[player] = clone
	decoyHumanoid:MoveTo(root.Position + Vector3.new(look.X, 0, look.Z) * 40)
	Debris:AddItem(clone, seconds)
	task.delay(seconds + 0.1, function()
		if decoys[player] == clone then
			decoys[player] = nil
		end
	end)
	return true, nil
end

-- A melee hit / shot near a decoy pops it. Returns true when one was popped.
function AbilitySystem.popDecoyNear(position: Vector3, radius: number, attacker: Player): boolean
	for owner, decoy in decoys do
		if owner ~= attacker and decoy.Parent then
			local root = decoy:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") and (root.Position - position).Magnitude <= radius then
				AbilitySystem.removeDecoy(owner)
				Remotes.event("Fx"):FireAllClients("Hit", "", root.Position, 0)
				return true
			end
		end
	end
	return false
end

function AbilitySystem.hasDecoy(player: Player): boolean
	local decoy = decoys[player]
	return decoy ~= nil and decoy.Parent ~= nil
end

---------------------------------------------------------------------------
-- Guard (shield)
---------------------------------------------------------------------------

local guards: { [Player]: { Until: number, Shield: Instance? } } = {}

function AbilitySystem.isGuarding(player: Player): boolean
	local guard = guards[player]
	return guard ~= nil and guard.Until > os.clock()
end

function AbilitySystem.endGuard(player: Player)
	local guard = guards[player]
	if not guard then
		return
	end
	guards[player] = nil
	if guard.Shield then
		guard.Shield:Destroy()
	end
	player:SetAttribute("Guarding", nil)
end

-- A raised shield: while it is up, hits do not stun or knock you back. It does NOT stop theft rules or hamster drops, and it
-- can't be raised while you carry a hamster (so it can't be used to make a theft unstoppable). Returns (ok, message).
function AbilitySystem.guard(player: Player, seconds: number): (boolean, string?)
	if AbilitySystem.isGuarding(player) then
		return false, "Your shield is already up"
	end
	if HamsterSystem.carriedBy(player) then
		return false, "You can't raise the shield while carrying a hamster"
	end
	local humanoid, root = PlayerState.character(player)
	if not humanoid or not root then
		return false, "You can't use the shield right now"
	end
	local shield = Instance.new("Part")
	shield.Name = "GuardBubble"
	shield.Shape = Enum.PartType.Ball
	shield.Size = Vector3.new(7.5, 7.5, 7.5)
	shield.Material = Enum.Material.ForceField
	shield.Color = Color3.fromRGB(90, 190, 255)
	shield.Transparency = 0.5
	shield.CanCollide = false
	shield.CanTouch = false
	shield.CanQuery = false
	shield.Massless = true
	shield.CFrame = root.CFrame
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = shield
	weld.Parent = shield
	shield.Parent = root.Parent
	local entry = { Until = os.clock() + math.clamp(seconds, 1, 6), Shield = shield :: Instance? }
	guards[player] = entry
	player:SetAttribute("Guarding", true)
	task.delay(entry.Until - os.clock(), function()
		if guards[player] == entry then
			AbilitySystem.endGuard(player)
		end
	end)
	return true, nil
end

---------------------------------------------------------------------------
-- lifecycle
---------------------------------------------------------------------------

-- Anything that "wakes" a cloaked player ends the cloak.
function AbilitySystem.reveal(player: Player)
	AbilitySystem.endCloak(player)
end

function AbilitySystem.forget(player: Player)
	AbilitySystem.endGuard(player)
	AbilitySystem.endCloak(player)
	AbilitySystem.removeDecoy(player)
end

function AbilitySystem.start()
	local function watch(player: Player)
		player.CharacterRemoving:Connect(function()
			AbilitySystem.endGuard(player)
			cloaks[player] = nil
			AbilitySystem.removeDecoy(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	-- picking up a hamster (claim / steal / recover) reveals you: poll cheaply once a second
	task.spawn(function()
		while true do
			task.wait(1)
			for player in cloaks do
				if HamsterSystem.carriedBy(player) then
					AbilitySystem.endCloak(player)
				end
			end
		end
	end)
end

return AbilitySystem
