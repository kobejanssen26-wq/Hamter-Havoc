# 🐹 Hamster Plaza

A cozy multiplayer hamster game for Roblox (Luau + [Rojo](https://rojo.space)).

> Hamster balls roll down the road in the middle. **Claim** one by paying for it — but it is **not yours yet**.
> It rolls home to *your* house, and everybody else can **steal** it on the way. Carry it, defend it, **slap** thieves,
> and once it lands on the pad in your house it is **secured for good** and runs on a **hamster wheel** earning coins.
> Upgrade, rebirth, hunt rarer hamsters, fill the Hamster Index.

> **Waar staat wat?** Zie [`WAAR_STAAT_WAT.md`](WAAR_STAAT_WAT.md) (Explorer-kaart, Nederlands). De wereld en alle 172 hamsters staan als voorbeeldkopie in `world/` en zijn in Studio direct zichtbaar zonder Play.

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

- One straight, mirror-symmetric avenue (z = 0) with two lanes; both house rows are the same distance from it, so no side is favoured.
  Balls steer around each other (lane changes, overtaking) and a hard separation pass makes overlap impossible. They also steer around people on the road.
- Wide promenades (z = ±18) are where claimed balls roll home; a paved path joins every gate to the road.
- **Hamster Plaza** in the middle: golden-king arch over the road, Shop (north), Hamster Index library (south). Nothing else.
- **8 big plots** (48 × 58) with gaps between them: gate + security lasers, driveway, front yard, mailbox (daily gift), name sign, rebirth altar,
  a house with a wide door, an **arrival pad**, **12 wheel stations** (a wheel appears when the slot unlocks; the hamster really runs on it),
  8 upgrade pedestals, chest, back garden.
- **Security gate**: lasers zap strangers out of the lot (stun + knockback + dropped ball) while active. Timer is shown above every gate and in your HUD.
  Tiers by rebirth: Basic Gate 45 s → Advanced 60 s (R1) → Fortress 80 s (R3) → Royal Vault 100 s (R6). Then recharge, then you press E at the pylon.
  While it is off anybody can walk in (and steal a ball that is still rolling to/at the pad). **Secured hamsters can never be stolen.**
  (To change the number of houses edit `WorldLayout.HouseColumns` only.)

## Content

14 rarities · 172 unique procedural hamster designs (built from primitives, rigged with Motor6D, animated on the client) ·
Hamster Index with browse-by Rarity / Theme / World / Event, inspect view, **collection milestones** (permanent coin/luck %) and titles ·
Rebirth, 8 upgrades, capped Luck, Shop, Settings, promo codes (`CodesConfig`), daily rewards, quests (incl. steal / recover / slap), achievements,
server-wide rare announcements, audio feedback for every step of the loop.

## Structure

```
src/
  ReplicatedStorage/Modules/   configs, WorldLayout, PathConfig, Route, HamsterStates, SecurityConfig, IndexRewardConfig, HamsterGroups, HamsterBuilder/ ...
  ReplicatedStorage/Remotes/   RemoteEvents + one validated Request function
  ServerScriptService/Systems/ HamsterSystem, SecuritySystem, CombatSystem, PlayerState, HouseSystem, Economy, Collection, Rebirth, ... WorldBuilder/
  StarterPlayer/StarterPlayerScripts/Controllers + UI/   WorldController (rolling balls), Input, Combat, Security, Nav, Ambient (wheels), Fx, Audio ...
```

## What you still have to fill in

- `AudioConfig.Music.Tracks`: paste licensed `rbxassetid://` music ids (SFX use built-in Roblox sounds; some of them may sound different from what you want).
- `ShopConfig`: gamepass / developer-product ids are `0` ("coming soon").
- `CodesConfig`: your own promo codes.

## Verification status — please read

Checked here (no Roblox Studio is available in this environment):
`rojo build`, `luau-lsp` typecheck (clean), and a **mock-Roblox simulation** that runs the real server + client scripts (75 checks, 0 script errors):
claim → roll home → secure → wheel runs → income; steal → carry → slap → drop → recover → secure; thief secures at own house + insurance;
security expires / recharge / manual re-arm / zap; entering open houses; stealing inside an open house; overtaking and no-overlap on the road;
anti-grief cases; rebirth; save/load; Index UI. Also: all 172 hamsters build, a top-down plot of the generated layout.

**Not verified:** how it looks and feels in real Studio (colours, camera, lighting, model quality), real physics/character behaviour
(knockback, humanoid states), network latency, mobile performance, audio. The simulation uses simplified physics and a mocked Roblox API.
Expect balance and polish tuning after the first real playtest (all numbers are in `HamsterStates.luau`, `SecurityConfig.luau`, `RarityConfig.luau`).
