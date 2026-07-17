--!strict
--[[
	BeastConfig
	The Beastdex. Each beast is produced by fusing element shards. A beast is
	eligible for a fusion if ALL of its `elements` tags are present in the set of
	distinct input elements (so a {Fire, Water} beast needs both a Fire and a
	Water input). `rarity` drives display boosts and discovery rewards.

	`event` beasts are only rollable while their live event flag is active
	(see EventConfig / MonetizationService gating).
]]

export type Beast = {
	id: string,
	name: string,
	rarity: string,
	elements: { string },
	event: string?, -- optional event id gating availability
}

local BeastConfig = {}

BeastConfig.List = {
	-- Common ─ single element, the reliable backbone of early progression
	{ id = "emberling", name = "Emberling", rarity = "Common", elements = { "Fire" } },
	{ id = "dewdrop", name = "Dewdrop", rarity = "Common", elements = { "Water" } },
	{ id = "pebblepup", name = "Pebble Pup", rarity = "Common", elements = { "Earth" } },
	{ id = "breezling", name = "Breezling", rarity = "Common", elements = { "Air" } },
	{ id = "sproutkin", name = "Sproutkin", rarity = "Common", elements = { "Nature" } },
	{ id = "dimlet", name = "Dimlet", rarity = "Common", elements = { "Void" } },

	-- Uncommon ─ single element upgrades
	{ id = "cinderfox", name = "Cinderfox", rarity = "Uncommon", elements = { "Fire" } },
	{ id = "tidepup", name = "Tidepup", rarity = "Uncommon", elements = { "Water" } },
	{ id = "boulderbug", name = "Boulderbug", rarity = "Uncommon", elements = { "Earth" } },
	{ id = "gustling", name = "Gustling", rarity = "Uncommon", elements = { "Air" } },
	{ id = "thornhog", name = "Thornhog", rarity = "Uncommon", elements = { "Nature" } },
	{ id = "shademite", name = "Shademite", rarity = "Uncommon", elements = { "Void" } },

	-- Rare ─ two-element pairs
	{ id = "steamserpent", name = "Steam Serpent", rarity = "Rare", elements = { "Fire", "Water" } },
	{ id = "magmole", name = "Magmole", rarity = "Rare", elements = { "Fire", "Earth" } },
	{ id = "lilypadder", name = "Lilypadder", rarity = "Rare", elements = { "Water", "Nature" } },
	{ id = "sparkhawk", name = "Sparkhawk", rarity = "Rare", elements = { "Fire", "Air" } },
	{ id = "mosscrawler", name = "Mosscrawler", rarity = "Rare", elements = { "Earth", "Nature" } },
	{ id = "whispwing", name = "Whispwing", rarity = "Rare", elements = { "Air", "Void" } },

	-- Epic ─ tougher two-element pairs
	{ id = "drownwraith", name = "Drownwraith", rarity = "Epic", elements = { "Water", "Void" } },
	{ id = "rotbloom", name = "Rotbloom", rarity = "Epic", elements = { "Nature", "Void" } },
	{ id = "ashphantom", name = "Ashphantom", rarity = "Epic", elements = { "Fire", "Void" } },
	{ id = "dustgolem", name = "Dustgolem", rarity = "Epic", elements = { "Earth", "Air" } },
	{ id = "mistrider", name = "Mistrider", rarity = "Epic", elements = { "Water", "Air" } },

	-- Legendary ─ three-element beasts
	{ id = "tempestdrake", name = "Tempest Drake", rarity = "Legendary", elements = { "Fire", "Water", "Air" } },
	{ id = "verdanttitan", name = "Verdant Titan", rarity = "Legendary", elements = { "Earth", "Nature", "Water" } },
	{ id = "obsidiancolossus", name = "Obsidian Colossus", rarity = "Legendary", elements = { "Fire", "Earth", "Void" } },
	{ id = "stormghast", name = "Stormghast", rarity = "Legendary", elements = { "Air", "Void", "Water" } },

	-- Mythic ─ signature three-element combos
	{ id = "solarphoenix", name = "Solar Phoenix", rarity = "Mythic", elements = { "Fire", "Air", "Void" } },
	{ id = "eternalleviathan", name = "Eternal Leviathan", rarity = "Mythic", elements = { "Water", "Nature", "Void" } },
	{ id = "worldheart", name = "Worldheart Beast", rarity = "Mythic", elements = { "Earth", "Fire", "Nature" } },

	-- Secret ─ the viral chase. Extremely rare; some are event-gated.
	{ id = "thenull", name = "The Null", rarity = "Secret", elements = { "Void" } },
	{ id = "chronodragon", name = "Chronodragon", rarity = "Secret", elements = { "Air", "Fire", "Void" } },
	{ id = "prisma", name = "Prisma, the Unfused", rarity = "Secret", elements = { "Water", "Nature", "Air" } },

	-- ── Expansion set 1 ──────────────────────────────────────────────────────
	-- Extra Common/Uncommon singles for early-game discovery variety.
	{ id = "bubblet", name = "Bubblet", rarity = "Common", elements = { "Water" } },
	{ id = "clodling", name = "Clodling", rarity = "Common", elements = { "Earth" } },
	{ id = "budling", name = "Budling", rarity = "Common", elements = { "Nature" } },
	{ id = "nullkin", name = "Nullkin", rarity = "Common", elements = { "Void" } },
	{ id = "flareimp", name = "Flare Imp", rarity = "Uncommon", elements = { "Fire" } },
	{ id = "zephling", name = "Zephling", rarity = "Uncommon", elements = { "Air" } },

	-- Fill the remaining element PAIRS (every 2-element combo now has a beast).
	{ id = "wildfirestag", name = "Wildfire Stag", rarity = "Rare", elements = { "Fire", "Nature" } },
	{ id = "mudbackturtle", name = "Mudback Turtle", rarity = "Rare", elements = { "Water", "Earth" } },
	{ id = "pollenwing", name = "Pollenwing", rarity = "Rare", elements = { "Air", "Nature" } },
	{ id = "gravemaw", name = "Gravemaw", rarity = "Epic", elements = { "Earth", "Void" } },

	-- Second beast on several pairs (depth within a combo).
	{ id = "geysereel", name = "Geyser Eel", rarity = "Epic", elements = { "Fire", "Water" } },
	{ id = "nullhawk", name = "Nullhawk", rarity = "Epic", elements = { "Air", "Void" } },
	{ id = "grovewarden", name = "Grovewarden", rarity = "Epic", elements = { "Earth", "Nature" } },
	{ id = "reedray", name = "Reedray", rarity = "Rare", elements = { "Water", "Nature" } },

	-- More Legendary three-element beasts.
	{ id = "primordialgolem", name = "Primordial Golem", rarity = "Legendary", elements = { "Fire", "Water", "Earth" } },
	{ id = "bogfirehydra", name = "Bogfire Hydra", rarity = "Legendary", elements = { "Fire", "Water", "Nature" } },
	{ id = "volcanoroc", name = "Volcano Roc", rarity = "Legendary", elements = { "Fire", "Earth", "Air" } },
	{ id = "monsoonserpent", name = "Monsoon Serpent", rarity = "Legendary", elements = { "Water", "Earth", "Air" } },
	{ id = "canopycolossus", name = "Canopy Colossus", rarity = "Legendary", elements = { "Earth", "Nature", "Air" } },
	{ id = "wildstormelk", name = "Wildstorm Elk", rarity = "Legendary", elements = { "Fire", "Nature", "Air" } },
	{ id = "duststormwraith", name = "Duststorm Wraith", rarity = "Legendary", elements = { "Earth", "Air", "Void" } },
	{ id = "sinkholehorror", name = "Sinkhole Horror", rarity = "Legendary", elements = { "Water", "Earth", "Void" } },
	{ id = "blightflame", name = "Blightflame Beast", rarity = "Legendary", elements = { "Fire", "Nature", "Void" } },

	-- More Mythic beasts.
	{ id = "magmaleviathan", name = "Magma Leviathan", rarity = "Mythic", elements = { "Water", "Earth", "Fire" } },
	{ id = "seraphofcinders", name = "Seraph of Cinders", rarity = "Mythic", elements = { "Nature", "Air", "Fire" } },
	{ id = "abyssalwarden", name = "Abyssal Warden", rarity = "Mythic", elements = { "Earth", "Void", "Water" } },
	{ id = "sporereaper", name = "Spore Reaper", rarity = "Mythic", elements = { "Air", "Nature", "Void" } },

	-- More Secrets (the endgame chase).
	{ id = "aurelion", name = "Aurelion, the First Flame", rarity = "Secret", elements = { "Fire", "Earth", "Air" } },
	{ id = "umbrasovereign", name = "Umbra Sovereign", rarity = "Secret", elements = { "Void", "Nature", "Earth" } },

	-- ── Live-event beasts (only rollable while their event flag is active) ─────
	-- Summer Bloom
	{ id = "sunpetal", name = "Sunpetal", rarity = "Legendary", elements = { "Nature", "Fire" }, event = "summer_bloom" },
	{ id = "blossomsprite", name = "Blossom Sprite", rarity = "Rare", elements = { "Nature", "Water" }, event = "summer_bloom" },
	-- Harvest Moon
	{ id = "pumpkinking", name = "Pumpkin King", rarity = "Legendary", elements = { "Nature", "Void" }, event = "harvest_moon" },
	-- Winter Freeze
	{ id = "frostfangalpha", name = "Frostfang Alpha", rarity = "Secret", elements = { "Water", "Air" }, event = "winter_freeze" },
	-- New Year
	{ id = "fireworksphoenix", name = "Fireworks Phoenix", rarity = "Mythic", elements = { "Fire", "Air" }, event = "new_year" },
}

BeastConfig.ById = {} :: { [string]: any }
BeastConfig.ByRarity = {} :: { [string]: { any } }
for _, beast in ipairs(BeastConfig.List) do
	BeastConfig.ById[beast.id] = beast
	BeastConfig.ByRarity[beast.rarity] = BeastConfig.ByRarity[beast.rarity] or {}
	table.insert(BeastConfig.ByRarity[beast.rarity], beast)
end

function BeastConfig.count(): number
	return #BeastConfig.List
end

return BeastConfig
