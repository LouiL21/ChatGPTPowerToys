--!strict
--[[
	MonetizationConfig
	Gamepasses and developer products. IDs are placeholders (0) — replace with
	real asset IDs from the Creator Hub before publishing (docs/SETUP_GUIDE.md §6).

	The rule everything here obeys: we sell TIME, CONVENIENCE, LUCK and LOOKS.
	We never sell raw combat power or a beast outright. Arena power is derived
	only from what you collected and fused, so a paying player climbs faster but
	can still be beaten by someone with a better collection — which is what keeps
	the competitive layer worth showing up for.

	Structure follows 2026 best practice:
	  - Gamepasses ≈ 60-70% of surface area (permanent, aspirational).
	  - Dev products ≈ 30-40% (repeatable, for engaged spenders).
	  - Barbell pricing: impulse tier (25-99 R$) and saved-up tier (400-1000 R$)
	    convert hardest; the middle band is deliberately thin.
]]

local MonetizationConfig = {}

-- ── Gamepasses (permanent) ────────────────────────────────────────────────
MonetizationConfig.Gamepasses = {
	-- Economy
	DoubleEssence = { id = 0, price = 199, name = "2x Essence", effect = "essenceMultiplier", value = 2,
		blurb = "Every drip, orb and offline payout doubled. Forever." },
	LuckyAura = { id = 0, price = 299, name = "Lucky Aura", effect = "luck", value = 0.5,
		blurb = "+50% odds of rare beasts from every summon." },
	ExtendedOffline = { id = 0, price = 249, name = "24h Offline", effect = "offlineCap", value = true,
		blurb = "Bank a full day of earnings instead of four hours." },

	-- Convenience — these remove chores, not challenge.
	AutoCollect = { id = 0, price = 349, name = "Auto-Collect", effect = "autoCollect", value = true,
		blurb = "Shards and orbs fly to you. No more chasing drops." },
	AutoSummon = { id = 0, price = 449, name = "Auto-Summon", effect = "autoSummon", value = true,
		blurb = "The Altar summons for you while you play." },

	-- Progression breadth
	ExtraSlots = { id = 0, price = 399, name = "+3 Habitat Slots", effect = "displaySlots", value = 3,
		blurb = "Three more beasts living in your sanctuary." },
	ChamberMastery = { id = 0, price = 599, name = "Chamber Mastery", effect = "fusionLuck", value = 1.35,
		blurb = "+35% chance that a variant fusion succeeds." },

	-- Flagship
	VIP = { id = 0, price = 799, name = "VIP", effect = "vip", value = true,
		blurb = "Daily gems, +1 habitat slot, VIP aura, chat tag and free Arena entries." },
}

-- ── Developer products (repeatable) ───────────────────────────────────────
MonetizationConfig.Products = {
	-- Entry tier (impulse)
	EssenceSmall = { id = 0, price = 49, name = "Pouch of Essence", grant = { essence = 5000 } },
	GemsSmall = { id = 0, price = 79, name = "Handful of Gems", grant = { gems = 80 } },
	LuckPotion15 = { id = 0, price = 99, name = "Luck Potion (15m)",
		grant = { boost = { kind = "luck", mult = 2, seconds = 900 } } },

	-- Mid tier
	FusionBoost15 = { id = 0, price = 149, name = "Fusion Frenzy (15m)",
		grant = { boost = { kind = "fusionSpeed", mult = 3, seconds = 900 } } },
	EssenceMedium = { id = 0, price = 199, name = "Chest of Essence", grant = { essence = 30000 } },
	ChamberCharge = { id = 0, price = 249, name = "Chamber Charge (10m)",
		grant = { boost = { kind = "fusionLuck", mult = 2, seconds = 600 } } },

	-- Elite tier (saved-up-for)
	MegaLuck = { id = 0, price = 499, name = "Mega Luck Potion (30m)",
		grant = { boost = { kind = "luck", mult = 4, seconds = 1800 } } },
	GemsLarge = { id = 0, price = 799, name = "Vault of Gems", grant = { gems = 1000 } },
}

-- ── Cosmetics (gem sink — earnable OR buyable, never power) ───────────────
-- Auras are purely visual trails/glows applied to your active pet.
MonetizationConfig.Cosmetics = {
	{ id = "aura_ember", name = "Ember Trail", gems = 150, color = Color3.fromRGB(255, 120, 60) },
	{ id = "aura_frost", name = "Frost Trail", gems = 150, color = Color3.fromRGB(120, 220, 255) },
	{ id = "aura_toxic", name = "Toxic Trail", gems = 300, color = Color3.fromRGB(140, 255, 90) },
	{ id = "aura_void", name = "Void Trail", gems = 750, color = Color3.fromRGB(160, 80, 255) },
	{ id = "aura_prism", name = "Prism Trail", gems = 1500, color = Color3.fromRGB(255, 150, 220) },
}

function MonetizationConfig.getProductByAssetId(assetId: number)
	for key, product in pairs(MonetizationConfig.Products) do
		if product.id == assetId and assetId ~= 0 then
			return key, product
		end
	end
	return nil
end

function MonetizationConfig.getCosmetic(cosmeticId: string)
	for _, cosmetic in ipairs(MonetizationConfig.Cosmetics) do
		if cosmetic.id == cosmeticId then
			return cosmetic
		end
	end
	return nil
end

return MonetizationConfig
