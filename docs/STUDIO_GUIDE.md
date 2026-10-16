# Managing the game in Roblox Studio

You do **not** need any other tool to run or tweak this game. Open `HamsterPlaza.rbxl` in Roblox Studio (or `rojo serve`
+ the Rojo plugin if you want live-sync with the repository), press **View → Explorer**, and everything below is a normal
Instance: Folder, Model, Part, ModuleScript, Script, LocalScript, Lighting object.

## The three kinds of things

| Kind | What it is | How you change it |
|---|---|---|
| **The world (edit by hand)** | `Workspace/Environment` (ground, paths, forest, **mountains**, lakes, clouds, invisible walls), `HamsterPlaza` (**Coins Shop, Robux Shop, Lucky Wheel**, arch, fountain), `LeaderboardHall`, `HamsterPath`, `SpawnLocations` and the **Lighting** service | Select, move, recolour, delete, duplicate. Saved with the place. Play never regenerates them (attribute `StudioOwned = true` on each folder): edit, press Play, see it. |
| **Settings (edit the numbers)** | ModuleScripts in `ReplicatedStorage/Modules` and `Modules/Content/*` | Double-click the ModuleScript, change the table, press Play. |
| **Generated at every start** | `PlayerHouses` (one apartment per player, with working benches, gates, lifts) and the golden statue on the arch. They are alive (owners, floors, slots), so ModuleScripts under `ServerScriptService/Systems/WorldBuilder` build them every time the server starts | Edit the builder ModuleScript (they are normal scripts in Studio) or the numbers in `WorldLayout` / `FloorConfig`. Editing the preview copy of a house in the Explorer will not stick. |

**How the Studio-owned folders work.** A folder with `StudioOwned = true` is kept exactly as saved. If you delete it (or set the attribute to false) the next Play builds it again from the code, and the new copy is Studio-owned from then on. Missing tags and particle emitters are added back automatically (they are never removed or moved). One rule for `LeaderboardHall`: keep the labels named `Title`, `Period`, `Row1`…`Row10`, `Footer` inside each board's `Screen/BoardGui`; if one is deleted the hall is rebuilt and the Output says so. Because your saved folder wins, changes I make to the builders do not appear in a place that already holds the old folder: use the new `HamsterPlaza.rbxl`, or delete the folder you want regenerated.

## Where is everything?

| I want to change… | Open this in the Explorer |
|---|---|
| The two shops (Coins Shop left, Robux Shop right), the Lucky Wheel behind them | `Workspace/HamsterPlaza/CoinsShop`, `RobuxShop`, `LuckyWheel`. Names, colours and which shop the door opens: the two `ShopStyle` tables at the top of `WorldBuilder/PlazaBuilder`; the door prompt's attribute `Focus` (`Weapons` = Coins Shop, `Gamepasses` = Robux Shop) can be changed in Studio |
| Mountains, trees, lakes, ground, clouds | `Workspace/Environment` (mountains: `Backdrop/Mountains/NearRidge · MidRidge · FarRidge`). To regenerate from numbers: set `Environment`'s attribute `StudioOwned` to false, press Play, and tweak `ReplicatedStorage/Modules/EnvironmentConfig` |
| Sky, sun, haze, colours of the light | `Lighting` and its children (Atmosphere, Bloom, ColorCorrection, SunRays). Numbers for a fresh place: `EnvironmentConfig.Lighting` |
| Map layout (where houses, road, plaza are) | `Modules/WorldLayout`, `Modules/PathConfig`, `Modules/Route` |
| Bases / apartments / working bench (wheels) | `ServerScriptService/Systems/WorldBuilder/HouseBuilder` (`Tower` = floors, lift, interior; `Wheels` = the working bench; `Yard` = front yard + security gate). Floors and elevator unlocks: `Modules/FloorConfig` |
| Hamsters: name, rarity, income, price, model, description, unlock, limited edition | `Modules/Content/Hamsters/<Hamster>` (copy `_Template`). The 172 original hamsters: `Modules/HamsterDatabase` + `Modules/HamsterNames` |
| Hamster 3D models | `ReplicatedStorage/Assets/HamsterModels/<Model>` (then set `ModelName`) |
| Rarities (colours, spawn chance, price + income formula) | `Modules/RarityConfig` |
| Shop items, weapons, equipment, boosts, prices | `Modules/Content/Items/<Item>` (copy `_Template`), categories + other items in `Modules/ShopConfig` |
| Game passes | `Modules/GamepassConfig` |
| Rebirth cost, requirements, rewards, what resets | `Modules/RebirthConfig` (and `UpgradeConfig` for which upgrades reset) |
| Security gate, stealing, carrying, slapping | `Modules/SecurityConfig`, `Modules/TheftConfig`, `Modules/HamsterStates` |
| Leaderboards | `Modules/LeaderboardConfig` |
| Quests, achievements, daily reward, index rewards, upgrades | `Modules/QuestConfig`, `AchievementConfig`, `DailyRewardConfig`, `IndexRewardConfig`, `UpgradeConfig` |
| UI colours, fonts, spacing | `StarterPlayer/StarterPlayerScripts/UI/Theme` |
| The HUD (resource pills, side buttons, hotbar, hints) | **`StarterGui/MainUI` and `StarterGui/HotbarUI`** - real ScreenGuis you edit visually, see "HUD in Studio" below |
| Windows (Shop, Backpack, Settings ...), icons, behaviour | `StarterPlayerScripts/UI/*` (each window is one LocalScript module; `UIKit` has the shared pieces, `Icons` draws every icon, `UIRegistry` adds side buttons). Windows are built by code at start |
| Game settings (gate cooldown, combat caps, starting cash ...) | `Modules/GameConfig` (one documented place); admins can change the `Live` ones in the Admin panel |
| Admin owner id and roles | `ServerScriptService/Config/AdminConfig` (server only) |
| Combat, weapons, animations | `docs/COMBAT_GUIDE.md`, `Modules/Content/Items`, `Modules/Content/Animations` |
| Sounds and volumes | `Modules/AudioConfig` |
| Emotes / animations | `Modules/Content/Emotes`, `Modules/Content/Animations` |
| Key bindings | `Modules/InputConfig` |

