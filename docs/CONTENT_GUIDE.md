# Content guide — add things yourself

Everything below is **local files in this repository** (edit in any editor, sync with Rojo, commit). Nothing needs a cloud
tool except where a Roblox asset id is unavoidable (uploading an animation or an icon) — those steps are marked **[upload]**.

Before testing, validate (see the last section). Typos are reported, never crash the game.

```
src/ReplicatedStorage/Modules/Content/
  Hamsters/    one .luau file per custom hamster       (_Template.luau = copy me)
  Emotes/      one .luau file per emote                (Wave, Point, Cheer, Laugh, Dance, Dance2 + _Template)
  Animations/  one .luau file per registered animation (_Template.luau)
  Items/       one .luau file per weapon / equipment / consumable (_Template.luau = copy me)
src/ReplicatedStorage/Assets/HamsterModels/   your own hamster models (.rbxm / .rbxmx)
src/StarterPlayer/StarterPlayerScripts/UI/    Theme.luau (look), UIRegistry.luau (buttons), UIKit.luau (components)
src/ReplicatedStorage/Modules/                FloorConfig, ShopConfig, AudioConfig, TheftConfig, LeaderboardConfig, EmoteConfig ...
```

Files named `_Something.luau`, or whose table has `Enabled = false`, are ignored by the game.

---

## 1. Add a hamster

1. Copy `Content/Hamsters/_Template.luau` to e.g. `Content/Hamsters/SilverHamster.luau` and delete `Enabled = false`.
2. Fill in the definition:

```lua
return {
	Id = "silver_hamster",          -- stable id: lowercase, digits, underscores. NEVER change it after release (saves use it)
	DisplayName = "Argent Nibbler", -- what players see
	Rarity = "Rare",                -- Basic Cute Shiny Rare Epic Ultra Legendary Mythic Divine Cosmic Celestial Secret Ancient Unknown
	Price = 25000,                  -- optional: cash to claim it (default: the rarity formula)
	IncomePerSecond = 350,          -- optional: cash/second on a wheel (default: price / rarity payback time)
	-- ModelName / Icon / Look / Animation / Sound / Effects / Unlock / SpawnWeight / Spawnable: see the template
}
```
3. Start the game. That is all: the hamster now rolls down the road (unless `Spawnable = false`), can be claimed, owned,
   equipped, sold, stolen, listed in the Index (with Index completion rewards) and counted by the leaderboards. No other
   script needs to change — every system reads the one registry (`HamsterDatabase`).
4. Rebirth requirements that name a species use its id (`RebirthConfig.RequiredSpecies = { [1] = "silver" }`).

### 2. Give it a model
* **Without a model**: the procedural hamster is built from `Look = { Fur = "C8935A", Belly = "F3DDB5", Ears = "round", Eyes = "dot", Size = 1 }`.
  Every species also gets its own stable body proportions (`HamsterBuilder.proportions`), override with `Look = { ... }` / `Build = { Width, Height, Length, Head }`.
* **With your own Studio model**: build it facing **-Z**, about **3.4 studs tall**, in a `Model` with a `PrimaryPart` (or a part named `Root`).
  Right-click the model in Studio → *Save to File…* → put the `.rbxm` in `src/ReplicatedStorage/Assets/HamsterModels/` (Rojo syncs it),
  then set `ModelName = "<model name>"`. Scripts inside are removed, parts are anchored/non-colliding by the game.
  Optional `Motor6D`s named `BodyJ HeadJ EarLJ EarRJ PawFLJ PawFRJ PawBLJ PawBRJ TailJ` get the built-in procedural walk/idle.
  If the model is missing or broken the game warns once and uses the procedural look.
* **Icon** (optional) **[upload]**: upload a PNG in Studio (Asset Manager → Add) and set `Icon = "rbxassetid://<id>"`.
  Without it the menus render a snapshot of the model. A placeholder like `rbxassetid://REPLACE_WITH_VALID_ASSET_ID` is reported as an error.
* Hamster-specific animations / sounds / effects: `Animation = { Idle = "Name", Walk = "Name" }` (names from `Content/Animations`),
  `Sound = { Spawn = "Coin" }` (names from `AudioConfig.Sfx`), `Effects = { { "sparkle", "FFD35A" } }`.

