--!strict
--[[
	MonetizationConfig
	Central registry of gamepasses and developer products. IDs are placeholders
	(0) — replace with real asset IDs from the Creator Hub before publishing.

	Design follows 2026 best practice:
	  - Gamepasses = ~60-70% of surface area (aspirational, permanent).
	  - Dev products = ~30-40% (repeatable, for engaged spenders).
	  - Pricing ladder: entry (25-99 R$) and elite (400-1000 R$) tiers convert
	    hardest; mid-band is intentionally thin.
	  - Everything sold is a MULTIPLIER, CONVENIENCE, or COSMETIC — never a
	    pay-to-win stat that breaks the trading economy.
]]

local MonetizationConfig = {}

-- ── Gamepasses (permanent) ────────────────────────────────────────────────
MonetizationConfig.Gamepasses = {
	DoubleEssence = { id = 0, price = 199, name = "2x Essence", effect = "essenceMultiplier", value = 2 },
	AutoFuse = { id = 0, price = 349, name = "Auto-Fuse", effect = "autoFuse", value = true },
	LuckyAura = { id = 0, price = 299, name = "Lucky Aura", effect = "luck", value = 0.5 },
	ExtendedOffline = { id = 0, price = 249, name = "24h Offline", effect = "offlineCap", value = true },
	ExtraSlots = { id = 0, price = 399, name = "+3 Display Slots", effect = "displaySlots", value = 3 },
	VIP = { id = 0, price = 799, name = "VIP", effect = "vip", value = true }, -- daily gems, chat tag, VIP zone, +1 trade slot
}

-- ── Developer products (repeatable) ───────────────────────────────────────
MonetizationConfig.Products = {
	-- entry tier (impulse)
	EssenceSmall = { id = 0, price = 49, name = "Pouch of Essence", grant = { essence = 5000 } },
	GemsSmall = { id = 0, price = 79, name = "Handful of Gems", grant = { gems = 80 } },
	LuckPotion15 = { id = 0, price = 99, name = "Luck Potion (15m)", grant = { boost = { kind = "luck", mult = 2, seconds = 900 } } },
	-- mid tier
	EssenceMedium = { id = 0, price = 199, name = "Chest of Essence", grant = { essence = 30000 } },
	FusionBoost15 = { id = 0, price = 149, name = "Fusion Frenzy (15m)", grant = { boost = { kind = "fusionSpeed", mult = 3, seconds = 900 } } },
	-- elite tier (saved-up-for)
	GemsLarge = { id = 0, price = 799, name = "Vault of Gems", grant = { gems = 1000 } },
	MegaLuck = { id = 0, price = 499, name = "Mega Luck Potion (30m)", grant = { boost = { kind = "luck", mult = 4, seconds = 1800 } } },
}

-- Fast lookup: assetId -> product key (built lazily so 0-placeholders don't collide).
function MonetizationConfig.getProductByAssetId(assetId: number)
	for key, product in pairs(MonetizationConfig.Products) do
		if product.id == assetId and assetId ~= 0 then
			return key, product
		end
	end
	return nil
end

return MonetizationConfig
