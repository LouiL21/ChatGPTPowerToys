# Fuse a Beast — Technical Architecture

> Phase 4. How the code is organized and why. Everything is server-authoritative,
> data-driven, and built to make weekly content updates a config edit.

## 1. Principles

1. **Server authority.** The client renders snapshots and *requests* actions. It
   never computes currency, ownership, or drop results. Every RemoteEvent is
   treated as hostile input.
2. **Data-driven.** Beasts, elements, recipes, quests, prices, and tuning all
   live in `Shared/Config`. Adding content = editing config, not gameplay code.
3. **One source of truth per concern.** Persistence → `DataService`. Currency →
   `CurrencyService`. Rates → `EssenceService`. This makes auditing (and
   anti-exploit review) tractable.
4. **No circular requires.** Services are plain modules loaded by a bootstrap
   that injects a shared `Registry`, so any service can call any other without
   `require` cycles.

## 2. Folder structure (Rojo)

```
default.project.json         → maps src/ into the DataModel
src/
  ReplicatedStorage/Shared/  → replicated to client + server
    Config/                  → GameConfig, ElementConfig, BeastConfig,
                               RecipeConfig, MonetizationConfig, QuestConfig
    Net/Remotes.lua          → single source of truth for the remote surface
    Util/                    → Signal, RateLimiter, TableUtil, Logger, Format
  ServerScriptService/Server/
    init.server.lua          → two-phase bootstrap (Init → Start)
    ServerNet.lua            → hardened remote wrapper (rate-limit + pcall + guard)
    Data/
      DataService.lua        → per-player profile lifecycle + autosave
      ProfileTemplate.lua    → canonical save schema (reconciled on load)
      Backends/              → DataStoreBackend (session-locked) + MockBackend
    Services/                → StateSync, Currency, Essence, Fusion, Collection,
                               Quest, DailyReward, Monetization, Analytics
  StarterPlayer/StarterPlayerScripts/Client/
    init.client.lua          → client bootstrap
    ClientState.lua          → observable local cache of server snapshots
    Controllers/             → UI, Essence (predicted counter), Notification, Fusion
    UI/Create.lua            → declarative instance builder
```

## 3. Service lifecycle

`init.server.lua` builds a `Registry` (`Registry[service.Name] = service`) then:

- **Init phase** — each `service:Init(Registry)` wires dependencies and picks the
  data backend. No remotes bound yet.
- Configure `ServerNet` with the `RateLimiter` + `DataService`.
- **Start phase** — start every service *except* `DataService`, so all
  `ProfileLoaded` listeners are connected first…
- …then `DataService:Start()` **last**, which begins loading players. This
  ordering guarantees no join event is missed.

Client mirrors this: build UI → connect controllers → connect server→client
remotes → pull initial state via the `GetState` RemoteFunction (with retry).

## 4. Data persistence & session locking

`DataService` owns each player's table for their whole session. It never lets two
servers edit one profile — the root cause of duplication exploits.

- **Backend abstraction:** `load / save / release`. `DataService` auto-selects
  `DataStoreBackend` in production and `MockBackend` when DataStores are
  unavailable (Studio without API access), so the full loop is always playable.
- **Session lock (`DataStoreBackend`):** a `{ data, lock = {jobId, time} }` record.
  `load` acquires the lock via `UpdateAsync` (aborting if another *live* server
  holds it), `save` refreshes the lock timestamp, `release` clears it. Stale
  locks (dead servers) are stolen after 5 minutes.
- **Schema migration:** `TableUtil.reconcile` back-fills new template fields into
  old saves without overwriting existing values — safe to add fields anytime.
- **Autosave** every 60s; `BindToClose` flushes + releases all profiles on
  shutdown.
- **Production note:** for a big launch, swap `DataStoreBackend` for the
  battle-tested **ProfileStore** (see `wally.toml`) behind the same interface.

## 5. Networking & anti-exploit

Defense-in-depth, all server-side:

1. **`Remotes.lua`** is the only definition of the remote surface — names can't
   drift between client and server.
2. **`ServerNet.onEvent`** wraps *every* inbound handler with:
   - **per-player sliding-window rate limiting** (`RateLimiter`, limits in
     `GameConfig.REMOTE_RATE_LIMITS`) — floods are dropped before touching state;
   - **profile-loaded guard** — no actions before data exists;
   - **pcall isolation** — a throwing handler can't kill the remote.
3. **Payload validation** in each handler: types checked, element ids validated
   against config, fusion inputs constrained to 2-3 valid elements, display/merge
   validated against server-side ownership.
4. **Atomic spends** (`CurrencyService:trySpendShards`) — never partially charge;
   fusion refunds shards if the essence charge fails.
5. **Idempotent receipts** (`MonetizationService:_processReceipt`) — `PurchaseId`
   recorded in the profile so a retried receipt can't double-grant.
6. **Value clamping** — hard currency ceiling; server cooldown on fusion in
   addition to the rate limiter.

The client is never trusted for outcomes: the fusion rarity roll, all currency
math, and gamepass ownership are computed and verified on the server.

## 6. The idle engine (`EssenceService`)

- A single global tick (`GENERATION_TICK = 5s`) grants essence + shards to every
  loaded player — one loop, not a thread per player.
- **Offline** is computed on `ProfileLoaded` from `lastSeen` (clamped to the cap,
  at 50% efficiency) and surfaced as a "Welcome back" toast.
- **Rate** is derived in one place (`getRate`) and consumed by both generation and
  the client readout, so they can never disagree.
- Fractional shards accumulate per session and are emitted as whole shards to a
  weighted-random element.

## 7. The fusion engine (`FusionService`)

Pure, testable pipeline: validate → charge (atomic) → build eligible-by-rarity
set for the input elements → weighted rarity roll (base × recipe-bias × luck) →
uniform pick within rarity → award + first-discovery rewards → replicate result.
Adding a beast or recipe is a config edit; the engine is unchanged.

## 8. State replication (`StateSync`)

- `buildFull` produces the client snapshot (currencies, shards, altar, ascension,
  codex, display, quests, login, gamepasses, stats, derived rate, active boosts).
- `push` sends **partial patches**; the client merges them into `ClientState`,
  which fires a `Changed` signal the UI subscribes to. Cheap and incremental —
  a currency change sends only currencies, not the whole profile.

## 9. Client architecture

- `ClientState` is an observable store; the UI is a pure function of it.
- `EssenceController` predicts the essence counter (`server + rate × dt`) for a
  smooth idle feel while always reconciling to server truth on each push.
- UI is **built in code** (no binary `.rbxmx` in git) so the entire interface is
  diffable and reviewable; swap for designer ScreenGuis later if desired.

## 10. Performance & scale

- O(players) work per tick, not O(players²); no per-player threads for generation.
- Partial state patches keep replication bandwidth low.
- Config lookups are pre-indexed (`ById`, `ByRarity`) at module load.
- Analytics and badge awards are `pcall`-wrapped and `task.spawn`-ed so they never
  block or crash gameplay.
- Designed to run within Roblox's per-server player cap; global scale is achieved
  by Roblox spinning up many servers (state is per-player, not cross-server).

## 11. Testing & verification

- **Mock backend** lets you play the entire loop in Studio with API access off.
- `Logger.minLevel = 1` in Studio for verbose tracing.
- Suggested manual test matrix in `docs/INSTALLATION.md`.
- Because currency/fusion logic is centralized and pure, it's straightforward to
  add TestEZ unit tests around `FusionService._rollRarity` and
  `CurrencyService.trySpendShards` (roadmap).
