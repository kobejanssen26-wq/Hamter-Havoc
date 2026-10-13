--[[
	House security: a gate that zaps strangers while it is active.
	Active for a limited time, then it switches off and has to be re-activated by hand at the
	pylon near the gate (after a short recharge). Higher rebirths = better gate.

	While the gate is OFF anybody can walk in: that is the window thieves wait for.
]]

local GameConfig = require(script.Parent.GameConfig)

local SecurityConfig = {}

-- Look/strength tiers by rebirth (MinRebirth ascending). The numbers (reopen cooldown, how long the gate stays on, zap stun)
-- are NOT here: they live in GameConfig.luau > Security, so there is one place to change them.
SecurityConfig.Tiers = {
	{ Name = "Basic Gate", MinRebirth = 0, Beams = 2, Color = Color3.fromRGB(255, 96, 96) },
	{ Name = "Advanced Security", MinRebirth = 1, Beams = 3, Color = Color3.fromRGB(255, 150, 80) },
	{ Name = "Fortress Gate", MinRebirth = 3, Beams = 4, Color = Color3.fromRGB(120, 190, 255) },
	{ Name = "Royal Vault", MinRebirth = 6, Beams = 5, Color = Color3.fromRGB(190, 130, 255) },
}

SecurityConfig.MaxBeams = 5
SecurityConfig.StartActive = true -- a new owner starts with an active gate

-- Read through to GameConfig so old call sites (SecurityConfig.ZapStunSeconds ...) keep working and always see the live value.
local READ_THROUGH = {
	BaseDuration = { "Security", "GateBaseDuration" },
	PerRebirthSeconds = { "Security", "GateSecondsPerRebirth" },
	ZapStunSeconds = { "Security", "ZapStunSeconds" },
	ZapCooldown = { "Security", "ZapCooldown" },
}
setmetatable(SecurityConfig, {
	__index = function(_, key)
		local target = READ_THROUGH[key]
		if target then
			return GameConfig.get(target[1], target[2])
		end
		return nil
	end,
})

-- How long the gate stays on after you switch it on: GateBaseDuration + GateSecondsPerRebirth for every rebirth you did.
-- Derived from the persisted rebirth count, so it can never be granted twice.
function SecurityConfig.duration(rebirths: number): number
	return GameConfig.get("Security", "GateBaseDuration") + GameConfig.get("Security", "GateSecondsPerRebirth") * math.max(0, math.floor(rebirths))
end

-- Seconds between the gate switching off and being allowed to switch on again (GameConfig > Security > GateReopenCooldown,
-- a little shorter for every better gate tier).
function SecurityConfig.recharge(tier: { MinRebirth: number }): number
	local index = table.find(SecurityConfig.Tiers, tier :: any) or 1
	local base = GameConfig.get("Security", "GateReopenCooldown") - GameConfig.get("Security", "GateRechargeBonusPerTier") * (index - 1)
	return math.max(GameConfig.get("Security", "GateMinCooldown"), base)
end

function SecurityConfig.tier(rebirths: number): { Name: string, MinRebirth: number, Beams: number, Color: Color3 }
	local result = SecurityConfig.Tiers[1]
	for _, tier in SecurityConfig.Tiers do
		if rebirths >= tier.MinRebirth then
			result = tier
		end
	end
	return result
end

return SecurityConfig
