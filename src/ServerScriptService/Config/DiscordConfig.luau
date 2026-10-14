--[[
	DiscordConfig: the Discord log (a webhook that posts important server events into a Discord channel).
	This module is in ServerScriptService, so players can never read it. STILL: never put the webhook URL in a script that is
	committed to a public GitHub repository.

	=========================  HOW TO SET IT UP (about 3 minutes)  =========================
	1. Discord: channel settings -> Integrations -> Webhooks -> New Webhook -> Copy Webhook URL.
	2. Roblox Studio: Home -> Game Settings -> Security -> turn on "Allow HTTP Requests".
	3. Studio: Explorer -> ServerStorage -> Insert Object -> StringValue, name it exactly  DiscordWebhookUrl ,
	   paste the webhook URL into its Value. (ServerStorage is never sent to players. This value lives in your place file in
	   Studio and is NOT in the GitHub repository, so the secret never reaches the repo. Do not commit a saved .rbxl that contains it.)
	4. Set  Enabled = true  below, publish, and press "Send Discord test message" in the admin panel (tab Logs).

	Alternative for a PRIVATE repository only: paste the URL into WebhookUrl below. The StringValue wins when both exist.

	If a test says HTTP 403 / blocked: Discord may refuse requests that come straight from Roblox servers. Then you need a relay
	that forwards to Discord (your own small proxy, or a relay service you trust): put the RELAY's URL in the StringValue instead
	(it is treated exactly like a webhook URL) and add its host to AllowedHosts. Nothing is invented here: the relay is the one
	external piece that may be needed, and it receives every log line, so only use one you control or trust.
]]

local DiscordConfig = {}

DiscordConfig.Enabled = false -- master switch (also false while the URL is missing)
DiscordConfig.SendInStudio = false -- false = nothing is sent from a Studio test session (the admin test button still works)
DiscordConfig.WebhookUrl = "" -- leave empty and use the ServerStorage StringValue (see above)
DiscordConfig.UrlValueName = "DiscordWebhookUrl"
DiscordConfig.AllowedHosts = { "discord.com", "discordapp.com", "ptb.discord.com", "canary.discord.com" } -- add your relay host here
DiscordConfig.BotName = "Hamster Plaza Log"

-- Which things are logged. Ordinary gameplay is NOT logged on purpose (it would flood the channel).
DiscordConfig.Events = {
	ServerStart = true,
	ServerStop = true,
	PlayerJoin = false, -- every join (noisy; staff joins are always listed when StaffJoin is true)
	PlayerLeave = false,
	StaffJoin = true,
	Admin = true, -- settings, shop prices, announcements, safe tools, log views
	Roles = true, -- roles created / edited / deleted, staff given or removed
	Moderation = true, -- warn, kick, ban, unban
	Economy = true, -- cash / diamonds / rebirth / items / hamsters granted or removed by staff
	Purchase = true, -- Game Pass granted, developer product granted (no payment details)
	WheelRare = true, -- jackpot and other rare Lucky Wheel results (see WheelRarePrizes)
	Error = true, -- serious server errors (rate limited)
}

DiscordConfig.WheelRarePrizes = { jackpot = true, cash_big = true, hamster = false }
DiscordConfig.ErrorsPerMinute = 4 -- at most this many error lines per minute reach Discord
DiscordConfig.MinSecondsBetweenMessages = 2.2 -- stays below Discord's rate limits (5 requests / 2 s per webhook)
DiscordConfig.MaxQueue = 80 -- older lines are dropped when Discord is unreachable for long
DiscordConfig.MaxRetries = 3 -- per message, for timeouts and 5xx answers

return DiscordConfig
