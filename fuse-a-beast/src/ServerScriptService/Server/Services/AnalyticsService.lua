--!strict
--[[
	AnalyticsService
	Thin, safe wrapper over Roblox's AnalyticsService. Every gameplay service logs
	through here so the funnel + economy events are consistent and centralised.
	Wrapped in pcall so analytics can never break gameplay.

	Key events (mirrored to the design's "analytics events" list):
	  session_start, first_fusion, beast_discovered, altar_upgrade, ascend,
	  purchase, quest_claim, daily_claim, achievement.
]]

local Players = game:GetService("Players")
local RobloxAnalytics = game:GetService("AnalyticsService")

local Logger = require(game:GetService("ReplicatedStorage").Shared.Util.Logger).new("Analytics")

local AnalyticsService = { Name = "AnalyticsService" }
local Registry: any

function AnalyticsService:Init(registry)
	Registry = registry
end

-- eventName, props: { [string]: any }
function AnalyticsService:log(player: Player, eventName: string, props: { [string]: any }?)
	-- Custom fields on Roblox analytics are limited to 3 string values; we pass a
	-- compact summary and rely on our own dashboards for the rest.
	local customFields = {}
	if props then
		local i = 0
		for key, value in pairs(props) do
			i += 1
			if i > 3 then
				break
			end
			customFields[tostring(key)] = tostring(value)
		end
	end
	pcall(function()
		RobloxAnalytics:LogCustomEvent(player, eventName, 1, customFields)
	end)
	Logger:debug(player.Name, eventName, props)
end

function AnalyticsService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:log(player, "session_start", { membership = tostring(player.MembershipType) })
	end)
end

return AnalyticsService
