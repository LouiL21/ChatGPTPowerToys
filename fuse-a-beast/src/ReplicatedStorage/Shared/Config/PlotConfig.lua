--!strict
--[[
	PlotConfig
	Layout and progression data for a player's Sanctuary plot.

	The world is built procedurally from this file — no art assets required — so
	changing the sanctuary layout, the tycoon upgrade ladder, or the island size
	is a config edit, never geometry code.

	Coordinates are PLOT-LOCAL, relative to the plot's centre:
	  +Z is toward the HUB — the entrance you walk in from, where the buy-pads
	     and the nameplate live.
	  -Z is toward the island RIM — the back, where the Altar, Fusion Chamber
	     and Beast Barn stand and where the boundary wall runs.
	PlotBuilder maps them into world space.
]]

local PlotConfig = {}

-- ── Island / plot geometry ────────────────────────────────────────────────
PlotConfig.PLOT_COUNT = 8 -- plots per server (matches a healthy Roblox lobby)
PlotConfig.PLOT_SIZE = 150 -- square plot, studs
-- Ring radius has to keep pace with plot size or neighbours crowd each other.
-- Chord spacing between adjacent plots is 2*R*sin(pi/8) ≈ 0.765*R, so 340
-- leaves ~110 studs of clear ground between one sanctuary and the next.
PlotConfig.PLOT_RING_RADIUS = 340 -- distance from island centre to plot centre
PlotConfig.HUB_RADIUS = 100 -- central hub disc
PlotConfig.GROUND_Y = 0

--[[
	Surface palette.

	These were all dark desaturated blues, which under a twilight sky collapsed
	into one another: sea, path, hub floor, arena and plot ground were
	indistinguishable, so the whole island read as a single flat mass. Each
	surface now differs in HUE as well as value — green ground, warm stone path,
	violet hub, bright teal sea — because at low light levels hue survives where
	brightness alone does not.
]]
PlotConfig.COLORS = {
	hubGround = Color3.fromRGB(96, 82, 146),
	hubTrim = Color3.fromRGB(178, 132, 255),
	plotGround = Color3.fromRGB(96, 148, 84),
	plotRim = Color3.fromRGB(62, 50, 92),
	path = Color3.fromRGB(196, 178, 150), -- warm sandstone: the one warm surface
	water = Color3.fromRGB(38, 132, 190),
	arenaFloor = Color3.fromRGB(70, 56, 108),
	altarStone = Color3.fromRGB(72, 62, 108),
	altarGlow = Color3.fromRGB(167, 139, 250),
	locked = Color3.fromRGB(58, 54, 76),
	-- Deliberately a deep amber, not a bright one. Neon material plus bloom
	-- pushes any light colour straight to white, which is what turned the pads
	-- into featureless glowing squares.
	affordable = Color3.fromRGB(186, 124, 34), -- pad you can buy RIGHT NOW
}

-- ── Element nodes ─────────────────────────────────────────────────────────
-- Physical structures that periodically emit a shard pickup the player runs
-- over. Fire and Water start unlocked so the core loop is available instantly;
-- the rest are tycoon purchases.
-- Nodes hug the side walls, leaving the middle of the plot clear for the
-- habitat. Crowding them inward is what made the sanctuary feel packed.
PlotConfig.Nodes = {
	{ element = "Fire", offset = Vector3.new(-66, 0, -32), unlockedByDefault = true },
	{ element = "Water", offset = Vector3.new(58, 0, -22), unlockedByDefault = true },
	{ element = "Earth", offset = Vector3.new(-63, 0, 6), unlockedByDefault = false },
	{ element = "Air", offset = Vector3.new(63, 0, 6), unlockedByDefault = false },
	{ element = "Nature", offset = Vector3.new(-48, 0, 32), unlockedByDefault = false },
	{ element = "Void", offset = Vector3.new(48, 0, 32), unlockedByDefault = false },
}

PlotConfig.NODE_BASE_INTERVAL = 6 -- seconds between shard emissions at tier 1
PlotConfig.NODE_TIER_SPEEDUP = 0.78 -- interval multiplier per node tier
PlotConfig.NODE_MAX_TIER = 5

-- ── Landmarks ─────────────────────────────────────────────────────────────
PlotConfig.ALTAR_OFFSET = Vector3.new(0, 0, -52) -- Summoning Altar, back-centre
PlotConfig.CHAMBER_OFFSET = Vector3.new(-54, 0, -50) -- Fusion Chamber, back-left
PlotConfig.BARN_OFFSET = Vector3.new(52, 0, -50) -- Beast Barn, back-right
PlotConfig.HOUSE_OFFSET = Vector3.new(-42, 0, -16) -- your Cottage, mid-left
-- Clear of the front pad row, so arriving home never lands you on a buy-pad.
PlotConfig.SPAWN_OFFSET = Vector3.new(0, 0, 70) -- where the owner is placed
PlotConfig.SIGN_OFFSET = Vector3.new(0, 0, 74) -- nameplate at the plot entrance

-- Beasts wander inside this radius around the habitat centre. The radius has to
-- grow with the slot count or a full sanctuary reads as a pile rather than a
-- collection you can walk through.
PlotConfig.HABITAT_CENTRE = Vector3.new(0, 0, -4)
PlotConfig.HABITAT_RADIUS = 40
-- How far a beast strays from its OWN patch. Small on purpose: beasts that each
-- roam the whole habitat inevitably bunch up in the middle.
PlotConfig.BEAST_ROAM_RADIUS = 7

