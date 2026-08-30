--!strict
--[[
	PetService
	Your strongest (or chosen) beast follows you around the island as an active
	pet. This is the single highest-impact "feels like a real Roblox game" touch:
	you are never walking alone, and everyone else can see what you're carrying.

	The pet is also your Arena fighter, so choosing one is a real decision rather
	than pure decoration.

	Movement is a smoothed follow with a hover bob, driven by ONE shared loop over
	anchored parts — no pathfinding, no physics.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local BeastConfig = require(Shared.Config.BeastConfig)
local VariantConfig = require(Shared.Config.VariantConfig)
local BeastInventory = require(Shared.Util.BeastInventory)

local BeastModelFactory = require(script.Parent.Parent.World.BeastModelFactory)
local ServerNet = require(script.Parent.Parent.ServerNet)

local PetService = { Name = "PetService" }
local Registry: any

type PetAgent = {
	model: Model,
	userId: number,
	position: Vector3,
	facing: number,
	busy: boolean, -- true while the pet is fighting in the Arena
}

local _pets: { [number]: PetAgent } = {}

local FOLLOW_DISTANCE = 6
local FOLLOW_HEIGHT = 2.5
local FOLLOW_SPEED = 12

function PetService:Init(registry)
	Registry = registry
end

function PetService:getAgent(player: Player): PetAgent?
	return _pets[player.UserId]
end

function PetService:despawn(player: Player)
	local agent = _pets[player.UserId]
	if agent then
		agent.model:Destroy()
		_pets[player.UserId] = nil
	end
end

-- (Re)spawns the active pet from the profile.
function PetService:refresh(player: Player)
	local data = Registry.DataService:get(player)
	if not data then
		return
	end
	self:despawn(player)

	local beastId, variant = data.activePet.beastId, data.activePet.variant
	-- Fall back to the strongest owned beast if the saved one is gone.
	if beastId == "" or not BeastInventory.owns(data.codex, beastId, variant) then
		local bestId, bestVariant = BeastInventory.strongest(data.codex)
		if not bestId then
			Registry.StateSync:push(player, { activePet = data.activePet })
			return
		end
		beastId, variant = bestId, bestVariant :: string
		data.activePet = { beastId = beastId, variant = variant }
	end

	local model = BeastModelFactory.create(beastId, 1, variant)
	if not model then
		return
	end
	model.Name = "Pet_" .. player.Name

	local character = player.Character
	local start = character and character:GetPivot().Position or Vector3.new(0, 10, 0)
	local position = start + Vector3.new(FOLLOW_DISTANCE, FOLLOW_HEIGHT, 0)
	BeastModelFactory.pivot(model, CFrame.new(position))
	model.Parent = workspace:FindFirstChild("FaBWorld") or workspace

	_pets[player.UserId] = { model = model, userId = player.UserId, position = position, facing = 0, busy = false }
	Registry.StateSync:push(player, { activePet = data.activePet })
end

-- Client asks to make a specific owned beast the active pet.
function PetService:setPet(player: Player, payload)
	local data = Registry.DataService:get(player)
	if not data or typeof(payload) ~= "table" then
		return
	end
	if typeof(payload.beastId) ~= "string" or typeof(payload.variant) ~= "string" then
		return
	end
	if not BeastInventory.owns(data.codex, payload.beastId, payload.variant) then
		ServerNet.notify(player, "You don't own that beast.", "warn")
		return
	end

	data.activePet = { beastId = payload.beastId, variant = payload.variant }
	self:refresh(player)

	local beast = BeastConfig.ById[payload.beastId]
	ServerNet.notify(player, VariantConfig.label(payload.variant, beast.name) .. " is now following you!", "success")
end

-- Lets the Arena take control of the pet's position during a battle.
function PetService:setBusy(player: Player, busy: boolean)
	local agent = _pets[player.UserId]
	if agent then
		agent.busy = busy
	end
end

function PetService:placeAt(player: Player, cframe: CFrame)
	local agent = _pets[player.UserId]
	if agent then
		agent.position = cframe.Position
		BeastModelFactory.pivot(agent.model, cframe)
	end
end

function PetService:Start()
	Registry.DataService.ProfileLoaded:connect(function(player)
		-- Wait for the character so the pet spawns beside them, not at origin.
		task.delay(1.5, function()
			if Registry.DataService:isLoaded(player) then
				self:refresh(player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:despawn(player)
	end)

	ServerNet.onEvent("SetPet", function(player, payload)
		self:setPet(player, payload)
	end)

	RunService.Heartbeat:Connect(function(dt)
		local now = os.clock()
		for userId, agent in pairs(_pets) do
			local player = Players:GetPlayerByUserId(userId)
			local character = player and player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?

			if not agent.model.Parent then
				_pets[userId] = nil
			elseif root and not agent.busy then
				-- Trail behind and to the right of the owner.
				local target = root.CFrame * CFrame.new(FOLLOW_DISTANCE * 0.6, FOLLOW_HEIGHT, FOLLOW_DISTANCE * 0.7)
				local toTarget = target.Position - agent.position
				local distance = toTarget.Magnitude

				if distance > 60 then
					agent.position = target.Position -- snap after a teleport
				elseif distance > 1.5 then
					agent.position += toTarget.Unit * math.min(FOLLOW_SPEED * dt * (distance / 6), distance)
					local wanted = math.atan2(-toTarget.X, -toTarget.Z)
					local delta = (wanted - agent.facing + math.pi) % (math.pi * 2) - math.pi
					agent.facing += delta * math.min(1, dt * 6)
				end

				local bob = math.sin(now * 3.4) * 0.28
				BeastModelFactory.pivot(
					agent.model,
					CFrame.new(agent.position + Vector3.new(0, bob, 0)) * CFrame.Angles(0, agent.facing, 0)
				)
			end
		end
	end)
end

return PetService
