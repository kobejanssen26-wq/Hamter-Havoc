-- Attack animation of the "SpringGlove" weapon (referenced by Weapon.Animation in Content/Items). NOT UPLOADED YET: until AssetId is set the
-- built-in procedural swing is used, so the weapon always animates. To make your own: docs/COMBAT_GUIDE.md ("Weapon animations").
return {
	Name = "Weapon_SpringGlove",
	AssetId = "", -- paste "rbxassetid://<number>" after you publish the animation
	Rig = "R15",
	Use = "Action",
	Priority = "Action2", -- above walk / idle (Movement) and above emotes (Action): a swing always shows, even while running
	Looped = false,
	FadeTime = 0.05,
}
