--!strict
--[[
	Daily
	Things that change once a day, derived from the DATE rather than stored.

	Deriving beats storing here: every client and the server compute the same
	answer from the same UTC day with no replication, no drift and no state to
	migrate — and a player can see tomorrow's rotation coming, which is the part
	that actually brings them back.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ElementConfig = require(ReplicatedStorage.Shared.Config.ElementConfig)

local Daily = {}

-- YYYY-MM-DD in UTC, so a day rolls over at the same moment for everyone.
function Daily.key(): string
	return os.date("!%Y-%m-%d") :: string
end

-- A stable integer for today, used to index rotations.
function Daily.seed(): number
	local t = os.date("!*t")
	return (t :: any).year * 1000 + (t :: any).yday
end

--[[
	Today's featured element. Summons that include it roll on boosted luck, so
	there is a reason to log in on a PARTICULAR day rather than "sometime".
	Rotating through the list by day means every element gets its turn.
]]
function Daily.featuredElement(): string
	local list = ElementConfig.List
	return list[(Daily.seed() % #list) + 1].id
end

return Daily
