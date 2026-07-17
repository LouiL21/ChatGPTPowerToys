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
	version = 1,

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

	-- codex: discovered beasts. entry = { count = n, level = n }
	-- `count` = duplicates owned; `level` = merge level (raises display boost).
	codex = {} :: { [string]: { count: number, level: number } },

	-- ordered list of beast ids currently displayed in the Sanctuary
	display = {} :: { string },

	stats = {
		totalFusions = 0,
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
