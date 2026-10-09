# Hamster Plaza - Models (asset library)

Every reusable visual asset of the game, stored **once**, in formats you can open anywhere:

| File | What it is | Open with |
|---|---|---|
| `Name.rbxm` | Roblox model, ready to use | Roblox Studio: drag the file into the viewport, or right-click Workspace > *Insert from File* |
| `Name.glb` | 3D model (glTF 2.0 binary), colours as materials, 1 unit = 1 stud, Y up | Blender, Windows 3D Viewer, <https://gltf-viewer.donmccurdy.com>, Studio *Import 3D* |
| `metadata.json` | name, category, size, part count, source function, stats | any text editor |
| `_preview.png` (per folder) | contact sheet of every asset in that folder | browser / GitHub |
| `UI/Icons/*.png` | every UI icon, 256 x 256, transparent | any image viewer; upload to Roblox as Decal/Image |

The full list with sizes and hamster stats is in **[ASSET_INDEX.md](ASSET_INDEX.md)** (generated).

## Folders

```
Models/
  Hamsters/<Rarity>/<Rarity>Hamster<Name>/   all 172 hamsters, one folder per rarity (Basic ... Unknown)
  Buildings/Apartment/                         modular apartment: Floor01 ... Floor05, Roof, Lift, Scaffold,
                                               EntranceGate, Lot, PrestigeTrims
  Buildings/Plaza/                             ShopStall, HamsterLibrary, PlazaArch, RecentFindsBoard
  HamsterWheel/                                BasicWheel, AdvancedWheel, PremiumWheel
  Environment/                                 Mountain, SnowMountain, Hill, Lake, Pond, Cloud, Rock, Windmill, BurrowHill
  Trees/                                       PineTree, RoundTree, CherryTree, LargeGreenTree, LargeDarkTree, ...
  Plants/                                      Bush, BerryBush, FlowerPatch, Sunflower, flower beds, Hedge, PottedPlant, ...
  Furniture/                                   Sofa, Bench, Rug, CeilingLight, GlassRailing
  Decorations/                                 StreetLamp, GardenLamp, PicketFence, Signpost, Flag, Balloon
  Props/  Props/Stations/                      Barrel, Crate; the props on the upgrade pedestals
  Animals/                                     Bird
  Effects/                                     Fireflies (particle emitter, no mesh)
  Vehicles/  Other/                            empty for now (see the README inside)
  UI/Icons/                                    all UI icons as PNG + _contact_sheet.png
  manifest.json                                machine-readable list (used to build ASSET_INDEX.md)
```

How the apartment modules fit together: put `Lot` and `EntranceGate` on the ground, stack
`Floor01`, `Floor02`, ... (each storey's bottom on the previous one's top: Floor01 is 12 studs, the others 11),
then `Roof` on top. `Lift` stands beside the building at x = -30. The wheels are separate
(`HamsterWheel`): 6 per floor, Floor01-02 use BasicWheel, Floor03 AdvancedWheel, Floor04-05 PremiumWheel.
In the `.rbxm` of a wheel, the child model `Wheel` is the part that turns (around the hub's X axis).

## Naming conventions

- **PascalCase, no spaces, no symbols, no numbers unless they mean something**: `GreenTree`, `StreetLamp`, `Floor03`.
- Hamsters: `<RarityId><"Hamster"><Name>` - e.g. `BasicHamsterBrownie`, `MythicHamsterChimera`.
  The rarity id is used (not the display name), so the Unknown rarity (shown as "???") is `UnknownHamster...`.
- Variants describe the difference: `PineTree` / `CherryTree`, `Mountain` / `SnowMountain`, `BasicWheel` / `PremiumWheel`.
- The folder name, the file names and `metadata.json` `Name` are always the same.

## One source of truth: the game code

The game does **not** load these files. Every model is built by code at runtime
(`src/ReplicatedStorage/Modules/HamsterBuilder`, `src/ServerScriptService/Systems/WorldBuilder/*`), and this library
is **exported from that same code** by `tools/build_models.sh`. So:

- **To change how something looks in the game, change the builder code** (the `Source` field in `metadata.json`
  says which function), then rebuild the library. Editing a `.rbxm` here does not change the game.
- The library can never drift from the game: rebuild it after visual changes and commit the result.
- Hamster stats in `metadata.json` (price, income, spawn chance, speed) come from `HamsterDatabase.stats`
  and `RarityConfig`; change them there.

Rebuild (from the project root; needs [lune](https://github.com/lune-org/lune), rojo and Python 3 with
`pillow numpy trimesh`):

```
tools/build_models.sh
```

## Adding a new asset

1. Write (or reuse) a builder function in the game code, e.g. a new `Decor.fountain(parent, pos, ...)`.
2. Add one line to `tools/lune/export_models.luau` in the right section, e.g.
   `decor("Decorations", "Fountain", "Decor.fountain", function(p) return Decor.fountain(p, origin) end)`.
   New hamsters need nothing: every entry of `HamsterDatabase` is exported automatically.
3. Run `tools/build_models.sh` and commit `Models/`.

Assets that only exist as hand-made models (made in Studio or Blender, not by code) go in the matching folder
with the same three files (`Name.rbxm`, `Name.glb`, `metadata.json` with `"Source": "hand-made"`) and must be
added by hand to `ASSET_INDEX.md` under a *Hand-made* section (the generator keeps nothing it did not make,
so keep hand-made files outside the generated folders, e.g. in `Other/` or `Vehicles/`).

## No duplicates

- The exporter hashes every model's geometry (shapes, positions, sizes, colours, materials, rounded to 0.01).
  If two exports are identical, only the first is written; the second is listed under *Skipped duplicates*
  in `ASSET_INDEX.md`. The hash is also in `metadata.json` (`Hash`).
- Hamsters are additionally checked by the game's own test: no two species may have the same look
  (`HamsterBuilder.signature`, see `tools/lune/tests.luau`).
- Before adding a hand-made asset, search `ASSET_INDEX.md` for a similar one and reuse or extend it instead.
- A whole apartment or the full world is *not* stored: they are combinations of the modules above.
  The plaza statue is `Hamsters/Legendary/LegendaryHamsterGoldenKing` scaled by 2.6 - not a separate model.
