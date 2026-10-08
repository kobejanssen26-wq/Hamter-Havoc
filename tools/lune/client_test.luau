--[[
	Client smoke test: boots the real client scripts (Main.client: controllers + every UI screen)
	headless with a fake LocalPlayer and a loaded profile, then opens every window, sends a few
	notifications and refreshes. Catches runtime errors (nil fields, wrong calls) in the UI code.
	It does not render anything; layout and looks still need a check in Studio.
	usage: lune run tools/lune/client_test.luau [projectRoot]
]]

local process = require("@lune/process")
local stdio = require("@lune/stdio")
local task = require("@lune/task")
local Runtime = require("./runtime")
local Mocks = require("./servermocks")

local game = Runtime.boot(process.args[1] or ".")
Runtime.quiet = process.env.VERBOSE == nil
Runtime.reportErrors = true
Mocks.install()
local roblox = Runtime.roblox

local failures, passes = 0, 0
local function check(ok: boolean, label: string, detail: any?)
	if ok then
		passes += 1
	else
		failures += 1
		print("FAIL  " .. label .. (if detail ~= nil then "  (" .. tostring(detail) .. ")" else ""))
	end
end

-- client-side engine mocks ---------------------------------------------------
local Players = game:GetService("Players")
local player = Mocks.addPlayer("Tester", 7)
pcall(function()
	(Players :: any).LocalPlayer = player
end)
local playerGui = roblox.Instance.new("PlayerGui")
playerGui.Parent = player
local uis = game:GetService("UserInputService")
for key, value in { TouchEnabled = false, KeyboardEnabled = true, MouseIconEnabled = true, GamepadEnabled = false } do
	pcall(function()
		(uis :: any)[key] = value
	end)
end
local camera = roblox.Instance.new("Camera")
camera.Parent = game:GetService("Workspace")
pcall(function()
	game:GetService("Workspace").CurrentCamera = camera
	camera.ViewportSize = roblox.Vector2.new(1280, 720)
end)
roblox.implementMethod("TweenService", "Create", function(_, instance, _info, goals)
	local tween = { Completed = Runtime.newSignal(), PlaybackState = nil }
	function tween.Play()
		for key, value in goals do
			pcall(function()
				instance[key] = value
			end)
		end
		tween.Completed:Fire(roblox.Enum.PlaybackState.Completed)
	end
	tween.Cancel = function() end
	tween.Pause = function() end
	tween.Destroy = function() end
	return tween
end)
roblox.implementMethod("RemoteFunction", "InvokeServer", function(_, action)
	return { ok = true, msg = "ok (" .. tostring(action) .. ")", extra = nil }
end)
roblox.implementMethod("RemoteEvent", "FireServer", function() end)
roblox.implementMethod("Debris", "AddItem", function() end)
roblox.implementMethod("Sound", "Play", function() end)
roblox.implementMethod("Sound", "Stop", function() end)
roblox.implementMethod("ContentProvider", "PreloadAsync", function() end)
roblox.implementMethod("SoundService", "PlayLocalSound", function() end)
roblox.implementMethod("Workspace", "Raycast", function()
	return nil
end)
roblox.implementMethod("Players", "GetFriendsAsync", function()
	return nil
end)
-- engine events that Lune doesn't know (they never fire here, connecting must just work)
for _, name in {
	"MouseEnter", "MouseLeave", "MouseButton1Down", "MouseButton1Up", "MouseButton1Click", "MouseButton2Click",
	"Activated", "InputBegan", "InputChanged", "InputEnded", "FocusLost", "Focused", "TouchTap", "Triggered",
	"Touched", "TouchEnded", "MouseClick", "JumpRequest", "WindowFocused", "CharacterAdded", "Died", "StateChanged",
	"Running", "PromptShown", "PromptHidden", "TriggerEnded", "ReturnPressedFromOnScreenKeyboard", "MoveToFinished",
} do
	pcall(roblox.implementProperty, "Instance", name, function(self)
		return Runtime.signalFor(self, name)
	end)
end
for _, method in { "BindAction", "UnbindAction", "SetTitle", "SetImage", "SetPosition", "SetDescription", "BindActionAtPriority" } do
	roblox.implementMethod("ContextActionService", method, function() end)
