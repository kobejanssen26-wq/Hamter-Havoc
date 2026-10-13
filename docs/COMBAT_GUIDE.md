# Combat guide

Everything about hitting, weapons, abilities and their animations. The code: `ServerScriptService/Systems/CombatSystem`, `AbilitySystem`, `PlayerState`;
shared timing in `Modules/CombatTiming`; settings in `Modules/GameConfig` (section `Combat`, `Abilities`) and one file per weapon in `Modules/Content/Items`.

## 1. Who decides what

| Question | Decided by |
|---|---|
| "I swing" | the client sends only `Attack(aim)`; **there is no remote through which a client can report a hit or damage** |
| Which weapon do I hold | the server (`GearSystem.equippedWeapon`: you must own the item and hold its Tool) |
| Cooldown, range, arc, knockback, stun | the server, from the item file and `GameConfig` caps |
| Who is hit | the server, by sampling the hit area while the swing is active |
| What a hit does | `CombatSystem.applyHit` (stun, knockback, hit immunity, theft rules) |

## 2. The swing lifecycle

`CombatTiming` gives every attack three phases, counted from the moment the server accepts the swing:

```
request ──► WindUp ──► Active ──────────► Recovery ──► idle
            (nothing    (the ONLY time a     (nothing hits;
             can hit)    hit can land)        next swing needs Cooldown)
```

* Defaults per type: Melee `WindUp 0.12 / Active 0.2`, Ranged `0.1 / 0.05`, Freeze `0.2 / 0.05`. An item may set `WindUp` and `Active` in its `Weapon` table. `Cooldown >= WindUp + Active` is enforced by the validator. `Cooldown` counts from the START of the swing.
* At the request the server tells every client (`Fx "Swing"`) so everyone plays the same animation; the sound plays when the weapon becomes active.
* A swing is cancelled when the attacker dies, is stunned/frozen, or puts the weapon away.

## 3. Hit detection (melee)

Every Heartbeat during the active window the server samples each other player:

1. **Eligible?** alive, not the attacker, not spawn-protected / in hit-immunity, not inside a `SafeZone`; the attacker must not stand in a safe zone either.
2. **Sweep:** the target is tested at its current position *and along the path it moved since the last sample*, so a runner cannot slip between two frames.
3. **Reach:** horizontal distance (to the closest point of that path) `<= Range + grace`; `grace = LatencyGrace * clamp(speed/16, 0, 1)`. A standing target gets no grace (range is exact); a sprinting one gets up to `LatencyGrace` (default 3 studs) so lag does not make you miss.
4. **Arc:** `dot(attacker look, direction to target) >= Arc` (or closer than 1.5 studs). Height difference at most 6 studs.
5. **Wall check:** a ray from the attacker to the target must not hit anything solid (`GameConfig.Combat.WallCheck`).
6. Per swing every player is decided **once** (a swing cannot hit twice); by default one player per swing (`MaxTargetsPerSwing`, nearest first).

Ranged and Freeze fire once at the end of the wind-up along the (validated) aim direction; the client sends a direction, never a target or position.
`Combat.PvpNeedsHamsterNearby = true` restores the old rule that attacks only land near a hamster that is rolling, carried or dropped (default: off — hitting works anywhere outside safe zones, with or without a carried hamster).

## 4. What a hit does

* **Stun** = `min(Stun, MaxStunSeconds)`; **knockback** = horizontal `min(Knockback, MaxKnockback)` + lift `min(Lift, MaxKnockbackLift)` (applied by the victim's own client from a server event, because a client owns its character's physics).
* **Hit immunity** (`HitImmunitySeconds`, after the stun) so two attackers, or one attacker spamming, cannot stack stun or knockback.
* **Spawn protection** (`SpawnProtectionSeconds`) after every respawn; stun/freeze/carry slowdown are cleared when a new character spawns, so nobody can be left immobilised.
* **Theft rules (unchanged design):** when the OWNER of a hamster that is being carried off hits the thief, `TheftSystem.ownerHit` decides (theft fails, hamster back on its wheel). Any other hit on a carrier drops the hamster with `DropChance`. A hit on a player carrying nothing is a normal hit. Ownership of hamsters is never touched by combat code.
* **Guard (shield)** blocks stun and knockback (not the theft/drop rules), cannot be raised while carrying a hamster.

## 5. Abilities (registered implementations only)

`Freeze` (aim ray, `Duration <= FreezeMaxSeconds`, immune afterwards), `Cloak` (invisibility; no immunity, ends on attack/hit/pickup/respawn), `Decoy` (see-through look-alike, a model only), `Guard`.
Add a NEW ability type: add its limits to `ContentValidator.ABILITY_LIMITS`, the implementation to `AbilitySystem`, a branch in `CombatSystem.attack`, a default in `CombatTiming.Defaults`. An item file can only choose among these; it can never contain code.

