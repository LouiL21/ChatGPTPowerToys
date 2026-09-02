--!strict
--[[
	EssenceController
	Smoothly animates the essence counter between server pushes for a satisfying
	always-ticking-up feel, without ever drifting from server truth: the display
	is always `serverEssence + rate * timeSincePush`, so every authoritative push
	reconciles it exactly.
]]

local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Format = require(ReplicatedStorage.Shared.Util.Format)

local ClientState = require(script.Parent.Parent.ClientState)
local UIController = require(script.Parent.UIController)

local EssenceController = {}

local serverEssence = 0
local rate = 0
local lastPush = os.clock()

function EssenceController.init()
	ClientState.Changed:connect(function()
		local data = ClientState.data
		if data.currencies and data.currencies.essence ~= nil then
			serverEssence = data.currencies.essence
			lastPush = os.clock()
		end
		if data.ratePerSecond ~= nil then
			rate = data.ratePerSecond
		end
	end)

	RunService.RenderStepped:Connect(function()
		local predicted = serverEssence + rate * (os.clock() - lastPush)
		UIController.setEssence(Format.abbreviate(predicted))
	end)
end

return EssenceController
