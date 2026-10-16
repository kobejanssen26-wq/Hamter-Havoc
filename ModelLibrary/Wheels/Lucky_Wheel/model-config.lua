-- Export definition of the standalone Lucky Wheel. Read by tools/ExportModels (never by the game).
return {
	Name = "Lucky_Wheel",
	Title = "Lucky Wheel (one free spin per hour, self-contained)",
	Category = "Wheels",
	File = "Lucky_Wheel.rbxm",
	RootClass = "Model",
	MinParts = 40,
	Dependencies = "None: the bundled server script LuckyWheel runs the spin by itself (prompt, hourly cooldown, animation, Won event)",
	Reusable = "Yes",
}
