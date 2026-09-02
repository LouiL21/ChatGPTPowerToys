--!strict
--[[
	FusionService — the Summoning Altar and the shared roll engine.

	Two responsibilities:

	1. SUMMON (the Altar). Spend element shards to call a wild beast. This is the
	   entry point that fills your roster, and the only way brand-new creatures
	   enter the economy.

	2. `rollFromElements` — the weighted rarity roll, exposed so the Fusion
	   Chamber can reuse it for hybrid offspring. One roll implementation means
	   drop rates can never drift between the two systems.

	Roll pipeline (server-authoritative throughout):
	  build the set of beasts eligible for the given elements → weight rarities by
	  base × recipe-bias × luck → pick a rarity → pick a beast within it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local ElementConfig = require(Shared.Config.ElementConfig)
local BeastConfig = require(Shared.Config.BeastConfig)
local RecipeConfig = require(Shared.Config.RecipeConfig)
local BeastInventory = require(Shared.Util.BeastInventory)
local Daily = require(Shared.Util.Daily)
local Logger = require(Shared.Util.Logger).new("Summon")

local ServerNet = require(script.Parent.Parent.ServerNet)

local FusionService = { Name = "FusionService" }
local Registry: any

local _lastSummon: { [number]: number } = {}

local RARITY_INDEX = {}
for i, rarity in ipairs(GameConfig.RARITY_ORDER) do
	RARITY_INDEX[rarity] = i
end

function FusionService:Init(registry)
	Registry = registry
end

local function distinctSet(elements: { string }): { [string]: boolean }
	local set = {}
	for _, id in ipairs(elements) do
		set[id] = true
	end
	return set
end

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

function FusionService:_rollRarity(elements: { string }, eligibleByRarity, luck: number, minRarity: string?): string?
	local bias = RecipeConfig.getBias(elements) or {}
	local floor = minRarity and (RARITY_INDEX[minRarity] or 1) or 1
	local pool: { { rarity: string, weight: number } } = {}
	local total = 0
	for _, rarity in ipairs(GameConfig.RARITY_ORDER) do
		if eligibleByRarity[rarity] and (RARITY_INDEX[rarity] or 1) >= floor then
			local weight = GameConfig.RARITY_BASE_WEIGHTS[rarity] * (bias[rarity] or 1)
			local idx = RARITY_INDEX[rarity]
			if idx >= 3 then -- luck lifts the Rare+ tail only
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
	return pool[#pool].rarity
end

--[[
	The shared roll. Returns the chosen beast config entry, or nil when no beast
	is eligible for the given element set. Used by the Altar (from shards) and by
	the Fusion Chamber (from two parents' combined elements).

	`minRarity` excludes everything below that rarity from the roll. The Chamber
	passes its parents' best rarity so a fusion can never roll you something
	worse than what you fed it; the Altar leaves it nil, since a summon has no
	inputs to be worse than.
]]
function FusionService:rollFromElements(player: Player, elements: { string }, minRarity: string?)
	local inputSet = distinctSet(elements)
	local eligibleByRarity = self:_eligibleByRarity(inputSet)
	local luck = Registry.MonetizationService:getLuck(player)
	-- Today's featured element pays out. This is the only mechanic in the game
	-- that rewards logging in on a PARTICULAR day rather than eventually.
	local featured = Daily.featuredElement()
	if inputSet[featured] then
		luck *= GameConfig.DAILY_FEATURE_LUCK
	end
	local rarity = self:_rollRarity(elements, eligibleByRarity, luck, minRarity)
	if not rarity then
		if minRarity then
			return nil -- caller decides whether to retry unconstrained
		end
		Logger:warn("No eligible beast for", table.concat(elements, "+"))
		return nil
	end
	local candidates = eligibleByRarity[rarity]
	return candidates[math.random(1, #candidates)]
end

--[[
	Every eligible beast for an element set, grouped by rarity.

	The Chamber needs to pick at an EXACT rarity rather than "this or better",
	because its outcome bands decide up front whether a fusion holds the line or
	jumps a tier. Exposed here so eligibility and event gating stay in one place.
]]
function FusionService:eligibleByElements(elements: { string })
	return self:_eligibleByRarity(distinctSet(elements))
end

-- ── The Altar: summon a beast from shards ────────────────────────────────
function FusionService:summon(player: Player, payload)
	local data = Registry.DataService:get(player)
	if not data then
		return
	end
	if typeof(payload) ~= "table" or typeof(payload.elements) ~= "table" then
		return
	end

	local elements = payload.elements
	if #elements < 1 or #elements > 3 then
		ServerNet.notify(player, "Choose 1-3 elements to summon with.", "warn")
		return
	end
	for _, id in ipairs(elements) do
		if typeof(id) ~= "string" or not ElementConfig.exists(id) then
			return -- malformed / spoofed
		end
	end

	local now = os.clock()
	local cooldown = GameConfig.FUSION_BASE_COOLDOWN / Registry.MonetizationService:getFusionSpeed(player)
	if _lastSummon[player.UserId] and (now - _lastSummon[player.UserId]) < cooldown then
		return
	end

	-- Charge shards atomically, then essence; refund shards if essence fails.
	local requirements: { [string]: number } = {}
	for _, id in ipairs(elements) do
		requirements[id] = (requirements[id] or 0) + GameConfig.FUSION_SHARD_COST
	end
	if not Registry.CurrencyService:trySpendShards(player, requirements) then
		ServerNet.notify(player, "Not enough shards to summon.", "warn")
		return
	end
	if not Registry.CurrencyService:trySpend(player, "essence", GameConfig.FUSION_ESSENCE_COST_BASE) then
		for id, amount in pairs(requirements) do
			Registry.CurrencyService:addShards(player, id, amount)
		end
		ServerNet.notify(player, "Not enough essence to summon.", "warn")
		return
	end

	_lastSummon[player.UserId] = now

	local beast = self:rollFromElements(player, elements)
	if not beast then
		-- Nothing eligible: give the inputs back rather than eating them.
		for id, amount in pairs(requirements) do
			Registry.CurrencyService:addShards(player, id, amount)
		end
		Registry.CurrencyService:add(player, "essence", GameConfig.FUSION_ESSENCE_COST_BASE)
		return
	end

	-- Summons always arrive Normal; variants are earned in the Chamber.
	local isNew = BeastInventory.add(data.codex, beast.id, "Normal", 1)
	if isNew then
		data.stats.totalDiscoveries += 1
		if (RARITY_INDEX[beast.rarity] or 0) > (RARITY_INDEX[data.stats.bestRarity] or 0) then
			data.stats.bestRarity = beast.rarity
		end
		local reward = GameConfig.NEW_DISCOVERY_GEM_REWARD[beast.rarity] or 0
		if reward > 0 then
			Registry.CurrencyService:add(player, "gems", reward)
		end
		Registry.QuestService:onDiscovery(player, beast.rarity)
		Registry.AnalyticsService:log(player, "beast_discovered", { id = beast.id, rarity = beast.rarity })
	end

	data.stats.totalSummons += 1
	Registry.QuestService:track(player, "summon", 1)
	if distinctSet(elements).Void then
		Registry.QuestService:track(player, "fuse_void", 1)
	end
	Registry.QuestService:grantAchievement(player, "first_fusion")

	-- A new species auto-joins the sanctuary if there's a free habitat slot.
	if isNew and #data.display < Registry.PlotService:habitatSlots(player) then
		table.insert(data.display, { beastId = beast.id, variant = "Normal" })
		Registry.BeastService:refresh(player)
	end
	-- First beast ever also becomes the active pet, so nobody walks around empty.
	if data.activePet.beastId == "" then
		data.activePet = { beastId = beast.id, variant = "Normal" }
		Registry.PetService:refresh(player)
	end

	Registry.BeastService:playFusionBurst(player, beast.rarity)
	ServerNet.fire(player, "FusionResult", {
		kind = "summon",
		success = true,
		beastId = beast.id,
		variant = "Normal",
		name = beast.name,
		rarity = beast.rarity,
		elements = beast.elements,
		isNew = isNew,
	})
	Registry.StateSync:pushCodex(player)
end

function FusionService:Start()
	ServerNet.onEvent("Fuse", function(player, payload)
		self:summon(player, payload)
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		_lastSummon[player.UserId] = nil
	end)
end

return FusionService
