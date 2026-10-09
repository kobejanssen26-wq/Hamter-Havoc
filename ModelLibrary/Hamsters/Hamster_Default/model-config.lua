-- Export definition of the default hamster. Read by tools/ExportModels (never by the game).
return {
	Name = "Hamster_Default",
	Title = "Default Hamster (Brownie)",
	Category = "Hamsters",
	File = "Hamster_Default.rbxm",
	Species = "brownie", -- id in src/ReplicatedStorage/Modules/HamsterDatabase.luau
	RootClass = "Model",
	MinParts = 20,
	Dependencies = "None to display. HamsterAutoAnimate + HamsterAnimator (bundled) animate it on the client",
	Reusable = "Yes",
}
