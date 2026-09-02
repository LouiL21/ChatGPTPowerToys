--!strict
--[[
	EssenceService
	The idle engine. Owns:
	  - continuous essence + shard generation (server-authoritative tick),
	  - offline earnings on join (the Grow-a-Garden "reward stepping away" hook),
	  - Altar upgrades and Ascension (rebirth),
	  - the Sanctuary display boost (idle synergy with the collection loop),
	  - the manual "tap" collect (a small active-play bonus that never replaces idle).

	All rates are derived here so there is one source of truth for "how fast do I
	earn", used both by generation and by the client-facing rate readout.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local PlotConfig = require(Shared.Config.PlotConfig)
local ElementConfig = require(Shared.Config.ElementConfig)
local BeastConfig = require(Shared.Config.BeastConfig)
local VariantConfig = require(Shared.Config.VariantConfig)
local Logger = require(Shared.Util.Logger).new("Essence")

local ServerNet = require(script.Parent.Parent.ServerNet)

local EssenceService = { Name = "EssenceService" }
local Registry: any

-- session-only fractional shard accumulator (userId -> fractional shards)
local _shardAccum: { [number]: number } = {}

-- Pre-build a weighted element picker.
local _elementBag: { string } = {}
do
	for _, element in ipairs(ElementConfig.List) do
		local weight = math.floor(element.baseWeight * 20 + 0.5)
		for _ = 1, weight do
			table.insert(_elementBag, element.id)
		end
	end
end

local function randomElement(): string
	return _elementBag[math.random(1, #_elementBag)]
end

function EssenceService:Init(registry)
	Registry = registry
end

-- ── Derived rates ───────────────────────────────────────────────────────────

-- Beasts living in the sanctuary raise essence output. Rarity sets the base
-- contribution; the variant multiplies it, so upgrading a beast in the Chamber
-- pays off economically as well as in the Arena.
function EssenceService:_displayBoost(data): number
	local boost = 1.0
	for _, item in ipairs(data.display) do
		if typeof(item) == "table" then
			local beast = BeastConfig.ById[item.beastId]
			if beast then
				local per = GameConfig.DISPLAY_BOOST_PER_RARITY[beast.rarity] or 0
				boost += per * VariantConfig.get(item.variant).essence
			end
		end
	end
	return boost
end

function EssenceService:_ascensionMult(data): number
	return 1 + data.ascension.count * GameConfig.ASCENSION_MULT_PER_LEVEL
end

-- essence / second
function EssenceService:getRate(player: Player): number
	local data = Registry.DataService:get(player)
	if not data then
		return 0
	end
	-- The Barn is a rested-beasts bonus rather than another flat habitat pad, so
	-- buying it is felt everywhere rather than only in the display list.
	local barn = data.plot.purchasedPads["beast_barn"] and (1 + PlotConfig.BARN_ESSENCE_BONUS) or 1
	local house = data.plot.purchasedPads["cottage"] and (1 + PlotConfig.HOUSE_ESSENCE_BONUS) or 1

	local rate = GameConfig.BASE_ESSENCE_PER_SECOND
		* GameConfig.ALTAR_RATE_GROWTH ^ (data.altar.level - 1)
		* self:_ascensionMult(data)
		* self:_displayBoost(data)
		* barn
		* house
	-- external multipliers (gamepasses, timed boosts, premium)
	rate *= Registry.MonetizationService:getEssenceMultiplier(player)
	return rate
end

-- shards / second
function EssenceService:getShardRate(player: Player): number
	local data = Registry.DataService:get(player)
	if not data then
		return 0
	end
	return GameConfig.SHARD_BASE_PER_SECOND
		* GameConfig.SHARD_ALTAR_GROWTH ^ (data.altar.level - 1)
		* self:_ascensionMult(data)
end

-- ── Generation ──────────────────────────────────────────────────────────────

--[[
	Grants essence (and optionally shards) for `elapsed` seconds at `efficiency`.

	`grantShards` is FALSE for the online tick: while you are playing, shards come
	from physically running over the drops your element nodes eject, which is the
	active gameplay. It is TRUE for the offline catch-up, so stepping away still
	pays — you just collect it as a lump on return instead of by hand.
]]
function EssenceService:_grant(player: Player, elapsed: number, efficiency: number, grantShards: boolean)
	if elapsed <= 0 then
		return { essence = 0, shards = 0 }
	end
	local essenceGain = self:getRate(player) * elapsed * efficiency
	Registry.CurrencyService:add(player, "essence", essenceGain)

	local data = Registry.DataService:get(player)
	if data then
		data.stats.totalEssenceCollected += essenceGain
		Registry.QuestService:track(player, "collect_essence", essenceGain)
	end

	local wholeShards = 0
	if grantShards then
		-- Tally into a per-element map, then apply as ONE batched push (a long
		-- offline grant could otherwise be thousands of individual pushes).
		local acc = (_shardAccum[player.UserId] or 0) + self:getShardRate(player) * elapsed * efficiency
		wholeShards = math.floor(acc)
		_shardAccum[player.UserId] = acc - wholeShards
		if wholeShards > 0 then
			local map: { [string]: number } = {}
			for _ = 1, wholeShards do
				local id = randomElement()
				map[id] = (map[id] or 0) + 1
			end
			Registry.CurrencyService:addShardsMap(player, map)
		end
	end

	return { essence = essenceGain, shards = wholeShards }
end

-- Brand-new players get a small starter kit so they can fuse within seconds of
-- joining (invisible onboarding — no waiting, no tutorial gate).
function EssenceService:_grantStarter(player: Player)
	Registry.CurrencyService:add(player, "essence", 150)
	local map: { [string]: number } = {}
	for _, element in ipairs(ElementConfig.List) do
		map[element.id] = 25 -- enough for a couple of 2-element fusions
	end
	Registry.CurrencyService:addShardsMap(player, map)
	ServerNet.fire(player, "Notify", {
		text = "Welcome, Alchemist! Pick 2 elements and press FUSE to discover your first beast.",
		kind = "info",
	})
end

function EssenceService:_applyOffline(player: Player, data)
	if data.lastSeen == 0 then
		self:_grantStarter(player) -- first-ever join
		return
	end
	local elapsed = os.time() - data.lastSeen
	if elapsed <= 5 then
		return
	end
	local cap = Registry.MonetizationService:getOfflineCap(player)
	elapsed = math.min(elapsed, cap)
	-- Offline pays shards too, since nobody was there to collect the node drops.
	local summary = self:_grant(player, elapsed, GameConfig.OFFLINE_EFFICIENCY, true)
	if summary.essence > 0 then
		ServerNet.fire(player, "Notify", {
			text = string.format(
				"Welcome back! Your Altar produced %s essence and %d shards while you were away.",
				self:_short(summary.essence),
				summary.shards
			),
			kind = "offline",
		})
	end
end

function EssenceService:_short(n: number): string
	local suffixes = { "", "K", "M", "B", "T" }
	local i = 1
	while n >= 1000 and i < #suffixes do
		n /= 1000
		i += 1
	end
	return string.format("%.1f%s", n, suffixes[i])
end

-- ── Actions ─────────────────────────────────────────────────────────────────

function EssenceService:upgradeAltar(player: Player)
	local data = Registry.DataService:get(player)
	if not data then
		return
	end
	if data.altar.level >= GameConfig.MAX_ALTAR_LEVEL then
		ServerNet.notify(player, "Altar is already max level!", "warn")
		return
	end
	local cost = math.floor(
		GameConfig.ALTAR_UPGRADE_BASE_COST * GameConfig.ALTAR_UPGRADE_COST_GROWTH ^ (data.altar.level - 1)
	)
	if not Registry.CurrencyService:trySpend(player, "essence", cost) then
		ServerNet.notify(player, "Not enough essence to upgrade the Altar.", "warn")
		return
	end
	data.altar.level += 1
	Registry.QuestService:track(player, "upgrade_altar", 1)
	Registry.StateSync:push(player, { altar = { level = data.altar.level }, ratePerSecond = self:getRate(player) })
	Registry.AnalyticsService:log(player, "altar_upgrade", { level = data.altar.level })
end

function EssenceService:ascend(player: Player)
	local data = Registry.DataService:get(player)
	if not data then
		return
	end
	local requirement = math.floor(
		GameConfig.ASCENSION_ALTAR_REQUIREMENT * GameConfig.ASCENSION_COST_GROWTH ^ data.ascension.count
	)
	if data.altar.level < requirement then
		ServerNet.notify(player, string.format("Reach Altar level %d to Ascend.", requirement), "warn")
		return
	end
	-- Reset the run, keep the collection + a permanent multiplier.
	data.ascension.count += 1
	data.altar.level = 1
	data.currencies.essence = 0
	for elementId in pairs(data.shards) do
		data.shards[elementId] = 0
	end
	_shardAccum[player.UserId] = 0

	Registry.QuestService:grantAchievement(player, "first_ascend")
	Registry.AnalyticsService:log(player, "ascend", { count = data.ascension.count })
	Registry.StateSync:push(player, self:_ascendSnapshot(player, data))
	ServerNet.notify(
		player,
		string.format("Ascended! Permanent essence bonus is now +%d%%.", data.ascension.count * 25),
		"success"
	)
end

function EssenceService:_ascendSnapshot(player, data)
	return {
		altar = { level = data.altar.level },
		currencies = data.currencies,
		shards = data.shards,
		ascension = { count = data.ascension.count, multiplier = self:_ascensionMult(data) },
		ratePerSecond = self:getRate(player),
	}
end

function EssenceService:collectTap(player: Player)
	-- Small active-play bonus; capped by the rate limiter on the "Collect" remote.
	local gain = self:getRate(player) * GameConfig.COLLECT_TAP_SECONDS
	Registry.CurrencyService:add(player, "essence", gain)
end

-- ── Lifecycle ───────────────────────────────────────────────────────────────

function EssenceService:Start()
	Registry.DataService.ProfileLoaded:connect(function(player, data)
		_shardAccum[player.UserId] = 0
		self:_applyOffline(player, data)
	end)

	Players.PlayerRemoving:Connect(function(player)
		_shardAccum[player.UserId] = nil
	end)

	-- Register action remotes.
	ServerNet.onEvent("UpgradeAltar", function(player)
		self:upgradeAltar(player)
	end)
	ServerNet.onEvent("Ascend", function(player)
		self:ascend(player)
	end)
	ServerNet.onEvent("Collect", function(player)
		self:collectTap(player)
	end)

	-- Global generation tick.
	task.spawn(function()
		while true do
			task.wait(GameConfig.GENERATION_TICK)
			for _, player in ipairs(Players:GetPlayers()) do
				if Registry.DataService:isLoaded(player) then
					-- Online: essence only. Shards are earned by running over the
					-- drops your element nodes eject (see NodeService).
					self:_grant(player, GameConfig.GENERATION_TICK, 1.0, false)
				end
			end
		end
	end)

	Logger:info("Generation loop started.")
end

return EssenceService