### Catalog fields, rarities and naming rules
`Id` (permanent), `DisplayName`, `Rarity`, optional `Price` / `IncomePerSecond` (otherwise the rarity formula, so a hamster can never break the economy), `SpawnWeight` (rarer inside its rarity),
`ModelName`, `Icon`, `Look`, `Effects`, `Animation`, `Sound`, `Unlock = { MinRebirth }`, `Description` (collection text), `Limited = { EndsAt, StartsAt? }` (limited edition), `Spawnable = false` (reward-only).
The rarity ladder is `RarityConfig` (Basic, Cute, Shiny, Rare, Epic, Ultra, Legendary, Mythic, Divine, Cosmic, Celestial, Secret, Ancient, Unknown): common-to-secret and beyond, each with its own spawn weight, unlock rebirth and visual effects.
Rarity is *balance* (how hard to get, how much it earns), never fame. Lowest income of a rarity must beat the best of the one below; the tests check this.

**Names and real people:** the bundled internet-culture hamsters (Lurker Larry, Viral Vera, Million Sub Milo ...) are original characters named after online *behaviour and archetypes*,
not after real streamers, YouTubers or celebrities, and use no logos or brand names. Do not add a real person's name, likeness, voice, channel logo or a recognisable branded character
without their written permission, and read Roblox's Terms of Use and Community Standards (impersonation, intellectual property) first: using someone's name can also suggest they endorse your game.
When in doubt use a parody archetype ("Clip Farmer Finn"), not a name.

## 3. Add an animation  **[upload]**
1. Make it in Studio's Animation Editor (R15 rig for player emotes; a custom rig for custom hamster models) → *Publish to Roblox* → copy the id.
2. Copy `Content/Animations/_Template.luau` → `Hamster_Walk.luau`, set `Name`, `AssetId = "rbxassetid://<id>"`, `Rig`, `Use`, `Priority`, `Looped`, `Speed`.
3. Use it: from an emote (`Animation = "Hamster_Walk"`), from a hamster (`Animation = { Walk = "Hamster_Walk" }`) or in code:
   `AnimationController.play(humanoid, "Hamster_Walk")`.
4. Check the upload loads: in Studio's *client* command bar run `require(game.StarterPlayer.StarterPlayerScripts.Controllers.AnimationController).preflight()`
   → prints `Success / Failure / NotSet` per animation. An entry without `AssetId` is simply skipped; a broken id warns once and is ignored.
   **No animation ids are shipped as defaults** — none can be invented. The default emotes use Roblox's own built-in emotes, which need no ids.

## 4. Add an emote
Copy `Content/Emotes/_Template.luau`. Choose ONE animation source: `Builtin = "wave"` (Roblox default emote: wave, point, dance, dance2, dance3, laugh, cheer),
`AnimationId = "rbxassetid://<id>"` **[upload]**, or `Animation = "<registry name>"`. Set `Icon` (a drawn icon, see `Icons.names()`),
`Default = true` or `Unlock = { MinRebirth = 2 }`, optional `Sound`, `Order`. The wheel shows up to 8 emotes (`EmoteConfig.MaxSlots`).
Open the wheel with **B** (players can choose another key in Settings → *Emote wheel key*; `InputConfig` checks for key conflicts) or the *Emotes* button
(this is how mobile players open it). The server decides whether you may use an emote (exists / unlocked / cooldown); the client plays it and stops it
when you move, jump, die or respawn.

## 5. Add a UI button or panel
Panel (a screen): copy any `UI/*UI.luau` (e.g. `QuestUI.luau`): `UIKit.panel({ Name = "Trophies", Title = "Trophies", Icon = "trophy", Design = Vector2.new(700, 500) })`,
build into `panel.Body`, add the module name to the `screens` list in `StarterPlayerScripts/Main.client.luau`.
Button that opens it — one registration, no HUD code:

```lua
UIRegistry.register({
	Id = "Trophies", Kind = "IconButton", Slot = "RightRail", Order = 60,
	Icon = "trophy", Tooltip = "Trophies", Panel = "Trophies",   -- or OnActivate = function() ... end
	Badge = function() return DataController.get("Stats").Trophies > 0 end,   -- optional red dot
})
```
`register` throws a clear error on: duplicate Id, replacing a `Core` entry, a conflicting `Order` in the same slot, a full slot (8 buttons), an unknown icon, a button with no action.
`UIRegistry.tryRegister` does the same without throwing (it warns). Colours, fonts, radii, spacing and layers live in `UI/Theme.luau` — change them there.
HUD layout rule: everything on the HUD lives in one of four regions (`MainUI.region("TopColumn" | "Rail" | "LeftColumn" | "BottomColumn")`) laid out by UIListLayouts;
add a frame to a region instead of positioning things by hand and nothing can overlap.

