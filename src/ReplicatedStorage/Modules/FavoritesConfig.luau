--[[
	FavoritesConfig: the texts and icons of the Like & Favorite board in the plaza (next to the guest spawn).

	What this board really does - read this before you change it:
	  * Roblox gives a game NO way to press "Like" or "Favorite" for a player: only the player can do it, on the game's page
	    (website or app). So the board never claims that anything was liked or favorited and never rewards it. It points to the
	    two buttons on the game page, in short plain words.
	  * "Favorite a server" does not exist as a Roblox feature (you favorite the game, not one server), so the board does not
	    offer it.
	  * What IS supported by Roblox from inside a game is the invite prompt: SocialService:PromptGameInvite opens Roblox's own
	    "invite friends" window. The prompt on the board uses exactly that (FavoritesController), and only when Roblox says the
	    player may send invites (CanSendGameInviteAsync). Nothing happens, and nothing is promised, when it can not.
]]

local FavoritesConfig = {}

FavoritesConfig.Title = "LIKE & FAVORITE"
FavoritesConfig.Footer = "Both buttons are on this game's Roblox page."
FavoritesConfig.PromptObject = "Like & Favorite board"
FavoritesConfig.PromptAction = "Invite friends"
FavoritesConfig.InviteUnavailable = "Invites are not available for your account right now."

-- Rows on the board: Icon = a drawn icon (UI/Icons), Title and Text are what the board shows.
FavoritesConfig.Rows = {
	{ Id = "like", Icon = "thumb", Title = "Like the game", Text = "Tap the thumbs-up on the game page" },
	{ Id = "favorite", Icon = "star", Title = "Add to Favorites", Text = "Tap the star on the game page" },
	{ Id = "invite", Icon = "people", Title = "Invite friends", Text = "Press F at this board" },
}

return FavoritesConfig
