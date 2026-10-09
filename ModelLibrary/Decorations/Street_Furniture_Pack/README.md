# Street_Furniture_Pack

Bench, lamp post (with PointLight), signpost (SurfaceGui text), barrel, crate, flag, balloon, pond, windmill and a fence segment.

| | |
|---|---|
| File | [`../Street_Furniture_Pack.rbxm`](../Street_Furniture_Pack.rbxm) (80 instances) |
| Layout | a Folder with 10 models in a row along +X, 16 studs apart |
| Pivot | every model: `PrimaryPart = Pivot` on the ground under it |
| External assets | none |
| Controller | optional bundled `AnimateTaggedProps` (Script, Client) |

`AnimateTaggedProps` animates only objects inside the pack, using these tags/attributes: `Sway` (flag: `Amplitude`, `Speed`, `Axis`), `Bob` (balloon), `SpinModel`
(windmill blades: `Speed`, `Axis`), and the `Ripple` attribute (pond water shimmer). Delete the script for completely static props. To change the signpost text, edit the `TextLabel`
inside its `SurfaceGui`.

Source: `build-model.lua` (game's `WorldBuilder/Decor.luau`); the shared script lives in `ModelLibrary/_shared/scripts/`. Regenerate: `python3 tools/ExportModels/export_models.py --update`.
