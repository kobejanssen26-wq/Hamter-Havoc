# Hamster_Wheel

The hamster wheel of the apartments: wooden stand, axle, glass-sided wheel with six rungs. The wheel turns **about the hub axle**, against the running direction.

| | |
|---|---|
| Model file | [`../Hamster_Wheel.rbxm`](../Hamster_Wheel.rbxm) (18 instances) |
| Size | 5.60 x 5.00 x 3.80 studs |
| Pivot | `PrimaryPart` = `WheelBase`, with `PivotOffset` so the pivot is the **bottom centre of the stand** (floor level). Insert it with `PivotTo(CFrame.new(x, groundY, z))` |
| Orientation | the hamster runs towards **+X** (attribute `RunDirection`), the axle runs along **Z** through the hub at height 2.7, wheel radius 2.3 |
| External assets | none |
| Works alone? | Static without a controller; the bundled `WheelSpin` Script (client) turns it |

## Hierarchy

```
Hamster_Wheel (Model, PrimaryPart = WheelBase)
├─ WheelBase, WheelLeg x4, Axle         the stand (static, anchored)
├─ Wheel (Model, PrimaryPart = Hub)      the turning part: Hub, Side x2 (glass), Rung x6
│     attributes  Speed = 3 (rad/s)   RunDirection = (1,0,0)   tag HamsterWheel
└─ WheelSpin (Script, RunContext = Client)
```

## How the rotation works

The floor under a running hamster has to move **backwards**. `WheelSpin` therefore rotates `Wheel` around the axis `up x RunDirection`, expressed in the **assembly's local space**
(so you may rotate or move the whole model freely). The hub never moves; only the angle changes. This is tested (see `tools/ExportModels/tests`): for three different yaw
angles the floor point moves against the run direction at about `Speed x 2.3 = 6.9 studs/s`, the axle direction and hub position stay constant.

| Attribute on `Wheel` | Meaning | Default |
|---|---|---|
| `Speed` | radians per second (0 = stand still, negative = reverse) | 3 |
| `RunDirection` | direction the hamster runs, local to the assembly | (1, 0, 0) |

## Dependencies

* `WheelSpin` is bundled and uses only `RunService`. Nothing else is required.
* The inner `Wheel` model also carries the CollectionService tag `HamsterWheel` that **Hamster Plaza's** own client controller reads. In another game the tag does nothing.
  If you insert this wheel *into Hamster Plaza itself*, delete the `WheelSpin` script (the game already animates tagged wheels), otherwise it would be driven twice.
* No constraints / HingeConstraint: the wheel is animated by `PivotTo` on an anchored model (cheap, deterministic, no physics). If you need a physics wheel, add a `HingeConstraint` between `Axle` and `Hub`.

## Source / regenerate

`build-model.lua` calls the game's `HouseBuilder/Wheels.luau` (the exact builder used in the apartments) and sets the pivot; `scripts/WheelSpin.client.luau` is the controller.
`python3 tools/ExportModels/export_models.py --update`.
