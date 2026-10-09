# Hamster Plaza - Economy & Progression

All numbers live in code; this page explains them and shows what the simulation says.
Change them in the files named in each section, then rerun `tools/lune/economy_sim.luau` (see the bottom).

## One formula for every hamster (`RarityConfig.luau`, `HamsterDatabase.luau`)

```
price  = rarity.Price x valueMult           valueMult goes from 1.0 (first of its rarity) to 1.5 (last), evenly
income = price / rarity.Payback             (coins per second, before multipliers)
```

Prices are rounded to 2 significant digits. Because every rarity's cheapest hamster costs more than the previous
rarity's most expensive one (rarity price steps are 4-5x, the spread inside a rarity is 1.5x), **a rarer hamster always
costs more and earns more**; the test suite checks this for all 172 hamsters. Payback grows with rarity, so rare
hamsters are worth more per hamster but are not a free win per coin spent.

| Rarity | Base price | Payback (s) | Spawn weight | From rebirth |
|---|---|---|---|---|
| Basic | 100 | 60 | 520 | 0 |
| Cute | 450 | 80 | 250 | 0 |
| Shiny | 2,000 | 110 | 120 | 0 |
| Rare | 9,000 | 150 | 60 | 0 |
| Epic | 40,000 | 200 | 24 | 0 |
| Ultra | 180,000 | 260 | 10 | 0 |
| Legendary | 800,000 | 340 | 4 | 0 |
| Mythic | 3.6M | 440 | 1.6 | 1 |
| Divine | 16M | 560 | 0.6 | 3 |
| Cosmic | 75M | 700 | 0.25 | 5 |
| Celestial | 340M | 880 | 0.12 | 7 |
| Secret | 1.5B | 1,100 | 0.05 | 9 |
| Ancient | 7B | 1,400 | 0.02 | 12 |
| Unknown | 35B | 1,800 | 0.004 | 15 |

The exact price, income/s and spawn chance of every hamster are in `Models/ASSET_INDEX.md` and each
hamster's `metadata.json`.

## Income per second (`EconomyMath.luau`)

```
income/s = sum over working hamsters of  hamster income x (1 + floor wheel bonus)
           x rebirth multiplier x upgrades (Hamster Training, Coin Multiplier, Turbo Wheels) x index milestones x boosts
```

The best hamster is placed on the wheel with the biggest floor bonus. Slots = rebirth slots + Extra Storage
upgrade (+ gamepass), never more than the wheels your floors have (6 per floor).

## Apartment floors (`FloorConfig.luau`)

| Floor | Name | Unlocks at | Wheels | Wheel bonus | Luck | What it adds |
|---|---|---|---|---|---|---|
| 1 | Workshop | start | 6 basic | - | - | arrival pad, coin upgrade stations, chest |
| 2 | Hamster Lofts | Rebirth 2 | 6 basic | +10% | - | more slots, lounge |
| 3 | Research Lab | Rebirth 5 | 6 advanced | +20% | - | advanced upgrades (Turbo Wheels, Lucky Charms) |
| 4 | Golden Suites | Rebirth 9 | 6 golden | +40% | +5% | high-tier production |
| 5 | Penthouse | Rebirth 14 | 6 diamond | +75% | +10% | rooftop terrace, pool |

The next floor is shown as scaffolding with a sign "unlocks at Rebirth N". Rebirth 10 / 15 / 20 add gold bands,
a crown and light strips to the outside.

## Rebirth (`RebirthConfig.luau`)

A rebirth needs **coins + a number of secured hamsters + one hamster of a minimum rarity**. Each rebirth is
clearly harder than the last (coins x4.5 per step after R10).

