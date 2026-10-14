# Onderhoudsgids: het spel zelf beheren (zonder AI)

Dit is de gids voor alles wat je na deze laatste ronde zelf doet. Elke taak heeft een label:

| Label | Betekent |
|---|---|
| **[Studio]** | alleen een eigenschap aanpassen in Roblox Studio (kleur, positie, tekst) |
| **[Config]** | een getal / tekst veranderen in één ModuleScript (dubbelklik, typ, Play) |
| **[Asset]** | eerst iets maken of importeren (model, plaatje) en dan één regel in een config |
| **[Publiceren]** | het ding moet eerst op Roblox staan (animatie, plaatje, game pass, product): jij uploadt, het ID plak je in de config |
| **[Geheim]** | een geheime instelling die NIET in de repository mag |

Niet alles kan zonder een ModuleScript te openen. Dat is bewust: de getallen staan op één plek per onderwerp, met uitleg erboven.
`ReplicatedStorage/Modules/_ConfigIndex` is de inhoudsopgave: "ik wil X veranderen → open Y".

---

## 0. Het project openen

1. **Zonder iets te installeren:** download `HamsterPlaza.rbxl` uit GitHub (bestand openen → *Download raw file*) en open het in Roblox Studio. Dit bestand is gebouwd uit de repository en bevat alles.
2. **Met Rojo (live synchroniseren met de bestanden):** `rokit install`, dan in de projectmap `rojo serve`, en in Studio de Rojo-plugin → **Connect**. Dan werkt wat jij in de bestanden (`src/`) wijzigt direct in Studio, en je zet de wijziging met `git commit` en `git push` in GitHub. `default.project.json` beschrijft welke map waar hoort.
3. **Let op, twee soorten dingen:**
   * Scripts, configuraties en GUI-sjablonen komen uit de repository. Wijzig je ze alleen in Studio zonder Rojo, dan ben je ze kwijt als je het .rbxl opnieuw downloadt. **Gebruik dus Rojo, of kopieer je wijziging terug naar het bestand.**
   * De wereld wordt bij elke Play opnieuw gebouwd door `WorldBuilder` (huizen, plein, rad, poort). Alleen de map `Workspace/Environment` (bomen, bergen, gras) is "van Studio" (`StudioOwned = true`) en blijft zoals jij hem bewaart. **Heb je ooit een oud .rbxl gepubliceerd? Dan staan daar nog de oude bomen in. Verwijder in dat geval `Workspace/Environment` en laat hem opnieuw bouwen, of gebruik het nieuwe .rbxl.**

## 1. Kleuren, lettertypes, knoppen, iconen, layout van de HUD **[Studio]**

* De HUD staat in `StarterGui/MainUI` (bovenbalk, rail rechts, onderkant) en `StarterGui/HotbarUI`. Het zijn echte ScreenGuis: sleep, kleur, hernoem, maak verborgen (**Visible = false**, niet verwijderen). Het spel houdt jouw wijzigingen en regelt alleen de inhoud (getallen, schaal op mobiel).
* Vensters (winkel, backpack, rebirth, rad ...) worden door `UI/*.luau` gebouwd met gedeelde onderdelen (`UIKit`). Hun **kleuren en maten** pas je op één plek aan: `StarterPlayerScripts/UI/Theme.luau` (accenten per venster, rand dikte, lettergroottes).
* **Iconen** zijn getekend (geen plaatjes): `UI/Icons.luau`, lijst met `Icons.names()`. Een eigen plaatje gebruik je door in een config `Icon = "rbxassetid://<nummer>"` te zetten **[Publiceren]**.
* Na een wijziging aan de vaste HUD-onderdelen in code: `tools/SimTests/bake_hud.sh` ververst de sjablonen.
* Het admin-paneel wordt bewust in code gebouwd (gereedschap, geen speler-HUD).

## 2. Een hamster toevoegen (model, naam, zeldzaamheid, inkomen, aura) **[Asset] + [Config]**

