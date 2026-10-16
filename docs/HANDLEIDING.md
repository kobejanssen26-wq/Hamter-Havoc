# Handleiding voor jou (zonder programmeren)

**Voor dagelijks beheer, publiceren en terugdraaien: lees `docs/MAINTENANCE.md` (stap voor stap, met publicatie-checklist).**
Dit is de korte, praktische versie. Technische details staan in `COMBAT_GUIDE.md`, `CONTENT_GUIDE.md` en `STUDIO_GUIDE.md`.
Alles hieronder werkt in Roblox Studio: open `HamsterPlaza.rbxl`, kijk in **View → Explorer**, dubbelklik een ModuleScript, verander het getal, druk op **Play**.

## 1. Eerst doen: jouw UserId invullen (admin-paneel)

1. Je UserId is het getal in je profiellink: `roblox.com/users/`**`123456789`**`/profile`.
2. Open `ServerScriptService/Config/AdminConfig`.
3. Vervang de `0` bij `OwnerUserIds` door jouw getal. Klaar: jij bent **Owner**.
   (Staat `CreatorIsOwner = true`, dan is de maker van het spel automatisch ook Owner; handig bij testen in Studio.)
4. Andere staf: zet onder `Users` regels als `[11111111] = "Moderator"`. Rollen: `Admin`, `Moderator`, `Developer`.
   Wat elke rol mag staat in `Roles`. Namen tellen nooit, alleen het nummer.

**Panel openen** (er is bewust géén knop op het scherm): druk op **F10** of typ **/admin** in de chat. Gewone spelers krijgen geen reactie en niets te zien.
De toets staat in `ReplicatedStorage/Modules/InputConfig` (`Admin`).

### Het paneel (F10 of /admin)

Links staan **alle spelers in de server** met hun foto, weergavenaam en @gebruikersnaam; typ in het zoekvak om te filteren. Klik een speler: onder de lijst zie je zijn kaart (foto, naam, UserId, rol). Het UserId gaat daarna vanzelf mee naar elke actie, je hoeft het nooit te onthouden. Voor iemand die **niet in de server** is: typ de gebruikersnaam bij *find a username (offline too)* en klik **Find username**; Roblox zoekt het UserId op. De lijst ververst zichzelf als iemand joint of weggaat.

Daarnaast staan de tabbladen (je ziet alleen wat jouw rol mag):

| Tab | Wat |
|---|---|
| Dashboard | je rol, spelers, staf online, serveruptime, of rollen opgeslagen worden |
| Players | speler bekijken (voortgang) |
| Roles | rollen maken, aanpassen, hernoemen, verwijderen en toewijzen (zie hieronder) |
| Moderation | waarschuwen, kicken, tijdelijk / permanent bannen, unbannen, geschiedenis |
| Economy | cash, diamanten, rebirths geven of afnemen |
| Hamsters | **visuele kiezer**: zoek op naam, filter op zeldzaamheid, klik een hamster, kies aantal, **Grant** |
| Weapons & gear | zoeklijst met alle wapens en items, klik en **Grant** |
| Game | aankondiging, serverinfo, veilige testtools |
| Settings | live instellingen (ook de Lucky Wheel: `Wheel.…`) en winkelprijzen |
| Logs | het staflogboek |

De hamster- en itemlijst komen uit **dezelfde catalogus als het spel** (`HamsterDatabase`, `ItemRegistry`): voeg je een hamster of wapen toe, dan staat hij hier vanzelf. Een hamster geven werkt voor spelers die in de server zijn (hun collectie moet geladen zijn). Gevaarlijke acties vragen om een tweede klik (**Confirm?**); alles wat staf doet komt in het logboek (naam, UserId, actie, doelwit, reden, tijd). Er is bewust geen "voer code uit"-vak.

### Rollen en rechten (tab Roles)

Klik **+ New role** of **Edit** bij een rol. Je ziet een vinkjeslijst per groep (General, Moderation, Economy, Staff) met alle rechten, plus de limieten (max cash, diamanten, rebirths, banminuten). **Save role** slaat op, **Give to selected player** geeft de rol aan de gekozen speler, **Remove** bij een lid haalt hem weg. Een ingebouwde rol (Admin, Moderator, Developer) kun je aanpassen; **Reset to file** zet hem terug naar `AdminConfig`. Een eigen rol (bv. *Trial Mod*, alleen Warn + Kick) kun je verwijderen.

