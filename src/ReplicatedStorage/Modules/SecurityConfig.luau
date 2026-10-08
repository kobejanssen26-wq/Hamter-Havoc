--[[
	House security: a gate that zaps strangers while it is active.
	Active for a limited time, then it switches off and has to be re-activated by hand at the
	pylon near the gate (after a short recharge). Higher rebirths = better gate.

	While the gate is OFF anybody can walk in: that is the window thieves wait for.
]]

local SecurityConfig = {}

-- MinRebirth ascending. Duration/Recharge in seconds.
SecurityConfig.Tiers = {
	{ Name = "Basic Gate", MinRebirth = 0, Duration = 45, Recharge = 14, Beams = 2, Color = Color3.fromRGB(255, 96, 96) },
	{ Name = "Advanced Security", MinRebirth = 1, Duration = 60, Recharge = 12, Beams = 3, Color = Color3.fromRGB(255, 150, 80) },
	{ Name = "Fortress Gate", MinRebirth = 3, Duration = 80, Recharge = 10, Beams = 4, Color = Color3.fromRGB(120, 190, 255) },
	{ Name = "Royal Vault", MinRebirth = 6, Duration = 100, Recharge = 8, Beams = 5, Color = Color3.fromRGB(190, 130, 255) },
}

SecurityConfig.MaxBeams = 5
SecurityConfig.ZapStunSeconds = 1.3
SecurityConfig.ZapCooldown = 2.2 -- per player, so they get time to leave
SecurityConfig.StartActive = true -- a new owner starts with an active gate

function SecurityConfig.tier(rebirths: number): { Name: string, MinRebirth: number, Duration: number, Recharge: number, Beams: number, Color: Color3 }
	local result = SecurityConfig.Tiers[1]
	for _, tier in SecurityConfig.Tiers do
		if rebirths >= tier.MinRebirth then
			result = tier
		end
	end
	return result
end

return SecurityConfig
