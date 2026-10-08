--[[
	The life of a hamster ball, and every number that tunes the claim -> transport -> steal -> secure loop.

	  Spawning    rolls out of the burrow
	  Travelling  rolls along the central road. This is the AVAILABLE state: anyone can claim it by paying
	  InTransit   claimed (the payer paid) and rolling home on its own. NOT safe: others can steal it
	  Carried     somebody holds it and must run it to their own house
	  Dropped     the carrier was knocked out / let go; briefly untouchable
	  Recoverable dropped and now free for anybody to pick up
	  Secured     reached its owner's house for good (then it lives in the collection)
	  Working     a secured hamster running on a wheel in the house (handled by HouseSystem, not here)

	CLAIMED is not OWNED: only SECURED is owned.
	The server owns the state machine. Clients only ever see what the server tells them.
]]

local HamsterStates = {}

HamsterStates.Spawning = "Spawning"
HamsterStates.Travelling = "Travelling"
HamsterStates.InTransit = "InTransit"
HamsterStates.Carried = "Carried"
HamsterStates.Dropped = "Dropped"
HamsterStates.Recoverable = "Recoverable"
HamsterStates.Secured = "Secured"
HamsterStates.Working = "Working"

HamsterStates.Config = {
	-- claiming / carrying
	MaxPending = 3, -- hamsters one player may have unsecured (rolling home + carried) at once
	ClaimRange = 4, -- extra studs added to the Collection Range upgrade
	InteractRange = 6, -- studs from the ball's surface to steal / pick up
	TransitSpeedFactor = 0.5, -- rolling-home speed = road speed * this ...
	TransitSpeedMin = 7.5,
	TransitSpeedMax = 14.5, -- ... clamped, so a player can keep up with (or chase) any hamster
	StealSeconds = { Min = 0.7, Max = 1.5 }, -- hold time to steal; rarer = longer
	PickupSeconds = 0.35,
	PadSettleSeconds = 1.8, -- a ball that rolled home rests on the pad this long before it is secured
	CarryWalkFactor = { Min = 0.72, Max = 0.92 }, -- carrier walk speed multiplier (rarer = slower)
	MaxCarrySeconds = 75, -- then the ball is let go
	MaxCarrySpeed = 85, -- faster than this = exploit -> dropped
	DropGraceSeconds = 1.5, -- Dropped -> Recoverable
	DropExpireSeconds = 25, -- nobody picked it up: it rolls back to its payer
	DropBanSeconds = 3, -- the player who dropped it can't instantly grab it again
	TimeoutBanSeconds = 8,
	MaxResets = 2, -- how often an abandoned ball may roll back home before it vanishes

	-- money risk
	StolenInsurance = 0.25, -- payer gets this share back when somebody else secures their stolen hamster
	VanishRefund = 1.0, -- payer leaves / ball is removed: full refund

	-- fighting
	SlapCooldown = 1.1,
	SlapRange = 8,
	SlapArc = 0.15, -- minimum dot(look, toTarget)
	StunSeconds = 0.9,
	StunImmunitySeconds = 1.6,
	DropChance = 0.7, -- chance that a hit carrier loses the hamster
	KnockbackPower = 38,
}

-- Radius of the glass ball (studs). Bigger rarity = bigger ball.
function HamsterStates.ballRadius(rank: number): number
	return 2.2 + 0.1 * (rank - 1)
end

return HamsterStates
