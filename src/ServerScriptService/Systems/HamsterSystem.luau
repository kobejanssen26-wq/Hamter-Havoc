--[[
	HamsterSystem: every hamster ball in the world, and the whole claim -> transport -> steal -> secure loop.
	This is the authority. Clients only render what it tells them and only ever ask ("I want to interact with h12").

	World model
	  - One shared stream of hamster balls rolls along the central road (Spawning -> Travelling).
	  - Anybody can CLAIM a travelling ball by paying its price. It then rolls home by itself (InTransit).
	    Claimed is NOT owned: a rolling-home ball can be STOLEN (hold E next to it) and is then CARRIED.
	  - A carrier slowly walks the ball to their OWN house. Slaps make a carrier drop it (Dropped ->
	    Recoverable) and anybody may pick it up. It only becomes permanent (SECURED) when it reaches the
	    arrival pad of the house of whoever holds it. Then it joins the collection and runs on a wheel.

	Simulation
	  - Positions live on the server (20 Hz), clients get compact snapshots (10 Hz) and interpolate.
	  - Balls steer around each other (lane changes) and a hard separation pass makes overlap impossible.

	Money risk
	  - The payer pays the full price when claiming.
	  - If somebody else secures the stolen ball, the payer gets StolenInsurance of the price back.
	  - If the payer leaves, the ball vanishes and they are refunded; abandoned balls roll back to the payer.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local EconomyMath = require(Modules.EconomyMath)
local Format = require(Modules.Format)
local HamsterDatabase = require(Modules.HamsterDatabase)
local HamsterStates = require(Modules.HamsterStates)
local PathConfig = require(Modules.PathConfig)
local RarityConfig = require(Modules.RarityConfig)
local Route = require(Modules.Route)
local Util = require(Modules.Util)
local WorldLayout = require(Modules.WorldLayout)

local Remotes = require(ReplicatedStorage.Remotes)

local AnnounceSystem = require(script.Parent.AnnounceSystem)
local CollectionSystem = require(script.Parent.CollectionSystem)
local DataSystem = require(script.Parent.DataSystem)
local EconomySystem = require(script.Parent.EconomySystem)
local HouseSystem = require(script.Parent.HouseSystem)
local Notifier = require(script.Parent.Notifier)
local PlayerState = require(script.Parent.PlayerState)
local ReplicationSystem = require(script.Parent.ReplicationSystem)

local HamsterSystem = {}

-- Natural spawning can be paused (events, tests).
HamsterSystem.AutoSpawn = true

local S = HamsterStates
local Config = HamsterStates.Config

local STEP = 1 / 20
local SNAP_EVERY = 2 -- steps between position snapshots (10 Hz)
local MAX_ON_ROAD = 14 -- the road is 500 studs long: a Basic needs ~55 s to roll through
local LATERAL_SPEED = 5.5
local PLAYER_RADIUS = 1.6 -- balls steer around people standing on the road / promenade

export type Entity = {
	Id: string,
	Species: any,
	SpeciesId: string,
	Rarity: string,
	Rank: number,
	State: string,
	StateSince: number,
	Price: number,
	Radius: number,
	Payer: Player?,
	PayerName: string,
	Holder: Player?,
	HolderName: string,
	Route: Route.Route?,
	Dist: number,
	Lat: number,
	LatTarget: number,
	HomeLat: number,
	LaneCooldown: number,
	BaseSpeed: number,
	TransitSpeed: number,
	Speed: number,
	Position: Vector3,
	Yaw: number,
	Static: boolean,
	CarryStart: number,
	DropAt: number,
	Bans: { [Player]: number },
	Resets: number,
	ArrivedAt: number?,
	LastSent: Vector3,
	SentSpeed: number,
	StolenFrom: Player?,
}

local random = Random.new()
local entities: { [string]: Entity } = {}
local counter = 0
local carrying: { [Player]: Entity } = {}
local channels: { [Player]: { Id: string, Start: number, Duration: number, Kind: string } } = {}
local buckets: { [Player]: { Tokens: number, Last: number } } = {}
local nextSpawnAt = 0
local walkers: { { Position: Vector3, Radius: number, Speed: number, Static: boolean, IsPlayer: boolean } } = {}
local sponsorQueue: { Player } = {}
local roadRoute: Route.Route = Route.new({
	Vector3.new(PathConfig.SpawnPoint.X, PathConfig.RoadHeight, 0),
	Vector3.new(PathConfig.ExitPoint.X, PathConfig.RoadHeight, 0),
}, 1)

---------------------------------------------------------------------------
-- small helpers
---------------------------------------------------------------------------

local function yawOf(dx: number, dz: number): number
	return math.atan2(-dx, -dz)
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function distanceXZ(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function allowRequest(player: Player): boolean
	local now = os.clock()
	local bucket = buckets[player]
	if not bucket then
		bucket = { Tokens = 6, Last = now }
		buckets[player] = bucket
	end
	bucket.Tokens = math.min(6, bucket.Tokens + (now - bucket.Last) * 8)
	bucket.Last = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

local function packet(e: Entity): { [string]: any }
	return {
		Id = e.Id,
		SpeciesId = e.SpeciesId,
		State = e.State,
		Price = e.Price,
		Radius = e.Radius,
		X = e.Position.X,
		Y = e.Position.Y,
		Z = e.Position.Z,
		Yaw = e.Yaw,
		Speed = e.Speed,
		PayerUserId = if e.Payer then e.Payer.UserId else 0,
		PayerName = e.PayerName,
		HolderUserId = if e.Holder then e.Holder.UserId else 0,
		HolderName = e.HolderName,
	}
end

local function statePacket(e: Entity): { [string]: any }
	return {
		Id = e.Id,
		State = e.State,
		PayerUserId = if e.Payer then e.Payer.UserId else 0,
		PayerName = e.PayerName,
		HolderUserId = if e.Holder then e.Holder.UserId else 0,
		HolderName = e.HolderName,
		Speed = e.Speed,
		X = e.Position.X,
		Y = e.Position.Y,
		Z = e.Position.Z,
		Yaw = e.Yaw,
	}
end

local function setState(e: Entity, state: string)
	e.State = state
	e.StateSince = os.clock()
	Remotes.event("HamsterState"):FireAllClients(statePacket(e))
end

-- One-off effect for everybody (sound + particles are decided client-side by distance / role).
local function fx(kind: string, e: Entity, extra: any?)
	Remotes.event("Fx"):FireAllClients(kind, e.Rarity, e.Position, extra)
end

local function pendingCount(player: Player): number
	local count = 0
	for _, e in entities do
		if e.Payer == player and e.State ~= S.Travelling and e.State ~= S.Spawning then
			count += 1
		end
	end
	return count
end

local function carryFactor(rank: number): number
	local range = Config.CarryWalkFactor
	local fraction = (rank - 1) / math.max(1, #RarityConfig.Order - 1)
	return range.Max - (range.Max - range.Min) * fraction
end

---------------------------------------------------------------------------
-- removal / refunds
---------------------------------------------------------------------------

local function cancelChannel(player: Player, silent: boolean?)
	if channels[player] then
		channels[player] = nil
		if not silent and player.Parent == Players then
			Remotes.event("Channel"):FireClient(player, "", 0, "")
		end
	end
end

local function release(e: Entity)
	local holder = e.Holder
	if holder then
		if carrying[holder] == e then
			carrying[holder] = nil
		end
		PlayerState.setCarry(holder, nil)
	end
	for player, channel in channels do
		if channel.Id == e.Id then
			cancelChannel(player)
		end
	end
	e.Holder = nil
	e.HolderName = ""
end

local function refund(player: Player?, amount: number)
	if player and player.Parent == Players and amount > 0 then
		EconomySystem.addCoins(player, amount, false)
	end
end

local function remove(e: Entity, reason: string, extra: any?)
	if entities[e.Id] ~= e then
		return
	end
	release(e)
	entities[e.Id] = nil
	Remotes.event("HamsterRemove"):FireAllClients(e.Id, reason, extra)
end

---------------------------------------------------------------------------
-- creation
---------------------------------------------------------------------------

local function newEntity(species: any, lane: number): Entity
	local definition = RarityConfig.ById[species.Rarity]
	counter += 1
	local spawn = Vector3.new(PathConfig.SpawnPoint.X, PathConfig.RoadHeight, lane)
	local baseSpeed = definition.Speed * (0.94 + random:NextNumber() * 0.12)
	return {
		Id = "h" .. counter,
		Species = species,
		SpeciesId = species.Id,
		Rarity = species.Rarity,
		Rank = definition.Rank,
		State = S.Spawning,
		StateSince = os.clock(),
		Price = HamsterDatabase.price(species),
		Radius = S.ballRadius(definition.Rank),
		Payer = nil,
		PayerName = "",
		Holder = nil,
		HolderName = "",
		Route = roadRoute,
		Dist = 0,
		Lat = lane,
		LatTarget = lane,
		HomeLat = lane,
		LaneCooldown = 0,
		BaseSpeed = baseSpeed,
		TransitSpeed = math.clamp(definition.Speed * Config.TransitSpeedFactor, Config.TransitSpeedMin, Config.TransitSpeedMax),
		Speed = 0,
		Position = spawn,
		Yaw = yawOf(1, 0),
		Static = false,
		CarryStart = 0,
		DropAt = 0,
		Bans = {},
		Resets = 0,
		ArrivedAt = nil,
		LastSent = spawn,
		SentSpeed = 0,
		StolenFrom = nil,
	}
end

-- Who is lucky this spawn? Players take turns: their Luck and Rebirths decide the species.
local function nextSponsor(): Player?
	for _ = 1, 2 do
		while #sponsorQueue > 0 do
			local player = table.remove(sponsorQueue, 1)
			if player and player.Parent == Players and DataSystem.isLoaded(player) then
				return player
			end
		end
		for _, player in Players:GetPlayers() do
			if DataSystem.isLoaded(player) then
				table.insert(sponsorQueue, player)
			end
		end
		Util.shuffle(sponsorQueue, random)
	end
	return nil
end

function HamsterSystem.roll(data: any, now: number): any
	local weights = RarityConfig.adjustedWeights(data.Rebirths, EconomyMath.luck(data, now))
	local ids = {}
	local values = {}
	for _, id in RarityConfig.Order do
		if weights[id] and #HamsterDatabase.Spawnable[id] > 0 then
			table.insert(ids, id)
			table.insert(values, weights[id])
		end
	end
	local index = Util.weightedIndex(values, random)
	local rarityId = if index then ids[index] else "Basic"
	local pool = HamsterDatabase.Spawnable[rarityId]
	return pool[random:NextInteger(1, #pool)]
end

local function countOnRoad(): number
	local count = 0
	for _, e in entities do
		if e.State == S.Spawning or e.State == S.Travelling then
			count += 1
		end
	end
	return count
end

-- Spawns one ball at the burrow. Returns the entity or nil (burrow busy / nobody online).
function HamsterSystem.spawn(speciesOverride: any?, sponsor: Player?): Entity?
	local species = speciesOverride
	local sponsorPlayer = sponsor
	if not species then
		sponsorPlayer = sponsorPlayer or nextSponsor()
		local data = if sponsorPlayer then DataSystem.get(sponsorPlayer) else nil
		if not data then
			return nil
		end
		species = HamsterSystem.roll(data, os.time())
	end

	-- pick a lane whose start is free
	local lanes = { table.unpack(PathConfig.LaneOffsets) }
	Util.shuffle(lanes, random)
	local chosen = nil
	local radius = S.ballRadius(RarityConfig.ById[species.Rarity].Rank)
	for _, lane in lanes do
		local free = true
		for _, other in entities do
			if (other.State == S.Spawning or other.State == S.Travelling) and other.Dist < 22 and math.abs(other.Lat - lane) < radius + other.Radius + 0.5 then
				free = false
				break
			end
		end
		if free then
			chosen = lane
			break
		end
	end
	if not chosen then
		return nil
	end

	local e = newEntity(species, chosen)
	entities[e.Id] = e
	Remotes.event("HamsterAdd"):FireAllClients({ packet(e) })

	local definition = RarityConfig.ById[species.Rarity]
	Remotes.event("Fx"):FireAllClients("Spawn", species.Rarity, e.Position, nil)
	if definition.Announce >= 1 then
		Remotes.event("Fx"):FireAllClients("RareSpawn", species.Rarity, e.Position, nil)
	end
	AnnounceSystem.rareSpawn(sponsorPlayer, species)
	return e
end

---------------------------------------------------------------------------
-- steering: lane changes, braking, hard separation
---------------------------------------------------------------------------

local function solid(e: Entity): boolean
	return e.State ~= S.Carried and e.State ~= S.Secured
end

-- The nearest ball that blocks lateral position `lat` within `lookAhead` studs in front of `e`.
local function findBlocker(e: Entity, lat: number, tangent: Vector3, normal: Vector3, lookAhead: number, behind: number): (any?, number)
	local nearest: any = nil
	local nearestAhead = math.huge
	local px, pz = e.Position.X, e.Position.Z
	local function consider(o: any)
		local dx, dz = o.Position.X - px, o.Position.Z - pz
		local ahead = dx * tangent.X + dz * tangent.Z
		local side = dx * normal.X + dz * normal.Z
		local reach = e.Radius + o.Radius
		if ahead > -(reach * 0.5 + behind) and ahead < lookAhead + o.Radius and math.abs(e.Lat + side - lat) < reach + 0.35 then
			if ahead < nearestAhead then
				nearest = o
				nearestAhead = ahead
			end
		end
	end
	for _, o in entities do
		if o ~= e and solid(o) then
			consider(o)
		end
	end
	for _, walker in walkers do
		consider(walker)
	end
	return nearest, nearestAhead
end

local function desiredSpeed(e: Entity): number
	if e.State == S.Spawning then
		return e.BaseSpeed * 0.4
	elseif e.State == S.Travelling then
		return e.BaseSpeed
	end
	return e.TransitSpeed
end

local function laneCandidates(e: Entity, maxLat: number): { number }
	local result = {}
	if maxLat >= 3.9 then
		for _, lane in PathConfig.LaneOffsets do
			table.insert(result, math.clamp(lane, -maxLat, maxLat))
		end
	end
	table.insert(result, -maxLat)
	table.insert(result, maxLat)
	if maxLat > 0.5 then
		table.insert(result, 0)
	end
	table.sort(result, function(a, b)
		return math.abs(a - e.Lat) < math.abs(b - e.Lat)
	end)
	return result
end

local function placeOnRoute(e: Entity)
	local route = e.Route
	if not route then
		return
	end
	local base, tangent = route:pointAt(e.Dist)
	local normal = tangent:Cross(Vector3.yAxis)
	e.Position = base + normal * e.Lat
end

local function stepRolling(e: Entity, dt: number)
	local route = e.Route
	if not route then
		return
	end
	local base, tangent = route:pointAt(e.Dist)
	local normal = tangent:Cross(Vector3.yAxis)
	local halfWidth = WorldLayout.corridorHalfWidth(base)
	local maxLat = math.max(0, halfWidth - e.Radius)
	local desired = desiredSpeed(e)
	local lookAhead = e.Radius + 5 + e.Speed * 0.9
	e.LaneCooldown -= dt

	local blocker, ahead = findBlocker(e, e.LatTarget, tangent, normal, lookAhead, 0)
	local blocking = blocker ~= nil and (blocker.Static or blocker.Speed < desired + 0.5 or ahead - e.Radius - blocker.Radius < 2)
	local brakeFor: any = nil
	local brakeAhead = 0

	if blocking and blocker then
		-- go around: nearest free lateral position
		local moved = false
		if e.LaneCooldown <= 0 then
			for _, candidate in laneCandidates(e, maxLat) do
				if math.abs(candidate - e.LatTarget) > 0.5 then
					local other = findBlocker(e, candidate, tangent, normal, lookAhead, 3)
					if not other then
						e.LatTarget = candidate
						e.LaneCooldown = 0.8
						moved = true
						break
					end
				end
			end
		end
		if not moved and not blocker.IsPlayer then
			-- people can't block the whole road: only other balls make us brake
			brakeFor, brakeAhead = blocker, ahead
		end
	elseif e.LatTarget ~= e.HomeLat and e.LaneCooldown <= 0 then
		-- overtake / detour finished: return to the home lane (road lane or route centre) when it is free
		local other = findBlocker(e, e.HomeLat, tangent, normal, lookAhead + 4, 6)
		if not other then
			e.LatTarget = e.HomeLat
			e.LaneCooldown = 0.8
		end
	end

	local target = desired
	if brakeFor then
		local gap = brakeAhead - e.Radius - brakeFor.Radius
		target = math.max(0, math.min(desired, brakeFor.Speed + (gap - 1.5) * 1.3))
	end
	local accel = if target > e.Speed then 16 else 42
	if e.Speed < target then
		e.Speed = math.min(target, e.Speed + accel * dt)
	else
		e.Speed = math.max(target, e.Speed - accel * dt)
	end

	local latSpeed = LATERAL_SPEED + e.Speed * 0.05
	e.LatTarget = math.clamp(e.LatTarget, -maxLat, maxLat)
	e.Lat += math.clamp(e.LatTarget - e.Lat, -latSpeed * dt, latSpeed * dt)
	e.Lat = math.clamp(e.Lat, -maxLat, maxLat)
	e.Dist = math.min(route.Length, e.Dist + e.Speed * dt)

	local before = e.Position
	placeOnRoute(e)
	local dx, dz = e.Position.X - before.X, e.Position.Z - before.Z
	if dx * dx + dz * dz > 1e-5 then
		local want = yawOf(dx, dz)
		local delta = (want - e.Yaw + math.pi) % (2 * math.pi) - math.pi
		e.Yaw += delta * math.min(1, dt * 9)
	end
end

local function pushEntity(e: Entity, px: number, pz: number)
	e.Position = Vector3.new(e.Position.X + px, e.Position.Y, e.Position.Z + pz)
	local route = e.Route
	if route and (e.State == S.Spawning or e.State == S.Travelling or e.State == S.InTransit) then
		local base, tangent = route:pointAt(e.Dist)
		local rx, rz = e.Position.X - base.X, e.Position.Z - base.Z
		e.Dist = math.clamp(e.Dist + rx * tangent.X + rz * tangent.Z, 0, route.Length)
		local base2, tangent2 = route:pointAt(e.Dist)
		local normal2 = tangent2:Cross(Vector3.yAxis)
		local lat = (e.Position.X - base2.X) * normal2.X + (e.Position.Z - base2.Z) * normal2.Z
		local maxLat = math.max(0, WorldLayout.corridorHalfWidth(base2) - e.Radius)
		e.Lat = math.clamp(lat, -maxLat, maxLat)
		placeOnRoute(e)
	end
end

local function separate()
	-- people standing in a ball's way: the ball is nudged around them
	for _, e in entities do
		if solid(e) and not e.Static then
			for _, walker in walkers do
				local dx, dz = e.Position.X - walker.Position.X, e.Position.Z - walker.Position.Z
				local dist = math.sqrt(dx * dx + dz * dz)
				local minDist = e.Radius + walker.Radius
				if dist < minDist and dist > 0.001 then
					local overlap = minDist - dist
					pushEntity(e, dx / dist * overlap, dz / dist * overlap)
				end
			end
		end
	end
	local list: { Entity } = {}
	for _, e in entities do
		if solid(e) then
			table.insert(list, e)
		end
	end
	for _ = 1, 2 do
		for i = 1, #list do
			local a = list[i]
			for j = i + 1, #list do
				local b = list[j]
				local dx, dz = b.Position.X - a.Position.X, b.Position.Z - a.Position.Z
				local dist = math.sqrt(dx * dx + dz * dz)
				local minDist = a.Radius + b.Radius
				if dist < minDist then
					if dist < 0.001 then
						dx, dz, dist = 1, 0, 1
					end
					local overlap = minDist - dist + 0.02
					local nx, nz = dx / dist, dz / dist
					local aMoves, bMoves = not a.Static, not b.Static
					local shareA = if aMoves and bMoves then 0.5 elseif aMoves then 1 else 0
					local shareB = if aMoves and bMoves then 0.5 elseif bMoves then 1 else 0
					if shareA > 0 then
						pushEntity(a, -nx * overlap * shareA, -nz * overlap * shareA)
					end
					if shareB > 0 then
						pushEntity(b, nx * overlap * shareB, nz * overlap * shareB)
					end
					-- the one behind slows to the speed of the one in front
					local aForwardX, aForwardZ = -math.sin(a.Yaw), -math.cos(a.Yaw)
					local bForwardX, bForwardZ = -math.sin(b.Yaw), -math.cos(b.Yaw)
					if a.Speed > b.Speed and nx * aForwardX + nz * aForwardZ > 0 then
						a.Speed = b.Speed
					elseif b.Speed > a.Speed and -nx * bForwardX - nz * bForwardZ > 0 then
						b.Speed = a.Speed
					end
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- state transitions
---------------------------------------------------------------------------

local function groundY(root: BasePart, humanoid: Humanoid?): number
	local hip = if humanoid then humanoid.HipHeight else 2
	return math.max(0.1, root.Position.Y - hip - root.Size.Y / 2)
end

-- A carried ball goes to the ground where the carrier stood.
local function dropEntity(e: Entity, reason: string, banSeconds: number?)
	if e.State ~= S.Carried then
		return
	end
	local holder = e.Holder
	if holder and banSeconds and banSeconds > 0 then
		e.Bans[holder] = os.clock() + banSeconds
	end
	local humanoid, root = nil, nil
	if holder then
		humanoid, root = PlayerState.character(holder)
	end
	if root then
		local look = flat(root.CFrame.LookVector)
		if look.Magnitude < 0.01 then
			look = Vector3.zAxis
		end
		local spot = root.Position - look.Unit * (e.Radius + 1.5)
		e.Position = Vector3.new(spot.X, groundY(root, humanoid), spot.Z)
	end
	-- keep it inside the map
	local limitX, limitZ = WorldLayout.GroundHalfX - 6, WorldLayout.GroundHalfZ - 6
	e.Position = Vector3.new(math.clamp(e.Position.X, -limitX, limitX), e.Position.Y, math.clamp(e.Position.Z, -limitZ, limitZ))
	if holder then
		local holderName = e.HolderName
		release(e)
		Notifier.send(holder, "You dropped the " .. e.Species.Name .. " ball!", "error")
		local payer = e.Payer
		if payer and payer ~= holder then
			Notifier.send(payer, string.format("%s dropped your hamster - get it back!", holderName), "info")
		end
	end
	e.Speed = 0
	e.Static = true
	e.Route = nil
	e.DropAt = os.clock()
	setState(e, S.Dropped)
	fx("Drop", e, reason)
end

local function projectToWalkway(e: Entity, side: number): Vector3
	local x = math.clamp(e.Position.X, -WorldLayout.GroundHalfX + 12, WorldLayout.GroundHalfX - 12)
	return Vector3.new(x, 0.1, side * WorldLayout.PromenadeZ)
end

local function startTransit(e: Entity, payer: Player, from: Vector3): boolean
	local house = HouseSystem.getHouse(payer)
	if not house then
		return false
	end
	local route = WorldLayout.transitRoute(house.CFrame, from)
	e.Route = route
	e.Dist = 0
	e.Lat = 0
	e.LatTarget = 0
	e.HomeLat = 0
	e.Static = false
	e.ArrivedAt = nil
	e.Position = route:pointAt(0)
	return true
end

-- Abandoned (nobody took it / carrier vanished): it rolls back to the player who paid.
local function returnToPayer(e: Entity)
	local payer = e.Payer
	if not payer or payer.Parent ~= Players or not HouseSystem.getHouse(payer) then
		remove(e, "Lost")
		return
	end
	e.Resets += 1
	if e.Resets > Config.MaxResets then
		refund(payer, e.Price * 0.5)
		Notifier.send(payer, "Your hamster ran away. You got half of its price back.", "info")
		remove(e, "Lost")
		return
	end
	local house = HouseSystem.getHouse(payer)
	local side = if house and house.CFrame.LookVector.Z > 0 then 1 else -1
	if not startTransit(e, payer, projectToWalkway(e, side)) then
		remove(e, "Lost")
		return
	end
	e.Speed = 0
	e.StolenFrom = nil
	setState(e, S.InTransit)
	Notifier.send(payer, "Your hamster is rolling home again.", "info")
end

local function secure(e: Entity, player: Player)
	if entities[e.Id] ~= e then
		return
	end
	local payer = e.Payer
	local position = e.Position
	local result = CollectionSystem.grant(player, e.SpeciesId, "Collect")
	if not result then
		return
	end
	remove(e, "Secured", player.UserId)
	Remotes.event("Fx"):FireAllClients("Secure", e.Rarity, position, player.UserId)

	local data = DataSystem.get(player)
	if data then
		data.Stats.Secured = (data.Stats.Secured or 0) + 1
	end
	local stolen = payer ~= nil and payer ~= player
	if stolen then
		if data then
			data.Stats.Stolen = (data.Stats.Stolen or 0) + 1
			ReplicationSystem.mark(player, "Stats")
		end
		if payer and payer.Parent == Players then
			local back = e.Price * Config.StolenInsurance
			EconomySystem.addCoins(payer, back, false)
			Notifier.send(payer, string.format("Insurance paid back %s for your stolen hamster.", Format.coins(back)), "info")
		end
	end
	Remotes.event("CollectResult"):FireClient(player, true, e.Id, e.SpeciesId, result.IsNew, if result.AutoSold then "AutoSold" else "")
	Notifier.send(player, "HAMSTER SECURED! " .. e.Species.Name .. " is yours for good.", "success")
	if stolen then
		AnnounceSystem.stolenSecured(player, payer, e.Species)
	end
end

local function takePossession(e: Entity, player: Player, kind: string)
	local previous = e.Holder
	if previous then
		release(e)
	end
	local payer = e.Payer
	local wasInTransit = e.State == S.InTransit
	e.Holder = player
	e.HolderName = player.DisplayName
	e.CarryStart = os.clock()
	e.Route = nil
	e.Static = false
	e.Speed = 0
	carrying[player] = e
	PlayerState.setCarry(player, carryFactor(e.Rank))
	setState(e, S.Carried)

	if kind == "steal" and payer and payer ~= player then
		e.StolenFrom = payer
		fx("Steal", e)
		Notifier.send(player, "You stole " .. e.Species.Name .. "! Run it to YOUR house!", "success")
		Notifier.send(payer, string.format("HAMSTER STOLEN! %s took your %s! Slap them or take it back - if they get it home you only get %d%% back.", player.DisplayName, e.Species.Name, math.floor(Config.StolenInsurance * 100)), "error")
		Remotes.event("Fx"):FireClient(payer, "Alarm", e.Rarity, e.Position, nil)
		AnnounceSystem.stolen(player, payer, e.Species)
		local data = DataSystem.get(player)
		if data then
			data.Stats.Steals = (data.Stats.Steals or 0) + 1
			ReplicationSystem.mark(player, "Stats")
		end
	elseif payer == player and not wasInTransit then
		fx("Recover", e)
		Notifier.send(player, "HAMSTER RECOVERED! Get it home!", "success")
		local data = DataSystem.get(player)
		if data then
			data.Stats.Recovered = (data.Stats.Recovered or 0) + 1
			ReplicationSystem.mark(player, "Stats")
		end
	elseif payer == player then
		fx("Pickup", e)
		Notifier.send(player, "You're carrying your hamster home.", "info")
	else
		fx("Pickup", e)
		Notifier.send(player, "You grabbed the dropped " .. e.Species.Name .. "! Run it to YOUR house!", "success")
		if payer and payer.Parent == Players then
			Notifier.send(payer, string.format("%s grabbed your dropped hamster!", player.DisplayName), "info")
		end
	end
end

---------------------------------------------------------------------------
-- interaction (claim / steal / pick up)
---------------------------------------------------------------------------

local function inReach(player: Player, e: Entity, root: BasePart, range: number): boolean
	local center = e.Position + Vector3.new(0, e.Radius, 0)
	return (root.Position - center).Magnitude - e.Radius <= range
end

local function startChannel(player: Player, e: Entity, kind: string, seconds: number)
	channels[player] = { Id = e.Id, Start = os.clock(), Duration = seconds, Kind = kind }
	Remotes.event("Channel"):FireClient(player, e.Id, seconds, kind)
	if kind == "steal" and e.Payer and e.Payer ~= player and e.Payer.Parent == Players then
		Notifier.send(e.Payer, string.format("%s is trying to steal your %s!", player.DisplayName, e.Species.Name), "error")
		Remotes.event("Fx"):FireClient(e.Payer, "Alarm", e.Rarity, e.Position, nil)
	end
end

local function claim(player: Player, e: Entity, data: any, root: BasePart)
	local range = EconomyMath.collectRange(data) + Config.ClaimRange + e.Speed * 0.3
	if not inReach(player, e, root, range) then
		return false
	end
	if pendingCount(player) >= Config.MaxPending then
		Notifier.send(player, "You already have " .. Config.MaxPending .. " hamsters on the way home. Secure one first!", "error")
		return false
	end
	if data.Coins < e.Price then
		Notifier.send(player, "Not enough coins! You need " .. Format.coins(e.Price), "error")
		return false
	end
	if not HouseSystem.getHouse(player) then
		Notifier.send(player, "You need a house first. Wait for a free one!", "error")
		return false
	end
	if not EconomySystem.trySpendCoins(player, e.Price) then
		return false
	end
	e.Payer = player
	e.PayerName = player.DisplayName
	if not startTransit(e, player, e.Position) then
		refund(player, e.Price)
		e.Payer = nil
		e.PayerName = ""
		return false
	end
	setState(e, S.InTransit)
	fx("Claim", e)
	Notifier.send(player, string.format("Claimed %s! It's rolling to your house - guard it!", e.Species.Name), "success")
	data.Stats.Claimed = (data.Stats.Claimed or 0) + 1
	ReplicationSystem.mark(player, "Stats")
	return true
end

function HamsterSystem.interact(player: Player, id: any)
	if type(id) ~= "string" or #id > 12 then
		return
	end
	local e = entities[id]
	local data = DataSystem.get(player)
	local humanoid, root = PlayerState.character(player)
	if not e or not data or not root or not humanoid or PlayerState.isStunned(player) then
		return
	end
	if channels[player] then
		return
	end

	if e.State == S.Travelling then
		claim(player, e, data, root)
		return
	end

	if e.State ~= S.InTransit and e.State ~= S.Recoverable then
		return
	end
	if carrying[player] then
		Notifier.send(player, "You're already carrying a hamster!", "error")
		return
	end
	if not HouseSystem.getHouse(player) then
		Notifier.send(player, "You need a house first. Wait for a free one!", "error")
		return
	end
	if not inReach(player, e, root, Config.InteractRange + 2) then
		return
	end
	local ban = e.Bans[player]
	if ban and ban > os.clock() then
		return
	end
	if e.State == S.InTransit then
		if e.Payer == player then
			startChannel(player, e, "carry", 0.4)
		else
			local fraction = (e.Rank - 1) / math.max(1, #RarityConfig.Order - 1)
			startChannel(player, e, "steal", Config.StealSeconds.Min + (Config.StealSeconds.Max - Config.StealSeconds.Min) * fraction)
		end
	else
		startChannel(player, e, "pickup", Config.PickupSeconds)
	end
end

-- A slap (or a zap) interrupts what the player is doing.
function HamsterSystem.interrupt(player: Player)
	cancelChannel(player)
end

function HamsterSystem.carriedBy(player: Player): Entity?
	return carrying[player]
end

-- Used by slaps / zaps / admin: makes `player` let go of their ball.
function HamsterSystem.dropCarried(player: Player, reason: string, banSeconds: number?): boolean
	local e = carrying[player]
	if not e then
		return false
	end
	dropEntity(e, reason, banSeconds or Config.DropBanSeconds)
	return true
end

---------------------------------------------------------------------------
-- the tick
---------------------------------------------------------------------------

local function updateChannels()
	local now = os.clock()
	for player, channel in channels do
		local e = entities[channel.Id]
		local humanoid, root = PlayerState.character(player)
		local valid = e ~= nil and humanoid ~= nil and root ~= nil and not PlayerState.isStunned(player)
		if valid and e and root then
			local stateOk = (channel.Kind == "pickup" and e.State == S.Recoverable) or ((channel.Kind == "steal" or channel.Kind == "carry") and e.State == S.InTransit)
			valid = stateOk and inReach(player, e, root, Config.InteractRange + 3.5)
			if valid and channel.Kind == "carry" and e.Payer ~= player then
				valid = false
			end
		end
		if not valid then
			cancelChannel(player)
		elseif e and now - channel.Start >= channel.Duration then
			channels[player] = nil
			Remotes.event("Channel"):FireClient(player, "", 0, "")
			if not carrying[player] then
				takePossession(e, player, channel.Kind)
			end
		end
	end
end

local function updateCarried(e: Entity, dt: number)
	local holder = e.Holder
	if not holder or holder.Parent ~= Players then
		dropEntity(e, "Left")
		return
	end
	local humanoid, root = PlayerState.character(holder)
	if not humanoid or not root then
		dropEntity(e, "Down", Config.DropBanSeconds)
		return
	end
	local now = os.clock()
	if now - e.CarryStart > Config.MaxCarrySeconds then
		Notifier.send(holder, "You carried it too long - it slipped away!", "error")
		dropEntity(e, "Timeout", Config.TimeoutBanSeconds)
		return
	end
	local position = root.Position
	if math.abs(position.X) > WorldLayout.GroundHalfX or math.abs(position.Z) > WorldLayout.GroundHalfZ or position.Y < -15 or position.Y > 120 then
		Notifier.send(holder, "You left the playing field - the ball rolled back!", "error")
		dropEntity(e, "OutOfBounds", Config.TimeoutBanSeconds)
		return
	end
	local velocity = root.AssemblyLinearVelocity
	if Vector3.new(velocity.X, 0, velocity.Z).Magnitude > Config.MaxCarrySpeed then
		dropEntity(e, "Speed", Config.TimeoutBanSeconds)
		return
	end

	local look = flat(root.CFrame.LookVector)
	if look.Magnitude < 0.01 then
		look = Vector3.zAxis
	end
	look = look.Unit
	local carriedRadius = e.Radius * 0.75
	local target = position - look * (carriedRadius + 2.2)
	local ground = groundY(root, humanoid)
	local alpha = 1 - math.exp(-14 * dt)
	local nextPosition = Vector3.new(
		e.Position.X + (target.X - e.Position.X) * alpha,
		e.Position.Y + (ground - e.Position.Y) * alpha,
		e.Position.Z + (target.Z - e.Position.Z) * alpha
	)
	e.Speed = distanceXZ(nextPosition, e.Position) / math.max(dt, 1e-3)
	e.Position = nextPosition
	e.Yaw = yawOf(look.X, look.Z)

	-- secure: the carrier reached the arrival pad of their own house
	local house = HouseSystem.getHouse(holder)
	if house then
		local pad = WorldLayout.padPosition(house.CFrame)
		if distanceXZ(position, pad) <= WorldLayout.SecureRadius and WorldLayout.inLot(house.CFrame, position, 0) then
			secure(e, holder)
		end
	end
end

local function refreshWalkers()
	table.clear(walkers)
	for _, player in Players:GetPlayers() do
		local _, root = PlayerState.character(player)
		-- only on the road / promenades; inside house lots people never block a ball
		if root and math.abs(root.Position.Z) < WorldLayout.GateDistance - 1 then
			table.insert(walkers, { Position = root.Position, Radius = PLAYER_RADIUS, Speed = 0, Static = true, IsPlayer = true })
		end
	end
end

local function tick(dt: number, step: number)
	local now = os.clock()
	refreshWalkers()

	-- state timers
	for _, e in entities do
		if e.State == S.Spawning and now - e.StateSince > 1.3 then
			setState(e, S.Travelling)
		elseif e.State == S.Dropped and now - e.DropAt > Config.DropGraceSeconds then
			setState(e, S.Recoverable)
		elseif e.State == S.Recoverable and now - e.DropAt > Config.DropExpireSeconds then
			returnToPayer(e)
		end
	end

	updateChannels()

	for _, e in entities do
		if e.State == S.Spawning or e.State == S.Travelling or e.State == S.InTransit then
			stepRolling(e, dt)
		elseif e.State == S.Carried then
			updateCarried(e, dt)
		end
	end
	separate()

	-- arrivals
	for _, e in entities do
		local route = e.Route
		if route and e.Dist >= route.Length - 0.05 then
			if e.State == S.Travelling or e.State == S.Spawning then
				remove(e, "Exit")
			elseif e.State == S.InTransit then
				-- it stops on the arrival pad for a moment: a thief standing in the house can still grab it
				local payer = e.Payer
				if not payer or payer.Parent ~= Players then
					remove(e, "Lost")
				elseif not e.ArrivedAt then
					e.ArrivedAt = now
					e.Speed = 0
				elseif now - e.ArrivedAt >= Config.PadSettleSeconds then
					secure(e, payer)
				end
			end
		end
	end

	-- spawning
	if HamsterSystem.AutoSpawn and now >= nextSpawnAt then
		local players = #Players:GetPlayers()
		local interval = math.clamp(5.6 - 0.35 * players, 2.8, 5.6)
		if countOnRoad() < MAX_ON_ROAD and players > 0 then
			if HamsterSystem.spawn() then
				nextSpawnAt = now + interval * (0.75 + random:NextNumber() * 0.5)
			else
				nextSpawnAt = now + 0.5
			end
		else
			nextSpawnAt = now + 1
		end
	end

	-- snapshots
	if step % SNAP_EVERY == 0 then
		local rows = {}
		for _, e in entities do
			if (e.Position - e.LastSent).Magnitude > 0.02 or math.abs(e.Speed - e.SentSpeed) > 0.2 then
				e.LastSent = e.Position
				e.SentSpeed = e.Speed
				table.insert(rows, { e.Id, e.Position.X, e.Position.Y, e.Position.Z, e.Yaw, e.Speed })
			end
		end
		if #rows > 0 then
			Remotes.event("HamsterSnap"):FireAllClients(rows)
		end
	end
end

-- Auto Collect (boost / pass): claims the best affordable travelling ball in range.
local function autoClaim()
	local now = os.time()
	for _, player in Players:GetPlayers() do
		local data = DataSystem.get(player)
		if data and EconomyMath.autoCollect(data, now) and not carrying[player] then
			local _, root = PlayerState.character(player)
			if root and pendingCount(player) < Config.MaxPending then
				local best: Entity? = nil
				for _, e in entities do
					if e.State == S.Travelling and data.Coins >= e.Price and inReach(player, e, root, EconomyMath.collectRange(data) + Config.ClaimRange) then
						if not best or e.Rank > best.Rank then
							best = e
						end
					end
				end
				if best then
					claim(player, best, data, root)
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- lifecycle
---------------------------------------------------------------------------

-- Everything currently in the world (sent to a player who just joined).
function HamsterSystem.sendAll(player: Player)
	local rows = {}
	for _, e in entities do
		table.insert(rows, packet(e))
	end
	Remotes.event("HamsterAdd"):FireClient(player, rows)
end

function HamsterSystem.onPlayerRemoving(player: Player)
	cancelChannel(player, true)
	channels[player] = nil
	buckets[player] = nil
	local held = carrying[player]
	if held then
		dropEntity(held, "Left")
	end
	for _, e in entities do
		e.Bans[player] = nil
		if e.Payer == player then
			-- they leave, the ball goes away and the price comes back before the profile is saved
			local data = DataSystem.get(player)
			if data then
				data.Coins += e.Price * Config.VanishRefund
				DataSystem.markDirty(player)
			end
			remove(e, "PayerLeft")
		elseif e.StolenFrom == player then
			e.StolenFrom = nil
		end
	end
	for i = #sponsorQueue, 1, -1 do
		if sponsorQueue[i] == player then
			table.remove(sponsorQueue, i)
		end
	end
end

-- True when a hamster that can be fought over (rolling home, carried, dropped) is within `radius` studs.
function HamsterSystem.hamsterNear(position: Vector3, radius: number): boolean
	for _, e in entities do
		if e.State == S.InTransit or e.State == S.Carried or e.State == S.Dropped or e.State == S.Recoverable then
			if distanceXZ(e.Position, position) <= radius then
				return true
			end
		end
	end
	return false
end

function HamsterSystem.isChanneling(player: Player): boolean
	return channels[player] ~= nil
end

function HamsterSystem.get(id: string): Entity?
	return entities[id]
end

function HamsterSystem.all(): { [string]: Entity }
	return entities
end

function HamsterSystem.start()
	Remotes.event("Interact").OnServerEvent:Connect(function(player, id)
		if not allowRequest(player) then
			return
		end
		HamsterSystem.interact(player, id)
	end)

	nextSpawnAt = os.clock() + 2
	task.spawn(function()
		local last = os.clock()
		local step = 0
		local autoTimer = 0
		while true do
			task.wait(STEP)
			local now = os.clock()
			local dt = math.min(now - last, 0.2)
			last = now
			step += 1
			local ok, err = pcall(tick, dt, step)
			if not ok then
				warn("[HamsterSystem] tick failed: " .. tostring(err))
			end
			autoTimer += dt
			if autoTimer >= 0.5 then
				autoTimer = 0
				local autoOk, autoErr = pcall(autoClaim)
				if not autoOk then
					warn("[HamsterSystem] autoClaim failed: " .. tostring(autoErr))
				end
			end
		end
	end)
end

return HamsterSystem