end
roblox.implementMethod("ContextActionService", "GetButton", function()
	return nil
end)
roblox.implementMethod("UserInputService", "GetMouseLocation", function()
	return roblox.Vector2.new(640, 360)
end)
roblox.implementMethod("UserInputService", "IsKeyDown", function()
	return false
end)
roblox.implementMethod("UserInputService", "GetLastInputType", function()
	return roblox.Enum.UserInputType.MouseMovement
end)
-- the server creates the remotes
local Remotes = Runtime.require(game:GetService("ReplicatedStorage").Remotes)
Remotes.init()

-- profile ----------------------------------------------------------------------
local Modules = Runtime.modules()
local Template = Runtime.mod("ProfileTemplate")
local EconomyMath = Runtime.mod("EconomyMath")
local HamsterDatabase = Runtime.mod("HamsterDatabase")
local function deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in t do
		c[k] = deepCopy(v)
	end
	return c
end
local data = deepCopy(Template)
data.Rebirths = 6
for index, species in HamsterDatabase.Species do
	if index % 3 == 0 then
		data.Index[species.Id] = true
	end
	if index % 9 == 0 then
		data.Inventory[species.Id] = 2
		table.insert(data.Equipped, species.Id)
	end
end
data.Stats.Found = { Basic = 30, Rare = 4, Legendary = 1 }
data.Derived = EconomyMath.derived(data, os.time())
player:SetAttribute("Coins", 123456789)
player:SetAttribute("Gems", 4321)
player:SetAttribute("Tokens", 12)
player:SetAttribute("HouseId", 1)

-- boot the client --------------------------------------------------------------
local scripts = game:GetService("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local ok, err = pcall(Mocks.runScript, scripts:FindFirstChild("Main"))
check(ok, "client boots", err)

local DataController = Runtime.require(scripts.Controllers.DataController)
local UIKit = Runtime.require(scripts.UI.UIKit)
local MainUI = Runtime.require(scripts.UI.MainUI)
-- deliver the profile like the server does
local dataUpdate = game:GetService("ReplicatedStorage"):FindFirstChild("RemoteEvents"):FindFirstChild("DataUpdate")
Runtime.signalFor(dataUpdate, "OnClientEvent"):Fire(data, true)
task.wait(0.2)
check(DataController.Ready, "profile delivered")

for _, name in { "Inventory", "Index", "Rebirth", "Upgrades", "Daily", "Quests", "Shop", "Settings", "Codes" } do
	local panel = UIKit.getPanel(name)
	check(panel ~= nil, "window exists: " .. name)
	if panel then
		local before = #Runtime.errors
		panel:Open()
		task.wait(0.05)
		check(panel.IsOpen, "window opens: " .. name)
		check(UIKit.anyWindowOpen(), "mouse is released while " .. name .. " is open")
		local newErrors = 0
		for index = before + 1, #Runtime.errors do
			if not string.find(Runtime.errors[index], "Absolute") then
				newErrors += 1
			end
		end
		check(newErrors == 0, "no errors while opening " .. name, Runtime.errors[#Runtime.errors])
		panel:Close()
		task.wait(0.05)
		check(not UIKit.anyWindowOpen(), "mouse goes back to the camera after closing " .. name)
	end
end
-- focus variants (opened from world prompts)
MainUI.open("Upgrades", "TurboWheels")
task.wait(0.05)
UIKit.closeAll()
for _, kind in { "info", "success", "error", "reward" } do
	MainUI.toast("Test " .. kind, kind)
end
Runtime.signalFor(dataUpdate, "OnClientEvent"):Fire({ Rebirths = 7, Derived = EconomyMath.derived(data, os.time()) }, false)
task.wait(1.2)

for _, message in Runtime.errors do
	-- AbsolutePosition / AbsoluteSize come from the layout engine, which doesn't run headless
	if not string.find(message, "Absolute") then
		failures += 1
		print("FAIL  error: " .. string.split(message, "\n")[1])
	end
end
print(string.format("%d checks passed, %d failed", passes, failures))
process.exit(if failures > 0 then 1 else 0)
