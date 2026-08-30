--!strict
--[[
	PlotConfig
	Layout and progression data for a player's Sanctuary plot.

	The world is built procedurally from this file — no art assets required — so
	changing the sanctuary layout, the tycoon upgrade ladder, or the island size
	is a config edit, never geometry code.

	Coordinates are PLOT-LOCAL (relative to the plot's centre, +Z toward the
	island rim, -Z toward the hub). PlotBuilder maps them into world space.
]]

local PlotConfig = {}

-- ── Island / plot geometry ────────────────────────────────────────────────
PlotConfig.PLOT_COUNT = 8 -- plots per server (matches a healthy Roblox lobby)
PlotConfig.PLOT_SIZE = 108 -- square plot, studs
PlotConfig.PLOT_RING_RADIUS = 250 -- distance from island centre to plot centre
PlotConfig.HUB_RADIUS = 92 -- central hub disc
PlotConfig.GROUND_Y = 0

PlotConfig.COLORS = {
	hubGround = Color3.fromRGB(58, 48, 92),
	hubTrim = Color3.fromRGB(139, 92, 246),
	plotGround = Color3.fromRGB(64, 92, 62),
	plotRim = Color3.fromRGB(38, 30, 60),
	path = Color3.fromRGB(86, 74, 122),
	water = Color3.fromRGB(38, 86, 140),
	altarStone = Color3.fromRGB(52, 44, 82),
	altarGlow = Color3.fromRGB(167, 139, 250),
	locked = Color3.fromRGB(70, 66, 88),
}

-- ── Element nodes ─────────────────────────────────────────────────────────
-- Physical structures that periodically emit a shard pickup the player runs
-- over. Fire and Water start unlocked so the core loop is available instantly;
-- the rest are tycoon purchases.
PlotConfig.Nodes = {
	{ element = "Fire", offset = Vector3.new(-34, 0, -14), unlockedByDefault = true },
	{ element = "Water", offset = Vector3.new(34, 0, -14), unlockedByDefault = true },
	{ element = "Earth", offset = Vector3.new(-42, 0, 12), unlockedByDefault = false },
	{ element = "Air", offset = Vector3.new(42, 0, 12), unlockedByDefault = false },
	{ element = "Nature", offset = Vector3.new(-26, 0, 34), unlockedByDefault = false },
	{ element = "Void", offset = Vector3.new(26, 0, 34), unlockedByDefault = false },
}

PlotConfig.NODE_BASE_INTERVAL = 6 -- seconds between shard emissions at tier 1
PlotConfig.NODE_TIER_SPEEDUP = 0.78 -- interval multiplier per node tier
PlotConfig.NODE_MAX_TIER = 5

-- ── Landmarks ─────────────────────────────────────────────────────────────
PlotConfig.ALTAR_OFFSET = Vector3.new(0, 0, -34) -- Fusion Altar, back-centre
PlotConfig.SPAWN_OFFSET = Vector3.new(0, 0, 40) -- where the owner is placed
PlotConfig.SIGN_OFFSET = Vector3.new(0, 0, 48) -- nameplate at the plot entrance

-- Beasts wander inside this radius around the habitat centre.
PlotConfig.HABITAT_CENTRE = Vector3.new(0, 0, 4)
PlotConfig.HABITAT_RADIUS = 30

-- ── Pickups ───────────────────────────────────────────────────────────────
PlotConfig.MAX_PICKUPS_PER_PLOT = 28 -- hard cap: keeps part count (and lag) bounded
PlotConfig.PICKUP_LIFETIME = 90 -- seconds before an uncollected pickup despawns
PlotConfig.ESSENCE_ORB_INTERVAL = 9 -- seconds between a beast's essence drops

-- ── Tycoon buy-pads ───────────────────────────────────────────────────────
-- Stepping on a pad charges essence and applies `apply`. Pads are laid out in a
-- row along the plot's front edge; `order` sets left-to-right position.
-- kind: "node" unlocks an element node · "nodeTier" upgrades all nodes
--       "habitat" raises how many beasts can live on the plot
--       "altar" raises the Altar level (fusion power / display slots)
PlotConfig.BuyPads = {
	{ id = "node_earth", order = 1, kind = "node", element = "Earth", cost = 400, label = "Earth Node" },
	{ id = "node_air", order = 2, kind = "node", element = "Air", cost = 1200, label = "Air Node" },
	{ id = "habitat_2", order = 3, kind = "habitat", value = 3, cost = 2500, label = "Habitat +3" },
	{ id = "node_nature", order = 4, kind = "node", element = "Nature", cost = 5000, label = "Nature Node" },
	{ id = "node_tier_2", order = 5, kind = "nodeTier", value = 2, cost = 9000, label = "Node Tier 2" },
	{ id = "habitat_3", order = 6, kind = "habitat", value = 3, cost = 18000, label = "Habitat +3" },
	{ id = "node_void", order = 7, kind = "node", element = "Void", cost = 40000, label = "Void Rift" },
	{ id = "node_tier_3", order = 8, kind = "nodeTier", value = 3, cost = 90000, label = "Node Tier 3" },
	{ id = "habitat_4", order = 9, kind = "habitat", value = 4, cost = 250000, label = "Habitat +4" },
	{ id = "node_tier_4", order = 10, kind = "nodeTier", value = 4, cost = 800000, label = "Node Tier 4" },
}

PlotConfig.PAD_ROW_Z = 44 -- plot-local Z for the buy-pad row
PlotConfig.PAD_SPACING = 11
PlotConfig.BASE_HABITAT_SLOTS = 4 -- beasts that can physically live on the plot

-- ── Rarity → physical presence ────────────────────────────────────────────
-- The core flex: rarity is expressed as SIZE and light, visible across the map.
PlotConfig.RARITY_SCALE = {
	Common = 0.75,
	Uncommon = 0.95,
	Rare = 1.2,
	Epic = 1.5,
	Legendary = 2.0,
	Mythic = 2.8,
	Secret = 3.6,
}

PlotConfig.RARITY_LIGHT = { -- point-light range; 0 = no glow
	Common = 0,
	Uncommon = 0,
	Rare = 6,
	Epic = 10,
	Legendary = 16,
	Mythic = 24,
	Secret = 34,
}

return PlotConfig
