--!strict
--[[
	QuestService
	Daily quests + one-time achievements/badges. Daily quests are the "unfinished
	business" that drives Day-2 return; each day the player gets 3 quests picked
	deterministically from the pool (stable across rejoins that day).

	Progress is server-authoritative and event-driven: gameplay services call
	:track(player, event, amount) and QuestService advances any active quest whose
	trigger matches.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BadgeService = game:GetService("BadgeService")

local Shared = ReplicatedStorage.Shared
local QuestConfig = require(Shared.Config.QuestConfig)
local GameConfig = require(Shared.Config.GameConfig)
local Logger = require(Shared.Util.Logger).new("Quest")

local ServerNet = require(script.Parent.Parent.ServerNet)

local QuestService = { Name = "QuestService" }
local Registry: any

local RARITY_INDEX = {}
for i, rarity in ipairs(GameConfig.RARITY_ORDER) do
	RARITY_INDEX[rarity] = i
end

local ACHIEVEMENT_BY_ID = {}
for _, achievement in ipairs(QuestConfig.Achievements) do
	ACHIEVEMENT_BY_ID[achievement.id] = achievement
end

function QuestService:Init(registry)
	Registry = registry
end

local function today(): string
	return os.date("!%Y-%m-%d")
end

-- Deterministic daily quest set per (date, player).
local function pickDaily(dateStr: string, userId: number): { string }
	local seed = userId
	for i = 1, #dateStr do
		seed += string.byte(dateStr, i) * i
	end
	local rng = Random.new(seed)
	local pool = table.clone(QuestConfig.DailyPool)
	-- Fisher-Yates using the seeded rng.
	for i = #pool, 2, -1 do
		local j = rng:NextInteger(1, i)
		pool[i], pool[j] = pool[j], pool[i]
	end
	local chosen = {}
	for i = 1, math.min(3, #pool) do
		chosen[i] = pool[i].id
	end
	return chosen
end

local function questDef(id: string)
	for _, quest in ipairs(QuestConfig.DailyPool) do
		if quest.id == id then
			return quest
		end
	end
	return nil
end

-- Regenerate the daily set if the calendar day rolled over.
function QuestService:ensureDaily(player: Player)
	local data = Registry.DataService:get(player)
	if not data then
		return
	end
	local now = today()
	if data.quests.date ~= now then
		data.quests.date = now
		data.quests.active = pickDaily(now, player.UserId)
		data.quests.progress = {}
		data.quests.claimed = {}
		Registry.StateSync:pushQuests(player)
	end
end

function QuestService:track(player: Player, event: string, amount: number)
	local data = Registry.DataService:get(player)
	if not data then
		return
	end
	local changed = false
	for _, questId in ipairs(data.quests.active) do
		local def = questDef(questId)
		if def and def.event == event and not data.quests.claimed[questId] then
			local current = data.quests.progress[questId] or 0
			if current < def.target then
				data.quests.progress[questId] = math.min(def.target, current + amount)
				changed = true
			end
		end
	end
	if changed then
		Registry.StateSync:pushQuests(player)
	end
end

function QuestService:claim(player: Player, payload)
	local data = Registry.DataService:get(player)
	if not data or typeof(payload) ~= "table" or typeof(payload.questId) ~= "string" then
		return
	end
	local questId = payload.questId
	local def = questDef(questId)
	if not def then
		return
	end
	local isActive = table.find(data.quests.active, questId) ~= nil
	local complete = (data.quests.progress[questId] or 0) >= def.target
	if not isActive or not complete or data.quests.claimed[questId] then
		return
	end
	data.quests.claimed[questId] = true
	self:_grantReward(player, def.reward)
	ServerNet.notify(player, "Quest complete!", "success")
	Registry.StateSync:pushQuests(player)
	Registry.AnalyticsService:log(player, "quest_claim", { id = questId })
end

function QuestService:_grantReward(player: Player, reward)
	if reward.gems then
		Registry.CurrencyService:add(player, "gems", reward.gems)
	end
	if reward.essence then
		Registry.CurrencyService:add(player, "essence", reward.essence)
	end
	if reward.boost then
		Registry.MonetizationService:applyBoost(player, reward.boost)
	end
end

-- Called by FusionService on every NEW discovery.
function QuestService:onDiscovery(player: Player, rarity: string)
	local data = Registry.DataService:get(player)
	if not data then
		return
	end
	if (RARITY_INDEX[rarity] or 0) >= RARITY_INDEX.Rare then
		self:track(player, "discover_rare_plus", 1)
	end
	if rarity == "Legendary" then
		self:grantAchievement(player, "first_legendary")
	elseif rarity == "Mythic" then
		self:grantAchievement(player, "first_mythic")
	elseif rarity == "Secret" then
		self:grantAchievement(player, "first_secret")
	end
	Registry.CollectionService:checkDexMilestones(player, data)
end

function QuestService:grantAchievement(player: Player, id: string)
	local data = Registry.DataService:get(player)
	if not data or data.achievements[id] then
		return
	end
	data.achievements[id] = true
	local def = ACHIEVEMENT_BY_ID[id]
	if def and def.badgeId and def.badgeId ~= 0 then
		task.spawn(function()
			pcall(function()
				BadgeService:AwardBadge(player.UserId, def.badgeId)
			end)
		end)
	end
	ServerNet.fire(player, "Notify", { text = "Achievement: " .. (def and def.desc or id), kind = "achievement" })
	Registry.StateSync:push(player, { achievements = data.achievements })
	Registry.AnalyticsService:log(player, "achievement", { id = id })
end

function QuestService:Start()
	Registry.DataService.ProfileLoaded:connect(function(player)
		self:ensureDaily(player)
	end)
	ServerNet.onEvent("ClaimQuest", function(player, payload)
		self:claim(player, payload)
	end)
	Logger:info("Quest service ready.")
end

return QuestService
