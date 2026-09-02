--!strict
--[[
	GameConfig
	Global tunables for Fuse a Beast. Everything the design/economy touches lives
	in Config/ so balancing never requires editing gameplay code.
]]

local GameConfig = {}

-- ── Core economy ──────────────────────────────────────────────────────────
GameConfig.BASE_ESSENCE_PER_SECOND = 1.0 -- Altar level 1 generation rate
GameConfig.ALTAR_RATE_GROWTH = 1.18 -- multiplier per Altar level
GameConfig.ALTAR_UPGRADE_BASE_COST = 100 -- essence cost for level 2
GameConfig.ALTAR_UPGRADE_COST_GROWTH = 1.55 -- cost multiplier per level
GameConfig.MAX_ALTAR_LEVEL = 250

-- Shard generation (the Altar drips element shards used by fusion).
GameConfig.SHARD_BASE_PER_SECOND = 0.4 -- shards/sec at altar level 1
GameConfig.SHARD_ALTAR_GROWTH = 1.10 -- shard rate multiplier per altar level
GameConfig.GENERATION_TICK = 5 -- seconds between server generation ticks
GameConfig.COLLECT_TAP_SECONDS = 1.5 -- essence granted per manual Altar tap (in seconds of rate)

-- Displayed beasts passively boost generation (idle synergy loop).
GameConfig.DISPLAY_SLOT_BASE = 3
GameConfig.DISPLAY_BOOST_PER_RARITY = { -- % additive essence boost per displayed beast
	Common = 0.02,
	Uncommon = 0.05,
	Rare = 0.10,
	Epic = 0.20,
	Legendary = 0.45,
	Mythic = 1.00,
	Secret = 2.50,
}

-- ── Offline generation ────────────────────────────────────────────────────
GameConfig.OFFLINE_CAP_SECONDS = 4 * 60 * 60 -- 4h default cap
GameConfig.OFFLINE_CAP_SECONDS_GAMEPASS = 24 * 60 * 60 -- with "Extended Offline" pass
GameConfig.OFFLINE_EFFICIENCY = 0.5 -- offline earns 50% of online rate (keeps active play valuable)

-- ── Fusion ────────────────────────────────────────────────────────────────
GameConfig.FUSION_SHARD_COST = 10 -- shards consumed per element input
GameConfig.FUSION_ESSENCE_COST_BASE = 25 -- essence per fusion at altar level 1
GameConfig.FUSION_BASE_COOLDOWN = 2.0 -- seconds between manual fusions (anti-spam, gameplay pacing)

-- Fusion Chamber: combining two owned beasts. Cost scales with the better
-- parent's variant so late-game fusions stay a real decision.
GameConfig.CHAMBER_BASE_COST = 500
GameConfig.CHAMBER_COST_GROWTH = 4.2

--[[
	Hybrid fusion outcome bands.

	The Chamber never returns a downgrade, so these decide how much BETTER the
	offspring is: how many rarity tiers it lands above the better parent's.
	Most fusions hold the line, which is what keeps the rare jump exciting —
	if every fusion were an upgrade there would be nothing to chase.

	Chamber luck (the Chamber Mastery pass, fusion-luck boosts) shifts weight
	out of `same` and into the two upgrade bands, clamped so an upgrade is never
	more likely than not.
]]
GameConfig.CHAMBER_OUTCOME = {
	same = 0.70, -- matches the better parent's rarity
	slightly = 0.20, -- one rarity tier up
	better = 0.10, -- two rarity tiers up
}
GameConfig.CHAMBER_MAX_UPGRADE_CHANCE = 0.6 -- ceiling on slightly + better after luck

