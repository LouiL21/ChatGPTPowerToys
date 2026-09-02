--!strict
--[[
	MockBackend
	In-memory persistence used when DataStores are unavailable (Studio without
	API access enabled, or local testing). Data does NOT survive a server restart
	— it exists only so the full game loop is playable offline.
]]

local MockBackend = {}
MockBackend.__index = MockBackend

function MockBackend.new()
	return setmetatable({ _store = {} :: { [string]: any } }, MockBackend)
end

function MockBackend:load(key: string)
	return self._store[key] -- may be nil for first-time players
end

function MockBackend:save(key: string, data: any)
	self._store[key] = data
end

function MockBackend:release(key: string, data: any)
	self._store[key] = data
end

function MockBackend:name(): string
	return "MockBackend (non-persistent)"
end

return MockBackend
