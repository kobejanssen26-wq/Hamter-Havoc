-- The game's current icon module, packaged as a ModuleScript. Icons are drawn from Frames / UICorner / UIStroke / UIGradient,
-- so they need no image assets and work on every device.
return function(ctx)
	return ctx.gameModule(ctx.Scratch, "src/StarterPlayer/StarterPlayerScripts/UI/Icons.luau", "Icons")
end
