# Handleiding voor jou (zonder programmeren)

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

Wat je in het paneel kunt: spelers waarschuwen / kicken / bannen (tijdelijk of permanent, met reden) / unbannen, geschiedenis bekijken, geld / diamanten /
rebirths / wapens geven of afnemen, aankondigingen, serverinfo, **instellingen live veranderen** en **winkelprijzen** aanpassen of een item uitzetten.
Gevaarlijke acties vragen om een tweede klik (**Confirm?**). Alles wat staf doet komt in het logboek (naam, UserId, actie, doelwit, reden, tijd).
Er is bewust geen "voer code uit"-vak.

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
De winkel heeft twee delen: **Cash Shop** (cash en diamanten) en **Robux Shop** (passes en diamantpakketten). Passes: `GamepassConfig` (zet `PassId`, `Enabled = false` verbergt een pass).
Diamantpakketten: `ShopConfig` (`ProductId`). `0` = niet ingesteld = niet te koop. Betalen gaat altijd via de officiële Roblox-aankoop; het spel geeft het voordeel pas als de server de aankoop bevestigt. Er is geen nep-Robux-saldo.

## 8. Veilige zones (geen gevechten)
Elk onzichtbaar deel met de tag `SafeZone` is een veilige zone: daarin kun je niet aanvallen en niet geraakt worden. De Leaderboard-hal heeft er één (die wordt bij elke Play opnieuw gebouwd door `LeaderboardBuilder`; maat aanpassen doe je daar).
Eigen zones: maak in Studio een onzichtbaar Part (Anchored aan, CanCollide uit, Transparency 1) in je **eigen map** (bv. `Workspace/MijnZones`, niet in een gegenereerde map) en geef het de tag `SafeZone` (**View → Tag Editor**). Die blijft staan bij Play.

## 9. Nieuwe dingen (laatste ronde)

* **Rebirth via admin-paneel:** bouwt nu ook het huis omhoog (net als een echte rebirth). Test: admin → Rebirths +10 → je huis krijgt extra verdiepingen.
* **Emotes:** kloppen ze niet met jouw animaties, dan speelt het spel de standaard Roblox-emotes (`EmoteConfig.BuiltinFallback`). Of dat in jouw Studio werkt kon ik niet zien; zie `AnimationController.preflight()` (hoofdstuk 5).
* **Vallen (traps):** Banana Peel, Glue Trap, Spike Trap staan in de wapenwinkel (zie `COMBAT_GUIDE.md` §7b). Aanpassen: `Content/Items/BananaPeel.luau` enz.
* **Prijzenrad:** knop **Lucky Wheel** in het Quests-scherm. Gratis draai elke 4 uur, extra draai voor 40 diamanten. Prijzen en kansen: `ReplicatedStorage/Modules/SpinWheelConfig` (`FreeSpinEverySeconds`, `ExtraSpinGems`, lijst `Prizes` met `Weight`).
* **Dagelijkse beloningen:** per dag een concrete lijst (bv. dag 1 = 500 Coins + Speed-item, dag 7 = zeldzame hamster + 150 Gems + Spike Trap) in `DailyRewardConfig.Days`.
* **Hamstervormen:** elke hamster heeft een lichaamstype (`standard`, `chonk`, `lanky`, `long`, `bean`, `tiny`, `giant`) dat hoogte, breedte en kop verandert. Kies er een in het hamsterbestand: `Look = { Shape = "lanky" }`; zonder keuze wordt er een vaste gekozen op basis van de id. Lijst/maten: `Modules/HamsterShapes`.

## 10. Wat ik niet kon testen
Alles is getest in een simulatie van Roblox (`tools/SimTests/run.sh --all`), niet in echte Roblox Studio. Zie het eindrapport voor de lijst van wat jij nog moet bekijken (uiterlijk van wapens, HUD, bergen, animaties, echte Robux-aankopen, meerdere echte spelers).
