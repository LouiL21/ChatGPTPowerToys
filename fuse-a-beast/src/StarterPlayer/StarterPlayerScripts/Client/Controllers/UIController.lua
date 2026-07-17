--!strict
--[[
	UIController
	Builds and drives the entire in-game interface in code and keeps it in sync
	with ClientState. The UI is intentionally "invisible onboarding": the player
	lands directly on the Fusion panel and can fuse within seconds — no tutorial
	gate (a top cause of Day-1 churn).

	Sections: top resource bar, central Fusion panel, bottom nav, and toggled
	panels for Beastdex, Quests, and Shop. Every button only *requests* an action;
	the server validates and replies with a StateUpdate that this controller renders.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local GameConfig = require(Shared.Config.GameConfig)
local ElementConfig = require(Shared.Config.ElementConfig)
local BeastConfig = require(Shared.Config.BeastConfig)
local RecipeConfig = require(Shared.Config.RecipeConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local QuestConfig = require(Shared.Config.QuestConfig)
local Format = require(Shared.Util.Format)

local ClientState = require(script.Parent.Parent.ClientState)
local Create = require(script.Parent.Parent.UI.Create)

local UIController = {}

local RARITY_COLORS = {
	Common = Color3.fromRGB(180, 180, 180),
	Uncommon = Color3.fromRGB(90, 200, 100),
	Rare = Color3.fromRGB(70, 140, 240),
	Epic = Color3.fromRGB(170, 90, 240),
	Legendary = Color3.fromRGB(245, 180, 40),
	Mythic = Color3.fromRGB(240, 70, 120),
	Secret = Color3.fromRGB(30, 30, 30),
}

local BG = Color3.fromRGB(24, 26, 34)
local PANEL = Color3.fromRGB(34, 37, 48)
local ACCENT = Color3.fromRGB(120, 90, 240)
local TEXT = Color3.fromRGB(235, 238, 245)

local refs: { [string]: any } = {}
local selected: { string } = {}
local elementButtons: { [string]: TextButton } = {}
local panels: { [string]: Frame } = {}

-- ── small styling helpers ────────────────────────────────────────────────────
local function corner(radius: number, parent: Instance)
	Create("UICorner", { CornerRadius = UDim.new(0, radius), Parent = parent })
end

local function pad(px: number, parent: Instance)
	Create("UIPadding", {
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		Parent = parent,
	})
end

local function button(text: string, color: Color3): TextButton
	local b = Create("TextButton", {
		Text = text,
		Font = Enum.Font.GothamBold,
		TextSize = 16,
		TextColor3 = TEXT,
		BackgroundColor3 = color,
		AutoButtonColor = true,
		BorderSizePixel = 0,
	}) :: TextButton
	corner(8, b)
	return b
end

-- ── build: static layout ─────────────────────────────────────────────────────
function UIController.build()
	local player = Players.LocalPlayer
	local gui = Create("ScreenGui", {
		Name = "FuseABeast",
		ResetOnSpawn = false,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		IgnoreGuiInset = false,
		Parent = player:WaitForChild("PlayerGui"),
	})
	refs.gui = gui

	-- Top resource bar.
	local topBar = Create("Frame", {
		Name = "TopBar",
		Size = UDim2.new(1, -20, 0, 46),
		Position = UDim2.new(0, 10, 0, 6),
		BackgroundColor3 = PANEL,
		BorderSizePixel = 0,
		Parent = gui,
	})
	corner(10, topBar)
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, 18),
		Parent = topBar,
	})
	local function stat(name: string)
		local label = Create("TextLabel", {
			Name = name,
			Size = UDim2.new(0, 170, 1, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 16,
			TextColor3 = TEXT,
			TextXAlignment = Enum.TextXAlignment.Center,
			Text = name .. ": 0",
			Parent = topBar,
		})
		refs[name] = label
	end
	stat("Essence")
	stat("Gems")
	stat("Rate")

	-- Central fusion panel.
	local fusion = Create("Frame", {
		Name = "FusionPanel",
		Size = UDim2.new(0, 360, 0, 300),
		Position = UDim2.new(0.5, -180, 0.5, -170),
		BackgroundColor3 = PANEL,
		BorderSizePixel = 0,
		Parent = gui,
	})
	corner(14, fusion)
	pad(14, fusion)
	Create("UIListLayout", {
		FillDirection = Enum.FillDirection.Vertical,
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Padding = UDim.new(0, 8),
		Parent = fusion,
	})
	Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = TEXT,
		Text = "Fusion Altar — pick 2-3 elements",
		LayoutOrder = 1,
		Parent = fusion,
	})

	-- element grid
	local grid = Create("Frame", {
		Size = UDim2.new(1, 0, 0, 120),
		BackgroundTransparency = 1,
		LayoutOrder = 2,
		Parent = fusion,
	})
	Create("UIGridLayout", {
		CellSize = UDim2.new(0, 106, 0, 54),
		CellPadding = UDim2.new(0, 6, 0, 6),
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		Parent = grid,
	})
	for _, element in ipairs(ElementConfig.List) do
		local color = Color3.new(element.color[1], element.color[2], element.color[3])
		local b = button(element.displayName .. "\n0", color)
		b.TextSize = 14
		b.Name = element.id
		b.Parent = grid
		elementButtons[element.id] = b
		b.MouseButton1Click:Connect(function()
			UIController._toggleElement(element.id)
		end)
	end

	-- selection preview + hint
	refs.selectionLabel = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 20),
		BackgroundTransparency = 1,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(190, 195, 210),
		Text = "Select elements to begin",
		LayoutOrder = 3,
		Parent = fusion,
	})

	local fuseBtn = button("FUSE", ACCENT)
	fuseBtn.Size = UDim2.new(1, 0, 0, 44)
	fuseBtn.TextSize = 20
	fuseBtn.LayoutOrder = 4
	fuseBtn.Parent = fusion
	fuseBtn.MouseButton1Click:Connect(UIController._fuse)
	refs.fuseBtn = fuseBtn

	-- Bottom nav.
	local nav = Create("Frame", {
		Name = "Nav",
		Size = UDim2.new(1, -20, 0, 50),
		Position = UDim2.new(0, 10, 1, -58),
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
	local navSpecs = {
		{ text = "Tap +", action = function() Remotes.event("Collect"):FireServer() end },
		{ text = "Altar", action = function() Remotes.event("UpgradeAltar"):FireServer() end },
		{ text = "Beastdex", action = function() UIController.openPanel("Beastdex") end },
		{ text = "Quests", action = function() UIController.openPanel("Quests") end },
		{ text = "Shop", action = function() UIController.openPanel("Shop") end },
		{ text = "Ascend", action = function() Remotes.event("Ascend"):FireServer() end },
	}
	for _, spec in ipairs(navSpecs) do
		local b = button(spec.text, Color3.fromRGB(48, 52, 66))
		b.Size = UDim2.new(0, 100, 1, 0)
		b.Parent = nav
		b.MouseButton1Click:Connect(spec.action)
		if spec.text == "Altar" then
			refs.altarBtn = b
		elseif spec.text == "Ascend" then
			refs.ascendBtn = b
		end
	end

	-- Toggled panels.
	panels.Beastdex = UIController._makeScrollPanel("Beastdex")
	panels.Quests = UIController._makeScrollPanel("Quests")
	panels.Shop = UIController._makeScrollPanel("Shop")
end

function UIController._makeScrollPanel(title: string): Frame
	local frame = Create("Frame", {
		Name = title .. "Panel",
		Size = UDim2.new(0, 420, 0, 420),
		Position = UDim2.new(0.5, -210, 0.5, -210),
		BackgroundColor3 = BG,
		BorderSizePixel = 0,
		Visible = false,
		Parent = refs.gui,
	}) :: Frame
	corner(14, frame)
	local header = Create("TextLabel", {
		Size = UDim2.new(1, 0, 0, 40),
		BackgroundColor3 = PANEL,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = TEXT,
		Text = title,
		Parent = frame,
	})
	corner(14, header)
	local close = button("X", Color3.fromRGB(200, 60, 70))
	close.Size = UDim2.new(0, 32, 0, 28)
	close.Position = UDim2.new(1, -38, 0, 6)
	close.Parent = frame
	close.MouseButton1Click:Connect(function()
		frame.Visible = false
	end)
	local scroll = Create("ScrollingFrame", {
		Name = "List",
		Size = UDim2.new(1, -16, 1, -50),
		Position = UDim2.new(0, 8, 0, 46),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		Parent = frame,
	})
	Create("UIListLayout", {
		Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = scroll,
	})
	refs[title .. "List"] = scroll
	return frame
end

function UIController.openPanel(name: string)
	for panelName, frame in pairs(panels) do
		frame.Visible = panelName == name
	end
	if name == "Beastdex" then
		UIController._renderBeastdex()
	elseif name == "Quests" then
		UIController._renderQuests()
	elseif name == "Shop" then
		UIController._renderShop()
	end
end

-- ── fusion selection ─────────────────────────────────────────────────────────
function UIController._toggleElement(id: string)
	local index = table.find(selected, id)
	if index then
		table.remove(selected, index)
	elseif #selected < 3 then
		table.insert(selected, id)
	end
	UIController._refreshSelection()
end

function UIController._refreshSelection()
	for id, b in pairs(elementButtons) do
		local isSelected = table.find(selected, id) ~= nil
		b.BackgroundTransparency = isSelected and 0 or 0.35
		local stroke = b:FindFirstChildOfClass("UIStroke")
		if isSelected and not stroke then
			Create("UIStroke", { Thickness = 3, Color = Color3.fromRGB(255, 255, 255), Parent = b })
		elseif not isSelected and stroke then
			stroke:Destroy()
		end
	end
	if #selected == 0 then
		refs.selectionLabel.Text = "Select elements to begin"
	else
		local hint = RecipeConfig.getHint(selected)
		refs.selectionLabel.Text = table.concat(selected, " + ") .. (hint and ("  —  " .. hint) or "")
	end
	refs.fuseBtn.BackgroundColor3 = (#selected >= 2) and ACCENT or Color3.fromRGB(70, 70, 80)
end

function UIController._fuse()
	if #selected < 2 then
		return
	end
	Remotes.event("Fuse"):FireServer({ elements = table.clone(selected) })
end

-- Essence is driven by EssenceController (smooth predicted counter), so refresh()
-- deliberately does NOT overwrite it.
function UIController.setEssence(text: string)
	if refs.Essence then
		refs.Essence.Text = "Essence: " .. text
	end
end

-- ── rendering from state ─────────────────────────────────────────────────────
function UIController.refresh(keys: { string })
	local data = ClientState.data
	if data.currencies then
		refs.Gems.Text = "Gems: " .. Format.abbreviate(data.currencies.gems or 0)
	end
	if data.shards then
		for id, b in pairs(elementButtons) do
			b.Text = ElementConfig.ById[id].displayName .. "\n" .. Format.abbreviate(data.shards[id] or 0)
		end
	end
	if data.ratePerSecond then
		refs.Rate.Text = "Rate: " .. Format.abbreviate(data.ratePerSecond) .. "/s"
	end
	if data.altar and refs.altarBtn then
		local cost = math.floor(GameConfig.ALTAR_UPGRADE_BASE_COST * GameConfig.ALTAR_UPGRADE_COST_GROWTH ^ (data.altar.level - 1))
		refs.altarBtn.Text = string.format("Altar Lv.%d\n%s", data.altar.level, Format.abbreviate(cost))
	end
	if data.ascension and data.altar and refs.ascendBtn then
		local req = math.floor(GameConfig.ASCENSION_ALTAR_REQUIREMENT * GameConfig.ASCENSION_COST_GROWTH ^ data.ascension.count)
		refs.ascendBtn.Text = string.format("Ascend\nLv%d req", req)
	end
	-- refresh open dynamic panels
	if panels.Beastdex.Visible then
		UIController._renderBeastdex()
	end
	if panels.Quests.Visible then
		UIController._renderQuests()
	end
end

function UIController._clearList(scroll: ScrollingFrame)
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function UIController._renderBeastdex()
	local scroll = refs.BeastdexList
	UIController._clearList(scroll)
	local data = ClientState.data
	local codex = data.codex or {}
	local display = data.display or {}
	local order = 0
	for _, beast in ipairs(BeastConfig.List) do
		order += 1
		local entry = codex[beast.id]
		local discovered = entry ~= nil
		local row = Create("Frame", {
			Size = UDim2.new(1, -6, 0, 46),
			BackgroundColor3 = PANEL,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = scroll,
		})
		corner(8, row)
		Create("Frame", { -- rarity color bar
			Size = UDim2.new(0, 6, 1, 0),
			BackgroundColor3 = RARITY_COLORS[beast.rarity] or TEXT,
			BorderSizePixel = 0,
			Parent = row,
		})
		Create("TextLabel", {
			Size = UDim2.new(0.55, 0, 1, 0),
			Position = UDim2.new(0, 14, 0, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = discovered and TEXT or Color3.fromRGB(110, 110, 120),
			Text = discovered
				and string.format("%s  (%s)\nx%d  Lv.%d", beast.name, beast.rarity, entry.count, entry.level)
				or string.format("???  (%s)", beast.rarity),
			Parent = row,
		})
		if discovered then
			local isDisplayed = table.find(display, beast.id) ~= nil
			local displayBtn = button(isDisplayed and "Displayed" or "Display", isDisplayed and Color3.fromRGB(90, 160, 90) or Color3.fromRGB(60, 64, 80))
			displayBtn.Size = UDim2.new(0, 84, 0, 32)
			displayBtn.Position = UDim2.new(1, -178, 0.5, -16)
			displayBtn.TextSize = 13
			displayBtn.Parent = row
			displayBtn.MouseButton1Click:Connect(function()
				UIController._toggleDisplay(beast.id)
			end)

			local mergeBtn = button("Merge", Color3.fromRGB(150, 110, 60))
			mergeBtn.Size = UDim2.new(0, 78, 0, 32)
			mergeBtn.Position = UDim2.new(1, -86, 0.5, -16)
			mergeBtn.TextSize = 13
			mergeBtn.Parent = row
			mergeBtn.MouseButton1Click:Connect(function()
				Remotes.event("Merge"):FireServer({ beastId = beast.id })
			end)
		end
	end
end

function UIController._toggleDisplay(beastId: string)
	local display = table.clone(ClientState.data.display or {})
	local index = table.find(display, beastId)
	if index then
		table.remove(display, index)
	else
		table.insert(display, beastId)
	end
	Remotes.event("SetDisplay"):FireServer({ beasts = display })
end

function UIController._renderQuests()
	local scroll = refs.QuestsList
	UIController._clearList(scroll)
	local data = ClientState.data
	local order = 0

	-- Daily login claim.
	order += 1
	local login = data.login or { streak = 0, lastClaimDate = "" }
	local todayStr = os.date("!%Y-%m-%d")
	local claimable = login.lastClaimDate ~= todayStr
	local loginRow = Create("Frame", {
		Size = UDim2.new(1, -6, 0, 50),
		BackgroundColor3 = PANEL,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = scroll,
	})
	corner(8, loginRow)
	Create("TextLabel", {
		Size = UDim2.new(0.6, 0, 1, 0),
		Position = UDim2.new(0, 12, 0, 0),
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = TEXT,
		Text = string.format("Daily Login  (streak %d)", login.streak or 0),
		Parent = loginRow,
	})
	local loginBtn = button(claimable and "Claim" or "Claimed", claimable and Color3.fromRGB(90, 160, 90) or Color3.fromRGB(60, 64, 80))
	loginBtn.Size = UDim2.new(0, 100, 0, 34)
	loginBtn.Position = UDim2.new(1, -110, 0.5, -17)
	loginBtn.Parent = loginRow
	if claimable then
		loginBtn.MouseButton1Click:Connect(function()
			Remotes.event("ClaimDaily"):FireServer()
		end)
	end

	-- Daily quests.
	local quests = data.quests or { active = {}, progress = {}, claimed = {} }
	for _, questId in ipairs(quests.active or {}) do
		local def
		for _, q in ipairs(QuestConfig.DailyPool) do
			if q.id == questId then
				def = q
				break
			end
		end
		if def then
			order += 1
			local progress = (quests.progress or {})[questId] or 0
			local complete = progress >= def.target
			local claimed = (quests.claimed or {})[questId] == true
			local row = Create("Frame", {
				Size = UDim2.new(1, -6, 0, 50),
				BackgroundColor3 = PANEL,
				BorderSizePixel = 0,
				LayoutOrder = order,
				Parent = scroll,
			})
			corner(8, row)
			Create("TextLabel", {
				Size = UDim2.new(0.62, 0, 1, 0),
				Position = UDim2.new(0, 12, 0, 0),
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextColor3 = TEXT,
				Text = string.format("%s\n%d / %d", def.desc, math.min(progress, def.target), def.target),
				Parent = row,
			})
			local questBtn = button(claimed and "Done" or (complete and "Claim" or "..."), (complete and not claimed) and Color3.fromRGB(90, 160, 90) or Color3.fromRGB(60, 64, 80))
			questBtn.Size = UDim2.new(0, 100, 0, 34)
			questBtn.Position = UDim2.new(1, -110, 0.5, -17)
			questBtn.Parent = row
			if complete and not claimed then
				questBtn.MouseButton1Click:Connect(function()
					Remotes.event("ClaimQuest"):FireServer({ questId = questId })
				end)
			end
		end
	end
end

function UIController._renderShop()
	local scroll = refs.ShopList
	UIController._clearList(scroll)
	local data = ClientState.data
	local order = 0

	local function addHeader(text: string)
		order += 1
		Create("TextLabel", {
			Size = UDim2.new(1, -6, 0, 26),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 15,
			TextColor3 = ACCENT,
			TextXAlignment = Enum.TextXAlignment.Left,
			Text = text,
			LayoutOrder = order,
			Parent = scroll,
		})
	end

	local function addItem(name: string, price: number, owned: boolean, onBuy: () -> ())
		order += 1
		local row = Create("Frame", {
			Size = UDim2.new(1, -6, 0, 46),
			BackgroundColor3 = PANEL,
			BorderSizePixel = 0,
			LayoutOrder = order,
			Parent = scroll,
		})
		corner(8, row)
		Create("TextLabel", {
			Size = UDim2.new(0.6, 0, 1, 0),
			Position = UDim2.new(0, 12, 0, 0),
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = TEXT,
			Text = name,
			Parent = row,
		})
		local buy = button(owned and "Owned" or (price .. " R$"), owned and Color3.fromRGB(60, 64, 80) or Color3.fromRGB(60, 160, 90))
		buy.Size = UDim2.new(0, 110, 0, 34)
		buy.Position = UDim2.new(1, -120, 0.5, -17)
		buy.Parent = row
		if not owned then
			buy.MouseButton1Click:Connect(onBuy)
		end
	end

	addHeader("Gamepasses")
	for key, pass in pairs(MonetizationConfig.Gamepasses) do
		local owned = (data.gamepasses or {})[key] == true
		addItem(pass.name, pass.price, owned, function()
			Remotes.event("PromptPurchase"):FireServer({ kind = "gamepass", key = key })
		end)
	end

	addHeader("Boosts & Packs")
	for key, product in pairs(MonetizationConfig.Products) do
		addItem(product.name, product.price, false, function()
			Remotes.event("PromptPurchase"):FireServer({ kind = "product", key = key })
		end)
	end
end

return UIController
