--!strict
--[[
	Theme
	Single source of truth for the interface's look — the "Arcane Workshop"
	direction from the design canvas.

	Everything is chunky and tactile: thick near-black strokes, a hard drop
	shadow under each surface, generous radii. That reads as a game rather than a
	settings menu, which was the whole problem with the first pass.
]]

local Theme = {}

-- ── Palette ───────────────────────────────────────────────────────────────
Theme.bg = Color3.fromRGB(16, 14, 28)
Theme.panel = Color3.fromRGB(34, 29, 58)
-- Neutral BUTTON fill. This used to double as a panel tint, which made every
-- "secondary" button — Beasts, Pets, Quests — nearly the same colour as the
-- surface behind it, so half the menu read as decoration rather than something
-- you could press. It is now clearly lighter than any panel it sits on.
Theme.panelLight = Color3.fromRGB(92, 79, 156)
Theme.stroke = Color3.fromRGB(8, 6, 16) -- the thick outline on everything
-- A light rim drawn INSIDE a control's top edge. Buttons read as raised because
-- they catch light on top and sit on a dark shadow below; without it, a flat
-- fill on a dark ground just looks like a coloured rectangle.
Theme.rim = Color3.fromRGB(255, 255, 255)
Theme.accent = Color3.fromRGB(139, 74, 248)
Theme.accentLight = Color3.fromRGB(184, 158, 255)
Theme.gold = Color3.fromRGB(255, 190, 62)
Theme.goldLight = Color3.fromRGB(255, 219, 140)
Theme.cyan = Color3.fromRGB(96, 224, 246)
Theme.green = Color3.fromRGB(84, 206, 98)
Theme.red = Color3.fromRGB(234, 68, 88)
Theme.text = Color3.fromRGB(248, 246, 255)
Theme.textMuted = Color3.fromRGB(178, 170, 208)

Theme.rarity = {
	Common = Color3.fromRGB(180, 180, 180),
	Uncommon = Color3.fromRGB(90, 200, 100),
	Rare = Color3.fromRGB(70, 140, 240),
	Epic = Color3.fromRGB(170, 90, 240),
	Legendary = Color3.fromRGB(245, 180, 40),
	Mythic = Color3.fromRGB(240, 70, 120),
	Secret = Color3.fromRGB(255, 255, 255),
	Boss = Color3.fromRGB(255, 120, 60),
}

Theme.variant = {
	Normal = Color3.fromRGB(220, 220, 230),
	Shiny = Color3.fromRGB(150, 230, 255),
	Golden = Color3.fromRGB(255, 196, 77),
	Rainbow = Color3.fromRGB(255, 120, 200),
	Void = Color3.fromRGB(150, 80, 255),
}

Theme.element = {
	Fire = Color3.fromRGB(230, 77, 41),
	Water = Color3.fromRGB(51, 140, 242),
	Earth = Color3.fromRGB(140, 102, 56),
	Air = Color3.fromRGB(191, 217, 242),
	Nature = Color3.fromRGB(77, 191, 89),
	Void = Color3.fromRGB(115, 51, 166),
}

-- ── Type ──────────────────────────────────────────────────────────────────
-- FredokaOne is the closest built-in Roblox font to the mockup's display face.
Theme.fontDisplay = Enum.Font.FredokaOne
Theme.fontBody = Enum.Font.GothamMedium
Theme.fontBold = Enum.Font.GothamBold

-- ── Metrics ───────────────────────────────────────────────────────────────
Theme.radius = 14
Theme.radiusSmall = 11
Theme.strokeWidth = 3
Theme.buttonStroke = 4 -- heavier outline on things you can press
Theme.shadowOffset = 5 -- the hard "lift" under buttons and panels
Theme.pressDepth = 4 -- how far a button sinks when held

return Theme
