# Changelog

All notable changes to Fuse a Beast are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); the project uses
[Semantic Versioning](https://semver.org/).

## [0.2.0] — 2026-08-30

**The 3D pivot.** v0.1 was a mobile idle game that happened to run on Roblox —
a category error, since on Roblox the 3D space *is* the game. The fusion engine
and full backend are unchanged; they now sit inside a sanctuary tycoon players
walk around.

### Added — World
- `PlotConfig`: island/plot layout, node positions, tycoon upgrade ladder,
  pickup caps, and the rarity→physical-size/glow mapping.
- `WorldBuilder`: procedurally generates the island, sea, central Hub, Arena ring
  and paths at server start; sets dusk lighting and atmosphere.
- `PlotBuilder`: builds a sanctuary — ground, walls, Fusion Altar with orbiting
  element motes and a ProximityPrompt, element node structures, tycoon buy-pads,
  entrance nameplate.
- `BeastModelFactory`: builds creatures from primitives with deterministic
  per-species variation. **Rarity is physical** — scale and glow radius grow with
  rarity so status is visible across the island.

### Added — Gameplay services
- `PlotService`: island build, per-player plot assignment, progression applied to
  geometry, teleport home, Altar prompt binding, clean release.
- `PickupService`: physical shard/essence collectibles, owner-only collection,
  per-plot cap, one shared animation loop.
- `NodeService`: unlocked nodes eject shard pickups on a tier-scaled, staggered
  interval.
- `BeastService`: displayed beasts spawn as wandering creatures that drop essence
  orbs; new discoveries auto-join the sanctuary when a slot is free; altar
  materialisation burst.
- `TycoonService`: owner-only buy-pads that charge essence and physically unlock
  nodes, node tiers and habitat capacity.

### Changed
- Online shards now come from physically collecting node drops; passive shard
  accrual is reserved for offline catch-up, so both play styles are rewarded.
- The fusion panel opens by walking to your Altar, rather than always being on
  screen.
- Habitat capacity is the single source of truth for display slots (tycoon
  purchases + gamepass bonus).
- Social model chosen: **safe sanctuaries + Arena competition** (no raiding), to
  avoid the griefing that churns players out of steal-'em-up games.

### Added — Design
- UI redesign mockups and design tokens under `design/`.

## [0.1.0] — 2026-07-17

First playable — the polished core loop, built to be launched and then iterated
on weekly (per the "ship a great loop, then add content" strategy).

### Added — Design & research
- Market research + gap analysis across the 2026 Roblox economy; ranked 20+ ideas
  by expected ROI and selected **Fuse a Beast** (`docs/MARKET_RESEARCH.md`).
- Complete Game Design Document, Technical Architecture, Optimization Review, and
  Installation guide (`docs/`).

### Added — Server
- Two-phase service bootstrap with a shared registry (no circular requires).
- `DataService` with pluggable, session-locked persistence
  (`DataStoreBackend` + in-memory `MockBackend`), schema reconciliation, autosave,
  and `BindToClose` flush.
- `EssenceService`: idle essence + shard generation, **offline earnings**, Altar
  upgrades, Ascension (rebirth), Sanctuary display boost, starter kit for new
  players.
- `FusionService`: server-authoritative discovery roll (eligibility × recipe bias
  × luck), first-discovery rewards, loud result replication.
- `CollectionService`: Beastdex, display slots, merge-for-power, dex milestones.
- `CurrencyService`: single choke point for all currency/shard mutations with
  atomic spends, clamping, and batched shard grants.
- `QuestService` (deterministic daily quests + achievements/badges),
  `DailyRewardService` (7-day login streak).
- `MonetizationService`: gamepass ownership, idempotent `ProcessReceipt`, timed
  boosts, derived multipliers, VIP daily gems, Premium perks, live-event gating.
- `AnalyticsService`: safe wrapper over Roblox AnalyticsService with the funnel /
  economy event taxonomy.
- `ServerNet`: hardened remote wrapper (per-player rate limiting + profile guard +
  pcall isolation).

### Added — Client
- Observable `ClientState` store; UI is a pure function of server snapshots.
- Code-built mobile-friendly UI: resource bar, Fusion panel, Beastdex, Quests,
  Shop, bottom nav.
- `EssenceController` (smooth predicted counter), `NotificationController`
  (toasts), `FusionController` (discovery popup).

### Added — Content
- 6 elements, 68 beasts across 7 rarities (Common → Secret, incl. event-gated),
  signature recipes,
  6 gamepasses, 7 developer products, 7 daily quests, 7-day login streak,
  7 achievements.

### Added — Assets pipeline
- Optional `icon`/`model` asset-id hooks on beasts and `icon` on elements; the
  Beastdex auto-renders a portrait when a beast has an `icon`, else falls back to
  the code-built color placeholder. Full manifest in `docs/ASSETS.md`.

### Fixed (pre-release review passes)
- Remote container name collision that made server→client remotes unreachable.
- Offline/tick shard grants no longer fan out into thousands of state pushes
  (batched into a single push).
- New players receive a starter kit so the first fusion happens within seconds.

[0.1.0]: https://github.com/LouiL21/ChatGPTPowerToys/tree/claude/roblox-game-research-dev-eealuv/fuse-a-beast
