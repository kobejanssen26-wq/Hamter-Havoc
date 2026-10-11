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
| `scn_lb` | leaderboards: period buckets, scoring rules, caching, outages, persistence across sessions |
| `scn_ui` | HUD regions (6 screen sizes: no overlap, on screen, top-centre under the top bar), layers, UI registry rules, hotbar, shop, leaderboard screen, tutorial, panels, cursor |
| `scn_content` | content validator, custom hamsters (good + deliberately broken files), animation registry, key bindings, emote server rules, emote wheel (B) |
| `scn_econ`, `scn_wheels`, `scn_game` | economy numbers, wheel rotation, many-player lifecycle |

**What the mock cannot tell you**: how anything looks or feels, real physics/Humanoid behaviour, real camera scripts, latency, real DataStore limits, real
animation assets, performance on phones. Those need Roblox Studio — see the checklist in `docs/SYSTEMS.md`.
