# Hamster_Apartment_5F

The complete "Hamster Apartment" lot at its biggest: front yard, modern security portal with status panel, a five-floor glass tower (lobby, wheel gallery, upgrade lab, premium suite,
penthouse), elevator shafts, balconies, rooftop and **all 40 hamster wheels** built (empty - no hamsters).

| | |
|---|---|
| File | [`../Hamster_Apartment_5F.rbxm`](../Hamster_Apartment_5F.rbxm) (1904 instances, about 25 KB compressed) |
| Size | 69.6 x 119.7 x 89.3 studs |
| Pivot | `PrimaryPart = Pivot` at the **middle of the gate line on the ground**; +Z leads into the lot, -Z is the street |
| External assets | none |
| Works alone? | As scenery: yes. The interactive parts need the game's server code (below) |

## Hierarchy

```
Hamster_Apartment_5F (Model)
├─ Yard        lawn, driveway, hedges, fences, security portal (GatePylon, LaserBeam x5, SecurityField, SecurityPanel), altar, mailbox, name sign, trees, pond
├─ Tower       Floor1_HamsterHall … Floor5_Penthouse (each: Shell, Interior, [Balcony]) and Roof
├─ Wheels      Wheel1 … Wheel40 (the same assembly as Hamster_Wheel, tagged HamsterWheel)
├─ Display     empty (hamsters running on wheels are added by the game)
└─ RoofAnchor  anchor of the roof billboard label
```

Delete `Floor5…` (and the wheels of that floor, `Wheel33`-`Wheel40`) to get a smaller tower; floor N holds wheels `8(N-1)+1 … 8N`.

## What is NOT included (game logic)

* `ProximityPrompt`s (chest, altar, mailbox, elevator buttons, security panel, upgrade pedestals) carry attributes such as `OpenUI`, `Elevator`, `Floor`, `SecurityHouse`; **handling them is the game's `HouseSystem` / `SecuritySystem`**, not part of the model.
  Remove the prompts or connect `ProximityPrompt.Triggered` yourself. The elevator prompts are disabled/enabled per floor by the game.
* Wheels do not turn and hamsters are not placed (see `Hamster_Wheel_Complete` for a self-animated wheel). Security lasers/lamps are shown in their "active" state.
* No DataStores, no server scripts, no player data (runtime attributes `HouseId`, `OwnerUserId`, ... are stripped).

## Source / regenerate

`build-model.lua` calls the game's `HouseBuilder` (`build`, `setFloors`, `setWheel`, `setStation`, `setSecurity`). Because it uses the real builder, a change to the apartments in `src/`
shows up as a changed export (`export_models.py --check` fails until you run `--update`).
