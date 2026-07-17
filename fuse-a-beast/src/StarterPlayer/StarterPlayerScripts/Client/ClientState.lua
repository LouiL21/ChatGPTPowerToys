--!strict
--[[
	ClientState
	The client's local cache of the server's authoritative snapshot. The client
	renders from this and NEVER treats it as truth it can mutate — every gameplay
	action is a request to the server, and the resulting StateUpdate patch is what
	updates this store.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local ClientState = {
	data = {} :: { [string]: any },
	Changed = Signal.new(), -- fires (changedKeys: {string}, data)
	Ready = Signal.new(), -- fires once when the first snapshot arrives
}

local _ready = false

-- Merge a partial patch from the server into the local cache.
function ClientState.merge(partial: { [string]: any })
	if typeof(partial) ~= "table" then
		return
	end
	local changedKeys = {}
	for key, value in pairs(partial) do
		ClientState.data[key] = value
		table.insert(changedKeys, key)
	end
	ClientState.Changed:fire(changedKeys, ClientState.data)
	if not _ready then
		_ready = true
		ClientState.Ready:fire(ClientState.data)
	end
end

function ClientState.get(key: string): any
	return ClientState.data[key]
end

function ClientState.isReady(): boolean
	return _ready
end

return ClientState
