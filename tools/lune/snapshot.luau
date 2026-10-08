-- Builds the world headless and writes every visible part to a JSON file (for render.py).
-- usage: lune run tools/lune/snapshot.luau <projectRoot> <out.json>
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local Runtime = require("./runtime")
local Dump = require("./dump")

local root = process.args[1] or "."
local out = process.args[2] or "/tmp/world.json"
local game = Runtime.boot(root)
Runtime.quiet = true
local WorldBuilder = Runtime.require(game:GetService("ServerScriptService").Systems.WorldBuilder)
local world = WorldBuilder.build()
if process.env.SHOWCASE then
	-- show every stage of the apartment: house i gets i floors (wrapping), wheels and prestige
	local HouseBuilder = Runtime.require(game:GetService("ServerScriptService").Systems.WorldBuilder.HouseBuilder)
	local prestige = { 0, 2, 5, 10, 20, 0, 3, 15 }
	for index, house in world.Houses do
		local floors = (index - 1) % 5 + 1
		HouseBuilder.setFloors(house, floors, true)
		HouseBuilder.setPrestige(house, prestige[index] or 0)
		for slot in house.Slots do
			HouseBuilder.setWheel(house, slot, true)
		end
	end
end
local list = {}
for _, child in game:GetService("Workspace"):GetChildren() do
	if child.Name ~= "Camera" and child.Name ~= "Terrain" then
		Dump.collect(child, list)
	end
end
fs.writeFile(out, serde.encode("json", list))
print("parts:", #list)
