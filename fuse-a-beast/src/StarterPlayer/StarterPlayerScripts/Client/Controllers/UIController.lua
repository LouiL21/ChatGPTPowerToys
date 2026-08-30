--!strict
--[[
	UIController
	Builds and drives the interface: a compact HUD plus modal panels for Summon,
	Chamber, Beastdex, Pets, Arena, Quests and Shop.

	Two principles carried over from the design pass:
	  1. The world is the way in. Summon and Chamber open by walking up to the
	     building; the HUD stays small so you can actually see the game.
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
		Size = UDim2.fromOffset(360, 52),
		Position = UDim2.new(0.5, -180, 0, 8),
		BackgroundColor3 = Theme.panel,
		BorderSizePixel = 0,
		Parent = gui,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 14),
		Parent = bar,
	})

	local function stat(name: string, color: Color3, width: number)
		local holder = Create("Frame", {
			Size = UDim2.fromOffset(width, 40),
			BackgroundTransparency = 1,
			Parent = bar,
		})
		refs[name] = UI.label("0", {
			Size = UDim2.new(1, 0, 0, 22),
			Font = Theme.fontDisplay,
			TextSize = 20,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = holder,
		})
		UI.label(string.upper(name), {
			Size = UDim2.new(1, 0, 0, 12),
			Position = UDim2.fromOffset(0, 24),
			Font = Theme.fontBold,
			TextSize = 10,
			TextColor3 = Theme.textMuted,
			TextXAlignment = Enum.TextXAlignment.Center,
			Parent = holder,
		})
	end
	stat("Essence", Theme.goldLight, 128)
	stat("Gems", Theme.cyan, 74)
	stat("Rate", Theme.accentLight, 96)

	-- Active pet card, bottom-left: your fighter, always visible.
	local petCard = UI.surface({
		Name = "PetCard",
		Size = UDim2.fromOffset(184, 62),
		Position = UDim2.new(0, 12, 1, -136),
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

local function buildNav(gui: Instance)
	local nav = Create("Frame", {
		Name = "Nav",
		Size = UDim2.new(1, -24, 0, 56),
		Position = UDim2.new(0, 12, 1, -66),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 8),
		Parent = nav,
	})

	local specs = {
		{ text = "Summon", color = Theme.accent, action = function() UIController.open("Summon") end },
		{ text = "Chamber", color = Theme.rarity.Mythic, action = function() UIController.open("Chamber") end },
		{ text = "Beasts", color = Theme.panelLight, action = function() UIController.open("Beastdex") end },
		{ text = "Pets", color = Theme.panelLight, action = function() UIController.open("Pets") end },
		{ text = "Arena", color = Theme.red, action = function() UIController.open("Arena") end },
		{ text = "Quests", color = Theme.panelLight, action = function() UIController.open("Quests") end },
		{ text = "Shop", color = Theme.green, action = function() UIController.open("Shop") end },
	}
	for _, spec in ipairs(specs) do
		local btn = UI.button(spec.text, spec.color, {
			Size = UDim2.fromOffset(104, 46),
			TextSize = 15,
			Parent = nav,
		})
		btn.MouseButton1Click:Connect(spec.action)
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
		UI.label("Build the Fusion Chamber on your plot to combine beasts.\nIt's the second buy-pad on your sanctuary.", {
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
				"Variant fusion → %.0f%% chance of a %s %s",
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
		previewText = "Hybrid fusion → a new beast from their combined elements"
		previewColor = Theme.rarity.Mythic
	end

	UI.label(previewText, {
		Size = UDim2.new(1, -8, 0, 34),
		TextSize = 13,
		TextColor3 = previewColor,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		Parent = body,
	})

	local fuse = UI.button("FUSE", (a and b) and Theme.rarity.Mythic or Theme.panelLight, {
		Size = UDim2.new(1, -8, 0, 50),
		TextSize = 20,
		LayoutOrder = 3,
		Parent = body,
	})
	fuse.MouseButton1Click:Connect(function()
		if a and b then
			Remotes.event("ChamberFuse"):FireServer({ a = a, b = b })
			chamberSlots = {}
		end
	end)

	UI.label("YOUR BEASTS", {
		Size = UDim2.new(1, -8, 0, 22),
		Font = Theme.fontBold,
		TextSize = 12,
		TextColor3 = Theme.accentLight,
		LayoutOrder = 4,
		Parent = body,
	})

	for index, item in ipairs(owned) do
		local row = UI.surface({
			Size = UDim2.new(1, -8, 0, 46),
			BackgroundColor3 = Theme.panel,
			BorderSizePixel = 0,
			LayoutOrder = 4 + index,
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
