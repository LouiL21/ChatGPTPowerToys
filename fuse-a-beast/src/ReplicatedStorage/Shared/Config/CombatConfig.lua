--!strict
--[[
	CombatConfig
	Arena battling. Power is DERIVED from what a player already collected
	(rarity × variant), never bought — so battling rewards the collection loop
	instead of the wallet. The shop sells cosmetics, entries and boosts; it never
	sells raw combat power.

	Battles are short auto-resolved exchanges: both beasts trade blows on a timer
	until one drops. Short enough to watch, long enough to feel tense.
]]

local CombatConfig = {}

-- Base combat stats by rarity. Variant multiplies these (see VariantConfig).
CombatConfig.RarityStats = {
	Common = { power = 10, health = 100 },
	Uncommon = { power = 18, health = 150 },
	Rare = { power = 34, health = 240 },
	Epic = { power = 62, health = 400 },
	Legendary = { power = 120, health = 700 },
	Mythic = { power = 240, health = 1300 },
	Secret = { power = 520, health = 2600 },
}

CombatConfig.TURN_INTERVAL = 0.85 -- seconds between exchanges
CombatConfig.MAX_TURNS = 30 -- draw guard so a battle always terminates
CombatConfig.CRIT_CHANCE = 0.18
CombatConfig.CRIT_MULTIPLIER = 1.8
CombatConfig.DAMAGE_VARIANCE = 0.22 -- +/- roll on each hit, keeps upsets possible

-- Element advantage: attacker's element beats defender's for bonus damage.
-- A rock-paper-scissors ring plus two wildcards keeps team-building meaningful.
CombatConfig.ADVANTAGE_BONUS = 1.35
CombatConfig.Advantage = {
	Fire = "Nature",
	Nature = "Earth",
	Earth = "Air",
	Air = "Water",
	Water = "Fire",
	Void = "Void", -- Void is neutral: never strong, never weak
}

-- ── Boss ladder (PvE, always available so solo players can battle) ────────
CombatConfig.Bosses = {
	{ id = "clay_sentinel", name = "Clay Sentinel", power = 26, health = 260, element = "Earth", reward = { gems = 8, essence = 1500 } },
	{ id = "tide_warden", name = "Tide Warden", power = 70, health = 620, element = "Water", reward = { gems = 18, essence = 9000 } },
	{ id = "ashen_maw", name = "Ashen Maw", power = 160, health = 1500, element = "Fire", reward = { gems = 40, essence = 60000 } },
	{ id = "storm_herald", name = "Storm Herald", power = 380, health = 3400, element = "Air", reward = { gems = 90, essence = 400000 } },
	{ id = "the_hollow", name = "The Hollow", power = 900, health = 8000, element = "Void", reward = { gems = 220, essence = 3000000 } },
}

CombatConfig.BOSS_COOLDOWN = 60 -- seconds between boss attempts
CombatConfig.PVP_COOLDOWN = 20 -- seconds between duel challenges
CombatConfig.PVP_WIN_REWARD = { gems = 12 }
CombatConfig.PVP_LOSS_REWARD = { gems = 2 } -- losing still pays a little: no dead ends

return CombatConfig
