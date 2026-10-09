--[[
	Props for the apartment: the 8 upgrade pedestal props (they grow with every upgrade level) and
	small furniture helpers shared by every floor. Everything is anchored, mostly non-colliding.
]]

local Build = require(script.Parent.Parent.Build)
local Palette = require(script.Parent.Parent.Palette)

local WOOD = Enum.Material.WoodPlanks
local PLASTIC = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

local Props = {}

-- upgrade pedestal props: (folder, top CFrame, fraction 0..1, ghost transparency)
local propBuilders: { [string]: (Instance, CFrame, number, number) -> () } = {}
Props.Upgrade = propBuilders

propBuilders.HamsterTraining = function(folder, top, fraction, ghost)
	local size = 1.2 + fraction * 0.9
	local wheel = Build.model(folder, "MiniWheel")
	local center = top * CFrame.new(0, size + 0.4, 0)
	local disc = Build.part(wheel, "Disc", Vector3.new(0.4, size * 2, size * 2), center, Palette.Glass, Enum.Material.Glass, { Shape = Enum.PartType.Cylinder, Transparency = 0.6 + ghost, CanCollide = false })
	Build.deco(wheel, "SpokeA", Vector3.new(0.2, size * 2, 0.2), center, Palette.Gold, NEON, { Transparency = ghost })
	Build.deco(wheel, "SpokeB", Vector3.new(0.2, 0.2, size * 2), center, Palette.Gold, NEON, { Transparency = ghost })
	wheel.PrimaryPart = disc
	wheel:SetAttribute("HomeCFrame", center)
	Build.animate(wheel, "SpinModel", { Speed = 0.8 + fraction * 5, Axis = "X" })
end

propBuilders.CollectionRange = function(folder, top, fraction, ghost)
	Build.pillar(folder, "Pole", 0.25, 2.2, top * CFrame.new(0, 1.1, 0), Palette.Ink, Enum.Material.Metal, { CanCollide = false })
	local bulb = Build.blob(folder, "Bulb", Vector3.one * (0.9 + fraction * 0.9), top * CFrame.new(0, 2.5, 0), Color3.fromRGB(120, 230, 255), NEON, { CanCollide = false, Transparency = ghost })
	Build.light(bulb, Color3.fromRGB(120, 230, 255), 0.8 * (1 - ghost), 10)
	Build.pillar(folder, "Ring", 1.8 + fraction * 2.6, 0.08, top * CFrame.new(0, 0.12, 0), Color3.fromRGB(120, 230, 255), NEON, { CanCollide = false, Transparency = 0.45 + ghost / 2 })
end

propBuilders.CoinMultiplier = function(folder, top, fraction, ghost)
	local coins = 2 + math.floor(fraction * 8)
	for index = 1, coins do
		Build.pillar(folder, "Coin", 1.5, 0.28, top * CFrame.new((index % 2) * 0.12, 0.15 + (index - 1) * 0.3, 0) * CFrame.Angles(0, index * 0.5, 0), Palette.Gold, Enum.Material.Metal, { CanCollide = false, Transparency = ghost })
	end
	Build.pillar(folder, "Coin", 1.5, 0.28, top * CFrame.new(1.4, 0.14, 0.3), Palette.Gold, Enum.Material.Metal, { CanCollide = false, Transparency = ghost })
end

propBuilders.SpawnLuck = function(folder, top, fraction, ghost)
	local clovers = 1 + math.floor(fraction * 3)
	for index = 1, clovers do
		local offset = (index - (clovers + 1) / 2) * 1.2
		local scale = 0.8 + fraction * 0.6
		Build.pillar(folder, "Stem", 0.14, 1.4 * scale, top * CFrame.new(offset, 0.7 * scale, 0), Palette.LeafDark, Enum.Material.Grass, { CanCollide = false, Transparency = ghost })
		for leaf = 0, 3 do
			local angle = leaf * math.pi / 2 + math.pi / 4
			Build.blob(folder, "Leaf", Vector3.new(0.75, 0.2, 0.75) * scale, top * CFrame.new(offset + math.cos(angle) * 0.45 * scale, 1.5 * scale, math.sin(angle) * 0.45 * scale), Color3.fromRGB(90, 200, 100), Enum.Material.Grass, { CanCollide = false, Transparency = ghost })
		end
	end
