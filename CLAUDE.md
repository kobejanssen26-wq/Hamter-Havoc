# Notes for contributors (human or AI)

* Game code: `src/` (Rojo project `default.project.json`). Preview world: `world/` (re-baked, see `WAAR_STAAT_WAT.md`).
* **Model library**: `ModelLibrary/` holds reusable `.rbxm` exports. Whenever you add or significantly change a reusable model, or code that builds one
  (`HamsterBuilder`, `HouseBuilder/*`, `Decor`, `HamsterAnimator`, `Icons`), run `python3 tools/ExportModels/export_models.py --update`, then `--test`, and commit the changed `.rbxm` files with the change.
  `export_models.py --check` must pass. Never hand-edit `ModelLibrary/README.md` (generated). See `tools/ExportModels/README.md`.
* Never claim an export exists unless the file is in `ModelLibrary/` and `--check` passes.
