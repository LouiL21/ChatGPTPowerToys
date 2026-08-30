--!strict
--[[
	CollectionService
	The Beastdex + Sanctuary. Handles:
	  - SetDisplay: which discovered beasts sit in the Sanctuary (they boost idle
	    essence, closing the collection -> production synergy loop),
	  - Merge: spend duplicate copies to raise a beast's level (bigger display
	    boost) — this is what gives duplicates value even without trading,
	  - Beastdex completion achievements.

	All ownership is validated against the server-side codex; the client can only
	*request* a display/merge, never assert one.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local BeastConfig = require(Shared.Config.BeastConfig)
local TableUtil = require(Shared.Util.TableUtil)

local ServerNet = require(script.Parent.Parent.ServerNet)

local CollectionService = { Name = "CollectionService" }
local Registry: any

local MAX_MERGE_LEVEL = 10
-- Duplicates required to go from level L to L+1.
local function mergeCost(level: number): number
	return level * 3
end

function CollectionService:Init(registry)
	Registry = registry
end

function CollectionService:setDisplay(player: Player, payload)
	local data = Registry.DataService:get(player)
	if not data then
		return
	end
	if typeof(payload) ~= "table" or typeof(payload.beasts) ~= "table" then
		return
	end

	-- Physical habitat capacity is the limit now (tycoon purchases + gamepass).
	local slots = Registry.PlotService:habitatSlots(player)
	local seen: { [string]: boolean } = {}
	local newDisplay: { string } = {}
	for _, beastId in ipairs(payload.beasts) do
		if #newDisplay >= slots then
			break
		end
		-- must be a real, owned, not-yet-listed beast
		if typeof(beastId) == "string" and BeastConfig.ById[beastId] and data.codex[beastId] and not seen[beastId] then
			seen[beastId] = true
			table.insert(newDisplay, beastId)
		end
	end

	data.display = newDisplay
	Registry.QuestService:track(player, "set_display", 1)
	-- Respawn the physical creatures so the sanctuary matches the new roster.
	Registry.BeastService:refresh(player)
	Registry.StateSync:push(player, {
		display = data.display,
		ratePerSecond = Registry.EssenceService:getRate(player),
	})
end

function CollectionService:merge(player: Player, payload)
	local data = Registry.DataService:get(player)
	if not data then
		return
	end
	if typeof(payload) ~= "table" or typeof(payload.beastId) ~= "string" then
		return
	end
	local entry = data.codex[payload.beastId]
	if not entry then
		return
	end
	if entry.level >= MAX_MERGE_LEVEL then
		ServerNet.notify(player, "This beast is already max level.", "warn")
		return
	end
	local cost = mergeCost(entry.level)
	-- Need `cost` duplicates ABOVE the single copy that represents the beast itself.
	if entry.count - 1 < cost then
		ServerNet.notify(player, string.format("Need %d duplicates to merge (have %d).", cost, entry.count - 1), "warn")
		return
	end
	entry.count -= cost
	entry.level += 1
	ServerNet.notify(player, string.format("%s reached level %d!", BeastConfig.ById[payload.beastId].name, entry.level), "success")
	Registry.StateSync:push(player, {
		codex = data.codex,
		ratePerSecond = Registry.EssenceService:getRate(player),
	})
end

-- Called by FusionService on each new discovery to fire completion milestones.
function CollectionService:checkDexMilestones(player: Player, data)
	local discovered = TableUtil.count(data.codex)
	if discovered >= 25 then
		Registry.QuestService:grantAchievement(player, "dex_25")
	end
	if discovered >= BeastConfig.count() then
		Registry.QuestService:grantAchievement(player, "dex_complete")
	end
end

function CollectionService:Start()
	ServerNet.onEvent("SetDisplay", function(player, payload)
		self:setDisplay(player, payload)
	end)
	ServerNet.onEvent("Merge", function(player, payload)
		self:merge(player, payload)
	end)
end

return CollectionService
