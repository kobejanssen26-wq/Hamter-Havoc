--[[
	DiscordLog: posts important server events to a Discord webhook (see Config/DiscordConfig for the setup).

	Safety
	  * The URL is read on the server only (ServerStorage value or DiscordConfig) and is never put in a log, a warning, an error
	    message or a reply to a player: everything that could contain it goes through redact().
	  * Logging can never stall or crash the game: log() only appends to a bounded queue; one background thread sends, every
	    HTTP call is in a pcall, nothing waits for Discord.
	Reliability
	  * One request carries up to 10 embeds; requests are at least MinSecondsBetweenMessages apart.
	  * 429 (rate limited): waits the time Discord asks (capped) and sends the same batch again.
	  * Timeouts / 5xx: retried with a growing pause, MaxRetries times, then the batch is dropped.
	  * 400 / 401 / 403 / 404: the webhook or relay is wrong or blocked: the batch is dropped, logging pauses for 5 minutes and
	    one clear warning (without the URL) is printed.
	  * Embeds are cut to Discord's limits. allowed_mentions is empty, so a player name can never ping @everyone.
]]

local HttpService = game:GetService("HttpService")
local LogService = game:GetService("LogService")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local DiscordConfig = require(script.Parent.Parent.Config.DiscordConfig)

local DiscordLog = {}

type Embed = { title: string, description: string?, color: number, fields: { any }?, timestamp: string, footer: { text: string }? }

local COLORS = {
	Info = 0x5DADE2, Good = 0x58D68D, Warn = 0xF4D03F, Bad = 0xEC7063, Purple = 0xAF7AC5, Gold = 0xF5B041,
}

local queue: { Embed } = {}
local sending = false
local epoch = 0 -- reset() (tests) bumps it so an old sender thread stops
local pausedUntil = 0
local lastSent = 0
local warned: { [string]: boolean } = {}
local errorWindow: { number } = {}
local stats = { Sent = 0, Dropped = 0, Failed = 0, LastStatus = 0 }
DiscordLog.Stats = stats

---------------------------------------------------------------------------
-- configuration (the URL never leaves this module)
---------------------------------------------------------------------------

local function rawUrl(): string?
	local holder = ServerStorage:FindFirstChild(DiscordConfig.UrlValueName)
	if holder and holder:IsA("StringValue") and holder.Value ~= "" then
		return holder.Value
	end
	if type(DiscordConfig.WebhookUrl) == "string" and DiscordConfig.WebhookUrl ~= "" then
		return DiscordConfig.WebhookUrl
	end
	return nil
end

local function hostOf(url: string): string?
	return string.match(url, "^https://([%w%.%-]+)[/:]") or string.match(url, "^https://([%w%.%-]+)$")
end

-- Is there a usable webhook? Returns (ok, reason-without-the-url).
function DiscordLog.configured(): (boolean, string?)
	if not DiscordConfig.Enabled then
		return false, "Discord logging is switched off (DiscordConfig.Enabled = false)"
	end
	local url = rawUrl()
	if not url then
		return false, "no webhook URL: add a StringValue named " .. DiscordConfig.UrlValueName .. " to ServerStorage (see DiscordConfig)"
	end
	local host = hostOf(url)
	if not host then
		return false, "the webhook URL does not look like an https address"
	end
	local allowed = false
	for _, entry in DiscordConfig.AllowedHosts do
		if host == entry then
			allowed = true
		end
	end
	if not allowed then
		return false, "the webhook host is not in DiscordConfig.AllowedHosts"
	end
	return true, nil
end

-- Removes anything that looks like (or is) the webhook URL from a text.
local function redact(text: any): string
	local value = tostring(text)
	local url = rawUrl()
	if url and #url > 8 then
		value = string.gsub(value, url:gsub("%p", "%%%0"), "<webhook>")
	end
	value = string.gsub(value, "https://[%w%.%-]*discord[%w%.%-]*/api/webhooks/%S+", "<webhook>")
	return value
end
DiscordLog.redact = redact

local function warnOnce(key: string, message: string)
	if not warned[key] then
		warned[key] = true
		warn("[Discord] " .. redact(message))
	end
