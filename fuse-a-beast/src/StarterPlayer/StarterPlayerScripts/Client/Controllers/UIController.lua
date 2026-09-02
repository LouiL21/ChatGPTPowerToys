--!strict
--[[
	UIController
	Builds and drives the interface: a compact HUD plus modal panels for Summon,
	Chamber, Sanctuary, Beastdex, Pets, Arena, Quests and Shop.

	Two principles carried over from the design pass:
	  1. The world is the way in. The Altar, Chamber and Barn all open by walking
	     up to the building; the HUD stays small so you can see the game.
	  2. Everything is chunky and tactile (Components), because a flat dark
	     dashboard is what made the first build feel like a menu, not a game.

	The client only ever *requests*; the server replies with a StateUpdate that
	this controller renders.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local GameConfig = require(Shared.Config.GameConfig)
local ElementConfig = require(Shared.Config.ElementConfig)
local BeastConfig = require(Shared.Config.BeastConfig)
local VariantConfig = require(Shared.Config.VariantConfig)
local CombatConfig = require(Shared.Config.CombatConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local QuestConfig = require(Shared.Config.QuestConfig)
local PlotConfig = require(Shared.Config.PlotConfig)
local BeastInventory = require(Shared.Util.BeastInventory)
local Format = require(Shared.Util.Format)

local ClientState = require(script.Parent.Parent.ClientState)
local Create = require(script.Parent.Parent.UI.Create)
local Theme = require(script.Parent.Parent.UI.Theme)
local UI = require(script.Parent.Parent.UI.Components)

local UIController = {}

local refs: { [string]: any } = {}
local panels: { [string]: Frame } = {}
local bodies: { [string]: ScrollingFrame } = {}
local selectedElements: { string } = {}
local chamberSlots: { any } = {} -- up to two { beastId, variant } picks

local function rarityColor(rarity: string): Color3
	return Theme.rarity[rarity] or Theme.textMuted
end

local function beastLabel(beastId: string, variant: string): string
	local beast = BeastConfig.ById[beastId]
	if not beast then
		return "?"
	end
	return VariantConfig.label(variant, beast.name)
end

-- ── HUD ───────────────────────────────────────────────────────────────────

local function buildHud(gui: Instance)
	local bar = UI.surface({
		Name = "TopBar",
		Size = UDim2.fromOffset(392, 56),
		Position = UDim2.new(0.5, -196, 0, 10),
		BackgroundColor3 = Theme.panel,
		BorderSizePixel = 0,
		Parent = gui,
	})
	UI.gradient(bar, Theme.panelLight, Theme.panel)
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		Parent = bar,
	})

	-- Each stat is its own inset chip. A row of bare numbers reads as debug
	-- output; three framed chips read as a game HUD.
	local function stat(name: string, glyph: string, color: Color3, width: number)
		local holder = UI.surface({
			Size = UDim2.fromOffset(width, 42),
			BackgroundColor3 = Theme.bg,
			BorderSizePixel = 0,
			Parent = bar,
		}, false)
		UI.label(glyph, {
			Size = UDim2.fromOffset(24, 42),
			Position = UDim2.fromOffset(8, 0),
			TextSize = 17,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = holder,
		})
		refs[name] = UI.label("0", {
			Size = UDim2.new(1, -38, 0, 20),
			Position = UDim2.fromOffset(34, 3),
			Font = Theme.fontDisplay,
			TextSize = 18,
			TextColor3 = color,
			Parent = holder,
		})
		UI.label(string.upper(name), {
			Size = UDim2.new(1, -38, 0, 12),
			Position = UDim2.fromOffset(34, 25),
			Font = Theme.fontBold,
			TextSize = 9,
			TextColor3 = Theme.textMuted,
			Parent = holder,
		})
	end
	stat("Essence", "✦", Theme.goldLight, 140)
	stat("Gems", "◆", Theme.cyan, 92)
	stat("Rate", "⟳", Theme.accentLight, 110)

	-- Reopen How to Play. Tucked beside the resource bar rather than in the nav:
	-- it is a one-off read, not a destination, and the nav is already full.
	local help = UI.button("?", Theme.panelLight, {
		Name = "Help",
		Size = UDim2.fromOffset(38, 38),
		Position = UDim2.new(0.5, 210, 0, 18),
		TextSize = 20,
		Parent = gui,
	})
	help.MouseButton1Click:Connect(function()
		if refs.helpAction then
			refs.helpAction()
		end
	end)

	-- Active pet card, bottom-left: your fighter, always visible.
	local petCard = UI.surface({
		Name = "PetCard",
		Size = UDim2.fromOffset(196, 66),
		Position = UDim2.new(0, 12, 1, -170),
		BackgroundColor3 = Theme.panel,
		BorderSizePixel = 0,
		Parent = gui,
	})
	refs.petName = UI.label("No pet", {
		Size = UDim2.new(1, -16, 0, 20),
		Position = UDim2.fromOffset(12, 9),
		Font = Theme.fontDisplay,
		TextSize = 15,
		Parent = petCard,
	})
	refs.petPower = UI.label("Summon a beast!", {
		Size = UDim2.new(1, -16, 0, 16),
		Position = UDim2.fromOffset(12, 31),
		TextSize = 12,
		TextColor3 = Theme.textMuted,
		Parent = petCard,
	})
end

-- The client bootstrap owns HowToController, so it hands the "?" action in here
-- rather than UIController reaching across into another controller.
function UIController.setHelpAction(action: () -> ())
	refs.helpAction = action
end

local function buildNav(gui: Instance)
	-- A dark tray behind the row. Eight bright keys floating over the world were
	-- hard to pick out against a lit sanctuary; a ground to sit on gives every
	-- button the same contrast partner whatever is behind it.
	local tray = UI.surface({
		Name = "NavTray",
		Size = UDim2.fromOffset(766, 84),
		Position = UDim2.new(0.5, -383, 1, -94),
		BackgroundColor3 = Theme.bg,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Parent = gui,
	}, false)

	local nav = Create("Frame", {
		Name = "Nav",
		Size = UDim2.new(1, -12, 1, -12),
		Position = UDim2.fromOffset(6, 6),
		BackgroundTransparency = 1,
		Parent = tray,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 6),
		Parent = nav,
	})

	local specs = {
		{ glyph = "🔮", text = "Summon", color = Theme.accent, panel = "Summon" },
		{ glyph = "⚗️", text = "Chamber", color = Theme.rarity.Mythic, panel = "Chamber" },
		-- The Altar entry was lost when the HUD was rebuilt, which left the whole
		-- upgrade and Ascension ladder unreachable. It lives here permanently now.
		{ glyph = "🏛️", text = "Altar", color = Theme.gold, panel = "Sanctuary" },
		{ glyph = "📖", text = "Beasts", color = Theme.panelLight, panel = "Beastdex" },
		{ glyph = "🐾", text = "Pets", color = Theme.panelLight, panel = "Pets" },
		{ glyph = "⚔️", text = "Arena", color = Theme.red, panel = "Arena" },
		{ glyph = "📋", text = "Quests", color = Theme.panelLight, panel = "Quests" },
		{ glyph = "🛒", text = "Shop", color = Theme.green, panel = "Shop" },
	}
	for _, spec in ipairs(specs) do
		local btn = UI.navButton(spec.glyph, spec.text, spec.color, {
			Size = UDim2.fromOffset(88, 66),
			Parent = nav,
		})
		btn.MouseButton1Click:Connect(function()
			UIController.open(spec.panel)
		end)
	end
