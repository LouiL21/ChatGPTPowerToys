--!strict
--[[
	NodeService
	Drives the element nodes on each sanctuary: every node that the owner has
	unlocked periodically ejects a shard pickup nearby for them to run over.

	This replaces the old invisible "shards tick into your inventory" model with
	something physical to do — while the offline/idle accrual in EssenceService
	still rewards stepping away, so both play styles are served.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local PlotConfig = require(Shared.Config.PlotConfig)

local NodeService = { Name = "NodeService" }
local Registry: any

-- userId -> { [elementId] = nextEmitClock }
local _timers: { [number]: { [string]: number } } = {}

function NodeService:Init(registry)
	Registry = registry
end

function NodeService:_interval(player: Player): number
	local data = Registry.DataService:get(player)
	local tier = data and data.plot.nodeTier or 1
	return PlotConfig.NODE_BASE_INTERVAL * PlotConfig.NODE_TIER_SPEEDUP ^ (tier - 1)
end

function NodeService:_emit(player: Player, node)
	-- Scatter the drop around the node so collecting is a little run, not a
	-- single stationary tap.
	local angle = math.random() * math.pi * 2
	local distance = 4 + math.random() * 5
	local position = node.emitPoint + Vector3.new(math.cos(angle) * distance, 1.5, math.sin(angle) * distance)
	Registry.PickupService:spawn(player, "shard", { element = node.element }, position)
end

function NodeService:Start()
	Players.PlayerRemoving:Connect(function(player)
		_timers[player.UserId] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(0.5)
			local now = os.clock()

			for _, player in ipairs(Players:GetPlayers()) do
				if Registry.DataService:isLoaded(player) then
					local handle = Registry.PlotService:getHandle(player)
					if handle then
						local timers = _timers[player.UserId]
						if not timers then
							timers = {}
							_timers[player.UserId] = timers
						end

						local interval = self:_interval(player)
						for elementId, node in pairs(handle.nodes) do
							if node.unlocked then
								local nextAt = timers[elementId]
								if not nextAt then
									-- Stagger first emissions so nodes don't fire in lockstep.
									timers[elementId] = now + math.random() * interval
								elseif now >= nextAt then
									timers[elementId] = now + interval
									self:_emit(player, node)
								end
							end
						end
					end
				end
			end
		end
	end)
end

return NodeService