end

---------------------------------------------------------------------------
-- building messages
---------------------------------------------------------------------------

local function cut(text: any, limit: number): string
	local value = tostring(text)
	-- keep control characters out and stay within Discord's limits
	value = string.gsub(value, "[%c]", " ")
	if #value > limit then
		value = string.sub(value, 1, limit - 3) .. "..."
	end
	return if value == "" then "-" else value
end

local function embed(title: string, color: number, fields: { { Name: string, Value: any, Inline: boolean? } }?, description: string?): Embed
	local list = {}
	if fields then
		for index, field in fields do
			if index > 12 then
				break
			end
			table.insert(list, { name = cut(field.Name, 120), value = cut(field.Value, 400), inline = field.Inline == true })
		end
	end
	return {
		title = cut(title, 200),
		description = if description then cut(description, 600) else nil,
		color = color,
		fields = list,
		timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
		footer = { text = cut("Server " .. string.sub(game.JobId ~= "" and game.JobId or "studio", 1, 8) .. " - place " .. tostring(game.PlaceId), 100) },
	}
end

local function who(player: Player): string
	return string.format("%s (%d)", player.Name, player.UserId)
end

local function enabledFor(category: string): boolean
	if not DiscordConfig.Events[category] then
		return false
	end
	if RunService:IsStudio() and not DiscordConfig.SendInStudio then
		return false
	end
	local ok = DiscordLog.configured()
	return ok
end

---------------------------------------------------------------------------
-- sending
---------------------------------------------------------------------------

local function payload(embeds: { Embed }): string
	return HttpService:JSONEncode({
		username = DiscordConfig.BotName,
		allowed_mentions = { parse = {} },
		embeds = embeds,
	})
end

-- One HTTP attempt. Returns (status, retryAfterSeconds?, errorText?). status 0 = no answer.
local function post(embeds: { Embed }): (number, number?, string?)
	local url = rawUrl()
	if not url then
		return 0, nil, "no url"
	end
	local ok, response = pcall(function()
		return HttpService:RequestAsync({
			Url = url,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = payload(embeds),
		})
	end)
	if not ok then
		return 0, nil, redact(response)
	end
	local retry: number? = nil
	if response.StatusCode == 429 then
		local parsed, body = pcall(function()
			return HttpService:JSONDecode(response.Body)
		end)
		local seconds: number = if parsed and type(body) == "table" and type(body.retry_after) == "number" then body.retry_after else 2
		if seconds > 100 then
			seconds = seconds / 1000 -- (some answers are in milliseconds)
		end
		retry = seconds
	end
	return response.StatusCode, retry, nil
end

local function drain()
	if sending then
		return
	end
	sending = true
	local mine = epoch
	task.spawn(function()
		while #queue > 0 and mine == epoch do
			local wait = math.max(DiscordConfig.MinSecondsBetweenMessages - (os.clock() - lastSent), pausedUntil - os.clock(), 0)
			if wait > 0 then
				task.wait(wait)
			end
			if mine ~= epoch then
				return
			end
			local batch = {}
			while #queue > 0 and #batch < 10 do
				local item = table.remove(queue, 1)
				if item then
					table.insert(batch, item)
				end
			end
			local attempts, done = 0, false
			while not done and mine == epoch do
				attempts += 1
				lastSent = os.clock()
				local status, retryAfter, problem = post(batch)
				stats.LastStatus = status
				if status >= 200 and status < 300 then
					stats.Sent += #batch
					done = true
				elseif status == 429 then
					task.wait(math.clamp(retryAfter or 2, 0.5, 30))
					if attempts >= DiscordConfig.MaxRetries + 2 then
						stats.Dropped += #batch
						done = true
					end
				elseif status == 400 or status == 401 or status == 403 or status == 404 then
					-- wrong, deleted or blocked webhook: do not hammer it
					stats.Failed += 1
					stats.Dropped += #batch
					pausedUntil = os.clock() + 300
					warnOnce("rejected" .. status, string.format("Discord rejected the webhook (HTTP %d). Check the URL / that the webhook still exists; HTTP 403 can mean Discord blocks Roblox servers (use a relay, see DiscordConfig). Logging pauses for 5 minutes.", status))
					done = true
				else
					-- no answer, timeout or 5xx
					stats.Failed += 1
					if attempts > DiscordConfig.MaxRetries then
						stats.Dropped += #batch
						warnOnce("unreachable", "Discord could not be reached (" .. tostring(problem or ("HTTP " .. status)) .. "). Messages are dropped after " .. DiscordConfig.MaxRetries .. " tries.")
						done = true
					else
						task.wait(2 ^ attempts)
					end
				end
			end
		end
		if mine == epoch then
			sending = false
		end
	end)