## 6. Animations

`Controllers/WeaponAnimator` plays the swing on every client:

1. If the item's `Weapon.Animation` names a `Content/Animations` entry **with an AssetId**, that animation is played (priority `Action2`, above running and emotes; the speed is scaled so it ends when the cooldown does). A failing asset id warns once and falls back.
2. Otherwise a built-in procedural swing moves the Tool's grip (shape from `Look.Swing`: `Overhead`, `Side`, `Thrust`, `Punch`, `Recoil`, `Raise`) or the right shoulder for bare paws. So a new weapon is never frozen.

No animation ids are included: none could be verified. To make your own: Animation Editor on an R15 rig → add a marker named `Hit` where the weapon should connect (the server does not need it: the hit window comes from `WindUp`/`Active`; match those two numbers to your animation) → *Publish to Roblox* → paste `rbxassetid://…` into `Content/Animations/Weapon_*.luau`. The animation must be owned by you/your group.
Emotes and swings never run together: attacking stops the current emote, and the server refuses an emote mid-swing. Emotes stop after `EmoteConfig.MaxSeconds`, on movement, jump, death or respawn. An R15 animation on an R6 character is skipped with a one-time warning.

## 7. The weapons

| Weapon | Rebirth | Price | Role | Range | Cooldown | Knockback | Stun |
|---|---|---|---|---|---|---|---|
| Mega Slap Glove | 0 | 1,500 cash | fast, first weapon (better than paws in reach, speed, drop chance) | 9 | 0.7 s | 34 | 0.7 s |
| Squeak Bat | 0 | 8,000 cash | long reach, heavy | 11 | 1.2 s | 54 | 1.0 s |
| Spring Boxing Glove | 1 | 40,000 cash | big shove, narrow | 12 | 1.7 s | 60 | 0.6 s |
| Frost Wand | 1 | 90,000 cash | freeze for 2 s (20 s cooldown) | 45 | 20 s | – | 2 s freeze |
| Bubble Shield | 2 | 120,000 cash | blocks stun + knockback for 3 s (22 s cooldown) | – | 22 s | – | – |
| Shock Baton | 2 | 160,000 cash | rapid taps, long stun, tiny shove | 7 | 0.55 s | 16 | 1.3 s |
| Seed Slingshot | 2 | 150,000 cash | ranged, aimed | 55 | 1.8 s | 30 | 0.8 s |
| Shadow Cloak | 3 | 400 diamonds | invisibility 6 s (sparkle trail counterplay) | – | 45 s | – | – |
| Party Hammer | 4 | 600,000 cash | wide slow smash, strongest shove | 12 | 2.2 s | 60 | 1.4 s |
| Mirror Clone | 5 | 900 diamonds | decoy 8 s | – | 50 s | – | – |
| Banana Peel (trap) | 0 | 3,500 cash | slip trap: knocks the victim back + short stun, 3 at a time, lasts 40 s | – | 5 s | 40 | 0.9 s |
| Glue Trap (trap) | 1 | 30,000 cash | slows the victim to 35% speed for 4.5 s, lasts 40 s | – | see file | – | – |
| Spike Trap (trap) | 2 | 75,000 cash | stuns 1.5 s and makes a carrier drop the hamster, lasts 60 s | – | see file | – | 1.5 s |

All numbers live in the item files; the table is a snapshot. Every damage weapon is capped by `GameConfig` (knockback 60, lift 28, stun 1.6 s).

## 7b. Traps

Type `Trap` (files `BananaPeel`, `GlueTrap`, `SpikeTrap` in `Content/Items`). Using the item places a trap on the ground in front of you (`TrapSystem`, server). Rules:
* limits: `MaxActive` per player, a trap is armed after `Arm` seconds and disappears after `Duration`; none inside a `SafeZone`, none while you carry a hamster;
* the server checks every 0.1 s who steps on an armed trap; the placer and spawn-protected players never trigger it;
* effects come only from the file: `Stun`, `Knockback`, `DropChance` (a carrier drops the hamster; if the trap's owner is the hamster's owner the normal theft rules decide), `Slow` + `SlowSeconds` (glue);
* all values are capped by `GameConfig` and `ContentValidator`. Kinds of look: `Look.Shape` = `Spike`, `Glue`, `Banana`.

## 8. Tests

`tools/SimTests/run.sh scn_combat.lua` (stationary / running-away / sprinting-across targets, running attacker, behind/side/far/above, walls, range, cooldown + button mashing, one hit per swing, caps, two attackers, respawn,
spawn protection, safe zones, forged remote payloads, abilities ending, emote vs swing). It runs the real server scripts inside a mock Roblox: it proves the rules, not how it feels. Not covered: real latency, real physics, real animations.
