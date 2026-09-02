--!strict
--[[
	Client bootstrap
	Builds the interface, connects the server→client streams, and pulls the
	initial authoritative snapshot.

	Onboarding is the gameplay: you land on your sanctuary with shards already
	dropping, and the Altar is a few steps away. The one exception is a single
	How to Play card on a player's very first join — the Fusion Chamber is a pad
	on the floor that nobody would guess combines two beasts, and losing that
	mechanic loses the game. It closes on one tap and never returns.
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
local HowToController = require(script.Controllers.HowToController)

UIController.build()
NotificationController.init()
FusionController.init()
BattleController.init()
HowToController.init()
EssenceController.init()

UIController.setHelpAction(function()
	HowToController.open()
end)

ClientState.Changed:connect(function()
	UIController.refresh()
	-- Opens once, the first time we learn this player has never seen it.
	HowToController.consider(ClientState.data, function()
		Remotes.event("TutorialSeen"):FireServer()
	end)
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
-- The Barn is where your beasts live, so walking up to it opens the roster.
Remotes.event("OpenBarn").OnClientEvent:Connect(function()
	UIController.open("Pets")
end)
-- Your own house opens your sanctuary's books: rate, upgrades, capacity.
Remotes.event("OpenHouse").OnClientEvent:Connect(function()
	UIController.open("Sanctuary")
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
