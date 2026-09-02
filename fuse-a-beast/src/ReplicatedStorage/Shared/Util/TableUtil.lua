--!strict
--[[ TableUtil — small pure helpers used across server + client. ]]

local TableUtil = {}

-- Deep copy plain tables (no metatables / cyclic refs). Used to clone the
-- profile template so every player gets an independent data table.
function TableUtil.deepCopy<T>(original: T): T
	if typeof(original) ~= "table" then
		return original
	end
	local copy = {}
	for key, value in pairs(original :: any) do
		copy[key] = TableUtil.deepCopy(value)
	end
	return (copy :: any) :: T
end

-- Recursively fill missing keys in `target` from `template` (schema migration).
-- Never overwrites existing player data.
function TableUtil.reconcile(target: { [any]: any }, template: { [any]: any })
	for key, value in pairs(template) do
		if target[key] == nil then
			if typeof(value) == "table" then
				target[key] = TableUtil.deepCopy(value)
			else
				target[key] = value
			end
		elseif typeof(value) == "table" and typeof(target[key]) == "table" then
			TableUtil.reconcile(target[key], value)
		end
	end
end

function TableUtil.count(t: { [any]: any }): number
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

return TableUtil