end

-- ── Panels ────────────────────────────────────────────────────────────────

function UIController.open(name: string)
	for panelName, frame in pairs(panels) do
		frame.Visible = panelName == name
	end
	local frame = panels[name]
	if frame then
		UI.tweenIn(frame)
	end
	local renderer = UIController["_render" .. name]
	if renderer then
		renderer(UIController)
	end
end

function UIController.openFusion()
	UIController.open("Summon")
end

function UIController.openChamber()
	UIController.open("Chamber")
end

-- ── Summon ────────────────────────────────────────────────────────────────

function UIController:_renderSummon()
	local body = bodies.Summon
	UI.clear(body)
	local data = ClientState.data

	UI.label("Pick 1-3 elements. Rarer beasts hide behind rarer combinations.", {
		Size = UDim2.new(1, -8, 0, 34),
		TextSize = 13,
		TextColor3 = Theme.textMuted,
		TextWrapped = true,
		LayoutOrder = 1,
		Parent = body,
	})

	local grid = Create("Frame", {
		Size = UDim2.new(1, -8, 0, 168),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = body,
	})
	Create("UIGridLayout", {
		CellSize = UDim2.fromOffset(126, 78),
		CellPadding = UDim2.fromOffset(8, 8),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = grid,
	})

	for _, element in ipairs(ElementConfig.List) do
		local color = Theme.element[element.id] or Theme.textMuted
		local held = (data.shards or {})[element.id] or 0
		local isSelected = table.find(selectedElements, element.id) ~= nil

		local btn = UI.button(
			string.format("%s\n%s", element.displayName, Format.abbreviate(held)),
			color,
			{ TextSize = 14, Parent = grid }
		)
		if isSelected then
			UI.stroke(btn, 4, Color3.fromRGB(255, 255, 255))
		end
		btn.MouseButton1Click:Connect(function()
			local index = table.find(selectedElements, element.id)
			if index then
				table.remove(selectedElements, index)
			elseif #selectedElements < 3 then
				table.insert(selectedElements, element.id)
			end
			self:_renderSummon()
		end)
	end

	local cost = #selectedElements * GameConfig.FUSION_SHARD_COST
	UI.label(
		#selectedElements == 0 and "Nothing selected"
			or string.format("%s  ·  %d shards each", table.concat(selectedElements, " + "), GameConfig.FUSION_SHARD_COST),
		{
			Size = UDim2.new(1, -8, 0, 22),
			TextSize = 13,
			TextColor3 = Theme.goldLight,
			TextXAlignment = Enum.TextXAlignment.Center,
			LayoutOrder = 3,
			Parent = body,
		}
	)

	local summon = UI.button("SUMMON", #selectedElements > 0 and Theme.accent or Theme.panelLight, {
		Size = UDim2.new(1, -8, 0, 54),
		TextSize = 22,
		LayoutOrder = 4,
		Parent = body,
	})
	summon.MouseButton1Click:Connect(function()
		if #selectedElements > 0 then
			Remotes.event("Fuse"):FireServer({ elements = table.clone(selectedElements) })
		end
	end)
