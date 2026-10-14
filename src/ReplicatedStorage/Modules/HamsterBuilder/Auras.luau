--[[
	Auras: builds the glow / particles / ground ring of a hamster from AuraConfig (rarity default + the hamster's own override).
	Everything it creates is a child of the hamster model, so removing the model removes the aura.
	One emitter + one light + one flat disc at most. Previews (LowDetail) and builds with Particles = false get no aura.
]]

local AuraConfig = require(script.Parent.Parent.AuraConfig)
local Toolkit = require(script.Parent.Toolkit)

local Auras = {}

local T = Toolkit
local CF = CFrame.new
local ANG = CFrame.Angles

-- rarity: { Color = Color3, Accent = Color3 } (RarityConfig.ById[...]) or nil
function Auras.apply(ctx: Toolkit.Ctx, species: any, opts: { Particles: boolean?, LowDetail: boolean?, Aura: boolean? }, rarity: any)
	if opts.Aura == false then
		return -- previews and icons (UIKit.hamsterIcon) never get one
	end
	local color = if rarity then rarity.Color else ctx.Accent
	local accent = if rarity then rarity.Accent else ctx.Accent
	local aura = AuraConfig.resolve(species, color, accent)
	if not aura then
		return
	end
	if aura.Style and aura.Rate > 0 then
		local emitter = T.emitter(ctx, aura.Style, aura.Color, "Body")
		if emitter then
			emitter.Name = "Aura"
			emitter.Rate = aura.Rate
			if opts.Particles == false then
				emitter.Enabled = false -- switched on near the camera by AmbientController (the server builds bench hamsters without particles)
			end
		end
	end
	if aura.Light > 0 and not species.Glow then -- (a hamster with its own Glow keeps that one light)
		T.glow(ctx, aura.Color, aura.Light, 6 + aura.Light * 3)
	end
	if aura.Ring then
		local ring = T.disc(ctx, "AuraRing", 4.4, 0.08, CF(0, 0.06, 0.3) * ANG(0, 0, math.rad(90)), aura.Ring, { Material = Enum.Material.Neon, Transparency = 0.45, Attach = "Body" })
		if ring then
			ring.CanCollide = false
			ring.CanQuery = false
			ring.CanTouch = false
			ring.CastShadow = false
		end
	end
end

return Auras
