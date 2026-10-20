--[[
	SocialUI: the Community window (opened by the Like & Favorite boards and by Settings > Community).
	Four separate rows - Invite friends, Like, Add to Favorites, Join the group - from Modules/SocialConfig.
	Nothing is faked: only "Invite" has a real button (Roblox's own invite window); Like / Favorite are explanations
	(Roblox gives a game no way to press them for a player), and the Group row shows the REAL membership (Player:IsInGroup).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local SocialConfig = require(Modules:WaitForChild("SocialConfig"))

local FavoritesController = require(script.Parent.Parent.Controllers.FavoritesController)
local Theme = require(script.Parent.Theme)
local UIKit = require(script.Parent.UIKit)

local SocialUI = {}

local C = UIKit.Colors

-- true / false, or nil when Roblox could not answer
function SocialUI.groupMember(): boolean?
	if not SocialConfig.groupConfigured() then
		return nil
	end
	local ok, member = pcall(function()
		return Players.LocalPlayer:IsInGroup(SocialConfig.GroupId)
	end)
	if ok and type(member) == "boolean" then
		return member
	end
	return nil
end

function SocialUI.start()
	local panel = UIKit.panel({ Name = "Social", Title = SocialConfig.WindowTitle, Icon = "people", Design = Vector2.new(760, 120 + 92 * #SocialConfig.actions()), Accent = Theme.Accents.Rebirth, Subtitle = SocialConfig.WindowSubtitle })
	local body = panel.Body
	local statusLabels: { [string]: TextLabel } = {}
	local note = UIKit.label(body, { Name = "Note", Size = UDim2.new(1, 0, 0, 22), Position = UDim2.new(0, 0, 1, -24), Text = "", TextSize = 14, TextColor3 = C.Muted, TextXAlignment = Enum.TextXAlignment.Center })

	for index, action in SocialConfig.actions() do
		local row = UIKit.frame(body, { Name = "Row_" .. action.Id, Size = UDim2.new(1, 0, 0, 80), Position = UDim2.fromOffset(0, (index - 1) * 90), BackgroundColor3 = C.Card })
		UIKit.corner(row, 12)
		UIKit.icon(row, action.Icon, { Name = "RowIcon", Size = UDim2.fromOffset(52, 52), Position = UDim2.fromOffset(14, 14) })
		UIKit.label(row, { Name = "RowTitle", Position = UDim2.fromOffset(80, 8), Size = UDim2.new(1, -300, 0, 32), Text = action.Title, Font = UIKit.Fonts.Title, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left })
		local detail = action.Text
		if action.Kind == "Group" then
			detail = string.format("%s: %s", SocialConfig.GroupName, action.Text)
		end
		UIKit.label(row, { Name = "RowText", Position = UDim2.fromOffset(80, 42), Size = UDim2.new(1, -300, 0, 30), Text = detail, TextSize = 16, TextColor3 = C.Muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top })
		if action.Kind == "Invite" then
			UIKit.button(row, {
				Name = "InviteButton",
				Text = action.Button or "Invite",
				Size = UDim2.fromOffset(190, 46),
				Position = UDim2.new(1, -14, 0.5, 0),
				AnchorPoint = Vector2.new(1, 0.5),
				Color = C.Green,
				TextSize = 20,
				OnClick = function()
					local problem = FavoritesController.invite()
					note.Text = problem or ""
				end,
			})
		else
			local status = UIKit.label(row, { Name = "Status", Size = UDim2.fromOffset(200, 46), Position = UDim2.new(1, -14, 0.5, 0), AnchorPoint = Vector2.new(1, 0.5), Text = "", TextSize = 17, Font = UIKit.Fonts.Title, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Right })
			if action.Kind == "Info" then
				status.Text = "On the game page"
				status.TextColor3 = C.Muted
			else
				statusLabels[action.Id] = status
			end
		end
	end

	local function refresh()
		note.Text = ""
		local label = statusLabels.group
		if label then
			local member = SocialUI.groupMember()
			if member == true then
				label.Text = "You are a member"
				label.TextColor3 = C.Green
			elseif member == false then
				label.Text = "Not a member yet"
				label.TextColor3 = C.Gold
			else
				label.Text = SocialConfig.GroupUnknown
				label.TextColor3 = C.Muted
			end
		end
	end
	panel.OnOpen[1] = refresh
	refresh()
end

return SocialUI
