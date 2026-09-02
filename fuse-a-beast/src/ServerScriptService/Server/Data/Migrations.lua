--!strict
--[[
	Migrations
	Forward-only save upgrades, run once per load before the template reconcile.

	Rule: a migration must be safe to run on a profile that has already been
	migrated (idempotent), because a save that fails to write will be migrated
	again next session. Never delete data a later version might want — reshape it.
]]

local Logger = require(game:GetService("ReplicatedStorage").Shared.Util.Logger).new("Migrate")

local Migrations = {}

-- v1 → v2: beasts became variant-aware.
-- Old: codex[id] = { count = n, level = n }   (aggregate count + merge level)
-- New: codex[id] = { variants = { Normal = n }, discovered = true }
-- Old merge levels are folded in as extra Normal copies so nothing is lost.
local function toVariantCodex(data)
	if typeof(data.codex) ~= "table" then
		return
	end
	for beastId, entry in pairs(data.codex) do
		if typeof(entry) == "table" and entry.variants == nil then
			local count = tonumber(entry.count) or 1
			local level = tonumber(entry.level) or 1
			-- Refund what merging cost: levels 2..L consumed 3,6,9... duplicates.
			local refunded = 0
			for l = 1, level - 1 do
				refunded += l * 3
			end
			data.codex[beastId] = {
				variants = { Normal = math.max(1, count + refunded) },
				discovered = true,
			}
		end
	end

	-- display was { beastId }; it is now { {beastId, variant} }.
	if typeof(data.display) == "table" then
		local rebuilt = {}
		for _, item in ipairs(data.display) do
			if typeof(item) == "string" then
				table.insert(rebuilt, { beastId = item, variant = "Normal" })
			elseif typeof(item) == "table" and typeof(item.beastId) == "string" then
				table.insert(rebuilt, item)
			end
		end
		data.display = rebuilt
	end
end

-- version -> function that upgrades a profile FROM that version to the next.
local STEPS: { [number]: (any) -> () } = {
	[1] = function(data)
		toVariantCodex(data)
		data.version = 2
	end,
}

-- Runs every applicable step in order. Returns true if anything changed.
function Migrations.run(data: any, targetVersion: number): boolean
	if typeof(data) ~= "table" then
		return false
	end
	local current = tonumber(data.version) or 1
	local changed = false

	while current < targetVersion do
		local step = STEPS[current]
		if not step then
			-- No path forward; reconcile will still fill gaps safely.
			Logger:warn("No migration step from version", current)
			break
		end
		local ok, err = pcall(step, data)
		if not ok then
			Logger:error("Migration from version", current, "failed:", err)
			break
		end
		Logger:info("Migrated profile", current, "->", data.version)
		changed = true
		local next_ = tonumber(data.version) or (current + 1)
		if next_ <= current then
			break -- guard against a step that forgets to bump
		end
		current = next_
	end

	return changed
end

return Migrations