end

-- ── Fusion Chamber ────────────────────────────────────────────────────────

function UIController:_renderChamber()
	local body = bodies.Chamber
	UI.clear(body)
	local data = ClientState.data
	local owned = BeastInventory.list(data.codex or {})
	local hasChamber = ((data.plot or {}).purchasedPads or {})["fusion_chamber"] == true

	if not hasChamber then
		UI.label("Build the Fusion Chamber on your plot to combine beasts.\nIt's the FIRST buy-pad at your sanctuary entrance.", {
			Size = UDim2.new(1, -8, 0, 60),
			TextSize = 14,
			TextColor3 = Theme.goldLight,
			TextWrapped = true,
			LayoutOrder = 1,
			Parent = body,
		})
		return
	end

	-- The two input slots.
	local slotRow = Create("Frame", {
		Size = UDim2.new(1, -8, 0, 86),
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Parent = body,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 12),
		Parent = slotRow,
	})

	for i = 1, 2 do
		local pick = chamberSlots[i]
		local slot = UI.surface({
			Size = UDim2.fromOffset(150, 78),
			BackgroundColor3 = pick and Theme.panelLight or Theme.panel,
			BorderSizePixel = 0,
			Parent = slotRow,
		}, false)
		UI.label(pick and beastLabel(pick.beastId, pick.variant) or ("Slot " .. i), {
			Size = UDim2.new(1, -12, 0, 34),
			Position = UDim2.fromOffset(8, 10),
			Font = Theme.fontDisplay,
			TextSize = 13,
			TextWrapped = true,
			TextColor3 = pick and Theme.variant[pick.variant] or Theme.textMuted,
			Parent = slot,
		})
		if pick then
			local clear = UI.button("Remove", Theme.red, {
				Size = UDim2.new(1, -16, 0, 24),
				Position = UDim2.fromOffset(8, 46),
				TextSize = 12,
				Parent = slot,
			})
			clear.MouseButton1Click:Connect(function()
				table.remove(chamberSlots, i)
				self:_renderChamber()
			end)
		end
	end

	-- Outcome preview: this is the teaching moment for the whole system.
	local a, b = chamberSlots[1], chamberSlots[2]
	local previewText, previewColor
	if not a or not b then
		previewText = "Choose two beasts below."
		previewColor = Theme.textMuted
	elseif a.beastId == b.beastId and a.variant == b.variant then
		local nextVariant = VariantConfig.next(a.variant)
		if nextVariant then
			previewText = string.format(
				"Variant fusion → %.0f%% chance of a %s %s\nA failed roll returns one unchanged — never weaker.",
				VariantConfig.get(a.variant).upgradeChance * 100,
				nextVariant,
				BeastConfig.ById[a.beastId].name
			)
			previewColor = Theme.variant[nextVariant]
		else
			previewText = "Void is the highest variant."
			previewColor = Theme.red
		end
	else
		-- Spell the floor out. A player who has been burned by a bad roll needs
		-- to see the guarantee before they will risk two good beasts again.
		local best = math.max(
			BeastInventory.stats(a.beastId, a.variant).power,
			BeastInventory.stats(b.beastId, b.variant).power
		)
		local bands = GameConfig.CHAMBER_OUTCOME
		previewText = string.format(
			"Hybrid fusion → never below %s power.\n%d%% same tier  ·  %d%% one tier up  ·  %d%% two tiers up",
			Format.abbreviate(best),
			math.floor(bands.same * 100 + 0.5),
			math.floor(bands.slightly * 100 + 0.5),
			math.floor(bands.better * 100 + 0.5)
		)
		previewColor = Theme.rarity.Mythic
	end

	UI.label(previewText, {
		Size = UDim2.new(1, -8, 0, 46),
		TextSize = 13,
		TextColor3 = previewColor,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		Parent = body,
	})

	-- The price was previously computed only on the server, so a player had no
	-- idea what a fusion would cost until it silently failed. Mirror the server's
	-- formula and put the number on the button itself.
	local essence = (data.currencies or {}).essence or 0
	local cost = 0
	if a and b then
		local tier = math.max(VariantConfig.index(a.variant), VariantConfig.index(b.variant))
		cost = math.floor(GameConfig.CHAMBER_BASE_COST * GameConfig.CHAMBER_COST_GROWTH ^ (tier - 1))
	end
	local affordable = cost > 0 and essence >= cost

	if a and b then
		UI.label(
			affordable and string.format("Cost  %s essence   (you have %s)", Format.abbreviate(cost), Format.abbreviate(essence))
				or string.format("Cost  %s essence  —  you have %s", Format.abbreviate(cost), Format.abbreviate(essence)),
			{
				Size = UDim2.new(1, -8, 0, 20),
				TextSize = 13,
				Font = Theme.fontBold,
				TextColor3 = affordable and Theme.goldLight or Theme.red,
				TextXAlignment = Enum.TextXAlignment.Center,
				LayoutOrder = 3,
				Parent = body,
			}
		)
	end

	local fuseText = "SELECT TWO BEASTS"
	if a and b then
		fuseText = affordable and string.format("FUSE  ·  %s", Format.abbreviate(cost)) or "NOT ENOUGH ESSENCE"
	end
	local fuse = UI.button(fuseText, affordable and Theme.rarity.Mythic or Theme.panelLight, {
		Size = UDim2.new(1, -8, 0, 50),
		TextSize = 20,
		LayoutOrder = 4,
		Parent = body,
	})
	fuse.MouseButton1Click:Connect(function()
		if a and b and affordable then
			Remotes.event("ChamberFuse"):FireServer({ a = a, b = b })
			chamberSlots = {}
		end
	end)

	UI.label("YOUR BEASTS", {
		Size = UDim2.new(1, -8, 0, 22),
		Font = Theme.fontBold,
		TextSize = 12,
		TextColor3 = Theme.accentLight,
		LayoutOrder = 5,
		Parent = body,
	})

	for index, item in ipairs(owned) do
		local row = UI.surface({
			Size = UDim2.new(1, -8, 0, 46),
			BackgroundColor3 = Theme.panel,
			BorderSizePixel = 0,
			LayoutOrder = 5 + index,
			Parent = body,
		}, false)
		local beast = BeastConfig.ById[item.beastId]
		UI.label(string.format("%s  ×%d", beastLabel(item.beastId, item.variant), item.count), {
			Size = UDim2.new(0.62, 0, 1, 0),
			Position = UDim2.fromOffset(12, 0),
			Font = Theme.fontBold,
			TextSize = 13,
			TextColor3 = Theme.variant[item.variant] or Theme.text,
			Parent = row,
		})
		UI.pill(beast.rarity, rarityColor(beast.rarity), {
			Position = UDim2.new(1, -190, 0.5, -11),
			Size = UDim2.fromOffset(84, 22),
			Parent = row,
		})
		local add = UI.button("Add", Theme.accent, {
			Size = UDim2.fromOffset(84, 30),
			Position = UDim2.new(1, -94, 0.5, -15),
			TextSize = 13,
			Parent = row,
		})
		add.MouseButton1Click:Connect(function()
			if #chamberSlots >= 2 then
				return
			end
			-- Adding the same entry twice is exactly how a variant fusion is made,
			-- so it's allowed as long as the player owns two copies.
			local already = 0
			for _, pick in ipairs(chamberSlots) do
				if pick.beastId == item.beastId and pick.variant == item.variant then
					already += 1
				end
			end
			if already < item.count then
				table.insert(chamberSlots, { beastId = item.beastId, variant = item.variant })
				self:_renderChamber()
			end
		end)
	end
