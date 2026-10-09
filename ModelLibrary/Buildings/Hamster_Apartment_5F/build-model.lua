-- The complete apartment lot (yard, security portal, 5-floor tower with elevator, roof) with all 40 wheels, built by the game's HouseBuilder.
-- Pivot (PrimaryPart "Pivot") = the middle of the gate line on the ground; +Z runs into the lot, -Z is the street.
return function(ctx)
	local HouseBuilder = ctx.module("ServerScriptService.Systems.WorldBuilder.HouseBuilder")
	local FloorConfig = ctx.module("ReplicatedStorage.Modules.FloorConfig")
	local rng = Random.new(3)

	local house = HouseBuilder.build(ctx.Scratch, 1, CFrame.identity, rng)
	HouseBuilder.setFloors(house, FloorConfig.MaxFloors, rng)
	for index in house.Slots do
		HouseBuilder.setWheel(house, index, true)
	end
	HouseBuilder.setStars(house, 5)
	house.Labels.Roof.Text = "Hamster Apartments"
	house.Labels.Name.Text = "Hamster Apartments"
	house.Labels.Stats.Text = "5 floors"
	house.Labels.Best.Text = ""
	for upgradeId in house.Stations do
		HouseBuilder.setStation(house, upgradeId, 5, 25)
	end
	HouseBuilder.setSecurity(house, "Active", ctx.module("ReplicatedStorage.Modules.SecurityConfig").tier(6))

	local model = house.Model
	model.Name = ctx.Config.Name
	for _, attribute in { "HouseId", "OwnerUserId", "OwnerName", "SecState", "SecUntil", "SecReady", "SecTier" } do
		model:SetAttribute(attribute, nil) -- runtime state of the game, not part of the asset
	end
	ctx.pivotPart(model, CFrame.identity)
	return model
end
