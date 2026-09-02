# Asset Manifest & Pipeline

> "Take a look at the assets used in the game." Here's the honest picture plus a
> complete plan for adding real art.

## TL;DR — the game currently uses ZERO external art assets

By design. The entire UI is **built in code** (colored frames + text) and beasts
are shown with **rarity-colored placeholders**. This is why the project runs the
moment you press Play — no uploads, no broken image ids, nothing to moderate.

That's a deliberate MVP choice, and it's *shippable* (plenty of top Roblox sims
launched with minimal art). Art is then added **incrementally**, highest-impact
first, without touching gameplay code — every art hook is an **optional config
field**.

## What art the game *can* use (all optional, all plug-in)

| Asset | Count | Where it plugs in | Shown when |
|---|---|---|---|
| **Beast icons** (square portraits) | 68 | `BeastConfig.lua` → `icon = "rbxassetid://…"` | Beastdex rows (auto-renders an `ImageLabel` if set) |
| **Beast models** (3D) | 68 | `BeastConfig.lua` → `model = "rbxassetid://…"` | Sanctuary display (spawning is a **v0.2** feature) |
| **Element icons** | 6 | `ElementConfig.lua` → `icon = "rbxassetid://…"` | Fusion element buttons (wire-up is a small follow-up) |
| **Game icon** | 1 | Creator Hub (not config) | Experience thumbnail on Roblox |
| **Thumbnails/banners** | 3-5 | Creator Hub (not config) | Experience page |
| **Gamepass/product icons** | 13 | Creator Hub, per item | Store prompts |
| **Sounds** (fuse, discover, button, ambient, rare-fanfare) | ~5 | `SoundService` (audio hooks are **roadmap**) | Fusion/discovery moments |
| **Badge icons** | 7 | Creator Hub, per badge | Achievements |

> Nothing above is required to launch a playable build. The color-coded system is
> the fallback everywhere.

## Recommended specs

- **Beast icons:** 256×256 PNG, transparent background, consistent framing/margins
  so the roster looks like one set. A rarity-tinted border helps readability.
- **Element icons:** 128×128 PNG, transparent, single clear silhouette.
- **Game icon:** 512×512 PNG (Roblox requirement).
- **Thumbnails:** 1920×1080 PNG/JPG.
- **Models:** low-poly, mobile-friendly (< ~2k tris each); Roblox `Model` with a
  `PrimaryPart` set.
- **Sounds:** short (< 3s) OGG/MP3; keep total memory modest for mobile.

## Where to get the art

1. **Commission artists** (Roblox art is a large freelance market) — best quality,
   consistent style.
2. **AI-generated art** — allowed for your own use, but **everything you upload is
   moderated by Roblox** and must follow their content rules; review before upload.
3. **Roblox Creator Store / Toolbox** — free & paid models/decals. Vet licenses
   and quality; avoid low-effort free models for a flagship.
4. **Make your own** in Blender/Studio for models, any 2D tool for icons.

## How to upload to Roblox (get an asset id)

**Images/decals & audio:**
- Roblox **Creator Hub** → *Creations* → your experience → *Development Items* →
  **Images / Audio**, or in **Studio → Asset Manager** → right-click → *Add Images…*
  (bulk import supported).
- Each upload is **moderated** (minutes to hours) and then gets an **asset id**.
- The usable string is `rbxassetid://<id>` (for images use the **image/decal** id).

**Models:**
- In Studio, select the model → right-click → *Save to Roblox…* (or publish as a
  package). You get an asset id you can `InsertService:LoadAsset` or reference.

## How to wire an id into the game

Open `src/ReplicatedStorage/Shared/Config/BeastConfig.lua`, find the beast, add the
field:

```lua
{ id = "solarphoenix", name = "Solar Phoenix", rarity = "Mythic",
  elements = { "Fire", "Air", "Void" },
  icon = "rbxassetid://123456789",       -- ← paste your uploaded image id
  model = "rbxassetid://987654321" },    -- ← optional, for v0.2 Sanctuary display
```

Elements are the same pattern in `ElementConfig.lua` (`icon = …`). Save; Rojo
syncs; the Beastdex row now shows the portrait automatically. **No gameplay code
changes needed.**

## Suggested rollout (priority tiers)

- **P0 (before publishing):** game icon + 1 good thumbnail. Required for a decent
  store page.
- **P1 (week 1):** 6 element icons + icons for the ~10 "hero" beasts (the Secrets,
  Mythics, and the signature-recipe payoffs people screenshot). These are your
  marketing images.
- **P2 (weeks 2-4):** remaining beast icons, in rarity order (rarest first).
- **P3 (v0.2+):** beast models for the Sanctuary + a small sound set.

## Naming & organization convention

- Store source art in this repo under `assets/` (e.g. `assets/beasts/solarphoenix.png`,
  `assets/elements/fire.png`, `assets/ui/`, `assets/sound/`). Source art *may* be
  committed; only compiled Roblox binaries are `.gitignore`d.
- Keep the filename == the config `id` so it's obvious which image maps to which
  beast.
- Track uploaded ids in the config (that's the source of truth) — no separate
  spreadsheet needed.

## Note on repo root `demo.gif`

The `demo.gif` in the repository **root** belongs to the unrelated ChatGPTPowerToys
project, not Fuse a Beast. Ignore it for this game.
