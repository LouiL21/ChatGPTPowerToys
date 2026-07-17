# Fuse a Beast — Game Design Document

> Phase 3. This GDD is the contract the code implements; every system here maps
> to a service in `src/` and tunables in `src/ReplicatedStorage/Shared/Config/`.

## 1. One-line pitch

**Fuse element shards to *discover* wild beasts, display them to power up your
idle Altar, and chase the rarest fusions on the server.** An idle
discovery-collector that rewards you for coming back.

## 2. Fantasy & tone

You are an Alchemist tending a living **Fusion Altar**. It drips elemental
shards even while you sleep. You combine them to *discover* creatures — most
common, a precious few legendary or **Secret** — and build a Sanctuary that both
shows off your collection and makes your Altar produce faster.

Tone: colorful, friendly, "6-to-99" readable. No violence; pure collection joy.

## 3. Core gameplay loop (the polished launch loop)

```
        ┌─────────────────────────────────────────────────┐
        │                                                  │
        ▼                                                  │
  Altar generates ──▶ Fuse 2-3 element ──▶ DISCOVER a ────▶ Display beasts in
  Essence + Shards     shards together      beast (rarity   Sanctuary → boosts
  (online + OFFLINE)                        roll!)          idle generation
        ▲                                      │                    │
        │                                      ▼                    │
        │                            Merge duplicates ◀─────────────┘
        │                            to level beasts
        └──────────── Upgrade Altar / Ascend for more ◀─────────────┘
```

- **Time-to-first-fusion: seconds.** The player lands on the Fusion panel; the
  Altar has already produced starter shards. No tutorial gate (invisible
  onboarding).
- **The hook is discovery.** Each fusion is a weighted rarity roll; new Beastdex
  entries fire a loud celebration (the shareable moment).
- **Idle synergy:** displayed beasts raise your essence rate, so collecting
  directly accelerates production — collection *is* progression.

## 4. Currencies & economy

| Currency | Source | Sink | Notes |
|---|---|---|---|
| **Essence** (soft) | Altar generation (online + offline), taps, quests | Altar upgrades, fusion cost | The primary throughput currency |
| **Element Shards** ×6 | Altar generation (weighted per element) | Fusion inputs (10/element) | The real gate on fusion; drives element strategy |
| **Gems** (premium-soft) | New discoveries, quests, streaks, VIP daily, purchase | Cosmetics/luck/convenience (future shop) | Earnable *and* buyable — never strictly pay-only |
| **Robux** (real) | — | Gamepasses & dev products | See Monetization |

**Balancing philosophy:** shards gate *breadth* (which beasts you can attempt);
essence gates *rate* (Altar level). Luck gates the *rarity tail*. Nothing bought
with Robux breaks the collection or a future trade economy — purchases are
**multipliers, convenience, and cosmetics only**.

Key tunables (`GameConfig.lua`):
- Essence rate = `BASE(1.0) × 1.18^(altarLvl-1) × ascensionMult × displayBoost × essenceMultiplier`.
- Shard rate = `0.4 × 1.10^(altarLvl-1) × ascensionMult`, allocated by element weight.
- Offline = 50% efficiency, capped 4h (24h with gamepass).
- Fusion cost = 10 shards/element + 25 essence; base 2s cooldown.

## 5. Progression

1. **Altar Level** (primary): each level multiplies essence *and* shard rate.
   Cost scales `100 × 1.55^(lvl-1)`. Max 250.
2. **Beastdex completion**: 32 beasts at launch across 7 rarities; milestones at
   25 and 100% grant achievements/badges.
3. **Merge levels** (per beast, max 10): spend duplicates to raise a beast's
   display boost — gives duplicates value.
4. **Ascension (rebirth)**: at Altar level ≥ 50 (scaling), reset Altar/essence/
   shards for a **permanent +25% essence multiplier** and prestige status. Keeps
   your entire collection.

## 6. Rarities & the discovery roll

`Common → Uncommon → Rare → Epic → Legendary → Mythic → Secret`, with base weights
1000 / 420 / 150 / 40 / 8 / 1.2 / 0.08.

- **Eligibility:** a beast is rollable only if all its element tags are present in
  your input (e.g. the Rare *Steam Serpent* needs Fire **and** Water inputs).
- **Signature recipes** (`RecipeConfig.lua`) bias specific combos toward high
  rarity — the "meta" players discover and share (e.g. `Fire+Air+Void` massively
  boosts Mythic/Secret and is the path to the **Chronodragon**).