Regels (de **server** dwingt ze af, niet het scherm):
* **Owner** en **CoOwner** bestaan alleen in `AdminConfig` en kunnen door niemand worden aangepast, verwijderd of weggehaald.
* Je kunt alleen rollen maken, aanpassen, geven en weghalen die **lager** zijn dan je eigen rol (de *Priority*, 0.5–3.9), en nooit je eigen rol.
* Je kunt een recht alleen geven als je het **zelf hebt**; limieten nooit boven je eigen limieten.
* Rollen met `ManageRoles` / `ManageAdmins` of priority 3+ geven of maken vraagt `ManageAdmins`. Standaard heeft alleen Owner/CoOwner dat; de Admin-rol heeft het niet.
* Niemand kan zichzelf promoveren; een speler uit `AdminConfig.Users` verander je alleen in dat bestand.
* Opgeslagen rollen worden bij elke serverstart gecontroleerd (namen, levels, onbekende rechten weg, nooit `*`). Gaat er iets mis: zet in `AdminConfig` **`IgnoreSavedRoles = true`**, dan telt alleen het bestand.
* Opslag: één DataStore-sleutel (`HamsterPlazaStaff_v1`), alleen geschreven als je iets verandert, andere servers lezen elke 90 seconden mee. Zonder *Studio Access to API Services* blijft een wijziging alleen tot de server sluit (het paneel meldt dat).

Rechten die er zijn: Panel, Inspect, ServerInfo, SafeTools, AuditLog, Announce, Settings, Warn, Kick, History, BanTemp, BanPerm, Unban, Cash, Diamonds, Rebirth, Items, Hamsters, ManageRoles, ManageAdmins (lijst + uitleg: `AdminConfig.PermissionCatalog`).
Kicken / bannen gebruiken onze eigen opslag (ban wordt bij joinen geweigerd), niet de Roblox-banfunctie.

Opmerking: *events aan/uitzetten* bestaat nog niet, want het spel heeft (nog) geen event-systeem om aan of uit te zetten.

## 2. Instellingen veranderen: één plek

Open `ReplicatedStorage/Modules/GameConfig`. Elke regel heeft een uitleg, een minimum en maximum (een typefout kan het spel niet breken) en zegt of hij `Live` (door admins te veranderen terwijl het spel draait) of alleen in Studio is.

| Ik wil … | Regel |
|---|---|
| de poort sneller opnieuw laten aanzetten | `Security.GateReopenCooldown` (nu **7** seconden; was 14). Betere poorten (rebirth 1, 3, 6) gaan er `GateRechargeBonusPerTier` seconden af, nooit onder `GateMinCooldown` |
| hoe lang de poort aan blijft | `Security.GateBaseDuration` en `GateSecondsPerRebirth` |
| bereik / cooldown / terugslag van de blote-poot-slag | `Combat.Paw…` |
| hoeveel terugslag / stun maximaal mag (alle wapens) | `Combat.MaxKnockback`, `MaxKnockbackLift`, `MaxStunSeconds` |
| startgeld en -diamanten | `Economy.StartingCash`, `StartingDiamonds` (alleen Studio) |
| freeze-duur maximaal / immuniteit na freeze | `Abilities.FreezeMaxSeconds`, `FreezeImmunitySeconds` |
| het oude "alleen vechten bij een hamster" terug | `Combat.PvpNeedsHamsterNearby = true` |

Een admin kan `Live`-regels ook in het paneel (tab **Settings**) veranderen. Dat wordt **opgeslagen** (één DataStore-sleutel, alleen geschreven als er iets verandert) en bij elke serverstart weer toegepast. **Reset** zet een waarde terug naar de standaard uit het bestand.

Per wapen / hamster / item: de eigen bestanden in `Modules/Content/…` (prijs, rebirth-eis, bereik, cooldown, terugslag, hamster-inkomen, zeldzaamheid).
Rebirth-eisen en -beloningen: `RebirthConfig`. Game passes: `GamepassConfig`.

## 3. Een wapen toevoegen (stap voor stap)

