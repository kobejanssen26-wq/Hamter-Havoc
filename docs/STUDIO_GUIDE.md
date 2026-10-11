# Managing the game in Roblox Studio

You do **not** need any other tool to run or tweak this game. Open `HamsterPlaza.rbxl` in Roblox Studio (or `rojo serve`
+ the Rojo plugin if you want live-sync with the repository), press **View → Explorer**, and everything below is a normal
Instance: Folder, Model, Part, ModuleScript, Script, LocalScript, Lighting object.

## The three kinds of things

| Kind | What it is | How you change it |
|---|---|---|
| **Scenery (edit by hand)** | `Workspace/Environment` (ground, paths, forest, **mountains**, lakes, clouds, invisible walls) and the **Lighting** service (Atmosphere, Bloom, ColorCorrection, SunRays) | Select, move, recolour, delete, duplicate. Saved with the place. Play never regenerates it (attribute `StudioOwned = true`). |
| **Settings (edit the numbers)** | ModuleScripts in `ReplicatedStorage/Modules` and `Modules/Content/*` | Double-click the ModuleScript, change the table, press Play. |
| **Generated gameplay objects** | Houses, working benches (wheels), plaza, road, leaderboard hall: built by ModuleScripts under `ServerScriptService/Systems/WorldBuilder` every time the server starts, because gameplay is wired to them (prompts, gates, slots) | Edit the builder ModuleScript (they are normal scripts in Studio) or the numbers in `WorldLayout` / `FloorConfig`. Editing the preview copy in the Explorer will not stick for these. |

The `Workspace` preview copies of houses/plaza/road exist so you can *see and measure* them without pressing Play.

## Where is everything?

| I want to change… | Open this in the Explorer |
|---|---|
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
| UI buttons / panels, icons, text, animations | `StarterPlayerScripts/UI/*` (each screen is one LocalScript module; `UIKit` has the shared pieces, `Icons` draws every icon, `UIRegistry` adds buttons). The UI is *built by those scripts when the game starts*, so it is edited there, not as ScreenGuis in `StarterGui` |
| Sounds and volumes | `Modules/AudioConfig` |
| Emotes / animations | `Modules/Content/Emotes`, `Modules/Content/Animations` |
| Key bindings | `Modules/InputConfig` |

`ReplicatedStorage/Modules/_ConfigIndex` is the same map as a comment you can read right inside Studio.

### Why the folders are not called `Shared` / `Services`
They are called `Modules` (shared by server and client) and `Systems` (server services) from the start. Renaming them would break
every `require` and every Rojo path for no gain, so the map above is the answer to "where is it". Server code lives only under
`ServerScriptService`, client code only under `StarterPlayer/StarterPlayerScripts`; configuration that both sides read is in `ReplicatedStorage/Modules`.

## Test in Studio (what only you can verify)
1. Open `HamsterPlaza.rbxl` → press **Play**. Mountains: walk to the map edge and look outward; the centre must stay open.
2. Rebirth: *Test → Clients and Servers → 1 player*. In the command bar (server): 
   `local d=require(game.ServerScriptService.Systems.DataSystem).get(game.Players:GetPlayers()[1]); d.Coins=1e7` then claim hamsters / use the rebirth screen. Place hamsters (Hamsters panel → *Work +*), rebirth, check the bench is identical, stop, play again, check again.
3. New hamster: copy `Content/Hamsters/_Template`, remove `Enabled = false`, rename Id/DisplayName, Play, open the Hamster Index. Run the content check (see CONTENT_GUIDE §8).
4. Environment edit: delete a mountain, press Play: it stays deleted. Set `Environment.StudioOwned = false`, Play: the scenery is regenerated.
