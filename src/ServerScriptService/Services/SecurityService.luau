--[[
	Base security: a laser barrier across the front of the base plus a marked border.
	Level driven (GameConfig.Security.Levels) so upgrades can be added later.
	Prototype rule: lasers only hurt non-owners and never fully block entry
	(you can still walk in from the sides).
]]

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local PartUtil = require(Shared.Util.PartUtil)

local SecurityService = {}

local lastZap = {} -- [Player] = os.clock()

local function onLaserTouched(base, levelConfig, hit: BasePart)
	local player = PartUtil.getPlayerFromPart(hit)
	if not player or player == base.Owner then
		return
	end

	local now = os.clock()
	if lastZap[player] and now - lastZap[player] < levelConfig.DamageCooldownSeconds then
		return
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		lastZap[player] = now
		humanoid:TakeDamage(levelConfig.LaserDamage)
	end
end

-- (Re)builds the security installation of a base for the given level.
function SecurityService.build(base, level: number?)
	level = level or GameConfig.Security.DefaultLevel
	local levelConfig = GameConfig.Security.Levels[level]
	base.SecurityLevel = level

	if base.SecurityFolder then
		base.SecurityFolder:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Security"
	base.SecurityFolder = folder

	local size = base.Size
	local floorTop = base.FloorTop
	local frontZ = -(size.Z / 2 - 1)

	for _, x in { -size.X / 2 + 0.5, size.X / 2 - 0.5 } do
		local post = PartUtil.create("LaserPost", Vector3.new(1, 7, 1), base.CFrame * CFrame.new(x, floorTop + 3.5, frontZ), {
			Color = Color3.fromRGB(40, 40, 50),
			Material = Enum.Material.Metal,
		})
		post.Parent = folder
	end

	for _, height in levelConfig.LaserHeights do
		local laser = PartUtil.create("Laser", Vector3.new(size.X - 2, 0.35, 0.35), base.CFrame * CFrame.new(0, floorTop + height, frontZ), {
			Color = levelConfig.Color,
			Material = Enum.Material.Neon,
			Transparency = 0.15,
			CanCollide = false,
		})
		CollectionService:AddTag(laser, "Laser")
		laser.Touched:Connect(function(hit)
			onLaserTouched(base, levelConfig, hit)
		end)
		laser.Parent = folder
	end

	-- Security area marking on the floor (four thin strips along the edge).
	local strips = {
		{ Vector3.new(size.X, 0.1, 0.6), Vector3.new(0, 0, -(size.Z / 2 - 0.3)) },
		{ Vector3.new(size.X, 0.1, 0.6), Vector3.new(0, 0, size.Z / 2 - 0.3) },
		{ Vector3.new(0.6, 0.1, size.Z), Vector3.new(-(size.X / 2 - 0.3), 0, 0) },
		{ Vector3.new(0.6, 0.1, size.Z), Vector3.new(size.X / 2 - 0.3, 0, 0) },
	}
	for _, strip in strips do
		local part = PartUtil.create("SecurityBorder", strip[1], base.CFrame * CFrame.new(strip[2] + Vector3.new(0, floorTop + 0.05, 0)), {
			Color = levelConfig.Color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
		part.Parent = folder
	end

	folder.Parent = base.Model
end

return SecurityService
