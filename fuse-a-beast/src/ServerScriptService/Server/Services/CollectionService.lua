--!strict
--[[
	CollectionService
	The Beastdex and the Sanctuary roster.

	Since the Fusion Chamber consumes beasts, this service also owns
	`pruneOwnership` — the sweep that removes anything from the sanctuary or the
	active-pet slot once the player no longer holds a copy. Every path that
	destroys a beast calls it, so the world can never show a creature you sold
	off to a fusion.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local BeastConfig = require(Shared.Config.BeastConfig)
local VariantConfig = require(Shared.Config.VariantConfig)
local BeastInventory = require(Shared.Util.BeastInventory)

local ServerNet = require(script.Parent.Parent.ServerNet)

local CollectionService = { Name = "CollectionService" }
local Registry: any

function CollectionService:Init(registry)
	Registry = registry
end

--[[
	Choose which owned beasts physically live in the sanctuary.
	payload.beasts = { { beastId = "...", variant = "..." }, ... }

	Capacity is the plot's habitat size, and a given (species, variant) can only
	be displayed as many times as the player actually owns.
]]
function CollectionService:setDisplay(player: Player, payload)
	local data = Registry.DataService:get(player)
	if not data then
		return
	end
	if typeof(payload) ~= "table" or typeof(payload.beasts) ~= "table" then
		return
	end

	local slots = Registry.PlotService:habitatSlots(player)
	local used: { [string]: number } = {}
	local newDisplay = {}

	for _, item in ipairs(payload.beasts) do
		if #newDisplay >= slots then
			break
		end
		if
			typeof(item) == "table"
			and typeof(item.beastId) == "string"
			and typeof(item.variant) == "string"
			and BeastConfig.ById[item.beastId]
			and VariantConfig.ById[item.variant]
		then
			local key = item.beastId .. "|" .. item.variant
			local owned = BeastInventory.count(data.codex, item.beastId, item.variant)
			local alreadyPlaced = used[key] or 0
			if alreadyPlaced < owned then
				used[key] = alreadyPlaced + 1
				table.insert(newDisplay, { beastId = item.beastId, variant = item.variant })
			end
		end
	end

	data.display = newDisplay
	Registry.QuestService:track(player, "set_display", 1)
	Registry.BeastService:refresh(player)
	Registry.StateSync:push(player, {
		display = data.display,
		ratePerSecond = Registry.EssenceService:getRate(player),
	})
end

--[[
	Drops anything the player no longer owns out of the sanctuary and the pet
	slot. Called after every fusion, since fusing consumes copies.
]]
function CollectionService:pruneOwnership(player: Player)
	local data = Registry.DataService:get(player)
	if not data then
		return
	end

	local used: { [string]: number } = {}
	local kept = {}
	for _, item in ipairs(data.display) do
		local key = item.beastId .. "|" .. item.variant
		local owned = BeastInventory.count(data.codex, item.beastId, item.variant)
		local placed = used[key] or 0
		if placed < owned then
			used[key] = placed + 1
			table.insert(kept, item)
		end
	end

	local displayChanged = #kept ~= #data.display
	data.display = kept

	local pet = data.activePet
	local petLost = pet.beastId ~= "" and not BeastInventory.owns(data.codex, pet.beastId, pet.variant)

	if displayChanged then
		Registry.BeastService:refresh(player)
	end
	if petLost then
		-- refresh() falls back to the strongest remaining beast on its own.
		data.activePet = { beastId = "", variant = "Normal" }
		Registry.PetService:refresh(player)
	end
end

-- Auto-place a newly acquired beast if the sanctuary has room.
function CollectionService:tryAutoDisplay(player: Player, beastId: string, variant: string)
	local data = Registry.DataService:get(player)
	if not data then
		return
	end
	if #data.display >= Registry.PlotService:habitatSlots(player) then
		return
	end
	table.insert(data.display, { beastId = beastId, variant = variant })
	Registry.BeastService:refresh(player)
end

function CollectionService:checkDexMilestones(player: Player, data)
	local discovered = BeastInventory.speciesCount(data.codex)
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
end

return CollectionService
