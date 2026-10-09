-- Export definition of the hamster wheel. Read by tools/ExportModels (never by the game).
return {
	Name = "Hamster_Wheel",
	Title = "Hamster Wheel",
	Category = "Wheels",
	File = "Hamster_Wheel.rbxm",
	RootClass = "Model",
	MinParts = 12,
	Speed = 3, -- default spin speed in radians per second (attribute `Speed` on the inner `Wheel` model)
	Dependencies = "WheelSpin script (bundled) turns it; without a controller it is a static model",
	Reusable = "Yes",
}
