# 🔮 Fuse a Beast

> A **3D creature-sanctuary tycoon** for Roblox. Collect element shards from the
> nodes on your plot, fuse them at your Altar to *discover* wild beasts, and grow
> a sanctuary they physically live in — where a Mythic towers over the treeline
> and every visitor can see it.

Built as a complete, production-oriented Roblox studio project — chosen from
market research as the highest expected-ROI opportunity on the 2026 platform:
**offline idle progression** (retention) × **collection/rarity** (monetization) ×
**shareable discovery moments** (viral growth), in a genre combination the top
charts don't yet occupy.

🆕 **New here / non-technical?** Start with the idiot-proof
[**Setup Guide**](docs/SETUP_GUIDE.md) — GitHub → Roblox Studio → published, step by step.

📄 **The full story:** [`docs/MARKET_RESEARCH.md`](docs/MARKET_RESEARCH.md) ·
[`docs/GAME_DESIGN_DOCUMENT.md`](docs/GAME_DESIGN_DOCUMENT.md) ·
[`docs/TECHNICAL_ARCHITECTURE.md`](docs/TECHNICAL_ARCHITECTURE.md) ·
[`docs/OPTIMIZATION_REVIEW.md`](docs/OPTIMIZATION_REVIEW.md) ·
[`docs/ASSETS.md`](docs/ASSETS.md) ·
[`docs/INSTALLATION.md`](docs/INSTALLATION.md) ·
[`docs/SETUP_GUIDE.md`](docs/SETUP_GUIDE.md)

## Why this game

The breakout hits of 2025-26 share a DNA: a dead-simple loop, a reason to return
tomorrow, a shareable moment, cosmetics-first monetization, and weekly updates.
*Grow a Garden* proved **offline progression** drives return habits and that a
**plot you physically tend** beats an inventory screen; *Steal a Brainrot* proved
**value embodied in objects other players can see** goes viral. Tycoons remain the
most-loved structure on the platform.

**Discovery/combination crafting** is proven addictive off-platform yet rare among
Roblox's top earners — so Fuse a Beast puts that engine inside the tycoon shell
Roblox players already love:

```
Element nodes on your plot eject SHARDS  →  run over them to collect
      → walk to your ALTAR, fuse 2-3 elements → DISCOVER a beast
      → the beast physically SPAWNS in your sanctuary and wanders it
      → it drops ESSENCE ORBS you collect + raises your passive rate
      → step on TYCOON PADS to unlock nodes, tiers and habitat space
      → your plot visibly grows → chase rarer, bigger, brighter beasts
```

**Rarity is physical.** A Common is knee-high and dull. A Mythic towers and glows
brightly enough to spot from across the island. Your collection isn't a number in
a menu — it's a landmark other players walk past.

Content (beasts, elements, recipes, events, plot layout, the upgrade ladder) is
**pure config**, so weekly updates are data edits — which is what makes the
cadence sustainable.

## Feature highlights

- **A real 3D world**, generated procedurally at server start — an island with a
  central Hub and Arena, and eight sanctuaries you walk between. No art assets
  required to run.
- **Physical collection gameplay:** element nodes eject shard pickups, beasts
  drop essence orbs, and you run around gathering them.
- **Tycoon progression:** step on a buy-pad, pay essence, and your sanctuary
  physically grows — new element nodes, faster node tiers, more habitat space.
- **Creatures that live in the world:** procedurally built beasts that wander,
  bob and glow, scaled by rarity. Anchored and driven by one shared loop, so a
  full island costs no physics.
- **Idle engine** with true **offline earnings** (capped, gamepass-extendable) —
  active play pays ~40% more, but stepping away is still rewarded.
- **Discovery-fusion** engine: 6 elements, 68 beasts across 7 rarities
  (Common → **Secret**), signature "recipe" combos, and a luck-driven rarity tail.
- **Safe sanctuaries:** nobody can rob your plot. Competition lives in the Arena
  instead, so nobody gets griefed out of the game.
- **Retention:** login streaks, deterministic daily quests, achievements → badges.
- **Monetization:** gamepasses + developer products + receipts + timed boosts +
  Premium perks — all multiplier/convenience/cosmetic, **never pay-to-win**.
- **Server-authoritative & anti-exploit:** rate-limited, validated remotes;
  session-locked data; idempotent purchases; owner-only pickups and pads.

## Architecture at a glance

- **Rojo** project — source as `.lua`, fully diffable (UI is built in code, no
  binary assets in git).
- **Server:** two-phase service bootstrap with dependency injection; one source of
  truth per concern (`DataService`, `CurrencyService`, `EssenceService`, …).
- **Client:** observable `ClientState` store; UI is a pure function of server
  snapshots.
- **Data:** pluggable backend (session-locked DataStore or in-memory mock);
  ProfileStore-ready.

See [`docs/TECHNICAL_ARCHITECTURE.md`](docs/TECHNICAL_ARCHITECTURE.md).

## Quick start

```bash
cd fuse-a-beast
rojo serve       # then Connect from the Rojo Studio plugin, and press Play
```

No API access required to test — the game falls back to an in-memory data backend
so the whole loop is playable immediately. Full guide:
[`docs/INSTALLATION.md`](docs/INSTALLATION.md).

## Project layout

```
fuse-a-beast/
├── default.project.json      # Rojo mapping
├── wally.toml                # (optional) ProfileStore dependency
├── docs/                     # research, GDD, architecture, review, install
├── design/                   # UI mockups + design tokens
└── src/
    ├── ReplicatedStorage/Shared/   # Config, Net, Util (shared client+server)
    ├── ServerScriptService/Server/ # bootstrap, Data, World, Services, ServerNet
    │   └── World/                  # procedural island, plots, beast models
    └── StarterPlayer/.../Client/   # bootstrap, ClientState, Controllers, UI
```

## Status & roadmap

**v0.2 (this repo):** the 3D sanctuary tycoon — procedural island, plots,
physical shard/essence collection, walk-up Fusion Altar, wandering beasts scaled
by rarity, tycoon buy-pads, plus the full v0.1 backend (fusion engine, economy,
offline earnings, quests, dailies, monetization, analytics, anti-exploit).

**Next:** Arena events (v0.3) → sanctuary decoration cosmetics + visiting rewards
(v0.4) → trading. Weekly beast/recipe drops throughout. See the GDD.

## License

[MIT](LICENSE).
