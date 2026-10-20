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
   * **De wereld is van Studio.** Deze mappen in `Workspace` blijven bij Play precies zoals jij ze opslaat (attribuut `StudioOwned = true`): `Environment` (bomen, bergen, gras), `HamsterPlaza` (beide shops, het rad, de boog, de fontein), `LeaderboardHall`, `HamsterPath` en `SpawnLocations`. Je past iets aan in Studio, drukt Play en ziet het meteen; er is geen aparte edit-modus. Alleen dit wordt bij elke start opnieuw gemaakt, omdat het levend is: `PlayerHouses` (de appartementen per speler) en het gouden standbeeld op de boog. Wil je een map terug naar de code: verwijder hem, of zet `StudioOwned` op false, en druk Play. **Heb je een oud .rbxl gepubliceerd? Dan staan daar nog de oude bomen, bergen en shop in. Verwijder die mappen (of gebruik het nieuwe .rbxl) om de nieuwe versie te krijgen; een map die je bewaart wordt nooit ongemerkt overschreven.**
   * Bij elke start voegt `WorldBuilder/Restore` alleen toe wat ontbreekt (tags, deeltjes), en haalt `LeaderboardHall` de bordteksten op met hun naam (`Title`, `Period`, `Row1…Row10`, `Footer`). Verwijder je zo'n tekst, dan wordt de hal opnieuw gebouwd (met een waarschuwing in de Output) zodat de ranglijsten niet breken.

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

## 10. Rad: cooldown, richting, plaatjes en schaling **[Config]**

Het rad is een **echt object** achter de twee winkels (loop erheen en druk F). Er is **één gratis draai per periode** en niets om voor te betalen. Het kleine paneel (rail-icoon met het wiel) toont alleen wat je kunt winnen, de kansen en de timer.

* **Cooldown:** `GameConfig` → `Wheel.FreeSpinSeconds` (standaard 10800 = 3 uur; 7200 = 2 uur). Ook live te veranderen in het admin-paneel (Settings). De server bewaart per speler wanneer de volgende draai klaar is (`profile.Wheel.NextFreeAt`).
* **Draairichting:** `GameConfig` → `Wheel.Clockwise` (`false` = tegen de klok in, gezien vanaf de voorkant waar de prijzen staan; `true` = met de klok mee). Staat het rad bij jou toch de verkeerde kant op, zet dit dan om: dat is alles. Duur van een draai: `Wheel.SpinSeconds`. Hoe de draai versnelt en vertraagt staat in `SpinWheelConfig.ease`; het aantal rondes in `SpinWheelConfig.Turns`.
* **Plaatjes in de vakken:** per prijs in `SpinWheelConfig.Prizes`. `Icon` = een getekend icoon (`UI/Icons`, werkt zonder upload); wil je een eigen plaatje, upload het naar Roblox en zet `Image = "rbxassetid://<jouw id>"` bij die prijs (er wordt geen id verzonnen: zonder `Image` zie je het getekende icoon). Plaatjes worden nooit uitgerekt (`ScaleType = Fit`).
* **Een eigen kopie van het rad** voor een ander place: `ModelLibrary/Wheels/Lucky_Wheel.rbxm` (Insert from File). Draait zelfstandig met 1 gratis draai per uur (attribuut `CooldownSeconds`) en meldt de winnaar op `Won`; daar hang je je eigen beloningen aan.
* **Schaling:** cash = het grootste van "x% van je volgende rebirth-kosten" en "x minuten van je inkomen", nooit boven `Wheel.CashCapPercent` van die rebirth-kosten. Percentages en minuten zet je per prijs in `Reward.Coins`.
* **Studio:** het rad is van jou (map `HamsterPlaza/LuckyWheel`): verplaatsen of draaien in Studio mag; de server onthoudt de rustpositie bij de start (`BaseCFrame`).

## 10b. Playtime-beloningen **[Config]**

`Modules/PlaytimeConfig.luau`: acht mijlpalen (10 min, 30 min, 1, 2, 3, 4, 6 en 8 uur). Per mijlpaal `Minutes`, `Icon` en `Reward` (`Coins`, `Gems`, `Boost`, `Items`, `HamsterRarity`; alleen bestaande valuta en items). De regels (uitleg bovenaan het bestand):

* Alleen tijd **in dit spel** telt; de **server** telt (elke 5 seconden), de speler kan het niet aanpassen.
* De tijd wordt bewaard: 8 uur mag over meerdere bezoeken verdeeld zijn.
* **Elke mijlpaal kan één keer per speler** worden geclaimd (permanente reeks, niet dagelijks, niet per seizoen). Rebirth zet het niet terug.
* Claimen gebeurt op de server: de mijlpaal wordt gemarkeerd voordat er betaald wordt en teruggedraaid als het betalen mislukt; claim en beloning staan in hetzelfde opgeslagen profiel.
* Het venster (zandloper in de rail) opent nooit vanzelf; een bolletje op het icoon laat zien dat er iets klaarstaat. Teksten staan bovenaan `UI/PlaytimeUI`.

