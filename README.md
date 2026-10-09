# Hamster Plaza

A cozy multiplayer hamster game for Roblox (Luau + [Rojo](https://rojo.space)).

> Hamster balls roll down the road in the middle. **Claim** one by paying for it — but it is **not yours yet**.
> It rolls home to *your* house, and everybody else can **steal** it on the way. Carry it, defend it, **slap** thieves,
> and once it lands on the pad in your house it is **secured for good** and runs on a **hamster wheel** earning coins.
> Upgrade, rebirth, hunt rarer hamsters, fill the Hamster Index.

> **Waar staat wat?** Zie [`WAAR_STAAT_WAT.md`](WAAR_STAAT_WAT.md) (Explorer-kaart, Nederlands). De wereld en alle 172 hamsters staan als voorbeeldkopie in `world/` en zijn in Studio direct zichtbaar zonder Play.
>
> **Every model as a file:** [`Models/`](Models/README.md) (`.rbxm` + `.glb` + metadata, index in [`Models/ASSET_INDEX.md`](Models/ASSET_INDEX.md)).
> **Economy and rebirth numbers + simulation:** [`ECONOMY.md`](ECONOMY.md).

## Run it

1. `rokit install` (installs Rojo 7.4.4 and Lune from `rokit.toml`).
2. `rojo build -o HamsterPlaza.rbxl`, open it in Roblox Studio (or `rojo serve` + the Rojo plugin).
   `HamsterPlaza.rbxl` is also committed, prebuilt.
3. Studio → Game Settings → Security → **Enable Studio Access to API Services** (DataStore saving).
4. Press Play / **Test with 2+ players**. The world you see in the editor is a preview copy (`world/*.rbxm`, rebuild it with `lune run tools/lune/bake_world.luau .`); on Play the server rebuilds it from code.

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

- One straight, mirror-symmetric avenue (z = 0, 22 studs wide, two lanes); both house rows are the same distance from it, so no side is favoured.
  Balls steer around each other (lane changes, overtaking) and a hard separation pass makes overlap impossible. They also steer around people on the road.
  At most 14 balls are on the road at once.
- Wide promenades (z = +-23) are where claimed balls roll home; a paved path joins every gate to the road.
- **Hamster Plaza** in the middle: a large paved square with a golden-king arch over the road, Shop (north), Hamster Index library (south),
  planter trees, benches and flower beds. Nothing else, so it stays readable.
- **8 big lots** (76 x 96 studs) far apart (house columns at x = -176, -80, 80, 176), street lamps and big trees in the gaps.
- **Landscape around the map** (outside the playable area): forest with clearings, rolling hills, a lake, two rings of mountains, drifting clouds and birds.

### Your apartment (grows with Rebirths)

Every lot has a modern apartment building that gains floors as you rebirth (`FloorConfig.luau`):

| Floor | Unlocks | Purpose |
|---|---|---|
| 1 Workshop | start | 6 wheels, arrival pad, coin upgrade stations, chest |
| 2 Hamster Lofts | Rebirth 2 | 6 more wheels, +10% income on this floor, lounge |
| 3 Research Lab | Rebirth 5 | 6 advanced wheels (+20%), lab with the advanced upgrades |
| 4 Golden Suites | Rebirth 9 | 6 golden wheels (+40%), +5% luck |
| 5 Penthouse | Rebirth 14 | 6 diamond wheels (+75%), +10% luck, rooftop terrace with pool |

A glass lift (press E) takes you up a floor. The next floor is shown as scaffolding with "unlocks at Rebirth N".
Rebirth 10 / 15 / 20 add gold bands, a crown and light strips to the facade. Every floor is furnished.

- **Wheels**: a hamster really runs inside; the wheel turns around its axle in the running direction
  (`HouseBuilder.spinSign`, spun on the client by `AmbientController`). The best hamster gets the wheel with the biggest bonus.
- **Security gate** at the entrance: lasers zap strangers out of the lot (stun + knockback + dropped ball) while active. Timer is shown above every gate and in your HUD.
  Tiers by rebirth: Basic Gate 45 s, Advanced 60 s (R1), Fortress 80 s (R3), Royal Vault 100 s (R6). Then recharge, then you press E at the kiosk.
  While it is off anybody can walk in (and steal a ball that is still rolling to/at the pad). **Secured hamsters can never be stolen.**
  (To change the number of houses edit `WorldLayout.HouseColumns` only.)

## Content

14 rarities, 172 unique procedural hamster designs (built from primitives, rigged with Motor6D, animated on the client).
Hamster Index (browse by Rarity / Theme / World / Event; every card shows Working / Owned / Discovered / Missing; collection milestones).
Rebirth with real requirements (coins + secured hamsters + a minimum rarity) and permanent rewards, 10 upgrades (2 unlock with the Research Lab),
capped luck, Shop, Settings, promo codes (`CodesConfig`), daily rewards, quests, achievements, server-wide rare announcements, audio for every step.

**Economy:** one formula for every hamster (`price = rarity price x 1.0-1.5`, `income = price / payback`), so a rarer hamster always costs
and earns more. Rebirth table and simulation results (5 min to 20 h, active and casual players) are in [`ECONOMY.md`](ECONOMY.md).

**UI:** a cute, rounded design with drawn icons (no emoji anywhere: `IconShapes.luau` + `UI/Icons.luau`, the same shapes are exported as PNG
to `Models/UI/Icons`), wallet top-left, menu buttons (Hamsters, Index, Rebirth, Upgrades, Daily, Quests, Shop, Settings), animated windows (0.15-0.3 s).
Opening any window frees the mouse, also in first person (`UIKit.windowOpened`). Labels above hamster balls are BillboardGuis on a separate
anchor that only moves, never turns, so they stay upright while the ball rolls.

## Structure

```
src/
  ReplicatedStorage/Modules/   configs, WorldLayout, PathConfig, Route, HamsterStates, SecurityConfig, IndexRewardConfig, HamsterGroups, HamsterBuilder/ ...
  ReplicatedStorage/Remotes/   RemoteEvents + one validated Request function
  ServerScriptService/Systems/ HamsterSystem, SecuritySystem, CombatSystem, PlayerState, HouseSystem, Economy, Collection, Rebirth, ... WorldBuilder/
  StarterPlayer/StarterPlayerScripts/Controllers + UI/   WorldController (rolling balls), Input, Combat, Security, Nav, Ambient (wheels), Fx, Audio ...
world/          editor preview of the world (baked .rbxm, replaced on Play)
Models/         asset library: every model as .rbxm + .glb + metadata (generated from the code)
tools/          lune/ (mock-Roblox runtime, tests, economy simulation, exporters), render.py / render_gui.py (screenshots without Studio)
```

## Tools (no Studio needed)

| Command | What it does |
|---|---|
| `lune run tools/lune/tests.luau .` | builds the world, every hamster, every floor and checks layout, economy and rebirth rules (1644 checks) |
| `lune run tools/lune/server_test.luau .` | runs the real server scripts with mocked players: claim, secure, wheels, rebirths up to R14 and 5 floors (100 checks) |
| `lune run tools/lune/client_test.luau .` | runs the real client scripts: HUD, every window, mouse release (47 checks); `GUI_DUMP=dir` also dumps the UI for `tools/render_gui.py` |
| `lune run tools/lune/economy_sim.luau 24 7 active` | economy simulation (see ECONOMY.md) |
| `tools/build_models.sh` | rebuilds `Models/` |
| `lune run tools/lune/bake_world.luau .` | rebuilds the editor preview in `world/` |

## What you still have to fill in

- `AudioConfig.Music.Tracks`: paste licensed `rbxassetid://` music ids (SFX use built-in Roblox sounds; some of them may sound different from what you want).
- `ShopConfig`: gamepass / developer-product ids are `0` ("coming soon").
- `CodesConfig`: your own promo codes.

## Verification status - please read

Checked here (no Roblox Studio is available in this environment): `rojo build`, `luau-lsp` typecheck (clean), and the three
mock-Roblox test suites above (1644 + 100 + 47 checks, 0 failures). They run the real server and client scripts: claim, roll home, secure,
wheel runs, income; steal, carry, slap, drop, recover; security; rebirths with requirements, kept hamsters and new floors;
every UI window opens without errors and frees the mouse. The world, the apartments (all floor stages) and every UI window were also
rendered to images and checked by eye.

**Not verified:** how it looks and feels in real Studio (lighting, materials, camera), real physics/character behaviour
(knockback, humanoid states), network latency, mobile performance, audio. The simulation uses simplified physics and a mocked Roblox API.
Expect balance and polish tuning after the first real playtest (numbers in `RarityConfig.luau`, `RebirthConfig.luau`, `FloorConfig.luau`,
`HamsterStates.luau`, `SecurityConfig.luau`).
