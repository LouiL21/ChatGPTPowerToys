# UI Design Mockups

Visual design for the Fuse a Beast interface. These are **source mockups**, not
game code — they define the look that `UIController.lua` should implement.

**Live canvas:** https://claude.ai/code/artifact/709e9e34-5754-448d-95fc-3194a36bca35

> When updating the canvas, publish with that `url` so the link stays the same.

## Why this exists

The v0.1 build is mechanically complete but visually reads like a settings menu:
flat dark panels, plain text rows, no focal point. On Roblox that is the
difference between a game people bounce off and one they play. These mockups
restyle the *same information* into a game: a glowing Altar hero, chunky tactile
shard tiles, and a discovery reveal loud enough to screenshot.

## Files

| File | What it is |
|---|---|
| `Main.dc.html` | Core screen — Altar hero, shard picker, FUSE, bottom nav |
| `Discovery.dc.html` | The reveal moment (the shareable/viral screen) |
| `Beastdex.dc.html` | Collection grid with locked slots + Sanctuary boost |
| `Shop.dc.html` | Monetization — featured VIP, gamepasses, boosts |
| `DirectionBright.dc.html` | Low-fi alternate direction: bright & friendly |
| `DirectionNeon.dc.html` | Low-fi alternate direction: neon arcade |
| `canvas.json` | Canvas layout, pages, annotations |

`fuse-a-beast-ui.html` is the **generated** canvas (~2.5 MB) — it is rebuilt from
the files above and is git-ignored.

## Design tokens

Element and rarity colors are unchanged from `ElementConfig.lua` /
`UIController.lua` — they are semantic and already correct. What changed is the
treatment around them.

| Token | Value | Use |
|---|---|---|
| Background | `#0c0916` → `#2e2459` radial | Deep indigo base |
| Panel | `#2f2757` → `#241d45` | Cards, pills, nav |
| Stroke | `#0a0713` | 3px outline on every element (the "chunky" read) |
| Accent | `#7c3aed` / `#a78bfa` | Primary action, active nav |
| Gold | `#ffc44d` / `#ffd782` | Essence, premium, rate |
| Gem | `#5ad9f0` | Gems currency |
| Text / muted | `#f4f1ff` / `#9c93bd` | Copy |

Type: **Fredoka** (display, numbers, buttons) + **Nunito** (body). Roblox has no
web fonts — implement with `Enum.Font.FredokaOne` / `GothamBold` as the closest
built-in equivalents, or upload the faces as custom fonts.

Key patterns to carry into Lua:
- 3px near-black stroke + `0 3-5px 0` hard shadow on every interactive element
  (gives the tactile "pressable" feel).
- 15-19px corner radii.
- Selected state = white ring + reduced drop shadow (reads as pressed).
- Rarity communicated by frame color + glow, never text alone.

## Status

Direction not yet chosen. Page 1 is the leading direction ("Arcane Workshop");
page 2 holds two alternates. Once picked, implement into
`src/StarterPlayer/StarterPlayerScripts/Client/Controllers/UIController.lua`.