end

-- ── Sanctuary (Altar level + Ascension) ───────────────────────────────────

function UIController:_renderSanctuary()
	local body = bodies.Sanctuary
	UI.clear(body)
	local data = ClientState.data
	local altarLevel = (data.altar or {}).level or 1
	local essence = (data.currencies or {}).essence or 0
	local ascension = data.ascension or { count = 0, multiplier = 1 }

	local atMax = altarLevel >= GameConfig.MAX_ALTAR_LEVEL
	local upgradeCost = math.floor(
		GameConfig.ALTAR_UPGRADE_BASE_COST * GameConfig.ALTAR_UPGRADE_COST_GROWTH ^ (altarLevel - 1)
	)
	local canAfford = essence >= upgradeCost

	-- Headline card: what the Altar is doing for you right now.
	local card = UI.surface({
		Size = UDim2.new(1, -8, 0, 108),
		BackgroundColor3 = Theme.panel,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Parent = body,
	}, false)
	UI.label(string.format("Altar  ·  Level %d", altarLevel), {
		Size = UDim2.new(1, -24, 0, 26),
		Position = UDim2.fromOffset(14, 10),
		Font = Theme.fontDisplay,
		TextSize = 20,
		TextColor3 = Theme.goldLight,
		Parent = card,
	})
	UI.label(string.format("%s essence / sec  ·  %s shards / sec", Format.abbreviate(data.ratePerSecond or 0),
		Format.abbreviate(GameConfig.SHARD_BASE_PER_SECOND * GameConfig.SHARD_ALTAR_GROWTH ^ (altarLevel - 1))), {
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.fromOffset(14, 38),
		TextSize = 12,
		TextColor3 = Theme.textMuted,
		Parent = card,
	})
	UI.label(string.format("Each level is +%d%% essence and +%d%% shards, forever.",
		math.floor((GameConfig.ALTAR_RATE_GROWTH - 1) * 100),
		math.floor((GameConfig.SHARD_ALTAR_GROWTH - 1) * 100)), {
		Size = UDim2.new(1, -24, 0, 18),
		Position = UDim2.fromOffset(14, 58),
		TextSize = 12,
		TextColor3 = Theme.accentLight,
		Parent = card,
	})
	UI.bar(atMax and 1 or math.min(1, essence / math.max(1, upgradeCost)), Theme.gold, {
		Size = UDim2.new(1, -28, 0, 10),
		Position = UDim2.fromOffset(14, 84),
		Parent = card,
	})

	local upgrade = UI.button(
		atMax and "MAX LEVEL" or string.format("UPGRADE  ·  %s essence", Format.abbreviate(upgradeCost)),
		(not atMax and canAfford) and Theme.gold or Theme.panelLight,
		{
			Size = UDim2.new(1, -8, 0, 54),
			TextSize = 18,
			LayoutOrder = 2,
			Parent = body,
		}
	)
	if not atMax then
		upgrade.MouseButton1Click:Connect(function()
			Remotes.event("UpgradeAltar"):FireServer()
		end)
	end

	-- Manual collect: a small active-play bonus, and the reason to be near the
	-- Altar rather than idling in a menu.
	local collect = UI.button("TAP TO CHANNEL  +", Theme.accent, {
		Size = UDim2.new(1, -8, 0, 44),
		TextSize = 15,
		LayoutOrder = 3,
		Parent = body,
	})
	collect.MouseButton1Click:Connect(function()
		Remotes.event("Collect"):FireServer()
	end)

	-- Ascension.
	local requirement = math.floor(
		GameConfig.ASCENSION_ALTAR_REQUIREMENT * GameConfig.ASCENSION_COST_GROWTH ^ (ascension.count or 0)
	)
	local canAscend = altarLevel >= requirement

	UI.label("ASCENSION", {
		Size = UDim2.new(1, -8, 0, 22),
		Font = Theme.fontBold,
		TextSize = 12,
		TextColor3 = Theme.rarity.Mythic,
		LayoutOrder = 4,
		Parent = body,
	})
	UI.label(string.format(
		"Reset your Altar, essence and shards — keep every beast — for a permanent +%d%% essence bonus.\nCurrent bonus: +%d%%  ·  Ascensions: %d",
		math.floor(GameConfig.ASCENSION_MULT_PER_LEVEL * 100),
		math.floor(((ascension.multiplier or 1) - 1) * 100),
		ascension.count or 0
	), {
		Size = UDim2.new(1, -8, 0, 52),
		TextSize = 12,
		TextColor3 = Theme.textMuted,
		TextWrapped = true,
		LayoutOrder = 5,
		Parent = body,
	})

	local ascend = UI.button(
		canAscend and "ASCEND" or string.format("Needs Altar level %d", requirement),
		canAscend and Theme.rarity.Mythic or Theme.panelLight,
		{
			Size = UDim2.new(1, -8, 0, 50),
			TextSize = 18,
			LayoutOrder = 6,
			Parent = body,
		}
	)
	if canAscend then
		ascend.MouseButton1Click:Connect(function()
			Remotes.event("Ascend"):FireServer()
		end)
	end

	-- Sanctuary capacity, so "why can't I display this beast" has an answer.
	local slots = data.habitatSlots or PlotConfig.BASE_HABITAT_SLOTS
	local hasBarn = ((data.plot or {}).purchasedPads or {})["beast_barn"] == true
	UI.label(string.format("Sanctuary space: %d / %d beasts — buy Habitat pads on your plot for more.",
		#(data.display or {}), slots), {
		Size = UDim2.new(1, -8, 0, 34),
		TextSize = 12,
		TextColor3 = Theme.cyan,
		TextWrapped = true,
		LayoutOrder = 7,
		Parent = body,
	})

	UI.label(
		hasBarn
				and string.format(
					"Beast Barn built: +%d beasts housed and +%d%% essence.",
					PlotConfig.BARN_HABITAT_SLOTS,
					math.floor(PlotConfig.BARN_ESSENCE_BONUS * 100)
				)
			or string.format(
				"Build the Beast Barn at the back of your plot: +%d beasts housed and +%d%% essence.",
				PlotConfig.BARN_HABITAT_SLOTS,
				math.floor(PlotConfig.BARN_ESSENCE_BONUS * 100)
			),
		{
			Size = UDim2.new(1, -8, 0, 34),
			TextSize = 12,
			TextColor3 = hasBarn and Theme.green or Theme.goldLight,
			TextWrapped = true,
			LayoutOrder = 8,
			Parent = body,
		}
	)
