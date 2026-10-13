--[[
	START HERE: where to change things (ReplicatedStorage/Modules). This ModuleScript is never required by the game, it is
	only a map you can read in Studio. Everything below is a normal ModuleScript or folder in this same Modules folder.
	The longer version, with Workspace / Lighting / StarterPlayerScripts too, is docs/STUDIO_GUIDE.md.

	WHAT                                   WHERE
	-------------------------------------  ---------------------------------------------------------------------------
	Add / edit a hamster (name, rarity,    Content/Hamsters/<YourHamster>   (copy _Template; built-ins live in HamsterDatabase)
	  income, price, model, description,   Hamster models: ReplicatedStorage/Assets/HamsterModels
	  unlock rebirth, limited edition)     Display names of built-ins: HamsterNames
	Rarities, colours, spawn chances,      RarityConfig
	  price / income formula
	Gate cooldown, combat caps, starting   GameConfig        (ONE documented place for ordinary settings; admins can change `Live` ones in the panel)
	  cash, ability caps ...
	Weapons, equipment, boosts, prices     Content/Items/<YourItem>   (copy _Template)   +   ShopConfig (categories, other shop items)
	Combat / weapon animations             docs/COMBAT_GUIDE.md, Content/Animations/Weapon_*, CombatTiming
	Admin owner UserId + staff roles       ServerScriptService/Config/AdminConfig   (server only; panel: F10 or /admin)
	Game passes (Robux)                    GamepassConfig
	Rebirth cost, requirements, rewards    RebirthConfig        (what resets / is kept: RebirthConfig.ResetList / KeepList)
	Floors, elevator unlocks               FloorConfig
	Security gate, stealing, carrying      GameConfig (Security), SecurityConfig (tiers), TheftConfig, HamsterStates (Config)
	Upgrades (coin + token)                UpgradeConfig
	Leaderboards                           LeaderboardConfig
	Quests, achievements, daily reward     QuestConfig, AchievementConfig, DailyRewardConfig, IndexRewardConfig
	Sounds, volumes                        AudioConfig
	Emotes, animations                     Content/Emotes, Content/Animations, EmoteConfig
	Keys                                   InputConfig
	Hotbar                                 HotbarConfig
	Mountains, scenery, lighting numbers   EnvironmentConfig   (the scenery itself is Workspace/Environment, editable by hand)
	Where houses / road / plaza stand      WorldLayout, PathConfig, Route

	HUD (pills, rail, hotbar)              StarterGui/MainUI, StarterGui/HotbarUI   (real ScreenGuis - edit them visually in Studio)
	UI look (colours, fonts, sizes)        StarterPlayer/StarterPlayerScripts/UI/Theme   (+ UIKit, Icons, UIRegistry for buttons)
	World / house / plaza builders         ServerScriptService/Systems/WorldBuilder/...
	Game systems (server)                  ServerScriptService/Systems/...
]]

return {}
