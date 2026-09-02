--!strict
--[[
	DataStoreBackend
	Session-locked DataStore persistence. This is a compact, self-contained
	implementation of the same core idea ProfileStore/ProfileService use: a lock
	record stored alongside the data so two servers can never edit one profile at
	once (the root cause of duplication exploits).

	For a large production launch, prefer the battle-tested ProfileStore (see
	wally.toml + docs/INSTALLATION.md) and point DataService at it. This backend
	keeps the project fully runnable without external packages.
]]

local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local DataStoreBackend = {}
DataStoreBackend.__index = DataStoreBackend

local STALE_LOCK_SECONDS = 60 * 5 -- steal a lock older than this (dead server)
local MAX_LOAD_ATTEMPTS = 6
local RETRY_WAIT = 4

function DataStoreBackend.new(storeName: string)
	return setmetatable({
		_store = DataStoreService:GetDataStore(storeName),
		_jobId = game.JobId ~= "" and game.JobId or ("studio-" .. tostring(os.clock())),
	}, DataStoreBackend)
end

local function now(): number
	return os.time()
end

-- Attempt to acquire the lock and return the stored data (or nil for new player).
function DataStoreBackend:load(key: string)
	local jobId = self._jobId
	for attempt = 1, MAX_LOAD_ATTEMPTS do
		local acquired = false
		local result
		local ok, err = pcall(function()
			result = self._store:UpdateAsync(key, function(record)
				record = record or { data = nil, lock = nil }
				local lock = record.lock
				if lock and lock.jobId ~= jobId and (now() - lock.time) < STALE_LOCK_SECONDS then
					-- Locked by another live server. Abort this write (returns nil).
					return nil
				end
				record.lock = { jobId = jobId, time = now() }
				acquired = true
				return record
			end)
		end)

		if ok and acquired and result then
			return result.data
		end

		if not ok then
			warn("[FaB:Data] UpdateAsync failed for", key, err)
		end
		-- Locked or transient failure — wait and retry.
		task.wait(RETRY_WAIT)
	end
	error("[FaB:Data] Could not acquire session lock for key " .. key)
end

-- Periodic save that also refreshes our lock timestamp so it never goes stale
-- mid-session.
function DataStoreBackend:save(key: string, data: any)
	local jobId = self._jobId
	local ok, err = pcall(function()
		self._store:UpdateAsync(key, function(record)
			record = record or { data = nil, lock = nil }
			-- Only write if we still own the lock (defensive against a steal).
			if record.lock and record.lock.jobId ~= jobId then
				return nil
			end
			record.data = data
			record.lock = { jobId = jobId, time = now() }
			return record
		end)
	end)
	if not ok then
		warn("[FaB:Data] save failed for", key, err)
	end
end

-- Final save + lock release when the player leaves / server shuts down.
function DataStoreBackend:release(key: string, data: any)
	local jobId = self._jobId
	local ok, err = pcall(function()
		self._store:UpdateAsync(key, function(record)
			record = record or { data = nil, lock = nil }
			if record.lock and record.lock.jobId ~= jobId then
				return nil -- we lost the lock; don't clobber the new owner
			end
			record.data = data
			record.lock = nil -- release
			return record
		end)
	end)
	if not ok then
		warn("[FaB:Data] release failed for", key, err)
	end
end

function DataStoreBackend:name(): string
	return "DataStoreBackend (session-locked)"
end

return DataStoreBackend
