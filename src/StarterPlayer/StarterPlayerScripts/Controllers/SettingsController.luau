--[[
	SettingsController: applies the saved settings that change the client's rendering:
	Low Graphics mode and Show Other Players. (Audio settings live in AudioController,
	particles in AmbientController / FxController, camera shake in FxController.)
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local DataController = require(script.Parent.DataController)

local SettingsController = {}

local localPlayer = Players.LocalPlayer
local trackedCharacters: { [Model]: boolean } = {}

local function setCharacterHidden(character: Model, hidden: boolean)
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("BasePart") or descendant:IsA("Decal") then
			(descendant :: any).LocalTransparencyModifier = if hidden then 1 else 0
		elseif descendant:IsA("BillboardGui") then
			descendant.Enabled = not hidden
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = if hidden then Enum.HumanoidDisplayDistanceType.None else Enum.HumanoidDisplayDistanceType.Viewer
	end
end

local function applyPlayers()
	local show = DataController.setting("ShowOtherPlayers") == true
	for _, other in Players:GetPlayers() do
		if other ~= localPlayer and other.Character then
			setCharacterHidden(other.Character, not show)
		end
	end
end

local function trackPlayer(other: Player)
	if other == localPlayer then
		return
	end
	local function onCharacter(character: Model)
		trackedCharacters[character] = true
		task.wait(0.5) -- let the avatar finish loading
		if DataController.setting("ShowOtherPlayers") ~= true and character.Parent then
			setCharacterHidden(character, true)
		end
		character.DescendantAdded:Connect(function(descendant)
			if DataController.setting("ShowOtherPlayers") ~= true and (descendant:IsA("BasePart") or descendant:IsA("Decal")) then
				(descendant :: any).LocalTransparencyModifier = 1
			end
		end)
	end
	other.CharacterAdded:Connect(onCharacter)
	if other.Character then
		task.spawn(onCharacter, other.Character)
	end
end

local function applyGraphics()
	local low = DataController.setting("LowGraphics") == true
	Lighting.GlobalShadows = not low
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
	if bloom then
		bloom.Enabled = not low
	end
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if rays then
		rays.Enabled = not low
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Density = if low then 0.08 else 0.28
	end
end

function SettingsController.start()
	for _, other in Players:GetPlayers() do
		trackPlayer(other)
	end
	Players.PlayerAdded:Connect(trackPlayer)

	local function apply()
		applyGraphics()
		applyPlayers()
	end
	apply()
	DataController.onChanged(function(keys)
		if keys.Settings then
			apply()
		end
	end)
end

return SettingsController