end

propBuilders.WalkSpeed = function(folder, top, fraction, ghost)
	for _, side in { -0.7, 0.7 } do
		Build.part(folder, "Shoe", Vector3.new(0.9, 0.8, 1.7), top * CFrame.new(side, 0.6, 0), Palette.Pink, PLASTIC, { CanCollide = false, Transparency = ghost })
		Build.part(folder, "Sole", Vector3.new(1, 0.25, 1.8), top * CFrame.new(side, 0.15, 0), Color3.new(1, 1, 1), PLASTIC, { CanCollide = false, Transparency = ghost })
		Build.deco(folder, "Wing", Vector3.new(0.12, 0.9 + fraction, 1.2 + fraction), top * CFrame.new(side * 1.5, 1.1, 0.2) * CFrame.Angles(0, 0, side * 0.4), Color3.new(1, 1, 1), PLASTIC, { Transparency = ghost })
	end
	for index = 1, 1 + math.floor(fraction * 4) do
		Build.deco(folder, "Streak", Vector3.new(0.12, 0.12, 1 + index * 0.4), top * CFrame.new(0, 0.5 + index * 0.15, 1.6 + index * 0.4), Color3.fromRGB(120, 230, 255), NEON, { Transparency = 0.3 + ghost })
	end
end

propBuilders.ExtraStorage = function(folder, top, fraction, ghost)
	local boxes = 1 + math.floor(fraction * 5)
	for index = 1, boxes do
		local row = math.ceil(math.sqrt(index))
		Build.part(folder, "Box", Vector3.one * 1.1, top * CFrame.new(((index - 1) % 3 - 1) * 1.15, 0.55 + (row - 1) * 1.1, 0), Palette.WoodLight, WOOD, { CanCollide = false, Transparency = ghost })
	end
end

propBuilders.RebirthBoost = function(folder, top, fraction, ghost)
	local size = 1 + fraction * 1.1
	local flame = Build.blob(folder, "Flame", Vector3.new(size, size * 1.7, size), top * CFrame.new(0, size * 0.9 + 0.2, 0), Color3.fromRGB(255, 120, 50), NEON, { CanCollide = false, Transparency = ghost })
	Build.blob(folder, "Core", Vector3.new(size * 0.5, size, size * 0.5), top * CFrame.new(0, size * 0.7 + 0.2, 0), Color3.fromRGB(255, 220, 110), NEON, { CanCollide = false, Transparency = ghost })
	Build.light(flame, Color3.fromRGB(255, 140, 60), 0.9 * (1 - ghost), 10)
	Build.animate(flame, "Bob", { Amplitude = 0.15, Speed = 3 })
end

propBuilders.GemBoost = function(folder, top, fraction, ghost)
	local gems = 1 + math.floor(fraction * 5)
	local colors = { Color3.fromRGB(120, 230, 255), Color3.fromRGB(255, 130, 220), Color3.fromRGB(150, 255, 190) }
	for index = 1, gems do
		local angle = index * 2.1
		local radius = if index == 1 then 0 else 0.9
		local height = 0.9 + (index % 3) * 0.3 + fraction * 0.4
		Build.part(folder, "Gem", Vector3.new(0.7, height, 0.7), top * CFrame.new(math.cos(angle) * radius, height / 2, math.sin(angle) * radius) * CFrame.Angles(0, angle, math.rad(8 * (index % 3))), colors[(index - 1) % 3 + 1], NEON, { CanCollide = false, Transparency = ghost })
	end
end


---------------------------------------------------------------------------
-- furniture
---------------------------------------------------------------------------

-- A sofa facing local -Z of `cframe`.
function Props.sofa(parent: Instance, cframe: CFrame, color: Color3, length: number?)
	local width = length or 7
	Build.part(parent, "SofaBase", Vector3.new(width, 1.2, 3), cframe * CFrame.new(0, 0.6, 0), color, PLASTIC)
	Build.part(parent, "SofaBack", Vector3.new(width, 2.4, 0.9), cframe * CFrame.new(0, 1.8, 1.2), color, PLASTIC)
	for _, side in { -1, 1 } do
		Build.part(parent, "SofaArm", Vector3.new(0.9, 1.9, 3), cframe * CFrame.new(side * (width / 2 - 0.45), 1.15, 0), color, PLASTIC)
	end
	Build.blob(parent, "Cushion", Vector3.new(1.4, 1.2, 1.4), cframe * CFrame.new(-width / 4, 1.6, 0.2), Palette.Cream, PLASTIC, { CanCollide = false })
