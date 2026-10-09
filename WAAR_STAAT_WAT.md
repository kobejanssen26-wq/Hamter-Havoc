# Waar staat wat? (Explorer-kaart)

Open `HamsterPlaza.rbxl` in Roblox Studio → **View → Explorer**. Je ziet de wereld nu ook **zonder op Play te drukken**.

> Let op: dit is een **voorbeeldkopie**. Bij Play bouwt het spel de wereld opnieuw op vanuit de code (`WorldBuilder`).
> Wil je iets blijvend veranderen, pas dan de bouwcode aan (zie "Welk bestand pas ik aan?"), niet de modellen in de Explorer.

## Workspace (de 3D-wereld)

| Explorer-pad | Wat is het |
|---|---|
| `Workspace/HamsterPlaza` | Het plein: boog met gouden hamster (`PlazaArch`), `ShopStall`, `HamsterLibrary` (Index), bord met recente vondsten |
| `Workspace/HamsterPath` | De weg met pijlen (`Road`, `Arrow`), het hol waar hamsters beginnen (`BurrowHill`, `BurrowHole`) en de uitgangstunnel (`ExitHill`) |
| `Workspace/PlayerHouses/House1 … House8` | De 8 appartementen-torens. 1-4 = noordrij, 5-8 = zuidrij. In de voorbeeldkopie hebben ze 1,2,3,4,5,3,2,1 verdiepingen zodat je ziet hoe het gebouw groeit (bij Play start iedereen met 1 verdieping) |
| `Workspace/Environment` | Grond (`Ground`), looppaden (`Promenades`), paden naar de poort (`GatePath`), lantaarns/banken (`Props`), bos (`Forest`), `Beyond` (buitenwereld), **`Backdrop`** (bergen `Mountain`, heuvels `Hill`, meren `Lake`, kliffen `Cliff`, wolken `Clouds`), onzichtbare muren (`Boundary`) |
| `Workspace/SpawnLocations` | Spawnpunt op het plein voor spelers zonder huis |
| `Workspace/HamsterShowcase` | **Alle 172 hamsters**, per zeldzaamheid in een rij (`01_Basic` … `14_???`). Ligt ver ten zuiden van de map (z = -250 en verder). Dubbelklik een model en druk op **F** om erheen te vliegen. Wordt bij Play verwijderd |

### Binnen één appartement (`PlayerHouses/House1`)

| Onderdeel | Wat |
|---|---|
| `Yard` | Voortuin en beveiliging: haag, oprit, **poortportaal** (`GatePylon`, `LaserBeam`, `SecurityField`), beveiligingspaneel (`SecurityPanel`, hier druk je `E`), brievenbus, naambord, wedergeboorte-altaar (`AltarPillar`), bomen, vijver |
| `Tower/Floor1_HamsterHall … Floor5_Penthouse` | Per verdieping een model: `Shell` (vloer, glazen gevel, muren), `Interior` (inrichting, wielplekken `SlotRing`, plafondlampen, **lift** `ElevatorFrame`/`CallUp`/`CallDown`), `Balcony` (vanaf verdieping 2) en op verdieping 1 het `Entrance` (luifel met 10 wedergeboorte-sterren) |
| `Tower/Floor1…/Interior` | Op verdieping 1: **aankomstpad** (`PadOuter`/`PadInner`/`PadGlow`), 8 upgrade-pedestals (`StationBase`…), kist (`ChestBody`), voortgangsbord (`ProgressBoard`), **Upgrade Terminal** (`UpgradeTerminal`) en **Collection Archive** (`CollectionArchive`, opent de Hamster Index) |
| `Tower/Roof` | Het dak: begin = gezellig schuin dak met schoorsteen; vanaf 2 verdiepingen plat dak met zonnepanelen, watertank, embleem; vanaf 4 dakterras; verdieping 5 heeft een lichtstraal |
| `Wheels/Wheel1 … Wheel40` | De hamsterwielen (8 per verdieping). Leeg in de voorbeeldkopie; bij Play verschijnt een wiel (`Wheel`, getagd `HamsterWheel`) per ontgrendelde plek |
| `Display` | De rennende hamsters op de wielen (alleen tijdens het spel) |

