--[[
	Hides prompts that make no sense for the local player (own STEAL prompts, other people's
	COLLECT prompts, your own HIT prompt). Purely cosmetic - the server validates everything anyway.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

local PromptController = {}

local function track(tag: string, shouldEnable: (ProximityPrompt) -> boolean)
	local function setup(prompt: Instance)
		if not prompt:IsA("ProximityPrompt") then
			return
		end
		prompt.Enabled = shouldEnable(prompt)
		prompt.AttributeChanged:Connect(function()
			prompt.Enabled = shouldEnable(prompt)
		end)
	end
	for _, prompt in CollectionService:GetTagged(tag) do
		setup(prompt)
	end
	CollectionService:GetInstanceAddedSignal(tag):Connect(setup)
end

function PromptController.start()
	track("StealPrompt", function(prompt)
		return prompt:GetAttribute("OwnerUserId") ~= player.UserId
	end)
	track("OwnerOnlyPrompt", function(prompt)
		return prompt:GetAttribute("OwnerUserId") == player.UserId
	end)
	track("HitPrompt", function(prompt)
		return prompt:GetAttribute("CarrierUserId") ~= player.UserId
	end)
end

return PromptController
