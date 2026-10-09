# Waar staat wat? (Explorer-kaart)

Open `HamsterPlaza.rbxl` in Roblox Studio → **View → Explorer**. Je ziet de wereld nu ook **zonder op Play te drukken**.

> Let op: dit is een **voorbeeldkopie** (`world/*.rbxm`). Bij Play bouwt het spel de wereld opnieuw op vanuit de code (`WorldBuilder`).
> Wil je iets blijvend veranderen, pas dan de bouwcode aan (zie "Welk bestand pas ik aan?"), niet de modellen in de Explorer.
> Daarna de voorbeeldkopie vernieuwen: `lune run tools/lune/bake_world.luau .`

## Workspace (de 3D-wereld)

| Explorer-pad | Wat is het |
|---|---|
| `Workspace/HamsterPlaza` | Het plein: grote bestrating met zon, boog met gouden hamster (`PlazaArch`, `PlazaStatue`), `ShopStall` (noord), `HamsterLibrary` (Index, zuid), bord met recente vondsten, plantenbakken, bankjes, bloemperken |
| `Workspace/HamsterPath` | De weg (`Road`, `Curb`, `LaneDash`), het hol waar hamsters beginnen (`BurrowHill`) en de uitgangstunnel |
| `Workspace/PlayerHouses/House1 … House8` | De 8 appartementen. 1-4 = noordrij, 5-8 = zuidrij |
| `Workspace/Environment` | Grond (`Ground`, `GrassPatches`), looppaden (`Promenades`, `GatePath`), straatlantaarns en grote bomen (`Props`), bos (`Forest`), achtergrondlandschap (`Backdrop`: `Hills`, `Lake`, `Mountains`, `Clouds`, `Birds`), onzichtbare muren (`Boundary`) |
| `Workspace/SpawnLocations` | Spawnpunt op het plein voor spelers zonder huis |
| `Workspace/HamsterShowcase` | **Alle 172 hamsters**, per zeldzaamheid in een rij (`01_Basic` … `14_Unknown`), op een zwevend platform **110 studs boven het plein**. Dubbelklik een model en druk op **F** om erheen te vliegen. Wordt bij Play verwijderd |

### Binnen één appartement (`PlayerHouses/House1`)

| Onderdeel | Wat |
|---|---|
| `Yard` | Kavel: gazon, oprit, hagen, bomen, terras, brievenbus (`Mailbox`, dagelijkse beloning), wedergeboorte-altaar (`Altar…`), en de **ingang met beveiliging**: poort (`GatePost`, `GateCanopy` met naam en sterren, lasers, `SecurityField`) en de beveiligingszuil (`PylonColumn`, hier druk je `E`) |
| `Floors/Floor1 … Floor5` | De verdiepingen, elk met een eigen doel en inrichting: 1 Workshop (aankomstpad, upgrade-zuilen `StationBase`, kist), 2 Hamster Lofts (lounge), 3 Research Lab (lab + geavanceerde upgrades), 4 Golden Suites (`Chandelier`), 5 Penthouse (`Pool`, dakterras). In de voorbeeldkopie staat alleen Floor1: verdiepingen komen erbij met Rebirths |
| `Wheels/Wheel1 … Wheel30` | De hamsterwielen (6 per verdieping). In de voorbeeldkopie leeg; bij Play verschijnt een wiel (`Wheel`) per ontgrendelde plek |
| `Roof` | Dak bovenop de hoogste verdieping (zonnepanelen, bord) |
| `Lift` | Glazen lift naast het gebouw (druk `E` bij het paneel om een verdieping hoger te gaan) |
| `Scaffold` | Steigers voor de volgende verdieping met bord "unlocks at Rebirth N" |
| `Prestige` | Gouden banden (R10), kroon (R15), lichtstrips (R20) |
| `Display` | De rennende hamsters op de wielen (alleen tijdens het spel) |

## Tijdens het spel (alleen zichtbaar in Play, niet in de editor)

- `Workspace/ClientHamsters` (alleen op de client): de rollende hamsterballen. Per bal: `Shell` (de glazen bal) en de hamster erin.
  Het naamlabel hangt aan een apart onzichtbaar blokje `TagAnchor_<id>` dat alleen meeschuift en nooit draait, daarom blijft het rechtop.
