--!strict
--[[
	VariantConfig
	Variants are the long-tail progression axis: every beast species can be held
	at an increasingly rare finish, and fusing two of the SAME species at the
	SAME variant is how you climb the ladder.

	This is what makes a duplicate valuable — you never sell a spare, you fuse it.
	It also gives whales and grinders somewhere to go long after the Beastdex is
	complete, without ever adding a pay-to-win stat.
]]

local VariantConfig = {}

export type Variant = {
	id: string,
	displayName: string,
	power: number, -- combat power multiplier
	essence: number, -- sanctuary essence-boost multiplier
	color: Color3, -- tint applied to the creature's aura/trim
	upgradeChance: number, -- odds that fusing two of THIS variant produces the next
	sparkle: boolean, -- adds particle sparkle in-world
}

VariantConfig.Order = { "Normal", "Shiny", "Golden", "Rainbow", "Void" }

VariantConfig.ById = {
	Normal = {
		id = "Normal",
		displayName = "",
		power = 1,
		essence = 1,
		color = Color3.fromRGB(220, 220, 230),
		upgradeChance = 0.50,
		sparkle = false,
	},
	Shiny = {
		id = "Shiny",
		displayName = "Shiny",
		power = 2.5,
		essence = 2,
		color = Color3.fromRGB(150, 230, 255),
		upgradeChance = 0.35,
		sparkle = true,
	},
	Golden = {
		id = "Golden",
		displayName = "Golden",
		power = 6,
		essence = 4,
		color = Color3.fromRGB(255, 196, 77),
		upgradeChance = 0.20,
		sparkle = true,
	},
	Rainbow = {
		id = "Rainbow",
		displayName = "Rainbow",
		power = 15,
		essence = 9,
		color = Color3.fromRGB(255, 120, 200),
		upgradeChance = 0.10,
		sparkle = true,
	},
	Void = {
		id = "Void",
		displayName = "Void",
		power = 40,
		essence = 22,
		color = Color3.fromRGB(150, 80, 255),
		upgradeChance = 0, -- terminal tier
		sparkle = true,
	},
} :: { [string]: Variant }

function VariantConfig.index(variantId: string): number
	return table.find(VariantConfig.Order, variantId) or 1
end

function VariantConfig.next(variantId: string): string?
	local i = VariantConfig.index(variantId)
	return VariantConfig.Order[i + 1]
end

function VariantConfig.get(variantId: string): Variant
	return VariantConfig.ById[variantId] or VariantConfig.ById.Normal
end

-- Display label, e.g. "Golden Solar Phoenix" (Normal adds no prefix).
function VariantConfig.label(variantId: string, beastName: string): string
	local variant = VariantConfig.get(variantId)
	if variant.displayName == "" then
		return beastName
	end
	return variant.displayName .. " " .. beastName
end

return VariantConfig
