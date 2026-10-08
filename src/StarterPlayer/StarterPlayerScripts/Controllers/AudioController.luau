--[[
	AudioController: UI sounds, collect fanfares scaled by rarity, hamster footsteps, background music.
	Volumes and on/off come from the player's saved settings. See AudioConfig for sound ids.
]]

local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local AudioConfig = require(Modules:WaitForChild("AudioConfig"))
local RarityConfig = require(Modules:WaitForChild("RarityConfig"))

local DataController = require(script.Parent.DataController)

local AudioController = {}

local sfxGroup: SoundGroup
local musicGroup: SoundGroup
local musicSound: Sound? = nil
local trackIndex = 0

local lastPlayed: { [string]: number } = {}

local function applySettings()
	local sfxOn = DataController.setting("SFX")
	local musicOn = DataController.setting("Music")
	sfxGroup.Volume = if sfxOn then DataController.setting("SFXVolume") else 0
	musicGroup.Volume = if musicOn then DataController.setting("MusicVolume") else 0
end

-- Plays a named sound effect. Cheap throttle so spamming a name never stacks dozens of sounds.
function AudioController.play(name: string, options: { Pitch: number?, Volume: number?, Position: Vector3? }?)
	local config = AudioConfig.Sfx[name]
	if not config or sfxGroup.Volume <= 0 then
		return
	end
	local now = os.clock()
	if lastPlayed[name] and now - lastPlayed[name] < 0.05 then
		return
	end
	lastPlayed[name] = now

	local sound = Instance.new("Sound")
	sound.SoundId = config.Id
	sound.Volume = config.Volume * ((options and options.Volume) or 1)
	sound.PlaybackSpeed = config.Pitch * ((options and options.Pitch) or 1)
	sound.SoundGroup = sfxGroup
	sound.RollOffMaxDistance = 80
	if options and options.Position then
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.one
		holder.Position = options.Position
		holder.Parent = workspace
		sound.Parent = holder
		Debris:AddItem(holder, 4)
	else
		sound.Parent = SoundService
		Debris:AddItem(sound, 4)
	end
	sound:Play()
end

-- Layered fanfare: more layers + lower pitches for rarer hamsters.
local function playLayers(sound: string, layers: { number }, volume: number?)
	for index, pitch in layers do
		task.delay((index - 1) * 0.07, function()
			AudioController.play(sound, { Pitch = pitch, Volume = volume })
		end)
	end
end

function AudioController.playCollect(rarityId: string)
	local rank = RarityConfig.rank(rarityId)
	local tier = math.clamp(math.ceil(rank / 2), 1, #AudioConfig.RarityFanfare)
	local fanfare = AudioConfig.RarityFanfare[tier]
	playLayers(fanfare.Sound, fanfare.Layers, 1)
end

function AudioController.playRareAlert(rarityId: string)
	local alert = AudioConfig.RareAlert[rarityId]
	if alert then
		playLayers(alert.Sound, alert.Layers, 1.2)
	end
end

local function playNextTrack()
	local tracks = AudioConfig.Music.Tracks
	if #tracks == 0 then
		return
	end
	trackIndex = trackIndex % #tracks + 1
	if musicSound then
		musicSound:Destroy()
	end
	local sound = Instance.new("Sound")
	sound.Name = "Music"
	sound.SoundId = tracks[trackIndex]
	sound.Volume = 1
	sound.SoundGroup = musicGroup
	sound.Parent = SoundService
	sound.Ended:Connect(playNextTrack)
	sound:Play()
	musicSound = sound
end

function AudioController.start()
	sfxGroup = Instance.new("SoundGroup")
	sfxGroup.Name = "SFX"
	sfxGroup.Parent = SoundService
	musicGroup = Instance.new("SoundGroup")
	musicGroup.Name = "MusicGroup"
	musicGroup.Parent = SoundService

	applySettings()
	DataController.onChanged(function(keys)
		if keys.Settings then
			applySettings()
		end
	end)
	playNextTrack()
end

return AudioController
