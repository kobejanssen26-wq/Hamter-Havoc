--[[
	Minimal server-side engine mocks on top of runtime.luau, enough to boot Main.server headless:
	Players (fake players you add yourself), RunService, remotes, an in-memory DataStore,
	MarketplaceService and ProximityPromptService. No physics, no characters unless you add them.
]]

local roblox = require("@lune/roblox")
local Runtime = require("./runtime")

local Mocks = {}

Mocks.players = {}
Mocks.sent = {} -- { { Remote = name, Target = player|"all", Args = {...} } }
Mocks.callbacks = {} -- keyed by remote name

local function signal(instance, name)
	return Runtime.signalFor(instance, name)
end

function Mocks.install()
	roblox.implementMethod("DataModel", "BindToClose", function() end)
	roblox.implementMethod("Workspace", "GetServerTimeNow", function()
		return os.clock()
	end)
	pcall(function()
		Runtime.game.JobId = "headless-test"
		Runtime.game.PlaceId = 0
	end)
	roblox.implementMethod("RunService", "IsServer", function()
		return true
	end)
	roblox.implementMethod("RunService", "IsClient", function()
		return false
	end)
	roblox.implementMethod("RunService", "IsStudio", function()
		return true
	end)
	for _, name in { "Heartbeat", "Stepped", "RenderStepped", "PostSimulation", "PreSimulation" } do
		roblox.implementProperty("RunService", name, function(self)
			return signal(self, name)
		end)
	end

	roblox.implementProperty("RemoteEvent", "OnServerEvent", function(self)
		return signal(self, "OnServerEvent")
	end)
	roblox.implementProperty("RemoteEvent", "OnClientEvent", function(self)
		return signal(self, "OnClientEvent")
	end)
	roblox.implementMethod("RemoteEvent", "FireClient", function(self, player, ...)
		table.insert(Mocks.sent, { Remote = self.Name, Target = player, Args = { ... } })
	end)
	roblox.implementMethod("RemoteEvent", "FireAllClients", function(self, ...)
		table.insert(Mocks.sent, { Remote = self.Name, Target = "all", Args = { ... } })
	end)
	roblox.implementProperty("RemoteFunction", "OnServerInvoke", function(self)
		return Mocks.callbacks[self.Name]
	end, function(self, value)
		Mocks.callbacks[self.Name] = value
	end)
	roblox.implementProperty("BindableEvent", "Event", function(self)
		return signal(self, "Event")
	end)
	roblox.implementMethod("BindableEvent", "Fire", function(self, ...)
		signal(self, "Event"):Fire(...)
	end)

	roblox.implementMethod("Players", "GetPlayers", function()
		return table.clone(Mocks.players)
	end)
	roblox.implementMethod("Players", "GetPlayerByUserId", function(_, userId)
		for _, player in Mocks.players do
			if player.UserId == userId then
				return player
			end
		end
		return nil
	end)
	roblox.implementMethod("Players", "GetUserThumbnailAsync", function()
		return "", true
	end)
	for _, name in { "PlayerAdded", "PlayerRemoving" } do
		roblox.implementProperty("Players", name, function(self)
			return signal(self, name)
		end)
	end
	for _, name in { "CharacterAdded", "CharacterRemoving" } do
		roblox.implementProperty("Player", name, function(self)
			return signal(self, name)
		end)
	end
	roblox.implementMethod("Player", "Kick", function(self)
		print("[kick]", self.Name)
	end)
	roblox.implementMethod("Player", "IsInGroup", function()
		return false
	end)

	local stores = {}
	roblox.implementMethod("DataStoreService", "GetDataStore", function(_, name)
		if not stores[name] then
			local data = {}
			stores[name] = {
				GetAsync = function(_, key)
					return data[key]
				end,
				SetAsync = function(_, key, value)
					data[key] = value
				end,
				UpdateAsync = function(_, key, transform)
					local result = transform(data[key])
					if result ~= nil then
						data[key] = result
					end
					return data[key]
				end,
				RemoveAsync = function(_, key)
					data[key] = nil
				end,
			}
		end
		return stores[name]
	end)
	roblox.implementMethod("DataStoreService", "GetOrderedDataStore", function()
		return {
			SetAsync = function() end,
			GetSortedAsync = function()
				return { GetCurrentPage = function()
					return {}
				end }
			end,
		}
	end)
	roblox.implementMethod("MarketplaceService", "UserOwnsGamePassAsync", function()
		return false
	end)
	roblox.implementMethod("MarketplaceService", "PromptGamePassPurchase", function() end)
	roblox.implementMethod("MarketplaceService", "PromptProductPurchase", function() end)
	roblox.implementProperty("MarketplaceService", "ProcessReceipt", function()
		return nil
	end, function() end)
	for _, name in { "PromptGamePassPurchaseFinished", "PromptProductPurchaseFinished" } do
		roblox.implementProperty("MarketplaceService", name, function(self)
			return signal(self, name)
		end)
	end
	for _, name in { "PromptTriggered", "PromptButtonHoldBegan", "PromptButtonHoldEnded" } do
		roblox.implementProperty("ProximityPromptService", name, function(self)
			return signal(self, name)
		end)
	end
end

-- Runs a Script (not a ModuleScript) with the runtime environment.
function Mocks.runScript(script)
	local luau = require("@lune/luau")
	local chunk = luau.load(luau.compile(script.Source), {
		debugName = script:GetFullName(),
		environment = Runtime.environmentFor(script),
		injectGlobals = false,
	})
	return chunk()
end

function Mocks.addPlayer(name: string, userId: number)
	local player = roblox.Instance.new("Player")
	player.Name = name
	player.UserId = userId
	player.DisplayName = name
	player.Parent = Runtime.game:GetService("Players")
	table.insert(Mocks.players, player)
	signal(Runtime.game:GetService("Players"), "PlayerAdded"):Fire(player)
	return player
end

function Mocks.removePlayer(player)
	signal(Runtime.game:GetService("Players"), "PlayerRemoving"):Fire(player)
	local index = table.find(Mocks.players, player)
	if index then
		table.remove(Mocks.players, index)
	end
	player.Parent = nil
end

return Mocks