- **Luck** lifts the Rare+ tail (`weight × luck^(rarityIndex-2)`), so Lucky Aura /
  Premium / luck potions feel meaningful without guaranteeing anything.

## 7. Retention systems

- **Offline earnings** (the marquee retention feature): a "Welcome back" summary
  on join. Extend the cap from 4h→24h via gamepass.
- **Login streak** (7-day, escalating, Day-7 spikes) — resets on a missed day.
- **Daily quests** (3/day, deterministic per player) — the "unfinished business"
  that drives Day-2 return. Claimable for gems/boosts.
- **Achievements → Badges** for first fusion, first Legendary/Mythic/Secret,
  Beastdex 25 & 100%, first Ascension.
- **Weekly content + limited events** (roadmap) — event-gated beasts already
  supported (`BeastConfig` `event` field + `MonetizationService:isEventActive`).

## 8. Social mechanics

- **Sanctuary display** is public-facing: displayed beasts are your flex.
- **Visiting & rating** other Sanctuaries (roadmap; remote reserved).
- **Trading** duplicates/shards, server-authoritative dual-confirm (roadmap;
  remotes reserved) — the rarity economy is designed to support it.

## 9. Monetization (see `MonetizationConfig.lua`)

Follows 2026 best practice: gamepasses ≈60-70% of surface, dev products ≈30-40%,
pricing barbell (cheap impulse + premium saved-up tiers).

**Gamepasses (permanent):**
- 2x Essence (199) · Auto-Fuse (349) · Lucky Aura (299) · 24h Offline (249) ·
  +3 Display Slots (399) · VIP (799: daily gems, +1 slot, chat tag, VIP zone).

**Developer products (repeatable):**
- Essence/Gem packs (49-799) · Luck Potions (99 / 499) · Fusion Frenzy (149).

**Premium payouts:** Roblox Premium members get +15% luck (engagement incentive)
and are eligible for time-based premium payouts.

**Timing rule (enforced by discipline, not code):** don't push monetization hard
until **Day-7 retention > 15%**. Before that, it's a retention problem, not a
monetization problem.

**Badges:** milestone achievements double as Roblox Badges (ids in QuestConfig).

## 10. Analytics events

`session_start`, `altar_upgrade`, `beast_discovered{rarity}`, `ascend`,
`quest_claim`, `daily_claim{streak}`, `achievement`, `purchase{product|gamepass, robux}`.
Funnel focus: install → first_fusion → first_discovery → Day1 → Day2 → Day7 →
first_purchase.

## 11. UX / UI principles

- **Mobile-first**, one-thumb reachable, big tap targets.
- **Invisible onboarding** — no modal tutorial; the fusion panel *is* the tutorial.
- **Loud feedback** on discovery (color-coded rarity popup, longer for NEW).
- **Always-ticking essence counter** (client-predicted, server-reconciled) for
  the satisfying idle feel.
- Toasts for every server action so the player always knows what happened.

## 12. Update roadmap (iterative launch)

**v0.1 (this repo) — polished core loop.** Generation, fusion/discovery,
collection, display boost, merge, altar, ascension, quests, dailies,
monetization, analytics, anti-exploit.

**v0.2 — social & trade (fast-follow).** Visit/rate Sanctuaries; server-
authoritative dual-confirm trading of duplicates + shards.

**v0.3 — first live event.** "Summer Bloom" (event beast already stubbed);
limited-time recipe + countdown UI; leaderboard.

**v0.4 — depth.** Element mastery perks; beast abilities; Sanctuary decoration
cosmetics (new Robux surface); global "rarest discovery" ticker.

**Cadence:** weekly beast/recipe drops (pure config), monthly limited events.
New content = data edits, not engine work — this is the whole point of the
data-driven architecture.

## 13. Live-event ideas

- Element festivals (double shards of one element for a weekend).
- "Fusion Frenzy Hour" server-wide luck boost.
- Hunt events: a Secret beast only rollable during the event window.
- Community goal: server collectively performs N fusions → unlocks a reward.

## 14. Balancing guardrails

- Hard currency ceiling (`1e15`) prevents overflow/exploit inflation.
- Offline at 50% keeps active play strictly better than idling.
- Fusion essence cost is trivial late-game *by design* — shards + luck are the
  real chase, protecting the rarity economy from pure-essence whales.
- Merge costs scale with level so top-end beasts stay aspirational.
