--!strict
--[[
	CurrencyService
	The ONLY place currencies and shards are added or removed. Centralizing this
	makes anti-exploit auditing trivial (one code path), keeps values clamped to
	sane bounds, and guarantees a state push after every change.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local ElementConfig = require(Shared.Config.ElementConfig)

local CurrencyService = { Name = "CurrencyService" }
local Registry: any

local MAX_CURRENCY = 1e15 -- hard ceiling to prevent overflow / display glitches

function CurrencyService:Init(registry)
	Registry = registry
end

function CurrencyService:Start() end

local function clamp(n: number): number
	if n < 0 then
		return 0
	elseif n > MAX_CURRENCY then
		return MAX_CURRENCY
	end
	return n
end

-- kind: "essence" | "gems"
function CurrencyService:get(player: Player, kind: string): number
	local data = Registry.DataService:get(player)
	return data and (data.currencies[kind] or 0) or 0
end

function CurrencyService:add(player: Player, kind: string, amount: number): boolean
	if amount == 0 then
		return true
	end
	local data = Registry.DataService:get(player)
	if not data or data.currencies[kind] == nil then
		return false
	end
	data.currencies[kind] = clamp(data.currencies[kind] + amount)
	Registry.StateSync:pushCurrencies(player)
	return true
end

-- Returns true and deducts iff the player can afford it (server-authoritative).
function CurrencyService:trySpend(player: Player, kind: string, amount: number): boolean
	if amount < 0 then
		return false
	end
	local data = Registry.DataService:get(player)
	if not data or (data.currencies[kind] or 0) < amount then
		return false
	end
	data.currencies[kind] = clamp(data.currencies[kind] - amount)
	Registry.StateSync:pushCurrencies(player)
	return true
end

-- Shards (per element) ──────────────────────────────────────────────────────
function CurrencyService:addShards(player: Player, elementId: string, amount: number): boolean
	if not ElementConfig.exists(elementId) then
		return false
	end
	local data = Registry.DataService:get(player)
	if not data then
		return false
	end
	data.shards[elementId] = clamp((data.shards[elementId] or 0) + amount)
	Registry.StateSync:pushCurrencies(player)
	return true
end

-- requirements: { [elementId] = amount }. Atomic: spends nothing unless ALL met.
function CurrencyService:trySpendShards(player: Player, requirements: { [string]: number }): boolean
	local data = Registry.DataService:get(player)
	if not data then
		return false
	end
	for elementId, amount in pairs(requirements) do
		if not ElementConfig.exists(elementId) or (data.shards[elementId] or 0) < amount then
			return false
		end
	end
	for elementId, amount in pairs(requirements) do
		data.shards[elementId] = clamp((data.shards[elementId] or 0) - amount)
	end
	Registry.StateSync:pushCurrencies(player)
	return true
end

return CurrencyService
