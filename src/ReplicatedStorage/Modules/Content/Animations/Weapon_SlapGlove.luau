-- Attack animation of the "SlapGlove" weapon (referenced by Weapon.Animation in Content/Items). NOT UPLOADED YET: until AssetId is set the
-- built-in procedural swing is used, so the weapon always animates. To make your own: docs/COMBAT_GUIDE.md ("Weapon animations").
return {
	Name = "Weapon_SlapGlove",
	AssetId = "", -- paste "rbxassetid://<number>" after you publish the animation
	Rig = "R15",
	Use = "Action",
	Priority = "Action", -- above walk / idle so it plays while running, below Action2+ used by emotes
	Looped = false,
	FadeTime = 0.05,
}
