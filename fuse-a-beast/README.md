# 🔮 Fuse a Beast

> An idle **element-fusion discovery-collector** for Roblox. Fuse element shards
> to *discover* wild beasts, display them to power up your idle Altar, and chase
> the rarest fusions on the server.

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
*Grow a Garden* proved **offline progression** drives return habits;
*Steal a Brainrot* proved **collectible + social tension** goes viral.
**Discovery/combination crafting** is proven addictive off-platform yet rare among
Roblox's top earners — so Fuse a Beast combines all of it:

```
Altar generates Essence + Shards (online + OFFLINE)
      → Fuse 2-3 elements → DISCOVER a beast (rarity roll!)
      → Display beasts in your Sanctuary → boosts idle generation
      → Merge duplicates / Upgrade Altar / Ascend → chase rarer beasts
```

Content (beasts, elements, recipes, events) is **pure config**, so weekly updates
are data edits — which is exactly what makes the update cadence sustainable.

## Feature highlights

- **Idle engine** with true **offline earnings** (capped, gamepass-extendable) and
  a smooth client-predicted essence counter.
- **Discovery-fusion** engine: 6 elements, 68 beasts across 7 rarities
  (Common → **Secret**), signature "recipe" combos, and a luck-driven rarity tail.
- **Collection & Sanctuary:** Beastdex, display-for-boost synergy, and
  **merge-for-power** so duplicates matter.
- **Progression:** Altar levels + **Ascension** (rebirth) with permanent bonuses.
- **Retention:** login streaks, deterministic daily quests, achievements → badges.
- **Monetization:** gamepasses + developer products + receipts + timed boosts +
  Premium perks — all multiplier/convenience/cosmetic, **never pay-to-win**.
- **Server-authoritative & anti-exploit:** rate-limited, validated remotes;
  session-locked data; idempotent purchases.

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
└── src/
    ├── ReplicatedStorage/Shared/   # Config, Net, Util (shared client+server)
    ├── ServerScriptService/Server/ # bootstrap, Data, Services, ServerNet
    └── StarterPlayer/.../Client/   # bootstrap, ClientState, Controllers, UI
```

## Status & roadmap

**v0.1 (this repo):** polished core loop — generation, fusion/discovery,
collection, display boost, merge, altar, ascension, quests, dailies,
monetization, analytics, anti-exploit.

**Next:** trading + Sanctuary visiting (v0.2) → first live event (v0.3) → element
mastery & cosmetics (v0.4). Weekly beast/recipe drops throughout. See the GDD.

## License

[MIT](LICENSE).
