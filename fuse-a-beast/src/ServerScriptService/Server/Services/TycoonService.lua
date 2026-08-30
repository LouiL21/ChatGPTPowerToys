--!strict
--[[
	TycoonService
	The tycoon spine: step on a buy-pad, pay essence, and something physically
	appears or improves on your sanctuary.

	This is the loop Roblox players already know and love — walk to a pad, watch
	the plot grow — wired to the fusion economy rather than a conveyor belt.

	Server-authoritative throughout: the pad only reacts to the OWNER standing on
	it, the charge goes through CurrencyService, and the unlock is written to the
	profile before any geometry changes.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local PlotConfig = require(Shared.Config.PlotConfig)
local Format = require(Shared.Util.Format)

local ServerNet = require(script.Parent.Parent.ServerNet)

local TycoonService = { Name = "TycoonService" }
local Registry: any

local PAD_BY_ID = {}
for _, spec in ipairs(PlotConfig.BuyPads) do
	PAD_BY_ID[spec.id] = spec
end

-- Debounce so standing on a pad doesn't fire dozens of purchase attempts.
local _lastAttempt: { [string]: number } = {}

function TycoonService:Init(registry)
	Registry = registry
end

function TycoonService:_apply(player: Player, spec): boolean
	local data = Registry.DataService:get(player)
	if not data then
		return false
	end

	if spec.kind == "node" then
		data.plot.unlockedNodes[spec.element] = true
	elseif spec.kind == "nodeTier" then
		-- Tiers are absolute, never additive, so buying out of order can't stack.
		data.plot.nodeTier = math.max(data.plot.nodeTier, spec.value)
	elseif spec.kind == "habitat" then
		data.plot.habitatSlots += spec.value
	elseif spec.kind == "altar" then
		data.altar.level += spec.value
	else
		return false
	end
	return true
end

function TycoonService:purchase(player: Player, padId: string)
	local spec = PAD_BY_ID[padId]
	local data = Registry.DataService:get(player)
	if not spec or not data then
		return
	end
	if data.plot.purchasedPads[padId] then
		return -- already owned
	end

	if not Registry.CurrencyService:trySpend(player, "essence", spec.cost) then
		ServerNet.notify(
			player,
			string.format("%s costs %s essence.", spec.label, Format.abbreviate(spec.cost)),
			"warn"
		)
		return
	end

	data.plot.purchasedPads[padId] = true
	if not self:_apply(player, spec) then
		-- Unknown kind: refund rather than silently eating the payment.
		data.plot.purchasedPads[padId] = nil
		Registry.CurrencyService:add(player, "essence", spec.cost)
		return
	end

	Registry.PlotService:applyProgression(player)
	Registry.BeastService:refresh(player) -- habitat changes may allow more beasts
	Registry.StateSync:push(player, {
		plot = data.plot,
		altar = { level = data.altar.level },
		ratePerSecond = Registry.EssenceService:getRate(player),
	})
	ServerNet.notify(player, "Unlocked: " .. spec.label .. "!", "success")
	Registry.QuestService:track(player, "tycoon_purchase", 1)
	Registry.AnalyticsService:log(player, "tycoon_purchase", { pad = padId, cost = spec.cost })
end

-- plotIndex -> { RBXScriptConnection }. Pads outlive their owners, so every
-- binding is tracked and torn down on release (otherwise handlers accumulate
-- one set per player who ever held the plot).
local _padConnections: { [number]: { RBXScriptConnection } } = {}

function TycoonService:_bindPad(player: Player, padHandle, spec, plotIndex: number)
	local connection = padHandle.pad.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then
			return
		end
		local toucher = Players:GetPlayerFromCharacter(character)
		-- Only the plot's owner can buy on their own pads.
		if not toucher or toucher ~= player then
			return
		end

		local key = tostring(player.UserId) .. ":" .. spec.id
		local now = os.clock()
		if _lastAttempt[key] and now - _lastAttempt[key] < 1 then
			return
		end
		_lastAttempt[key] = now

		self:purchase(player, spec.id)
	end)

	local bucket = _padConnections[plotIndex]
	if not bucket then
		bucket = {}
		_padConnections[plotIndex] = bucket
	end
	table.insert(bucket, connection)
end

function TycoonService:_unbindPlot(plotIndex: number)
	local bucket = _padConnections[plotIndex]
	if not bucket then
		return
	end
	for _, connection in ipairs(bucket) do
		connection:Disconnect()
	end
	_padConnections[plotIndex] = nil
end

function TycoonService:Start()
	Registry.PlotService.PlotAssigned:connect(function(player, handle)
		-- Rebind pads to the new owner each time a plot is claimed.
		self:_unbindPlot(handle.index)
		for _, spec in ipairs(PlotConfig.BuyPads) do
			local padHandle = handle.pads[spec.id]
			if padHandle then
				self:_bindPad(player, padHandle, spec, handle.index)
			end
		end
	end)

	Registry.PlotService.PlotReleased:connect(function(_, handle)
		self:_unbindPlot(handle.index)
	end)

	Players.PlayerRemoving:Connect(function(player)
		for key in pairs(_lastAttempt) do
			if string.sub(key, 1, #tostring(player.UserId) + 1) == tostring(player.UserId) .. ":" then
				_lastAttempt[key] = nil
			end
		end
	end)
end

return TycoonService
