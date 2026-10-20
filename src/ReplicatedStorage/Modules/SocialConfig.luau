--[[
	SocialConfig: the ONE place for everything about the "Community" window and the Like & Favorite boards in the plaza.

	WHAT YOU MUST FILL IN BEFORE PUBLISHING (nothing else is needed):
	  GroupId   the number in your group's web address: roblox.com/communities/<GroupId>/...   (0 = no group yet: the Group row is hidden)
	  GroupName the name players should search for / look for on the group page

	WHAT EACH ACTION REALLY DOES (no action ever pretends to succeed):
	  Invite    opens Roblox's OWN "invite friends" window (SocialService:PromptGameInvite), only when Roblox says this player
	            may send invites (CanSendGameInviteAsync). If it can not, the player is told so.
	  Like      Roblox gives a game NO way to press "Like" for a player. The window only says where the button is. It never
	            rewards or confirms anything, because nothing can be checked.
	  Favorite  Same as Like: only the player can press the star on the game page. ("Favorite a server" is not a Roblox feature.)
	  Group     The window shows whether the player is ALREADY in the group (Player:IsInGroup, checked on the client and
	            refreshed whenever the window opens). Roblox lets nobody join a group from inside a game, so the button only
	            tells the player where to join. Joining is detected on the next open, nothing is promised before.
]]

local SocialConfig = {}

SocialConfig.GameName = "Hamster Plaza"
SocialConfig.GroupId = 0 -- <<< put your group's number here
SocialConfig.GroupName = "Hamster Plaza Fans" -- <<< and its name

SocialConfig.WindowTitle = "Community"
SocialConfig.WindowSubtitle = "Help the game grow - every one of these is optional"

-- Texts shown when something is not available (so a player is never left guessing).
SocialConfig.InviteUnavailable = "Invites are not available for your account right now."
SocialConfig.GroupUnknown = "Could not check the group right now. Try again in a moment."

-- Rows in the window, in order. Kind: "Invite" (button), "Info" (explanation only), "Group" (status + explanation).
SocialConfig.Actions = {
	{ Id = "invite", Kind = "Invite", Icon = "people", Title = "Invite friends", Text = "Opens Roblox's invite window.", Button = "Invite" },
	{ Id = "like", Kind = "Info", Icon = "thumb", Title = "Like the game", Text = "Tap the thumbs-up on the game page." },
	{ Id = "favorite", Kind = "Info", Icon = "star", Title = "Add to Favorites", Text = "Tap the star on the game page." },
	{ Id = "group", Kind = "Group", Icon = "shield", Title = "Join the group", Text = "Find the group on Roblox and press Join." },
}

function SocialConfig.groupConfigured(): boolean
	return type(SocialConfig.GroupId) == "number" and SocialConfig.GroupId > 0
end

-- The actions that exist right now (the Group row disappears until a GroupId is filled in).
function SocialConfig.actions(): { any }
	local list = {}
	for _, action in SocialConfig.Actions do
		if action.Kind ~= "Group" or SocialConfig.groupConfigured() then
			table.insert(list, action)
		end
	end
	return list
end

return SocialConfig