## 6. Configure a floor
`FloorConfig.Floors`: append `{ Index = 6, Name = "Sky Lounge", MinRebirth = 20, IncomeBonus = 0.1, LuckBonus = 0, Perk = "...", Feature = nil }`,
raise `FloorConfig.StationsPerFloor`-based capacity automatically, and add a `furnish` function for it in `WorldBuilder/HouseBuilder/Tower.luau` (`FURNISH` list).
Elevators are derived, not hard-coded: `FloorConfig.elevator(index, built)` → `Visible / Up / Down`. A one-floor tower has no elevator, a floor only gets an
*up* button when the next floor exists, every floor above the first gets a *down* button. Per-floor switches: `Elevator = { Visible = false }`, `{ Up = false }`, `{ Down = false }`.
The server validates every ride against the same function (`HouseSystem.useElevator`).
Rack theft only reaches floors listed in `TheftConfig.StealableFloors` (default: floor 1, because thieves cannot use the owner's elevator).

## 7. Shop, sounds, security, leaderboards (config only)
* Shop items: `ShopConfig.Items` (each names its `Currency` implicitly through `Coins =` / `Gems =` / `Robux =`; empty categories are hidden).
* Sounds: `AudioConfig.Sfx` (ids + base volume), `AudioConfig.Categories` (group volumes incl. `Gate`), `AudioConfig.MinInterval`, player setting *Gate & alarm sounds*.
* Gate time and the reopen cooldown: `GameConfig.Security` (`GateBaseDuration` 45 s, `GateSecondsPerRebirth` 10 s, `GateReopenCooldown` 7 s). Theft rules: `TheftConfig`.
* Leaderboards: `LeaderboardConfig` (metrics, periods, cache/flush times).

## 7b. Items: weapons, equipment, boosts (one file each)
Copy `Content/Items/_Template.luau`, rename it and fill it in. The item then appears **everywhere it belongs** with no UI code:
Shop (Weapons / Equipment / Boosts tab), Backpack, hotbar, and (weapons) as a real `Tool` in the player's Backpack.

| Category | `Equip.Kind` | What it does |
|---|---|---|
| `Weapon` | `Tool` | a real Tool. `Weapon = { Type = "Melee" / "Ranged" / "Freeze" / "Cloak" / "Decoy" / "Guard", Range, Arc, Cooldown, Knockback, Lift, Stun, DropChance, WindUp, Active, Animation = "<Content/Animations name>", Look = { Style = "glove" / "spring" / "baton" / "hammer" / "shield" / "bat" / "wand" / "slingshot" / "cloak" / "mirror", Color, Accent, Swing = "Overhead" / "Side" / "Thrust" / "Punch" / "Recoil" / "Raise" } }` - full explanation: `docs/COMBAT_GUIDE.md` |
| `Equipment` | `Passive` | works while owned. Supported `Stats`: `CollectRange`, `WalkSpeed` (a new stat needs code in `EconomyMath` first) |
| `Consumable` | `Consume` | counted; `Effect = "Boost"` (+`BoostId`, `Seconds`) or `"Pouch"` (+`Minutes`) |

Required: `Id` (lowercase letters/digits/underscore, **never change it later**), `DisplayName`, `Description`, `Category`, `Icon` (a drawn icon id from `UI/Icons.luau`, or a real `rbxassetid://<number>`), `Equip`.
For sale: `Currency` (`"Coins"` or `"Gems"`) **and** `Price` together. Without them the item is not in the shop. Optional: `Rarity`, `ModelName`
(your own Tool in `ReplicatedStorage/Assets/Tools/<ModelName>`; it needs a part called `Handle`, scripts inside it are ignored. If it is missing the built-in look is used and you get a warning).
Invalid files are skipped and listed by the content check (§8); a typo never crashes the game. Limits are enforced (range ≤ 60, cooldown ≥ 0.3 s ...), so no file can make a "spam" weapon.

**How weapons behave (all decided on the server, `CombatSystem`):** the client only says "attack" (+ an aim direction for ranged weapons). The server checks that you really own and hold the weapon, applies its own range/arc/cooldown,
and samples the hit area every frame during the active part of the swing (so moving targets are hit; walls block; safe zones and spawn protection apply). Weapons work with or without a carried hamster and never take health
(`GameConfig.Combat.PvpNeedsHamsterNearby = true` brings back the old "only near a hamster" rule). See `docs/COMBAT_GUIDE.md`.
A valid hit by the **owner** on a thief carrying a hamster uses the existing failed-theft path (`CombatSystem.theftHook` → `TheftSystem.ownerHit`); a hit by anybody else makes the carrier drop it with the weapon's `DropChance`.

**Hotbar:** slot 1 is always the paws (slap). Owned weapons/consumables fill slots 2–8 in the order you got them (`profile.Hotbar`); re-order in the Backpack. Keys 1–8, `I` opens the Backpack. Pressing a weapon's key equips it, pressing again puts it away.

### Abilities, rebirth locks (Content/Items)
Weapon `Type` can also be `Freeze` (Range, Cooldown, Duration <= 3 s), `Cloak` or `Decoy` (Cooldown, Duration). The rules live in
`ServerScriptService/Systems/AbilitySystem` and `CombatSystem`; the item file only picks numbers within hard caps. `MinRebirth = N`
keeps the item visible in the Shop with a lock and "Requires Rebirth N" and makes the server refuse the purchase below that level.
Current ladder: Mega Slap Glove (R0, 1,500 cash) - Squeak Bat (R0) - Spring Boxing Glove (R1) - Frost Wand (R1) - Bubble Shield (R2) - Shock Baton (R2) - Seed Slingshot (R2) - Shadow Cloak (R3) - Party Hammer (R4) - Mirror Clone (R5).
`Guard` is a shield: `Duration` 1-6 s, `Cooldown` 10-120 s.

### Characters (Content/Hamsters)
New fields: `Persona` (idle personality), `Inspiration` (who/what the joke is, why it is recognisable), `Licensed` / `LicensedName`
(a real name is shown ONLY when `Licensed = true`, i.e. when you hold the rights). Character props for `Look.Acc` are in `HamsterBuilder/Characters`
(cash_stack, sweater_vest, side_part, box_stack, mini_rocket, jersey, held_pie, quiff, trench_coat, held_microphone, headset_mic, bald_shine).

## 7c. Game passes (Robux) — `GamepassConfig.luau`
(The shop has two parts: **Cash Shop** and **Robux Shop**. Add `Enabled = false` to a pass to hide it. Diamond packs are developer products in `ShopConfig` (`Kind = "Product"`, `ProductId`, `Enabled`); `ProductId = 0` = not for sale.)
1. Creator Dashboard → your experience → Monetization → Passes → create the pass, copy its numeric **PassId**.
2. In `Modules/GamepassConfig.luau` set `PassId` on an existing entry or add one: `{ Key = "VIP", PassId = 123456, Name = ..., Description = ..., Icon = ..., Order = 60, Benefit = { CoinMult = 1.5 } }`.
   `Key` is permanent (it is stored in saves). Optional `Category` (default `Gamepasses`). Supported `Benefit` stats: `CoinMult`, `Luck`, `WalkSpeed`, `Slots`, `AutoCollect`.
3. `PassId = 0` means **not configured**: the pass is never purchasable, and it is only *listed* (greyed, "Not configured") while you test in Studio. In a live game players do not see it at all.
4. The Robux price is **not** in the config: the server asks Roblox (`MarketplaceService:GetProductInfo`), so it can't be out of date. There is no fake Robux balance anywhere; paying always goes through Roblox's own purchase prompt.
5. The benefit is granted only when `UserOwnsGamePassAsync` says the player owns the pass (checked on join, after the prompt closes, and with the *Refresh purchases* button). A client report of "I bought it" is never trusted.
6. Test in Studio: Game Settings → Avatar/Monetization → the pass must be on-sale or owned by your account; open the Shop → *Game Passes* → buy (Studio shows the official prompt; testing purchases of your own passes is free for the creator account). Then check the benefit (e.g. cash multiplier in the HUD) and rejoin to see it persist.

## 8. Validate before testing
* In Studio (server command bar):
  `for _, i in require(game.ReplicatedStorage.Modules.ContentCheck).run() do print(i.Level, i.Kind, i.Id, i.Message) end`
  Errors (the item is skipped): duplicate ids, bad item/weapon stats, price without currency, duplicate PassIds, unknown rarity, bad price/income, invalid or placeholder asset ids, emote with no/two animation sources.
  Warnings: model not found (procedural look used), animation without `AssetId`.
  The server prints the same summary at every start: `[Content] checked N hamsters: X error(s), Y warning(s)`.
* Offline, without Studio: `tools/SimTests/run.sh --all` (needs the `luau` binary) — includes the content validator tests (`scn_content`).
