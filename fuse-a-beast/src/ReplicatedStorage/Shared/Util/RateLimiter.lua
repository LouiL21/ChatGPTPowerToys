--!strict
--[[
	RateLimiter
	Sliding-window per-player rate limiter for RemoteEvent/RemoteFunction traffic.
	Every server handler runs through this BEFORE touching game state — the first
	line of the "assume every remote is hostile" defense.
]]

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type Rule = { max: number, window: number }

function RateLimiter.new(rules: { [string]: Rule })
	return setmetatable({
		_rules = rules,
		_buckets = {} :: { [number]: { [string]: { number } } }, -- userId -> action -> timestamps
	}, RateLimiter)
end

-- Returns true if the call is allowed, false if it should be dropped.
function RateLimiter:check(userId: number, action: string): boolean
	local rule = self._rules[action]
	if not rule then
		return true -- no rule configured = unrestricted (still validated elsewhere)
	end

	local now = os.clock()
	local userBuckets = self._buckets[userId]
	if not userBuckets then
		userBuckets = {}
		self._buckets[userId] = userBuckets
	end

	local timestamps = userBuckets[action]
	if not timestamps then
		timestamps = {}
		userBuckets[action] = timestamps
	end

	-- Drop timestamps outside the window.
	local cutoff = now - rule.window
	local kept = {}
	for _, t in ipairs(timestamps) do
		if t > cutoff then
			table.insert(kept, t)
		end
	end
	userBuckets[action] = kept

	if #kept >= rule.max then
		return false
	end

	table.insert(kept, now)
	return true
end

function RateLimiter:clearPlayer(userId: number)
	self._buckets[userId] = nil
end

return RateLimiter
