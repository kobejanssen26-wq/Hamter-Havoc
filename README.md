# 🐹 Hamster Plaza

A cozy hamster-collection simulator for Roblox, written in Luau and synced with [Rojo](https://rojo.space).

Loop: **hamsters walk the road → you collect them → they earn coins → upgrade → rarer hamsters → fill the Index → Rebirth → repeat.**

## Run it

1. Install tools: `rokit install` (installs Rojo 7.4.4 from `rokit.toml`).
2. Build the place: `rojo build -o HamsterPlaza.rbxl` and open it in Roblox Studio
   (or `rojo serve` + the Rojo plugin to live-sync).
3. In Studio: **Game Settings → Security → Enable Studio Access to API Services** (needed for DataStore saving).
4. Press Play (or Test with 2 players). The world (houses, plaza, road, forest) is generated at runtime by `WorldBuilder`.

## Controls
- **E / tap / click** – collect a hamster near you
- **F** – interact with world prompts (house, plaza stalls)

## Structure
```
src/
  ReplicatedFirst/        LoadingScreen
  ReplicatedStorage/
    Modules/              configs (Rarity, Hamster database, Upgrades, Rebirth, Quests, Shop, Settings, Audio…),
                          EconomyMath, PathConfig, HamsterBuilder (procedural models)
    Remotes/              RemoteEvents + single Request function
  ServerScriptService/
    Config/CodesConfig    promo codes (single place)
    Systems/              Data, Economy, Spawn, Pickup, Collection, Rebirth, Upgrade, Quest, Reward,
                          Shop, Settings, House, Leaderboard, Announce, RequestRouter, WorldBuilder/
  StarterPlayer/StarterPlayerScripts/
    Controllers/          Data, Audio, Animator, Fx, World, Input, Settings, Ambient
    UI/                   Main HUD, Index, Inventory, Upgrades, Rebirth, Shop, Settings/Codes, Quests, Daily, Announcements
```

## Design notes
- Server-authoritative: every action goes through `RequestRouter` (validation + rate limit). Collecting is checked by distance and affordability.
- Each player gets their own hamster stream (id, species, spawn time, speed, price); position = `PathConfig.pointAt((now - spawn) * speed)`, so clients animate locally and the server stays cheap.
- 14 rarities, 164 hamster species built procedurally from primitive parts (Motor6D rig, animated client-side). Luck is capped.
- Saving: DataStore with session lock, autosave and `BindToClose`.

## What you must fill in
- `AudioConfig`: music track asset ids (`Music.Tracks` is empty; built-in placeholder sounds are used for SFX).
- `ShopConfig`: gamepass / developer product ids are `0` ("coming soon") until you create them on Roblox.
- `CodesConfig`: your own promo codes.

## Verification status (honest)
Verified here: `rojo build`, `luau-lsp` typecheck (clean), pure-logic tests (economy, luck, rebirth), and a mock-Roblox simulation of boot → join → client start → collect → requests → rebirth → second player (0 errors).
**Not verified:** real Roblox Studio / real devices. Visuals, performance on mobile, audio and DataStore behaviour have not been seen running. Expect small tuning/bug fixes after your first playtest.
The world is ~6.4k parts; see `Decor`/`HouseBuilder` if you need to trim further for low-end mobile.
