--!strict
--[[
	PickupService
	Physical collectibles — the moment-to-moment gameplay. Element nodes drop
	shards and beasts drop essence orbs; the player runs over them to collect.

	Ownership rule: a pickup belongs to the plot it spawned on and only that
	plot's owner can collect it. This keeps the "safe sanctuary" promise — nobody
	can vacuum up a visitor's drops — and is enforced server-side.

	Performance: pickups are CanCollide=false anchored parts animated by ONE
	shared loop (not a thread each), and every plot is hard-capped by
	PlotConfig.MAX_PICKUPS_PER_PLOT so a idle-rich plot can never flood the server.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local PlotConfig = require(Shared.Config.PlotConfig)
local ElementConfig = require(Shared.Config.ElementConfig)
local VariantConfig = require(Shared.Config.VariantConfig)
local Format = require(Shared.Util.Format)

local PickupService = { Name = "PickupService" }
local Registry: any

-- part -> record. Kept as a plain map so the animation loop is a single pass.
local _active: { [BasePart]: { spawnedAt: number, phase: number, baseY: number } } = {}

function PickupService:Init(registry)
	Registry = registry
end

local function elementColor(elementId: string): Color3
	local element = ElementConfig.ById[elementId]
	if not element then
		return Color3.fromRGB(220, 220, 220)
	end
	return Color3.new(element.color[1], element.color[2], element.color[3])
end

function PickupService:countOnPlot(handle): number
	return #handle.pickupFolder:GetChildren()
end

--[[
	Spawns a pickup on `player`'s plot.
	kind    — "shard" | "essence"
	payload — { element = "Fire" } for shards, { amount = n } for essence
]]
function PickupService:spawn(player: Player, kind: string, payload: any, position: Vector3): BasePart?
	local handle = Registry.PlotService:getHandle(player)
	if not handle then
		return nil
	end
	if self:countOnPlot(handle) >= PlotConfig.MAX_PICKUPS_PER_PLOT then
		return nil -- plot is saturated; collecting is the way to make room
	end

	local isShard = kind == "shard"
	-- Essence orbs take the dropping beast's variant colour, so a Golden's orb
	-- is visibly a Golden's orb — the payout is legible before you touch it.
	local color = isShard and elementColor(payload.element)
		or VariantConfig.get(payload.variant or "Normal").color:Lerp(Color3.fromRGB(255, 196, 77), 0.45)

	-- Rarer drops are physically bigger. Same rule as the beasts themselves.
	local weight = isShard and 1 or (PlotConfig.ORB_RARITY_MULT[payload.rarity or "Common"] or 1)
	local orbSize = math.clamp(1.9 + math.log(weight + 1) * 0.9, 1.9, 4.2)

	local part = Instance.new("Part")
	part.Name = isShard and ("Shard_" .. tostring(payload.element)) or "EssenceOrb"
	part.Size = isShard and Vector3.new(1.8, 2.6, 1.8) or Vector3.new(orbSize, orbSize, orbSize)
	part.Shape = isShard and Enum.PartType.Block or Enum.PartType.Ball
	part.Color = color
	part.Material = Enum.Material.Neon
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	part.Position = position

	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = isShard and 7 or 7 + orbSize
	light.Brightness = 1.4
	light.Parent = part

	-- A worthwhile orb advertises itself. Sparkle scales with value so a Mythic
	-- drop is unmistakable across the plot.
	if not isShard and weight > 1 then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Color = ColorSequence.new(color)
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, orbSize * 0.35),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparkle.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.15),
			NumberSequenceKeypoint.new(1, 1),
		})
		sparkle.Lifetime = NumberRange.new(0.4, 0.9)
		sparkle.Rate = math.min(24, 5 + weight)
		sparkle.Speed = NumberRange.new(0.5, 2)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Parent = part
	end

	part:SetAttribute("Kind", kind)
	part:SetAttribute("OwnerUserId", player.UserId)
	if isShard then
		part:SetAttribute("Element", payload.element)
	else
		part:SetAttribute("Amount", payload.amount)
	end

	part.Touched:Connect(function(hit)
		self:_onTouched(part, hit)
	end)

	part.Parent = handle.pickupFolder
	_active[part] = { spawnedAt = os.clock(), phase = math.random() * math.pi * 2, baseY = position.Y }

	-- Safety net in case the collection path never fires.
	Debris:AddItem(part, PlotConfig.PICKUP_LIFETIME)
	return part
end

