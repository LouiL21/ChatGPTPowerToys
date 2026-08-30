--!strict
--[[
	FusionService
	The core loop and the viral hook: combine element shards to DISCOVER beasts.

	Roll pipeline (fully server-authoritative):
	  1. validate inputs (2-3 valid elements) + charge shards/essence atomically,
	  2. build rarity weights = base * recipe-bias * luck-scaling,
	  3. restrict to rarities that have an ELIGIBLE beast for the input elements
	     (a beast is eligible when all its element tags are present in the inputs,
	     and any event gate is active),
	  4. weighted-pick a rarity, then uniform-pick a beast of that rarity,
	  5. award it; first-time discoveries pay gems + fire achievements + analytics.

	"Discovery" is deliberately loud (FusionResult -> client popup) because
	shareable "I found a Secret!" moments are what drives the growth loop.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local ElementConfig = require(Shared.Config.ElementConfig)
local BeastConfig = require(Shared.Config.BeastConfig)
local RecipeConfig = require(Shared.Config.RecipeConfig)
local Logger = require(Shared.Util.Logger).new("Fusion")

local ServerNet = require(script.Parent.Parent.ServerNet)

local FusionService = { Name = "FusionService" }
local Registry: any

local _lastFuse: { [number]: number } = {} -- session cooldown tracking

local RARITY_INDEX = {}
for i, rarity in ipairs(GameConfig.RARITY_ORDER) do
	RARITY_INDEX[rarity] = i
end

function FusionService:Init(registry)
	Registry = registry
end

-- Distinct element set of the inputs (order-independent).
local function distinctSet(elements: { string }): { [string]: boolean }
	local set = {}
	for _, id in ipairs(elements) do
		set[id] = true
	end
	return set
end

-- Is `beast` producible from this input element set + current event state?
function FusionService:_eligible(beast, inputSet: { [string]: boolean }): boolean
	if beast.event and not Registry.MonetizationService:isEventActive(beast.event) then
		return false
	end
	for _, tag in ipairs(beast.elements) do
		if not inputSet[tag] then
			return false
		end
	end
	return true
end

-- Build { rarity -> {eligible beasts} } for the input set.
function FusionService:_eligibleByRarity(inputSet)
	local byRarity: { [string]: { any } } = {}
	for _, beast in ipairs(BeastConfig.List) do
		if self:_eligible(beast, inputSet) then
			byRarity[beast.rarity] = byRarity[beast.rarity] or {}
			table.insert(byRarity[beast.rarity], beast)
		end
	end
	return byRarity
end

-- Weighted rarity roll restricted to rarities that actually have an eligible beast.
function FusionService:_rollRarity(elements: { string }, eligibleByRarity, luck: number): string?
	local bias = RecipeConfig.getBias(elements) or {}
	local pool: { { rarity: string, weight: number } } = {}
	local total = 0
	for _, rarity in ipairs(GameConfig.RARITY_ORDER) do
		if eligibleByRarity[rarity] then
			local weight = GameConfig.RARITY_BASE_WEIGHTS[rarity] * (bias[rarity] or 1)
			-- Luck lifts the rare tail. Index 1=Common (no lift) up to Secret.
			local idx = RARITY_INDEX[rarity]
			if idx >= 3 then -- Rare and above
				weight *= luck ^ (idx - 2)
			end
			pool[#pool + 1] = { rarity = rarity, weight = weight }
			total += weight
		end
	end
	if total <= 0 then
		return nil
	end
	local roll = math.random() * total
	local cumulative = 0
	for _, entry in ipairs(pool) do
		cumulative += entry.weight
		if roll <= cumulative then
			return entry.rarity
		end
	end
	return pool[#pool].rarity -- float safety
end

function FusionService:_award(player: Player, data, beast)
	local entry = data.codex[beast.id]
	local isNew = entry == nil
	if isNew then
		entry = { count = 0, level = 1 }
		data.codex[beast.id] = entry
		data.stats.totalDiscoveries += 1
		if (RARITY_INDEX[beast.rarity] or 0) > (RARITY_INDEX[data.stats.bestRarity] or 0) then
			data.stats.bestRarity = beast.rarity
		end
	end
	entry.count += 1

	if isNew then
		local gemReward = GameConfig.NEW_DISCOVERY_GEM_REWARD[beast.rarity] or 0
		if gemReward > 0 then
			Registry.CurrencyService:add(player, "gems", gemReward)
		end
		Registry.QuestService:onDiscovery(player, beast.rarity)
		Registry.AnalyticsService:log(player, "beast_discovered", { id = beast.id, rarity = beast.rarity })
	end
	return isNew
end

function FusionService:fuse(player: Player, payload)
	local data = Registry.DataService:get(player)
	if not data then
		return
	end

	-- Validate payload shape: { elements = {id, id[, id]} }
	if typeof(payload) ~= "table" or typeof(payload.elements) ~= "table" then
		return
	end
	local elements = payload.elements
	local count = #elements
	if count < 2 or count > 3 then
		ServerNet.notify(player, "Select 2 or 3 elements to fuse.", "warn")
		return
	end
	for _, id in ipairs(elements) do
		if typeof(id) ~= "string" or not ElementConfig.exists(id) then
			return -- malformed / spoofed input
		end
	end

	-- Server cooldown (boosts can shorten it). Rate limiter is the hard cap.
	local now = os.clock()
	local cooldown = GameConfig.FUSION_BASE_COOLDOWN / Registry.MonetizationService:getFusionSpeed(player)
	if _lastFuse[player.UserId] and (now - _lastFuse[player.UserId]) < cooldown then
		return
	end

	-- Build shard requirements (per element, summing duplicates).
	local requirements: { [string]: number } = {}
	for _, id in ipairs(elements) do
		requirements[id] = (requirements[id] or 0) + GameConfig.FUSION_SHARD_COST
	end

	-- Charge shards atomically, then essence. Refund shards if essence fails.
	if not Registry.CurrencyService:trySpendShards(player, requirements) then
		ServerNet.notify(player, "Not enough shards for this fusion.", "warn")
		return
	end
	if not Registry.CurrencyService:trySpend(player, "essence", GameConfig.FUSION_ESSENCE_COST_BASE) then
		for id, amount in pairs(requirements) do
			Registry.CurrencyService:addShards(player, id, amount) -- refund
		end
		ServerNet.notify(player, "Not enough essence for this fusion.", "warn")
		return
	end

	_lastFuse[player.UserId] = now

	-- Roll.
	local inputSet = distinctSet(elements)
	local eligibleByRarity = self:_eligibleByRarity(inputSet)
	local luck = Registry.MonetizationService:getLuck(player)
	local rarity = self:_rollRarity(elements, eligibleByRarity, luck)
	if not rarity then
		Logger:warn("No eligible beast for inputs", table.concat(elements, "+"))
		return
	end
	local candidates = eligibleByRarity[rarity]
	local beast = candidates[math.random(1, #candidates)]

	-- Award + stats.
	local isNew = self:_award(player, data, beast)
	data.stats.totalFusions += 1
	Registry.QuestService:track(player, "fuse", 1)
	if inputSet.Void then
		Registry.QuestService:track(player, "fuse_void", 1)
	end
	Registry.QuestService:grantAchievement(player, "first_fusion")

	-- Fire the physical altar burst so the moment happens in the world, not just
	-- in the UI.
	Registry.BeastService:playFusionBurst(player, beast.rarity)

	-- A brand-new beast auto-joins the sanctuary if there's a free habitat slot,
	-- so a player's first discoveries physically appear without a menu detour.
	if isNew and #data.display < Registry.PlotService:habitatSlots(player) then
		table.insert(data.display, beast.id)
		Registry.BeastService:refresh(player)
	end

	-- Replicate result (loud, for the discovery popup) + codex.
	ServerNet.fire(player, "FusionResult", {
		beastId = beast.id,
		name = beast.name,
		rarity = beast.rarity,
		elements = beast.elements,
		isNew = isNew,
	})
	Registry.StateSync:pushCodex(player)
end

function FusionService:Start()
	ServerNet.onEvent("Fuse", function(player, payload)
		self:fuse(player, payload)
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		_lastFuse[player.UserId] = nil
	end)
end

return FusionService