## Tijdens het spel (alleen zichtbaar in Play, niet in de editor)

- `Workspace/ClientHamsters` (alleen op de client): de rollende hamsterballen. Per bal: `Shell` (de glazen bal met kralen) en `Run_h12` (de hamster erin).
- Hamsterballen bestaan op de server alleen als gegevens (`HamsterSystem`), dus ze staan niet in de server-Explorer.
  Wil je ze zien: start Play → klik in de Explorer op **Client** (knop bovenin "Server/Client") → `Workspace/ClientHamsters`.

## Scripts

| Explorer-pad | Wat |
|---|---|
| `ReplicatedStorage/Modules` | Gedeelde instellingen: `RarityConfig`, `HamsterDatabase` (alle hamsters), `HamsterStates` (alle getallen van stelen/dragen/beveiliging), `SecurityConfig`, `WorldLayout` (waar alles staat), `PathConfig` (weg), `EconomyMath`, `HamsterBuilder` (bouwt een hamstermodel uit blokjes) … |
| `ReplicatedStorage/Remotes` | Netwerkverbindingen |
| `ServerScriptService/Main` | Startpunt van de server |
| `ServerScriptService/Systems` | `HamsterSystem` (ballen + stelen), `SecuritySystem`, `CombatSystem`, `HouseSystem`, `EconomySystem`, `CollectionSystem` … |
| `ServerScriptService/Systems/WorldBuilder` | Bouwt de wereld: `HouseBuilder/` (`init` = API, `Tower` = verdiepingen/lift/dak/inrichting, `Yard` = voortuin + poort, `Wheels`, `Props`), `PlazaBuilder`, `PathBuilder`, `EnvironmentBuilder` (grond + bergen/meren/wolken), `Decor` (bomen/bankjes) |
| `StarterPlayer/StarterPlayerScripts` | Alles aan de kant van de speler: `Controllers` (rollende ballen, invoer, effecten) en `UI` (menu's) |

## Welk bestand pas ik aan?

| Ik wil … | Bestand |
|---|---|
| een hamster toevoegen/veranderen | `ReplicatedStorage/Modules/HamsterDatabase` |
| claim-tijd, stelen, drop-kans, verzekering | `ReplicatedStorage/Modules/HamsterStates` (`Config`) |
| beveiligingstijd per rebirth | `ReplicatedStorage/Modules/SecurityConfig` |
| het appartement aanpassen | `…/WorldBuilder/HouseBuilder/Tower.luau` (verdiepingen) en `Yard.luau` (voortuin/poort) |
| verdiepingen en wat ze geven | `ReplicatedStorage/Modules/FloorConfig` |
| wedergeboorte: eisen, beloningen, wat reset | `ReplicatedStorage/Modules/RebirthConfig` |
| prijs/inkomen per zeldzaamheid, spawnkans | `ReplicatedStorage/Modules/RarityConfig` (`BasePrices`, `PaybackGrowth`, `Weight`) |
| de kleuren/lettertypen van de hele UI veranderen | `StarterPlayer/StarterPlayerScripts/UI/Theme.luau` |
| winkel-items, categorieën, prijzen (Cash/Diamonds) | `ReplicatedStorage/Modules/ShopConfig` |
| de hotbar (slots, items) | `ReplicatedStorage/Modules/HotbarConfig` |
| de tutorial-stappen | `ReplicatedStorage/Modules/TutorialConfig` |
| de zichtbare namen van hamsters (ids blijven gelijk) | `ReplicatedStorage/Modules/HamsterNames` |
| een icoon toevoegen | `StarterPlayer/StarterPlayerScripts/UI/Icons.luau` |
| het plein aanpassen | `…/WorldBuilder/PlazaBuilder` |
| aantal/ligging van huizen | `ReplicatedStorage/Modules/WorldLayout` (`HouseColumns`) |
| promocodes | `ServerScriptService/Config/CodesConfig` |