--[[
	Floating "+N" at the point of collection. Without it a pickup is a part that
	silently vanishes and a counter that moves somewhere else on screen — which
	reads as nothing happening. This is the single cheapest way to make gathering
	feel like it pays.

	The popup is a tiny anchored, non-queried part that deletes itself, and it is
	visible to everyone on the plot on purpose: watching a visitor's Mythic pay
	out is an advert for the game.
]]
function PickupService:_popup(parent: Instance, position: Vector3, text: string, color: Color3)
	local host = Instance.new("Part")
	host.Size = Vector3.new(0.2, 0.2, 0.2)
	host.Transparency = 1
	host.Anchored = true
	host.CanCollide = false
	host.CanQuery = false
	host.CastShadow = false
	host.Position = position
	host.Name = "Popup"
	host.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(150, 44)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 90
	billboard.Parent = host

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.TextStrokeColor3 = Color3.fromRGB(10, 7, 19)
	label.Text = text
	label.Parent = billboard

	task.spawn(function()
		local start = os.clock()
		while os.clock() - start < 0.9 do
			local t = (os.clock() - start) / 0.9
			host.Position = position + Vector3.new(0, t * 4.5, 0)
			label.TextTransparency = math.max(0, (t - 0.45) / 0.55)
			label.TextStrokeTransparency = 0.2 + label.TextTransparency * 0.8
			task.wait()
		end
		host:Destroy()
	end)
end

function PickupService:_onTouched(part: BasePart, hit: BasePart)
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if player then
		self:_collect(part, player)
	end
end

-- The single credit path. Both the Touched handler and the magnet's proximity
-- check funnel through here, so ownership and the double-credit guard are
-- enforced in exactly one place.
function PickupService:_collect(part: BasePart, player: Player)
	if not part.Parent or not _active[part] then
		return
	end
	-- Only the plot owner may collect. Visitors can look, not hoover.
	if part:GetAttribute("OwnerUserId") ~= player.UserId then
		return
	end
	if not Registry.DataService:isLoaded(player) then
		return
	end

	-- Claim immediately so a fast double-touch can't double-credit.
	_active[part] = nil
	local folder = part.Parent
	local where = part.Position
	part.Parent = nil

	local kind = part:GetAttribute("Kind")
	if kind == "shard" then
		local element = part:GetAttribute("Element")
		if typeof(element) == "string" then
			Registry.CurrencyService:addShards(player, element, 1)
			Registry.QuestService:track(player, "collect_shard", 1)
			if folder then
				self:_popup(folder, where, "+1 " .. element, elementColor(element))
			end
		end
	elseif kind == "essence" then
		local amount = part:GetAttribute("Amount")
		if typeof(amount) == "number" and amount > 0 then
			Registry.CurrencyService:add(player, "essence", amount)
			local data = Registry.DataService:get(player)
			if data then
				data.stats.totalEssenceCollected += amount
			end
			Registry.QuestService:track(player, "collect_essence", amount)
			if folder then
				self:_popup(folder, where, "+" .. Format.abbreviate(amount), part.Color)
			end
		end
	end

	part:Destroy()
end

function PickupService:clearPlot(handle)
	for _, child in ipairs(handle.pickupFolder:GetChildren()) do
		_active[child :: BasePart] = nil
		child:Destroy()
	end
end

function PickupService:Start()
	Registry.PlotService.PlotReleased:connect(function(_, handle)
		self:clearPlot(handle)
	end)

	-- One shared loop bobs, spins and magnetises every pickup on the server.
	-- Owner positions are resolved ONCE per frame rather than once per pickup,
	-- so the cost stays proportional to players, not to parts.
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()

		local ownerPosition: { [number]: Vector3 } = {}
		local ownerById: { [number]: Player } = {}
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				ownerPosition[player.UserId] = root.Position
				ownerById[player.UserId] = player
			end
		end

		local range = PlotConfig.PICKUP_MAGNET_RANGE
		for part, record in pairs(_active) do
			if not part.Parent then
				_active[part] = nil
			else
				local userId = part:GetAttribute("OwnerUserId") :: number
				local target = ownerPosition[userId]
				local toOwner = target and (target - part.Position) or nil

				if toOwner and toOwner.Magnitude < range then
					-- Homing. A fast-moving anchored part can tunnel past a
					-- character without ever raising Touched, so close the last
					-- few studs with an explicit claim through the same guarded
					-- path rather than trusting the physics event.
					if toOwner.Magnitude < 4 then
						self:_collect(part, ownerById[userId])
					else
						local step = math.min(PlotConfig.PICKUP_MAGNET_SPEED * dt, toOwner.Magnitude)
						part.Position += toOwner.Unit * step
						record.baseY = part.Position.Y
					end
				else
					local t = now - record.spawnedAt + record.phase
					part.CFrame = CFrame.new(part.Position.X, record.baseY + math.sin(t * 2) * 0.35, part.Position.Z)
						* CFrame.Angles(0, t * 1.6, 0)
				end
			end
		end
	end)
end

return PickupService
