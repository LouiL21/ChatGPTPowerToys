--!strict
--[[
	FusionChamberService
	The heart of the game: put TWO beasts you own into the Chamber.

	  Same species + same variant  →  chance to produce ONE of the NEXT variant
	                                  (Normal → Shiny → Golden → Rainbow → Void)
	  Different species            →  a HYBRID: rolls a brand-new beast from the
	                                  two parents' combined elements

	Why this shape works:
	  - Duplicates are never junk. A spare is fuel, so every summon matters.
	  - The variant ladder is effectively endless progression that costs no new
	    content, which keeps players busy between weekly beast drops.
	  - Hybrid fusion reuses the discovery roll, so combining a Fire beast and a
	    Water beast is how you find the Steam Serpent — the Beastdex fills by
	    experimenting with pairs rather than grinding one button.

	Everything is server-authoritative: ownership, the roll and the consume are
	all validated here; the client only nominates two beasts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local BeastConfig = require(Shared.Config.BeastConfig)
local VariantConfig = require(Shared.Config.VariantConfig)
local GameConfig = require(Shared.Config.GameConfig)
local BeastInventory = require(Shared.Util.BeastInventory)

local ServerNet = require(script.Parent.Parent.ServerNet)

local FusionChamberService = { Name = "FusionChamberService" }
local Registry: any

local _lastFuse: { [number]: number } = {}
local FUSE_COOLDOWN = 0.6

function FusionChamberService:Init(registry)
	Registry = registry
end

-- Validates that the payload names two beasts the player actually owns, and
-- that they hold enough copies (two of the SAME entry needs a count of 2).
local function validatePair(data, a, b): boolean
	if typeof(a) ~= "table" or typeof(b) ~= "table" then
		return false
	end
	if typeof(a.beastId) ~= "string" or typeof(b.beastId) ~= "string" then
		return false
	end
	if typeof(a.variant) ~= "string" or typeof(b.variant) ~= "string" then
		return false
	end
	if not BeastConfig.ById[a.beastId] or not BeastConfig.ById[b.beastId] then
		return false
	end
	if not VariantConfig.ById[a.variant] or not VariantConfig.ById[b.variant] then
		return false
	end

	local sameEntry = a.beastId == b.beastId and a.variant == b.variant
	if sameEntry then
		return BeastInventory.count(data.codex, a.beastId, a.variant) >= 2
	end
	return BeastInventory.owns(data.codex, a.beastId, a.variant)
		and BeastInventory.owns(data.codex, b.beastId, b.variant)
end

-- Cost scales with the better parent's variant so late fusions stay meaningful.
function FusionChamberService:costFor(a, b): number
	local tier = math.max(VariantConfig.index(a.variant), VariantConfig.index(b.variant))
	return math.floor(GameConfig.CHAMBER_BASE_COST * GameConfig.CHAMBER_COST_GROWTH ^ (tier - 1))
end

-- Same species + same variant: roll for a variant upgrade.
function FusionChamberService:_variantFuse(player: Player, data, beastId: string, variantId: string)
	local variant = VariantConfig.get(variantId)
	local nextVariant = VariantConfig.next(variantId)

	if not nextVariant then
		ServerNet.notify(player, "Void is the highest variant — nothing to fuse into.", "warn")
		return nil
	end

	BeastInventory.remove(data.codex, beastId, variantId, 2)

	-- Luck can improve the odds but never guarantees the upgrade.
	local chance = math.min(0.95, variant.upgradeChance * Registry.MonetizationService:getFusionLuck(player))
	local success = math.random() < chance
	local resultVariant = success and nextVariant or variantId
	-- On failure you get one back, so a fusion costs one beast rather than two.
	BeastInventory.add(data.codex, beastId, resultVariant, 1)

	if success then
		local ACHIEVEMENT_BY_VARIANT = {
			Shiny = "first_variant",
			Golden = "first_golden",
			Rainbow = "first_rainbow",
			Void = "first_void_variant",
		}
		local achievement = ACHIEVEMENT_BY_VARIANT[resultVariant]
		if achievement then
			Registry.QuestService:grantAchievement(player, achievement)
		end
	end

	local beast = BeastConfig.ById[beastId]
	return {
		kind = "variant",
		success = success,
		beastId = beastId,
		variant = resultVariant,
		name = VariantConfig.label(resultVariant, beast.name),
		rarity = beast.rarity,
		isNew = false,
	}
end

-- Different species: roll a hybrid from the parents' combined elements.
function FusionChamberService:_hybridFuse(player: Player, data, a, b)
	local beastA = BeastConfig.ById[a.beastId]
	local beastB = BeastConfig.ById[b.beastId]

	-- Union of both parents' elements drives which offspring are eligible.
	local elements: { string } = {}
	local seen: { [string]: boolean } = {}
	for _, list in ipairs({ beastA.elements, beastB.elements }) do
		for _, elementId in ipairs(list) do
			if not seen[elementId] then
				seen[elementId] = true
				table.insert(elements, elementId)
			end
		end
	end

	local result = Registry.FusionService:rollFromElements(player, elements)
	if not result then
		ServerNet.notify(player, "These two produced nothing. Try a different pair.", "warn")
		return nil
	end

	BeastInventory.remove(data.codex, a.beastId, a.variant, 1)
	BeastInventory.remove(data.codex, b.beastId, b.variant, 1)

	-- The offspring inherits the LOWER of the two parent variants, so you can't
	-- launder a Golden into a brand-new species for free.
	local inherited = VariantConfig.Order[math.min(VariantConfig.index(a.variant), VariantConfig.index(b.variant))]
	local isNew = BeastInventory.add(data.codex, result.id, inherited, 1)

	if isNew then
		local reward = GameConfig.NEW_DISCOVERY_GEM_REWARD[result.rarity] or 0
		if reward > 0 then
			Registry.CurrencyService:add(player, "gems", reward)
		end
		data.stats.totalDiscoveries += 1
		Registry.QuestService:onDiscovery(player, result.rarity)
		Registry.AnalyticsService:log(player, "beast_discovered", { id = result.id, rarity = result.rarity })
	end

	return {
		kind = "hybrid",
		success = true,
		beastId = result.id,
		variant = inherited,
		name = VariantConfig.label(inherited, result.name),
		rarity = result.rarity,
		isNew = isNew,
	}
end

function FusionChamberService:fuse(player: Player, payload)
	local data = Registry.DataService:get(player)
	if not data then
		return
	end
	if typeof(payload) ~= "table" then
		return
	end

	-- The Chamber is a tycoon unlock, not available from the start.
	if not data.plot.purchasedPads["fusion_chamber"] then
		ServerNet.notify(player, "Build the Fusion Chamber on your plot first!", "warn")
		return
	end

	local now = os.clock()
	if _lastFuse[player.UserId] and now - _lastFuse[player.UserId] < FUSE_COOLDOWN then
		return
	end

	local a, b = payload.a, payload.b
	if not validatePair(data, a, b) then
		ServerNet.notify(player, "You don't own both of those beasts.", "warn")
		return
	end

	local cost = self:costFor(a, b)
	if not Registry.CurrencyService:trySpend(player, "essence", cost) then
		ServerNet.notify(player, "The Chamber needs more essence to run.", "warn")
		return
	end

	_lastFuse[player.UserId] = now

	local sameEntry = a.beastId == b.beastId and a.variant == b.variant
	local result
	if sameEntry then
		result = self:_variantFuse(player, data, a.beastId, a.variant)
	else
		result = self:_hybridFuse(player, data, a, b)
	end

	if not result then
		Registry.CurrencyService:add(player, "essence", cost) -- refund a no-op fusion
		return
	end

	data.stats.totalFusions += 1
	Registry.QuestService:track(player, "fuse", 1)

	-- Prune anything that no longer exists out of the sanctuary / active pet.
	Registry.CollectionService:pruneOwnership(player)

	Registry.BeastService:playFusionBurst(player, result.rarity)
	ServerNet.fire(player, "FusionResult", result)
	Registry.StateSync:pushCodex(player)
	Registry.AnalyticsService:log(player, "chamber_fuse", { kind = result.kind, success = result.success })
end

function FusionChamberService:Start()
	ServerNet.onEvent("ChamberFuse", function(player, payload)
		self:fuse(player, payload)
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		_lastFuse[player.UserId] = nil
	end)
end

return FusionChamberService
