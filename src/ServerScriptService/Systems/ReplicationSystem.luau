--[[
	Sends the player's profile to their client (read only; the client never writes anything back).
	Systems call `mark(player, "Inventory", ...)` after changing data; changes are batched every 0.2s.
	Coins / Gems / Tokens / Rebirths additionally live in player attributes (cheap, always current).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local EconomyMath = require(Modules.EconomyMath)
local Remotes = require(ReplicatedStorage.Remotes)

local DataSystem = require(script.Parent.DataSystem)

local ReplicationSystem = {}

-- Profile keys the client may see (Receipts/Codes stay on the server).
local PUBLIC_KEYS = {
	"Inventory", "Index", "Equipped", "IndexRewards", "Upgrades", "Boosts", "Passes", "Cosmetics", "Stats",
	"Quests", "Achievements", "Daily", "Settings", "Rebirths", "FirstJoin", "Items", "Tutorial",
}

local dirty: { [Player]: { [string]: boolean } } = {}

function ReplicationSystem.mark(player: Player, ...: string)
	local set = dirty[player]
	if not set then
		set = {}
		dirty[player] = set
	end
	for _, key in { ... } do
		set[key] = true
	end
	DataSystem.markDirty(player)
end

local function send(player: Player, keys: { string }?)
	local data = DataSystem.get(player)
	if not data or player.Parent == nil then
		return
	end
	local payload: { [string]: any } = {}
	local list: { string } = keys or PUBLIC_KEYS
	for _, key in list do
		payload[key] = data[key]
	end
	local now = os.time()
	local derived = EconomyMath.derived(data, now)
	payload.Derived = derived
	payload.ServerNow = now
	payload.Temporary = DataSystem.isTemporary(player)
	player:SetAttribute("IncomePerSecond", derived.IncomePerSecond)
	Remotes.event("DataUpdate"):FireClient(player, payload, keys == nil)
end

function ReplicationSystem.sendFull(player: Player)
	dirty[player] = nil
	send(player, nil)
end

function ReplicationSystem.clear(player: Player)
	dirty[player] = nil
end

function ReplicationSystem.start()
	task.spawn(function()
		while true do
			task.wait(0.2)
			for player, set in dirty do
				dirty[player] = nil
				local keys = {}
				for key in set do
					table.insert(keys, key)
				end
				send(player, keys)
			end
		end
	end)
end

return ReplicationSystem