- Hamsterballen bestaan op de server alleen als gegevens (`HamsterSystem`), dus ze staan niet in de server-Explorer.
  Wil je ze zien: start Play → klik in de Explorer op **Client** (knop bovenin "Server/Client") → `Workspace/ClientHamsters`.

## Scripts

| Explorer-pad | Wat |
|---|---|
| `ReplicatedStorage/Modules` | Gedeelde instellingen: `RarityConfig` (prijs/terugverdientijd/kans per zeldzaamheid), `HamsterDatabase` (alle hamsters), `RebirthConfig` (eisen en beloningen), `FloorConfig` (verdiepingen), `UpgradeConfig`, `EconomyMath`, `HamsterStates` (stelen/dragen), `SecurityConfig`, `WorldLayout` (waar alles staat), `PathConfig` (weg), `IconShapes` (alle UI-iconen), `HamsterBuilder` (bouwt een hamstermodel uit blokjes) … |
| `ReplicatedStorage/Remotes` | Netwerkverbindingen |
| `ServerScriptService/Main` | Startpunt van de server |
| `ServerScriptService/Systems` | `HamsterSystem` (ballen + stelen), `SecuritySystem`, `CombatSystem`, `HouseSystem` (verdiepingen, wielen, lift), `RebirthSystem`, `UpgradeSystem`, `EconomySystem`, `CollectionSystem` … |
| `ServerScriptService/Systems/WorldBuilder` | Bouwt de wereld: `HouseBuilder` (appartement, verdiepingen, wielen, poort), `PlazaBuilder`, `PathBuilder`, `EnvironmentBuilder` (bos, bergen, meer, wolken), `Decor` (bomen, bankjes, lantaarns …) |
| `StarterPlayer/StarterPlayerScripts` | Alles aan de kant van de speler: `Controllers` (rollende ballen, wielen draaien, invoer, effecten) en `UI` (`MainUI`, `RebirthUI`, `IndexUI`, `UpgradeUI`, … en `UIKit` + `Icons` voor het ontwerp) |

## Welk bestand pas ik aan?

| Ik wil … | Bestand |
|---|---|
| een hamster toevoegen/veranderen | `ReplicatedStorage/Modules/HamsterDatabase` |
| prijs, inkomen of kans per zeldzaamheid | `ReplicatedStorage/Modules/RarityConfig` (zie `ECONOMY.md`) |
| rebirth-eisen of -beloningen | `ReplicatedStorage/Modules/RebirthConfig` |
| wanneer een verdieping vrijkomt / wat die geeft | `ReplicatedStorage/Modules/FloorConfig` |
| claim-tijd, stelen, drop-kans, verzekering | `ReplicatedStorage/Modules/HamsterStates` (`Config`) |
| beveiligingstijd per rebirth | `ReplicatedStorage/Modules/SecurityConfig` |
| het appartement aanpassen | `ServerScriptService/Systems/WorldBuilder/HouseBuilder` |
| het plein aanpassen | `…/WorldBuilder/PlazaBuilder` |
| het landschap (bos, bergen, meer) | `…/WorldBuilder/EnvironmentBuilder` en `Decor` |
| aantal/ligging van huizen | `ReplicatedStorage/Modules/WorldLayout` (`HouseColumns`) |
| een icoon veranderen of toevoegen | `ReplicatedStorage/Modules/IconShapes` |
| kleuren en knoppen van de menu's | `StarterPlayer/StarterPlayerScripts/UI/UIKit` |
| promocodes | `ServerScriptService/Config/CodesConfig` |

## Alle modellen als losse bestanden

In de map [`Models/`](Models/README.md) staat elk model één keer als `.rbxm` (sleep in Studio), `.glb` (Blender e.d.) en
`metadata.json`: alle hamsters per zeldzaamheid (met prijs, inkomen, kans, snelheid), de appartement-modules
(`Floor01` … `Floor05`, `Roof`, `Lift`, `EntranceGate`, …), de drie wielen, bomen, planten, meubels, decoratie,
landschap en alle iconen als PNG. Overzicht met plaatjes: [`Models/ASSET_INDEX.md`](Models/ASSET_INDEX.md).
Vernieuwen na een wijziging in de code: `tools/build_models.sh`.