1. (Eigen model, optioneel) Bouw het in Studio als **Tool** met een deel genaamd `Handle`. Zet het in `ReplicatedStorage/Assets/Tools`.
   Zonder eigen model gebruikt het spel een ingebouwd model (`Look.Style`: `glove`, `spring`, `baton`, `hammer`, `shield`, `bat`, `wand`, `slingshot`, `cloak`, `mirror`).
   Alle bestaande wapens staan ook als kant-en-klare Tools in `ModelLibrary/Weapons/Weapon_Pack.rbxm` (invoegen via *Insert from File*, aanpassen, in `Assets/Tools` zetten).
2. Kopieer `Modules/Content/Items/_Template.luau` (of een bestaand wapen, bv. `SlapGlove.luau`), geef het een nieuwe naam en `Id`.
3. Vul in: `DisplayName`, `Description`, `Icon` (naam van een getekend icoon, bv. `glove`; eigen plaatje: `rbxassetid://<nummer>`), `Currency` (`Coins` of `Gems`), `Price`, `MinRebirth`.
4. Kies het type in `Equip.Weapon.Type`: `Melee`, `Ranged`, `Freeze`, `Cloak`, `Decoy` of `Guard` (schild). Dit zijn de enige types; het spel voert nooit tekst uit een bestand uit.
5. Getallen: `Range`, `Arc`, `Cooldown`, `Knockback`, `Lift`, `Stun`, `DropChance`, en eventueel `WindUp` / `Active` (zie `COMBAT_GUIDE.md`). Te hoge of onmogelijke getallen worden geweigerd met een melding.
6. Animatie (optioneel): `Animation = "Weapon_MijnWapen"` en maak `Content/Animations/Weapon_MijnWapen.luau` (kopieer een bestaande). Zolang `AssetId` leeg is gebruikt het spel de ingebouwde zwaai.
7. Druk op Play. Het wapen staat nu in de winkel (met slotje en eis als `MinRebirth` > 0), in de Backpack en op de hotbar zodra je het koopt.
8. Controle: `ContentCheck` meldt typefouten (zie `CONTENT_GUIDE.md` §8).

## 4. Een hamster toevoegen
Kopieer `Modules/Content/Hamsters/_Template.luau` (of een bestaande), geef een unieke `Id`, `DisplayName`, `Rarity`, `IncomePerSecond`, `Price`, eventueel `Icon`, `ModelName` en een unlock. Hij verschijnt vanzelf in collectie, Index, winkel en op de werkbank.

## 5. Animaties en emotes toevoegen
1. Maak de animatie in Studio (Animation Editor, **R15**-rig) en publiceer hem: Animation Editor → ⋯ → *Publish to Roblox*. De animatie moet **van jou (of je groep) zijn**, anders speelt hij niet in jouw spel.
2. Kopieer het ID (`rbxassetid://123…`) in een bestand in `Modules/Content/Animations/` (kopieer `_Template.luau`): `AssetId`, `Rig = "R15"`, `Priority` (wapen: `Action2`, emote: `Action`).
3. Emote: kopieer `Content/Emotes/_Template.luau`, kies `Animation = "<naam>"`, zet `Enabled` weg. Hij staat daarna in het emote-wiel.
4. Controle in Studio (client-commandobalk): `require(game.StarterPlayer.StarterPlayerScripts.Controllers.AnimationController).preflight()` laat zien welke animaties laden.
Ik heb **geen** echte animatie-ID's verzonnen: tot jij er een plakt gebruikt het spel de ingebouwde zwaai en de standaard Roblox-emotes. Voor markers: zie `COMBAT_GUIDE.md`.

## 6. De HUD aanpassen in Studio
Zie `STUDIO_GUIDE.md` → "HUD in Studio". Kort: `StarterGui/MainUI` en `StarterGui/HotbarUI` zijn echte ScreenGuis. Verplaats, kleur, verberg (**Visible = false**, niet verwijderen) en pas teksten aan zoals bij elke UI; het spel behoudt jouw wijzigingen en blijft de rest (schaal per scherm, mobiel) zelf regelen.
Na een codewijziging aan de HUD: `tools/SimTests/bake_hud.sh` ververst de sjablonen.

