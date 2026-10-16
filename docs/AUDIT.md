# Audit checklist (status per system)

"Tested" = covered by `tools/SimTests/run.sh --all` (a simulation of Roblox: it checks rules and structure, not looks or feel).
"Manual" = only you can verify it in Roblox Studio / a live server.

| System | Implementation | Problems found and fixed | Tests | Manual / open |
|---|---|---|---|---|
| Combat | `CombatSystem` (server swing lifecycle, sweep hit detection), `CombatTiming`, `GameConfig.Combat` | attacks only worked near a hamster; target chosen once at click; no active window; client could not report hits (still true) | `scn_combat` (67) | real latency, feel, physics |
| Weapons + abilities | `Content/Items`, `ToolBuilder`, `AbilitySystem` (Freeze, Cloak, Decoy, Guard) | crude placeholder models; no first affordable weapon | `scn_gear`, `scn_combat` | how the 10 models look in hand, balance in real play |
| Animations / emotes | `WeaponAnimator`, `AnimationController`, `Content/Animations`, `EmoteController` | emote vs swing conflicts, rig mismatch, endless emotes, priorities | `scn_combat`, `scn_content` | **no published animation ids exist yet** (built-in swing is used); real playback |
| HUD | `StarterGui/MainUI`, `HotbarUI` templates + `UIKit` adoption | double HUD layers when the template arrived late, unclickable tutorial, missing icons | `scn_hud`, `scn_ui` | look and feel in Studio |
| Visual identity | `Theme` (violet surfaces, saturated accents, thick outlines, per-window colours) | grey generic look | `scn_ui` | **the reference images were not visible to me**: tune `Theme.luau` to taste |
| Shops | `ShopUI` (Cash Shop / Robux Shop), `ShopSystem`, `ShopConfig`, `GamepassConfig` | one mixed shop; generic icons for weapons | `scn_gear` | real Robux purchase, real product ids |
| Admin | `AdminSystem`, `AdminConfig`, `StaffStore`, `ConfigStore`, `AdminUI` | none existed; roles were fixed in a file; UserIds had to be typed | `scn_admin` (146), `scn_adminui` (16) | live DataStore behaviour (roles, bans), `/admin` chat command, avatars (`rbxthumb`) and the look of the 1100x600 panel in a real client |
| Lucky Wheel | `SpinWheelConfig`, `SpinSystem`, `WheelUI`, rail button | 4 h cooldown, linear cash scaling, label did not show the real prize, no rail button | `scn_luckywheel` (33), `scn_gear`, `scn_combat` | the animation / reveal in a real client, real multi-server cooldown |
| Auras | `AuraConfig`, `HamsterBuilder/Auras` | rarity effects were defined but never applied to hamsters | `scn_auras` (26) | how they look, performance with a full tower on a phone |
| F key | `PromptController` (fallback + debug), world prompts | cause not reproducible without Studio: prompts share one key (nearest wins, steal prompt needs a hold) | - | **needs a real test**: set `PromptDebug = true` on your Player and read the Output when F fails |
| Config | `GameConfig` (one place) | gate cooldown hard-coded in tiers (14 s) | `scn_combat`, `scn_admin` | - |
| World | builders in `WorldBuilder`, `world/*.model.json` | fountain blocked the route, sign in the path | `scn_audit` (intersections, floating, route clear) | mountains/hamster models are still procedural blocks: art needs iteration in Studio |
| Rebirth / persistence | `RebirthSystem`, `DataSystem` | (verified earlier) collection and bench kept | `scn_rebirth` | rejoin on a live server |
| Tutorial | `TutorialSystem`, `TutorialUI`, tagged world targets | `Tutorial.Enabled` was not wired | `scn_tutorial` | - |
| Theft / security gate | `TheftSystem`, `SecuritySystem` | cooldown scattered | `scn_theft`, `scn_loop` | - |
| Leaderboards | `LeaderboardService`, hall | route and sign | `scn_lb`, `scn_audit` | live DataStore |
| Trees (release pass) | `Decor.tree` | **root cause of the "crown floats above the trunk" look: the crown height was scaled twice, so every tree with scale != 1 was disconnected (237 of 717)** | `scn_audit` (checks every tree) | how the scenery looks from the player camera |
| Fences | `Decor.fenceRun` | picket spacing varied 3.2-4.8 studs | `scn_audit` (no collisions) | look in Studio |
| Mountains | `MountainBuilder`, `Build.triangle`, `EnvironmentBuilder.cliffWall` | angular dark slabs | `scn_world` (faceted triangle meshes, height bounds, deterministic), `scn_audit`; checked visually with `tools/WorldPreview` | final look in real Studio; old published places keep their old `Workspace/Environment` until it is deleted |
| Physical Lucky Wheel | `LuckyWheelBuilder`, `WheelWorld`, `WheelWorldController` | wheel only existed as a window | `scn_luckywheel` section 7 | how it looks, F prompt in a real client |
| Discord log | `DiscordLog`, `DiscordConfig` | none existed | `scn_discord` (30) | **real Discord delivery (Discord may block Roblox servers: relay)** |
| Tutorial | `TutorialConfig`, `TutorialSystem`, `TutorialUI` | **step 2 pointed at nothing (its stat target was used as the marker name)**; no income / wheel step | `scn_tutorial` (44), `scn_loop` | arrows in a real client |
| Icons | `Icons` (new: wheel, backpack) | shop used a gift, backpack a bag, wheel a gift, index a book | `tools/ReleaseCheck` | taste |
| Release check | `tools/ReleaseCheck/release_check.py` | - | runs in `run.sh --all` | - |

