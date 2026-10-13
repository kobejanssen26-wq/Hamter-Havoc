-- Builds every weapon Tool with the game's own ToolBuilder, one per item in Content/Items. To customise a weapon:
-- Insert this file in Studio, edit a Tool's parts (keep the part named Handle), copy it into ReplicatedStorage/Assets/Tools
-- and set  ModelName = "<Tool name>"  in the weapon's item file. See docs/COMBAT_GUIDE.md.
return function(ctx)
	local ToolBuilder = ctx.module("ServerScriptService.Systems.ToolBuilder")
	local ItemRegistry = ctx.module("ReplicatedStorage.Modules.ItemRegistry")
	local pack = ctx.new("Folder", ctx.Config.Name, ctx.Scratch)
	for _, def in ItemRegistry.List do
		if def.Equip.Kind == "Tool" then
			local tool = ToolBuilder.build(def)
			tool.Parent = pack
		end
	end
	return pack
end
