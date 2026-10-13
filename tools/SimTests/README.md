# SimTests

Runs the **real game scripts** (all server systems and the client UI/controllers) inside a mock Roblox environment (`mock.lua`, API
shapes from `classes.lua`) and checks game logic. Needs the `luau` binary (`LUAU=/path/to/luau`) and `python3`.

```
tools/SimTests/run.sh --all            # every scenario, one summary line each + all failures
tools/SimTests/run.sh scn_theft.lua    # a single scenario with full output
```

| Scenario | What it checks |
|---|---|
| `scn_loop` | claim → roll home → steal → carry → slap → drop → recover → secure, security gate, rebirth, shop/hotbar/tutorial, save/load |
| `scn_theft` | rack theft (locked base, validation, owner hit, completion, duplicates, gate trap + 60 s timeout, death, disconnect, owner leaves, rebirth), rebirth gate time, elevators |
| `scn_gear` | items/weapons/equipment: validation, server-side purchases, hotbar layout, equip rules, melee + ranged combat (range, cooldown, aim, walls, theft interruption), game-pass flow with a mock MarketplaceService, hotbar/shop/backpack UI geometry and behaviour |
| `scn_combat` | the rebuilt combat: stationary / moving / running targets, directions, walls, cooldown, one hit per swing, knockback + stun caps, respawn + spawn protection, safe zones, forged remote payloads, abilities ending, emote vs swing, GameConfig wiring (gate cooldown) |
| `scn_admin` | admin panel + config: authorization (ordinary players get nothing), roles, rank rules, limits, confirmation, validation, audit log, bans, live settings that survive a restart, shop overrides, panel not on the HUD |
| `scn_hud` | Studio-editable HUD: templates (`src/StarterGui`) are adopted by the code with Studio edits kept, no duplicates, leftovers removed (run twice and compared). `bake_hud.sh` regenerates the templates, `--check` tests they are current |
| `scn_rebirth` | rebirth keeps the whole collection and the bench (same hamsters, same places), save/leave/rejoin, auto-place never replaces, hamster catalog (new fields, balance, limited editions) |
| `scn_world` | Studio-owned Environment is kept on Play, mountain placement/shape/budget, Lighting ownership |
| `scn_audit` | geometry audit of the generated world: solid objects of different buildings intersecting, buried or floating parts (with a self-test that proves the audit can see a problem) |
| `scn_tutorial` | 7-step tutorial: tagged real targets (your own base only), markers follow moved objects, skip / replay / persistence |
| `scn_lb` | leaderboards: period buckets, scoring rules, caching, outages, persistence across sessions |
| `scn_ui` | HUD regions (6 screen sizes: no overlap, on screen, top-centre under the top bar), layers, UI registry rules, hotbar, shop, leaderboard screen, tutorial, panels, cursor |
| `scn_content` | content validator, custom hamsters (good + deliberately broken files), animation registry, key bindings, emote server rules, emote wheel (B) |
| `scn_econ`, `scn_wheels`, `scn_game` | economy numbers, wheel rotation, many-player lifecycle |

**What the mock cannot tell you**: how anything looks or feels, real physics/Humanoid behaviour, real camera scripts, latency, real DataStore limits, real
animation assets, performance on phones. Those need Roblox Studio — see the checklist in `docs/SYSTEMS.md`.
