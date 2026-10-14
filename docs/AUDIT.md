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
