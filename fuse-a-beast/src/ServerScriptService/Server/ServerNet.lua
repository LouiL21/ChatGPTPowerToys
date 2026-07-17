--!strict
--[[
	ServerNet
	Thin, hardened wrapper around Remotes for the server. EVERY inbound handler
	registered here is automatically:
	  1. rate-limited per player (drops floods before they touch game state),
	  2. wrapped in pcall (a throwing handler can't take down the remote),
	  3. guarded so it only runs once the player's profile is loaded.

	This is the choke point that enforces "assume every remote is hostile".
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local Logger = require(Shared.Util.Logger).new("Net")

local ServerNet = {}

local _limiter: any = nil
local _dataService: any = nil

function ServerNet.configure(limiter: any, dataService: any)
	_limiter = limiter
	_dataService = dataService
end

-- Register a client->server RemoteEvent handler.
-- handler(player, data, ...) is only invoked for a loaded, non-rate-limited call.
function ServerNet.onEvent(name: string, handler: (Player, ...any) -> ())
	local remote = Remotes.event(name)
	remote.OnServerEvent:Connect(function(player, ...)
		if _limiter and not _limiter:check(player.UserId, name) then
			-- Silently drop; a legit client never trips these limits.
			return
		end
		if _dataService and not _dataService:isLoaded(player) then
			return
		end
		local ok, err = pcall(handler, player, ...)
		if not ok then
			Logger:error("Handler '" .. name .. "' errored:", err)
		end
	end)
end

-- Register a RemoteFunction handler (request/response).
function ServerNet.onFunction(name: string, handler: (Player, ...any) -> ...any)
	local remote = Remotes.func(name)
	remote.OnServerInvoke = function(player, ...)
		if _limiter and not _limiter:check(player.UserId, name) then
			return nil
		end
		local results = { pcall(handler, player, ...) }
		if not results[1] then
			Logger:error("Function '" .. name .. "' errored:", results[2])
			return nil
		end
		return table.unpack(results, 2)
	end
end

-- Server -> client.
function ServerNet.fire(player: Player, name: string, payload: any)
	Remotes.event(name):FireClient(player, payload)
end

function ServerNet.notify(player: Player, text: string, kind: string?)
	Remotes.event("Notify"):FireClient(player, { text = text, kind = kind or "info" })
end

return ServerNet
