--!strict
--[[
	RecipeConfig
	Signature element combinations that bias the rarity roll. This is the
	"discovery meta": players learn (or share) that certain combos are the path
	to Mythic/Secret beasts. Unknown combos still work — they just use base odds.

	A recipe key is the sorted, distinct element ids joined with "+".
	`bias` values MULTIPLY the base rarity weights from GameConfig.RARITY_BASE_WEIGHTS.
]]

local RecipeConfig = {}

-- Canonical key for a set of input elements (order-independent, de-duplicated).
function RecipeConfig.key(elements: { string }): string
	local seen: { [string]: boolean } = {}
	local distinct: { string } = {}
	for _, id in ipairs(elements) do
		if not seen[id] then
			seen[id] = true
			table.insert(distinct, id)
		end
	end
	table.sort(distinct)
	return table.concat(distinct, "+")
end

-- key -> { bias = {rarity = mult}, hint = string }
RecipeConfig.Signatures = {
	["Air+Fire+Void"] = {
		bias = { Legendary = 3, Mythic = 6, Secret = 12 },
		hint = "Chaos and shadow — the Chronodragon sleeps here.",
	},
	["Nature+Void+Water"] = {
		bias = { Legendary = 2.5, Mythic = 5 },
		hint = "Life drowned in shadow.",
	},
	["Air+Fire+Water"] = {
		bias = { Rare = 1.5, Epic = 2, Legendary = 3 },
		hint = "The storm triad.",
	},
	["Earth+Fire+Nature"] = {
		bias = { Legendary = 2.5, Mythic = 4 },
		hint = "The heart of the world.",
	},
	["Void"] = { -- pure void spam (single element) — tiny secret chance for The Null
		bias = { Secret = 4 },
		hint = "Stare long enough into the void...",
	},
}

function RecipeConfig.getBias(elements: { string }): { [string]: number }?
	local sig = RecipeConfig.Signatures[RecipeConfig.key(elements)]
	return sig and sig.bias or nil
end

function RecipeConfig.getHint(elements: { string }): string?
	local sig = RecipeConfig.Signatures[RecipeConfig.key(elements)]
	return sig and sig.hint or nil
end

return RecipeConfig
