# Waar staat wat? (Explorer-kaart)

Open `HamsterPlaza.rbxl` in Roblox Studio → **View → Explorer**. Je ziet de wereld nu ook **zonder op Play te drukken**.

> Let op: dit is een **voorbeeldkopie**. Bij Play bouwt het spel de wereld opnieuw op vanuit de code (`WorldBuilder`).
> Wil je iets blijvend veranderen, pas dan de bouwcode aan (zie "Welk bestand pas ik aan?"), niet de modellen in de Explorer.

## Workspace (de 3D-wereld)

| Explorer-pad | Wat is het |
|---|---|
| `Workspace/HamsterPlaza` | Het plein: boog met gouden hamster (`PlazaArch`), `ShopStall`, `HamsterLibrary` (Index), bord met recente vondsten |
| `Workspace/HamsterPath` | De weg met pijlen (`Road`, `Arrow`), het hol waar hamsters beginnen (`BurrowHill`, `BurrowHole`) en de uitgangstunnel (`ExitHill`) |
| `Workspace/PlayerHouses/House1 … House8` | De 8 huizen. 1-4 = noordrij, 5-8 = zuidrij |
| `Workspace/Environment` | Grond (`Ground`), looppaden (`Promenades`), paden naar de poort (`GatePath`), lantaarns/banken (`Props`), bos (`Forest`), onzichtbare muren (`Boundary`) |
| `Workspace/SpawnLocations` | Spawnpunt op het plein voor spelers zonder huis |
| `Workspace/HamsterShowcase` | **Alle 172 hamsters**, per zeldzaamheid in een rij (`01_Basic` … `14_???`). Ligt ten zuiden van de map (z = -150 en verder). Dubbelklik een model en druk op **F** om erheen te vliegen. Wordt bij Play verwijderd |

### Binnen één huis (`PlayerHouses/House1`)

| Onderdeel | Wat |
|---|---|
| `Yard` | Voortuin: hek, poort (`GatePost`, `LaserBeam`, `SecurityField`), beveiligingspaal (`PylonColumn`, hier druk je `E`), brievenbus, naambord, wedergeboorte-altaar, bomen |
| `Structure` | Het gebouw zelf: muren, dak, ramen, deur, schoorsteen, sterren-banner |
| `Interior` | Binnenkant: **aankomstpad** (`PadOuter`/`PadInner`/`PadGlow`), 8 upgrade-pedestals (`StationBase`…), kist (`ChestBody`), 12 wiel-markeringen (`SlotRing`) |
| `Wheels/Wheel1 … Wheel12` | De hamsterwielen. In de voorbeeldkopie leeg; bij Play verschijnt een wiel (`Wheel`) per ontgrendelde plek |
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
| `ServerScriptService/Systems/WorldBuilder` | Bouwt de wereld: `HouseBuilder` (huis), `PlazaBuilder`, `PathBuilder`, `EnvironmentBuilder`, `Decor` (bomen/bankjes) |
| `StarterPlayer/StarterPlayerScripts` | Alles aan de kant van de speler: `Controllers` (rollende ballen, invoer, effecten) en `UI` (menu's) |

## Welk bestand pas ik aan?

| Ik wil … | Bestand |
|---|---|
| een hamster toevoegen/veranderen | `ReplicatedStorage/Modules/HamsterDatabase` |
| snelheid, kans of prijs per zeldzaamheid | `ReplicatedStorage/Modules/RarityConfig` |
| claim-tijd, stelen, drop-kans, verzekering | `ReplicatedStorage/Modules/HamsterStates` (`Config`) |
| beveiligingstijd per rebirth | `ReplicatedStorage/Modules/SecurityConfig` |
| het huis aanpassen | `ServerScriptService/Systems/WorldBuilder/HouseBuilder` |
| het plein aanpassen | `…/WorldBuilder/PlazaBuilder` |
| aantal/ligging van huizen | `ReplicatedStorage/Modules/WorldLayout` (`HouseColumns`) |
| promocodes | `ServerScriptService/Config/CodesConfig` |
