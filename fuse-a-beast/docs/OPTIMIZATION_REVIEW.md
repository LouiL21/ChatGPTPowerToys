# Optimization & Self-Review Passes

> Phase 6. Multiple review passes over the codebase for bugs, exploits, lag,
> duplication, memory leaks, UX, and monetization. Findings and their resolutions.

## Pass 1 — Correctness & bugs

| # | Finding | Resolution |
|---|---|---|
| 1.1 | `Remotes.buildServer` created **two folders both named "RemoteEvent"**, so server→client remotes were unreachable (`FindFirstChild` returns the first). | Merged all RemoteEvents into one container; names are unique across both direction lists. |
| 1.2 | New players waited ~50s (essence + shard accrual) before their first fusion — contradicts "fuse within seconds". | Added `EssenceService:_grantStarter` (150 essence + 25 of each shard) on first-ever join. |
| 1.3 | `folder`/return type casts in `Remotes` tripped strict analysis. | Added explicit `:: Folder` casts. |

## Pass 2 — Performance & lag

| # | Finding | Resolution |
|---|---|---|
| 2.1 | **Push storm:** a large offline/tick shard grant called `addShards` in a loop, each firing a `StateUpdate` — potentially thousands of `FireClient` calls. | Added `CurrencyService:addShardsMap` (tally per element, **one** push). `_grant` now batches. |
| 2.2 | Per-player generation threads would scale poorly. | Single global `GENERATION_TICK` loop iterating players — O(players), not a thread each. |
| 2.3 | Full-profile replication on every change would waste bandwidth. | `StateSync` sends **partial patches**; the client merges them. A currency change sends only currencies. |
| 2.4 | Config scans on hot paths. | Configs pre-index `ById` / `ByRarity` / element bag at module load. |

## Pass 3 — Exploits & server authority

| # | Finding | Resolution |
|---|---|---|
| 3.1 | Remotes are hostile input. | `ServerNet` wraps every handler with **rate limiting + profile guard + pcall**. |
| 3.2 | Spoofed fusion inputs (bad element ids, >3 inputs, non-tables). | `FusionService.fuse` validates payload shape, count (2-3), and every element id against config. |
| 3.3 | Partial-charge / negative-amount exploits. | `trySpendShards` is atomic; amounts clamped ≥0; fusion refunds shards if essence charge fails. |
| 3.4 | Data duplication across servers. | Session-locked `DataStoreBackend` (lock record + stale-steal). |
| 3.5 | Receipt replay / double-grant. | `ProcessReceipt` records `PurchaseId` in-profile and is idempotent; unknown/unloaded → `NotProcessedYet`. |
| 3.6 | Client asserting ownership (display/merge). | Validated against the server-side `codex`; client can only *request*. |
| 3.7 | Currency overflow. | Hard `1e15` ceiling in `CurrencyService`. |

## Pass 4 — Memory leaks & lifecycle

| # | Finding | Resolution |
|---|---|---|
| 4.1 | Per-session tables (`_shardAccum`, `_lastFuse`, `_boosts`, rate-limit buckets) could leak after players leave. | All cleared on `PlayerRemoving` (and rate-limit buckets via bootstrap). |
| 4.2 | Profiles left session-locked on crash. | `BindToClose` releases every profile; stale locks auto-steal after 5 min. |
| 4.3 | Player left during load yield. | `_load` re-checks `player.Parent` and releases immediately if gone. |
| 4.4 | Toast/popup instances accumulating. | Auto-`Destroy` after tween on timeout. |

## Pass 5 — Duplicated code & structure

| # | Finding | Resolution |
|---|---|---|
| 5.1 | Currency math scattered risk. | Single `CurrencyService` choke point; no other code mutates currencies/shards. |
| 5.2 | Remote names duplicated across client/server. | Single `Remotes.lua` definition. |
| 5.3 | Circular `require` risk between services. | Registry injection in bootstrap; services never `require` each other. |
| 5.4 | Rarity/number formatting repetition. | Shared `Format` util; rarity color/index tables centralized. |

## Pass 6 — UX & onboarding

| # | Finding | Resolution |
|---|---|---|
| 6.1 | Tutorial gates are a top Day-1 churn cause. | No tutorial modal; player lands on the Fusion panel with a starter kit and one guiding toast. |
| 6.2 | Idle counters that only jump every 5s feel dead. | `EssenceController` predicts the counter smoothly, reconciling to server truth each push. |
| 6.3 | Players losing track of actions. | Toasts for every server action; loud, longer, color-coded popup for **new** discoveries. |
| 6.4 | Duplicates feeling worthless. | Merge system gives duplicates a purpose (bigger display boost). |

## Pass 7 — Monetization review

| # | Finding | Resolution |
|---|---|---|
| 7.1 | Pay-to-win would poison the (future) trade economy. | Every purchase is a **multiplier / convenience / cosmetic** — no purchasable rarity or power that breaks trading. |
| 7.2 | Barbell pricing best-practice. | Product ladder spans 49-799 R$ (impulse + saved-up tiers); gamepasses 199-799. |
| 7.3 | Monetizing before retention. | GDD explicitly gates aggressive monetization behind Day-7 retention > 15%. |
| 7.4 | Premium incentive. | Premium members get +15% luck; VIP grants daily gems + slots + tag. |

## Known remaining work (intentional, roadmap)

- **Trading & Sanctuary visiting** — remotes are reserved; server logic is a v0.2
  fast-follow (dual-confirm, server-authoritative).
- **Real asset IDs** — gamepass/product/badge ids are `0` placeholders to be set
  in the Creator Hub before publishing.
- **Automated tests** — the pure fusion/currency logic is structured for TestEZ
  unit tests (roadmap).
- **ProfileStore swap** — recommended for a large launch; interface already
  abstracted.

No *major* correctness, exploit, or performance issues remain in the launch loop.
