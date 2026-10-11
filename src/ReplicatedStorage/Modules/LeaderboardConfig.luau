--[[
	Leaderboards: what is ranked, over which periods, and the rules (shared by the server service, the UI and the boards).

	METRICS
	  Hamsters  Most hamsters: the PEAK number of hamsters a player owned at one time during the period (stored +
	            equipped, only valid registry hamsters). A peak (not "now") so a rebirth reset does not erase a ranking.
	  Steals    Most steals: hamsters a player really stole - rack thefts and stolen balls that reached their own pad.
	            Failed attempts never count.
	  Money     Most money: LIFETIME CASH EARNED during the period (spending never lowers it; diamonds are not mixed in).

	PERIODS (all UTC)
	  Weekly    Monday 00:00 -> next Monday 00:00
	  Monthly   the calendar month
	  Yearly    the calendar year
	  AllTime   never resets
	Each period is its own OrderedDataStore ("LB_v1_<Metric>_<PeriodKey>"), so a new week/month/year starts empty
	without touching any other period. Old periods stay in the datastore (nothing is deleted).
]]

local LeaderboardConfig = {}

LeaderboardConfig.Version = "v1"
LeaderboardConfig.Metrics = { "Hamsters", "Steals", "Money" }
LeaderboardConfig.MetricInfo = {
	Hamsters = { Name = "Most Hamsters", Short = "Hamsters", Mode = "Peak", Icon = "hamster", Description = "Most hamsters owned at one time" },
	Steals = { Name = "Most Steals", Short = "Steals", Mode = "Sum", Icon = "shield", Description = "Hamsters successfully stolen (failed thefts don't count)" },
	Money = { Name = "Most Money", Short = "Cash", Mode = "Sum", Icon = "coin", Description = "Total cash earned (spending never lowers it)" },
}
LeaderboardConfig.Periods = { "Weekly", "Monthly", "Yearly", "AllTime" }
LeaderboardConfig.PeriodInfo = {
	Weekly = { Name = "Weekly", Note = "This week (Mon-Sun, UTC)" },
	Monthly = { Name = "Monthly", Note = "This calendar month (UTC)" },
	Yearly = { Name = "Yearly", Note = "This calendar year (UTC)" },
	AllTime = { Name = "All-time", Note = "Since the leaderboards started" },
}

LeaderboardConfig.PageSize = 50 -- rows fetched per ranking (the UI shows the top 25, boards the top 10)
LeaderboardConfig.CacheSeconds = 60 -- a ranking is fetched at most once per minute per server
LeaderboardConfig.FlushSeconds = 120 -- pending scores of a player are written at most this often (and when they leave)
LeaderboardConfig.PollSeconds = 15 -- how often player stats are sampled (memory only, no datastore calls)
LeaderboardConfig.RequestCooldown = 1 -- per player, for the Leaderboard request
LeaderboardConfig.MaxScore = 1e15
LeaderboardConfig.BoardRows = 10
LeaderboardConfig.BoardCycleSeconds = 30 -- the physical boards show the next period every N seconds

local function dayOf(t: number): number
	return math.floor(t / 86400)
end

-- The store key suffix of `period` at unix time `t`.
function LeaderboardConfig.periodKey(period: string, t: number): string
	if period == "Weekly" then
		return "W" .. math.floor((dayOf(t) + 3) / 7)
	elseif period == "Monthly" then
		local d = os.date("!*t", t)
		return string.format("M%04d%02d", d.year, d.month)
	elseif period == "Yearly" then
		return "Y" .. os.date("!*t", t).year
	end
	return "A"
end

function LeaderboardConfig.storeName(metric: string, period: string, t: number): string
	return string.format("LB_%s_%s_%s", LeaderboardConfig.Version, metric, LeaderboardConfig.periodKey(period, t))
end

function LeaderboardConfig.valid(metric: any, period: any): boolean
	return type(metric) == "string" and type(period) == "string" and LeaderboardConfig.MetricInfo[metric] ~= nil and LeaderboardConfig.PeriodInfo[period] ~= nil
end

return LeaderboardConfig
