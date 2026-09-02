--!strict
--[[
	BeastService
	Puts the collection into the world. Beasts on a player's display list are
	spawned as physical creatures that wander their sanctuary and periodically
	drop essence orbs the owner runs over.

	Two things this earns the game:
	  1. Status is visible — a Mythic towers over the plot and glows, so a
	     visitor can see what you've built without opening a menu.
	  2. Active play pays. Displayed beasts already raise the passive rate; the
	     orbs add roughly 40% on top for players who actually run around, without
	     ever making idle progression feel pointless.

	All beasts across the server are driven by ONE movement loop over anchored
	parts, so a full island costs no physics simulation.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local PlotConfig = require(Shared.Config.PlotConfig)
local VariantConfig = require(Shared.Config.VariantConfig)
local Logger = require(Shared.Util.Logger).new("Beast")

local BeastModelFactory = require(script.Parent.Parent.World.BeastModelFactory)

local BeastService = { Name = "BeastService" }
local Registry: any

type Agent = {
	model: Model,
	userId: number,
	position: Vector3,
	target: Vector3,
	facing: number,
	nextOrb: number,
	speed: number,
	homeCentre: Vector3,
	rarity: string,
	variant: string,
}

local _agents: { Agent } = {}

function BeastService:Init(registry)
	Registry = registry
end

--[[
	Where beast `index` of `total` lives.

	Every beast used to wander the whole habitat, which meant they converged on
	the middle and a full sanctuary looked like a scrum. Each now gets its own
	patch, laid out by the golden angle so the points spread evenly across the
	disc however many there are — no clumps, no rows, and adding a beast never
	moves anyone else's spot much.
]]
local GOLDEN_ANGLE = math.pi * (3 - math.sqrt(5))

local function anchorFor(centre: Vector3, index: number, total: number): Vector3
	local angle = index * GOLDEN_ANGLE
	-- sqrt keeps the density even rather than crowding the centre.
	local radius = PlotConfig.HABITAT_RADIUS * math.sqrt((index + 0.5) / math.max(1, total))
	return centre + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

-- A wander target inside one beast's own patch.
local function roamPoint(anchor: Vector3): Vector3
	local angle = math.random() * math.pi * 2
	local radius = math.sqrt(math.random()) * PlotConfig.BEAST_ROAM_RADIUS
	return anchor + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

-- Rebuild every physical beast on a player's plot from their display list.
function BeastService:refresh(player: Player)
	local handle = Registry.PlotService:getHandle(player)
	local data = Registry.DataService:get(player)
	if not handle or not data then
		return
	end

	-- Drop existing agents for this player.
	for i = #_agents, 1, -1 do
		if _agents[i].userId == player.UserId then
			table.remove(_agents, i)
		end
	end
	handle.beastFolder:ClearAllChildren()

	local centre = (handle.origin * CFrame.new(PlotConfig.HABITAT_CENTRE)).Position
	local slots = Registry.PlotService:habitatSlots(player)

	local spawned = 0
	for _, item in ipairs(data.display) do
		if spawned >= slots then
			break
		end
		-- display entries are { beastId, variant } pairs.
		if typeof(item) == "table" and typeof(item.beastId) == "string" then
			local model = BeastModelFactory.create(item.beastId, item.variant)
			if model then
				local anchor = anchorFor(centre, spawned, math.min(slots, #data.display))
				local position = roamPoint(anchor)
				BeastModelFactory.pivot(model, CFrame.new(position))
				model.Parent = handle.beastFolder

				table.insert(_agents, {
					model = model,
					userId = player.UserId,
					position = position,
					target = roamPoint(anchor),
					facing = 0,
					nextOrb = os.clock() + math.random() * PlotConfig.ESSENCE_ORB_INTERVAL,
					speed = 3 + math.random() * 2.5,
					homeCentre = anchor,
					rarity = model:GetAttribute("Rarity") or "Common",
					variant = model:GetAttribute("Variant") or "Normal",
				})
				spawned += 1
			end
		end
	end

	Logger:debug("Spawned", spawned, "beasts for", player.Name)
end

-- Plays the materialisation moment at the altar when a fusion resolves.
function BeastService:playFusionBurst(player: Player, rarity: string)
	local handle = Registry.PlotService:getHandle(player)
	if not handle then
		return
	end
	local crystal = handle.altarCrystal
	local original = crystal.Size
	local light = crystal:FindFirstChildOfClass("PointLight")

	task.spawn(function()
		for i = 1, 8 do
			crystal.Size = original * (1 + i * 0.18)
			if light then
				light.Brightness = 3 + i
			end
			task.wait(0.03)
		end
		for i = 8, 1, -1 do
			crystal.Size = original * (1 + i * 0.18)
			if light then
				light.Brightness = 3 + i
			end
			task.wait(0.03)
		end
		crystal.Size = original
		if light then
			light.Brightness = 3
		end
	end)
end

--[[
	An orb is worth what THIS beast contributes, scaled by its rarity and
	variant. The previous even split meant adding beasts made each orb smaller,
	so the reward for growing a sanctuary was more running for the same money —
	which is why orbs felt like they did nothing.
]]
function BeastService:_dropOrb(agent: Agent, player: Player)
	local rate = Registry.EssenceService:getRate(player)
	local rarityMult = PlotConfig.ORB_RARITY_MULT[agent.rarity] or 1
	local variantMult = VariantConfig.get(agent.variant).essence or 1

	local amount = rate * PlotConfig.ESSENCE_ORB_INTERVAL * PlotConfig.ORB_SHARE * rarityMult * variantMult
	if amount <= 0 then
		return
	end
	Registry.PickupService:spawn(
		player,
		"essence",
		{ amount = math.floor(amount + 0.5), rarity = agent.rarity, variant = agent.variant },
		agent.position + Vector3.new(0, 2.5, 0)
	)
end

function BeastService:Start()
	Registry.PlotService.PlotAssigned:connect(function(player)
		self:refresh(player)
	end)
	Registry.PlotService.PlotReleased:connect(function(player)
		for i = #_agents, 1, -1 do
			if _agents[i].userId == player.UserId then
				table.remove(_agents, i)
			end
		end
	end)

	-- Wander + orb loop, shared across every beast on the server.
	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for _, agent in ipairs(_agents) do
			if agent.model.Parent then
				local toTarget = agent.target - agent.position
				local distance = toTarget.Magnitude

				if distance < 2 then
					agent.target = roamPoint(agent.homeCentre)
				else
					local step = math.min(agent.speed * dt, distance)
					agent.position += toTarget.Unit * step
					-- Ease the facing toward travel direction so turns look natural.
					local wanted = math.atan2(-toTarget.X, -toTarget.Z)
					local delta = (wanted - agent.facing + math.pi) % (math.pi * 2) - math.pi
					agent.facing += delta * math.min(1, dt * 5)
				end

				-- Legs stride, tails sway, wings beat. `moving` is 1 while walking
				-- and 0 at the target, so a beast that has arrived settles into an
				-- idle instead of marching on the spot.
				local bob = math.sin(now * 3 + agent.speed) * 0.18
				BeastModelFactory.pivot(
					agent.model,
					CFrame.new(agent.position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, agent.facing, 0),
					now + agent.speed,
					distance < 2 and 0 or 1
				)

				if now >= agent.nextOrb then
					agent.nextOrb = now + PlotConfig.ESSENCE_ORB_INTERVAL
					local player = Players:GetPlayerByUserId(agent.userId)
					if player and Registry.DataService:isLoaded(player) then
						self:_dropOrb(agent, player)
					end
				end
			end
		end
	end)
end

return BeastService
