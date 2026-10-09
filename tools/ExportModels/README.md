# ExportModels - turns the game's reusable assets into genuine Roblox model files

Output: `ModelLibrary/<Category>/<Asset>.rbxm` (binary Roblox models, importable with *Insert from File...*), plus the catalog `ModelLibrary/README.md`.

```
python3 tools/ExportModels/export_models.py            # build everything; new files are written, CHANGED files are only reported
python3 tools/ExportModels/export_models.py --update   # also replace files whose content changed (git keeps the old version)
python3 tools/ExportModels/export_models.py --check    # CI / pre-commit: exit 1 if any export is missing or out of date
python3 tools/ExportModels/export_models.py --only Hamster_Wheel
python3 tools/ExportModels/export_models.py --hamsters-zip Hamster_Models.zip   # all 172 species as separate .rbxm files (one folder per rarity); not stored in the repo
python3 tools/ExportModels/export_models.py --test     # behaviour tests (wheel direction / axle / pivot, hamster joints, packages, no asset ids)
python3 tools/ExportModels/inspect_model.py ModelLibrary/Hamsters/Hamster_Default.rbxm --depth 2 [--props]   # look inside any .rbxm
```

Requirements: Python 3.9+, [`rojo`](https://rojo.space) (`rokit install` installs the version pinned in `rokit.toml`) and the [`luau`](https://github.com/luau-lang/luau/releases) command-line
interpreter (`rokit add luau-lang/luau`, or download it and set `$LUAU`). `$ROJO` / `$LUAU` can point at the binaries.

## Why this way - and what it is not

Roblox Studio is **not** available in the cloud environment this project is developed in, so the `.rbxm` files are **not** saved by Studio. Instead:

1. `harness/` is a small mock of the Roblox runtime (`mock.lua`, API names validated against Roblox's official type definitions in `classes.lua`) that can *execute the game's real
   Luau modules* (`harness/gen.py` wraps `src/` according to `default.project.json`).
2. `exporter/run_assets.lua` (with `context.lua` + `serialize.lua`) runs every `ModelLibrary/**/build-model.lua` there. Those files call the game's own builders (`HamsterBuilder`, `Wheels`, `Decor`, `HouseBuilder`, ...),
   so an exported asset is, by construction, the asset the game builds. The result is validated (root class/name, pivot, Motor6D parts, sizes) and printed as JSON.
3. `export_models.py` turns that JSON into a Rojo project and lets **Rojo** write the model: Rojo knows the type of every property and the numeric value of every enum, and writes the
   binary `.rbxm` format. Two things Rojo's project format cannot express are patched in between: *duplicate sibling names* and *instance references* (`PrimaryPart`, `Motor6D.Part0/Part1`,
   `WeldConstraint.Part0/Part1`). The final file is read back and verified (instance count, classes, names, every reference, script sources byte-for-byte).

So the files are real Roblox binary models produced by the same library (rbx-dom) Rojo uses to build places, and the whole pipeline is reproducible and deterministic
(`--check` proves it). What has **not** been done: opening them in Roblox Studio itself. Please insert them once into a test place - if anything differs, tell me, or use
the Studio route below, which produces the file with Studio's own serializer.

Not exported: particle emitters / beams / trails (NumberSequence & ColorSequence properties are not supported by the pipeline - the exporter prints a warning if an asset contains one),
Terrain, sounds. That is why there is no `Effects/` folder: the game's effects are created at runtime by `FxController`, not stored as models.

## Adding or changing an asset

Create `ModelLibrary/<Category>/<Asset>/` with

| File | Purpose |
|---|---|
| `model-config.lua` | `return { Name, Title, Category, File, RootClass, MinParts, Dependencies, Reusable, ... }` (see an existing one) |
| `build-model.lua` | `return function(ctx) ... return rootInstance end` - builds the asset with the game's modules |
| `scripts/` | library-only scripts (`X.client.luau` = Script with RunContext Client, `X.server.luau`, `X.luau` = ModuleScript) added with `ctx.libraryScript(parent, "X.client.luau")` |
| `README.md` | hierarchy, pivot, dependencies, attributes, usage (hand-written; the catalog row is generated) |

`ctx` helpers: `ctx.module("ReplicatedStorage.Modules.X")` (a game module), `ctx.new(class, name, parent)`, `ctx.set`, `ctx.attr`, `ctx.pivotPart(model, cframe)`,
`ctx.libraryScript`, `ctx.gameModule(parent, "src/....luau", name)` (packages the *current* source of a game file; the path must appear as a string literal), `ctx.buildAsset(name, options)` (compose assets),
`ctx.Options`, `ctx.Config`. Scripts shared by several assets go in `ModelLibrary/_shared/scripts/` (`"shared/X.client.luau"`).
Then run `export_models.py --update` and `--test`, and commit the `.rbxm`, the asset folder and the catalog together.

### Keeping the library in sync

The exported file must match the game. Whenever a reusable model or one of the builders it uses changes (`src/.../HamsterBuilder`, `Wheels.luau`, `Decor.luau`, `HouseBuilder/`, `HamsterAnimator.luau`, `Icons.luau`):
run `export_models.py --update` and commit the result. `--check` fails if you forgot.

## Studio route (for models you make by hand)

`plugin/ExportToModelLibrary.server.luau` is a Studio plugin: select one model, press **Export to Library**. It validates (pivot, scripts that touch DataStores / HttpService / secrets,
external asset ids), prints a report, and opens Studio's save dialog with the suggested name `<Category>__<Name>`; save it as `ModelLibrary/<Category>/<Name>.rbxm`. (Studio cannot write into a
folder by itself, and its dialog asks before replacing a file.) Run `export_models.py` afterwards: hand-saved models are listed in the catalog as "saved from Studio". This plugin is
**untested** - it could not be run without Studio; the fallback is *Explorer -> right-click the model -> Save to File...*.
