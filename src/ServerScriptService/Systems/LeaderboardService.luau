--[[
	LeaderboardService: global rankings in OrderedDataStores (see LeaderboardConfig for metrics and periods).

	WRITE path (cheap, batched)
	  - every PollSeconds the stats of each player are sampled IN MEMORY: cash earned since last time, peak hamster count
	  - steals are recorded when the server confirms a completed theft (Events.TheftCompleted)
	  - amounts are kept per datastore name (metric x period-bucket) and written with UpdateAsync every FlushSeconds and when
	    the player leaves, only for stores that changed, only when the request budget allows
	  - first time a player appears in the ALL-TIME store, it is seeded from their saved lifetime stats (legit history)
	READ path (cached, single flight)
	  - GetSortedAsync(top PageSize) at most once per CacheSeconds per ranking per server, shared by every player and board
	  - results carry Status = "ok" | "empty" | "error" (stale rows are returned with "error" when we have them)
	Security: the client can only READ rankings; scores come from server-side stats and events, never from client numbers.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local Config = require(Modules.LeaderboardConfig)
local HamsterDatabase = require(Modules.HamsterDatabase)

local DataSystem = require(script.Parent.DataSystem)
local Events = require(script.Parent.Events)

local LeaderboardService = {}

-- unix time (overridable for tests)
LeaderboardService.clock = function(): number
	return os.time()
end

export type Row = { Rank: number, UserId: number, Name: string, Score: number }
export type Result = { Status: string, Rows: { Row }, UpdatedAt: number, Metric: string, Period: string, Note: string }

type Pending = {
	Sum: { [string]: number }, -- store name -> amount to add
	Peak: { [string]: number }, -- store name -> best value to write (max)
	Seed: { [string]: number }, -- store name -> value to use if the player has no entry yet (all-time backfill)
	LastCash: number?,
	LastFlush: number,
	Dirty: boolean,
}

local stores: { [string]: any } = {}
local pending: { [Player]: Pending } = {}
local cache: { [string]: { At: number, Result: Result } } = {}
local inflight: { [string]: boolean } = {}
local nameCache: { [number]: string } = {}
local meCache: { [string]: { At: number, Score: number } } = {}
local lastRequest: { [Player]: number } = {}

local function store(name: string)
	local existing = stores[name]
	if not existing then
		existing = DataStoreService:GetOrderedDataStore(name)
		stores[name] = existing
	end
	return existing
end

local function budgetOk(kind: string): boolean
	local ok, budget = pcall(function()
		return DataStoreService:GetRequestBudgetForRequestType((Enum.DataStoreRequestType :: any)[kind])
	end)
	return not ok or type(budget) ~= "number" or budget >= 2
end

local function clampScore(value: number): number
	if value ~= value then
		return 0
	end
	return math.floor(math.clamp(value, 0, Config.MaxScore))
end

---------------------------------------------------------------------------
-- stats of a player (server data only)
---------------------------------------------------------------------------

-- Hamsters the player legitimately owns: only registry hamsters with a positive whole count.
function LeaderboardService.hamsterCount(data: any): number
	local total = 0
	for speciesId, count in data.Inventory do
		if HamsterDatabase.ById[speciesId] and type(count) == "number" and count >= 1 and count % 1 == 0 then
			total += count
		end
	end
	return total
end

local function pendingOf(player: Player): Pending
	local entry = pending[player]
	if not entry then
		entry = { Sum = {}, Peak = {}, Seed = {}, LastCash = nil, LastFlush = os.clock(), Dirty = false }
		pending[player] = entry
	end
	return entry
end

local function addSum(player: Player, metric: string, amount: number)
	if amount <= 0 then
		return
	end
	local entry = pendingOf(player)
	local now = LeaderboardService.clock()
	for _, period in Config.Periods do
		local name = Config.storeName(metric, period, now)
		entry.Sum[name] = (entry.Sum[name] or 0) + amount
	end
	entry.Dirty = true
end

local function setPeak(player: Player, metric: string, value: number)
	if value <= 0 then
		return
	end
	local entry = pendingOf(player)
	local now = LeaderboardService.clock()
	for _, period in Config.Periods do
		local name = Config.storeName(metric, period, now)
		if (entry.Peak[name] or 0) < value then
			entry.Peak[name] = value
			entry.Dirty = true
		end
	end
end

-- Samples the player's stats (memory only).
local function sample(player: Player)
	local data = DataSystem.get(player)
	if not data or DataSystem.isTemporary(player) then
		return
	end
	local entry = pendingOf(player)
	local cash = data.Stats.CoinsEarned or 0
	if entry.LastCash == nil then
		entry.LastCash = cash -- earnings before this moment are covered by the all-time seed
	elseif cash > entry.LastCash then
		addSum(player, "Money", cash - entry.LastCash)
		entry.LastCash = cash
	elseif cash < entry.LastCash then
		entry.LastCash = cash -- the stat went DOWN (never expected): never subtract, just re-baseline
	end
	setPeak(player, "Hamsters", LeaderboardService.hamsterCount(data))
end

local function seed(player: Player)
	local data = DataSystem.get(player)
	if not data then
		return
	end
	local entry = pendingOf(player)
	local now = LeaderboardService.clock()
	entry.Seed[Config.storeName("Money", "AllTime", now)] = clampScore(data.Stats.CoinsEarned or 0)
	entry.Seed[Config.storeName("Steals", "AllTime", now)] = clampScore(data.Stats.Stolen or 0)
	entry.Seed[Config.storeName("Hamsters", "AllTime", now)] = clampScore(LeaderboardService.hamsterCount(data))
	entry.Dirty = true
end

---------------------------------------------------------------------------
-- writing
---------------------------------------------------------------------------

-- Writes the pending amounts of one player. Returns true when everything was written.
function LeaderboardService.flush(player: Player): boolean
	local entry = pending[player]
	if not entry then
		return true
	end
	sample(player)
	entry.LastFlush = os.clock()
	if not entry.Dirty then
		return true
	end
	local userKey = tostring(player.UserId)
	local allOk = true
	local function write(name: string, update: (number?) -> number?): boolean
		if not budgetOk("SetIncrementSortedAsync") then
			return false
		end
		local ok, err = pcall(function()
			store(name):UpdateAsync(userKey, update)
		end)
		if not ok then
			warn(string.format("[Leaderboard] write %s failed: %s", name, tostring(err)))
		end
		return ok
	end
	for name, amount in table.clone(entry.Sum) do
		local seedValue = entry.Seed[name]
		if write(name, function(old)
			return clampScore((old or seedValue or 0) + amount)
		end) then
			entry.Sum[name] = nil
			entry.Seed[name] = nil
		else
			allOk = false
		end
	end
	for name, value in table.clone(entry.Peak) do
		if write(name, function(old)
			return clampScore(math.max(old or 0, value))
		end) then
			entry.Peak[name] = nil
			entry.Seed[name] = nil
		else
			allOk = false
		end
	end
	-- seeds that were not needed by a delta: only create the entry if there is none yet
	for name, value in table.clone(entry.Seed) do
		if write(name, function(old)
			if old ~= nil then
				return nil
			end
			return if value > 0 then value else nil
		end) then
			entry.Seed[name] = nil
		else
			allOk = false
		end
	end
	entry.Dirty = not allOk
	return allOk
end

---------------------------------------------------------------------------
-- reading
---------------------------------------------------------------------------

local function nameOf(userId: number): string
	if nameCache[userId] then
		return nameCache[userId]
	end
	local online = Players:GetPlayerByUserId(userId)
	if online then
		nameCache[userId] = online.DisplayName
		return online.DisplayName
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	nameCache[userId] = if ok and type(name) == "string" then name else "Player"
	return nameCache[userId]
end

function LeaderboardService.fetch(metric: string, period: string, force: boolean?): Result
	local now = LeaderboardService.clock()
	local name = Config.storeName(metric, period, now)
	local cached = cache[name]
	if cached and not force and os.clock() - cached.At < Config.CacheSeconds then
		return cached.Result
	end
	-- single flight: another thread is already loading this ranking
	local waited = 0
	while inflight[name] and waited < 6 do
		task.wait(0.2)
		waited += 0.2
	end
	cached = cache[name]
	if cached and os.clock() - cached.At < Config.CacheSeconds and not force then
		return cached.Result
	end
	inflight[name] = true
	local result: Result = { Status = "error", Rows = {}, UpdatedAt = now, Metric = metric, Period = period, Note = Config.PeriodInfo[period].Note }
	local ok, err = pcall(function()
		if not budgetOk("GetSortedAsync") then
			error("request budget exhausted")
		end
		local pages = store(name):GetSortedAsync(false, Config.PageSize)
		local page = pages:GetCurrentPage()
		local rows: { Row } = {}
		for index, entry in page do
			local userId = tonumber(entry.key)
			if userId and type(entry.value) == "number" and entry.value > 0 then
				table.insert(rows, { Rank = index, UserId = userId, Name = "", Score = entry.value })
			end
		end
		-- names (cached; resolved in parallel with a short timeout)
		local remaining = 0
		for _, row in rows do
			if nameCache[row.UserId] then
				row.Name = nameCache[row.UserId]
			else
				remaining += 1
				task.spawn(function()
					row.Name = nameOf(row.UserId)
					remaining -= 1
				end)
			end
		end
		local waitedNames = 0
		while remaining > 0 and waitedNames < 3 do
			task.wait(0.1)
			waitedNames += 0.1
		end
		for _, row in rows do
			if row.Name == "" then
				row.Name = "Player"
			end
		end
		result.Rows = rows
		result.Status = if #rows == 0 then "empty" else "ok"
	end)
	inflight[name] = nil
	if not ok then
		warn(string.format("[Leaderboard] read %s failed: %s", name, tostring(err)))
		if cached then
			result.Rows = cached.Result.Rows -- show the last known ranking, flagged as error
		end
		result.Status = "error"
		cache[name] = { At = os.clock() - Config.CacheSeconds + 10, Result = result } -- retry in ~10 s, not every request
		return result
	end
	cache[name] = { At = os.clock(), Result = result }
	return result
end

-- The player's own score in a ranking (cached per player and ranking).
function LeaderboardService.myScore(player: Player, metric: string, period: string): number?
	local name = Config.storeName(metric, period, LeaderboardService.clock())
	local key = name .. ":" .. player.UserId
	local cached = meCache[key]
	if cached and os.clock() - cached.At < Config.CacheSeconds then
		return cached.Score
	end
	if not budgetOk("GetAsync") then
		return nil
	end
	local ok, value = pcall(function()
		return store(name):GetAsync(tostring(player.UserId))
	end)
	if not ok then
		return nil
	end
	-- plus what is still waiting to be written
	local entry = pending[player]
	local score = (value or 0)
	if entry then
		score += entry.Sum[name] or 0
		if entry.Peak[name] and entry.Peak[name] > score then
			score = entry.Peak[name]
		end
	end
	meCache[key] = { At = os.clock(), Score = score }
	return score
end

-- Request handler for the UI: validated input, per-player cooldown, extra info about the caller.
function LeaderboardService.request(player: Player, metric: any, period: any): (boolean, string, any?)
	if not Config.valid(metric, period) then
		return false, "Unknown leaderboard"
	end
	local clock = os.clock()
	if (lastRequest[player] or 0) + Config.RequestCooldown > clock then
		return false, "Slow down"
	end
	lastRequest[player] = clock
	local result = LeaderboardService.fetch(metric, period)
	local mine = nil
	for _, row in result.Rows do
		if row.UserId == player.UserId then
			mine = row.Rank
		end
	end
	return true, result.Status, { Result = result, MyRank = mine, MyScore = LeaderboardService.myScore(player, metric, period), UserId = player.UserId }
end

---------------------------------------------------------------------------
-- lifecycle
---------------------------------------------------------------------------

function LeaderboardService.onPlayerRemoving(player: Player)
	if pending[player] then
		LeaderboardService.flush(player)
	end
	pending[player] = nil
	lastRequest[player] = nil
end

---------------------------------------------------------------------------
-- the physical boards in the Leaderboard Hall
---------------------------------------------------------------------------

local boards: { any } = {}
local boardPeriod = 1
local RANK_COLORS = { "FFD24A", "D5DBE6", "E0955A" }

local function scoreText(metric: string, score: number): string
	return require(Modules.Format).short(score)
end

local function fillBoard(board: any, period: string)
	local info = Config.MetricInfo[board.Metric]
	local ok, result = pcall(LeaderboardService.fetch, board.Metric, period)
	board.Period.Text = Config.PeriodInfo[period].Note
	if not ok then
		result = { Status = "error", Rows = {} }
	end
	for index, label in board.Rows do
		local row = result.Rows[index]
		if row then
			local color = RANK_COLORS[index] or "C8CDE6"
			label.Text = string.format('<font color="#%s">%d.</font>  %s   <font color="#%s">%s</font>', color, row.Rank, row.Name, "FFD24A", scoreText(board.Metric, row.Score))
		elseif index == 1 and result.Status == "empty" then
			label.Text = '<font color="#A5ABCD">No scores yet - be the first!</font>'
		elseif index == 1 and result.Status == "error" then
			label.Text = '<font color="#FF8A8A">Rankings are unavailable right now</font>'
		else
			label.Text = ""
		end
	end
	board.Footer.Text = info.Description
end

function LeaderboardService.attachBoards(list: { any })
	boards = list or {}
	if #boards == 0 then
		return
	end
	task.spawn(function()
		while true do
			local period = Config.Periods[boardPeriod]
			for _, board in boards do
				local ok, err = pcall(fillBoard, board, period)
				if not ok then
					warn("[Leaderboard] board update failed: " .. tostring(err))
				end
			end
			boardPeriod = boardPeriod % #Config.Periods + 1
			task.wait(Config.BoardCycleSeconds)
		end
	end)
end

function LeaderboardService.start()
	Events.ProfileLoaded:Connect(function(player)
		seed(player)
		sample(player)
	end)
	Events.TheftCompleted:Connect(function(thief)
		addSum(thief, "Steals", 1)
	end)
	task.spawn(function()
		while true do
			task.wait(Config.PollSeconds)
			for _, player in Players:GetPlayers() do
				local ok, err = pcall(function()
					sample(player)
					local entry = pending[player]
					if entry and entry.Dirty and os.clock() - entry.LastFlush >= Config.FlushSeconds then
						LeaderboardService.flush(player)
					end
				end)
				if not ok then
					warn("[Leaderboard] " .. tostring(err))
				end
			end
		end
	end)
end

return LeaderboardService
