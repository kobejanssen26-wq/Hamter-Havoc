# Hamster_Default

The default hamster ("Brownie", a Basic hamster of Hamster Plaza), fully rigged and animated by a bundled client script.

| | |
|---|---|
| Model file | [`../Hamster_Default.rbxm`](../Hamster_Default.rbxm) (binary Roblox model, 86 instances) |
| Size | 3.89 x 3.76 x 4.01 studs, facing **-Z** (front = `LookVector`) |
| Pivot | `PrimaryPart` = invisible anchored part `Root` at the feet; the lowest point of the model is y = -0.1 |
| External assets | none (everything is built from parts, no mesh / texture / sound ids) |
| Works alone? | Yes as a static model. With the two bundled scripts it also animates itself (client side) |

## Hierarchy

```
Hamster_Default (Model, PrimaryPart = Root)
├─ Root                      anchored, invisible, CanCollide off - the pivot
├─ Body, Head, PawFL/FR/BL/BR, EarL, EarR, Tail      (unanchored, Massless, welded through Motor6D)
├─ Belly, Cheek x2, Muzzle, Nose, Blush x2, Whisker x6, EarLInner, EarRInner, Eye x2, EyeShine x2, Smile x2
│                            decoration parts, welded with WeldConstraint
├─ Motor6D  BodyJ HeadJ PawFLJ PawFRJ PawBLJ PawBRJ EarLJ EarRJ TailJ      the 9 animated joints
├─ HamsterAnimator           ModuleScript (the game's procedural animator, no animation assets)
└─ HamsterAutoAnimate        Script, RunContext = Client: drives HamsterAnimator every frame
```

## Attributes

| Attribute | Meaning |
|---|---|
| `MoveSpeed` (number) | **Set this from your own code.** 0 = idle (breathing, tail wag, ear twitch, random behaviours), > 0 = running cycle (about studs/second; the game uses 7 on a wheel) |
| `ModelScale` | size factor of this export (1). The animator scales joint movement with it, because a saved file does not remember `Model:ScaleTo()` |
| `SpeciesId`, `Rarity`, `Height` | information only |

## Dependencies

* Scripts: `HamsterAutoAnimate` + `HamsterAnimator` are **inside** the file. They only use `RunService.RenderStepped`, `Motor6D.Transform` and the model's own joints.
  Because `Motor6D.Transform` is set on the client, other players do not see the animation unless they also run the script - which they do, since it is a Client script inside the model.
* No remotes, DataStores, services or other models are needed. Delete both scripts if you want to animate it yourself (the 9 `*J` Motor6Ds are the joint names the animator uses).
* To move the hamster through the world use `model:PivotTo(cframe)` (the Root is anchored). Hamster movement / pathing is *not* part of this asset.

## Use it

1. Download `Hamster_Default.rbxm` (see [`../../README.md`](../../README.md)), Studio -> right-click Workspace -> **Insert from File...**
2. In a script: `hamster:SetAttribute("MoveSpeed", 8)` to make it run, `0` to stand.
3. Want other species (all 172)? Use [`HamsterBuilder_Package`](../HamsterBuilder_Package.rbxm).

## Source / regenerate

`model-config.lua` (species id, checks) and `build-model.lua` (calls the game's `HamsterBuilder`, bundles the *current* `HamsterAnimator.luau`) define the export;
`scripts/HamsterAutoAnimate.client.luau` is the only library-specific code. Regenerate with
`python3 tools/ExportModels/export_models.py --update`.
