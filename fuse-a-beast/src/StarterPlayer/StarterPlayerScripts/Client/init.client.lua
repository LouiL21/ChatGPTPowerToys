--!strict
--[[
	Client bootstrap
	Builds the interface, connects the server→client streams, and pulls the
	initial authoritative snapshot.

	Onboarding is the gameplay: you land on your sanctuary with shards already
	dropping, and the Altar is a few steps away. No tutorial gate.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)

local ClientState = require(script.ClientState)
local UIController = require(script.Controllers.UIController)
local EssenceController = require(script.Controllers.EssenceController)
local NotificationController = require(script.Controllers.NotificationController)
local FusionController = require(script.Controllers.FusionController)
local BattleController = require(script.Controllers.BattleController)

UIController.build()
NotificationController.init()
FusionController.init()
BattleController.init()
EssenceController.init()

ClientState.Changed:connect(function()
	UIController.refresh()
end)

-- Server → client streams.
Remotes.event("StateUpdate").OnClientEvent:Connect(function(partial)
	ClientState.merge(partial)
end)
Remotes.event("Notify").OnClientEvent:Connect(function(payload)
	NotificationController.show(payload)
end)
Remotes.event("FusionResult").OnClientEvent:Connect(function(result)
	FusionController.show(result)
end)
Remotes.event("BattleEvent").OnClientEvent:Connect(function(payload)
	BattleController.handle(payload)
end)
Remotes.event("DuelChallenge").OnClientEvent:Connect(function(payload)
	BattleController.showChallenge(payload, function(accept)
		Remotes.event("RespondDuel"):FireServer({ accept = accept })
	end)
end)

-- Walking up to a building is what opens its panel.
Remotes.event("OpenFusion").OnClientEvent:Connect(function()
	UIController.openFusion()
end)
Remotes.event("OpenChamber").OnClientEvent:Connect(function()
	UIController.openChamber()
end)

-- Initial full-state pull, retried until the profile is loaded server-side.
task.spawn(function()
	local getState = Remotes.func("GetState")
	for _ = 1, 20 do
		local ok, snapshot = pcall(function()
			return getState:InvokeServer()
		end)
		if ok and snapshot then
			ClientState.merge(snapshot)
			return
		end
		task.wait(0.5)
	end
	warn("[FaB] Failed to fetch initial state after retries.")
end)
