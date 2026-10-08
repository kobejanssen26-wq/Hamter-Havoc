--[[
	Client entry point. The client only displays state and hides prompts that don't apply to
	the local player; it never decides money, ownership or stealing.
]]

local Controllers = script.Parent:WaitForChild("Controllers")

for _, name in { "HudController", "PromptController", "WheelAnimator" } do
	require(Controllers:WaitForChild(name)).start()
end