## 10c. Like & Favorite-bord **[Config]**

Er staan twee borden bij de gast-spawn (`HamsterPlaza/FavoritesBoard` en `FavoritesBoard2`); elk bord is aan **beide** kanten afgewerkt (voor- en achterkant tonen dezelfde rijen) en heeft aan elke kant een F-knop die het **Community-venster** opent (`UI/SocialUI`, ook bereikbaar via Instellingen > Community). Het venster heeft vier aparte acties: **Vrienden uitnodigen** (Roblox' eigen uitnodigingsvenster via `SocialService:PromptGameInvite`, alleen als `CanSendGameInviteAsync` het toestaat), **Like**, **Favoriet** en **Groep**. Roblox geeft een spel **geen** manier om "Like" of "Favoriet" voor een speler in te drukken (en "een server favoriet maken" bestaat niet), dus die twee rijen leggen alleen uit waar de knop op de spelpagina staat en claimen of belonen niets. De groeprij toont echt of de speler al lid is (`Player:IsInGroup`); lid worden kan alleen op de groepspagina. **Alle ID's en teksten staan op één plek: `Modules/SocialConfig`** (`GroupId` en `GroupName` invullen; zolang `GroupId = 0` is verdwijnt de groeprij). De bordtitel en voettekst staan in `Modules/FavoritesConfig`.

## 11. Poort-cooldowns en andere spelinstellingen **[Config]**

`Modules/GameConfig.luau`: elke regel heeft `Default`, `Min`, `Max`, `Live` en een uitleg. Bv. `Security.GateReopenCooldown`, `Security.GateBaseDuration`. `Live = true` kun je in het admin-paneel veranderen terwijl het spel draait (wordt bewaard). Rebirth: `RebirthConfig`. Inkomen/prijzen per zeldzaamheid: `RarityConfig`. Upgrades: `UpgradeConfig`. Quests: `QuestConfig`. Dagelijkse beloningen: `DailyRewardConfig`. Tutorial aan/uit: `GameConfig` → `Tutorial.Enabled`; tekst en volgorde: `TutorialConfig`.

## 12. Een admin-rol toevoegen of weghalen **[Config] of in het spel**

* **In het spel** (aanbevolen): F10 of `/admin` → tab **Roles**. Maak een rol met vinkjes, kies een speler (of zoek een gebruikersnaam), **Give to selected player**. Opgeslagen; alleen Owner/CoOwner mogen staf aanstellen.
* **Jouw eigen UserId / de Owner / CoOwner:** `ServerScriptService/Config/AdminConfig` (`OwnerUserIds`, `Users`). Alleen het nummer telt, nooit de naam.
* Gaat er iets mis met opgeslagen rollen: `AdminConfig.IgnoreSavedRoles = true`, dan telt alleen het bestand.

## 12b. Admin: bases bekijken en repareren **[in het spel]**

Open het adminpaneel (F10 of `/admin`), kies links een speler en ga naar het tabblad **Bases**. Je ziet: poortstatus (lasers), hoeveel hamsters op de werkbank staan (geplaatst) en alles wat de speler bezit. Knoppen: **Lasers ON / OFF / Reset timers**, **Take off bench** (hamster blijft eigendom) en **Delete 1** (hamster verdwijnt echt, ook van de werkbank). Alles vraagt eerst "Confirm?", een **reden is verplicht** en elke actie komt in het staff-log (en in Discord als dat aan staat). Rechten (`ServerScriptService/Config/AdminConfig`): `BaseView` (kijken: ook Moderator), `BaseControl` (lasers + bench: Admin, Developer), `HamsterRemove` (verwijderen: alleen Admin en hoger). Je kunt nooit iemand met een gelijke of hogere rol aanpakken.

## 12c. Animaties en acties **[Config]**

Alle acties van het personage (hamster oppakken/plaatsen/terugnemen, kopen, prijs openen, beloning claimen, item equippen, rebirth vieren, slaan) staan in `Modules/ActionCatalog`; het overzicht met stabiele ID's staat in `docs/ANIMATIONS.md` (wordt gegenereerd: `python3 tools/ReleaseCheck/gen_animation_docs.py`). De **server** meldt een actie pas nadat het echt gelukt is; elke speler ziet hem. Zonder eigen animatie gebruikt het spel een ingebouwde beweging (R15). Eigen animatie: publiceer in Studio, maak een bestand in `Modules/Content/Animations/` met het `AssetId` en zet de naam in het veld `Animation` van de actie.

## 12d. Eigen plaatjes voor iconen **[Config]**

`Modules/IconOverrides`: zet `coin = "rbxassetid://<nummer>"` en overal waar het muntje staat verschijnt jouw plaatje. Het bestand is standaard leeg; een verkeerd geschreven regel wordt genegeerd en door `release_check.py` gemeld.

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