## 7. De Robux-winkel
Er zijn nu **twee winkelgebouwen** op het plein: de **Coins Shop** (links, cash en diamanten) en de **Robux Shop** (rechts, passes en diamantpakketten). Elke deur opent het juiste winkelscherm. Passes: `GamepassConfig` (zet `PassId`, `Enabled = false` verbergt een pass).
Diamantpakketten: `ShopConfig` (`ProductId`). `0` = niet ingesteld = niet te koop. Betalen gaat altijd via de officiële Roblox-aankoop; het spel geeft het voordeel pas als de server de aankoop bevestigt. Er is geen nep-Robux-saldo.

## 8. Veilige zones (geen gevechten)
Elk onzichtbaar deel met de tag `SafeZone` is een veilige zone: daarin kun je niet aanvallen en niet geraakt worden. De Leaderboard-hal heeft er één (die wordt bij elke Play opnieuw gebouwd door `LeaderboardBuilder`; maat aanpassen doe je daar).
Eigen zones: maak in Studio een onzichtbaar Part (Anchored aan, CanCollide uit, Transparency 1) in je **eigen map** (bv. `Workspace/MijnZones`, niet in een gegenereerde map) en geef het de tag `SafeZone` (**View → Tag Editor**). Die blijft staan bij Play.

## 9. Nieuwe dingen (eerdere ronde)

* **Rebirth via admin-paneel:** bouwt nu ook het huis omhoog (net als een echte rebirth). Test: admin → Rebirths +10 → je huis krijgt extra verdiepingen.
* **Emotes:** kloppen ze niet met jouw animaties, dan speelt het spel de standaard Roblox-emotes (`EmoteConfig.BuiltinFallback`). Of dat in jouw Studio werkt kon ik niet zien; zie `AnimationController.preflight()` (hoofdstuk 5).
* **Vallen (traps):** Banana Peel, Glue Trap, Spike Trap staan in de wapenwinkel (zie `COMBAT_GUIDE.md` §7b). Aanpassen: `Content/Items/BananaPeel.luau` enz.
* **Prijzenrad:** zie hoofdstuk 10.
* **Dagelijkse beloningen:** per dag een concrete lijst (bv. dag 1 = 500 Coins + Speed-item, dag 7 = zeldzame hamster + 150 Gems + Spike Trap) in `DailyRewardConfig.Days`.
* **Hamstervormen:** elke hamster heeft een lichaamstype (`standard`, `chonk`, `lanky`, `long`, `bean`, `tiny`, `giant`) dat hoogte, breedte en kop verandert. Kies er een in het hamsterbestand: `Look = { Shape = "lanky" }`; zonder keuze wordt er een vaste gekozen op basis van de id. Lijst/maten: `Modules/HamsterShapes`.

## 10. Lucky Wheel, auras, toetsen, emotes

* **Lucky Wheel:** een **echt rad achter de twee winkels** (loop tussen Coins Shop en Robux Shop door, op het gras erachter, en druk F) en een knop met een wiel-icoon rechts in de rail (bolletje = gratis draai klaar). Het fysieke rad draait naar dezelfde prijs die de server trok; er kan maar één speler tegelijk draaien. Het groene bord erboven zegt wanneer jouw gratis draai klaar is. Elke **1 uur** een gratis draai (`Wheel.FreeSpinSeconds`, live in het paneel te veranderen); extra draai voor `Wheel.ExtraSpinGems` diamanten. De server trekt de prijs; de tijd staat opgeslagen als servertijd, dus opnieuw joinen, van server wisselen of de pc-klok aanpassen helpt niet.
  Prijzen en kansen: `ReplicatedStorage/Modules/SpinWheelConfig` (uitleg bovenaan). **Cash schaalt mee met de voortgang**: de grootste van "x% van de kosten van je volgende rebirth" en "x minuten van je huidige inkomen", nooit boven `Wheel.CashCapPercent` van die rebirthkosten. Een beginner krijgt dus een paar duizend, een veteraan miljoenen. Diamanten groeien per rebirth, de mysteriehamster wordt zeldzamer naarmate je verder bent, sommige vakjes zijn pas vanaf rebirth 1 te winnen (grijs met "locked"). Een kapotte prijs (gewicht 0, negatief, onbekende hamster …) wordt overgeslagen en gemeld in de Output.