end

-- ── Beastdex ──────────────────────────────────────────────────────────────

function UIController:_renderBeastdex()
	local body = bodies.Beastdex
	UI.clear(body)
	local data = ClientState.data
	local codex = data.codex or {}
	local discovered = BeastInventory.speciesCount(codex)

	UI.label(string.format("Discovered  %d / %d", discovered, BeastConfig.count()), {
		Size = UDim2.new(1, -8, 0, 26),
		Font = Theme.fontDisplay,
		TextSize = 17,
		TextColor3 = Theme.goldLight,
		LayoutOrder = 1,
		Parent = body,
	})

	for index, beast in ipairs(BeastConfig.List) do
		local entry = codex[beast.id]
		local row = UI.surface({
			Size = UDim2.new(1, -8, 0, 48),
			BackgroundColor3 = entry and Theme.panel or Color3.fromRGB(21, 17, 42),
			BorderSizePixel = 0,
			LayoutOrder = 1 + index,
			Parent = body,
		}, false)

		Create("Frame", {
			Size = UDim2.fromOffset(6, 48),
			BackgroundColor3 = rarityColor(beast.rarity),
			BorderSizePixel = 0,
			Parent = row,
		})

		if entry then
			-- Show every variant held, e.g. "3 Normal · 1 Golden".
			local parts = {}
			for _, variantId in ipairs(VariantConfig.Order) do
				local count = entry.variants[variantId]
				if count and count > 0 then
					table.insert(parts, string.format("%d %s", count, variantId))
				end
			end
			UI.label(beast.name, {
				Size = UDim2.new(0.6, 0, 0, 20),
				Position = UDim2.fromOffset(16, 5),
				Font = Theme.fontBold,
				TextSize = 14,
				Parent = row,
			})
			UI.label(table.concat(parts, " · "), {
				Size = UDim2.new(0.7, 0, 0, 16),
				Position = UDim2.fromOffset(16, 25),
				TextSize = 11,
				TextColor3 = Theme.textMuted,
				Parent = row,
			})
		else
			UI.label("???", {
				Size = UDim2.new(0.6, 0, 1, 0),
				Position = UDim2.fromOffset(16, 0),
				Font = Theme.fontBold,
				TextSize = 14,
				TextColor3 = Color3.fromRGB(96, 88, 128),
				Parent = row,
			})
		end

		UI.pill(beast.rarity, rarityColor(beast.rarity), {
			Position = UDim2.new(1, -96, 0.5, -11),
			Size = UDim2.fromOffset(88, 22),
			Parent = row,
		})
	end
