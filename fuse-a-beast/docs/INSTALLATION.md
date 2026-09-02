# Installation & Running

Fuse a Beast is a **Rojo** project: source lives as `.lua` files in git and syncs
into Roblox Studio. Nothing is stored as a binary `.rbxlx`, so everything is
diffable.

## Prerequisites

- [Roblox Studio](https://create.roblox.com/)
- [Rojo](https://rojo.space/) 7.x — the Studio plugin **and** the CLI/VS Code
  extension.
- (Optional, recommended for launch) [Aftman](https://github.com/LPGhatguy/aftman)
  or [Rokit](https://github.com/rojo-rbx/rokit) to manage toolchains, and
  [Wally](https://wally.run/) for `ProfileStore`.

## Quick start (5 minutes)

1. **Install Rojo**
   ```bash
   # via Aftman/Rokit (recommended)
   aftman add rojo-rbx/rojo
   aftman install
   # or via cargo
   cargo install rojo
   ```
2. **Serve the project** from the `fuse-a-beast/` folder:
   ```bash
   cd fuse-a-beast
   rojo serve
   ```
3. **In Roblox Studio:** open a new baseplate → open the **Rojo** plugin →
   **Connect** (default `localhost:34872`). The `src/` tree syncs into the
   DataModel per `default.project.json`.
4. **Press Play.** You'll spawn with a starter kit — pick 2 elements, press
   **FUSE**, and discover your first beast.

> No API access needed to test: with DataStores unavailable, the game
> automatically uses the in-memory `MockBackend` (data won't persist across
> restarts, but the full loop is playable).

## Enabling real data persistence

- In Studio: **Game Settings → Security → Enable Studio Access to API Services**.
- Publish the place (persistence requires a published place id).
- The game auto-detects DataStores and switches to the session-locked
  `DataStoreBackend`.

## Using ProfileStore (recommended for launch)

1. Install Wally and run `wally install` in `fuse-a-beast/` (adds `Packages/`).
2. Add a `Packages` mapping to `default.project.json` under `ReplicatedStorage`
   (it's omitted by default so Rojo never looks for a folder that isn't there):
   ```json
   "Packages": { "$path": { "optional": "Packages" } }
   ```
3. Point `DataService` at ProfileStore behind the existing backend interface
   (`load` / `save` / `release`). The abstraction is in
   `src/ServerScriptService/Server/Data/Backends/`.

## Configuring monetization & badges

All asset ids are `0` placeholders. Before publishing:

1. Create gamepasses & developer products in the **Creator Hub**.
2. Put their asset ids into
   `src/ReplicatedStorage/Shared/Config/MonetizationConfig.lua`.
3. Create badges and set their ids in
   `src/ReplicatedStorage/Shared/Config/QuestConfig.lua` (`Achievements[].badgeId`).

## Manual test matrix

| Area | Steps | Expect |
|---|---|---|
| Onboarding | Join fresh | Starter kit toast; can fuse immediately |
| Fusion | Fuse Fire+Water | Charges shards/essence; result popup; codex updates |
| Discovery | Fuse a new combo | "NEW DISCOVERY" popup; gems awarded |
| Idle | Wait; watch top bar | Essence ticks up smoothly; shards accrue |
| Offline | Leave + rejoin (real DataStore) | "Welcome back" summary |
| Display | Beastdex → Display a beast | Rate increases |
| Merge | Get duplicates → Merge | Beast level up; rate increases |
| Quests | Quests panel | 3 dailies + login streak; Claim works |
| Altar | Nav → Altar | Essence spent; rate up |
| Ascend | Reach requirement → Ascend | Reset + permanent bonus |
| Shop | Shop panel → buy | Purchase prompt (once ids are set) |
| Anti-exploit | Spam Fuse | Excess calls dropped by the rate limiter |

## Tuning

Everything is data-driven — edit `src/ReplicatedStorage/Shared/Config/`:
- `GameConfig.lua` — rates, costs, caps, rate limits, rarity weights.
- `BeastConfig.lua` / `ElementConfig.lua` / `RecipeConfig.lua` — content.
- `MonetizationConfig.lua` / `QuestConfig.lua` — offers, quests, streaks.

Set `Logger.minLevel = 1` (in `Util/Logger.lua`) for verbose tracing in Studio.
