-- The game's own Lucky Wheel (WorldBuilder/LuckyWheelBuilder.luau), exported as a model that works on its own: drop it into
-- Workspace and it spins. The bundled server script gives one free spin per player per hour (attribute CooldownSeconds) and
-- announces the prize on the BindableEvent `Won` (player, prizeId, prizeName) and on the attribute LastPrize, so any game can
-- hook its own rewards in. Slices are the parts Rotor/Slice_*; rename / recolour / add slices in Studio, the script adapts.
-- Pivot = the ground point under the platform (PrimaryPart "Base").
return function(ctx)
	local Builder = ctx.module("ServerScriptService.Systems.WorldBuilder.LuckyWheelBuilder")

	local scratch = ctx.new("Folder", "Scratch", ctx.Scratch)
	local model = Builder.build(scratch, Random.new(1))
	-- the builder also adds a bench and flowers to the plaza next to it: not part of the wheel
	for _, child in scratch:GetChildren() do
		if child ~= model then
			child:Destroy()
		end
	end
	model.Name = ctx.Config.Name
	model.Parent = ctx.Scratch
	scratch:Destroy()

	local base = model:FindFirstChild("Base")
	assert(base, "Base missing: the wheel builder changed")
	local center = Builder.CENTER
	-- move the model to the origin so the pivot is the ground point under the platform
	local shift = CFrame.new(-center.X, 0, -center.Z)
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame = shift * part.CFrame
		end
	end
	model.PrimaryPart = base
	base.PivotOffset = CFrame.new(0, -base.Size.Y / 2, 0)
	local pad = model:FindFirstChild("PromptPad")
	if pad then
		pad:SetAttribute("TutorialTarget", nil)
		pad:RemoveTag("TutorialTarget")
	end
	model:SetAttribute("CooldownSeconds", 3600)
	model:SetAttribute("SpinSeconds", 6)
	model:SetAttribute("BaseCFrame", nil)
	model:RemoveTag("LuckyWheel")

	ctx.libraryScript(model, "LuckyWheel.server.luau")
	return model
end