end

-- ── Pets ──────────────────────────────────────────────────────────────────

function UIController:_renderPets()
	local body = bodies.Pets
	UI.clear(body)
	local data = ClientState.data
	local owned = BeastInventory.list(data.codex or {})
	local active = data.activePet or { beastId = "", variant = "Normal" }

	UI.label("Your pet follows you and fights in the Arena. Power comes from rarity and variant.", {
		Size = UDim2.new(1, -8, 0, 34),
		TextSize = 13,
		TextColor3 = Theme.textMuted,
		TextWrapped = true,
		LayoutOrder = 1,
		Parent = body,
	})

	if #owned == 0 then
		UI.label("You don't own any beasts yet — summon one at your Altar!", {
			Size = UDim2.new(1, -8, 0, 40),
			TextSize = 14,
			TextColor3 = Theme.goldLight,
			TextWrapped = true,
			LayoutOrder = 2,
			Parent = body,
		})
		return
	end

	for index, item in ipairs(owned) do
		local isActive = active.beastId == item.beastId and active.variant == item.variant
		local stats = BeastInventory.stats(item.beastId, item.variant)
		local row = UI.surface({
			Size = UDim2.new(1, -8, 0, 52),
			BackgroundColor3 = isActive and Theme.accent or Theme.panel,
			BorderSizePixel = 0,
			LayoutOrder = 1 + index,
			Parent = body,
		}, false)

		UI.label(beastLabel(item.beastId, item.variant), {
			Size = UDim2.new(0.55, 0, 0, 20),
			Position = UDim2.fromOffset(12, 7),
			Font = Theme.fontBold,
			TextSize = 14,
			TextColor3 = Theme.variant[item.variant] or Theme.text,
			Parent = row,
		})
		UI.label(string.format("%s power  ·  %s HP", Format.abbreviate(stats.power), Format.abbreviate(stats.health)), {
			Size = UDim2.new(0.6, 0, 0, 16),
			Position = UDim2.fromOffset(12, 28),
			TextSize = 11,
			TextColor3 = Theme.textMuted,
			Parent = row,
		})

		local pick = UI.button(isActive and "Active" or "Equip", isActive and Theme.green or Theme.panelLight, {
			Size = UDim2.fromOffset(92, 32),
			Position = UDim2.new(1, -102, 0.5, -16),
			TextSize = 13,
			Parent = row,
		})
		if not isActive then
			pick.MouseButton1Click:Connect(function()
				Remotes.event("SetPet"):FireServer({ beastId = item.beastId, variant = item.variant })
			end)
		end
	end
end

-- ── Arena ─────────────────────────────────────────────────────────────────

