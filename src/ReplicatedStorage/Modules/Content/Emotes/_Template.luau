--[[
	EMOTE TEMPLATE - copy it, rename the file, edit it. This template is ignored by the game.
	Choose ONE way to define the animation:
	  Builtin = "wave"                      Roblox's own default emotes: wave, point, dance, dance2, dance3, laugh, cheer
	  AnimationId = "rbxassetid://<number>" your own animation (R15 recommended), uploaded to Roblox
	  Animation = "My_Animation"            a name from Content/Animations
	Full guide: docs/CONTENT_GUIDE.md
]]
return {
	Enabled = false,

	Id = "my_emote", -- stable id: lowercase letters, digits, underscores
	DisplayName = "My Emote",
	Icon = "star", -- a drawn icon from UI/Icons.luau (run Icons.names() for the list)
	Builtin = "wave",
	Default = true, -- true: everybody has it. false: needs the Unlock below
	-- Unlock = { MinRebirth = 1 },
	-- Sound = "Emote", -- name from AudioConfig.Sfx played when the emote starts
	Order = 90, -- position in the wheel (lower = earlier)
}