end

local function push(message: Embed)
	table.insert(queue, message)
	while #queue > DiscordConfig.MaxQueue do
		table.remove(queue, 1)
		stats.Dropped += 1
	end
	drain()
end

---------------------------------------------------------------------------
-- public events
---------------------------------------------------------------------------

-- Generic: category (a key of DiscordConfig.Events), title, fields. Does nothing when that category is off.
function DiscordLog.log(category: string, title: string, fields: { { Name: string, Value: any, Inline: boolean? } }?, color: number?, description: string?)
	if not enabledFor(category) then
		return
	end
	local ok, problem = pcall(function()
		push(embed(title, color or COLORS.Info, fields, description))
	end)
	if not ok then
		warn("[Discord] could not queue a message: " .. redact(problem))
	end
end

local MODERATION = { warn = true, kick = true, ban = true, unban = true }
local ROLES = { setStaff = true, saveRole = true, deleteRole = true }
local ECONOMY = { giveCash = true, giveDiamonds = true, setRebirths = true, grantItem = true, revokeItem = true, giveHamster = true, cash = true, diamonds = true, rebirths = true }

-- Called by AdminSystem for every staff action (its audit entry).
function DiscordLog.fromAudit(entry: any)
	local category = if MODERATION[entry.Action] then "Moderation" elseif ROLES[entry.Action] then "Roles" elseif ECONOMY[entry.Action] then "Economy" else "Admin"
	local color = if category == "Moderation" then COLORS.Bad elseif category == "Roles" then COLORS.Purple elseif category == "Economy" then COLORS.Gold else COLORS.Info
	if entry.Action == "DENIED" then
		color = COLORS.Warn
	end
	DiscordLog.log(category, string.format("%s: %s", category, tostring(entry.Action)), {
		{ Name = "Staff", Value = string.format("%s (%s) - %s", tostring(entry.AdminName), tostring(entry.AdminId), tostring(entry.Role)), Inline = true },
		{ Name = "Target", Value = if entry.TargetId then tostring(entry.TargetId) else "-", Inline = true },
		{ Name = "Detail", Value = entry.Detail },
		{ Name = "Reason", Value = if entry.Reason ~= "" then entry.Reason else "-" },
	}, color)
end

function DiscordLog.playerJoined(player: Player, staffRole: string?)
	if staffRole and DiscordConfig.Events.StaffJoin then
		DiscordLog.log("StaffJoin", "Staff joined", { { Name = "Player", Value = who(player), Inline = true }, { Name = "Role", Value = staffRole, Inline = true } }, COLORS.Purple)
	end
	DiscordLog.log("PlayerJoin", "Player joined", { { Name = "Player", Value = who(player) } }, COLORS.Good)
end

function DiscordLog.playerLeft(player: Player)
	DiscordLog.log("PlayerLeave", "Player left", { { Name = "Player", Value = who(player) } }, COLORS.Warn)
end

function DiscordLog.purchase(player: Player, kind: string, name: string, outcome: string)
	DiscordLog.log("Purchase", "Purchase: " .. outcome, {
		{ Name = "Player", Value = who(player), Inline = true },
		{ Name = "Type", Value = kind, Inline = true },
		{ Name = "Item", Value = name },
	}, if outcome == "granted" then COLORS.Good else COLORS.Warn)
end