function UIController:_renderArena()
	local body = bodies.Arena
	UI.clear(body)
	local data = ClientState.data
	local battle = data.battle or { wins = 0, losses = 0, bossesCleared = {} }

	UI.label(string.format("Record  %d W / %d L", battle.wins, battle.losses), {
		Size = UDim2.new(1, -8, 0, 26),
		Font = Theme.fontDisplay,
		TextSize = 17,
		TextColor3 = Theme.goldLight,
		LayoutOrder = 1,
		Parent = body,
	})

	UI.label("BOSSES", {
		Size = UDim2.new(1, -8, 0, 20),
		Font = Theme.fontBold,
		TextSize = 12,
		TextColor3 = Theme.accentLight,
		LayoutOrder = 2,
		Parent = body,
	})

	for index, boss in ipairs(CombatConfig.Bosses) do
		local cleared = (battle.bossesCleared or {})[boss.id] == true
		local row = UI.surface({
			Size = UDim2.new(1, -8, 0, 54),
			BackgroundColor3 = Theme.panel,
			BorderSizePixel = 0,
			LayoutOrder = 2 + index,
			Parent = body,
		}, false)

		UI.label(boss.name, {
			Size = UDim2.new(0.5, 0, 0, 20),
			Position = UDim2.fromOffset(12, 8),
			Font = Theme.fontBold,
			TextSize = 14,
			TextColor3 = cleared and Theme.green or Theme.text,
			Parent = row,
		})
		UI.label(string.format("%s power · %s HP", Format.abbreviate(boss.power), Format.abbreviate(boss.health)), {
			Size = UDim2.new(0.6, 0, 0, 16),
			Position = UDim2.fromOffset(12, 29),
			TextSize = 11,
			TextColor3 = Theme.textMuted,
			Parent = row,
		})

		local fight = UI.button(cleared and "Rematch" or "Fight", Theme.red, {
			Size = UDim2.fromOffset(96, 34),
			Position = UDim2.new(1, -106, 0.5, -17),
			TextSize = 14,
			Parent = row,
		})
		fight.MouseButton1Click:Connect(function()
			Remotes.event("FightBoss"):FireServer({ bossId = boss.id })
			panels.Arena.Visible = false
		end)
	end

	UI.label("DUEL A PLAYER", {
		Size = UDim2.new(1, -8, 0, 20),
		Font = Theme.fontBold,
		TextSize = 12,
		TextColor3 = Theme.accentLight,
		LayoutOrder = 40,
		Parent = body,
	})

	local order = 41
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= Players.LocalPlayer then
			local row = UI.surface({
				Size = UDim2.new(1, -8, 0, 46),
				BackgroundColor3 = Theme.panel,
				BorderSizePixel = 0,
				LayoutOrder = order,
				Parent = body,
			}, false)
			order += 1
			UI.label(other.DisplayName, {
				Size = UDim2.new(0.6, 0, 1, 0),
				Position = UDim2.fromOffset(12, 0),
				Font = Theme.fontBold,
				TextSize = 14,
				Parent = row,
			})
			local challenge = UI.button("Challenge", Theme.accent, {
				Size = UDim2.fromOffset(110, 32),
				Position = UDim2.new(1, -120, 0.5, -16),
				TextSize = 13,
				Parent = row,
			})
			challenge.MouseButton1Click:Connect(function()
				Remotes.event("ChallengePlayer"):FireServer({ targetUserId = other.UserId })
			end)
		end
	end
end

-- ── Quests ────────────────────────────────────────────────────────────────