`ReplicatedStorage/Modules/_ConfigIndex` is the same map as a comment you can read right inside Studio.

### Why the folders are not called `Shared` / `Services`
They are called `Modules` (shared by server and client) and `Systems` (server services) from the start. Renaming them would break
every `require` and every Rojo path for no gain, so the map above is the answer to "where is it". Server code lives only under
`ServerScriptService`, client code only under `StarterPlayer/StarterPlayerScripts`; configuration that both sides read is in `ReplicatedStorage/Modules`.

## HUD in Studio (MainUI, HotbarUI)

`StarterGui/MainUI` (cash / cash-per-second / diamonds / rebirths, status row, toasts, side buttons, hints, grab prompt) and `StarterGui/HotbarUI` (the 8 slots) are normal ScreenGuis made of
Frames, TextLabels, TextButtons, UIListLayouts, UICorners, UIStrokes ... Select them in the Explorer and edit them with the Properties panel and the on-screen handles like any Studio UI.

How it works: when the game starts, the HUD code finds these instances and **adopts** them instead of creating new ones. For every property it checks whether *you* changed it:
what you changed stays exactly as you set it (position, size, colour, font, text, visibility, layout order, padding ...); everything you did not touch is still set by the code
(for example touch-screen sizes, the scale that fits the HUD to the screen, state colours). Each instance has an attribute `CodeProps` (what the code wrote when the template was made) - do not edit or delete it.

Rules of thumb:
* **Hide, don't delete:** set `Visible = false`. A deleted element is simply created again by the code.
* **Don't rename** template instances (the code finds them by name and order). You may add your own decorations (an ImageLabel logo ...): they stay.
* Region frames (`TopColumn`, `Rail`, `LeftColumn`, `BottomColumn`, `Hotbar`) scale with the screen through a `UIScale` the code manages; move them with `Position`/`AnchorPoint`.
* Things that change with game state (selected rail button, cooldown shading, rarity colours, toasts, shop cards) are driven by the code and the `Theme` module, not by the template.
* The hotbar is **not** Roblox's own backpack bar (that one is switched off); there is exactly one hotbar, at the bottom.
* The templates are generated from the code: after changing HUD code run `tools/SimTests/bake_hud.sh` (needs the `luau` binary) and commit `src/StarterGui`. `run.sh --all` tells you when they are out of date. Leftover template instances that the code no longer builds are removed at start with a warning.
* Windows (Shop, Backpack ...) and item cards are still built by code with the same design system (`Theme`, `UIKit`); only the HUD is a template.

## Test in Studio (what only you can verify)
1. Open `HamsterPlaza.rbxl` → press **Play**. Mountains: walk to the map edge and look outward; the centre must stay open.
2. Rebirth: *Test → Clients and Servers → 1 player*. In the command bar (server): 
   `local d=require(game.ServerScriptService.Systems.DataSystem).get(game.Players:GetPlayers()[1]); d.Coins=1e7` then claim hamsters / use the rebirth screen. Place hamsters (Hamsters panel → *Work +*), rebirth, check the bench is identical, stop, play again, check again.
3. New hamster: copy `Content/Hamsters/_Template`, remove `Enabled = false`, rename Id/DisplayName, Play, open the Hamster Index. Run the content check (see CONTENT_GUIDE §8).
4. World edit: delete a mountain, recolour the Coins Shop roof, move the wheel, press Play: all of it stays. Set `Environment.StudioOwned = false` (or delete `HamsterPlaza`), Play: that folder is regenerated from the code.

## Tutorial and world markers
`Modules/TutorialConfig` holds the 7 steps (text, order, target). Targets are found by tag: builders call `Build.target(part, "Base" | "Bench" | "Gate" | "Upgrade" | "Altar" | "Leaderboard")`.
To point the guide at something else, tag another part the same way (set attribute `TutorialTarget` and add the tag `TutorialTarget` in Studio). Objects inside a house are offered only to its owner.
