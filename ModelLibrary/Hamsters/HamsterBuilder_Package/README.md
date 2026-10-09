# HamsterBuilder_Package

The hamster generator of Hamster Plaza as three linked ModuleScripts: build any of the **172 species** (14 rarities) in code, in any experience.
This is a code package, not a 3D model - the 3D example is [`Hamster_Default`](../Hamster_Default/README.md).

| | |
|---|---|
| File | [`../HamsterBuilder_Package.rbxm`](../HamsterBuilder_Package.rbxm) (10 instances: Folder + 9 ModuleScripts) |
| Contents | `HamsterBuilder` (+ children `Toolkit`, `Faces`, `Hats`, `Gear`, `Wings`), `HamsterDatabase`, `HamsterNames` (display names), `RarityConfig` |
| External assets | none |
| Needs a controller? | Building does not. To animate, also use `HamsterAnimator` from `Hamster_Default` |

Keep `HamsterBuilder`, `HamsterDatabase`, `HamsterNames` and `RarityConfig` **in the same folder** (they find each other with `script.Parent`).

## Use it

```lua
-- put the folder anywhere both sides can see, e.g. ReplicatedStorage
local package = game.ReplicatedStorage.HamsterBuilder_Package
local HamsterBuilder = require(package.HamsterBuilder)
local HamsterDatabase = require(package.HamsterDatabase)

local species = HamsterDatabase.ById.brownie               -- or HamsterDatabase.Species[n]; HamsterDatabase.Total == 172
local hamster = HamsterBuilder.build(species, { Scale = 1, LowDetail = false, Particles = false })
hamster.Parent = workspace
hamster:PivotTo(CFrame.new(0, 5, 0))
```

Build options: `Scale` (model scale), `LowDetail` (fewer decoration parts), `Particles = false` drops the aura particle emitters of high rarities (default: kept). Useful: `HamsterDatabase.ByRarity[...]`, `HamsterBuilder.frameCamera(model)`
for ViewportFrame icons. The built model has the same rig as `Hamster_Default` (PrimaryPart `Root`, 9 `*J` Motor6Ds, facing -Z).

## Notes

`HamsterDatabase` also contains the game's prices / incomes (`HamsterDatabase.price(species)`); ignore them in another game. It contains no player data and no DataStore code.

## Source / regenerate

The scripts are copies of the **current** files under `src/ReplicatedStorage/Modules/` taken by `build-model.lua` - edit the game files, not the package.
`python3 tools/ExportModels/export_models.py --update`.
