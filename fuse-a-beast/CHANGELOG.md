# Changelog

All notable changes to Fuse a Beast are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); the project uses
[Semantic Versioning](https://semver.org/).

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
