--[[
	TheftController: client side of rack theft.
	  - the steal prompt on a wheel is only shown to people who could use it: never to the owner of that base, never
	    while it is unavailable (gate locked, hamster being stolen, owner protected). The server decides "Available";
	    this only hides prompts that make no sense for ME (the server still validates every trigger).
	The messages (THEFT / THEFT STOPPED / THEFT COMPLETE ...) come from the server as toasts; sounds from Fx events.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local TheftController = {}

local player = Players.LocalPlayer

local function watch(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local function update()
		local owner = prompt:GetAttribute("OwnerUserId")
		local want = prompt:GetAttribute("Available") == true and owner ~= player.UserId
		if prompt.Enabled ~= want then
			prompt.Enabled = want
		end
	end
	update()
	prompt:GetAttributeChangedSignal("Available"):Connect(update)
	prompt:GetAttributeChangedSignal("OwnerUserId"):Connect(update)
	prompt:GetPropertyChangedSignal("Enabled"):Connect(update)
end

function TheftController.start()
	CollectionService:GetInstanceAddedSignal("TheftPrompt"):Connect(watch)
	for _, prompt in CollectionService:GetTagged("TheftPrompt") do
		watch(prompt)
	end
end

return TheftController
