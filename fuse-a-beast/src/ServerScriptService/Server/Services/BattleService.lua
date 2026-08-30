--!strict
--[[
	BattleService
	Arena combat. Your active pet fights either a boss (PvE, always available so
	solo players are never blocked) or another player who accepts a duel.

	Design guardrails:
	  - Power comes ONLY from rarity × variant, i.e. from collecting and fusing.
	    Nothing in the shop raises it, so the Arena stays a test of your roster.
	  - Battles auto-resolve on a timer with crits, element advantage and damage
	    variance, so a slightly weaker beast can still pull off an upset.
	  - Losing still pays a little. Dead-end losses are why players quit
	    competitive modes.
	  - Beasts are never lost. Plots and rosters stay safe (the social model we
	    chose); the Arena stakes rewards, not property.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local CombatConfig = require(Shared.Config.CombatConfig)
local BeastConfig = require(Shared.Config.BeastConfig)
local VariantConfig = require(Shared.Config.VariantConfig)
local PlotConfig = require(Shared.Config.PlotConfig)
local BeastInventory = require(Shared.Util.BeastInventory)

local ServerNet = require(script.Parent.Parent.ServerNet)

local BattleService = { Name = "BattleService" }
local Registry: any

local _busy: { [number]: boolean } = {}
local _lastBoss: { [number]: number } = {}
local _lastDuel: { [number]: number } = {}
local _pendingChallenge: { [number]: { from: number, expires: number } } = {}

function BattleService:Init(registry)
	Registry = registry
end

-- ── Fighter construction ──────────────────────────────────────────────────

function BattleService:_fighterFor(player: Player)
	local data = Registry.DataService:get(player)
	if not data or data.activePet.beastId == "" then
		return nil
	end
	local beastId, variant = data.activePet.beastId, data.activePet.variant
	if not BeastInventory.owns(data.codex, beastId, variant) then
		return nil
	end
	local beast = BeastConfig.ById[beastId]
	local stats = BeastInventory.stats(beastId, variant)
	return {
		name = VariantConfig.label(variant, beast.name),
		power = stats.power,
		health = stats.health,
		maxHealth = stats.health,
		element = beast.elements[1],
		rarity = beast.rarity,
		userId = player.UserId,
	}
end

local function bossFighter(boss)
	return {
		name = boss.name,
		power = boss.power,
		health = boss.health,
		maxHealth = boss.health,
		element = boss.element,
		rarity = "Boss",
		userId = 0,
	}
end

-- ── Resolution ────────────────────────────────────────────────────────────

local function damageOf(attacker, defender): (number, boolean, boolean)
	local variance = 1 + (math.random() * 2 - 1) * CombatConfig.DAMAGE_VARIANCE
	local damage = attacker.power * variance

	local advantaged = CombatConfig.Advantage[attacker.element] == defender.element
		and attacker.element ~= "Void"
	if advantaged then
		damage *= CombatConfig.ADVANTAGE_BONUS
	end

	local crit = math.random() < CombatConfig.CRIT_CHANCE
	if crit then
		damage *= CombatConfig.CRIT_MULTIPLIER
	end

	return math.max(1, math.floor(damage)), crit, advantaged
end

-- Runs the exchange, streaming each turn to the involved players so the client
-- can animate it. Returns the winning fighter.
function BattleService:_resolve(a, b, audience: { Player })
	local function broadcast(payload)
		for _, player in ipairs(audience) do
			ServerNet.fire(player, "BattleEvent", payload)
		end
	end

	broadcast({
		phase = "start",
		a = { name = a.name, health = a.health, maxHealth = a.maxHealth, rarity = a.rarity },
		b = { name = b.name, health = b.health, maxHealth = b.maxHealth, rarity = b.rarity },
	})

	local attacker, defender = a, b
	for turn = 1, CombatConfig.MAX_TURNS do
		task.wait(CombatConfig.TURN_INTERVAL)

		local damage, crit, advantaged = damageOf(attacker, defender)
		defender.health = math.max(0, defender.health - damage)

		broadcast({
			phase = "hit",
			turn = turn,
			attacker = attacker.name,
			damage = damage,
			crit = crit,
			advantage = advantaged,
			aHealth = a.health,
			bHealth = b.health,
		})

		if defender.health <= 0 then
			broadcast({ phase = "end", winner = attacker.name })
			return attacker
		end
		attacker, defender = defender, attacker
	end

	-- Turn limit: the healthier fighter takes it.
	local winner = (a.health / a.maxHealth >= b.health / b.maxHealth) and a or b
	broadcast({ phase = "end", winner = winner.name, byTimeout = true })
	return winner
end

-- Stages both fighters on the Arena floor for the duration.
function BattleService:_stage(player: Player, side: number)
	local centre = Vector3.new(0, PlotConfig.GROUND_Y + 4, 0)
	local spot = centre + Vector3.new(side * 9, 1, 0)
	Registry.PetService:setBusy(player, true)
	Registry.PetService:placeAt(player, CFrame.lookAt(spot, centre))
end

function BattleService:_unstage(player: Player)
	Registry.PetService:setBusy(player, false)
end

-- ── Boss battles (PvE) ────────────────────────────────────────────────────

function BattleService:fightBoss(player: Player, payload)
	local data = Registry.DataService:get(player)
	if not data or typeof(payload) ~= "table" or typeof(payload.bossId) ~= "string" then
		return
	end
	if _busy[player.UserId] then
		return
	end

	local now = os.clock()
	if _lastBoss[player.UserId] and now - _lastBoss[player.UserId] < CombatConfig.BOSS_COOLDOWN then
		local wait = math.ceil(CombatConfig.BOSS_COOLDOWN - (now - _lastBoss[player.UserId]))
		ServerNet.notify(player, string.format("The Arena is resetting — %ds.", wait), "warn")
		return
	end

	local boss
	for _, entry in ipairs(CombatConfig.Bosses) do
		if entry.id == payload.bossId then
			boss = entry
			break
		end
	end
	if not boss then
		return
	end

	local fighter = self:_fighterFor(player)
	if not fighter then
		ServerNet.notify(player, "Summon a beast first — you need a pet to fight!", "warn")
		return
	end

	_busy[player.UserId] = true
	_lastBoss[player.UserId] = now
	self:_stage(player, -1)

	task.spawn(function()
		local winner = self:_resolve(fighter, bossFighter(boss), { player })
		local won = winner.userId == player.UserId

		if won then
			local firstClear = not data.battle.bossesCleared[boss.id]
			data.battle.bossesCleared[boss.id] = true
			data.battle.wins += 1
			-- First clear pays full; repeats pay a quarter, so farming still works
			-- but progression comes from moving up the ladder.
			local scale = firstClear and 1 or 0.25
			Registry.CurrencyService:add(player, "gems", math.floor(boss.reward.gems * scale))
			Registry.CurrencyService:add(player, "essence", math.floor(boss.reward.essence * scale))
			Registry.QuestService:track(player, "win_battle", 1)
			Registry.QuestService:grantAchievement(player, "first_win")

			-- Clearing the whole ladder is the PvE capstone.
			local allCleared = true
			for _, entry in ipairs(CombatConfig.Bosses) do
				if not data.battle.bossesCleared[entry.id] then
					allCleared = false
					break
				end
			end
			if allCleared then
				Registry.QuestService:grantAchievement(player, "boss_slayer")
			end

			ServerNet.notify(player, string.format("You beat %s!", boss.name), "success")
		else
			data.battle.losses += 1
			ServerNet.notify(player, string.format("%s was too strong. Fuse up and try again.", boss.name), "warn")
		end

		Registry.AnalyticsService:log(player, "boss_battle", { boss = boss.id, won = won })
		Registry.StateSync:push(player, { battle = data.battle })
		self:_unstage(player)
		Registry.PetService:refresh(player)
		_busy[player.UserId] = false
	end)
end

-- ── Duels (PvP, consensual) ───────────────────────────────────────────────

function BattleService:challenge(player: Player, payload)
	if typeof(payload) ~= "table" or typeof(payload.targetUserId) ~= "number" then
		return
	end
	local target = Players:GetPlayerByUserId(payload.targetUserId)
	if not target or target == player then
		return
	end
	if _busy[player.UserId] or _busy[target.UserId] then
		ServerNet.notify(player, "One of you is already battling.", "warn")
		return
	end

	local now = os.clock()
	if _lastDuel[player.UserId] and now - _lastDuel[player.UserId] < CombatConfig.PVP_COOLDOWN then
		return
	end
	if not self:_fighterFor(player) then
		ServerNet.notify(player, "You need an active pet to duel.", "warn")
		return
	end

	_pendingChallenge[target.UserId] = { from = player.UserId, expires = os.time() + 30 }
	ServerNet.fire(target, "DuelChallenge", { fromUserId = player.UserId, fromName = player.DisplayName })
	ServerNet.notify(player, "Challenge sent to " .. target.DisplayName .. ".", "info")
end

function BattleService:respond(player: Player, payload)
	if typeof(payload) ~= "table" then
		return
	end
	local pending = _pendingChallenge[player.UserId]
	if not pending or os.time() > pending.expires then
		_pendingChallenge[player.UserId] = nil
		return
	end
	_pendingChallenge[player.UserId] = nil

	local challenger = Players:GetPlayerByUserId(pending.from)
	if not challenger then
		return
	end
	if payload.accept ~= true then
		ServerNet.notify(challenger, player.DisplayName .. " declined.", "info")
		return
	end

	local a = self:_fighterFor(challenger)
	local b = self:_fighterFor(player)
	if not a or not b then
		return
	end
	if _busy[challenger.UserId] or _busy[player.UserId] then
		return
	end

	_busy[challenger.UserId] = true
	_busy[player.UserId] = true
	_lastDuel[challenger.UserId] = os.clock()
	_lastDuel[player.UserId] = os.clock()
	self:_stage(challenger, -1)
	self:_stage(player, 1)

	task.spawn(function()
		local winner = self:_resolve(a, b, { challenger, player })

		for _, participant in ipairs({ challenger, player }) do
			local data = Registry.DataService:get(participant)
			if data then
				local won = winner.userId == participant.UserId
				if won then
					data.battle.wins += 1
					Registry.CurrencyService:add(participant, "gems", CombatConfig.PVP_WIN_REWARD.gems)
					Registry.QuestService:track(participant, "win_battle", 1)
					Registry.QuestService:grantAchievement(participant, "first_win")
				else
					data.battle.losses += 1
					-- Consolation: never leave a duel with nothing.
					Registry.CurrencyService:add(participant, "gems", CombatConfig.PVP_LOSS_REWARD.gems)
				end
				Registry.StateSync:push(participant, { battle = data.battle })
			end
			self:_unstage(participant)
			Registry.PetService:refresh(participant)
			_busy[participant.UserId] = false
		end

		Registry.AnalyticsService:log(challenger, "duel", { won = winner.userId == challenger.UserId })
	end)
end

function BattleService:Start()
	ServerNet.onEvent("FightBoss", function(player, payload)
		self:fightBoss(player, payload)
	end)
	ServerNet.onEvent("ChallengePlayer", function(player, payload)
		self:challenge(player, payload)
	end)
	ServerNet.onEvent("RespondDuel", function(player, payload)
		self:respond(player, payload)
	end)

	Players.PlayerRemoving:Connect(function(player)
		_busy[player.UserId] = nil
		_lastBoss[player.UserId] = nil
		_lastDuel[player.UserId] = nil
		_pendingChallenge[player.UserId] = nil
	end)
end

return BattleService
