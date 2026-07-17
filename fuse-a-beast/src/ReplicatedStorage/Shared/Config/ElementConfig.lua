--!strict
--[[
	ElementConfig
	The six essence elements. The Altar generates shards of each element over time;
	fusion recipes are keyed on element pairs/triples.
]]

export type Element = {
	id: string,
	displayName: string,
	color: { number }, -- {r,g,b} 0-1
	baseWeight: number, -- relative generation frequency at the altar
}

local ElementConfig = {}

ElementConfig.List = {
	{ id = "Fire", displayName = "Fire", color = { 0.90, 0.30, 0.16 }, baseWeight = 1.0 },
	{ id = "Water", displayName = "Water", color = { 0.20, 0.55, 0.95 }, baseWeight = 1.0 },
	{ id = "Earth", displayName = "Earth", color = { 0.55, 0.40, 0.22 }, baseWeight = 1.0 },
	{ id = "Air", displayName = "Air", color = { 0.75, 0.85, 0.95 }, baseWeight = 1.0 },
	{ id = "Nature", displayName = "Nature", color = { 0.30, 0.75, 0.35 }, baseWeight = 0.85 },
	{ id = "Void", displayName = "Void", color = { 0.45, 0.20, 0.65 }, baseWeight = 0.55 },
}

ElementConfig.ById = {} :: { [string]: any }
for _, element in ipairs(ElementConfig.List) do
	ElementConfig.ById[element.id] = element
end

function ElementConfig.exists(id: string): boolean
	return ElementConfig.ById[id] ~= nil
end

return ElementConfig
