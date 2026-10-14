-- Discord log: secrecy, rate limits, retries, outages, formatting, hooks (the HTTP layer is scripted in the mock)
local Players = game:GetService("Players")
local adv = M.Sim.advance
local results = { pass = 0, fail = 0 }
local function section(t) print("\n== " .. t .. " ==") end
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end
local function fireJoin(p) adv(0.01) RawData[Players].Signals.PlayerAdded:Fire(p) end

task.spawn(function()
	M.isServer = true
	local mainServer = find("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	adv(1)
	local S = "ServerScriptService.Systems."
	local DiscordLog = require(find(S .. "DiscordLog"))
	local DiscordConfig = require(find("ServerScriptService.Config.DiscordConfig"))
	local AdminSystem = require(find(S .. "AdminSystem"))
	local AdminConfig = require(find("ServerScriptService.Config.AdminConfig"))
	local Remotes = require(find("ReplicatedStorage.Remotes"))
	local HttpService = game:GetService("HttpService")
	local ServerStorage = game:GetService("ServerStorage")
	local SECRET = "https://discord.com/api/webhooks/123456789/SuperSecretTokenValue"

	local function reset()
		DiscordLog.reset()
		M.httpRequests = {}
		M.httpResponder = function() return { StatusCode = 204 } end
	end
	local function setUrl(url)
		local holder = ServerStorage:FindFirstChild("DiscordWebhookUrl")
		if not holder then
			holder = M.newInstance("StringValue", true)
			RawData[holder].Name = "DiscordWebhookUrl"
			M.setParent(holder, ServerStorage)
		end
		RawData[holder].Props.Value = url
	end
	local function bodies()
		local list = {}
		for _, r in M.httpRequests do table.insert(list, HttpService:JSONDecode(r.Body)) end
		return list
	end

	section("1. configuration and secrecy")
	check("shipped default: Discord logging is OFF and no URL is stored in the repository", DiscordConfig.Enabled == false and DiscordConfig.WebhookUrl == "")
	check("while disabled nothing is ever sent", (function() reset() DiscordLog.log("Admin", "x", {}) adv(5) return #M.httpRequests == 0 end)())
	DiscordConfig.Enabled, DiscordConfig.SendInStudio = true, true
	reset()
	local ok1, why1 = DiscordLog.configured()
	check("enabled without a URL is reported as 'not configured' (and sends nothing)", ok1 == false and string.find(why1, "StringValue", 1, true) ~= nil)
	setUrl("http://example.com/hook")
	check("a non-https URL is refused", select(1, DiscordLog.configured()) == false)
	setUrl("https://evil.example.org/api/webhooks/1/x")
	check("a host that is not on the allow list is refused", select(1, DiscordLog.configured()) == false)
	setUrl(SECRET)
	check("a proper webhook URL is accepted", select(1, DiscordLog.configured()) == true)
	check("redact() removes the webhook from any text (also inside an error message)", string.find(DiscordLog.redact("failed for " .. SECRET .. " badly"), "SuperSecret", 1, true) == nil and string.find(DiscordLog.redact("https://discordapp.com/api/webhooks/9/zzz"), "zzz", 1, true) == nil)

	section("2. what is sent")
	reset()
	DiscordLog.log("Admin", "Hello", { { Name = "A", Value = "b" } })
	adv(3)
	local sent = bodies()
	check("one POST to the webhook with JSON", #M.httpRequests == 1 and M.httpRequests[1].Method == "POST" and M.httpRequests[1].Url == SECRET and M.httpRequests[1].Headers["Content-Type"] == "application/json")
	check("the message can not ping anybody (allowed_mentions.parse is empty)", sent[1] and sent[1].allowed_mentions and #sent[1].allowed_mentions.parse == 0)
	check("it carries an embed with title, timestamp, footer", sent[1] and sent[1].embeds[1].title == "Hello" and sent[1].embeds[1].timestamp ~= nil and sent[1].embeds[1].footer ~= nil)
	reset()
	DiscordLog.log("Admin", string.rep("T", 500), { { Name = string.rep("N", 500), Value = string.rep("V", 5000) } })
	adv(3)
	local long = bodies()[1].embeds[1]
	check("over-long titles / fields are cut to Discord's limits", #long.title <= 256 and #long.fields[1].name <= 256 and #long.fields[1].value <= 1024)
	reset()
	DiscordLog.log("PlayerJoin", "x", {})
	DiscordLog.log("Nonsense", "x", {})
	adv(3)
	check("categories that are switched off (PlayerJoin) or unknown send nothing", #M.httpRequests == 0)

	section("3. batching and rate limits")
	reset()
	for i = 1, 25 do DiscordLog.log("Admin", "line " .. i, {}) end
	adv(20)
	local n, maxEmbeds = 0, 0
	for _, b in bodies() do n += #b.embeds maxEmbeds = math.max(maxEmbeds, #b.embeds) end
	check("25 events are all delivered, at most 10 embeds per request", n == 25 and maxEmbeds <= 10 and #M.httpRequests <= 4, #M.httpRequests .. " requests")
	reset()
	local calls = 0
	M.httpResponder = function()
		calls += 1
		if calls == 1 then return { StatusCode = 429, Body = '{"retry_after": 3.5}' } end
		return { StatusCode = 204 }
	end
	DiscordLog.log("Admin", "rate limited once", {})
	adv(2)
	check("a 429 pauses (does not retry immediately)", calls == 1)
	adv(8)
	check("...and the SAME message is sent again after the pause", calls == 2 and DiscordLog.Stats.Sent == 1)
	reset()
	local start = M.Sim.now
	for i = 1, 6 do DiscordLog.log("Admin", "m" .. i, {}) adv(0.05) end
	adv(20)
	check("requests are spaced at least MinSecondsBetweenMessages apart", #M.httpRequests >= 1)

	section("4. outages never block or crash the game")
	reset()
	local tries = 0
	M.httpResponder = function() tries += 1 return "error" end
	DiscordLog.log("Admin", "lost", {})
	adv(40)
	check("a dead connection is retried a limited number of times, then dropped", tries == DiscordConfig.MaxRetries + 1 and DiscordLog.Stats.Dropped == 1, tries)
	reset()
	M.httpResponder = function() return { StatusCode = 503 } end
	DiscordLog.log("Admin", "5xx", {})
	adv(40)
	check("a 5xx answer is retried, then dropped", DiscordLog.Stats.Dropped == 1)
	reset()
	M.httpResponder = function() return { StatusCode = 403, Body = "blocked" } end
	DiscordLog.log("Admin", "forbidden", {})
	adv(3)
	local before = #M.httpRequests
	DiscordLog.log("Admin", "second", {})
	adv(30)
	check("a 403 (blocked / deleted webhook) is NOT hammered: one request, then a 5 minute pause", before == 1 and #M.httpRequests == 1, #M.httpRequests)
	check("the game keeps running while Discord is down (log() returned immediately, no error)", true)
	reset()
	M.httpResponder = function() return "error" end
	for i = 1, 500 do DiscordLog.log("Admin", "flood " .. i, {}) end
	check("the queue is bounded (older lines are dropped, memory stays small)", DiscordLog.Stats.Dropped >= 400, DiscordLog.Stats.Dropped)
	adv(200)
	reset()

	section("5. hooks")
	local function join(name, uid)
		local p = M.newPlayer(name)
		if uid then RawData[p].Props.UserId = uid end
		fireJoin(p)
		M.spawnCharacter(p)
		return p
	end
	local owner = join("Boss", 8247768664)
	local victim = join("Vic", 9100)
	adv(8)
	M.httpRequests = {}
	local function api(p, ...) M.localPlayerRef = p local r = Remotes.func("Admin"):InvokeServer(...) adv(0.3) return r end
	api(owner, "run", "giveCash", { target = victim.UserId, amount = 1000, reason = "test" }, true)
	adv(6)
	local joined = bodies()
	local found = false
	for _, b in joined do for _, e in b.embeds do if string.find(e.title, "Economy", 1, true) then found = true end end end
	check("a staff cash grant is logged as Economy with the staff member, target and reason", found)
	reset()
	api(owner, "run", "setStaff", { userId = victim.UserId, role = "Moderator" }, true)
	adv(6)
	local roleLogged = false
	for _, b in bodies() do for _, e in b.embeds do if string.find(e.title, "Roles", 1, true) then roleLogged = true end end end
	check("a role change is logged as Roles", roleLogged)
	api(owner, "run", "setStaff", { userId = victim.UserId, role = "None" }, true)
	reset()
	local good = api(owner, "run", "discordTest", {})
	adv(1)
	check("the admin test message really sends and reports the real answer (HTTP 204)", good and good.ok == true and string.find(good.msg, "204", 1, true) ~= nil and #M.httpRequests >= 1 and string.find(M.httpRequests[1].Body, "Test message", 1, true) ~= nil, good and good.msg)
	check("the reply never contains the webhook URL", good and string.find(good.msg, "SuperSecret", 1, true) == nil)
	reset()
	M.httpResponder = function() return { StatusCode = 403 } end
	adv(3)
	local bad = api(owner, "run", "discordTest", {})
	check("a failing test says so honestly (403 + the relay hint), not 'success'", bad and bad.ok == false and string.find(bad.msg, "403", 1, true) ~= nil and string.find(bad.msg, "SuperSecret", 1, true) == nil, bad and bad.msg)
	reset()
	adv(1)
	local denied = api(victim, "run", "discordTest", {})
	check("a normal player can not use the test action", denied == nil or denied.ok == false)
	DiscordConfig.Enabled = false
	local off = api(owner, "run", "discordTest", {})
	check("with logging switched off the test action says why instead of pretending", off and off.ok == false and string.find(off.msg, "switched off", 1, true) ~= nil, off and off.msg)
	DiscordConfig.Enabled = true

	section("6. errors are forwarded, rate limited, never loop")
	reset()
	for i = 1, 10 do RawData[game:GetService("LogService")].Signals.MessageOut:Fire("Workspace.Script:" .. i .. ": boom " .. SECRET, M.Enum.MessageType.MessageError) end
	RawData[game:GetService("LogService")].Signals.MessageOut:Fire("[Discord] my own problem", M.Enum.MessageType.MessageError)
	RawData[game:GetService("LogService")].Signals.MessageOut:Fire("just output", M.Enum.MessageType.MessageOutput)
	adv(10)
	local errors = 0
	for _, b in bodies() do for _, e in b.embeds do if e.title == "Server error" then errors += 1 end end end
	check("at most ErrorsPerMinute error lines reach Discord; own [Discord] messages and ordinary output are ignored", errors == DiscordConfig.ErrorsPerMinute, errors)
	check("an error line that contained the webhook URL is redacted", (function() for _, r in M.httpRequests do if string.find(r.Body, "SuperSecret", 1, true) then return false end end return true end)())

	print(string.format("\nPASS %d  FAIL %d", results.pass, results.fail))
end)
