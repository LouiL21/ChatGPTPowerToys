# assets/

Source art for Fuse a Beast. **The game runs without anything in here** — the UI
is code-built and beasts use rarity-colored placeholders until you add art.

See [`../docs/ASSETS.md`](../docs/ASSETS.md) for the full manifest, specs, upload
steps, and how to wire asset ids into config.

Suggested layout:

```
assets/
├── beasts/     # <beastId>.png  (256×256, transparent) — matches BeastConfig ids
├── elements/   # fire.png, water.png, …  (128×128, transparent)
├── ui/         # optional UI art / logo
└── sound/      # fuse.ogg, discover.ogg, rare_fanfare.ogg, button.ogg, ambient.ogg
```

Keep each filename equal to its config `id` so the mapping is obvious. Upload to
Roblox (Creator Hub / Studio Asset Manager), then paste the resulting
`rbxassetid://…` into the matching config entry.