1. Kopieer `ReplicatedStorage/Modules/Content/Hamsters/_Template.luau`, geef het een nieuwe bestandsnaam.
2. Vul in: `Id` (unieke kleine letters met `_`), `DisplayName`, `Description`, `Rarity`, `IncomePerSecond` (leeg = formule van de zeldzaamheid), `Price`, `Look = { ... }` (kleuren, oren, ogen, `Shape` = lichaamstype, `Acc` = accessoires), eventueel `Persona`, `Unlock`.
3. **Aura:** `Look = { Aura = { Style = "flame", Color = "FF8800", Rate = 6, Light = 1.2, Ring = "FFD866" } }`, of `Aura = false`. Zonder regel geldt de standaard van de zeldzaamheid (`Modules/AuraConfig`).
4. **Eigen 3D-model (optioneel):** zet het model in `ReplicatedStorage/Assets/HamsterModels` en schrijf `ModelName = "NaamVanHetModel"`. Zonder model bouwt het spel de hamster uit het `Look`. Een eigen plaatje: `Icon = "rbxassetid://..."` **[Publiceren]**.
5. Druk op Play. De hamster staat nu in de collectie, Index, winkel, op de werkbank, in het admin-paneel (tab Hamsters) en in het rad (mysteriehamster) zonder dat je iets anders aanpast. Fouten staan in de Output (`[Content] ...`).
* Namen: gebruik originele namen of grappen op een naam. Een echte naam, gezicht of logo alleen met toestemming (`Licensed = true` pas als je de rechten hebt). De bestaande parodieën hebben `Licensed = false` en een `Inspiration`-regel.

## 3. Een wapen toevoegen (met icoon) **[Config]** (+ **[Asset]** voor een eigen model)

Zie `docs/HANDLEIDING.md` hoofdstuk 3 en `docs/COMBAT_GUIDE.md`. Kort: kopieer `Content/Items/_Template.luau`, kies `Equip.Weapon.Type` (`Melee`, `Ranged`, `Freeze`, `Cloak`, `Decoy`, `Guard`, `Trap`), vul prijs, bereik, cooldown, terugslag in. `Icon` = naam van een getekend icoon. Het model in de winkel is **hetzelfde** model als het wapen in je hand (ToolBuilder bouwt beide). Eigen model: Tool met een `Handle` in `ReplicatedStorage/Assets/Tools`.

## 4. Een wapen-eigenschap / ability instellen **[Config]**

In hetzelfde bestand: `Range`, `Arc`, `Cooldown`, `Knockback`, `Lift`, `Stun`, `DropChance`, voor vallen `MaxActive`, `Duration`, `Slow`. Harde grenzen staan in `GameConfig.Combat`/`Abilities` en kunnen live in het admin-paneel (tab Settings) worden aangepast. Een **nieuw soort** ability heeft code nodig (`AbilitySystem`).

## 5. Een animatie of emote toevoegen **[Publiceren] + [Config]**

1. Maak de animatie in de Animation Editor (R15 rig) en publiceer hem (*Publish to Roblox*), op jouw account of groep.
2. Kopieer `Content/Animations/_Template.luau`: `Name`, `AssetId = "rbxassetid://..."`, `Rig = "R15"`.
3. Emote: kopieer `Content/Emotes/_Template.luau`, kies `Animation = "<naam>"`. Hij staat daarna in het emote-wiel (toets B).
4. Zonder `AssetId` gebruikt het spel de ingebouwde zwaai / de standaard Roblox-emotes. Lukt een emote niet, dan staat in de Output `[Emote] '...' could not start (rig, id ...)`.

## 6. Een winkel-item toevoegen **[Config]**

* Wapen of item met prijs: het item-bestand (stap 3) staat vanzelf in de Cash Shop.
* Boosts, capsules, diamantenpakketten: `Modules/ShopConfig.luau` (`Items`). Elke regel: `Id`, `Section`, `Name`, `Icon`, `Desc`, prijs (`Coins`/`Gems`/`Robux`).
* Een categorie verschijnt alleen als er iets in staat dat echt te koop is. Prijzen en beschikbaarheid kun je ook live aanpassen in het admin-paneel (Settings → Shop prices).

## 7. Een Game Pass instellen **[Publiceren] + [Config]**

1. Creator Dashboard → je experience → Monetization → Passes → maak de pass, kopieer het nummer.
2. `Modules/GamepassConfig.luau`: zet bij de juiste regel `PassId = <nummer>` (of voeg een regel toe: `Key`, `PassId`, `Name`, `Description`, `Icon`, `Order`, `Benefit`).
3. `PassId = 0` betekent **niet ingesteld**: de pass is nooit koopbaar. De Robux-prijs staat niet in het bestand: de server vraagt hem aan Roblox.
4. Test met een alt-account (of in Studio *Test → Local Server* met je eigen account): koop, kijk of het voordeel er is, rejoin.
* **Game Pass** = eenmalig, permanent voordeel (je bezit het of niet). **Developer product** = kan vaker gekocht worden (bv. diamanten). Een pass controleert de server via `UserOwnsGamePassAsync`; een product via `ProcessReceipt` (één keer toegekend per aankoop-id).

## 8. Een developer product instellen **[Publiceren] + [Config]**

