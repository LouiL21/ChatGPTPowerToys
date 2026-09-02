--!strict
--[[
	Signal
	Minimal, dependency-free signal (observer) implementation used for
	server-side service-to-service events. Not a replacement for RBXScriptSignal;
	just enough for decoupled internal eventing.
]]

local Signal = {}
Signal.__index = Signal

export type Connection = { disconnect: (Connection) -> () }

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:connect(fn: (...any) -> ()): Connection
	local handlers = self._handlers
	local connection = {}
	function connection.disconnect()
		handlers[connection] = nil
	end
	handlers[connection] = fn
	return connection
end

function Signal:fire(...: any)
	-- Snapshot so handlers may disconnect during dispatch without skipping others.
	for connection, fn in pairs(self._handlers) do
		if self._handlers[connection] then
			task.spawn(fn, ...)
		end
	end
end

function Signal:destroy()
	table.clear(self._handlers)
end

return Signal
