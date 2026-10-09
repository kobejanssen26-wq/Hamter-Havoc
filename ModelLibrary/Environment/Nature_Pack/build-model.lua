-- Builds every item with the game's own decoration builder (WorldBuilder/Decor.luau), in a row along +X, 14 studs apart.
-- Each item is a Model whose PrimaryPart "Pivot" sits on the ground under it.
return function(ctx)
	local Decor = ctx.module("ServerScriptService.Systems.WorldBuilder.Decor")
	local rng = Random.new(7)
	local pack = ctx.new("Folder", ctx.Config.Name, ctx.Scratch)

	local items = {
		{ "Tree_Round", function(pos) return Decor.tree(pack, pos, "round", 1, rng) end },
		{ "Tree_Pine", function(pos) return Decor.tree(pack, pos, "pine", 1, rng) end },
		{ "Tree_Cherry", function(pos) return Decor.tree(pack, pos, "cherry", 1, rng) end },
		{ "Bush", function(pos) return Decor.bush(pack, pos, 1, rng, false) end },
		{ "Bush_Berries", function(pos) return Decor.bush(pack, pos, 1, rng, true) end },
		{ "Rock", function(pos) return Decor.rock(pack, pos, 1.5, rng) end },
		{ "Stump", function(pos) return Decor.stump(pack, pos, 1) end },
		{ "Mushrooms", function(pos) return Decor.mushrooms(pack, pos, rng) end },
		{ "Flowers", function(pos) return Decor.flowers(pack, pos, 3, 12, rng) end },
		{ "Sunflower", function(pos) return Decor.sunflower(pack, pos, 1) end },
	}
	for index, item in items do
		local pos = Vector3.new((index - 1) * 14, 0, 0)
		local model = item[2](pos)
		model.Name = item[1]
		ctx.pivotPart(model, CFrame.new(pos))
	end
	-- a hedge needs two end points
	local hedge = Decor.hedgeRun(pack, Vector3.new(#items * 14 - 5, 0, 0), Vector3.new(#items * 14 + 7, 0, 0), rng)
	hedge.Name = "Hedge_Segment"
	ctx.pivotPart(hedge, CFrame.new(#items * 14 + 1, 0, 0))
	return pack
end
