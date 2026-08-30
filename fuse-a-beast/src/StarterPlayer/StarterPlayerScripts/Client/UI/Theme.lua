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
Theme.panel = Color3.fromRGB(30, 26, 51)
Theme.panelLight = Color3.fromRGB(47, 39, 87)
Theme.stroke = Color3.fromRGB(10, 7, 19) -- the thick outline on everything
Theme.accent = Color3.fromRGB(124, 58, 237)
Theme.accentLight = Color3.fromRGB(167, 139, 250)
Theme.gold = Color3.fromRGB(255, 196, 77)
Theme.goldLight = Color3.fromRGB(255, 215, 130)
Theme.cyan = Color3.fromRGB(90, 217, 240)
Theme.green = Color3.fromRGB(77, 191, 89)
Theme.red = Color3.fromRGB(224, 62, 82)
Theme.text = Color3.fromRGB(244, 241, 255)
Theme.textMuted = Color3.fromRGB(156, 147, 189)

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
Theme.radiusSmall = 10
Theme.strokeWidth = 3
Theme.shadowOffset = 4 -- the hard "lift" under buttons and panels

return Theme
