# Nature_Pack

Low-poly cozy nature props built from primitives: three trees, two bushes, rock, stump, mushrooms, flower patch, sunflower and a hedge segment.

| | |
|---|---|
| File | [`../Nature_Pack.rbxm`](../Nature_Pack.rbxm) (97 instances) |
| Layout | a Folder with 11 models in a row along +X, 14 studs apart (drag individual models out) |
| Pivot | every model has `PrimaryPart = Pivot` (invisible, anchored) on the **ground** under it, so `PivotTo(CFrame.new(x, groundY, z))` places it correctly |
| External assets | none |
| Needs a controller? | No. Trees carry the tag `TreeSway`; the sunflower the tag `Sway` (attributes `Amplitude`, `Speed`) - purely optional hooks for your own animation |

Models: `Tree_Round`, `Tree_Pine`, `Tree_Cherry`, `Bush`, `Bush_Berries`, `Rock`, `Stump`, `Mushrooms`, `Flowers`, `Sunflower`, `Hedge_Segment`.
Only the trunks collide (canopy parts are non-collidable) so players can walk through bushes. Scale a model with `model:ScaleTo(1.5)`.

Source: `build-model.lua` calls the game's `WorldBuilder/Decor.luau` with a fixed random seed (so the export is reproducible).
Regenerate: `python3 tools/ExportModels/export_models.py --update`.
