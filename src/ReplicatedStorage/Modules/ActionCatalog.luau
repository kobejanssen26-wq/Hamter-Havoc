--[[
	ActionCatalog: every named character action the game shows (the ONE list; docs/ANIMATIONS.md is generated from it).

	An action is a short body movement + optional sound that everybody nearby sees: pick up a hamster, place it on the bench,
	buy something, open / claim a reward, equip an item, celebrate a rebirth, swing a weapon ...
	The SERVER decides that an action happened (a purchase went through, the placement was valid ...) and announces it
	(Systems/ActionFx.play); every client then animates it (Controllers/ActionAnimator). Clients can not trigger an action
	for somebody else, and an action never decides anything - it is only the picture of something that already happened.

	How each action is drawn (Controllers/ActionAnimator):
	  1. If the entry has Animation = "<Name from Modules/Content/Animations>" AND that animation has an AssetId -> that published animation is played.
	  2. Otherwise the built-in procedural Pose is used (arm / neck movements on the character's joints). Nothing is ever invented:
	     no asset id appears anywhere in this file; to use your own animation upload it in Studio and fill in its Content/Animations file.

	Fields
	  Id            stable name (never rename; code and docs refer to it)
	  Name          what to call it in docs
	  Group         Hamster | Shop | Reward | Item | Combat | Progress
	  Pose          procedural fallback: a key of ActionAnimator.Poses (ReachDown, PresentForward, Nod, ArmsUp, Raise, Swing, Drop)
	  Animation     optional Content/Animations name that replaces the pose once it has an AssetId (nil = pose only)
	  Sound         optional AudioConfig sound name played with the action
	  Priority      Enum.AnimationPriority name used for a published animation
	  Cooldown      seconds before the same player's same action may be announced again (server enforced; stops spam)
	  Duration      seconds the procedural pose takes
	  Rig           R15 | R6 | Any: what the procedural pose is made for. The built-in poses move R15 joints; on an R6 character only the sound plays
	                until you assign a published animation (Animation field)
	  Availability  who sees / may trigger it
	  Trigger       where the server announces it
]]

local ActionCatalog = {}

ActionCatalog.List = {
	{ Id = "PickUpHamster", Name = "Pick up a hamster", Group = "Hamster", Pose = "ReachDown", Sound = nil, Priority = "Action", Cooldown = 0.4, Duration = 0.7, Rig = "R15",
		Availability = "every player (the one who claims it)", Trigger = "HamsterSystem.claim - after the cash was paid and the hamster is rolling home" },
	{ Id = "PlaceHamster", Name = "Place a hamster on the bench", Group = "Hamster", Pose = "PresentForward", Sound = "Click", Priority = "Action", Cooldown = 0.25, Duration = 0.6, Rig = "R15",
		Availability = "the owner of the base", Trigger = "RequestRouter Equip / EquipBest - only after CollectionSystem.equip validated slot, ownership and theft lock" },
	{ Id = "TakeHamster", Name = "Take a hamster off the bench", Group = "Hamster", Pose = "ReachDown", Sound = "Click", Priority = "Action", Cooldown = 0.25, Duration = 0.6, Rig = "R15",
		Availability = "the owner of the base", Trigger = "RequestRouter Unequip - only after CollectionSystem.unequip succeeded" },
	{ Id = "Buy", Name = "Buy something", Group = "Shop", Pose = "Nod", Sound = "Coin", Priority = "Action", Cooldown = 0.5, Duration = 0.5, Rig = "R15",
		Availability = "the buyer", Trigger = "RequestRouter ShopBuy / BuyUpgrade - only when the purchase really went through" },
	{ Id = "OpenReward", Name = "Open a prize (Lucky Wheel)", Group = "Reward", Pose = "ArmsUp", Sound = "Reward", Priority = "Action", Cooldown = 1, Duration = 0.9, Rig = "R15",
		Availability = "the player who won it", Trigger = "RequestRouter SpinWheel - after SpinSystem paid out the prize" },
	{ Id = "ClaimReward", Name = "Claim a reward", Group = "Reward", Pose = "Raise", Sound = "Reward", Priority = "Action", Cooldown = 0.8, Duration = 0.7, Rig = "R15",
		Availability = "the player who claimed it", Trigger = "RequestRouter ClaimPlaytime / ClaimDaily / ClaimQuest / ClaimAchievement / ClaimIndexReward / RedeemCode - after the reward was granted" },
	{ Id = "EquipItem", Name = "Equip a weapon or tool", Group = "Item", Pose = "Raise", Sound = nil, Priority = "Action", Cooldown = 0.3, Duration = 0.45, Rig = "R15",
		Availability = "every player (the one who equips it)", Trigger = "RequestRouter EquipItem - after GearSystem.equip succeeded" },
	{ Id = "Celebrate", Name = "Celebrate a rebirth", Group = "Progress", Pose = "ArmsUp", Sound = nil, Priority = "Action", Cooldown = 2, Duration = 1.1, Rig = "R15",
		Availability = "the player who rebirthed", Trigger = "RequestRouter Rebirth - after RebirthSystem.perform succeeded" },
	{ Id = "Slap", Name = "Slap / weapon swing", Group = "Combat", Pose = "Swing", Animation = "Weapon_SlapGlove", Sound = "Slap", Priority = "Action2", Cooldown = 0, Duration = 0.5, Rig = "R15",
		Availability = "every player; timings come from CombatTiming (server phases WindUp / Active / Recovery)",
		Trigger = "CombatSystem (Fx Swing) - played by Controllers/WeaponAnimator, which has its own per-weapon animation or procedural swing" },
}

ActionCatalog.ById = {} :: { [string]: any }
for _, entry in ActionCatalog.List do
	assert(ActionCatalog.ById[entry.Id] == nil, "duplicate action id " .. entry.Id)
	ActionCatalog.ById[entry.Id] = entry
end

return ActionCatalog
