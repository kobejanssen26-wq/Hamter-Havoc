-- Composes the library's Hamster_Wheel and Hamster_Default exactly like the game does when a hamster works on a wheel
-- (HouseSystem: hamster scaled to fit the wheel, standing on the wheel floor facing the run direction, wheel speed 3 rad/s, run animation 7).
return function(ctx)
	local Wheels = ctx.module("ServerScriptService.Systems.WorldBuilder.HouseBuilder.Wheels")
	local HamsterDatabase = ctx.module("ReplicatedStorage.Modules.HamsterDatabase")

	local assembly = ctx.buildAsset("Hamster_Wheel")
	assembly.Name = ctx.Config.Name

	local species = HamsterDatabase.ById["brownie"]
	local MAX_DISPLAY_HEIGHT = 1.9 -- same limit as HouseSystem: the hamster has to fit inside the wheel
	local scale = math.min(0.5, MAX_DISPLAY_HEIGHT / (3.4 * (species.Size or 1)))
	local hamster = ctx.buildAsset("Hamster_Default", { Scale = scale })
	hamster.Name = "Hamster"

	-- stand on the bottom of the wheel, facing +X (the wheel's RunDirection)
	local runCFrame = CFrame.new(0, Wheels.CenterAboveFloor - Wheels.Radius + 0.1, 0) * CFrame.Angles(0, -math.pi / 2, 0)
	hamster:PivotTo(assembly:GetPivot() * runCFrame)
	hamster:SetAttribute("MoveSpeed", 7)
	hamster.Parent = assembly
	return assembly
end