function DiscordLog.wheel(player: Player, prizeId: string, lines: { string })
	if not DiscordConfig.WheelRarePrizes[prizeId] then
		return
	end
	DiscordLog.log("WheelRare", "Lucky Wheel: " .. prizeId, { { Name = "Player", Value = who(player), Inline = true }, { Name = "Won", Value = table.concat(lines, ", ") } }, COLORS.Gold)
end

---------------------------------------------------------------------------
-- admin test (really sends, reports the real answer, never shows the URL)
---------------------------------------------------------------------------

function DiscordLog.sendTest(staffName: string): (boolean, string)
	local ok, reason = DiscordLog.configured()
	if not ok then
		return false, reason or "not configured"
	end
	if not HttpService.HttpEnabled then
		return false, "HTTP requests are off: Studio -> Home -> Game Settings -> Security -> Allow HTTP Requests"
	end
	local status, retryAfter, problem = post({ embed("Test message", COLORS.Good, { { Name = "Sent by", Value = staffName } }, "If you can read this, the Discord log works.") })
	if status >= 200 and status < 300 then
		return true, "Discord accepted the test message (HTTP " .. status .. ")"
	elseif status == 429 then
		return false, string.format("Discord says: slow down (HTTP 429, retry in %ds)", math.ceil(retryAfter or 2))
	elseif status == 0 then
		return false, "no answer from Discord: " .. tostring(problem)
	end
	return false, string.format("Discord answered HTTP %d%s", status, if status == 403 then " (blocked: Discord may refuse Roblox servers, see DiscordConfig: relay)" elseif status == 404 then " (the webhook does not exist any more)" else "")
end

function DiscordLog.status(): string
	local ok, reason = DiscordLog.configured()
	return string.format("%s | HTTP %s | queue %d | sent %d | dropped %d", if ok then "configured" else tostring(reason), if HttpService.HttpEnabled then "on" else "OFF", #queue, stats.Sent, stats.Dropped)
end

---------------------------------------------------------------------------
-- lifecycle
---------------------------------------------------------------------------

local function onMessage(message: string, messageType: Enum.MessageType)
	if messageType ~= Enum.MessageType.MessageError or not DiscordConfig.Events.Error then
		return
	end
	if string.find(message, "[Discord]", 1, true) then
		return -- never log our own problems (no loops)
	end
	local now = os.clock()
	while #errorWindow > 0 and now - errorWindow[1] > 60 do
		table.remove(errorWindow, 1)
	end
	if #errorWindow >= DiscordConfig.ErrorsPerMinute then
		return
	end
	table.insert(errorWindow, now)
	DiscordLog.log("Error", "Server error", { { Name = "Message", Value = redact(message) } }, COLORS.Bad)
end

function DiscordLog.start()
	local ok, reason = DiscordLog.configured()
	if DiscordConfig.Enabled and not ok then
		warn("[Discord] logging is enabled but not usable: " .. tostring(reason))
	end
	if DiscordConfig.Enabled and ok and not HttpService.HttpEnabled then
		warn("[Discord] HTTP requests are off: Studio -> Home -> Game Settings -> Security -> Allow HTTP Requests")
	end
	LogService.MessageOut:Connect(onMessage)
	game:BindToClose(function()
		DiscordLog.log("ServerStop", "Server shutting down", { { Name = "Players", Value = #game:GetService("Players"):GetPlayers() } }, COLORS.Warn)
		-- give the sender a few seconds to flush (BindToClose may wait up to 30 s; we take at most 5)
		local waited = 0
		while (#queue > 0 or sending) and waited < 5 do
			task.wait(0.25)
			waited += 0.25
		end
	end)
	DiscordLog.log("ServerStart", "Server started", { { Name = "Place version", Value = tostring(game.PlaceVersion) } }, COLORS.Good)
end

-- (for tests) clears the queue and counters
function DiscordLog.reset()
	epoch += 1
	sending = false
	table.clear(queue)
	table.clear(errorWindow)
	table.clear(warned)
	stats.Sent, stats.Dropped, stats.Failed, stats.LastStatus = 0, 0, 0, 0
	pausedUntil = 0
	lastSent = 0
end

return DiscordLog
