--[[
	IconOverrides: replace any drawn icon by your own picture, without touching code.

	  IconOverrides.Images = {
	      coin = "rbxassetid://1234567890",      -- every place that shows the "coin" icon now shows your image
	      trophy = "rbxassetid://9876543210",
	  }

	How: upload a square PNG in Roblox Studio (View > Asset Manager > Images > Bulk Import), copy its id, paste it here.
	The names are the icon ids of UI/Icons.luau (the list is also in docs/STUDIO_GUIDE.md). An entry that is not written exactly
	like "rbxassetid://<digits>" is ignored, so a typo can never break a window. It starts empty: no image id is invented.
	You can also give a single item its own picture by putting the "rbxassetid://<digits>" text directly in its Icon field.
]]

local IconOverrides = {}

IconOverrides.Images = {} :: { [string]: string }

function IconOverrides.imageFor(id: string): string?
	local candidate = if string.sub(id, 1, 13) == "rbxassetid://" then id else IconOverrides.Images[id]
	if type(candidate) == "string" and string.match(candidate, "^rbxassetid://%d+$") then
		return candidate
	end
	return nil
end

return IconOverrides
