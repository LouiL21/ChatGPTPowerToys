--!strict
--[[
	ProfileTemplate
	Canonical schema for a player's saved data. New fields added here are
	back-filled into existing saves via TableUtil.reconcile on load, so schema
	changes never wipe players.

	IMPORTANT: only serializable primitives / tables. No Instances, no functions.
]]

local ElementConfig = require(game:GetService("ReplicatedStorage").Shared.Config.ElementConfig)

local shards = {}
for _, element in ipairs(ElementConfig.List) do
	shards[element.id] = 0
end

local ProfileTemplate = {
	-- Bumped to 2 when beasts became variant-aware (see DataService migrations).
	version = 2,

	currencies = {
		essence = 0, -- soft currency, generated + spent on fusion/upgrades
		gems = 0, -- premium-ish, from quests/discoveries/purchases
	},

	shards = shards, -- { Fire = n, Water = n, ... } consumed by fusion

	altar = {
		level = 1,
	},

	ascension = {
		count = 0, -- number of rebirths
	},

	--[[
		codex: everything you own, keyed by species then VARIANT.
		  entry = { variants = { Normal = 3, Golden = 1 }, discovered = true }
		Duplicates are never dead weight — two of the same species and variant
		fuse into the next variant up, which is the long-tail progression.
	]]
	codex = {} :: { [string]: { variants: { [string]: number }, discovered: boolean } },

	-- Beasts physically living in the Sanctuary: { beastId, variant } pairs.
	display = {} :: { { beastId: string, variant: string } },

	-- The single beast that follows the player and fights in the Arena.
	activePet = { beastId = "", variant = "Normal" },

	battle = {
		wins = 0,
		losses = 0,
		bossesCleared = {} :: { [string]: boolean },
	},

	-- Sanctuary (3D plot) progression, driven by the tycoon buy-pads.
	plot = {
		nodeTier = 1, -- shard emission speed tier for all element nodes
		habitatSlots = 0, -- EXTRA beast slots bought on top of the base allowance
		unlockedNodes = {} :: { [string]: boolean }, -- elementId -> true
		purchasedPads = {} :: { [string]: boolean }, -- padId -> true
	},

	stats = {
		totalFusions = 0,
		totalSummons = 0,
		totalEssenceCollected = 0,
		totalDiscoveries = 0,
		bestRarity = "none",
		joinTimestamp = 0,
	},

	quests = {
		date = "", -- YYYY-MM-DD the daily set was generated for
		active = {} :: { string }, -- ids of today's 3 quests
		progress = {} :: { [string]: number },
		claimed = {} :: { [string]: boolean },
	},

	login = {
		streak = 0,
		lastClaimDate = "", -- YYYY-MM-DD
		vipClaimDate = "", -- YYYY-MM-DD, last VIP daily-gem grant
	},

	-- Processed developer-product receipt ids (idempotency for ProcessReceipt).
	receipts = {} :: { [string]: boolean },

	achievements = {} :: { [string]: boolean },

	-- Cached gamepass ownership. Authoritative check still hits MarketplaceService,
	-- but this lets us restore benefits instantly on join.
	gamepasses = {} :: { [string]: boolean },

	settings = {
		musicEnabled = true,
		sfxEnabled = true,
		lowGraphics = false,
	},

	lastSeen = 0, -- os.time() at last save/leave; drives offline generation
}

return ProfileTemplate
