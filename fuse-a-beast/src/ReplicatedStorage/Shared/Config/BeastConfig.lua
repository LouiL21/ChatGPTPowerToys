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

	-- Event-gated example (only rollable during the "Summer Bloom" live event)
	{ id = "sunpetal", name = "Sunpetal", rarity = "Legendary", elements = { "Nature", "Fire" }, event = "summer_bloom" },
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
