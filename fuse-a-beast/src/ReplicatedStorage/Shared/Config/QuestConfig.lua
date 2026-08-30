--!strict
--[[
	QuestConfig
	Daily quests (rotating) and login-streak rewards. Quests create the
	"unfinished business" hook that drives Day-2 return. Progress is tracked
	server-side against analytics-style event counters.
]]

local QuestConfig = {}

-- Daily quest pool. Each day the server picks 3 at random (seeded by date).
QuestConfig.DailyPool = {
	{ id = "summon_10", desc = "Summon 10 beasts at the Altar", event = "summon", target = 10, reward = { gems = 10 } },
	{ id = "fuse_5", desc = "Fuse 5 beasts in the Chamber", event = "fuse", target = 5, reward = { gems = 15 } },
	{ id = "win_battle_3", desc = "Win 3 Arena battles", event = "win_battle", target = 3, reward = { gems = 20 } },
	{ id = "discover_1_rare", desc = "Discover any Rare+ beast", event = "discover_rare_plus", target = 1, reward = { gems = 20 } },
	{ id = "upgrade_altar_3", desc = "Upgrade your Altar 3 times", event = "upgrade_altar", target = 3, reward = { gems = 15 } },
	{ id = "collect_essence_5k", desc = "Collect 5,000 essence", event = "collect_essence", target = 5000, reward = { gems = 12 } },
	{ id = "display_beast", desc = "Display a beast in your Sanctuary", event = "set_display", target = 1, reward = { gems = 8 } },
	{ id = "fuse_void", desc = "Fuse using the Void element 5 times", event = "fuse_void", target = 5, reward = { gems = 15 } },
	-- NOTE: no "visit another sanctuary" quest until visiting is tracked — a
	-- daily that cannot be completed is worse than one fewer daily.
	{ id = "collect_shards_40", desc = "Collect 40 shards from your nodes", event = "collect_shard", target = 40, reward = { gems = 12 } },
	{ id = "buy_upgrade", desc = "Buy any Sanctuary upgrade", event = "tycoon_purchase", target = 1, reward = { gems = 18 } },
}

-- Login streak (Day 1..7, then loops on Day 7 reward). Escalating value keeps
-- the streak worth protecting.
QuestConfig.LoginStreak = {
	{ day = 1, reward = { essence = 500 } },
	{ day = 2, reward = { gems = 15 } },
	{ day = 3, reward = { essence = 2000 } },
	{ day = 4, reward = { gems = 30 } },
	{ day = 5, reward = { boost = { kind = "luck", mult = 2, seconds = 1800 } } },
	{ day = 6, reward = { gems = 60 } },
	{ day = 7, reward = { gems = 120, essence = 10000 } },
}

-- One-time achievements (also map to Roblox Badges).
QuestConfig.Achievements = {
	{ id = "first_fusion", desc = "Summon your first beast", badgeId = 0 },
	{ id = "first_variant", desc = "Create your first Shiny variant", badgeId = 0 },
	{ id = "first_golden", desc = "Create a Golden variant", badgeId = 0 },
	{ id = "first_rainbow", desc = "Create a Rainbow variant", badgeId = 0 },
	{ id = "first_void_variant", desc = "Create a Void variant — the peak", badgeId = 0 },
	{ id = "first_win", desc = "Win your first Arena battle", badgeId = 0 },
	{ id = "boss_slayer", desc = "Defeat every Arena boss", badgeId = 0 },
	{ id = "first_legendary", desc = "Discover a Legendary beast", badgeId = 0 },
	{ id = "first_mythic", desc = "Discover a Mythic beast", badgeId = 0 },
	{ id = "first_secret", desc = "Discover a Secret beast", badgeId = 0 },
	{ id = "dex_25", desc = "Complete 25 Beastdex entries", badgeId = 0 },
	{ id = "dex_complete", desc = "Complete the entire Beastdex", badgeId = 0 },
	{ id = "first_ascend", desc = "Ascend for the first time", badgeId = 0 },
}

return QuestConfig
