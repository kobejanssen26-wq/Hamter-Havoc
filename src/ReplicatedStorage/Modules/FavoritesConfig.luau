--[[
	FavoritesConfig: the texts and icons of the Like & Favorite boards in the plaza (one beside the guest spawn, one across the south promenade; both stand on grass, clear of every path).

	What this board really does - read this before you change it:
	  * Roblox gives a game NO way to press "Like" or "Favorite" for a player: only the player can do it, on the game's page
	    (website or app). So the board never claims that anything was liked or favorited and never rewards it. It points to the
	    two buttons on the game page, in short plain words.
	  * "Favorite a server" does not exist as a Roblox feature (you favorite the game, not one server), so the board does not
	    offer it.
	  * The same four actions (invite, like, favorite, group) are explained in the Community window; IDs live in SocialConfig.
	  * What IS supported by Roblox from inside a game is the invite prompt: SocialService:PromptGameInvite opens Roblox's own
	    "invite friends" window. The prompt on the board uses exactly that (FavoritesController), and only when Roblox says the
	    player may send invites (CanSendGameInviteAsync). Nothing happens, and nothing is promised, when it can not.
]]

local SocialConfig = require(script.Parent.SocialConfig)

local FavoritesConfig = {}

FavoritesConfig.Title = "LIKE & FAVORITE"
FavoritesConfig.Footer = "Both buttons are on this game's Roblox page."
FavoritesConfig.PromptObject = "Like & Favorite board"
FavoritesConfig.PromptAction = "Open community"
FavoritesConfig.InviteUnavailable = SocialConfig.InviteUnavailable

-- Rows on the board (both faces): the same actions as the Community window, see Modules/SocialConfig. Icon = a drawn icon (UI/Icons).
function FavoritesConfig.rows(): { { Id: string, Icon: string, Title: string, Text: string } }
	local rows = {}
	for _, action in SocialConfig.actions() do
		local text = action.Text
		if action.Kind == "Invite" then
			text = "Press F at this board"
		elseif action.Kind == "Group" then
			text = SocialConfig.GroupName
		end
		table.insert(rows, { Id = action.Id, Icon = action.Icon, Title = action.Title, Text = text })
	end
	return rows
end

return FavoritesConfig
