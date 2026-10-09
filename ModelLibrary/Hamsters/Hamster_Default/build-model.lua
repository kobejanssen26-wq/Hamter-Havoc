-- Builds the exported model with the game's own hamster builder, so the file always matches the game.
-- Also bundles the game's CURRENT client animator ("src/StarterPlayer/StarterPlayerScripts/Controllers/HamsterAnimator.luau").
return function(ctx)
	local HamsterBuilder = ctx.module("ReplicatedStorage.Modules.HamsterBuilder")
	local HamsterDatabase = ctx.module("ReplicatedStorage.Modules.HamsterDatabase")
	local species = assert(HamsterDatabase.ById[ctx.Config.Species], "unknown species " .. ctx.Config.Species)

	local model = HamsterBuilder.build(species, { Scale = ctx.Options.Scale or 1, LowDetail = false, Particles = false })
	model.Name = ctx.Config.Name
	model:PivotTo(CFrame.new(0, 0, 0))
	model.Parent = ctx.Scratch

	-- configuration the bundled controller reads
	-- Roblox does not keep Model:ScaleTo() factors in a saved file (the parts are already scaled), so the animator is told the size explicitly
	ctx.attr(model, { ModelScale = model:GetScale() })
	ctx.attr(model, { MoveSpeed = 0 }) -- studs/second the hamster is moving at; 0 = idle animations

	ctx.gameModule(model, "src/StarterPlayer/StarterPlayerScripts/Controllers/HamsterAnimator.luau", "HamsterAnimator")
	ctx.libraryScript(model, "HamsterAutoAnimate.client.luau")
	return model
end
