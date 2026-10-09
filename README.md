# 🐹 Hamster Plaza

A cozy multiplayer hamster game for Roblox (Luau + [Rojo](https://rojo.space)).

> Hamster balls roll down the road in the middle. **Claim** one by paying for it — but it is **not yours yet**.
> It rolls home to *your* house, and everybody else can **steal** it on the way. Carry it, defend it, **slap** thieves,
> and once it lands on the pad in your house it is **secured for good** and runs on a **hamster wheel** earning coins.
> Upgrade, rebirth, hunt rarer hamsters, fill the Hamster Index.

> **Waar staat wat?** Zie [`WAAR_STAAT_WAT.md`](WAAR_STAAT_WAT.md) (Explorer-kaart, Nederlands). De wereld en alle 172 hamsters staan als voorbeeldkopie in `world/` en zijn in Studio direct zichtbaar zonder Play.

> **Model library:** reusable Roblox models (hamster, wheel, combined assembly, apartment tower, nature/decor packs, upgrade machines, icons) are in [`ModelLibrary/`](ModelLibrary/README.md)
> as genuine `.rbxm` files you can download one by one and insert into any other Roblox experience.

## Run it

1. `rokit install` (installs Rojo 7.4.4 from `rokit.toml`).
2. `rojo build -o HamsterPlaza.rbxl`, open it in Roblox Studio (or `rojo serve` + the Rojo plugin).
   `HamsterPlaza.rbxl` is also committed, prebuilt.
3. Studio → Game Settings → Security → **Enable Studio Access to API Services** (DataStore saving).
4. Press Play / **Test with 2+ players**. The world you see in the editor is a preview copy (`world/*.model.json`); on Play the server rebuilds it from code.

Controls: **E** claim / steal / carry / pick up · **Q** slap · **F** shops, upgrades, altar (world prompts) · E at the gate panel re-arms your security.

## The core loop (all server-authoritative)

| Step | What happens |
|---|---|
| Spawn | A ball rolls out of the burrow (west). Rarity decides speed, size, price, effects. Spawn luck is "sponsored" by players in turns (their Luck + Rebirths pick the species). |
| Claim `E` | Pay the full price. The ball is now **InTransit** and rolls toward your house **by itself** (it is never teleported). |
| Steal `E` | Hold-time grows with rarity (0.7–1.5 s). The ball becomes **Carried**: it floats behind the thief, who walks slower (rarer = heavier) and must reach **their own** arrival pad. |
| Fight `Q` | A slap (1.1 s cooldown, small knockback, short stun, then brief immunity) near a ball in play. A hit carrier drops it 70 % of the time → **Dropped** → **Recoverable** → anyone can pick it up. |
| Secure | A carrier within 7 studs of their own pad, or a ball that rolled home and rested 1.8 s on the pad, is **Secured**: permanent, joins the collection, gets a wheel, earns money. |
| Money risk | Payer loses the price when it is stolen; if the thief secures it the payer gets **25 % insurance**. Payer leaves → ball vanishes, **100 % refund**. Abandoned balls roll back to the payer. |
| Anti-grief | Max carry time 75 s, carrier leaves/dies/leaves the map/moves impossibly fast → dropped; 3 s / 8 s re-grab bans; max 3 unsecured balls per player; no physics-launched balls (positions are simulated, never physical). |

States: `Spawning → Travelling (available) → InTransit (claimed) → Carried → Dropped → Recoverable → Secured → Working`.
See `HamsterStates.luau` (all tuning numbers) and `HamsterSystem.luau`.

## The world

- One straight, mirror-symmetric avenue (z = 0, 450 long, 26 wide) with two lanes; both house rows are the same distance from it, so no side is favoured.
  Balls steer around each other (lane changes, overtaking) and a hard separation pass makes overlap impossible. They also steer around people on the road.
- Wide promenades (z = ±34) are where claimed balls roll home; a paved path joins every gate to the road.
- **Hamster Plaza** in the middle (60 studs wide): golden-king arch over the road, Shop (north), Hamster Index library (south). Nothing else.
- **Scenery** around the playable area: forest, rocks and cliffs on the edge, rolling hills, lakes, a three-row ring of mountains that fade into the haze, drifting clouds,
  circling birds and swaying trees (client-side, `NatureController`).
- **8 big plots** (68 × 86) with generous gaps between them; every plot holds a **Hamster Apartment tower** that grows with the owner's rebirths:

| Floor | Name | Unlocked | Gameplay |
|---|---|---|---|
| 1 | Hamster Hall | start | arrival pad, 8 upgrade pedestals, chest, 8 wheel stations, tower board, cozy gabled roof |
| 2 | Wheel Gallery | Rebirth 3 | +8 wheel stations, +10 % income, storage lounge (second chest) |
| 3 | Upgrade Lab | Rebirth 6 | +8 wheel stations, +10 % income, upgrade console |
| 4 | Premium Suite | Rebirth 10 | +8 wheel stations, +10 % income, +10 % luck, rooftop garden |
| 5 | Penthouse | Rebirth 15 | +8 wheel stations, +10 % income, +10 % luck, crown with a light beam |

  Floors are connected by an **elevator** (call buttons by the shaft, `F`). The tower gets narrower towards the top, has glass facades, balconies, and the
  trim material changes with rebirths (Wood → Silver R5 → Gold R10 → Diamond R20). All numbers: `FloorConfig.luau`.
- **Security gate** (modern portal with pylons, lasers and a status panel): lasers zap strangers out of the lot (stun + knockback + dropped ball) while active.
  Timer is shown above every gate and in your HUD. Tiers by rebirth: Basic Gate 45 s → Advanced 60 s (R1) → Fortress 80 s (R3) → Royal Vault 100 s (R6).
  Then recharge, then you press E at the panel. While it is off anybody can walk in (and steal a ball that is still rolling to/at the pad).
  **Secured hamsters can never be stolen.** (To change the number of houses edit `WorldLayout.HouseColumns` only.)

## Rebirth & progression

Rebirth is hard to reach and every one gives permanent power (`RebirthConfig.luau`, all tuned with the progression simulation):

- **Requirements:** cash ($700,000 × 4.6^(n-1)), a growing collection (n + 3 hamsters), and a hamster of a minimum rarity (Shiny → … → Unknown); the first rebirth specifically needs the Silver hamster (shown in-game as "Argent Nibbler", id `silver`).
- **Every rebirth:** +1 hamster slot (3 at the start), +30 % permanent income, +5 % luck, diamonds and tokens.
- **Milestones:** new floors (R3/6/10/15), advanced upgrade tiers (R5/R10), better security, new rarities (Mythic R2 … Unknown R12), keepsake hamsters
  (you keep your best N hamsters, N grows with rebirths), tower trim.
- **Resets:** coins, hamsters (except keepsakes), coin upgrades. **Keeps:** Index, rebirth level and everything it unlocked, floors, token upgrades, gems, tokens, quests, achievements, cosmetics, gamepasses.
- The Rebirth screen shows requirements with live progress, your slots, your tower floors, every reward, and what resets / what you keep.

## Economy

Price and income per rarity follow one formula (`RarityConfig`): `BasePrice` grows ×5 per tier roughly, `Payback` (seconds until a hamster pays for itself)
grows 1.3× per tier, `Income = BasePrice / Payback`; inside a rarity a small value spread keeps the order consistent, so a higher rarity is never worse than a lower one.
Spawn weights (Basic ≈ 52 %, Cute 25 %, Shiny 12 % (Silver is weighted x4 inside Shiny because the first rebirth needs it), Rare 6.5 %, Epic 2.8 %, Ultra 1.3 %, Legendary 0.65 %, rarer tiers far below). Python/Luau progression simulation:
first rebirth after ≈ 50 min (with active play), Epic ≈ 30 min, Legendary ≈ 2 h, Mythic ≈ 3–4 h.

## Interface

Mature **dark graphite** style (`UI/Theme.luau` is the single place for colours, fonts, radii and motion; `UIKit.Colors` is built from it): graphite windows with a thin bronze edge,
a header bar with a small close button, restrained gold/bronze accents, green for positive actions, purple for diamonds, high-contrast text. No emoji anywhere: every icon is
**drawn from UI shapes** (`UI/Icons.luau`, 52 icons).

- **HUD** (`MainUI`): four indicators centred under the Roblox top bar (safe-area aware) - **Cash, Cash/s, Diamonds, Rebirths** - plus four small icon buttons top-right with tooltips and
  pressed/selected states: **Daily Quests** (quests, achievements and the daily reward), **Hamsters** (collection), **Shop**, **Settings**. There is no big side menu any more.
- **In-world menus** (all in your own plot, `HouseBuilder/Tower.luau` + `Yard.luau`, proximity prompts, work on PC and mobile): **Upgrade Terminal** and the upgrade pedestals (Upgrades),
  **Collection Archive** (Hamster Index), **Rebirth Altar** (Rebirth), **Mailbox** (daily gift), **Hamster Chest** (Hamsters). The central **Shop** stall in the plaza opens the Shop.
- **Hotbar** (`HotbarUI`, `HotbarConfig`): permanent bottom bar, keys 1-6 or tap. Slot 1 = Slap (the real ability, shows its cooldown); the other slots are consumable items bought in the
  Shop (2x Cash, 2x Luck, Speed Tonic, Auto Collector, Cash Pouch). Counts live in the server-owned `Items` table; `UseItem` is validated on the server. There is no fake weapon system.
- **Shop** (`ShopUI`, `ShopConfig`): categories (Boosts, Equipment, Hamsters, Diamonds, Cosmetics, Limited Offers) are configuration-driven and only shown when they hold items that can
  really be bought right now. Each item names its currency (Cash / Diamonds / Robux) and price; the server validates, charges and grants atomically and refuses double clicks.
- **Hamster nameplates** (`WorldController.createTag`): fixed pixel size (158 x 66, BillboardGui offset sizing, max distance 120 studs), name, rarity, price and income per second
  (your real income with all multipliers), created once per ball.
- **Base banners** (`BannerUI`): "YOUR BASE IS NOW OPEN!" / "YOUR BASE IS NOW LOCKED!" - sent by `SecuritySystem` only on real gate transitions of an owned base.
- **Tutorial** (`TutorialUI`, `TutorialConfig`, `TutorialSystem`): short, skippable, saved in `profile.Tutorial`; steps advance from real progress (buy a hamster, secure it);
  profiles saved before the tutorial existed are marked done on load.

The Hamster Index cards show **Working / Owned / Discovered / Missing**. In first person the mouse is freed while any menu is open (and while you hold **ALT**).

## Content

14 rarities · 172 unique procedural hamster designs (built from primitives, rigged with Motor6D, animated on the client) ·
Hamster Index with browse-by Rarity / Theme / World / Event, inspect view, **collection milestones** (permanent coin/luck %) and titles ·
Rebirth, 8 upgrades, capped Luck, Shop, Settings, promo codes (`CodesConfig`, button in Settings), daily rewards, quests (incl. steal / recover / slap), achievements,
server-wide rare announcements, audio feedback for every step of the loop.

**Extending:** new floor → add an entry to `FloorConfig.Floors` and a `furnish` function in `HouseBuilder/Tower.luau`; new rarity → `RarityConfig`; new rebirth tier →
`RebirthConfig` tables; new icon → one entry in `UI/Icons.luau`; events / limited hamsters → `HamsterDatabase` (`Exclusive`) + `CodesConfig` / `DailyRewardConfig`.

## Structure

```
src/
  ReplicatedStorage/Modules/   configs, WorldLayout, PathConfig, Route, HamsterStates, SecurityConfig, IndexRewardConfig, HamsterGroups, HamsterBuilder/ ...
  ReplicatedStorage/Remotes/   RemoteEvents + one validated Request function
  ServerScriptService/Systems/ HamsterSystem, SecuritySystem, CombatSystem, PlayerState, HouseSystem, Economy, Collection, Rebirth, ... WorldBuilder/
  StarterPlayer/StarterPlayerScripts/Controllers + UI/   WorldController (rolling balls), Input, Combat, Security, Nav, Ambient (wheels), Fx, Audio ...
```

## Model library

`ModelLibrary/` (catalog: [`ModelLibrary/README.md`](ModelLibrary/README.md)) is generated from the game's own builders by `tools/ExportModels/` (`export_models.py --update`, `--check`, `--test`).
Every asset has its own folder with `README.md` (hierarchy, pivot, dependencies, attributes), `model-config.lua`, `build-model.lua` and optional `scripts/`.

## What you still have to fill in

- `AudioConfig.Music.Tracks`: paste licensed `rbxassetid://` music ids (SFX use built-in Roblox sounds; some of them may sound different from what you want).
- `ShopConfig`: gamepass / developer-product ids are `0` ("coming soon").
- `CodesConfig`: your own promo codes.

## Verification status — please read

Checked here (no Roblox Studio is available in this environment):
`rojo build`, `luau-lsp` typecheck (clean), and a **mock-Roblox simulation** that runs the real server + client scripts:
- game loop (109 checks, incl. shop purchases, double-click protection, hotbar items, tutorial and banner transitions): claim → roll home → secure → wheel runs → income; steal → carry → slap → drop → recover → secure; insurance; security expiry / re-arm / zap;
  entering open houses; stealing inside an open house; overtaking and no-overlap on the road; anti-grief; rebirth requirements, reset and slot gain; save/load; Index UI
- wheels (5 checks): 216 wheels in 8 five-floor towers all turn about their axle and the floor under the hamster moves **against** its run direction; 8 stations per floor, elevator + landings exist
- economy: price/income strictly increase with rarity, spawn chances, rebirth table, floor unlocks, requirement checks
- UI (72 checks): all 9 panels open/close, 52 icons draw, HUD has four indicators and no sidebar, hotbar keys select/use items through the server, shop categories, base banners, tutorial steps, nameplate size, no emoji in any UI text, the first-person cursor sequence (third person → first person → Settings → close → Index → close → third person),
  ball tag anchors never rotate.

**Not verified:** how it looks and feels in real Studio (colours, camera, lighting, model quality, performance of the bigger world), real physics/character behaviour
(knockback, humanoid states), the real camera scripts' mouse handling (the cursor fix is tested against a stand-in), network latency, mobile performance, audio.
Wheels are client-animated anchored parts (not HingeConstraint / AngularVelocity): the turning direction is computed from the run direction and verified numerically.
Expect balance and polish tuning after the first real playtest (numbers: `RarityConfig`, `RebirthConfig`, `FloorConfig`, `UpgradeConfig`, `HamsterStates`, `SecurityConfig`).
