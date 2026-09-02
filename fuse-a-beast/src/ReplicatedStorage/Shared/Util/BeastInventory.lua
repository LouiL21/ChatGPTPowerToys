--!strict
--[[
	BeastInventory
	Pure helpers over the variant-keyed codex. Every service that touches beast
	ownership goes through here, so counting, adding and removing can't drift
	between the fusion chamber, the sanctuary and the arena.

	Shape:  codex[beastId] = { variants = { [variantId] = count }, discovered = true }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local BeastConfig = require(Shared.Config.BeastConfig)
local VariantConfig = require(Shared.Config.VariantConfig)
local CombatConfig = require(Shared.Config.CombatConfig)

local BeastInventory = {}

function BeastInventory.count(codex, beastId: string, variantId: string): number
	local entry = codex[beastId]
	if not entry then
		return 0
	end
	return entry.variants[variantId] or 0
end

function BeastInventory.totalOf(codex, beastId: string): number
	local entry = codex[beastId]
	if not entry then
		return 0
	end
	local total = 0
	for _, n in pairs(entry.variants) do
		total += n
	end
	return total
end

-- Returns true if this is the first time the species has been seen.
function BeastInventory.add(codex, beastId: string, variantId: string, amount: number?): boolean
	local entry = codex[beastId]
	local isNewSpecies = entry == nil
	if isNewSpecies then
		entry = { variants = {}, discovered = true }
		codex[beastId] = entry
	end
	entry.variants[variantId] = (entry.variants[variantId] or 0) + (amount or 1)
	return isNewSpecies
end

-- Removes `amount`; returns false and changes nothing if the player is short.
function BeastInventory.remove(codex, beastId: string, variantId: string, amount: number): boolean
	local entry = codex[beastId]
	if not entry then
		return false
	end
	local held = entry.variants[variantId] or 0
	if held < amount then
		return false
	end
	local left = held - amount
	entry.variants[variantId] = left > 0 and left or nil
	-- The species stays in the Beastdex once discovered, even at zero held.
	return true
end

function BeastInventory.owns(codex, beastId: string, variantId: string): boolean
	return BeastInventory.count(codex, beastId, variantId) > 0
end

function BeastInventory.speciesCount(codex): number
	local n = 0
	for _ in pairs(codex) do
		n += 1
	end
	return n
end

--[[
	How many distinct species+variant entries are held, and how many exist.

	Species count alone understates the game badly: completing the Beastdex is
	the FIRST goal, not the last one. Every species can be held at five
	variants, so the real collection is five times bigger than the species list
	and cannot be finished in a sitting.
]]
function BeastInventory.variantEntries(codex): number
	local held = 0
	for _, entry in pairs(codex) do
		for _, count in pairs(entry.variants) do
			if count > 0 then
				held += 1
			end
		end
	end
	return held
end

function BeastInventory.variantTotal(): number
	return BeastConfig.count() * #VariantConfig.Order
end

-- ── Derived stats ─────────────────────────────────────────────────────────

function BeastInventory.stats(beastId: string, variantId: string): { power: number, health: number }
	local beast = BeastConfig.ById[beastId]
	if not beast then
		return { power = 0, health = 0 }
	end
	local base = CombatConfig.RarityStats[beast.rarity] or CombatConfig.RarityStats.Common
	local variant = VariantConfig.get(variantId)
	return {
		power = math.floor(base.power * variant.power),
		health = math.floor(base.health * variant.power),
	}
end

-- Strongest owned beast — used to pick a sensible default pet.
function BeastInventory.strongest(codex): (string?, string?)
	local bestId, bestVariant, bestPower = nil, nil, -1
	for beastId, entry in pairs(codex) do
		for variantId, count in pairs(entry.variants) do
			if count > 0 then
				local power = BeastInventory.stats(beastId, variantId).power
				if power > bestPower then
					bestId, bestVariant, bestPower = beastId, variantId, power
				end
			end
		end
	end
	return bestId, bestVariant
end

-- Flat list for UI, sorted strongest first.
function BeastInventory.list(codex): { { beastId: string, variant: string, count: number, power: number } }
	local out = {}
	for beastId, entry in pairs(codex) do
		for variantId, count in pairs(entry.variants) do
			if count > 0 then
				table.insert(out, {
					beastId = beastId,
					variant = variantId,
					count = count,
					power = BeastInventory.stats(beastId, variantId).power,
				})
			end
		end
	end
	table.sort(out, function(a, b)
		return a.power > b.power
	end)
	return out
end

return BeastInventory
