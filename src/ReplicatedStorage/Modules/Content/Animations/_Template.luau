--[[
	ANIMATION TEMPLATE - copy it, name the file like the animation (e.g. Hamster_Walk.luau), edit it.
	Upload your animation in Roblox Studio (Animation Editor -> ... -> Publish to Roblox) and paste the id below.
	This template is ignored by the game. Full guide: docs/CONTENT_GUIDE.md
]]
return {
	Enabled = false,

	Name = "My_Animation", -- unique, letters/digits/underscores; the name other configs refer to
	AssetId = "", -- "rbxassetid://<number>" after you uploaded it. Empty = skipped, nothing breaks
	Rig = "R15", -- R15 | R6 | Hamster | Any
	Use = "Emote", -- Idle | Walk | Run | Emote | Action | Hamster | Cosmetic

	Priority = "Action", -- Enum.AnimationPriority name: Core Idle Movement Action Action2 Action3 Action4
	Looped = false,
	Speed = 1,
	FadeTime = 0.15,
}
