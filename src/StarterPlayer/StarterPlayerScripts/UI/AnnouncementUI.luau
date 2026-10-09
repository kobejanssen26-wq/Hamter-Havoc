--[[
	AnnouncementUI: the exciting moments.
	  - server-wide banners ("A LEGENDARY HAMSTER HAS APPEARED!") with sound + colour flash
	  - a personal alert when a rare hamster starts running for YOU
	  - a "NEW HAMSTER" reveal card with a spinning 3D model for big finds and capsules
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Format = require(Modules:WaitForChild("Format"))
local HamsterDatabase = require(Modules:WaitForChild("HamsterDatabase"))
local RarityConfig = require(Modules:WaitForChild("RarityConfig"))
local Remotes = require(ReplicatedStorage:WaitForChild("Remotes"))

local AudioController = require(script.Parent.Parent.Controllers.AudioController)
local DataController = require(script.Parent.Parent.Controllers.DataController)
local FxController = require(script.Parent.Parent.Controllers.FxController)
local WorldController = require(script.Parent.Parent.Controllers.WorldController)
local UIKit = require(script.Parent.UIKit)

local AnnouncementUI = {}

local C = UIKit.Colors
local player = Players.LocalPlayer

local gui: ScreenGui
local flash: Frame
local bannerHolder: Frame
local revealFrame: Frame? = nil
local revealToken = 0

local function doFlash(color: Color3, strength: number)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 1 - strength
	UIKit.tween(flash, 0.7, { BackgroundTransparency = 1 })
end

local function showBanner(text: string, rarityId: string, subtitle: string?)
	local definition = RarityConfig.ById[rarityId]
	local color = if definition then UIKit.rarityColor(definition) else C.Gold
	local rank = if definition then definition.Rank else 1

	local banner = UIKit.frame(bannerHolder, {
		Size = UDim2.fromOffset(620, 74),
		Position = UDim2.new(0.5, 0, 0, -90),
		AnchorPoint = Vector2.new(0.5, 0),
		BackgroundColor3 = C.Dim,
		BackgroundTransparency = 0.05,
	})
	UIKit.corner(banner, 22)
	UIKit.stroke(banner, color, 4)
	UIKit.gradient(banner, Color3.fromRGB(70, 48, 66), C.Dim, 90)
	UIKit.icon(banner, "hamster", { Size = UDim2.fromOffset(46, 46), Position = UDim2.fromOffset(14, 14) })
	UIKit.label(banner, {
		Size = UDim2.new(1, -90, 0, if subtitle then 42 else 74),
		Position = UDim2.fromOffset(78, if subtitle then 6 else 0),
		Text = text,
		Font = UIKit.Fonts.Title,
		TextSize = 24,
		TextColor3 = color,
		TextScaled = false,
		TextWrapped = true,
	})
	if subtitle then
		UIKit.label(banner, {
			Size = UDim2.new(1, -90, 0, 22),
			Position = UDim2.fromOffset(78, 44),
			Text = subtitle,
			TextSize = 14,
			TextColor3 = C.White,
		})
	end

	UIKit.tween(banner, 0.4, { Position = UDim2.new(0.5, 0, 0, 80) }, Enum.EasingStyle.Back)
	if rank >= 8 then
		doFlash(color, 0.35)
	end
	task.delay(4.5, function()
		UIKit.tween(banner, 0.4, { Position = UDim2.new(0.5, 0, 0, -90) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
		task.delay(0.45, function()
			banner:Destroy()
		end)
	end)
end

-- Big card with a spinning 3D hamster.
function AnnouncementUI.reveal(speciesId: string, isNew: boolean)
	local species = HamsterDatabase.ById[speciesId]
	if not species then
		return
	end
	revealToken += 1
	local token = revealToken
	if revealFrame then
		revealFrame:Destroy()
	end

	local definition = RarityConfig.ById[species.Rarity]
	local color = UIKit.rarityColor(definition)
	local frame = UIKit.frame(gui, {
		Size = UDim2.fromOffset(360, 420),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = C.Cream,
	})
	revealFrame = frame
	UIKit.corner(frame, 12)
	UIKit.stroke(frame, color, 3)
	local scale = UIKit.new("UIScale", { Scale = 0.2 }, frame)
	UIKit.gradient(frame, C.Cream:Lerp(color, 0.28), C.Cream, 90)

	UIKit.label(frame, {
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromOffset(0, 12),
		Text = if isNew then "NEW HAMSTER!" else "You got a hamster!",
		Font = UIKit.Fonts.Title,
		TextSize = 28,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextColor3 = if isNew then C.GoldDark else C.Ink,
	})
	UIKit.hamsterIcon(frame, species, { Size = UDim2.new(1, -30, 0, 230), Position = UDim2.fromOffset(15, 54), Spin = true })
	local index = DataController.get("Index") or {}
	local shownName = if definition.Hidden and not index[species.Id] and not isNew then "???" else species.Name
	UIKit.label(frame, {
		Size = UDim2.new(1, 0, 0, 36),
		Position = UDim2.fromOffset(0, 290),
		Text = shownName,
		Font = UIKit.Fonts.Title,
		TextSize = 32,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	UIKit.chip(frame, string.upper(definition.Name), color, UDim2.fromOffset(150, 28)).Position = UDim2.new(0.5, -75, 0, 332)
	UIKit.iconText(frame, {
		Icon = "coin",
		Text = string.format("+%s / sec", Format.short(HamsterDatabase.income(species))),
		Size = UDim2.new(1, 0, 0, 26),
		Position = UDim2.fromOffset(0, 368),
		TextSize = 18,
		TextColor = C.GoldDark,
		Align = Enum.HorizontalAlignment.Center,
	})

	UIKit.tween(scale, 0.45, { Scale = 1 }, Enum.EasingStyle.Back)
	doFlash(color, 0.3)
	task.delay(3.2, function()
		if token == revealToken and frame.Parent then
			UIKit.tween(scale, 0.25, { Scale = 0.01 }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
			task.delay(0.28, function()
				if frame.Parent then
					frame:Destroy()
				end
			end)
		end
	end)
end

function AnnouncementUI.start()
	gui = UIKit.new("ScreenGui", {
		Name = "AnnouncementUI",
		ResetOnSpawn = false,
		DisplayOrder = 30,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, player:WaitForChild("PlayerGui"))
	flash = UIKit.frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 0 })
	flash.Active = false
	bannerHolder = UIKit.frame(gui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })

	-- server-wide announcements
	Remotes.event("Announce").OnClientEvent:Connect(function(info: { Kind: string, RarityId: string, Text: string, PlayerName: string, UserId: number })
		local subtitle = nil
		if info.Kind == "Spawn" then
			subtitle = if info.PlayerName ~= "" then string.format("Rolled by %s's luck - claim it before anyone else!", info.PlayerName) else "Claim it before anyone else!"
		elseif info.Kind == "Steal" then
			subtitle = "Chase them down and slap it loose!"
		end
		showBanner(info.Text, info.RarityId, subtitle)
		AudioController.playRareAlert(info.RarityId)
	end)

	-- a rare hamster is running for me: screen tint + a hint
	FxController.OnRareAlert = function(rarityId)
		local definition = RarityConfig.ById[rarityId]
		if definition then
			doFlash(UIKit.rarityColor(definition), 0.18)
		end
	end
	FxController.OnQuestDone = function() end
	-- somebody is stealing from me: red flash
	FxController.OnAlarm = function()
		doFlash(Color3.fromRGB(255, 70, 70), 0.3)
	end

	-- reveal cards for big finds
	WorldController.OnCollectResult = function(success, speciesId, isNew, _note)
		if not success then
			return
		end
		local species = HamsterDatabase.ById[speciesId]
		if not species then
			return
		end
		local rank = RarityConfig.rank(species.Rarity)
		if rank >= 7 or (isNew and rank >= 5) then
			AnnouncementUI.reveal(speciesId, isNew)
		end
	end
end

return AnnouncementUI
