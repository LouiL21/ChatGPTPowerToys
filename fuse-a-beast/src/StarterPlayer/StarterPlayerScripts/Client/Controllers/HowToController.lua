--!strict
--[[
	HowToController
	The "How to Play" card shown once, the first time a player ever joins.

	Why it exists: the loop is summon → fuse two beasts → equip → fight, and the
	Fusion Chamber is the part nobody discovers on their own — it is a buy-pad on
	the floor, and a new player has no reason to suspect that two beasts combine
	into a better one. One card up front costs a few seconds and saves the whole
	mechanic.

	Why it is not a gate: it opens with the game already running behind it and a
	close box top-right, so anyone who would rather just play can dismiss it
	immediately. The server owns the "seen" flag, so it follows the player across
	devices and never shows twice.
]]

local Players = game:GetService("Players")

local Create = require(script.Parent.Parent.UI.Create)
local Theme = require(script.Parent.Parent.UI.Theme)
local UI = require(script.Parent.Parent.UI.Components)

local HowToController = {}

local gui: ScreenGui
local card: Frame?
local onDismiss: (() -> ())?
local shown = false

local STEPS = {
	{
		glyph = "🔮",
		title = "Summon a beast",
		body = "Element nodes on your plot drop shards — run over them to collect. Then walk to your Altar and spend them to call a creature.",
	},
	{
		glyph = "⚗️",
		title = "Fuse two beasts",
		body = "Buy the Fusion Chamber (first pad at your entrance). Two of the SAME beast roll a better variant: Normal → Shiny → Golden → Rainbow → Void. Two DIFFERENT beasts can climb a rarity tier — easy at the bottom, brutal at the top. Duplicates are fuel, never junk.",
	},
	{
		glyph = "🐾",
		title = "Equip a pet",
		body = "Your best beast follows you around and is your fighter. Beasts living in your sanctuary drop essence orbs — the rarer the beast, the bigger the orb.",
	},
	{
		glyph = "⚔️",
		title = "Win the Arena",
		body = "Ten bosses, plus duels with other players. Power comes only from what you collect and fuse — never from the shop — so the Arena is a test of your roster.",
	},
	{
		glyph = "♾️",
		title = "The long game",
		body = "68 species is the FIRST goal, not the last — every one can be held at five variants, so the full collection is 340 entries. Secrets are a genuine chase: two Mythics have about a 1-in-70 shot at one.",
	},
	{
		glyph = "🏛️",
		title = "Grow",
		body = "Buy-pads unlock nodes, habitat space, your Cottage and the Beast Barn. Check the Altar daily: a different element is FEATURED each day and summons using it roll on much better luck.",
	},
}

function HowToController.init()
	gui = Create("ScreenGui", {
		Name = "FaBHowTo",
		ResetOnSpawn = false,
		DisplayOrder = 8,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	}) :: ScreenGui
end

function HowToController.close()
	if card then
		card:Destroy()
		card = nil
	end
	if onDismiss then
		onDismiss()
		onDismiss = nil
	end
end

--[[
	Builds and shows the card. `dismissed` fires once when it closes, so the
	caller can tell the server. Safe to call again later (a Help button) — it
	just rebuilds.
]]
function HowToController.open(dismissed: (() -> ())?)
	HowToController.close()
	onDismiss = dismissed

	-- Dim the world behind it so the card reads as a takeover, without hiding
	-- the game entirely.
	local shade = Create("Frame", {
		Name = "Shade",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 6, 16),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		Parent = gui,
	}) :: Frame

	local panel = Create("Frame", {
		Name = "HowToCard",
		Size = UDim2.fromOffset(470, 520),
		Position = UDim2.new(0.5, 0, 0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0.5),
		BackgroundColor3 = Theme.bg,
		BorderSizePixel = 0,
		Parent = shade,
	}) :: Frame
	UI.corner(Theme.radius, panel)
	UI.stroke(panel)
	UI.gradient(panel, Theme.panel, Theme.bg)
	card = shade

	-- Header, with the close box top-right.
	local header = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 58),
		BackgroundColor3 = Theme.panel,
		BorderSizePixel = 0,
		Parent = panel,
	})
	UI.corner(Theme.radius, header)
	UI.gradient(header, Theme.panelLight, Theme.panel)
	-- Square off the header's lower corners so it reads as a bar.
	Create("Frame", {
		Size = UDim2.new(1, 0, 0, Theme.radius),
		Position = UDim2.new(0, 0, 1, -Theme.radius),
		BackgroundColor3 = Theme.panel,
		BorderSizePixel = 0,
		Parent = header,
	})
	local rule = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 3),
		Position = UDim2.new(0, 0, 1, -3),
		BackgroundColor3 = Theme.gold,
		BorderSizePixel = 0,
		Parent = header,
	})
	UI.gradient(rule, Theme.goldLight, Theme.gold)

	UI.label("How to Play", {
		Size = UDim2.new(1, -70, 1, -3),
		Position = UDim2.fromOffset(20, 0),
		Font = Theme.fontDisplay,
		TextSize = 24,
		TextColor3 = Theme.goldLight,
		Parent = header,
	})

	local close = UI.button("✕", Theme.red, {
		Size = UDim2.fromOffset(40, 36),
		Position = UDim2.new(1, -52, 0, 11),
		TextSize = 18,
		Parent = header,
	})
	close.MouseButton1Click:Connect(HowToController.close)

	-- Steps.
	local body = Create("ScrollingFrame", {
		Size = UDim2.new(1, -24, 1, -134),
		Position = UDim2.fromOffset(12, 66),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.accentLight,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = panel,
	}) :: ScrollingFrame
	Create("UIListLayout", {
		Padding = UDim.new(0, 10),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = body,
	})

	for index, step in ipairs(STEPS) do
		-- AutomaticSize lets a row grow to fit its text, so a long step never
		-- gets clipped on a narrow phone screen.
		local row = UI.surface({
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			BackgroundColor3 = Theme.panel,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Parent = body,
		}, false)

		UI.label(step.glyph, {
			Size = UDim2.fromOffset(44, 44),
			Position = UDim2.fromOffset(8, 8),
			TextSize = 24,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = row,
		})
		UI.label(string.format("%d.  %s", index, step.title), {
			Size = UDim2.new(1, -70, 0, 22),
			Position = UDim2.fromOffset(56, 10),
			Font = Theme.fontDisplay,
			TextSize = 16,
			TextColor3 = Theme.accentLight,
			Parent = row,
		})
		UI.label(step.body, {
			Size = UDim2.new(1, -70, 0, 0),
			Position = UDim2.fromOffset(56, 34),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextSize = 13,
			TextColor3 = Theme.textMuted,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = row,
		})
		-- Bottom padding, since the label's AutomaticSize drives the row height.
		Create("UIPadding", { PaddingBottom = UDim.new(0, 12), Parent = row })
	end

	local play = UI.button("LET'S GO", Theme.green, {
		Size = UDim2.new(1, -24, 0, 52),
		Position = UDim2.new(0, 12, 1, -62),
		TextSize = 20,
		Parent = panel,
	})
	play.MouseButton1Click:Connect(HowToController.close)

	UI.tweenIn(panel)
end

--[[
	Called on every state update. Opens the card exactly once, the first time we
	learn this player has never seen it.

	The `shown` latch matters: state updates arrive constantly, and without it a
	player who ignores the card would get a fresh copy every push.
]]
function HowToController.consider(data, dismissed: () -> ())
	if shown or data.tutorialSeen ~= false then
		return
	end
	shown = true
	HowToController.open(dismissed)
end

return HowToController
