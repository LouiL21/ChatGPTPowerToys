--!strict
--[[
	DataService
	Owns every player's authoritative data table for the lifetime of their
	session. Chooses a persistence backend, loads on join, auto-saves on an
	interval, and releases (final save + unlock) on leave / shutdown.

	Other services NEVER touch DataStores directly — they read/write the table
	returned by DataService:get(player). This keeps all persistence concerns in
	one place and all game state server-authoritative.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local TableUtil = require(Shared.Util.TableUtil)
local Signal = require(Shared.Util.Signal)
local Logger = require(Shared.Util.Logger).new("Data")

local ProfileTemplate = require(script.Parent.ProfileTemplate)
local Migrations = require(script.Parent.Migrations)
local DataStoreBackend = require(script.Parent.Backends.DataStoreBackend)
local MockBackend = require(script.Parent.Backends.MockBackend)

local STORE_NAME = "FaB_PlayerData_v1"
local KEY_PREFIX = "u_"

local DataService = {
	Name = "DataService",
	ProfileLoaded = Signal.new(), -- (player, data)
	ProfileReleasing = Signal.new(), -- (player, data)
}

local _backend: any
local _profiles: { [number]: { data: any, releasing: boolean } } = {}

local function keyFor(player: Player): string
	return KEY_PREFIX .. tostring(player.UserId)
end

-- Detect whether real DataStores are usable; fall back to the in-memory mock.
local function selectBackend()
	local ok = pcall(function()
		local dss = game:GetService("DataStoreService")
		-- A cheap probe: GetDataStore itself throws if the API is unavailable.
		dss:GetDataStore(STORE_NAME)
	end)
	if ok and not RunService:IsStudio() then
		return DataStoreBackend.new(STORE_NAME)
	end
	-- In Studio, DataStores require "Enable Studio Access to API Services". If it's
	-- on, prefer the real backend so you test real persistence.
	if ok and RunService:IsStudio() then
		local probeOk = pcall(function()
			game:GetService("DataStoreService"):GetDataStore(STORE_NAME):GetAsync("__probe__")
		end)
		if probeOk then
			return DataStoreBackend.new(STORE_NAME)
		end
	end
	Logger:warn("DataStores unavailable — using MockBackend (data will NOT persist).")
	return MockBackend.new()
end

function DataService:_load(player: Player)
	local key = keyFor(player)
	local raw
	local ok, err = pcall(function()
		raw = _backend:load(key)
	end)
	if not ok then
		Logger:error("Load failed for", player.Name, err)
		player:Kick("Your data failed to load. Please rejoin. (data error)")
		return
	end

	-- New player or migrate existing. Migrations reshape old saves BEFORE the
	-- reconcile fills in any genuinely new fields.
	local data = raw or TableUtil.deepCopy(ProfileTemplate)
	if raw then
		Migrations.run(data, ProfileTemplate.version)
	end
	TableUtil.reconcile(data, ProfileTemplate)

	if data.stats.joinTimestamp == 0 then
		data.stats.joinTimestamp = os.time()
	end

	-- Guard: if the player left during the yield, release immediately.
	if not player.Parent then
		_backend:release(key, data)
		return
	end

	_profiles[player.UserId] = { data = data, releasing = false }
	Logger:info("Loaded profile for", player.Name)
	self.ProfileLoaded:fire(player, data)
end

function DataService:_release(player: Player)
	local entry = _profiles[player.UserId]
	if not entry or entry.releasing then
		return
	end
	entry.releasing = true

	entry.data.lastSeen = os.time()
	self.ProfileReleasing:fire(player, entry.data)

	_backend:release(keyFor(player), entry.data)
	_profiles[player.UserId] = nil
	Logger:info("Released profile for", player.Name)
end

-- Public API ────────────────────────────────────────────────────────────────

function DataService:get(player: Player): any?
	local entry = _profiles[player.UserId]
	return entry and not entry.releasing and entry.data or nil
end

function DataService:isLoaded(player: Player): boolean
	local entry = _profiles[player.UserId]
	return entry ~= nil and not entry.releasing
end

function DataService:save(player: Player)
	local entry = _profiles[player.UserId]
	if not entry or entry.releasing then
		return
	end
	entry.data.lastSeen = os.time()
	_backend:save(keyFor(player), entry.data)
end

-- Lifecycle ───────────────────────────────────────────────────────────────

function DataService:Init()
	_backend = selectBackend()
	Logger:info("Backend:", _backend:name())
end

function DataService:Start()
	Players.PlayerAdded:Connect(function(player)
		self:_load(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:_release(player)
	end)
	-- Handle players already present (e.g. hot reload in Studio).
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:_load(player)
		end)
	end

	-- Auto-save loop.
	task.spawn(function()
		while true do
			task.wait(GameConfig.AUTOSAVE_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				if self:isLoaded(player) then
					self:save(player)
				end
			end
		end
	end)

	-- Flush everything on shutdown (critical to avoid data loss + lock leaks).
	game:BindToClose(function()
		for _, player in ipairs(Players:GetPlayers()) do
			task.spawn(function()
				self:_release(player)
			end)
		end
		-- Give release UpdateAsync calls time to complete.
		task.wait(3)
	end)
end

return DataService
