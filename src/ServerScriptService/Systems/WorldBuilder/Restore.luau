--[[
	Restore: puts the RUNTIME wiring back on a world folder that was saved in a place file (StudioOwned).

	A saved / baked copy keeps parts, models, attributes and prompts, but the world must not depend on that: tags and
	particle emitters are re-added here by name and by attribute, so a copy that lost them (or a hand-built copy) works.
	Nothing is ever removed or moved: this only ADDS what is missing, so your edits in Studio are never overwritten.

	  attribute TutorialTarget      -> tag TutorialTarget   (the tutorial points at it)
	  attribute AnimTag             -> that tag             (Sway / SpinModel / Bob, read by the client)
	  Model "Tree_*"                -> TreeSway             Model "Cloud" -> Cloud
	  Model "LuckyWheel"            -> LuckyWheel           Part "SafeZone" -> SafeZone (no fighting inside)
	  Model "FavoritesBoard"        -> FavoritesBoard       Frame with attribute IconName -> WorldIcon (the client draws its picture)
	  Part "Fireflies"              -> firefly emitter      Part "BurrowGlow" -> sparkle emitter
]]

local Decor = require(script.Parent.Decor)
local PathBuilder = require(script.Parent.PathBuilder)

local Restore = {}

function Restore.apply(root: Instance)
	for _, instance in root:GetDescendants() do
		if type(instance:GetAttribute("TutorialTarget")) == "string" then
			instance:AddTag("TutorialTarget")
		end
		local animation = instance:GetAttribute("AnimTag")
		if type(animation) == "string" then
			instance:AddTag(animation)
		end
		if instance:IsA("GuiObject") and type(instance:GetAttribute("IconName")) == "string" then
			instance:AddTag("WorldIcon")
		end
		if instance:IsA("Model") then
			if instance.Name == "LuckyWheel" then
				instance:AddTag("LuckyWheel")
			elseif instance.Name == "FavoritesBoard" then
				instance:AddTag("FavoritesBoard")
			elseif instance.Name == "Cloud" then
				instance:AddTag("Cloud")
			elseif string.sub(instance.Name, 1, 5) == "Tree_" then
				instance:AddTag("TreeSway")
			end
		elseif instance:IsA("BasePart") then
			if instance.Name == "SafeZone" then
				instance:AddTag("SafeZone")
			elseif instance.Name == "Fireflies" then
				Decor.addFireflyEmitter(instance)
			elseif instance.Name == "BurrowGlow" then
				PathBuilder.addSparkle(instance)
			end
		end
	end
end

return Restore