Creator Dashboard → Monetization → Developer Products → maak het product, kopieer het nummer. In `ShopConfig.Items` bij de regel met `Kind = "Product"`: `ProductId = <nummer>` en `GemAmount = <aantal>`. `ProductId = 0` = verborgen. De server geeft de diamanten pas na `ProcessReceipt` en slaat eerst op.
**Sky Glider en Rocket Booster** bestaan als Robux-gamepasses (`GamepassConfig`: `Benefit = { Gear = "item_id" }` geeft het item zodra het bezit is geverifieerd). De items staan in `Content/Items/SkyGlider.luau` en `RocketBooster.luau` (Category "Gadget", geen Price/Currency: alleen via pass). De server beslist (MobilitySystem: cooldown, brandstof, bereik); de client past alleen de snelheid toe (MobilityController). Let op: dit is client-eigendom beweging, een aangepaste client kan het misbruiken, en het is nooit permanent vliegen. Zet bij de passes in `GamepassConfig` je echte PassId; tot dan zijn ze zichtbaar maar niet koopbaar. Dit is getest in de simulatie (`scn_gadgets`), niet in echte Studio.

**Bergen**: `MountainBuilder` bouwt gefacetteerde massieven uit driehoeken (`Build.triangle`, twee wedges per driehoek) met kleur per hoogte (bos, rots, sneeuw). Kliffen aan de rand zijn lage massieven (`EnvironmentBuilder.cliffWall`). Een al gepubliceerde place houdt zijn oude `Workspace/Environment` tot je die map verwijdert.

**Visuele controle zonder Studio**: `node tools/WorldPreview/render.js` rendert de gebakken wereld (`world/*.model.json`) en `python3 tools/WorldPreview/tool_sheet.py` maakt een overzicht van alle wapens/gadgets. Dit is een benadering, geen echte Roblox-weergave.

**Telefoons**: de UI schaalt tot 0.35, dus tekst is op kleine telefoons klein (bekende beperking).

## 9. Een Lucky Wheel-prijs toevoegen **[Config]**

`Modules/SpinWheelConfig.luau`, lijst `Prizes`. Kopieer een regel: `Id`, `Short` (woord op het fysieke rad), `Label`, `Icon`, `Color`, `Weight` (kans, relatief), `Reward`. Voorbeelden van `Reward`: `{ Gems = { Min = 25, Max = 40, PerRebirth = 0.15 } }`, `{ Coins = { Percent = {0.2, 0.4}, Minutes = {1, 2} } }`, `{ Items = { "banana_peel" } }`, `{ HamsterByRebirth = { [0] = "Cute", [3] = "Rare" } }`. `MinRebirth` = pas winbaar vanaf die rebirth. Het fysieke rad in het plein krijgt het extra vakje vanzelf; een kapotte regel wordt overgeslagen en gemeld in de Output (`[Wheel] ...`).

## 10. Rad-cooldown en schaling aanpassen **[Config]**

* Cooldown: `GameConfig` → `Wheel.FreeSpinSeconds` (7200 = 2 uur). Ook live in het admin-paneel (Settings). Prijs van een extra draai: `Wheel.ExtraSpinGems`.
* Schaling: cash = het grootste van "x% van je volgende rebirth-kosten" en "x minuten van je inkomen", nooit boven `Wheel.CashCapPercent` van die rebirth-kosten. Percentages en minuten zet je per prijs in `Reward.Coins`.

## 11. Poort-cooldowns en andere spelinstellingen **[Config]**

`Modules/GameConfig.luau`: elke regel heeft `Default`, `Min`, `Max`, `Live` en een uitleg. Bv. `Security.GateReopenCooldown`, `Security.GateBaseDuration`. `Live = true` kun je in het admin-paneel veranderen terwijl het spel draait (wordt bewaard). Rebirth: `RebirthConfig`. Inkomen/prijzen per zeldzaamheid: `RarityConfig`. Upgrades: `UpgradeConfig`. Quests: `QuestConfig`. Dagelijkse beloningen: `DailyRewardConfig`. Tutorial aan/uit: `GameConfig` → `Tutorial.Enabled`; tekst en volgorde: `TutorialConfig`.

## 12. Een admin-rol toevoegen of weghalen **[Config] of in het spel**

* **In het spel** (aanbevolen): F10 of `/admin` → tab **Roles**. Maak een rol met vinkjes, kies een speler (of zoek een gebruikersnaam), **Give to selected player**. Opgeslagen; alleen Owner/CoOwner mogen staf aanstellen.
* **Jouw eigen UserId / de Owner / CoOwner:** `ServerScriptService/Config/AdminConfig` (`OwnerUserIds`, `Users`). Alleen het nummer telt, nooit de naam.
* Gaat er iets mis met opgeslagen rollen: `AdminConfig.IgnoreSavedRoles = true`, dan telt alleen het bestand.

## 13. Discord-logging instellen **[Geheim]**

