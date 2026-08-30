# 🧭 The Idiot-Proof Setup Guide
### From "I'm chatting in Discord" to a live Roblox game

No prior coding knowledge assumed. Follow the steps in order. Every command is
copy-paste. If a step doesn't apply to you, skip it.

---

## 0. What you actually have right now

- You've been talking to me (Claude) **in Discord**.
- I wrote the game and pushed it to **GitHub**, into your repository
  `LouiL21/ChatGPTPowerToys`, on a branch called
  `claude/roblox-game-research-dev-eealuv`.
- The game lives in the **`fuse-a-beast/` folder** of that repo. (The rest of the
  repo is your unrelated ChatGPTPowerToys project — leave it alone.)
- A **Pull Request** is open so you can review everything in one place on GitHub.

**The journey:** GitHub (the cloud) → your computer → Roblox Studio → Roblox (published).
Roblox has no "import from GitHub" button, so we bridge them with a free tool
called **Rojo**. That's the only slightly-technical part, and I'll hold your hand.

You'll need two free accounts: a **GitHub** account (you have one) and a **Roblox**
account.

---

## 1. Get the code onto your computer

**Easiest way (no command line): GitHub Desktop**

1. Download **GitHub Desktop**: https://desktop.github.com/ — install it, sign in
   with your GitHub account.
2. `File → Clone repository → URL` → paste:
   `https://github.com/LouiL21/ChatGPTPowerToys` → choose a folder → **Clone**.
3. In GitHub Desktop, click the **Current Branch** dropdown at the top and pick
   `claude/roblox-game-research-dev-eealuv`.
4. Done. On disk you now have a folder `ChatGPTPowerToys/fuse-a-beast/`. That
   `fuse-a-beast` folder is the game.

> Even simpler (but no updates later): on the GitHub PR page, `Code → Download ZIP`,
> and unzip it. GitHub Desktop is better because you can pull my future changes.

---

## 2. Install Roblox Studio

1. Go to https://create.roblox.com/ → **Start Creating** → it downloads **Roblox
   Studio**. Install and sign in with your Roblox account.
2. Open Studio once, create a **New → Baseplate**, just to confirm it works. Leave
   it open for the next step.

---

## 3. Install Rojo (the GitHub → Studio bridge)

I recommend the **VS Code path** because it has buttons instead of typing.

1. Install **VS Code** (free): https://code.visualstudio.com/
2. Open VS Code → Extensions (the square icon on the left) → search **"Rojo"**
   (by *evaera*) → **Install**.
3. Install the **Rojo Studio plugin**: in Studio, top menu **Plugins → Manage
   Plugins → find/Install "Rojo"**, OR get it from
   https://create.roblox.com/store/asset/... (search "Rojo" in the Creator Store).
   The VS Code extension can also install the plugin for you from its menu.
4. In VS Code: `File → Open Folder` → open the **`fuse-a-beast`** folder (open the
   game folder itself, not the whole repo).
5. Press `Ctrl+Shift+P` (Cmd+Shift+P on Mac) → type **"Rojo: Open Menu"** → click
   **Serve** (VS Code will offer to install the Rojo tool the first time — say
   yes). You should see "Rojo server listening on port 34872".
6. Switch to **Roblox Studio** → open the **Rojo** plugin toolbar → **Connect**.
   The whole game tree syncs into your open baseplate.

**Press the Play button (▶) in Studio.** You should land on your own sanctuary
with the **How to Play** card open. Close it, run over a few shard drops, walk to
the **Altar** and summon a beast. 🎉

> The How to Play card only shows on a player's *first ever* join. To see it
> again, press the **?** next to the resource bar.

