-- Environment: angular mountains around the outer edges, Studio-owned scenery, Lighting ownership
local adv = M.Sim.advance
local results = { pass = 0, fail = 0 }
local function section(t) print("\n== " .. t .. " ==") end
local function check(name, cond, detail)
	if cond then results.pass += 1 else results.fail += 1 end
	print(string.format("  [%s] %s%s", cond and "PASS" or "FAIL", name, detail and ("  (" .. tostring(detail) .. ")") or ""))
end

task.spawn(function()
	M.isServer = true
	local Lighting = game:GetService("Lighting")
	local CollectionService = game:GetService("CollectionService")
	local Config = require(find("ReplicatedStorage.Modules.EnvironmentConfig"))
	local Layout = require(find("ReplicatedStorage.Modules.WorldLayout"))

	-- a place that was saved from Studio: Environment is Studio-owned and was edited by hand
	local stale = workspace:FindFirstChild("Environment") -- the mock pre-creates empty folders named like the project's world models
	if stale then stale:Destroy() end
	local env = M.newInstance("Folder", true)
	RawData[env].Name = "Environment"
	env:SetAttribute("StudioOwned", true)
	local marker = M.newInstance("Part", true)
	RawData[marker].Name = "MyOwnRock"
	M.setParent(marker, env)
	local cloud = M.newInstance("Model", true)
	RawData[cloud].Name = "Cloud"
	M.setParent(cloud, env)
	M.setParent(env, workspace)
	Lighting:SetAttribute("StudioOwned", true)
	RawData[Lighting].Props.ClockTime = 9.5 -- the creator picked morning light in Studio

	local mainServer = find("ServerScriptService.Main")
	task.spawn(function() RawData[mainServer].Source(mainServer, require) end)
	adv(2)

	section("1. Studio-owned scenery is left alone")
	local kept = workspace:FindFirstChild("Environment")
	check("the Environment from the place is still the same object", kept == env)
	check("hand-made objects survive Play", kept:FindFirstChild("MyOwnRock") == marker)
	check("it was NOT regenerated (no generated Ground)", kept:FindFirstChild("Ground") == nil)
	check("clouds get their runtime tag back", CollectionService:HasTag(cloud, "Cloud"))
	check("the rest of the world is still built (houses, plaza, path)", workspace:FindFirstChild("PlayerHouses") ~= nil and workspace:FindFirstChild("HamsterPlaza") ~= nil and workspace:FindFirstChild("HamsterPath") ~= nil)
	check("Lighting from the place is respected", Lighting.ClockTime == 9.5, Lighting.ClockTime)

	section("2. mountains: shapes and placement (generated copy)")
	local MountainBuilder = require(find("ServerScriptService.Systems.WorldBuilder.MountainBuilder"))
	local holder = M.newInstance("Folder", true)
	local halfX, halfZ = Layout.GroundHalfX, Layout.GroundHalfZ
	local folder = MountainBuilder.build(holder, Random.new(Config.Seed), halfX, halfZ, {})
	local parts, bad, minGap, tallest, uncollidable, anchored = 0, 0, math.huge, 0, true, true
	local mountains = 0
	for _, range in M.InstanceMethods.GetChildren(folder) do
		for _, mountain in M.InstanceMethods.GetChildren(range) do
			mountains += 1
			for _, part in M.InstanceMethods.GetChildren(mountain) do
				parts += 1
				local p = RawData[part].Props
				local cf, size = p.CFrame, p.Size
				anchored = anchored and p.Anchored == true
				uncollidable = uncollidable and p.CanCollide == false and p.CastShadow == false
				-- distance of the part's centre to the playable rectangle (it must lie outside it)
				local dx, dz = math.max(math.abs(cf.X) - halfX, 0), math.max(math.abs(cf.Z) - halfZ, 0)
				local gap = math.sqrt(dx * dx + dz * dz)
				minGap = math.min(minGap, gap)
				tallest = math.max(tallest, cf.Y + size.Y / 2)
				if gap < 20 then bad += 1 end
			end
		end
	end
	check("a real set of mountains exists", mountains >= 40, mountains)
	check("nothing stands inside or at the edge of the playable ground (centre stays open)", bad == 0 and minGap >= 20, string.format("%d bad, closest %.0f studs", bad, minGap))
	check("part budget is sane (cheap scenery)", parts > 500 and parts < 14000, parts)
	check("all mountain parts are anchored, non-colliding and don't cast shadows", anchored and uncollidable)
	check("heights are bounded (no sky-high spikes)", tallest < 700, math.floor(tallest))
	local rangesOk = true
	for _, range in Config.Ranges do if M.InstanceMethods.FindFirstChild(folder, range.Name) == nil then rangesOk = false end end
	check("every configured range (near / mid / far) is present", rangesOk)
	-- faceted massifs: built from triangles, with recorded height, and every part below the declared height
	local m1 = M.InstanceMethods.GetChildren(folder)[1]
	local m1 = M.InstanceMethods.GetChildren(m1)[1]
	local tri = RawData[m1].Attributes.Triangles
	local hgt = RawData[m1].Attributes.Height
	local within = true
	for _, part in M.InstanceMethods.GetChildren(m1) do
		local cf, size = RawData[part].Props.CFrame, RawData[part].Props.Size
		if cf and size and hgt and cf.Y - size.Y / 2 > hgt + 1 then within = false end
	end
	check("mountains are faceted triangle meshes (Triangles/Height recorded, parts stay under the height)", type(tri) == "number" and tri >= 20 and type(hgt) == "number" and within, tostring(tri) .. "/" .. tostring(hgt))
	-- deterministic: same seed -> same mountains (reproducible scenery)
	local holder2 = M.newInstance("Folder", true)
	local folder2 = MountainBuilder.build(holder2, Random.new(Config.Seed), halfX, halfZ, {})
	check("same seed gives the same range", #M.descendants(folder2) == #M.descendants(folder))
	-- lakes veto positions
	local holder3 = M.newInstance("Folder", true)
	local lakeBlock = MountainBuilder.build(holder3, Random.new(Config.Seed), halfX, halfZ, { { Vector3.new(0, 0, halfZ + 175), 300 } })
	check("lakes keep mountains away", #M.descendants(lakeBlock) < #M.descendants(folder))

	print(string.format("PASS %d  FAIL %d", results.pass, results.fail))
	print("== done ==")
end)
