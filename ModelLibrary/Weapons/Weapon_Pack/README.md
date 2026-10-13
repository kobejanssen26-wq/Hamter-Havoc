# Weapon Pack

Every weapon of the game as a ready-made Roblox `Tool`, built by the game's own `ToolBuilder` (so it is exactly what players hold).

- Root: `Folder` "Weapon_Pack"; children: one `Tool` per weapon, each with a `Handle` part and welded, massless, non-colliding parts.
- Attributes: `ItemId`, `WeaponType` (the server uses the item file, not these, to decide what a weapon does).
- Orientation: long along Z, business end at -Z, `Tool.Grip` places the hand.
- To use your own version: edit the Tool in Studio, put it in `ReplicatedStorage > Assets > Tools`, then set `ModelName = "<Tool name>"` in the weapon's file in `Modules/Content/Items`.
