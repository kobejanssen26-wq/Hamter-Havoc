# Hamster_Wheel_Complete

A hamster running on its wheel, ready to drop into any experience. Built from the two library assets [`Hamster_Wheel`](../Wheels/Hamster_Wheel/README.md) and
[`Hamster_Default`](../Hamsters/Hamster_Default/README.md), composed exactly like the game does when a hamster works on a wheel.

| | |
|---|---|
| Model file | [`../Hamster_Wheel_Complete.rbxm`](../Hamster_Wheel_Complete.rbxm) (104 instances) |
| Size | 5.60 x 5.00 x 3.89 studs |
| Pivot | the wheel's pivot: bottom centre of the stand, run direction +X, axle along Z |
| External assets | none |
| Works alone? | **Yes** - all three controller scripts are inside and run on the client |

## Hierarchy

```
Hamster_Wheel_Complete (Model, PrimaryPart = WheelBase)
├─ WheelBase, WheelLeg x4, Axle, Wheel (Model)          see Hamster_Wheel
├─ WheelSpin (Script, Client)                            turns Wheel (Speed 3 rad/s)
└─ Hamster (Model, PrimaryPart = Root, scale 0.5, MoveSpeed = 7)
     ├─ parts + 9 Motor6D joints                          see Hamster_Default
     ├─ HamsterAnimator (ModuleScript)
     └─ HamsterAutoAnimate (Script, Client)               running animation
```

The hamster stands on the inside floor of the wheel (hub height 2.7 - radius 2.3 + 0.1) and faces the run direction (+X). Wheel speed 3 rad/s x radius 2.3 = 6.9 studs/s
matches the running animation speed 7, so the feet do not slide.

## Configure it

* Faster / slower: set `Speed` on `Wheel` and `MoveSpeed` on `Hamster` together (`MoveSpeed ≈ Speed x 2.3`).
* Stop: both to 0.
* Another hamster: replace the `Hamster` model (build one with `HamsterBuilder_Package`) and keep the same position/orientation.
* Move or rotate the whole assembly with `PivotTo` - the wheel direction is local to the assembly.

## Dependencies

None outside the file. If you insert it into Hamster Plaza itself, delete `WheelSpin` (the game animates `HamsterWheel`-tagged wheels on its own).

## Source / regenerate

`build-model.lua` composes the two other assets (`ctx.buildAsset`). `python3 tools/ExportModels/export_models.py --update`.
