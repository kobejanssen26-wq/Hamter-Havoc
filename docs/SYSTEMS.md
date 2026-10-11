# How the systems work (and what still needs Roblox Studio)

## Phase A — what the inspection found (before this overhaul)
| Area | Finding |
|---|---|
| Top HUD | Built with a `UIScale` on every positioned frame and a hand-added `GuiService` inset. A `UIScale` on a positioned frame also scales its position offset and the inset arithmetic only held for one top-bar height, so the pieces drifted on other resolutions/devices. Several HUD elements (security pill, boosts, toasts, prompts, tracker) were placed independently and could overlap on small screens. I could not reproduce "HUD halfway down the screen" without Studio; the fix removes the whole class of causes (see *UI layout*). |
| UI | 9 panels + ad-hoc ScreenGuis with their own `DisplayOrder`; a huge left sidebar; big banner for gate state; duplicated information (gate timer in two places). |
| Content | Hamsters are 172 literal table rows; adding one meant editing `HamsterDatabase` and sometimes other scripts. No emotes, no animation registry, no validator. |
| Stealing | Existed for rolling balls only (claim → transit → steal → carry → slap → secure). Nothing for hamsters running on wheels, no trap when the gate closes. |
| Security | Gate length per "tier" (45/60/80/100 s) instead of +10 s per rebirth; beeps at full volume, the `Alarm` played twice per event, last-5-second beep every second. |
| Floors | Elevator model + prompts were built on every floor, even in a one-floor tower (only the prompts were disabled). |
| Leaderboard | Only Roblox `leaderstats`; the board in the plaza was a "recent finds" text board in the middle of the plaza. |
| Audio / animation | Sound ids + volumes in one table, no categories; animation was purely procedural (Motor6D), no registry. |

## UI layout
* `UI/Theme.luau` — palette, fonts, radii, spacing, layers (`Theme.Layers`: Hud 1 < Hotbar 2 < Tutorial 8 < Panels 10 < Reveal 15 < Toast 30 < Tooltip 60 < Modal 80).
* `UIKit.screenGui(name, {Layer, Insets})` — the only way ScreenGuis are created. `Insets = "Topbar"` sets `ScreenInsets = TopbarSafeInsets`: the origin is already
  **below the Roblox top bar and phone notches**, so the HUD uses a plain 8 px margin on every device (no per-device offsets).