end

-- Potted plant (one big leafy blob in a pot).
function Props.plant(parent: Instance, position: CFrame, scale: number?)
	local s = scale or 1
	Build.pillar(parent, "Pot", 1.8 * s, 1.5 * s, position * CFrame.new(0, 0.75 * s, 0), Palette.Peach, PLASTIC)
	Build.blob(parent, "Plant", Vector3.new(2.8, 3.2, 2.8) * s, position * CFrame.new(0, 3 * s, 0), Palette.Leaf, Enum.Material.Grass, { CanCollide = false })
end

-- A rug (two nested discs).
function Props.rug(parent: Instance, position: CFrame, diameter: number, outer: Color3, inner: Color3)
	Build.pillar(parent, "RugOuter", diameter, 0.06, position * CFrame.new(0, 0.04, 0), outer, PLASTIC, { CanCollide = false })
	Build.pillar(parent, "RugInner", diameter * 0.66, 0.08, position * CFrame.new(0, 0.05, 0), inner, PLASTIC, { CanCollide = false })
end

-- A low bookshelf against a wall facing local -Z.
function Props.shelf(parent: Instance, cframe: CFrame, width: number, rng: Random)
	Build.part(parent, "ShelfBody", Vector3.new(width, 5, 1.4), cframe * CFrame.new(0, 2.5, 0), Palette.WoodDark, WOOD)
	for row = 1, 3 do
		Build.part(parent, "ShelfBoard", Vector3.new(width - 0.4, 0.25, 1.5), cframe * CFrame.new(0, row * 1.2, -0.05), Palette.WoodLight, WOOD, { CanCollide = false })
		local books = math.max(3, math.floor(width / 1.1))
		for book = 1, books do
			local color = Palette.FlowerColors[rng:NextInteger(1, #Palette.FlowerColors)]
			Build.deco(parent, "Book", Vector3.new(0.6, 0.9, 0.9), cframe * CFrame.new(-width / 2 + 0.8 + (book - 1) * ((width - 1.6) / books), row * 1.2 + 0.6, -0.4), color, PLASTIC)
		end
	end
end

-- Counter / desk facing local -Z.
function Props.desk(parent: Instance, cframe: CFrame, width: number, color: Color3?)
	Build.part(parent, "DeskBody", Vector3.new(width, 2.6, 2), cframe * CFrame.new(0, 1.3, 0), color or Palette.WoodLight, WOOD)
	Build.part(parent, "DeskTop", Vector3.new(width + 0.4, 0.4, 2.4), cframe * CFrame.new(0, 2.8, 0), Palette.WoodDark, WOOD, { CanCollide = false })
end

-- A glowing screen on a stand (lab / console look).
function Props.screen(parent: Instance, cframe: CFrame, size: Vector2, color: Color3)
	Build.part(parent, "ScreenFrame", Vector3.new(size.X, size.Y, 0.4), cframe, Palette.Ink, PLASTIC, { CanCollide = false })
	Build.deco(parent, "ScreenGlow", Vector3.new(size.X - 0.4, size.Y - 0.4, 0.2), cframe * CFrame.new(0, 0, -0.15), color, NEON)
end

-- A stack of crates (storage).
function Props.crates(parent: Instance, cframe: CFrame)
	Build.part(parent, "Crate", Vector3.new(2.6, 2.6, 2.6), cframe * CFrame.new(0, 1.3, 0), Palette.WoodLight, WOOD)
	Build.part(parent, "Crate", Vector3.new(2.6, 2.6, 2.6), cframe * CFrame.new(2.8, 1.3, 0.2) * CFrame.Angles(0, 0.2, 0), Palette.Wood, WOOD)
	Build.part(parent, "Crate", Vector3.new(2.4, 2.4, 2.4), cframe * CFrame.new(1.2, 3.8, 0.1) * CFrame.Angles(0, -0.15, 0), Palette.WoodLight, WOOD)
end

return Props
