# Hamster_Icons

48 UI icons drawn from `Frame`s, `UICorner`, `UIStroke` and `UIGradient` - **no emoji, no images**, so they look the same on every device and need no asset ids.

| | |
|---|---|
| File | [`../Hamster_Icons.rbxm`](../Hamster_Icons.rbxm) (one ModuleScript named `Icons`) |
| Dependencies | none |

```lua
local Icons = require(game.ReplicatedStorage.Icons)
Icons.create(parentFrame, "coin", { Size = UDim2.fromOffset(32, 32) })              -- returns the icon Frame
Icons.create(parentFrame, "star", { Size = UDim2.fromOffset(24, 24), Color = Color3.fromRGB(120, 200, 255) })  -- optional tint of the main part
print(Icons.has("coin"), Icons.names())                                              -- list of ids
```

Ids: coin gem flame clover bolt gear hamster book arrowup gift scroll bag crown trophy shield home star sparkle question check cross plus lock music speaker monitor people bell trash
magnet shoe egg cookie heart moon rocket mountain stone flower cloud sun hole roof leaf pouch bot hourglass dot (plus aliases like `slot`, `luck`, `income`, `floor`).
Props: `Size`, `Position`, `AnchorPoint`, `Color`, `ZIndex`, `LayoutOrder`, `Name`. Add an icon by adding a `draw.<id>` function to the module.

The file contains the **current** `src/StarterPlayer/StarterPlayerScripts/UI/Icons.luau`; edit that file, then `python3 tools/ExportModels/export_models.py --update`.