Volledige uitleg staat bovenaan `ServerScriptService/Config/DiscordConfig`. Kort:
1. Discord: kanaal → Integrations → Webhooks → New Webhook → kopieer de URL.
2. Studio: Game Settings → Security → **Allow HTTP Requests** aan.
3. Studio: `ServerStorage` → voeg een **StringValue** `DiscordWebhookUrl` toe, plak de URL in `Value`. (ServerStorage gaat nooit naar spelers en staat **niet** in de GitHub-repository.)
4. `DiscordConfig.Enabled = true`, publiceer, en druk in het admin-paneel (tab Logs) op **Send Discord test message**: het antwoord is het echte antwoord van Discord.
* Wat gelogd wordt kies je in `DiscordConfig.Events` (standaard: serverstart/-stop, staf-acties, rollen, moderatie, economie door staf, aankopen, jackpot van het rad, ernstige fouten; geen gewone joins).
* **Beperking:** Discord weigert soms verzoeken die rechtstreeks van Roblox-servers komen (HTTP 403). Dan heb je een doorgeefluik (relay) nodig dat jij beheert of vertrouwt; zet de relay-URL in dezelfde StringValue en de host in `AllowedHosts`. Ik kon dit niet vanuit hier testen.
* Commit nooit een opgeslagen .rbxl waarin de StringValue staat.

## 14. Veilig testen vóór je publiceert

1. `python3 tools/ReleaseCheck/release_check.py` (statische controle: iconen, dubbele ids, geheimen, config).
2. `tools/SimTests/run.sh --all` (simulatie van de spelregels; wijst geen uiterlijk of gevoel aan).
3. In Studio: **Test → Start** (1 speler) en **Test → Local Server** met 2-3 spelers: loop het plein, koop een hamster, draai het rad, open het admin-paneel, probeer F bij winkel en lift.
4. Controleer de Output op rode regels en `[Content]`/`[Wheel]`/`[Discord]`-meldingen.

## 15. Publiceren **[Studio]**

Studio → **File → Publish to Roblox** (of *Publish to Roblox As...*). Pas daarna zijn je wijzigingen live. Publiceer eerst naar een **testversie van de experience** (een tweede place of privé experience) als je grote dingen verandert. Games die draaien herstarten servers pas na een shutdown/update: *Game Settings → Publish → Update servers* of wacht tot ze sluiten.

## 16. Terugdraaien

* **Spel (Roblox):** Creator Dashboard → je experience → Places → het place → ⋯ → **Version History** → kies een oudere versie → **Revert**.
* **Bestanden (GitHub):** `git log`, dan `git revert <commit>` en `git push`. Je spelersdata staat in DataStores en verandert niet door code terug te draaien; de profielstructuur is alleen uitgebreid (nieuwe velden hebben standaardwaarden), dus terugdraaien verliest niets.

---

# Publicatie-checklist (afvinken)

- [ ] `python3 tools/ReleaseCheck/release_check.py` zonder ERROR
- [ ] `tools/SimTests/run.sh --all` zonder FAIL
- [ ] Game Settings → Security: **Enable Studio Access to API Services** aan (DataStores werken in Studio-tests en rollen/instellingen worden opgeslagen)
- [ ] Game Settings → Security: **Allow HTTP Requests** aan als je Discord-logging gebruikt
- [ ] Game Passes en Developer Products: ids ingevuld (`GamepassConfig`, `ShopConfig`), prijzen op Roblox gecontroleerd, een testaankoop gedaan
- [ ] `AdminConfig.OwnerUserIds` bevat jouw echte UserId; `CreatorIsOwner` bewust gekozen
- [ ] `DiscordConfig`: StringValue in ServerStorage (niet in de repository), test-bericht ontvangen
- [ ] Animaties/emotes/plaatjes die je gebruikt zijn van jouw account of groep en gepubliceerd (anders spelen ze niet)
- [ ] Je hebt het nieuwe `.rbxl` gebruikt of `Workspace/Environment` laten herbouwen (oude bomen!)
- [ ] Geloop door het plein: pad naar winkel, rad, leaderboard, rebirth-altaar, eigen basis; bomen, hekken en gebouwen zien er goed uit
- [ ] Lokale server met 2+ spelers: stelen, poort, wapens, rad (twee spelers tegelijk), admin-paneel
- [ ] Mobiel (Studio → Device emulator): HUD, winkel, tutorial, rad
- [ ] Spawn-locaties en startplace kloppen (Game Settings → Places)
- [ ] Output zonder rode fouten

# Wat niet automatisch te controleren is

Uiterlijk (bomen, bergen, huizen, wapens, UI), gevoel van gevechten, echte Robux-aankopen, meerdere echte spelers tegelijk, live DataStore- en HTTP-gedrag, het uitzicht van de bergen en de prestaties op een telefoon: dit moet jij in Studio of in een gepubliceerde testversie bekijken.
