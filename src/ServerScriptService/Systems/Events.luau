--[[
	Tiny internal signals so systems stay independent (no circular requires).
	Handlers run in their own thread: a failing listener never breaks the sender.
]]

local Events = {}

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(handler: (...any) -> ())
	table.insert(self._handlers, handler)
end

function Signal:Fire(...: any)
	for _, handler in self._handlers do
		task.spawn(handler, ...)
	end
end

Events.ProfileLoaded = Signal.new() -- (player)
Events.Collected = Signal.new() -- (player, speciesId, isNew, autoSold)
Events.EquippedChanged = Signal.new() -- (player)
Events.UpgradeChanged = Signal.new() -- (player, upgradeId)
Events.Rebirthed = Signal.new() -- (player, newRebirths)
Events.RoofChanged = Signal.new() -- (player)
Events.StatsChanged = Signal.new() -- (player)

return Events
