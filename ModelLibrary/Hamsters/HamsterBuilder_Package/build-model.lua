-- The game's hamster generator: HamsterBuilder (+ Toolkit, Faces, Hats, Gear, Wings), HamsterDatabase (172 species) and RarityConfig.
-- Sources are the CURRENT files of the game. Usage is documented in the README next to this file.
return function(ctx)
	local package = ctx.new("Folder", ctx.Config.Name, ctx.Scratch)
	local builder = ctx.gameModule(package, "src/ReplicatedStorage/Modules/HamsterBuilder/init.luau", "HamsterBuilder")
	ctx.gameModule(builder, "src/ReplicatedStorage/Modules/HamsterBuilder/Toolkit.luau", "Toolkit")
	ctx.gameModule(builder, "src/ReplicatedStorage/Modules/HamsterBuilder/Faces.luau", "Faces")
	ctx.gameModule(builder, "src/ReplicatedStorage/Modules/HamsterBuilder/Hats.luau", "Hats")
	ctx.gameModule(builder, "src/ReplicatedStorage/Modules/HamsterBuilder/Gear.luau", "Gear")
	ctx.gameModule(builder, "src/ReplicatedStorage/Modules/HamsterBuilder/Wings.luau", "Wings")
	ctx.gameModule(package, "src/ReplicatedStorage/Modules/HamsterDatabase.luau", "HamsterDatabase")
	ctx.gameModule(package, "src/ReplicatedStorage/Modules/RarityConfig.luau", "RarityConfig")
	return package
end