function UIController:_renderQuests()
	local body = bodies.Quests
	UI.clear(body)
	local data = ClientState.data
	local login = data.login or { streak = 0, lastClaimDate = "" }
	local claimable = login.lastClaimDate ~= os.date("!%Y-%m-%d")

	local loginRow = UI.surface({
		Size = UDim2.new(1, -8, 0, 52),
		BackgroundColor3 = Theme.panel,
		BorderSizePixel = 0,
		LayoutOrder = 1,
		Parent = body,
	}, false)
	UI.label(string.format("Daily Login  ·  streak %d", login.streak or 0), {
		Size = UDim2.new(0.6, 0, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		Font = Theme.fontBold,
		TextSize = 14,
		Parent = loginRow,
	})
	local claim = UI.button(claimable and "Claim" or "Claimed", claimable and Theme.green or Theme.panelLight, {
		Size = UDim2.fromOffset(106, 34),
		Position = UDim2.new(1, -116, 0.5, -17),
		TextSize = 14,
		Parent = loginRow,
	})
	if claimable then
		claim.MouseButton1Click:Connect(function()
			Remotes.event("ClaimDaily"):FireServer()
		end)
	end

	local quests = data.quests or { active = {}, progress = {}, claimed = {} }
	for index, questId in ipairs(quests.active or {}) do
		local def
		for _, q in ipairs(QuestConfig.DailyPool) do
			if q.id == questId then
				def = q
				break
			end
		end
		if def then
			local progress = (quests.progress or {})[questId] or 0
			local complete = progress >= def.target
			local claimed = (quests.claimed or {})[questId] == true

			local row = UI.surface({
				Size = UDim2.new(1, -8, 0, 52),
				BackgroundColor3 = Theme.panel,
				BorderSizePixel = 0,
				LayoutOrder = 1 + index,
				Parent = body,
			}, false)
			UI.label(def.desc, {
				Size = UDim2.new(0.62, 0, 0, 20),
				Position = UDim2.fromOffset(12, 7),
				Font = Theme.fontBold,
				TextSize = 13,
				Parent = row,
			})
			UI.label(string.format("%d / %d", math.min(progress, def.target), def.target), {
				Size = UDim2.new(0.5, 0, 0, 16),
				Position = UDim2.fromOffset(12, 28),
				TextSize = 11,
				TextColor3 = complete and Theme.green or Theme.textMuted,
				Parent = row,
			})
			local btn = UI.button(
				claimed and "Done" or (complete and "Claim" or "…"),
				(complete and not claimed) and Theme.green or Theme.panelLight,
				{
					Size = UDim2.fromOffset(106, 34),
					Position = UDim2.new(1, -116, 0.5, -17),
					TextSize = 14,
					Parent = row,
				}
			)
			if complete and not claimed then
				btn.MouseButton1Click:Connect(function()
					Remotes.event("ClaimQuest"):FireServer({ questId = questId })
				end)
			end
		end
	end
end

-- ── Shop ──────────────────────────────────────────────────────────────────

function UIController:_renderShop()
	local body = bodies.Shop
	UI.clear(body)
	local data = ClientState.data
	local order = 0

	local function header(text: string)
		order += 1
		UI.label(text, {
			Size = UDim2.new(1, -8, 0, 22),
			Font = Theme.fontBold,
			TextSize = 12,
			TextColor3 = Theme.accentLight,
			LayoutOrder = order,
			Parent = body,
		})
	end

	local function item(name: string, blurb: string, price: number, owned: boolean, onBuy: () -> ())
		order += 1
		local row = UI.surface({
			Size = UDim2.new(1, -8, 0, 58),
			BackgroundColor3 = Theme.panel,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = body,
		}, false)
		UI.label(name, {
			Size = UDim2.new(0.62, 0, 0, 20),
			Position = UDim2.fromOffset(12, 8),
			Font = Theme.fontDisplay,
			TextSize = 15,
			Parent = row,
		})
		UI.label(blurb, {
			Size = UDim2.new(0.66, 0, 0, 18),
			Position = UDim2.fromOffset(12, 30),
			TextSize = 11,
			TextColor3 = Theme.textMuted,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = row,
		})
		local buy = UI.button(owned and "Owned" or (price .. " R$"), owned and Theme.panelLight or Theme.green, {
			Size = UDim2.fromOffset(112, 36),
			Position = UDim2.new(1, -122, 0.5, -18),
			TextSize = 14,
			Parent = row,
		})
		if not owned then
			buy.MouseButton1Click:Connect(onBuy)
		end
	end

	header("PERMANENT UPGRADES")
	for key, pass in pairs(MonetizationConfig.Gamepasses) do
		item(pass.name, pass.blurb or "", pass.price, (data.gamepasses or {})[key] == true, function()
			Remotes.event("PromptPurchase"):FireServer({ kind = "gamepass", key = key })
		end)
	end

	header("BOOSTS & PACKS")
	for key, product in pairs(MonetizationConfig.Products) do
		item(product.name, "", product.price, false, function()
			Remotes.event("PromptPurchase"):FireServer({ kind = "product", key = key })
		end)
	end
end

-- ── Refresh ───────────────────────────────────────────────────────────────

function UIController.setEssence(text: string)
	if refs.Essence then
		refs.Essence.Text = text
	end
end

function UIController.refresh()
	local data = ClientState.data
	if data.currencies then
		refs.Gems.Text = Format.abbreviate(data.currencies.gems or 0)
	end
	if data.ratePerSecond then
		refs.Rate.Text = Format.abbreviate(data.ratePerSecond) .. "/s"
	end

	local pet = data.activePet
	if pet and pet.beastId ~= "" and refs.petName then
		local stats = BeastInventory.stats(pet.beastId, pet.variant)
		refs.petName.Text = beastLabel(pet.beastId, pet.variant)
		refs.petName.TextColor3 = Theme.variant[pet.variant] or Theme.text
		refs.petPower.Text = string.format("%s power", Format.abbreviate(stats.power))
	end

	-- Re-render whichever panel is open so it never shows stale data.
	for name, frame in pairs(panels) do
		if frame.Visible then
			local renderer = UIController["_render" .. name]
			if renderer then
				renderer(UIController)
			end
		end
	end
end

function UIController.build()
	local gui = Create("ScreenGui", {
		Name = "FuseABeast",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
	})
	refs.gui = gui

	buildHud(gui)
	buildNav(gui)

	local panelSpecs = {
		{ name = "Summon", title = "Summoning Altar", size = UDim2.fromOffset(430, 430) },
		{ name = "Chamber", title = "Fusion Chamber", size = UDim2.fromOffset(470, 520) },
		{ name = "Sanctuary", title = "Summoning Altar", size = UDim2.fromOffset(450, 520) },
		{ name = "Beastdex", title = "Beastdex", size = UDim2.fromOffset(450, 520) },
		{ name = "Pets", title = "Your Pets", size = UDim2.fromOffset(450, 480) },
		{ name = "Arena", title = "The Arena", size = UDim2.fromOffset(450, 520) },
		{ name = "Quests", title = "Quests", size = UDim2.fromOffset(450, 460) },
		{ name = "Shop", title = "Shop", size = UDim2.fromOffset(470, 520) },
	}
	for _, spec in ipairs(panelSpecs) do
		local frame, bodyFrame = UI.panel(gui, spec.title, spec.size)
		frame.Name = spec.name .. "Panel"
		panels[spec.name] = frame
		bodies[spec.name] = bodyFrame
	end
end

return UIController
