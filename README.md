# Hamster Havoc (Roblox / Rojo) – Fase 1 prototype

Alle code is Luau en wordt met Rojo naar Roblox Studio gesynchroniseerd.

**Snel proberen zonder Rojo:** open `HamsterTycoon.rbxl` in Roblox Studio en druk op Play.

## Starten (Windows)

1. Rokit installeren (PowerShell): `Invoke-RestMethod https://raw.githubusercontent.com/rojo-rbx/rokit/main/scripts/install.ps1 | Invoke-Expression`, nieuw venster openen.
2. In de projectmap: `rokit install` (leest `rokit.toml`, installeert Rojo).
3. Rojo-plugin in Studio: `rojo plugin install` (of via de VS Code Rojo-extensie).
4. `rojo serve` draaien in de projectmap.
5. Studio: nieuwe **Baseplate**, Plugins → Rojo → **Connect**.
6. Play, of Test → Clients and Servers → 2 spelers.

## Spelen / testen

| Actie | Hoe |
|---|---|
| Hamster kopen | Naast een bal op de route staan, **[E]** |
| Geld ophalen | Groene collector in je basis, **[E]** |
| Hamster stelen | Bij andermans wiel **[E] vasthouden (1s)**, dan naar je eigen basis rennen |
| Dief "raken" (test) | Dichtbij de dief **[F]** → hamster gaat terug |

Test-hulpmiddelen staan in `GameConfig.Debug` (`ForceRarity`, `SpawnIntervalOverride`).

## Structuur

```
src/
  ReplicatedStorage/Shared/
    Config/   GameConfig, Rarities, HamsterCatalog, Mutations, Rebirth
    Types/    Hamster
    Util/     Format, PartUtil, RouteMath
    Remotes/  (alleen server -> client "Notify")
  ServerScriptService/
    Main.server.luau
    Services/ DataService, HamsterFactory, HamsterModel, VisualEffects, RouteService,
              PurchaseService, BaseService, SecurityService, IncomeService, StealService,
              MapService, Notifier
  ServerStorage/Assets/        (leeg, voor later)
  StarterPlayer/StarterPlayerScripts/
    Main.client.luau
    Controllers/ HudController, PromptController, WheelAnimator
  StarterGui/UI/               (leeg; HUD wordt nu vanuit code gebouwd)
```

## Server-autoriteit

Geld, kopen, eigendom, inkomen en stelen draaien volledig op de server via ProximityPrompts.
De client stuurt geen gameplay-requests; hij toont alleen attributen (`Cash`, `Stored`, `IncomePerSecond`)
en verbergt prompts die niet voor jou zijn (puur cosmetisch).
