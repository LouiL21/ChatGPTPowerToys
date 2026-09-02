--!strict
--[[
	DailyRewardService
	Escalating 7-day login streak. Returning on consecutive days grows the streak
	(and the reward); a missed day resets it. This is one of the cheapest, highest-
	leverage retention systems on Roblox, so the reward curve deliberately spikes
	on Day 7 to make the streak feel worth protecting.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local QuestConfig = require(Shared.Config.QuestConfig)

local ServerNet = require(script.Parent.Parent.ServerNet)

local DailyRewardService = { Name = "DailyRewardService" }
local Registry: any

function DailyRewardService:Init(registry)
	Registry = registry
end

local function dayString(offsetDays: number): string
	return os.date("!%Y-%m-%d", os.time() + offsetDays * 86400)
end

function DailyRewardService:isClaimable(data): boolean
	return data.login.lastClaimDate ~= dayString(0)
end

function DailyRewardService:claim(player: Player)
	local data = Registry.DataService:get(player)
	if not data then
		return
	end
	local todayStr = dayString(0)
	if data.login.lastClaimDate == todayStr then
		ServerNet.notify(player, "You already claimed today's reward.", "warn")
		return
	end

	-- Continue or reset the streak.
	if data.login.lastClaimDate == dayString(-1) then
		data.login.streak += 1
	else
		data.login.streak = 1
	end
	data.login.lastClaimDate = todayStr

	local index = ((data.login.streak - 1) % #QuestConfig.LoginStreak) + 1
	local reward = QuestConfig.LoginStreak[index].reward

	if reward.gems then
		Registry.CurrencyService:add(player, "gems", reward.gems)
	end
	if reward.essence then
		Registry.CurrencyService:add(player, "essence", reward.essence)
	end
	if reward.boost then
		Registry.MonetizationService:applyBoost(player, reward.boost)
	end

	ServerNet.notify(player, string.format("Day %d reward claimed! Streak: %d", index, data.login.streak), "success")
	Registry.StateSync:pushQuests(player)
	Registry.AnalyticsService:log(player, "daily_claim", { streak = data.login.streak, day = index })
end

function DailyRewardService:Start()
	ServerNet.onEvent("ClaimDaily", function(player)
		self:claim(player)
	end)
end

return DailyRewardService
