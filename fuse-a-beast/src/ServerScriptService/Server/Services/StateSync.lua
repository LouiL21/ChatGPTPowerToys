--!strict
--[[
	StateSync
	Builds the client-facing snapshot of a player's authoritative state and
	replicates it. Clients render from these snapshots only — they never compute
	currency or ownership themselves.

	- buildFull: complete snapshot (sent on join / GetState).
	- push: send a partial patch the client merges into its local cache.
	Convenience wrappers keep call sites terse.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local BeastConfig = require(Shared.Config.BeastConfig)

local Remotes = require(Shared.Net.Remotes)
local ServerNet = require(script.Parent.Parent.ServerNet)

local StateSync = { Name = "StateSync" }
local Registry: any

function StateSync:Init(registry)
	Registry = registry
end

function StateSync:Start()
	-- Initial full-state pull requested by the client once remotes are ready.
	Remotes.func("GetState").OnServerInvoke = function(player)
		if not Registry.DataService:isLoaded(player) then
			return nil
		end
		return self:buildFull(player)
	end

	-- Also push a full snapshot proactively when the profile finishes loading, so
	-- late-joining UI still converges even if GetState raced the load.
	Registry.DataService.ProfileLoaded:connect(function(player)
		task.defer(function()
			local snapshot = self:buildFull(player)
			if snapshot then
				self:push(player, snapshot)
			end
		end)
	end)

	-- The player closed the How to Play card. This is a one-way latch: it can be
	-- set but never cleared from the client, so a hostile client can at worst
	-- skip its own tutorial.
	ServerNet.onEvent("TutorialSeen", function(player)
		local data = Registry.DataService:get(player)
		if data and not data.tutorialSeen then
			data.tutorialSeen = true
			self:push(player, { tutorialSeen = true })
		end
	end)
end

-- Full authoritative snapshot for the client UI.
function StateSync:buildFull(player: Player)
	local data = Registry.DataService:get(player)
	if not data then
		return nil
	end
	return {
		currencies = data.currencies,
		shards = data.shards,
		altar = { level = data.altar.level },
		ascension = {
			count = data.ascension.count,
			multiplier = 1 + data.ascension.count * require(Shared.Config.GameConfig).ASCENSION_MULT_PER_LEVEL,
		},
		codex = data.codex,
		codexTotal = BeastConfig.count(),
		display = data.display,
		activePet = data.activePet,
		battle = data.battle,
		plot = data.plot,
		habitatSlots = Registry.PlotService:habitatSlots(player),
		quests = data.quests,
		login = data.login,
		achievements = data.achievements,
		gamepasses = data.gamepasses,
		stats = data.stats,
		ratePerSecond = Registry.EssenceService:getRate(player),
		boosts = Registry.MonetizationService:getActiveBoosts(player),
		tutorialSeen = data.tutorialSeen == true,
	}
end

-- Send a partial patch (any subset of the full snapshot's top-level fields).
function StateSync:push(player: Player, partial: { [string]: any })
	ServerNet.fire(player, "StateUpdate", partial)
end

-- Common convenience pushes ─────────────────────────────────────────────────
function StateSync:pushCurrencies(player: Player)
	local data = Registry.DataService:get(player)
	if data then
		self:push(player, { currencies = data.currencies, shards = data.shards })
	end
end

function StateSync:pushRate(player: Player)
	self:push(player, { ratePerSecond = Registry.EssenceService:getRate(player) })
end

function StateSync:pushCodex(player: Player)
	local data = Registry.DataService:get(player)
	if data then
		self:push(player, {
			codex = data.codex,
			display = data.display,
			activePet = data.activePet,
			stats = data.stats,
			currencies = data.currencies,
			ratePerSecond = Registry.EssenceService:getRate(player),
		})
	end
end

function StateSync:pushQuests(player: Player)
	local data = Registry.DataService:get(player)
	if data then
		self:push(player, { quests = data.quests, login = data.login })
	end
end

return StateSync
