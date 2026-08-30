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
	local color = isShard and elementColor(payload.element) or Color3.fromRGB(255, 196, 77)

	local part = Instance.new("Part")
	part.Name = isShard and ("Shard_" .. tostring(payload.element)) or "EssenceOrb"
	part.Size = isShard and Vector3.new(1.8, 2.6, 1.8) or Vector3.new(2, 2, 2)
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
	light.Range = 7
	light.Brightness = 1.4
	light.Parent = part

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

function PickupService:_onTouched(part: BasePart, hit: BasePart)
	if not part.Parent or not _active[part] then
		return
	end
	local character = hit:FindFirstAncestorOfClass("Model")
	if not character then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
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
	part.Parent = nil

	local kind = part:GetAttribute("Kind")
	if kind == "shard" then
		local element = part:GetAttribute("Element")
		if typeof(element) == "string" then
			Registry.CurrencyService:addShards(player, element, 1)
			Registry.QuestService:track(player, "collect_shard", 1)
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

	-- One shared loop bobs and spins every pickup on the server.
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for part, record in pairs(_active) do
			if not part.Parent then
				_active[part] = nil
			else
				local t = now - record.spawnedAt + record.phase
				part.CFrame = CFrame.new(part.Position.X, record.baseY + math.sin(t * 2) * 0.35, part.Position.Z)
					* CFrame.Angles(0, t * 1.6, 0)
			end
		end
	end)
end

return PickupService
