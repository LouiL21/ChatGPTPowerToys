--!strict
--[[
	Server bootstrap
	Loads every service, injects a shared registry so services can reference one
	another without circular requires, then runs a two-phase lifecycle:

	  Init  — wire dependencies, choose the data backend. No remotes yet.
	  Start — connect remotes, start loops, begin loading players.

	DataService:Start runs LAST so every ProfileLoaded listener (Essence, Quests,
	Monetization, StateSync, ...) is connected before the first profile loads.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local RateLimiter = require(Shared.Util.RateLimiter)
local Logger = require(Shared.Util.Logger).new("Boot")

local ServerNet = require(script.ServerNet)
local DataService = require(script.Data.DataService)

local Services = script.Services
local StateSync = require(Services.StateSync)
local AnalyticsService = require(Services.AnalyticsService)
local MonetizationService = require(Services.MonetizationService)
local CurrencyService = require(Services.CurrencyService)
local EssenceService = require(Services.EssenceService)
local CollectionService = require(Services.CollectionService)
local QuestService = require(Services.QuestService)
local DailyRewardService = require(Services.DailyRewardService)
local FusionService = require(Services.FusionService)
-- World services: the physical sanctuary layer.
local PlotService = require(Services.PlotService)
local PickupService = require(Services.PickupService)
local NodeService = require(Services.NodeService)
local BeastService = require(Services.BeastService)
local TycoonService = require(Services.TycoonService)

-- Registry: every service is reachable as Registry.<Name>.
local Registry = {}
local allServices = {
	DataService,
	AnalyticsService,
	MonetizationService,
	CurrencyService,
	StateSync,
	EssenceService,
	CollectionService,
	QuestService,
	DailyRewardService,
	FusionService,
	-- PlotService starts before the services that decorate a plot, so the island
	-- and every sanctuary exist before anything tries to spawn into one.
	PlotService,
	PickupService,
	NodeService,
	BeastService,
	TycoonService,
}
for _, service in ipairs(allServices) do
	Registry[service.Name] = service
end

Logger:info("Initialising", #allServices, "services...")

-- Phase 1: Init (no remotes bound yet).
for _, service in ipairs(allServices) do
	if service.Init then
		service:Init(Registry)
	end
end

-- Configure the network choke point now that DataService exists.
local limiter = RateLimiter.new(GameConfig.REMOTE_RATE_LIMITS)
ServerNet.configure(limiter, DataService)

-- Phase 2: Start everything EXCEPT DataService first, so all ProfileLoaded
-- listeners are connected before profiles begin loading.
for _, service in ipairs(allServices) do
	if service ~= DataService and service.Start then
		service:Start()
	end
end

-- Clean up the per-player rate-limit buckets on leave.
game:GetService("Players").PlayerRemoving:Connect(function(player)
	limiter:clearPlayer(player.UserId)
end)

-- Finally, begin loading players.
DataService:Start()

Logger:info("Fuse a Beast server is live.")
