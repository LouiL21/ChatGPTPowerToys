--!strict
--[[
	BeastModelFactory
	Builds a physical creature from primitives — no art assets required.

	The important design rule lives here: RARITY IS PHYSICAL. A Common is
	knee-high and dull; a Mythic towers and glows so brightly you can pick it out
	from across the island. That visible status is the game's flex and the reason
	a visitor screenshots someone's sanctuary.

	Every part is anchored and the model moves via PivotTo, so a plot full of
	beasts costs no physics simulation.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local BeastConfig = require(Shared.Config.BeastConfig)
local ElementConfig = require(Shared.Config.ElementConfig)
local PlotConfig = require(Shared.Config.PlotConfig)
local VariantConfig = require(Shared.Config.VariantConfig)

local Build = require(script.Parent.Build)

local BeastModelFactory = {}

local RARITY_COLOR = {
	Common = Color3.fromRGB(180, 180, 180),
	Uncommon = Color3.fromRGB(90, 200, 100),
	Rare = Color3.fromRGB(70, 140, 240),
	Epic = Color3.fromRGB(170, 90, 240),
	Legendary = Color3.fromRGB(245, 180, 40),
	Mythic = Color3.fromRGB(240, 70, 120),
	Secret = Color3.fromRGB(255, 255, 255),
}

local function elementColor(elementId: string): Color3
	local element = ElementConfig.ById[elementId]
	if not element then
		return Color3.fromRGB(190, 190, 200)
	end
	return Color3.new(element.color[1], element.color[2], element.color[3])
end

-- Deterministic per-beast variation so every species looks distinct but a given
-- species always looks the same.
local function seedFor(beastId: string): number
	local seed = 0
	for i = 1, #beastId do
		seed += string.byte(beastId, i) * i
	end
	return seed
end

local function piece(model: Model, size: Vector3, offset: Vector3, color: Color3, shape: Enum.PartType?, material: Enum.Material?): BasePart
	local part = Build.part({
		size = size,
		color = color,
		shape = shape,
		material = material or Enum.Material.SmoothPlastic,
		canCollide = false,
		anchored = true,
		name = "Piece",
		parent = model,
	})
	part:SetAttribute("Offset", offset)
	return part
end

--[[
	Creates the beast model at the origin. Parts store their local offset as an
	attribute; `BeastModelFactory.pivot` re-places them, which keeps movement a
	single cheap loop over parts rather than a weld/physics tree.
]]
function BeastModelFactory.create(beastId: string, level: number?, variantId: string?): Model?
	local beast = BeastConfig.ById[beastId]
	if not beast then
		return nil
	end

	local variant = VariantConfig.get(variantId or "Normal")
	local variantIndex = VariantConfig.index(variant.id)

	local scale = PlotConfig.RARITY_SCALE[beast.rarity] or 1
	-- Higher variants read as slightly larger as well as brighter.
	scale *= 1 + (variantIndex - 1) * 0.07

	local rng = Random.new(seedFor(beastId))
	local primary = elementColor(beast.elements[1])
	local secondary = elementColor(beast.elements[math.min(2, #beast.elements)])
	local accent = RARITY_COLOR[beast.rarity] or Color3.fromRGB(220, 220, 220)

	-- A non-Normal variant recolours the creature toward its finish, so a Golden
	-- reads as gold at a glance while keeping its species silhouette.
	if variantIndex > 1 then
		local blend = math.min(0.75, 0.3 + variantIndex * 0.12)
		primary = primary:Lerp(variant.color, blend)
		secondary = secondary:Lerp(variant.color, blend * 0.8)
		accent = variant.color
	end

	local model = Instance.new("Model")
	model.Name = beastId

	local bodyLength = rng:NextNumber(3.4, 4.6) * scale
	local bodyHeight = rng:NextNumber(2.4, 3.2) * scale
	local bodyWidth = rng:NextNumber(2.4, 3.0) * scale
	local legHeight = rng:NextNumber(1.4, 2.4) * scale

	-- Root: invisible anchor the whole creature is positioned from.
	local root = piece(model, Vector3.new(1, 1, 1), Vector3.new(0, 0, 0), primary, Enum.PartType.Block)
	root.Name = "Root"
	root.Transparency = 1
	model.PrimaryPart = root

	local bodyY = legHeight + bodyHeight / 2

	-- Body
	piece(model, Vector3.new(bodyWidth, bodyHeight, bodyLength), Vector3.new(0, bodyY, 0), primary, Enum.PartType.Ball).Name =
		"Body"

	-- Head
	local headSize = bodyHeight * rng:NextNumber(0.72, 0.92)
	local headZ = -(bodyLength / 2) - headSize * 0.35
	local headY = bodyY + bodyHeight * rng:NextNumber(0.18, 0.42)
	piece(model, Vector3.new(headSize, headSize, headSize), Vector3.new(0, headY, headZ), primary, Enum.PartType.Ball).Name =
		"Head"

	-- Snout
	piece(
		model,
		Vector3.new(headSize * 0.5, headSize * 0.45, headSize * 0.6),
		Vector3.new(0, headY - headSize * 0.16, headZ - headSize * 0.5),
		secondary,
		Enum.PartType.Ball
	).Name = "Snout"

	-- Eyes
	local eyeOffset = headSize * 0.26
	for _, side in ipairs({ -1, 1 }) do
		piece(
			model,
			Vector3.new(headSize * 0.26, headSize * 0.26, headSize * 0.26),
			Vector3.new(side * eyeOffset, headY + headSize * 0.12, headZ - headSize * 0.34),
			Color3.fromRGB(250, 250, 255),
			Enum.PartType.Ball
		).Name = "Eye"
		piece(
			model,
			Vector3.new(headSize * 0.13, headSize * 0.13, headSize * 0.13),
			Vector3.new(side * eyeOffset, headY + headSize * 0.12, headZ - headSize * 0.43),
			Color3.fromRGB(18, 14, 28),
			Enum.PartType.Ball
		).Name = "Pupil"
	end

	-- Legs
	local legInsetX = bodyWidth * 0.3
	local legInsetZ = bodyLength * 0.28
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			piece(
				model,
				Vector3.new(bodyWidth * 0.22, legHeight, bodyWidth * 0.22),
				Vector3.new(sx * legInsetX, legHeight / 2, sz * legInsetZ),
				secondary,
				Enum.PartType.Cylinder
			).Name = "Leg"
		end
	end

	-- Tail
	piece(
		model,
		Vector3.new(bodyWidth * 0.3, bodyWidth * 0.3, bodyLength * 0.7),
		Vector3.new(0, bodyY + bodyHeight * 0.1, bodyLength / 2 + bodyLength * 0.24),
		secondary,
		Enum.PartType.Ball
	).Name = "Tail"

	-- Crest / horn — bigger and brighter the rarer the beast.
	local rarityIndex = table.find(
		{ "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" },
		beast.rarity
	) or 1
	if rarityIndex >= 3 then
		piece(
			model,
			Vector3.new(headSize * 0.2, headSize * 0.8, headSize * 0.2),
			Vector3.new(0, headY + headSize * 0.62, headZ + headSize * 0.06),
			accent,
			Enum.PartType.Ball,
			Enum.Material.Neon
		).Name = "Horn"
	end

	-- Wings for airborne / high-rarity species.
	local hasWings = table.find(beast.elements, "Air") ~= nil or rarityIndex >= 5
	if hasWings then
		for _, side in ipairs({ -1, 1 }) do
			local wing = piece(
				model,
				Vector3.new(bodyWidth * 1.5, bodyHeight * 0.16, bodyLength * 0.62),
				Vector3.new(side * bodyWidth * 0.85, bodyY + bodyHeight * 0.36, bodyLength * 0.04),
				accent,
				Enum.PartType.Block,
				Enum.Material.Neon
			)
			wing.Name = "Wing"
			wing.Transparency = 0.28
		end
	end

	-- Sparkles mark every variant above Normal — cheap, readable prestige.
	if variant.sparkle then
		local sparkleHost = piece(
			model,
			Vector3.new(0.6, 0.6, 0.6),
			Vector3.new(0, bodyY + bodyHeight * 0.5, 0),
			variant.color,
			Enum.PartType.Ball,
			Enum.Material.Neon
		)
		sparkleHost.Name = "SparkleHost"
		sparkleHost.Transparency = 1

		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Color = ColorSequence.new(variant.color)
		sparkles.LightEmission = 1
		sparkles.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5 * scale),
			NumberSequenceKeypoint.new(1, 0),
		})
		sparkles.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		sparkles.Lifetime = NumberRange.new(0.7, 1.3)
		sparkles.Rate = 6 + variantIndex * 5
		sparkles.Speed = NumberRange.new(1, 2.5)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Parent = sparkleHost
	end

	-- Rarity glow: the "visible from across the map" signal. Variants add to it,
	-- so a Rainbow Common still stands out.
	local range = (PlotConfig.RARITY_LIGHT[beast.rarity] or 0) + (variantIndex - 1) * 5
	if range > 0 then
		local aura = piece(
			model,
			Vector3.new(bodyWidth * 1.5, bodyWidth * 1.5, bodyWidth * 1.5),
			Vector3.new(0, bodyY, 0),
			accent,
			Enum.PartType.Ball,
			Enum.Material.Neon
		)
		aura.Name = "Aura"
		aura.Transparency = 0.86
		Build.glow(aura, accent, range * scale, 2 + rarityIndex * 0.4)
	end

	-- Nameplate: variant-prefixed name in the variant/rarity colour.
	local plate = Build.label(
		root,
		VariantConfig.label(variant.id, beast.name),
		Vector2.new(240, 52),
		bodyY + bodyHeight + 2.4
	)
	local plateText = plate:FindFirstChild("Text") :: TextLabel
	plateText.TextColor3 = accent
	plate.MaxDistance = 140

	model:SetAttribute("BeastId", beastId)
	model:SetAttribute("Rarity", beast.rarity)
	model:SetAttribute("Variant", variant.id)
	model:SetAttribute("Height", bodyY + bodyHeight)

	return model
end

-- Positions every piece from its stored local offset. Cheap enough to call on a
-- movement tick for every beast on the server.
function BeastModelFactory.pivot(model: Model, cframe: CFrame)
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			local offset = child:GetAttribute("Offset")
			if typeof(offset) == "Vector3" then
				local isCylinder = child:IsA("Part") and child.Shape == Enum.PartType.Cylinder
				-- Cylinders are X-aligned; stand legs upright.
				local rotation = isCylinder and CFrame.Angles(0, 0, math.rad(90)) or CFrame.identity
				child.CFrame = cframe * CFrame.new(offset) * rotation
			end
		end
	end
end

return BeastModelFactory
