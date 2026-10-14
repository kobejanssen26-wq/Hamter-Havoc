--[[
	PromptController: makes the world key [F] (shops, upgrades, elevator, security panel) dependable.

	Roblox shows ONE prompt per key (Exclusivity = OnePerButton): the nearest. Normally the engine triggers it by itself. This
	controller watches which F prompt is currently shown and, if the engine did not trigger a tap-prompt (HoldDuration 0) within
	a moment after F was pressed, it presses it through the prompt's public input methods (InputHoldBegin / InputHoldEnd). It
	never fires a prompt that is hidden, disabled, too far away, or a hold-prompt (the steal prompt needs a real hold).
	The server still validates every trigger (distance, ownership), so this cannot give anyone anything extra.

	Debug: set the attribute "PromptDebug" = true on the LocalPlayer (or run PromptController.debug = true) and the Output shows
	which prompt answered F, or why none did.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")

local InputConfig = require(game:GetService("ReplicatedStorage").Modules.InputConfig)

local PromptController = {}
PromptController.debug = false

local player = Players.LocalPlayer
local shown: { [ProximityPrompt]: boolean } = {}
local lastTriggered = 0

local function say(text: string)
	if PromptController.debug or player:GetAttribute("PromptDebug") == true then
		print("[Prompt] " .. text)
	end
end

local function keyCode(): Enum.KeyCode
	local name = InputConfig.Bindings.WorldMenu
	local ok, key = pcall(function()
		return (Enum.KeyCode :: any)[name]
	end)
	return if ok and key then key else Enum.KeyCode.F
end

-- The shown tap-prompt that uses the world key and is closest to the character (nil when none qualifies).
local function candidate(): ProximityPrompt?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for prompt in shown do
		if prompt.Parent and prompt.Enabled and prompt.HoldDuration == 0 and prompt.KeyboardKeyCode == keyCode() then
			local part = prompt.Parent
			local position = if part:IsA("BasePart") then part.Position elseif part:IsA("Attachment") then part.WorldPosition else nil
			if position then
				local distance = (root.Position - position).Magnitude
				if distance <= prompt.MaxActivationDistance and distance < bestDistance then
					best, bestDistance = prompt, distance
				end
			end
		end
	end
	return best
end

function PromptController.start()
	ProximityPromptService.PromptShown:Connect(function(prompt)
		shown[prompt] = true
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		shown[prompt] = nil
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt)
		lastTriggered = os.clock()
		say("engine triggered " .. prompt:GetFullName())
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if input.KeyCode ~= keyCode() then
			return
		end
		if UserInputService:GetFocusedTextBox() ~= nil then
			return -- typing in a text box: never act
		end
		local pressedAt = os.clock()
		task.delay(0.25, function()
			if lastTriggered >= pressedAt then
				return -- the engine handled it
			end
			local prompt = candidate()
			if not prompt then
				say("F pressed, no tap-prompt in reach" .. (if processed then " (input was already used by the UI)" else ""))
				return
			end
			say("engine did not answer, pressing " .. prompt:GetFullName())
			pcall(function()
				prompt:InputHoldBegin()
				task.wait()
				prompt:InputHoldEnd()
			end)
		end)
	end)
end

return PromptController
