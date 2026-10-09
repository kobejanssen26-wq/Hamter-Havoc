-- Builds every item with the game's own decoration builder (WorldBuilder/Decor.luau), in a row along +X, 14 studs apart.
return function(ctx)
	local Decor = ctx.module("ServerScriptService.Systems.WorldBuilder.Decor")
	local rng = Random.new(11)
	local pack = ctx.new("Folder", ctx.Config.Name, ctx.Scratch)

	local items = {
		{ "Bench", function(pos) return Decor.bench(pack, CFrame.new(pos)) end },
		{ "Lamp_Post", function(pos) return Decor.lamp(pack, pos, 7) end },
		{ "Signpost", function(pos) return Decor.signpost(pack, CFrame.new(pos), "WELCOME", nil) end },
		{ "Barrel", function(pos) return Decor.barrel(pack, pos) end },
		{ "Crate", function(pos) return Decor.crate(pack, pos, 0.3) end },
		{ "Flag", function(pos) return Decor.flag(pack, pos, Color3.fromRGB(232, 112, 104)) end },
		{ "Balloon", function(pos) return Decor.balloon(pack, pos, Color3.fromRGB(104, 160, 224)) end },
		{ "Pond", function(pos) return Decor.pond(pack, pos, 5, rng) end },
		{ "Windmill", function(pos) return Decor.windmill(pack, pos, 0) end },
	}
	for index, item in items do
		local pos = Vector3.new((index - 1) * 16, 0, 0)
		local model = item[2](pos)
		model.Name = item[1]
		ctx.pivotPart(model, CFrame.new(pos))
	end
	local fence = Decor.fenceRun(pack, Vector3.new(#items * 16 - 6, 0, 0), Vector3.new(#items * 16 + 8, 0, 0), nil)
	fence.Name = "Fence_Segment"
	ctx.pivotPart(fence, CFrame.new(#items * 16 + 1, 0, 0))

	ctx.libraryScript(pack, "shared/AnimateTaggedProps.client.luau")
	return pack
end