* `UIKit.responsive` — positioned wrapper + scaled content frame (the `UIScale` is on the inner frame only, the wrapper's size = design × scale).
* `MainUI` has four regions (TopColumn / Rail / LeftColumn / BottomColumn); everything else is parented into them and laid out by `UIListLayout`.
  `tools/SimTests` verifies at 1920×1080, 1280×720, 1024×768, 800×400, 667×375, 844×390 that regions are on screen, do not overlap, and the top HUD is centred
  directly under the top bar.
* Only one big menu is open at a time (`UIKit.closeAll`); the emote wheel closes when a panel opens.

## Rack theft (`TheftSystem`, `TheftConfig`)
1. A wheel on a stealable floor (floor 1) shows a hold-prompt (F, 1.2 s) only when: the base has an owner, the **gate is off**, the wheel holds an eligible hamster, it is not being stolen, the owner has been in the game 45 s.
2. Server checks on the trigger: thief alive/not stunned/not channelling, not carrying, owns a house, is not the owner, cooldown 4 s, distance to the wheel ≤ 14 and inside the lot, slot valid and unlocked, gate not active, not locked by another theft.
3. The hamster **stays in the owner's data**; it disappears from the wheel (runtime lock only, never saved) and becomes a carried ball whose payer is the owner — so the existing slap/drop/recover/secure rules apply.
4. **Completed** (thief reaches *their own* pad): one synchronous block — `Settled` flag first, take it from the owner (inventory + wheel), grant to the thief, roll back if the grant fails, stats, `TheftCompleted`, both profiles saved. It can never run twice.
5. **Owner hits the thief** (server-validated slap, range/arc/cooldown): theft fails for sure, ball removed, wheel shows the hamster again, `TheftsStopped`/`TheftsFailed` recorded, both players get a message. Nothing is deleted, duplicated or transferred.
6. **Gate switched on while a carrying thief is inside**: thief is *trapped* (not zapped): a 0.1 s leash puts them back inside if they cross the gate line. Ends when the owner hits them, the gate switches off (valid exit), or after `EscapeTimeout` = 60 s (theft fails, thief is put outside). Other strangers inside are zapped out as before.
7. Edge cases (all tested in `scn_theft`): thief dies (ball dropped → rolls back, nothing lost), thief leaves (theft ends at once), owner leaves (ball vanishes, **no refund paid**), owner rebirths (theft cancelled), wheel/species gone, second thief on the same wheel (rejected), unequip/auto-equip while locked (blocked).
8. Known limit: the transfer touches two profiles; Roblox DataStores have no cross-key transaction. Order is *remove from owner, grant to thief, save both*. A server crash between the two saves loses the hamster rather than duplicating it.

## Rebirth gate time
`SecurityConfig.duration(rebirths) = 45 s + 10 s × rebirths`. It is derived from the saved rebirth count when the gate is switched on, so it applies exactly once per rebirth, existing players get it automatically, and no other timer (recharge, zap cooldown, carry limits) changes. The HUD gate chip tooltip and the Rebirth screen show the current/next value.

## Elevators
`FloorConfig.elevator(index, built)` decides shaft / up / down (see CONTENT_GUIDE §6). `Tower.syncElevators` builds/destroys the shaft and call buttons when floors change; `HouseSystem.useElevator` validates owner, direction, distance and destination with the same function.

## Leaderboards (`LeaderboardService`, `LeaderboardConfig`)
* **Most Hamsters** = peak number of valid hamsters owned at one time within the period. **Most Steals** = completed thefts (rack thefts and stolen balls that reached the thief's pad; failed attempts never count). **Most Money** = cash *earned* within the period (spending never lowers it; diamonds are not mixed in).
* Periods are separate OrderedDataStores `LB_v1_<Metric>_<bucket>`: Weekly = Monday 00:00 → Monday 00:00 **UTC** (`W<weekIndex>`), Monthly = calendar month UTC (`M202610`), Yearly = calendar year UTC (`Y2026`), All-time = `A`. A new bucket starts empty; old buckets and all-time are never touched or deleted.
* Writes are batched (memory sampling every 15 s, datastore writes every 120 s per player and on leave, only changed stores, budget-checked, failed writes are retried). All-time is seeded once from the player's saved lifetime stats. Reads: top 50, cached 60 s per server, single-flight. The client may only read.
* Display: the *Leaderboards* screen (rail button / kiosk) with metric tabs, period selector, avatars, top-3 styling, loading/empty/error states; and three boards in the **Leaderboard Hall** behind the library (`WorldBuilder/LeaderboardBuilder`) cycling through the periods every 30 s.
* Rewards: none yet (build them server-side with a claim flag if you add them).

## Items, hotbar, weapons, shop, passes
* `ItemRegistry` (Content/Items) is the single source for weapons, equipment and consumables. `ShopConfig` generates its Weapons/Equipment entries from it, `GamepassConfig` generates the Game Pass entries.
* Ownership lives in the profile: `Gear[id]` (weapons/equipment), `Items[id]` (consumable counts), `Hotbar["2".."8"]` (layout; slot 1 is the built-in paws). `GearSystem` owns all changes (grant, equip, move, discard, tools), `ShopSystem` charges first-validated-then-atomically.
* Purchases: the client sends only an item id. Price, currency, ownership, stack limits and double-click protection are server side. Owned gear can't be bought twice.
* Hotbar UI (`HotbarUI`) is the **only** hotbar (Roblox's own backpack bar is switched off). Slot parts come from `HotbarConfig.layout` so number/icon/count can't overlap. Backpack (`BackpackUI`, key `I`) manages owned items; hamsters stay in *My Hamsters* (the chest) — all owned hamsters are listed, with *Work +* / *Rest −* per species.
* Passes: see CONTENT_GUIDE §7c.

## Audio
`AudioConfig.Categories` (UI, Purchase, Movement, Gate, Steal, Escape, Failed, Rebirth, Emote, Notification) × each sound's own volume × the player's *Effects volume*; gate sounds additionally × the player's *Gate & alarm sounds* slider. `AudioConfig.MinInterval` stops repeats (gate on/off 1.5 s, alarm 0.6 s ...). The big "base open/locked" banner is gone; gate state = gate visuals + HUD gate chip + one quiet sound.

## Manual checks that need Roblox Studio (not verifiable here)
1. Run the content check (CONTENT_GUIDE §8) and `AnimationController.preflight()` after you add real animation ids.
2. Play with **2+ players** (Studio → Test → Clients): steal from an open base; get hit by the owner; close the gate while the thief is inside; let the 60 s timeout run; die/reset while carrying; leave while carrying.
3. HUD on real devices (Studio device emulator: phone landscape/portrait, tablet, 1080p): top HUD directly under the Roblox top bar, nothing overlapping, notch/home-indicator safe.
4. Emote wheel with B, with the Emotes button on touch, with each default emote (R15 avatar with the standard Animate script); a custom animation emote after you uploaded one.
5. Leaderboards need **Studio → Game Settings → Security → Enable Studio Access to API Services**; check each period after a session, and the hall boards.
6. Elevators: unlock floors with rebirths (or set `data.Rebirths` in the command bar) and walk through 1 → 2 → 3 floors.
7. **Weapons and shop (not testable offline):** buy each weapon in the Shop (check cash/diamonds drop once), see it appear on the hotbar, equip with its number key, and check the Tool in your hand looks right (bat/ladle/slingshot are built from parts — grip angle may need a tweak in `ToolBuilder`). Swing at another player while a thief carries a hamster (valid) and while nothing is going on (must do nothing). Respawn: tools come back. Rejoin: owned items and hotbar order persist.
8. **Game passes:** with a real PassId in `GamepassConfig`: prompt appears, benefit appears only after the purchase finishes, *Refresh purchases* works, an unconfigured pass is greyed out and cannot be bought.
9. Hotbar/Shop/Backpack on phone landscape + portrait and 1080p: hotbar bottom-centre, nothing overlapping, number keys 1–8 and touch taps both work.
10. Hamster look/feel (proportions, tufts, teeth, turn lean), audio levels, and performance with a full server (8 players).
