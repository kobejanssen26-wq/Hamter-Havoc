# Upgrade_Stations

The eight upgrade "machines" of the apartments: a pedestal with a prop on top that visibly grows with the upgrade level. Exported **fully upgraded**.

| Model | Prop |
|---|---|
| `Station_HamsterTraining` | spinning glass mini-wheel |
| `Station_CollectionRange` | pole with a glowing bulb and a ring |
| `Station_CoinMultiplier` | stack of gold coins |
| `Station_SpawnLuck` | clover bunch |
| `Station_WalkSpeed` | pair of winged sneakers with speed streaks |
| `Station_ExtraStorage` | stack of wooden boxes |
| `Station_RebirthBoost` | glowing flame that bobs (tag `Bob`) |
| `Station_GemBoost` | cluster of coloured gem crystals |

| | |
|---|---|
| File | [`../Upgrade_Stations.rbxm`](../Upgrade_Stations.rbxm) (118 instances) |
| Layout | Folder, stations 8 studs apart along +X |
| Pivot | `PrimaryPart = Pivot` on the floor under each pedestal |
| Attributes | `UpgradeId`, `UpgradeName` (information) |
| External assets | none |
| Controller | optional bundled `AnimateTaggedProps` (Script, Client) spins the training wheel (tag `SpinModel`) |

They are pure visuals: no prompts, no purchase logic. Hook your own `ProximityPrompt` to the pedestal (`StationBase`). To show other levels run the export with a different fraction
(see `build-model.lua`: `Props.Upgrade[id](folder, top, fraction, ghost)`, fraction 0..1).
Regenerate: `python3 tools/ExportModels/export_models.py --update`.
