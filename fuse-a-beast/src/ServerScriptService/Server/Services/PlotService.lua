--!strict
--[[
	PlotService
	Owns the physical sanctuaries: builds the island on server start, hands a
	free plot to each arriving player, applies their saved progression to the
	geometry, teleports them onto it, and frees the plot when they leave.

	Everything physical about a player hangs off the PlotHandle this service
	stores, so other services (nodes, beasts, pads) never search the workspace.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local PlotConfig = require(Shared.Config.PlotConfig)
local GameConfig = require(Shared.Config.GameConfig)
local Signal = require(Shared.Util.Signal)
local Format = require(Shared.Util.Format)
local Logger = require(Shared.Util.Logger).new("Plot")

local World = script.Parent.Parent.World
local WorldBuilder = require(World.WorldBuilder)
local PlotBuilder = require(World.PlotBuilder)
local ServerNet = require(script.Parent.Parent.ServerNet)

local PlotService = {
	Name = "PlotService",
	PlotAssigned = Signal.new(), -- (player, handle)
	PlotReleased = Signal.new(), -- (player, handle)
}
local Registry: any

local _plots: { any } = {} -- index -> PlotHandle
local _ownerByIndex: { [number]: Player } = {}
local _indexByUser: { [number]: number } = {}

function PlotService:Init(registry)
	Registry = registry
end

function PlotService:getHandle(player: Player)
	local index = _indexByUser[player.UserId]
	return index and _plots[index] or nil
end

function PlotService:getOwner(index: number): Player?
	return _ownerByIndex[index]
end

-- Is this world position inside `player`'s plot? Used to keep pickups private
-- to their owner without a per-part ownership lookup.
function PlotService:isOnPlot(player: Player, position: Vector3): boolean
	local handle = self:getHandle(player)
	if not handle then
		return false
	end
	local local_ = handle.origin:PointToObjectSpace(position)
	local half = PlotConfig.PLOT_SIZE / 2
	return math.abs(local_.X) <= half and math.abs(local_.Z) <= half
end

-- Apply saved progression to the plot's geometry.
--[[
	Paints one buy-pad for its state. Single source of truth for pad appearance
	so the build-time pass and the affordability sweep can never disagree.

	The tile carries the state colour and the thin frame carries the emission —
	keeping neon off the large face is what stops a plot full of pads reading as
	a field of white squares.
]]
local PAD_TILE = {
	purchased = Color3.fromRGB(46, 96, 56),
	affordable = PlotConfig.COLORS.affordable,
	locked = PlotConfig.COLORS.locked,
}
local PAD_FRAME = {
	purchased = Color3.fromRGB(72, 168, 88),
	affordable = Color3.fromRGB(214, 156, 52),
	locked = Color3.fromRGB(96, 76, 158),
}
local PAD_TEXT = {
	purchased = Color3.fromRGB(160, 240, 175),
	affordable = Color3.fromRGB(255, 224, 150),
	locked = Color3.fromRGB(190, 184, 216),
}

function PlotService:_paintPad(pad, spec, purchased: boolean, affordable: boolean)
	local state = purchased and "purchased" or (affordable and "affordable" or "locked")
	pad.pad.Color = PAD_TILE[state]
	pad.glow.Color = PAD_FRAME[state]
	pad.glow.Transparency = purchased and 0.45 or 0
	pad.label.TextColor3 = PAD_TEXT[state]
	pad.label.Text = purchased and (spec.label .. "\n✔ OWNED")
		or string.format("%s\n%s essence", spec.label, Format.abbreviate(spec.cost))
end

--[[
	Shows or hides a purchasable building.

	`glassName`/`glassTransparency` let one structure keep a see-through part
	(the Chamber's pods) without the reveal flattening it to opaque.
]]
function PlotService:_reveal(model: Model?, owned: boolean, glassName: string?, glassTransparency: number)
	if not model then
		return
	end
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			local isGlass = glassName ~= nil and part.Name == glassName
			part.Transparency = owned and (isGlass and glassTransparency or 0) or 1
			part.CanCollide = owned and not isGlass
		elseif part:IsA("PointLight") then
			part.Enabled = owned
		elseif part:IsA("BillboardGui") then
			part.Enabled = owned
		elseif part:IsA("ProximityPrompt") then
			part.Enabled = owned
		end
	end
end

function PlotService:applyProgression(player: Player)
	local handle = self:getHandle(player)
	local data = Registry.DataService:get(player)
	if not handle or not data then
		return
	end

	-- Element nodes: default-unlocked ones plus anything bought.
	for _, spec in ipairs(PlotConfig.Nodes) do
		local node = handle.nodes[spec.element]
		if node then
			local unlocked = spec.unlockedByDefault or data.plot.unlockedNodes[spec.element] == true
			node.unlocked = unlocked
			node.crystal.Transparency = unlocked and 0 or 0.75
			node.crystal.Material = unlocked and Enum.Material.Neon or Enum.Material.Glass
			local light = node.crystal:FindFirstChildOfClass("PointLight")
			if light then
				light.Enabled = unlocked
			end
		end
	end

	-- Buy pads: purchased ones go green and stop charging. An unpurchased pad the
	-- player can afford right now lights up gold, so "what can I buy" is legible
	-- from across the plot instead of requiring a walk-and-read of every pad.
	local essence = data.currencies.essence or 0
	for _, spec in ipairs(PlotConfig.BuyPads) do
		local pad = handle.pads[spec.id]
		if pad then
			local purchased = data.plot.purchasedPads[spec.id] == true
			pad.purchased = purchased
			self:_paintPad(pad, spec, purchased, not purchased and essence >= spec.cost)
		end
	end

	-- Buildings only exist once bought — hiding them keeps the first session
	-- focused on summoning, and makes each purchase land as an event.
	self:_reveal(handle.chamber, data.plot.purchasedPads["fusion_chamber"] == true, "PodGlass", 0.55)
	self:_reveal(handle.barn, data.plot.purchasedPads["beast_barn"] == true, nil, 0)

	handle.sign.Text = player.DisplayName .. "'s Sanctuary"
end

-- Single source of truth for "how many beasts can physically live here":
-- the base allowance, plus tycoon habitat purchases, plus any gamepass bonus.
function PlotService:habitatSlots(player: Player): number
	local data = Registry.DataService:get(player)
	if not data then
		return PlotConfig.BASE_HABITAT_SLOTS
	end
	local gamepassBonus = Registry.MonetizationService:getDisplaySlots(player) - GameConfig.DISPLAY_SLOT_BASE
	-- The Barn houses beasts too, so it counts toward capacity rather than being
	-- a building you buy and then still have nowhere to put anything.
	local barn = data.plot.purchasedPads["beast_barn"] and PlotConfig.BARN_HABITAT_SLOTS or 0
	return PlotConfig.BASE_HABITAT_SLOTS + data.plot.habitatSlots + barn + math.max(0, gamepassBonus)
end

local function firstFreeIndex(): number?
	for i = 1, PlotConfig.PLOT_COUNT do
		if _ownerByIndex[i] == nil then
			return i
		end
	end
	return nil
end

function PlotService:_assign(player: Player)
	local index = firstFreeIndex()
	if not index then
		Logger:warn("No free plot for", player.Name)
		ServerNet.notify(player, "All sanctuaries are occupied on this island.", "warn")
		return
	end

	_ownerByIndex[index] = player
	_indexByUser[player.UserId] = index

	local handle = _plots[index]
	self:applyProgression(player)
	self:_bindAltar(player, handle)
	Logger:info("Assigned plot", index, "to", player.Name)
	self.PlotAssigned:fire(player, handle)

	-- Place the player on their sanctuary.
	self:teleportHome(player)
end

-- The Altar's ProximityPrompt is what opens the fusion panel — the UI is now
-- reached by walking to a place in the world, not by a button that is always
-- on screen. Connections are tracked per plot and torn down on release.
local _altarConnections: { [number]: { RBXScriptConnection } } = {}

local function bindPrompt(handle, host: Instance, promptName: string, player: Player, remoteName: string, denial: string)
	local prompt = host:FindFirstChild(promptName) :: ProximityPrompt?
	if not prompt then
		return
	end
	local connection = prompt.Triggered:Connect(function(triggering)
		-- Visitors can admire the buildings; only the owner may use them.
		if triggering ~= player then
			ServerNet.notify(triggering, denial, "warn")
			return
		end
		ServerNet.fire(player, remoteName, { open = true })
	end)
	local bucket = _altarConnections[handle.index]
	table.insert(bucket, connection)
end

function PlotService:_bindAltar(player: Player, handle)
	for _, connection in ipairs(_altarConnections[handle.index] or {}) do
		connection:Disconnect()
	end
	_altarConnections[handle.index] = {}

	bindPrompt(handle, handle.altar, "AltarPrompt", player, "OpenFusion",
		"This is someone else's Altar. Head home to summon!")
	bindPrompt(handle, handle.chamberPillar, "ChamberPrompt", player, "OpenChamber",
		"This is someone else's Chamber. Head home to fuse!")
	bindPrompt(handle, handle.barnPost, "BarnPrompt", player, "OpenBarn",
		"This is someone else's Barn. Head home to tend yours!")
end

function PlotService:teleportHome(player: Player)
	local handle = self:getHandle(player)
	if not handle then
		return
	end
	local target = (handle.origin * CFrame.new(PlotConfig.SPAWN_OFFSET)).Position + Vector3.new(0, 5, 0)

	local function place(character: Model)
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			character:PivotTo(CFrame.new(target))
		end
	end

	if player.Character then
		place(player.Character)
	else
		local connection
		connection = player.CharacterAdded:Connect(function(character)
			connection:Disconnect()
			task.wait(0.2)
			place(character)
		end)
	end
end

function PlotService:_release(player: Player)
	local index = _indexByUser[player.UserId]
	if not index then
		return
	end
	local handle = _plots[index]
	self.PlotReleased:fire(player, handle)

	-- Clear anything transient so the next owner gets a clean sanctuary.
	handle.pickupFolder:ClearAllChildren()
	handle.beastFolder:ClearAllChildren()
	handle.sign.Text = "Empty Sanctuary"

	for _, connection in ipairs(_altarConnections[index] or {}) do
		connection:Disconnect()
	end
	_altarConnections[index] = nil

	_ownerByIndex[index] = nil
	_indexByUser[player.UserId] = nil
	Logger:info("Released plot", index)
end

function PlotService:Start()
	local world = WorldBuilder.build()
	local plotsFolder = world:FindFirstChild("Plots") :: Folder

	for i = 1, PlotConfig.PLOT_COUNT do
		_plots[i] = PlotBuilder.build(i, WorldBuilder.plotCFrame(i), plotsFolder)
	end
	Logger:info("Island built with", PlotConfig.PLOT_COUNT, "sanctuaries.")

	-- Assign once data is loaded, so progression can be applied immediately.
	Registry.DataService.ProfileLoaded:connect(function(player)
		self:_assign(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:_release(player)
	end)

	-- Keep the "you can afford this" pad highlight live. Essence changes
	-- constantly, and a highlight that only refreshes on purchase would be wrong
	-- almost all the time. A 2s sweep over at most 8 plots is far cheaper than
	-- pushing pad state on every currency change.
	task.spawn(function()
		while true do
			task.wait(2)
			for userId, index in pairs(_indexByUser) do
				local player = Players:GetPlayerByUserId(userId)
				local handle = _plots[index]
				local data = player and Registry.DataService:get(player)
				if player and handle and data then
					local essence = data.currencies.essence or 0
					for _, spec in ipairs(PlotConfig.BuyPads) do
						local pad = handle.pads[spec.id]
						if pad and not pad.purchased then
							self:_paintPad(pad, spec, false, essence >= spec.cost)
						end
					end
				end
			end
		end
	end)
end

return PlotService
