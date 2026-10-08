local Runtime = require("./runtime")
local game = Runtime.boot("/home/user/hamter-havoc")
local sss = game:GetService("ServerScriptService")
local WorldBuilder = Runtime.require(sss.Systems.WorldBuilder)
local t = os.clock()
local world = WorldBuilder.build()
print("built in", os.clock() - t, "houses", #world.Houses)
local ws = game:GetService("Workspace")
for _, c in ws:GetChildren() do print(c.Name, #c:GetDescendants()) end
