--[[
	PlaytimeSystem: counts the time a player spends in this experience (on the SERVER) and pays the playtime rewards.
	Milestones, rewards and the rules (one claim per milestone, per player, permanent) are in Modules/PlaytimeConfig.

	  * Counting: a loop adds the real time that passed to profile.Playtime.Seconds every PlaytimeConfig.TickSeconds (never more
	    than one tick per round, so a frozen server or a changed clock can not add a burst). The number is also published as the
	    player attribute PlaytimeSeconds so the window can show a live counter. The client can not change either.
	  * Claiming (request ClaimPlaytime { Id }): the server checks that the milestone exists, that the time is reached and that it
	    is not claimed yet. The milestone is marked as claimed BEFORE the reward is paid (a second click, a second request or a
	    second server can never pay it again) and the mark is undone only if paying itself failed. The claim and the reward live
	    in the same saved profile, so a crash can not leave a paid reward without the mark or the other way round.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local HamsterDatabase = require(ReplicatedStorage.Modules.HamsterDatabase)
local PlaytimeConfig = require(ReplicatedStorage.Modules.PlaytimeConfig)

local DataSystem = require(script.Parent.DataSystem)
local Notifier = require(script.Parent.Notifier)
local ReplicationSystem = require(script.Parent.ReplicationSystem)
local Rewards = require(script.Parent.Rewards)

local PlaytimeSystem = {}

local random = Random.new()
local lastTick: { [Player]: number } = {}
local lastSent: { [Player]: number } = {}
local busy: { [Player]: boolean } = {}
local lastRequest: { [Player]: number } = {}
local MIN_GAP = 0.5
local REPLICATE_EVERY = 30 -- seconds between full profile updates (the live counter uses the attribute)
local started = false

local function profile(player: Player): any?
	local data = DataSystem.get(player)
	if not data then
		return nil
	end
	if type(data.Playtime) ~= "table" then
		data.Playtime = { Seconds = 0, Claimed = {} }
	end
	if type(data.Playtime.Seconds) ~= "number" or data.Playtime.Seconds ~= data.Playtime.Seconds or data.Playtime.Seconds < 0 then
		data.Playtime.Seconds = 0
	end
	if type(data.Playtime.Claimed) ~= "table" then
		data.Playtime.Claimed = {}
	end
	return data.Playtime
end

-- Adds `seconds` of played time (at most one tick) and publishes it. Returns the new total.
function PlaytimeSystem.credit(player: Player, seconds: number): number
	local playtime = profile(player)
	if not playtime then
		return 0
	end
	playtime.Seconds += math.clamp(seconds, 0, PlaytimeConfig.TickSeconds * 2)
	player:SetAttribute("PlaytimeSeconds", math.floor(playtime.Seconds))
	DataSystem.markDirty(player)
	return playtime.Seconds
end

function PlaytimeSystem.seconds(player: Player): number
	local playtime = profile(player)
	return if playtime then playtime.Seconds else 0
end

-- A hamster of that rarity that anybody may get (never an exclusive or limited-edition one).
local function pickHamster(rarity: string): string?
	local pool = {}
	for _, species in HamsterDatabase.ByRarity[rarity] or {} do
		if not species.Exclusive and not species.Limited then
			table.insert(pool, species.Id)
		end
	end
	if #pool == 0 then
		return nil
	end
	return pool[random:NextInteger(1, #pool)]
end

-- Returns (ok, message, { Id, Lines })
function PlaytimeSystem.claim(player: Player, id: any): (boolean, string, any?)
	local data = DataSystem.get(player)
	local playtime = profile(player)
	if not data or not playtime then
		return false, "No data"
	end
	local milestone = PlaytimeConfig.byId(id)
	if not milestone then
		return false, "Unknown reward"
	end
	local clock = os.clock()
	if busy[player] or clock - (lastRequest[player] or -10) < MIN_GAP then
		return false, "One moment..."
	end
	lastRequest[player] = clock
	if playtime.Claimed[milestone.Id] then
		return false, "You already claimed that reward"
	end
	if playtime.Seconds < PlaytimeConfig.seconds(milestone) then
		return false, "Not yet: keep playing"
	end
	local reward = PlaytimeConfig.reward(milestone, data.Rebirths or 0)
	if reward.HamsterRarity then
		reward.Hamster = pickHamster(reward.HamsterRarity)
		reward.HamsterRarity = nil
	end
	busy[player] = true
	playtime.Claimed[milestone.Id] = true -- marked FIRST: nothing can claim it a second time while it is being paid
	local paid, lines = pcall(function()
		return Rewards.grant(player, reward)
	end)
	busy[player] = nil
	if not paid then
		warn("[Playtime] paying " .. milestone.Id .. " failed: " .. tostring(lines))
		playtime.Claimed[milestone.Id] = nil
		ReplicationSystem.mark(player, "Playtime")
		return false, "Something went wrong, the reward was kept for you"
	end
	DataSystem.markDirty(player)
	ReplicationSystem.mark(player, "Playtime")
	local text = Rewards.describe(lines)
	Notifier.send(player, "Playtime reward: " .. text, "reward")
	return true, text, { Id = milestone.Id, Lines = lines }
end

function PlaytimeSystem.start()
	if started then
		return
	end
	started = true
	for _, issue in PlaytimeConfig.validate() do
		warn("[Playtime] " .. issue)
	end
	task.spawn(function()
		while true do
			task.wait(PlaytimeConfig.TickSeconds)
			local now = os.clock()
			for _, player in Players:GetPlayers() do
				if DataSystem.get(player) then
					local since = lastTick[player]
					lastTick[player] = now
					if since then
						PlaytimeSystem.credit(player, now - since)
						if now - (lastSent[player] or 0) >= REPLICATE_EVERY then
							lastSent[player] = now
							ReplicationSystem.mark(player, "Playtime")
						end
					else
						lastSent[player] = now
						ReplicationSystem.mark(player, "Playtime")
					end
				end
			end
		end
	end)
end

function PlaytimeSystem.forget(player: Player)
	lastTick[player] = nil
	lastSent[player] = nil
	busy[player] = nil
	lastRequest[player] = nil
end

return PlaytimeSystem