-- ── Pickups ───────────────────────────────────────────────────────────────
--[[
	Pickup density.

	A full sanctuary is fifteen beasts each dropping an orb, and at a nine-second
	interval that is well over one new glowing part per second — the plot filled
	with litter faster than anyone could walk it. The interval is now longer and
	each orb is worth proportionally more, so INCOME IS UNCHANGED (an orb's value
	scales with the interval) while there is half as much on the ground, and what
	is there is worth stopping for.
]]
PlotConfig.MAX_PICKUPS_PER_PLOT = 18 -- hard cap: keeps part count (and lag) bounded
PlotConfig.PICKUP_LIFETIME = 90 -- seconds before an uncollected pickup despawns
PlotConfig.ESSENCE_ORB_INTERVAL = 18 -- seconds between a beast's essence drops
PlotConfig.PICKUP_MAGNET_RANGE = 24 -- studs at which pickups start flying to the owner
PlotConfig.PICKUP_MAGNET_SPEED = 34 -- studs/sec once a pickup is homing

-- An orb's worth is the DROPPING BEAST's, not an even split of the plot's rate.
-- Splitting meant every extra beast made every orb worth less, so a sanctuary
-- full of Mythics paid the same dribble as one Common — which is exactly why
-- picking orbs up felt pointless. Now a rare beast visibly pays more.
PlotConfig.ORB_SHARE = 0.5 -- orb value as a fraction of the plot's per-second rate
PlotConfig.ORB_RARITY_MULT = {
	Common = 1,
	Uncommon = 1.6,
	Rare = 2.6,
	Epic = 4.5,
	Legendary = 9,
	Mythic = 20,
	Secret = 50,
}

-- ── Tycoon buy-pads ───────────────────────────────────────────────────────
-- Stepping on a pad charges essence and applies `apply`. Pads are laid out in a
-- row along the plot's front edge; `order` sets left-to-right position.
-- kind: "node" unlocks an element node · "nodeTier" upgrades all nodes
--       "habitat" raises how many beasts can live on the plot
--       "altar" raises the Altar level (fusion power / display slots)
-- kind "building" reveals a structure (the Fusion Chamber, the Beast Barn).
--
-- Ordering rule: the Chamber is pad ONE and deliberately cheap. Fusing two
-- beasts is the whole game, so a new player has to reach it inside their first
-- couple of minutes — anything later and they judge the game on the summon
-- button alone. Habitat space is second for the same reason: somewhere to put
-- what you catch matters before another element does.
--
-- After that, `order` follows COST, so walking the pad rows left to right is
-- walking your way up the upgrade ladder. Two rows of six.
PlotConfig.BuyPads = {
	{ id = "fusion_chamber", order = 1, kind = "building", value = "chamber", cost = 250, label = "Fusion Chamber" },
	{ id = "habitat_2", order = 2, kind = "habitat", value = 4, cost = 600, label = "Habitat +4" },
	-- The Cottage is early and cheap on purpose: it is the first thing you BUILD
	-- rather than unlock, and a plot with a house on it stops looking like a test
	-- level about ninety seconds into the game.
	{ id = "cottage", order = 3, kind = "building", value = "house", cost = 1200, label = "Your Cottage" },
	{ id = "node_earth", order = 4, kind = "node", element = "Earth", cost = 1600, label = "Earth Node" },
	{ id = "node_air", order = 5, kind = "node", element = "Air", cost = 3000, label = "Air Node" },
	{ id = "node_nature", order = 6, kind = "node", element = "Nature", cost = 6000, label = "Nature Node" },
	{ id = "node_tier_2", order = 7, kind = "nodeTier", value = 2, cost = 9000, label = "Node Tier 2" },
	{ id = "habitat_3", order = 8, kind = "habitat", value = 4, cost = 14000, label = "Habitat +4" },
	-- The Barn is the mid-game landmark: the first purchase that changes the
	-- plot's skyline rather than adding another crystal, and it pays in both room
	-- and rate so it never feels like decoration bought by mistake.
	{ id = "beast_barn", order = 9, kind = "building", value = "barn", cost = 22000, label = "Beast Barn" },
	{ id = "node_void", order = 10, kind = "node", element = "Void", cost = 40000, label = "Void Rift" },
	{ id = "node_tier_3", order = 11, kind = "nodeTier", value = 3, cost = 90000, label = "Node Tier 3" },
	{ id = "habitat_4", order = 12, kind = "habitat", value = 5, cost = 250000, label = "Habitat +5" },
	{ id = "node_tier_4", order = 13, kind = "nodeTier", value = 4, cost = 800000, label = "Node Tier 4" },
}

-- Pads are laid out in rows across the plot's front edge. One row of eleven made
-- each pad too small to read or stand on comfortably, so they wrap instead: a
-- bigger pad is easier to hit on mobile and gives the label room to breathe.
PlotConfig.PAD_ROW_Z = 62 -- plot-local Z of the FRONT pad row
PlotConfig.PAD_ROW_GAP = 25 -- distance between pad rows (rows march toward the altar)
PlotConfig.PAD_PER_ROW = 7
PlotConfig.PAD_SIZE = 18 -- square pad footprint, studs
PlotConfig.PAD_SPACING = 21
PlotConfig.BASE_HABITAT_SLOTS = 6 -- beasts that can physically live on the plot

-- What the Beast Barn is worth once built.
PlotConfig.BARN_HABITAT_SLOTS = 5 -- extra beasts it houses
PlotConfig.BARN_ESSENCE_BONUS = 0.25 -- +25% sanctuary essence: rested beasts produce more

-- The Cottage is yours rather than the beasts'. It pays a smaller, earlier
-- bonus, so the two buildings never feel like the same purchase twice.
PlotConfig.HOUSE_ESSENCE_BONUS = 0.15

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
