-- The 8 upgrade pedestals of the apartments, fully upgraded (fraction 1), built with HouseBuilder/Props.luau.
-- Every station is a Model; its PrimaryPart "Pivot" is the floor point under the pedestal. Stations stand 8 studs apart along +X.
return function(ctx)
	local Props = ctx.module("ServerScriptService.Systems.WorldBuilder.HouseBuilder.Props")
	local Build = ctx.module("ServerScriptService.Systems.WorldBuilder.Build")
	local Palette = ctx.module("ServerScriptService.Systems.WorldBuilder.Palette")
	local UpgradeConfig = ctx.module("ReplicatedStorage.Modules.UpgradeConfig")

	local pack = ctx.new("Folder", ctx.Config.Name, ctx.Scratch)
	for index, id in UpgradeConfig.Order do
		local x = (index - 1) * 8
		local station = ctx.new("Model", "Station_" .. id, pack)
		station:SetAttribute("UpgradeId", id)
		station:SetAttribute("UpgradeName", UpgradeConfig.Definitions[id].Name)
		-- pedestal exactly like the one in the apartment
		Build.pillar(station, "StationBase", 2.6, 1.8, CFrame.new(x, 0.9, 0), Palette.Cream, Enum.Material.SmoothPlastic)
		Build.pillar(station, "StationPlate", 3, 0.25, CFrame.new(x, 1.9, 0), Palette.WoodLight, Enum.Material.WoodPlanks, { CanCollide = false })
		local props = ctx.new("Folder", "Prop", ctx.Scratch)
		Props.Upgrade[id](props, CFrame.new(x, 2.05, 0), 1, 0)
		for _, child in props:GetChildren() do
			child.Parent = station
		end
		props:Destroy()
		ctx.pivotPart(station, CFrame.new(x, 0, 0))
	end
	ctx.libraryScript(pack, "shared/AnimateTaggedProps.client.luau")
	return pack
end