* **Auras:** `Modules/AuraConfig`. Standaard per zeldzaamheid (Rare = zachte gloed, Epic = sparkles, Legendary = sterren + ring, Mythic = vuur, Secret = glitch …). Per hamster in zijn bestand: `Look = { Aura = false }` (geen aura) of `Look = { Aura = { Style = "flame", Color = "FF8800", Rate = 6, Light = 1.2, Ring = "FFD866" } }`; alle velden zijn optioneel. `AuraConfig.Enabled`, `Intensity` en `MaxRate` regelen alles tegelijk (handig voor prestaties). Een aura is maximaal één emitter + één licht + één dunne ring, wordt uitgezet als je ver weg bent en verdwijnt met het model.
* **F-toets:** F is de toets van alle wereldmenu's (winkel, upgrades, lift, beveiliging, stelen). Roblox toont per toets één prompt (de dichtstbijzijnde); de stelen-prompt vraagt ingedrukt houden. Nieuw: `Controllers/PromptController` drukt een niet-reagerende tikprompt zelf in als de engine hem niet afhandelt. Debug: zet in Studio op je `Player` het attribuut `PromptDebug = true`, dan meldt de Output welke prompt reageerde of waarom geen.
* **Emotes:** B opent het wiel. Lukt een emote niet, dan staat in de Output een regel `[Emote] '…' could not start (rig, id …)` met de reden. Zie hoofdstuk 5.

## 11. Het project openen en beheren in Studio

1. **Gewoon openen:** download `HamsterPlaza.rbxl` uit de repository (GitHub → het bestand → *Download raw file*) en open het in Roblox Studio. Alles wat hieronder staat staat daarin, je kunt het meteen bewerken en publiceren. Haal het bestand opnieuw op na elke wijziging die ik maak.
2. **Met Rojo (aanbevolen als je vaak wijzigt):** het project gebruikt Rojo (`default.project.json`, de scripts staan in `src/`, de wereld in `world/`). Installeer Rojo (Studio-plugin + `rokit install`), draai `rojo serve` in de projectmap en klik in Studio **Connect**. Wijzigingen in de bestanden verschijnen direct in Studio. Zonder Rojo hoef je niets te installeren: gebruik stap 1.
3. **Waar staat wat:**
   * Instellingen: `ReplicatedStorage/Modules/GameConfig` (live-regels ook in het admin-paneel), prijzen/kansen van het rad `SpinWheelConfig`, auras `AuraConfig`, rebirths `RebirthConfig`, dagelijkse beloningen `DailyRewardConfig`, winkel `ShopConfig`, passes `GamepassConfig`.
   * Hamsters / wapens / emotes / animaties: `ReplicatedStorage/Modules/Content/Hamsters | Items | Emotes | Animations` (één bestand per ding, kopieer `_Template.luau`).
   * Rollen en rechten: in het spel (tab Roles); de basis (jouw UserId, Owner, CoOwner, standaardrollen) in `ServerScriptService/Config/AdminConfig`.
   * HUD: `StarterGui/MainUI` en `StarterGui/HotbarUI` (echte ScreenGuis, hoofdstuk 6). Het admin-paneel wordt bewust in code gebouwd (het is gereedschap voor jou, geen speler-HUD).
   * Eigen modellen: hamsters in `ReplicatedStorage/Assets/HamsterModels`, wapens in `Assets/Tools`.
4. **Wat kan direct in Studio, en wat moet eerst naar Roblox:** getallen, teksten, kleuren, UI-posities en modellen bewerk je direct. **Animaties, geluiden, plaatjes (icons), game passes en developer products** moeten eerst door jou op Roblox staan (upload / publiceer, het ID is dan van jouw account of groep); daarna plak je het ID in het bestand. Ik heb geen ID's verzonnen.
5. **Controleren:** na een wijziging meldt de Output (`[Content] …`, `[Wheel] …`) typefouten en kapotte regels; ongeldige waarden worden geweigerd of begrensd in plaats van het spel te breken.

## 12. Wat ik niet kon testen
Alles is getest in een simulatie van Roblox (`tools/SimTests/run.sh --all`), niet in echte Roblox Studio. Zie het eindrapport voor de lijst van wat jij nog moet bekijken (uiterlijk van wapens, HUD, bergen, animaties, echte Robux-aankopen, meerdere echte spelers).
