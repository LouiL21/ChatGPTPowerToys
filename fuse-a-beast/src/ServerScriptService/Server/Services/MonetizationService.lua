--!strict
--[[
	MonetizationService
	Owns everything money-adjacent and exposes the multipliers other services read:
	  - gamepass ownership (verified on join, cached for instant benefit restore),
	  - developer-product fulfilment via an idempotent ProcessReceipt,
	  - timed boosts (luck / fusion-speed) from products and rewards,
	  - derived getters: essence multiplier, luck, fusion speed, offline cap,
	    display slots,
	  - VIP daily gems + Roblox Premium bonuses,
	  - live-event gating (isEventActive) used by fusion drop tables.

	Nothing here is trusted from the client: purchases are validated by Roblox,
	and PromptPurchase only *requests* a prompt — grants happen server-side.
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Logger = require(Shared.Util.Logger).new("Money")

local ServerNet = require(script.Parent.Parent.ServerNet)

local MonetizationService = { Name = "MonetizationService" }
local Registry: any

-- session boosts: userId -> { kind -> { mult, expiry } }
local _boosts: { [number]: { [string]: { mult: number, expiry: number } } } = {}
-- live events currently running (id -> true). Toggle via setEventActive / scheduler.
local _activeEvents: { [string]: boolean } = {}

function MonetizationService:Init(registry)
	Registry = registry
end

-- ── Gamepass ownership ──────────────────────────────────────────────────────

function MonetizationService:_refreshGamepasses(player: Player)
	local data = Registry.DataService:get(player)
	if not data then
		return
	end
	for key, pass in pairs(MonetizationConfig.Gamepasses) do
		if pass.id and pass.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			if ok then
				data.gamepasses[key] = owns
			end
		end
	end
	Registry.StateSync:push(player, { gamepasses = data.gamepasses })
end

function MonetizationService:ownsGamepass(player: Player, key: string): boolean
	local data = Registry.DataService:get(player)
	return data ~= nil and data.gamepasses[key] == true
end

-- ── Boosts ──────────────────────────────────────────────────────────────────

function MonetizationService:applyBoost(player: Player, boost: { kind: string, mult: number, seconds: number })
	local userBoosts = _boosts[player.UserId]
	if not userBoosts then
		userBoosts = {}
		_boosts[player.UserId] = userBoosts
	end
	local expiry = os.time() + boost.seconds
	local existing = userBoosts[boost.kind]
	-- Stacking rule: take the better mult and extend the timer (never shrink it).
	if existing and existing.expiry > os.time() then
		userBoosts[boost.kind] = { mult = math.max(existing.mult, boost.mult), expiry = math.max(existing.expiry, expiry) }
	else
		userBoosts[boost.kind] = { mult = boost.mult, expiry = expiry }
	end
	self:_pushBoosts(player)
end

function MonetizationService:_boostMult(player: Player, kind: string): number
	local userBoosts = _boosts[player.UserId]
	local boost = userBoosts and userBoosts[kind]
	if boost and boost.expiry > os.time() then
		return boost.mult
	end
	return 1
end

function MonetizationService:getActiveBoosts(player: Player)
	local out = {}
	local userBoosts = _boosts[player.UserId]
	if userBoosts then
		local now = os.time()
		for kind, boost in pairs(userBoosts) do
			if boost.expiry > now then
				table.insert(out, { kind = kind, mult = boost.mult, remaining = boost.expiry - now })
			end
		end
	end
	return out
end

function MonetizationService:_pushBoosts(player: Player)
	Registry.StateSync:push(player, {
		boosts = self:getActiveBoosts(player),
		ratePerSecond = Registry.EssenceService:getRate(player),
	})
end

-- ── Derived getters (read by gameplay services) ─────────────────────────────

function MonetizationService:getEssenceMultiplier(player: Player): number
	local mult = 1.0
	if self:ownsGamepass(player, "DoubleEssence") then
		mult *= (MonetizationConfig.Gamepasses.DoubleEssence.value :: number)
	end
	return mult
end

function MonetizationService:getLuck(player: Player): number
	local luck = GameConfig.BASE_LUCK
	if self:ownsGamepass(player, "LuckyAura") then
		luck += GameConfig.LUCKY_GAMEPASS_BONUS
	end
	if player.MembershipType == Enum.MembershipType.Premium then
		luck += GameConfig.PREMIUM_LUCK_BONUS
	end
	return luck * self:_boostMult(player, "luck")
end

function MonetizationService:getFusionSpeed(player: Player): number
	return self:_boostMult(player, "fusionSpeed")
end

function MonetizationService:getOfflineCap(player: Player): number
	if self:ownsGamepass(player, "ExtendedOffline") then
		return GameConfig.OFFLINE_CAP_SECONDS_GAMEPASS
	end
	return GameConfig.OFFLINE_CAP_SECONDS
end

function MonetizationService:getDisplaySlots(player: Player): number
	local slots = GameConfig.DISPLAY_SLOT_BASE
	if self:ownsGamepass(player, "ExtraSlots") then
		slots += (MonetizationConfig.Gamepasses.ExtraSlots.value :: number)
	end
	if self:ownsGamepass(player, "VIP") then
		slots += 1
	end
	return slots
end

-- ── Live events ─────────────────────────────────────────────────────────────

function MonetizationService:isEventActive(eventId: string): boolean
	return _activeEvents[eventId] == true
end

function MonetizationService:setEventActive(eventId: string, active: boolean)
	_activeEvents[eventId] = active or nil
	Logger:info("Event", eventId, active and "ENABLED" or "disabled")
end

-- ── Purchase flow ───────────────────────────────────────────────────────────

function MonetizationService:_promptPurchase(player: Player, payload)
	if typeof(payload) ~= "table" or typeof(payload.kind) ~= "string" or typeof(payload.key) ~= "string" then
		return
	end
	if payload.kind == "gamepass" then
		local pass = MonetizationConfig.Gamepasses[payload.key]
		if not pass or pass.id == 0 then
			ServerNet.notify(player, "This item isn't available yet.", "warn")
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, pass.id)
	elseif payload.kind == "product" then
		local product = MonetizationConfig.Products[payload.key]
		if not product or product.id == 0 then
			ServerNet.notify(player, "This item isn't available yet.", "warn")
			return
		end
		MarketplaceService:PromptProductPurchase(player, product.id)
	end
end

-- Idempotent developer-product fulfilment.
function MonetizationService:_processReceipt(receiptInfo): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- retry when they're back
	end
	local data = Registry.DataService:get(player)
	if not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local receiptKey = tostring(receiptInfo.PurchaseId)
	if data.receipts[receiptKey] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted
	end

	local key, product = MonetizationConfig.getProductByAssetId(receiptInfo.ProductId)
	if not product then
		Logger:warn("Unknown product id", receiptInfo.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Grant, then record. If the server dies between grant and record, the receipt
	-- retries and the (rare) double-grant is preferable to a lost purchase.
	local grant = product.grant
	if grant.essence then
		Registry.CurrencyService:add(player, "essence", grant.essence)
	end
	if grant.gems then
		Registry.CurrencyService:add(player, "gems", grant.gems)
	end
	if grant.boost then
		self:applyBoost(player, grant.boost)
	end

	data.receipts[receiptKey] = true
	Registry.DataService:save(player) -- persist the receipt promptly
	ServerNet.notify(player, "Purchase complete: " .. product.name, "success")
	Registry.AnalyticsService:log(player, "purchase", { product = key, robux = product.price })
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MonetizationService:_onGamepassFinished(player: Player, passId: number, wasPurchased: boolean)
	if not wasPurchased then
		return
	end
	local data = Registry.DataService:get(player)
	if not data then
		return
	end
	for key, pass in pairs(MonetizationConfig.Gamepasses) do
		if pass.id == passId then
			data.gamepasses[key] = true
			ServerNet.notify(player, "Unlocked: " .. pass.name, "success")
			Registry.StateSync:push(player, { gamepasses = data.gamepasses, ratePerSecond = Registry.EssenceService:getRate(player) })
			Registry.AnalyticsService:log(player, "purchase", { gamepass = key, robux = pass.price })
			return
		end
	end
end

-- VIP daily gems + benefits check on join.
function MonetizationService:_onJoin(player: Player, data)
	self:_refreshGamepasses(player)
	if self:ownsGamepass(player, "VIP") then
		local todayStr = os.date("!%Y-%m-%d")
		if data.login.vipClaimDate ~= todayStr then
			data.login.vipClaimDate = todayStr
			Registry.CurrencyService:add(player, "gems", 25)
			ServerNet.notify(player, "VIP daily bonus: +25 gems!", "success")
		end
	end
end

function MonetizationService:Start()
	Registry.DataService.ProfileLoaded:connect(function(player, data)
		task.spawn(function()
			self:_onJoin(player, data)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		_boosts[player.UserId] = nil
	end)

	ServerNet.onEvent("PromptPurchase", function(player, payload)
		self:_promptPurchase(player, payload)
	end)

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		self:_onGamepassFinished(player, passId, purchased)
	end)
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		return self:_processReceipt(receiptInfo)
	end

	-- Expire boosts periodically so timers visibly tick down client-side.
	task.spawn(function()
		while true do
			task.wait(10)
			for _, player in ipairs(Players:GetPlayers()) do
				local userBoosts = _boosts[player.UserId]
				if userBoosts then
					local now = os.time()
					local changed = false
					for kind, boost in pairs(userBoosts) do
						if boost.expiry <= now then
							userBoosts[kind] = nil
							changed = true
						end
					end
					if changed and Registry.DataService:isLoaded(player) then
						self:_pushBoosts(player)
					end
				end
			end
		end
	end)
end

return MonetizationService
