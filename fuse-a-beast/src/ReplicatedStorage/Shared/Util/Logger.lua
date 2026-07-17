--!strict
--[[ Logger — namespaced, level-gated logging so production noise is tunable. ]]

local Logger = {}
Logger.__index = Logger

local LEVELS = { debug = 1, info = 2, warn = 3, error = 4 }
Logger.minLevel = 2 -- change to 1 in Studio for verbose output

function Logger.new(scope: string)
	return setmetatable({ scope = scope }, Logger)
end

function Logger:_emit(level: string, ...: any)
	if LEVELS[level] < Logger.minLevel then
		return
	end
	local prefix = string.format("[FaB:%s]", self.scope)
	if level == "warn" then
		warn(prefix, ...)
	elseif level == "error" then
		warn(prefix, "ERROR:", ...)
	else
		print(prefix, ...)
	end
end

function Logger:debug(...: any) self:_emit("debug", ...) end
function Logger:info(...: any) self:_emit("info", ...) end
function Logger:warn(...: any) self:_emit("warn", ...) end
function Logger:error(...: any) self:_emit("error", ...) end

return Logger
