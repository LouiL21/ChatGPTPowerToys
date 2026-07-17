--!strict
--[[
	Client bootstrap
	Wires the client: builds UI, connects the server->client remotes, and pulls
	the initial authoritative snapshot. The player can fuse within seconds of
	joining — onboarding is the gameplay itself.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)

local ClientState = require(script.ClientState)
local UIController = require(script.Controllers.UIController)
local EssenceController = require(script.Controllers.EssenceController)
local NotificationController = require(script.Controllers.NotificationController)
local FusionController = require(script.Controllers.FusionController)

-- Build interface first so state pushes have somewhere to render.
UIController.build()
NotificationController.init()
FusionController.init()
EssenceController.init()

-- Re-render whenever the local cache changes.
ClientState.Changed:connect(function(keys)
	UIController.refresh(keys)
end)

-- Server -> client streams.
Remotes.event("StateUpdate").OnClientEvent:Connect(function(partial)
	ClientState.merge(partial)
end)
Remotes.event("Notify").OnClientEvent:Connect(function(payload)
	NotificationController.show(payload)
end)
Remotes.event("FusionResult").OnClientEvent:Connect(function(result)
	FusionController.show(result)
end)

-- Initial full-state pull (retry until the profile is loaded server-side).
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
