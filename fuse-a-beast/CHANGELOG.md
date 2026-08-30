# Changelog

All notable changes to Fuse a Beast are documented here. Format loosely follows
[Keep a Changelog](https://keepachangelog.com/); the project uses
[Semantic Versioning](https://semver.org/).

## [0.3.1] — 2026-08-30

**First playtest pass.** Everything here comes from playing 0.3.0 and writing
down what was confusing, invisible or unrewarding.

### Fixed
- **The Altar upgrade ladder was unreachable.** The nav rebuild in 0.3.0 dropped
  the Altar, Ascend and Collect buttons while the remotes stayed live, so altar
  levels and Ascension could not be bought at all. New **Sanctuary** panel
  restores all three and shows level, rate, upgrade cost, Ascension requirement
  and habitat capacity.
- **The Chamber never showed what a fusion costs** — it just failed quietly when
  you could not afford one. The price now mirrors the server formula, shows
  against your balance, and rides on the FUSE button.

### Changed — Pacing
- The Fusion Chamber is now buy-pad **one at 250 essence** (was pad two at 900).
  Fusing two beasts is the game; it has to be reachable in the first couple of
  minutes.
- Habitat space is pad two, and the base allowance rises 4 → 6 with a wider
  wander radius.
- Buy-pads are 15×15 on raised plinths and wrap into rows of six instead of
  eleven crammed across the plot. They show an abbreviated cost and light up
  gold when affordable.

### Changed — Feel
- **Essence orbs are worth something.** An orb's value was the plot rate split
  evenly across displayed beasts, so every beast you added made every orb
  smaller. An orb is now worth what the *dropping beast* contributes, scaled by
  its rarity and variant — and it looks the part: bigger, variant-tinted,
  sparkling with value.
- Pickups fly to their owner inside 16 studs and pop a floating **+N** where
  they were taken. Touch and magnet share one guarded credit path.
- **Every species has its own silhouette.** All 68 beasts shared one quadruped
  body with jittered dimensions. Each now resolves to a body plan — quadruped,
  serpent, avian, golem, wisp or brute — from its primary element, with a
  per-species hue nudge. Legendary+ always takes the more dramatic plan.
- Lighting gains bloom, a colour grade and sun rays; plots gain scattered trees,
  rock clusters and lit wall capstones; the HUD's bare numbers became framed
  chips; nav buttons became glyph-over-label.

## [0.3.0] — 2026-08-30

**Beasts became the currency of the game.** Fusing raw shards made creatures
disposable; now you catch them and combine *them*, so every beast matters.

### Added — Core loop
- **Fusion Chamber** (`FusionChamberService`): combine two owned beasts. Same
  species + variant rolls a variant upgrade; two different species produce a
  hybrid rolled from their combined elements. A failed variant fusion returns
  one beast, so it costs one rather than two.
- **Variants** (`VariantConfig`): Normal → Shiny → Golden → Rainbow → Void, each
  multiplying combat power and sanctuary essence output, with falling upgrade
  odds. Endless progression that costs no new content.
- The Altar is now a **Summoning Altar**; `FusionService.rollFromElements` is
  shared with the Chamber so drop rates can never drift between them.

### Added — Pets & combat
- `PetService`: your active beast follows you and is your Arena fighter.
- `BattleService`: a five-boss PvE ladder (always available so solo players are
  never blocked) plus consensual duels, with crits, element advantage and
  damage variance so upsets are possible. Losing still pays; beasts are never
  lost.
- `BattleController`: live health bars, rolling hit log, duel prompt.

### Added — Presentation
- `Theme` + `Components`: chunky tactile UI system (thick strokes, hard offset
  shadows, press feedback) replacing the flat dashboard look.
- UIController rebuilt with seven panels; the Chamber previews its outcome
  before you commit, which is how the variant/hybrid distinction is taught.
- `AmbienceService`: altar crystals breathe, motes orbit, node crystals bob,
  arena pillars pulse — all from one shared Heartbeat pass.
- Variants recolour, sparkle and glow in-world.

### Changed
- Profile v2 with a forward-only, idempotent `Migrations` module; v1 saves fold
  old merge levels back into copies rather than losing them.
- Monetisation reworked: time, convenience, luck and looks only, with a cosmetic
  gem sink and an explicit rule that Arena power is never purchasable.
- Removed the uncompletable "visit another sanctuary" daily.

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
