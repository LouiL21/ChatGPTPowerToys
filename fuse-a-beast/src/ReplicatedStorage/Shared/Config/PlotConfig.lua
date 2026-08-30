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
	affordable = Color3.fromRGB(255, 196, 77), -- pad you can buy RIGHT NOW
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
PlotConfig.ALTAR_OFFSET = Vector3.new(0, 0, -34) -- Summoning Altar, back-centre
PlotConfig.CHAMBER_OFFSET = Vector3.new(-40, 0, -34) -- Fusion Chamber, back-left
PlotConfig.SPAWN_OFFSET = Vector3.new(0, 0, 40) -- where the owner is placed
PlotConfig.SIGN_OFFSET = Vector3.new(0, 0, 48) -- nameplate at the plot entrance

-- Beasts wander inside this radius around the habitat centre. The radius has to
-- grow with the slot count or a full sanctuary reads as a pile rather than a
-- collection you can walk through.
PlotConfig.HABITAT_CENTRE = Vector3.new(0, 0, 2)
PlotConfig.HABITAT_RADIUS = 36

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
-- kind "building" reveals a structure (currently the Fusion Chamber).
--
-- Ordering rule: the Chamber is pad ONE and deliberately cheap. Fusing two
-- beasts is the whole game, so a new player has to reach it inside their first
-- couple of minutes — anything later and they judge the game on the summon
-- button alone. Habitat space is second for the same reason: somewhere to put
-- what you catch matters before another element does.
PlotConfig.BuyPads = {
	{ id = "fusion_chamber", order = 1, kind = "building", value = "chamber", cost = 250, label = "Fusion Chamber" },
	{ id = "habitat_2", order = 2, kind = "habitat", value = 4, cost = 600, label = "Habitat +4" },
	{ id = "node_earth", order = 3, kind = "node", element = "Earth", cost = 900, label = "Earth Node" },
	{ id = "node_air", order = 4, kind = "node", element = "Air", cost = 2000, label = "Air Node" },
	{ id = "node_nature", order = 5, kind = "node", element = "Nature", cost = 5000, label = "Nature Node" },
	{ id = "node_tier_2", order = 6, kind = "nodeTier", value = 2, cost = 9000, label = "Node Tier 2" },
	{ id = "habitat_3", order = 7, kind = "habitat", value = 4, cost = 18000, label = "Habitat +4" },
	{ id = "node_void", order = 8, kind = "node", element = "Void", cost = 40000, label = "Void Rift" },
	{ id = "node_tier_3", order = 9, kind = "nodeTier", value = 3, cost = 90000, label = "Node Tier 3" },
	{ id = "habitat_4", order = 10, kind = "habitat", value = 5, cost = 250000, label = "Habitat +5" },
	{ id = "node_tier_4", order = 11, kind = "nodeTier", value = 4, cost = 800000, label = "Node Tier 4" },
}

-- Pads are laid out in rows across the plot's front edge. One row of eleven made
-- each pad too small to read or stand on comfortably, so they wrap instead: a
-- bigger pad is easier to hit on mobile and gives the label room to breathe.
PlotConfig.PAD_ROW_Z = 46 -- plot-local Z of the FRONT pad row
PlotConfig.PAD_ROW_GAP = 19 -- distance between pad rows (rows march toward the altar)
PlotConfig.PAD_PER_ROW = 6
PlotConfig.PAD_SIZE = 15 -- square pad footprint, studs
PlotConfig.PAD_SPACING = 18
PlotConfig.BASE_HABITAT_SLOTS = 6 -- beasts that can physically live on the plot

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
