--[[
	House security: a gate that zaps strangers while it is active.
	Active for a limited time, then it switches off and has to be re-activated by hand at the
	pylon near the gate (after a short recharge). Higher rebirths = better gate.

	While the gate is OFF anybody can walk in: that is the window thieves wait for.
]]

local SecurityConfig = {}

-- Look/strength tiers by rebirth (MinRebirth ascending). Recharge in seconds. The ACTIVE time is NOT per tier:
-- it grows with every single rebirth, see SecurityConfig.duration.
SecurityConfig.Tiers = {
	{ Name = "Basic Gate", MinRebirth = 0, Recharge = 14, Beams = 2, Color = Color3.fromRGB(255, 96, 96) },
	{ Name = "Advanced Security", MinRebirth = 1, Recharge = 12, Beams = 3, Color = Color3.fromRGB(255, 150, 80) },
	{ Name = "Fortress Gate", MinRebirth = 3, Recharge = 10, Beams = 4, Color = Color3.fromRGB(120, 190, 255) },
	{ Name = "Royal Vault", MinRebirth = 6, Recharge = 8, Beams = 5, Color = Color3.fromRGB(190, 130, 255) },
}

-- How long the gate stays on after you switch it on: BaseDuration + PerRebirthSeconds for every rebirth you did.
-- (R0 = 45 s, R1 = 55 s, R2 = 65 s ...). Derived from the persisted rebirth count, so it can never be granted twice.
SecurityConfig.BaseDuration = 45
SecurityConfig.PerRebirthSeconds = 10

SecurityConfig.MaxBeams = 5
SecurityConfig.ZapStunSeconds = 1.3
SecurityConfig.ZapCooldown = 2.2 -- per player, so they get time to leave
SecurityConfig.StartActive = true -- a new owner starts with an active gate

function SecurityConfig.duration(rebirths: number): number
	return SecurityConfig.BaseDuration + SecurityConfig.PerRebirthSeconds * math.max(0, math.floor(rebirths))
end

function SecurityConfig.tier(rebirths: number): { Name: string, MinRebirth: number, Recharge: number, Beams: number, Color: Color3 }
	local result = SecurityConfig.Tiers[1]
	for _, tier in SecurityConfig.Tiers do
		if rebirths >= tier.MinRebirth then
			result = tier
		end
	end
	return result
end

return SecurityConfig
