# Content guide — add things yourself

Everything below is **local files in this repository** (edit in any editor, sync with Rojo, commit). Nothing needs a cloud
tool except where a Roblox asset id is unavoidable (uploading an animation or an icon) — those steps are marked **[upload]**.

Before testing, validate (see the last section). Typos are reported, never crash the game.

```
src/ReplicatedStorage/Modules/Content/
  Hamsters/    one .luau file per custom hamster       (_Template.luau = copy me)
  Emotes/      one .luau file per emote                (Wave, Point, Cheer, Laugh, Dance, Dance2 + _Template)
  Animations/  one .luau file per registered animation (_Template.luau)
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
* Gate time: `SecurityConfig.BaseDuration + PerRebirthSeconds * rebirths` (45 s, +10 s per rebirth). Theft rules: `TheftConfig`.
* Leaderboards: `LeaderboardConfig` (metrics, periods, cache/flush times).

## 8. Validate before testing
* In Studio (server command bar):
  `for _, i in require(game.ReplicatedStorage.Modules.ContentCheck).run() do print(i.Level, i.Kind, i.Id, i.Message) end`
  Errors (the item is skipped): duplicate ids, unknown rarity, bad price/income, invalid or placeholder asset ids, emote with no/two animation sources.
  Warnings: model not found (procedural look used), animation without `AssetId`.
  The server prints the same summary at every start: `[Content] checked N hamsters: X error(s), Y warning(s)`.
* Offline, without Studio: `tools/SimTests/run.sh --all` (needs the `luau` binary) — includes the content validator tests (`scn_content`).
