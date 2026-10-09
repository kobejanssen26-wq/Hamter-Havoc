-- Builds the wheel with the game's own wheel builder (HouseBuilder/Wheels.luau), so the file always matches the game.
--
-- Local frame of the exported model (pivot = PrimaryPart "WheelBase" with PivotOffset, i.e. the bottom centre of the stand):
--   +Y up, hamster runs towards +X (attribute RunDirection), the axle runs along Z through the hub, hub height = Wheels.CenterAboveFloor.
return function(ctx)
	local Wheels = ctx.module("ServerScriptService.Systems.WorldBuilder.HouseBuilder.Wheels")

	local model = ctx.new("Model", ctx.Config.Name, ctx.Scratch)
	local frame = ctx.new("Folder", "Frame", ctx.Scratch)
	-- the game places a wheel at slot.Center; here the floor is y = 0 and the hub is above the origin
	local slot = { Frame = frame, Center = CFrame.new(0, Wheels.CenterAboveFloor, 0) }
	Wheels.build({ CFrame = CFrame.identity }, slot)

	for _, child in frame:GetChildren() do
		child.Parent = model
	end
	frame:Destroy()

	local base = model:FindFirstChild("WheelBase")
	assert(base, "WheelBase missing: the wheel builder changed")
	base.PivotOffset = CFrame.new(0, -base.Size.Y / 2, 0) -- pivot = floor level under the hub
	model.PrimaryPart = base

	local wheel = model:FindFirstChild("Wheel")
	assert(wheel and wheel.PrimaryPart, "inner Wheel model / hub missing")
	-- `Wheel` carries the attributes the game's client controller reads (Speed in rad/s, RunDirection = direction the hamster runs)
	wheel:SetAttribute("Speed", ctx.Config.Speed)

	ctx.libraryScript(model, "WheelSpin.client.luau")
	return model
end
