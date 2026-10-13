--[[
	EmoteController: plays emotes (the wheel is EmoteUI) with the safety rules the game needs:
	  - the server decides if you may use it (unlocked, cooldown); the client only plays the animation
	  - one emote at a time: a new one stops the old one
	  - an emote ends when you walk, jump, die, respawn or get stunned; walking is never blocked by it
	  - Roblox default emotes use Humanoid:PlayEmote (they need no asset ids), custom ones use AnimationController
	  - an unavailable animation produces a short message, never an error
	The opening key comes from the player's setting (default B) through InputConfig, which prevents key conflicts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local EmoteConfig = require(Modules:WaitForChild("EmoteConfig"))
local InputConfig = require(Modules:WaitForChild("InputConfig"))

local AnimationController = require(script.Parent.AnimationController)
local AudioController = require(script.Parent.AudioController)
local DataController = require(script.Parent.DataController)

local EmoteController = {}

local player = Players.LocalPlayer
local currentTrack: AnimationTrack? = nil
local currentConnections: { RBXScriptConnection } = {}
local openCallbacks: { () -> () } = {}
local playing: string? = nil

function EmoteController.key(): Enum.KeyCode
	local name = InputConfig.emoteKey(DataController.setting("EmoteKey"))
	return (Enum.KeyCode :: any)[name]
end

function EmoteController.keyName(): string
	return InputConfig.emoteKey(DataController.setting("EmoteKey"))
end

function EmoteController.onToggle(callback: () -> ())
	table.insert(openCallbacks, callback)
end

local function humanoid(): Humanoid?
	local character = player.Character
	local found = character and character:FindFirstChildOfClass("Humanoid")
	if found and found.Health > 0 then
		return found
	end
	return nil
end

function EmoteController.isPlaying(): boolean
	return playing ~= nil
end

-- Stops the running emote and releases every connection that watches for movement / death.
function EmoteController.stop()
	for _, connection in currentConnections do
		connection:Disconnect()
	end
	table.clear(currentConnections)
	if currentTrack then
		AnimationController.stop(currentTrack, 0.2)
		currentTrack = nil
	end
	local h = humanoid()
	if h and playing then
		-- built-in emotes are cancelled by the Animate script when you move; make sure nothing keeps playing
		for _, track in h:GetPlayingAnimationTracks() do
			if track.Priority == Enum.AnimationPriority.Action and track.Name:lower():find("emote") then
				track:Stop(0.2)
			end
		end
	end
	playing = nil
end

local function watch(h: Humanoid)
	table.insert(currentConnections, h.Running:Connect(function(speed)
		if speed > 1 then
			EmoteController.stop()
		end
	end))
	table.insert(currentConnections, h.Jumping:Connect(function(active)
		if active then
			EmoteController.stop()
		end
	end))
	table.insert(currentConnections, h.Died:Connect(EmoteController.stop))
	table.insert(currentConnections, h.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Physics or new == Enum.HumanoidStateType.FallingDown or new == Enum.HumanoidStateType.Ragdoll or new == Enum.HumanoidStateType.Dead then
			EmoteController.stop()
		end
	end))
end

-- Asks the server and plays. Returns (ok, message).
function EmoteController.play(emoteId: string): (boolean, string)
	local def = EmoteConfig.ById[emoteId]
	local h = humanoid()
	if not def or not h then
		return false, "You can't emote right now"
	end
	local response = DataController.request("Emote", { Id = emoteId })
	if not response.ok then
		return false, response.msg
	end
	h = humanoid() -- the character may have changed while we waited
	if not h then
		return false, "You can't emote right now"
	end
	EmoteController.stop()

	local started = false
	if def.Builtin then
		local ok, result = pcall(function()
			return h:PlayEmote(def.Builtin)
		end)
		started = ok and result == true
	else
		local track
		if def.AnimationId then
			track = AnimationController.playAsset(h, def.AnimationId, { Priority = Enum.AnimationPriority.Action, Looped = false })
		elseif def.Animation then
			track = AnimationController.play(h, def.Animation)
		end
		if track then
			currentTrack = track
			started = true
			table.insert(currentConnections, track.Stopped:Connect(function()
				if currentTrack == track then
					EmoteController.stop()
				end
			end))
		end
	end
	if not started then
		return false, def.DisplayName .. " isn't available right now"
	end
	playing = emoteId
	watch(h)
	task.delay(EmoteConfig.MaxSeconds, function()
		if playing == emoteId then
			EmoteController.stop() -- nothing may play for ever
		end
	end)
	if def.Sound then
		AudioController.play(def.Sound)
	end
	return true, def.DisplayName
end

function EmoteController.start()
	-- key to open the wheel; typing in a text box never triggers it
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or input.UserInputType ~= Enum.UserInputType.Keyboard then
			return
		end
		if input.KeyCode == EmoteController.key() then
			for _, callback in openCallbacks do
				callback()
			end
		end
	end)
	-- a respawn or character swap ends whatever was playing (the old connections belong to the old humanoid)
	player.CharacterRemoving:Connect(EmoteController.stop)
	player.CharacterAdded:Connect(EmoteController.stop)
end

return EmoteController
