--[[
	AdminConfig: WHO may use the admin panel and WHAT each role may do.
	This module lives on the SERVER only (ServerScriptService): players can never read this list.

	=========================  1. PUT YOUR OWN ROBLOX USER ID HERE  =========================
	Your UserId is the number in your profile link:  roblox.com/users/  <<< 123456789 >>>  /profile
	Replace the 0 below. Nothing else is needed to become Owner.
]]

local AdminConfig = {}

AdminConfig.OwnerUserIds = {
	8247768664, -- main owner: can do everything and can not be kicked, banned or changed by anybody
}

-- true = also treat the person who owns the experience (game.CreatorId) as Owner. Off, so ONLY the ids listed here count.
AdminConfig.CreatorIsOwner = false

--[[
	=========================  2. OTHER STAFF  =========================
	[UserId] = "CoOwner" | "Admin" | "Moderator" | "Developer"
	Names do not matter and are never used for permission - only the number counts.
]]
AdminConfig.Users = {
	[7426751118] = "CoOwner", -- every permission, but can not kick / ban / change the main Owner above
	-- [11111111] = "Admin",
	-- [22222222] = "Moderator",
	-- [33333333] = "Developer",
}

--[[
	=========================  3. WHAT EACH ROLE MAY DO  =========================
	Permission names (used by the commands in AdminSystem.luau):
	  Panel      open the panel at all                 Inspect    look at a player's progress
	  Warn       warn a player                         ServerInfo basic server numbers
	  Kick       kick a player                         Announce   message to everybody
	  History    read a player's moderation history    SafeTools  harmless test tools (clear stun / freeze)
	  BanTemp    temporary ban (limited minutes)       Settings   change live GameConfig values + shop prices
	  BanPerm    permanent ban (minutes = 0)           AuditLog   read the admin action log
	  Unban      lift a ban                            Cash / Diamonds / Rebirth / Items   economy and progression
	A role with  "*"  has every permission.
	Limits are per role; a bigger number than the limit is refused by the server.
]]
AdminConfig.PermissionCatalog = {
	{ Id = "Panel", Label = "Open the panel", Group = "General" },
	{ Id = "Inspect", Label = "View player details", Group = "General" },
	{ Id = "ServerInfo", Label = "View server info", Group = "General" },
	{ Id = "SafeTools", Label = "Safe test tools (clear stun / freeze)", Group = "General" },
	{ Id = "AuditLog", Label = "View the staff log", Group = "General" },
	{ Id = "Announce", Label = "Send server announcements", Group = "General" },
	{ Id = "Settings", Label = "Edit approved live settings + shop prices", Group = "General" },
	{ Id = "Logging", Label = "Send a Discord test log / see its status", Group = "General" },
	{ Id = "Warn", Label = "Warn players", Group = "Moderation" },
	{ Id = "Kick", Label = "Kick players", Group = "Moderation" },
	{ Id = "History", Label = "View moderation history", Group = "Moderation" },
	{ Id = "BanTemp", Label = "Temporarily ban players", Group = "Moderation" },
	{ Id = "BanPerm", Label = "Permanently ban players", Group = "Moderation" },
	{ Id = "Unban", Label = "Unban players", Group = "Moderation" },
	{ Id = "Cash", Label = "Give / remove cash", Group = "Economy" },
	{ Id = "Diamonds", Label = "Give / remove diamonds", Group = "Economy" },
	{ Id = "Rebirth", Label = "Change rebirth count", Group = "Economy" },
	{ Id = "Items", Label = "Grant weapons / gear / boosts", Group = "Economy" },
	{ Id = "Hamsters", Label = "Grant hamsters", Group = "Economy" },
	{ Id = "ManageRoles", Label = "Manage ordinary roles + assign them", Group = "Staff" },
	{ Id = "ManageAdmins", Label = "Manage administrators + elevated roles", Group = "Staff" },
}

-- Roles made or edited in the panel are saved in a DataStore. true = ignore everything that was saved and use only this file
-- (the safe recovery path if a saved role ever causes trouble). Owners listed above always work either way.
AdminConfig.IgnoreSavedRoles = false

-- A custom role's Level (its priority) can be anything from 0.5 up to this: nobody can create a role as strong as CoOwner / Owner.
AdminConfig.MaxCustomLevel = 3.9

AdminConfig.Roles = {
	Owner = {
		Level = 5,
		Permissions = { "*" },
		Limits = { MaxCash = 1e12, MaxDiamonds = 1e9, MaxRebirths = 25, MaxBanMinutes = math.huge },
	},
	CoOwner = {
		Level = 4, -- below Owner: may do everything, but not to an Owner
		Permissions = { "*" },
		Limits = { MaxCash = 1e12, MaxDiamonds = 1e9, MaxRebirths = 25, MaxBanMinutes = math.huge },
	},
	Admin = {
		Level = 3,
		Permissions = { "Panel", "Inspect", "Warn", "Kick", "History", "BanTemp", "BanPerm", "Unban", "Cash", "Diamonds", "Rebirth", "Items", "Hamsters", "Announce", "ServerInfo", "SafeTools", "Settings", "AuditLog" },
		Limits = { MaxCash = 1e9, MaxDiamonds = 1e6, MaxRebirths = 25, MaxBanMinutes = math.huge },
	},
	Moderator = {
		Level = 2,
		Permissions = { "Panel", "Inspect", "Warn", "Kick", "History", "BanTemp", "ServerInfo", "SafeTools" },
		Limits = { MaxCash = 0, MaxDiamonds = 0, MaxRebirths = 0, MaxBanMinutes = 7 * 24 * 60 },
	},
	Developer = {
		Level = 1,
		-- testing tools only: no kicking, banning or announcing
		Permissions = { "Panel", "Inspect", "ServerInfo", "SafeTools", "Settings", "Cash", "Diamonds", "Rebirth", "Items", "Hamsters", "AuditLog" },
		Limits = { MaxCash = 1e8, MaxDiamonds = 1e5, MaxRebirths = 25, MaxBanMinutes = 0 },
	},
}

-- Actions that need an explicit "Are you sure?" (the server refuses them without a confirmation flag).
AdminConfig.ConfirmCashAbove = 1e6 -- cash / diamond changes bigger than this (or any removal) need confirmation

-- Seconds between two admin requests of one player (spam protection).
AdminConfig.MinSecondsBetweenRequests = 0.15

-- A discreet way in: the key lives in InputConfig.Bindings.Admin (client) and the chat command /admin. Both only ASK the server;
-- the server decides. There is no button on the normal HUD.

return AdminConfig