--[[
	Per-tier override of those odds — and the single most important table in the
	game's pacing.

	A FLAT 70/20/10 across every tier is an escalator, not a chase. Expected gain
	is 0.4 tiers per fusion, so Common to Secret is about fifteen fusions and a
	player finishes the entire Beastdex inside an hour. Worse, two Mythics had a
	30% chance of producing a Secret, which is meant to be the rarest thing in
	the game.

	So the generosity is front-loaded: the early tiers keep the feel of 70/20/10
	because that is where a new player needs momentum, and the top tightens hard
	until Mythic to Secret is a genuine grind. Indexed by the BETTER PARENT's
	rarity index (1 = Common ... 7 = Secret).

	Expected fusions to climb one tier: ~2 at Common, ~4 at Rare, ~13 at
	Legendary, ~65 at Mythic — and each of those consumes two beasts of that
	tier, so the real cost compounds well beyond the ratio.
]]
GameConfig.CHAMBER_UPGRADE_BY_TIER = {
	[1] = { slightly = 0.34, better = 0.12 }, -- Common
	[2] = { slightly = 0.28, better = 0.09 }, -- Uncommon
	[3] = { slightly = 0.20, better = 0.05 }, -- Rare
	[4] = { slightly = 0.11, better = 0.02 }, -- Epic
	[5] = { slightly = 0.06, better = 0.004 }, -- Legendary
	[6] = { slightly = 0.015, better = 0 }, -- Mythic → Secret is the endgame chase
	[7] = { slightly = 0, better = 0 }, -- Secret: nowhere left to climb
}

-- Summons including the day's featured element roll on this much extra luck.
GameConfig.DAILY_FEATURE_LUCK = 2.5
GameConfig.NEW_DISCOVERY_GEM_REWARD = { -- gems granted the FIRST time a rarity is discovered
	Common = 1,
	Uncommon = 2,
	Rare = 5,
	Epic = 15,
	Legendary = 50,
	Mythic = 150,
	Secret = 500,
}

-- ── Rebirth / Ascension ───────────────────────────────────────────────────
GameConfig.ASCENSION_ALTAR_REQUIREMENT = 50 -- min altar level to first ascend
GameConfig.ASCENSION_MULT_PER_LEVEL = 0.25 -- +25% permanent essence per ascension
GameConfig.ASCENSION_COST_GROWTH = 2.0

-- ── Luck (drives rarity roll) ─────────────────────────────────────────────
GameConfig.BASE_LUCK = 1.0
GameConfig.LUCKY_GAMEPASS_BONUS = 0.5 -- +50% luck
GameConfig.PREMIUM_LUCK_BONUS = 0.15 -- Roblox Premium members

-- ── Retention ─────────────────────────────────────────────────────────────
GameConfig.DAILY_STREAK_MAX = 7
GameConfig.AUTOSAVE_INTERVAL = 60 -- seconds

-- ── Anti-exploit ──────────────────────────────────────────────────────────
GameConfig.REMOTE_RATE_LIMITS = { -- max calls per window (seconds)
	Fuse = { max = 8, window = 1 },
	ChamberFuse = { max = 6, window = 1 },
	SetPet = { max = 6, window = 1 },
	FightBoss = { max = 3, window = 5 },
	ChallengePlayer = { max = 3, window = 5 },
	RespondDuel = { max = 5, window = 5 },
	BuyCosmetic = { max = 4, window = 2 },
	UpgradeAltar = { max = 5, window = 1 },
	SetDisplay = { max = 10, window = 1 },
	ClaimDaily = { max = 3, window = 5 },
	Ascend = { max = 2, window = 5 },
	RequestTrade = { max = 5, window = 5 },
	Collect = { max = 20, window = 1 },
	TutorialSeen = { max = 2, window = 5 },
}

-- ── Rarity table (weights are BEFORE luck/recipe modifiers) ───────────────
GameConfig.RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }
GameConfig.RARITY_BASE_WEIGHTS = {
	Common = 1000,
	Uncommon = 420,
	Rare = 150,
	Epic = 40,
	Legendary = 8,
	Mythic = 1.2,
	Secret = 0.08,
}

return GameConfig
