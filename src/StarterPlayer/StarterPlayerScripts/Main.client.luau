--[[
	Client entry point. Order matters only for data: DataController first (everything reads it),
	then the world/audio/fx controllers, then the UI.
	The client never decides money, rarity, ownership or rewards - it displays and asks.
]]

local Controllers = script.Parent:WaitForChild("Controllers")
local UI = script.Parent:WaitForChild("UI")

local DataController = require(Controllers:WaitForChild("DataController"))
DataController.start()

local order = {
	"AudioController",
	"FxController",
	"WorldController",
	"InputController",
	"CursorController",
	"CombatController",
	"SecurityController",
	"NavController",
	"SettingsController",
	"AmbientController",
	"NatureController",
}
for _, name in order do
	local ok, err = pcall(function()
		require(Controllers:WaitForChild(name)).start()
	end)
	if not ok then
		warn(string.format("[Client] %s failed to start: %s", name, tostring(err)))
	end
end

local screens = {
	"MainUI",
	"IndexUI",
	"InventoryUI",
	"UpgradeUI",
	"RebirthUI",
	"ShopUI",
	"SettingsUI",
	"QuestUI",
	"DailyRewardUI",
	"HamsterHUD",
	"AnnouncementUI",
}
for _, name in screens do
	local ok, err = pcall(function()
		require(UI:WaitForChild(name)).start()
	end)
	if not ok then
		warn(string.format("[Client] %s failed to start: %s", name, tostring(err)))
	end
end

-- let the loading screen know we're ready
game.Players.LocalPlayer:SetAttribute("ClientReady", true)
