--[[
	Server-wide excitement: banners when something rare appears / is collected, plus the
	"Recent Finds" board in the plaza. Rate limited so a lucky streak can't spam the screen.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage.Modules
local RarityConfig = require(Modules.RarityConfig)

local Remotes = require(ReplicatedStorage.Remotes)

local AnnounceSystem = {}

local MIN_SECONDS_BETWEEN = 2.5
local lastTime = 0
local lastRank = 0

local recentLabels: { TextLabel } = {}
local recentEntries: { string } = {}

function AnnounceSystem.setRecentLabels(labels: { TextLabel })
	recentLabels = labels
end

local function allow(rank: number): boolean
	local now = os.clock()
	if now - lastTime < MIN_SECONDS_BETWEEN and rank <= lastRank then
		return false
	end
	lastTime = now
	lastRank = rank
	return true
end

local function pushRecent(player: Player, rarityId: string, name: string)
	local definition = RarityConfig.ById[rarityId]
	local color = if definition.Hidden then definition.Accent else definition.Color
	local entry = string.format('<font color="#%s">● %s</font>  %s  <font color="#9a9ab0">— %s</font>', color:ToHex(), definition.Name, name, player.DisplayName)
	table.insert(recentEntries, 1, entry)
	while #recentEntries > #recentLabels do
		table.remove(recentEntries)
	end
	for index, label in recentLabels do
		label.Text = recentEntries[index] or "—"
	end
end

-- A rare hamster started running for `player`.
function AnnounceSystem.rareSpawn(player: Player, species: any)
	local definition = RarityConfig.ById[species.Rarity]
	if definition.Announce < 2 or not allow(definition.Rank) then
		return
	end
	Remotes.event("Announce"):FireAllClients({
		Kind = "Spawn",
		RarityId = species.Rarity,
		UserId = player.UserId,
		PlayerName = player.DisplayName,
		Text = string.format("A %s HAMSTER HAS APPEARED!", string.upper(definition.Name)),
	})
end

-- Somebody collected a rare hamster.
function AnnounceSystem.rareCollected(player: Player, species: any, isNew: boolean)
	local definition = RarityConfig.ById[species.Rarity]
	if definition.Rank >= 7 then
		local shownName = if definition.Hidden and not isNew then "???" else species.Name
		pushRecent(player, species.Rarity, shownName)
	end
	if definition.Rank >= 8 and allow(definition.Rank + 0.5) then
		Remotes.event("Announce"):FireAllClients({
			Kind = "Collect",
			RarityId = species.Rarity,
			UserId = player.UserId,
			PlayerName = player.DisplayName,
			SpeciesId = species.Id,
			Text = string.format("%s collected a %s hamster!", player.DisplayName, string.upper(definition.Name)),
		})
	end
end

function AnnounceSystem.rebirth(player: Player, count: number)
	if count >= 3 and allow(1) then
		Remotes.event("Announce"):FireAllClients({
			Kind = "Rebirth",
			RarityId = "Legendary",
			UserId = player.UserId,
			PlayerName = player.DisplayName,
			Text = string.format("%s reached Rebirth %d!", player.DisplayName, count),
		})
	end
end

return AnnounceSystem
