--[[
	FavoritesController: the Like & Favorite board in the plaza.

	  * Draws the pictures on the board: every GuiObject tagged "WorldIcon" with an attribute IconName gets that drawn icon (UI/Icons).
	  * Answers the board's prompt (attribute InviteFriends): opens Roblox's OWN invite window with SocialService:PromptGameInvite,
	    but only when Roblox says this player may send invites (CanSendGameInviteAsync). Nothing is faked: Roblox gives a game no way
	    to press "Like" or "Favorite" for a player, so the board only explains where those buttons are (see Modules/FavoritesConfig).
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local FavoritesConfig = require(ReplicatedStorage:WaitForChild("Modules"):WaitForChild("FavoritesConfig"))
local Icons = require(script.Parent.Parent.UI.Icons)

local FavoritesController = {}

local drawn: { [Instance]: boolean } = {}

local function drawIcon(instance: Instance)
	if drawn[instance] or not instance:IsA("GuiObject") then
		return
	end
	local name = instance:GetAttribute("IconName")
	if type(name) ~= "string" then
		return
	end
	drawn[instance] = true
	local icon = Icons.create(instance, name, { Name = "Art", Size = UDim2.fromOffset(52, 52) })
	icon.Size = UDim2.fromScale(1, 1)
end

-- Opens Roblox's invite window if Roblox allows it. Returns a message for the player when it can not.
function FavoritesController.invite(): string?
	local player = Players.LocalPlayer
	local ok, allowed = pcall(function()
		return SocialService:CanSendGameInviteAsync(player)
	end)
	if not ok or allowed ~= true then
		return FavoritesConfig.InviteUnavailable
	end
	local opened = pcall(function()
		SocialService:PromptGameInvite(player)
	end)
	if not opened then
		return FavoritesConfig.InviteUnavailable
	end
	return nil
end

function FavoritesController.start()
	for _, instance in CollectionService:GetTagged("WorldIcon") do
		drawIcon(instance)
	end
	CollectionService:GetInstanceAddedSignal("WorldIcon"):Connect(drawIcon)
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= Players.LocalPlayer or prompt:GetAttribute("InviteFriends") ~= true then
			return
		end
		local problem = FavoritesController.invite()
		if problem then
			require(script.Parent.Parent.UI.MainUI).toast(problem, "error")
		end
	end)
end

return FavoritesController