> **Prefer no live-sync, just want to see it once?** Instead of steps 5-6, run this
> in a terminal opened at the `fuse-a-beast` folder:
> ```
> rojo build -o FuseABeast.rbxlx
> ```
> Then double-click `FuseABeast.rbxlx` to open it in Studio. (You still need Rojo
> installed — the VS Code extension installs it, or grab the binary from
> https://github.com/rojo-rbx/rojo/releases.)

---

## 4. Publish it to Roblox (as PRIVATE first)

1. In Studio: `File → Publish to Roblox As…`
2. Click **Create new Experience**, give it a name (e.g. "Fuse a Beast"), pick a
   genre → **Create/Publish**.
3. Make sure it's **private** while you set things up: on the **Creator Hub**
   (https://create.roblox.com/) → your experience → **Configure → Permissions/
   Playability → Private** (only you). Flip to **Public** only when you're ready to
   launch.

---

## 5. Turn on data saving (DataStores)

The game auto-detects this. To make player progress actually save:

1. Studio → **Home → Game Settings → Security** → toggle **Enable Studio Access to
   API Services** → Save.
2. Make sure the place is **published** (step 4). Persistence needs a real place id.

Without this, the game still runs but uses temporary memory (progress resets on
server restart) — fine for testing.

---

## 6. Set up monetization (make it earn Robux)

All prices are pre-designed; you just need to create the items and paste their ids.

**Gamepasses & Developer Products:**
1. Creator Hub → your experience → **Monetization → Passes** (and **Developer
   Products**) → **Create**. Create one for each entry in
   `fuse-a-beast/src/ReplicatedStorage/Shared/Config/MonetizationConfig.lua`
   (names + suggested prices are already in that file).
2. After creating each, copy its **id** and paste it over the `id = 0` placeholder
   in that config file. Example:
   ```lua
   DoubleEssence = { id = 111222333, price = 199, name = "2x Essence", ... },
   ```
3. Save → Rojo syncs → republish (`File → Publish to Roblox` again).

**Badges (for achievements):**
- Creator Hub → your experience → **Badges → Create Badge** (one per entry in
  `QuestConfig.lua` `Achievements`). Paste each badge id into `badgeId = 0`.

> Leaving ids at `0` is safe — those items just show as "not available yet" and
> nothing breaks.

---

## 7. Add an icon and thumbnail (do this before going public)

- Creator Hub → your experience → **Configure → Icon** (512×512) and
  **Thumbnails** (1920×1080). See `docs/ASSETS.md` for the full art plan. You can
  launch with just these two images and add beast art later.

---

## 8. Test, then go live

1. Playtest in Studio (Play button) and with **Play → Start (2 players)** to test
   multiplayer.
2. Walk the test checklist in `docs/INSTALLATION.md`.
3. When happy: Creator Hub → **Configure → Playability → Public**. You're live.
4. Post it, share the discovery moments, and start the **weekly update** rhythm
   (add beasts/recipes — pure config edits — see the GDD roadmap).

---

## 9. Pulling my future changes

If I (or you) push more updates to the branch:
- GitHub Desktop → **Fetch/Pull origin** → your local `fuse-a-beast` updates.
- Rojo is still serving → Studio picks up the changes live. Republish to push them
  to players.

---

## Where everything lives (cheat sheet)

| I want to change… | Edit this file |
|---|---|
| Rates, costs, caps, drop odds | `src/ReplicatedStorage/Shared/Config/GameConfig.lua` |
| Beasts (add/rename/rarity/art) | `src/ReplicatedStorage/Shared/Config/BeastConfig.lua` |
| Elements | `src/ReplicatedStorage/Shared/Config/ElementConfig.lua` |
| Signature "recipe" combos | `src/ReplicatedStorage/Shared/Config/RecipeConfig.lua` |
| Gamepass/product ids & prices | `src/ReplicatedStorage/Shared/Config/MonetizationConfig.lua` |
| Quests, login streak, badge ids | `src/ReplicatedStorage/Shared/Config/QuestConfig.lua` |

You almost never need to touch anything outside `Config/` for content updates.

---

## If you get stuck

| Symptom | Fix |
|---|---|
| Studio Rojo plugin won't connect | Make sure VS Code shows "Rojo server listening"; both must be on the same PC; port `34872`. |
| "Rojo not found" in VS Code | Run the extension's install-Rojo prompt, or download the binary from the Rojo releases page and restart VS Code. |
| Game runs but nothing saves | Do step 5 (Enable API Services) **and** publish the place. |
| Shop items say "not available yet" | You haven't set real ids in `MonetizationConfig.lua` (step 6). Expected until you do. |
| Changed a file, nothing happened | Rojo must be **serving** and **connected**; save the file; check the Studio Rojo panel says "Connected". |
| I broke something | GitHub Desktop → **Discard changes**, or re-pull my branch. |

That's it — you've gone from a Discord chat to a publishable Roblox game.
