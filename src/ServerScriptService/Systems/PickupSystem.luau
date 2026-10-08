--[[
	PickupSystem: the world-side of collecting. A client says "grab hamster h12"; the server decides.
	It checks the record exists, where the hamster really is right now, how far the player's character
	is, and that the player can afford it - the client never sends a price or a position.
	Also runs Auto Collect for players who have it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local EconomyMath = require(Modules.EconomyMath)
local Format = require(Modules.Format)
local RarityConfig = require(Modules.RarityConfig)

local Remotes = require(ReplicatedStorage.Remotes)

local CollectionSystem = require(script.Parent.CollectionSystem)
local DataSystem = require(script.Parent.DataSystem)
local EconomySystem = require(script.Parent.EconomySystem)
local Notifier = require(script.Parent.Notifier)
local SpawnSystem = require(script.Parent.SpawnSystem)

local PickupSystem = {}

local RANGE_SLACK = 6 -- studs of leniency for lag
local BUCKET_SIZE = 6
local BUCKET_REFILL = 8 -- requests per second

local buckets: { [Player]: { Tokens: number, Last: number } } = {}

local function allowRequest(player: Player): boolean
	local now = os.clock()
	local bucket = buckets[player]
	if not bucket then
		bucket = { Tokens = BUCKET_SIZE, Last = now }
		buckets[player] = bucket
	end
	bucket.Tokens = math.min(BUCKET_SIZE, bucket.Tokens + (now - bucket.Last) * BUCKET_REFILL)
	bucket.Last = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

local function getRoot(player: Player): BasePart?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return root
	end
	return nil
end

local function inRange(player: Player, data: any, record: SpawnSystem.Record, root: BasePart): boolean
	local range = EconomyMath.collectRange(data) + RANGE_SLACK + record.Speed * 0.3
	local hamsterPosition = SpawnSystem.positionOf(record) + Vector3.new(0, 1.5, 0)
	return (root.Position - hamsterPosition).Magnitude <= range
end

-- Returns true if the hamster was collected.
function PickupSystem.tryCollect(player: Player, id: any, silent: boolean?): boolean
	if type(id) ~= "string" or #id > 12 then
		return false
	end
	local data = DataSystem.get(player)
	local record = SpawnSystem.getRecord(player, id)
	local root = getRoot(player)
	if not data or not record or not root then
		return false
	end
	if not inRange(player, data, record, root) then
		return false
	end

	local price = record.Price
	if data.Coins < price then
		if not silent then
			Notifier.send(player, "Not enough coins! You need " .. Format.coins(price), "error")
			Remotes.event("CollectResult"):FireClient(player, false, id, record.SpeciesId, false, "Poor")
		end
		return false
	end

	-- everything below is atomic (no yields)
	if not EconomySystem.trySpendCoins(player, price) then
		return false
	end
	SpawnSystem.remove(player, id, "Collected")
	local result = CollectionSystem.grant(player, record.SpeciesId, "Collect")
	if result then
		Remotes.event("CollectResult"):FireClient(player, true, id, record.SpeciesId, result.IsNew, if result.AutoSold then "AutoSold" else "")
	end
	return true
end

function PickupSystem.start()
	Remotes.event("Collect").OnServerEvent:Connect(function(player, id)
		if not allowRequest(player) then
			return
		end
		PickupSystem.tryCollect(player, id)
	end)

	-- Auto Collect: once a second, grab affordable hamsters in range (best rarity first)
	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.time()
			for _, player in Players:GetPlayers() do
				local data = DataSystem.get(player)
				if data and EconomyMath.autoCollect(data, now) then
					local root = getRoot(player)
					if root then
						local candidates = {}
						for _, record in SpawnSystem.getAll(player) do
							if inRange(player, data, record, root) and data.Coins >= record.Price then
								table.insert(candidates, record)
							end
						end
						table.sort(candidates, function(a, b)
							return RarityConfig.rank(a.Rarity) > RarityConfig.rank(b.Rarity)
						end)
						for index = 1, math.min(#candidates, 2) do
							PickupSystem.tryCollect(player, candidates[index].Id, true)
						end
					end
				end
			end
		end
	end)
end

function PickupSystem.forget(player: Player)
	buckets[player] = nil
end

return PickupSystem