| Sky Glider / Rocket Booster | `SkyGlider`, `RocketBooster`, `MobilitySystem`, `MobilityController`, `GamepassConfig` (`Gear` benefit) | did not exist | `scn_gadgets` (33) | real feel and pass purchase; client-owned movement can be abused by modified clients |
| Tool models | `ToolBuilder` (slingshot, cloak, mirror, banana, glider, rocket redone) | blocky placeholders | `tools/WorldPreview/tool_sheet.py` contact sheet | in-hand look in a real client |
| Phone UI | `UIKit` scale | fits all tested window sizes (`scn_ui` matrix) | `scn_ui` | text is small at scale 0.35 on phones |
| Shops (world) | `PlazaBuilder` (`CoinsShop`, `RobuxShop` + `ShopStyle` tables), `ShopUI` focus | one building for both shops | `scn_audit` (two shops, prompts, mirrored, 10+ studs apart), `scn_gear` | look in Studio; real Robux purchase (PassId / ProductId still 0) |
| Lucky Wheel placement | `LuckyWheelBuilder.CENTER` = (0, 0, 80), `WheelPath` | in the plaza corner | `scn_luckywheel` section 7 | the exact spot of your screenshot (I could not see it) |
| Studio workflow | `WorldBuilder/init` (StudioOwned folders), `Restore`, `LeaderboardBuilder.adopt` | plaza, hall and road were rebuilt at every Play, so edits vanished | `scn_studio` (20): edits survive, lost tags/emitters restored, deleted folder rebuilt, StudioOwned=false regenerates | the same check in real Studio |
| Decoration in the air | `scn_audit` section 5 (18 000 parts, incl. non-colliding moss/bush/hills) | - | `scn_audit` | - |
| Trees touching things | `EnvironmentBuilder` footprints, yard trees in `Yard` | 602 forest trees had a crown inside a neighbour's trunk / a rock; two yard trees touched the tower roof / fence | `scn_audit` (every tree part vs every solid) | - |
| Lucky Wheel (physical) | `LuckyWheelBuilder` (wedge slices, picture plates, fixed pointer), `WheelWorld`, `SpinWheelConfig` (direction, ease, rotorCFrame), `WheelWorldController` | **the rotor's pivot had the cylinder's own orientation: the first turn tipped the whole wheel over onto its edge**; `BaseCFrame` was an attribute that neither the baked place nor a moved wheel could keep; prize names as text; two wheels (window and world); paid respin | `scn_luckywheel` (70): pivot and axis, clockwise = top slice moves to the viewer's right, both directions end exactly on the drawn prize, ease curve, no text on slices, no paid spin, spin only at the wheel | the look and feel in a real client; the default direction (`Wheel.Clockwise = false`) is my reading of "wrong direction": flip it if it is still wrong |
| Lucky Wheel panel | `WheelUI` (docked right, `UIKit.panel Dock = "Right"`) | a full-screen window with a second wheel and a spin button | `scn_ui` window matrix | - |
| Shops (UI) | `ShopUI` builds two windows (`Shop` = Coins Shop, `RobuxShop`); `ShopUI.shopOf` decides which category belongs where | one window with a Cash/Robux switch, so each shop showed a way into the other | `scn_gear`, `scn_ui` (no switch, no foreign tabs) | real Robux purchase |
| Playtime rewards | `PlaytimeConfig`, `PlaytimeSystem`, `PlaytimeUI`, rail icon | did not exist | `scn_playtime` (40) | in a live server over several hours |
| Like & Favorite board | `PlazaBuilder.buildFavoritesBoard`, `FavoritesConfig`, `FavoritesController` | did not exist | `scn_audit` | Roblox's invite window in a real client; Like / Favorite can not be pressed by a game, the board says so |
| Model mock | `tools/SimTests/mock.lua` | `GetPivot` / `PivotTo` ignored `PivotOffset` (how the wheel bug stayed hidden) | all scenarios | - |