| Rebirth | Coins | Needs a | Secured hamsters | Income multiplier | Slots | Floors | Luck | Best hamsters kept |
|---|---|---|---|---|---|---|---|---|
| R1 | $2.50M | Rare | 6 | x1.25 | 4 | 1 | 0% | 0 |
| R2 | $12.0M | Epic | 8 | x1.5 | 5 | 2 | 5% | 0 |
| R3 | $55.0M | Epic | 10 | x1.75 | 6 | 2 | 5% | 0 |
| R4 | $250M | Ultra | 12 | x2 | 7 | 2 | 10% | 1 |
| R5 | $1.10B | Ultra | 14 | x2.25 | 8 | 3 | 10% | 1 |
| R6 | $5.00B | Legendary | 16 | x2.6 | 9 | 3 | 15% | 1 |
| R7 | $22.0B | Legendary | 18 | x2.95 | 10 | 3 | 15% | 1 |
| R8 | $100B | Mythic | 20 | x3.3 | 11 | 3 | 20% | 2 |
| R9 | $450B | Mythic | 22 | x3.65 | 12 | 4 | 20% | 2 |
| R10 | $2.00T | Mythic | 24 | x4 | 13 | 4 | 25% | 2 |
| R12 | $40.5T | Divine | 28 | x5 | 15 | 4 | 30% | 3 |
| R14 | $820T | Cosmic | 32 | x6 | 17 | 5 | 35% | 3 |
| R16 | $16.6Qa | Cosmic | 36 | x7 | 19 | 5 | 40% | 4 |
| R20 | $6.81Qi | Celestial | 40 | x9 | 23 | 5 | 50% | 5 |

Max 25 rebirths. Milestones at R5, R10, R15, R20, R25 give extra gems and tokens.

**Resets:** coins, coin upgrades, hamsters and wheels (except the best N hamsters above, which go straight back on a wheel).
**Kept:** Hamster Index, rebirths, floors and slots, multipliers and luck, gems and tokens, token upgrades, cosmetics.
You start each life with `150 x 1.5^rebirths` coins.

## Simulation results (`tools/lune/economy_sim.luau`)

One player alone on a server (a hamster spawns every ~5.25 s). The *active* player catches 85% of the hamsters
they can afford, buys upgrades and rebirths as soon as possible; the *casual* player catches 55%.
Seed 7, 24 simulated hours.

**Active player**

| Time | Rebirth | Floors | Slots | Income/s | Best hamster |
|---|---|---|---|---|---|
| 5 min | R0 | 1 | 3 | 16 | Cute |
| 15 min | R0 | 1 | 4 | 272 | Shiny |
| 30 min | R0 | 1 | 4 | 4.8K | Epic |
| 1 h | R1 | 1 | 6 | 2.7K (just reset) | Rare |
| 2 h | R2 | 2 | 7 | 36K | Ultra |
| 3 h | R3 | 2 | 8 | 197K | Legendary |
| 5 h | R5 | 3 | 10 | 851K | Mythic |
| 10 h | R7 | 3 | 12 | 485K (just reset) | Mythic |
| 20 h | R9 | 4 | 15 | 206M | Secret |

Rebirths at: R1 32 min, R2 1.3 h, R3 2.2 h, R4 3.1 h, R5 4.3 h, R6 6.0 h, R7 9.5 h, R8 13.2 h, R9 18.0 h, R10 22.0 h.

**Casual player**

| Time | Rebirth | Floors | Slots | Income/s | Best hamster |
|---|---|---|---|---|---|
| 5 min | R0 | 1 | 3 | 7 | Basic |
| 15 min | R0 | 1 | 3 | 45 | Cute |
| 30 min | R0 | 1 | 5 | 420 | Shiny |
| 1 h | R1 | 1 | 4 | 31 (just reset) | Cute |
| 3 h | R2 | 2 | 7 | 6.2K | Epic |
| 5 h | R4 | 2 | 9 | 50K | Legendary |
| 10 h | R6 | 3 | 11 | 660K | Mythic |
| 20 h | R8 | 3 | 13 | 25M | Celestial |

Rebirths at: R1 53 min, R2 2.0 h, R3 3.5 h, R4 4.8 h, R5 6.6 h, R6 8.7 h, R7 12.7 h, R8 19.8 h.

What this means: the first rebirth comes after roughly half an hour to an hour, the second floor after 1.5-2 hours,
the third floor (Research Lab) after 4-7 hours, the fourth after ~18 hours of active play, and the Penthouse is a
long-term goal (several days). More players on a server means more competition for each hamster (and more stealing),
so real numbers will be somewhat slower; tune `RebirthConfig.CoinCosts` first if rebirths feel too fast or slow.

## Rerun it

```
lune run tools/lune/economy_sim.luau [hours=12] [seed=7] [profile=active|casual]
```

The simulation uses the real config modules (`RarityConfig`, `HamsterDatabase`, `RebirthConfig`, `FloorConfig`,
`UpgradeConfig`, `EconomyMath`), so it always matches the game.
