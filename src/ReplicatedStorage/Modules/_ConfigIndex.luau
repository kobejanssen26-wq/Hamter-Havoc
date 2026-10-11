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
	Weapons, equipment, boosts, prices     Content/Items/<YourItem>   (copy _Template)   +   ShopConfig (categories, other shop items)
	Game passes (Robux)                    GamepassConfig
	Rebirth cost, requirements, rewards    RebirthConfig        (what resets / is kept: RebirthConfig.ResetList / KeepList)
	Floors, elevator unlocks               FloorConfig
	Security gate, stealing, carrying      SecurityConfig, TheftConfig, HamsterStates (Config)
	Upgrades (coin + token)                UpgradeConfig
	Leaderboards                           LeaderboardConfig
	Quests, achievements, daily reward     QuestConfig, AchievementConfig, DailyRewardConfig, IndexRewardConfig
	Sounds, volumes                        AudioConfig
	Emotes, animations                     Content/Emotes, Content/Animations, EmoteConfig
	Keys                                   InputConfig
	Hotbar                                 HotbarConfig
	Mountains, scenery, lighting numbers   EnvironmentConfig   (the scenery itself is Workspace/Environment, editable by hand)
	Where houses / road / plaza stand      WorldLayout, PathConfig, Route

	UI look (colours, fonts, sizes)        StarterPlayer/StarterPlayerScripts/UI/Theme   (+ UIKit, Icons, UIRegistry for buttons)
	World / house / plaza builders         ServerScriptService/Systems/WorldBuilder/...
	Game systems (server)                  ServerScriptService/Systems/...
]]

return {}
