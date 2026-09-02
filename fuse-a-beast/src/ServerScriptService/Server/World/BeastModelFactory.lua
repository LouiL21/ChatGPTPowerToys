--!strict
--[[
	BeastModelFactory
	Builds a physical creature from primitives — no art assets required.

	Two design rules live here.

	1. RARITY IS PHYSICAL. A Common is knee-high and dull; a Mythic towers and
	   glows so brightly you can pick it out from across the island. That visible
	   status is the game's flex and the reason a visitor screenshots someone's
	   sanctuary.

	2. SPECIES HAVE SILHOUETTES. Every beast used to be the same quadruped with
	   jittered dimensions, so a Beastdex of 68 creatures read as one creature in
	   68 colours. Each species now resolves to a body PLAN — quadruped, serpent,
	   avian, golem, wisp, brute, crab or dragon — chosen from its primary element
	   with a deterministic split, so a Fire beast and a Void beast are different
	   animals at a glance, not different palettes.

	3. THEY LOOK BACK. Every plan has glowing neon eyes in its accent colour.
	   It is the cheapest thing that turns an arrangement of parts into a
	   creature, and the one feature every monster in this genre shares.

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

local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

local RARITY_COLOR = {
	Common = Color3.fromRGB(180, 180, 180),
	Uncommon = Color3.fromRGB(90, 200, 100),
	Rare = Color3.fromRGB(70, 140, 240),
	Epic = Color3.fromRGB(170, 90, 240),
	Legendary = Color3.fromRGB(245, 180, 40),
	Mythic = Color3.fromRGB(240, 70, 120),
	Secret = Color3.fromRGB(255, 255, 255),
}

--[[
	Body plans available to each element. The hash picks one of the three, so a
	species always looks the same but siblings of one element still differ.
	Air leans airborne, Earth leans heavy, Void leans incorporeal — the shape
	tells you something true about the beast before you read its card.
]]
local FORMS_BY_ELEMENT: { [string]: { string } } = {
	Fire = { "dragon", "quadruped", "brute" },
	Water = { "serpent", "crab", "quadruped" },
	Earth = { "golem", "crab", "brute" },
	Air = { "avian", "dragon", "wisp" },
	Nature = { "quadruped", "crab", "avian" },
	Void = { "wisp", "dragon", "serpent" },
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

local function rarityIndexOf(rarity: string): number
	return table.find(RARITY_ORDER, rarity) or 1
end

local function formFor(beast, seed: number): string
	local options = FORMS_BY_ELEMENT[beast.elements[1]] or { "quadruped", "brute" }
	-- Legendary+ beasts always take the FIRST plan, which is the most dramatic
	-- of the three, so the top of the dex never looks like a bigger Common.
	if rarityIndexOf(beast.rarity) >= 5 then
		return options[1]
	end
	return options[(seed % #options) + 1]
end

--[[
	One piece of a creature. `rotation` is stored as an attribute rather than
	baked into the CFrame, because `pivot` rebuilds every part's CFrame from its
	stored offset each time the beast moves.
]]
local function piece(
	model: Model,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	shape: Enum.PartType?,
	material: Enum.Material?,
	rotation: Vector3?,
	kind: string?
): BasePart
	local part = Build.part({
		size = size,
		color = color,
		shape = shape,
		kind = kind,
		material = material or Enum.Material.SmoothPlastic,
		canCollide = false,
		anchored = true,
		name = "Piece",
		parent = model,
	})
	part:SetAttribute("Offset", offset)
	if rotation then
		part:SetAttribute("Rot", rotation)
	end
	return part
end

--[[
	Tags a piece so `pivot` animates it.

	`role` names the motion (see MOTION in pivot); `phase` staggers pieces that
	share a role, which is the whole difference between four legs walking and
	four legs twitching in unison. `swing` scales the amplitude, so a heavy
	golem's arms move less than a bird's wings.

	Storing this on the part rather than in a table keeps the model
	self-describing: any system that owns a beast model can animate it without
	looking anything up.
]]
local function animate(part: BasePart, role: string, phase: number, swing: number?): BasePart
	part:SetAttribute("Anim", role)
	part:SetAttribute("Phase", phase)
	part:SetAttribute("Swing", swing or 1)
	return part
end

--[[
	Two eyes, used by every form that has a face.

	They GLOW. A neon eye in the creature's accent colour is the cheapest thing
	that separates "a shape made of parts" from "a thing that is looking at you",
	and it is the one feature every monster in the genre shares. The dark socket
	behind it stops the glow reading as a floating dot.
]]
local function addEyes(model: Model, headSize: number, headY: number, headZ: number, spread: number, glow: Color3)
	for _, side in ipairs({ -1, 1 }) do
		piece(
			model,
			Vector3.new(headSize * 0.34, headSize * 0.3, headSize * 0.2),
			Vector3.new(side * spread, headY + headSize * 0.12, headZ - headSize * 0.3),
			Color3.fromRGB(16, 12, 24),
			Enum.PartType.Ball
		).Name = "Socket"
		piece(
			model,
			Vector3.new(headSize * 0.24, headSize * 0.22, headSize * 0.24),
			Vector3.new(side * spread, headY + headSize * 0.12, headZ - headSize * 0.4),
			glow,
			Enum.PartType.Ball,
			Enum.Material.Neon
		).Name = "Eye"
	end
end

-- ── Body plans ────────────────────────────────────────────────────────────
-- Each returns the creature's overall height, used to place the nameplate.

local function buildQuadruped(model: Model, rng: Random, scale: number, primary: Color3, secondary: Color3, accent: Color3, rarityIndex: number): number
	local bodyLength = rng:NextNumber(3.4, 4.6) * scale
	local bodyHeight = rng:NextNumber(2.4, 3.2) * scale
	local bodyWidth = rng:NextNumber(2.4, 3.0) * scale
	local legHeight = rng:NextNumber(1.6, 2.6) * scale
	local bodyY = legHeight + bodyHeight / 2

	local body = piece(model, Vector3.new(bodyWidth, bodyHeight, bodyLength), Vector3.new(0, bodyY, 0), primary, Enum.PartType.Ball)
	body.Name = "Body"
	animate(body, "body", 0)

	-- A paler underside. Real animals are counter-shaded, and one extra part
	-- does more for "creature" than any amount of extra silhouette.
	piece(
		model,
		Vector3.new(bodyWidth * 0.82, bodyHeight * 0.5, bodyLength * 0.86),
		Vector3.new(0, bodyY - bodyHeight * 0.26, 0),
		primary:Lerp(Color3.new(1, 1, 1), 0.35),
		Enum.PartType.Ball
	).Name = "Belly"

	local headSize = bodyHeight * rng:NextNumber(0.72, 0.92)
	local headZ = -(bodyLength / 2) - headSize * 0.35
	local headY = bodyY + bodyHeight * rng:NextNumber(0.18, 0.42)
	local head = piece(model, Vector3.new(headSize, headSize, headSize), Vector3.new(0, headY, headZ), primary, Enum.PartType.Ball)
	head.Name = "Head"
	animate(head, "head", 1.2)

	piece(
		model,
		Vector3.new(headSize * 0.5, headSize * 0.45, headSize * 0.6),
		Vector3.new(0, headY - headSize * 0.16, headZ - headSize * 0.5),
		secondary,
		Enum.PartType.Ball
	).Name = "Snout"

	-- Ears: wedges rather than balls, so the head has a point to it.
	for _, side in ipairs({ -1, 1 }) do
		animate(
			piece(
				model,
				Vector3.new(headSize * 0.16, headSize * 0.55, headSize * 0.34),
				Vector3.new(side * headSize * 0.3, headY + headSize * 0.5, headZ + headSize * 0.1),
				secondary,
				nil,
				nil,
				Vector3.new(0, 0, side * 0.35),
				"wedge"
			),
			"ear",
			side * 1.4,
			0.8
		).Name = "Ear"
	end

	addEyes(model, headSize, headY, headZ, headSize * 0.26, accent)

	local legInsetX = bodyWidth * 0.32
	local legInsetZ = bodyLength * 0.3
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			-- Diagonal pairs move together, which is how a real quadruped walks
			-- and the reason the gait reads as a trot rather than a hop.
			local leg = piece(
				model,
				Vector3.new(bodyWidth * 0.24, legHeight, bodyWidth * 0.24),
				Vector3.new(sx * legInsetX, legHeight / 2, sz * legInsetZ),
				secondary,
				Enum.PartType.Cylinder
			)
			leg.Name = "Leg"
			animate(leg, "leg", (sx * sz > 0) and 0 or math.pi)

			-- Paw, so the leg does not end in a floating stump.
			piece(
				model,
				Vector3.new(bodyWidth * 0.3, bodyWidth * 0.16, bodyWidth * 0.36),
				Vector3.new(sx * legInsetX, bodyWidth * 0.08, sz * legInsetZ - bodyWidth * 0.04),
				secondary:Lerp(Color3.new(0, 0, 0), 0.25),
				Enum.PartType.Ball
			).Name = "Paw"
		end
	end

	local tail = piece(
		model,
		Vector3.new(bodyWidth * 0.3, bodyWidth * 0.3, bodyLength * 0.7),
		Vector3.new(0, bodyY + bodyHeight * 0.1, bodyLength / 2 + bodyLength * 0.24),
		secondary,
		Enum.PartType.Ball
	)
	tail.Name = "Tail"
	animate(tail, "tail", 0.6)
	-- Tail tip in the accent colour: a small bright point at the far end of the
	-- silhouette makes the sway readable from a distance.
	piece(
		model,
		Vector3.new(bodyWidth * 0.24, bodyWidth * 0.24, bodyWidth * 0.3),
		Vector3.new(0, bodyY + bodyHeight * 0.14, bodyLength / 2 + bodyLength * 0.55),
		accent,
		Enum.PartType.Ball
	).Name = "TailTip"

	if rarityIndex >= 3 then
		for _, side in ipairs({ -1, 1 }) do
			piece(
				model,
				Vector3.new(headSize * 0.16, headSize * 0.75, headSize * 0.16),
				Vector3.new(side * headSize * 0.2, headY + headSize * 0.62, headZ + headSize * 0.06),
				accent,
				nil,
				Enum.Material.Neon,
				Vector3.new(0, 0, side * 0.25),
				"wedge"
			).Name = "Horn"
		end
	end

	return bodyY + bodyHeight
end

local function buildSerpent(model: Model, rng: Random, scale: number, primary: Color3, secondary: Color3, accent: Color3, rarityIndex: number): number
	-- A chain of tapering segments riding a slow S-curve. No legs — it hovers
	-- just off the ground, which is what makes it read as a snake and not a
	-- stretched dog.
	local segments = 8
	local girth = rng:NextNumber(1.5, 2.1) * scale
	local step = girth * 1.05
	local baseY = girth * 0.9

	for i = 1, segments do
		local t = (i - 1) / (segments - 1)
		local taper = 1 - t * 0.62
		local sway = math.sin(t * math.pi * 1.6) * girth * 0.9
		local segment = piece(
			model,
			Vector3.new(girth * taper, girth * taper * 0.85, girth * taper),
			Vector3.new(sway, baseY + math.sin(t * math.pi) * girth * 0.5, (i - 1) * step - step * 0.5),
			i % 2 == 0 and secondary or primary,
			Enum.PartType.Ball
		)
		segment.Name = "Segment"
		-- Phase advances down the chain, so the individual bobs add up to one
		-- travelling wave instead of the whole body pulsing at once.
		animate(segment, "segment", t * math.pi * 2.2, taper)
	end

	local headSize = girth * 1.15
	local headY = baseY + girth * 0.4
	local headZ = -step * 1.1
	local head = piece(model, Vector3.new(headSize * 0.95, headSize * 0.8, headSize * 1.3), Vector3.new(0, headY, headZ), primary, Enum.PartType.Ball)
	head.Name = "Head"
	animate(head, "head", 0, 1.4)
	addEyes(model, headSize, headY, headZ - headSize * 0.2, headSize * 0.24, accent)

	-- Jaw and a forked tongue: cheap, and it sells the silhouette.
	animate(
		piece(
			model,
			Vector3.new(headSize * 0.2, headSize * 0.12, headSize * 0.5),
			Vector3.new(0, headY - headSize * 0.22, headZ - headSize * 0.75),
			Color3.fromRGB(220, 70, 90),
			Enum.PartType.Block
		),
		"tail",
		0,
		1.6
	).Name = "Tongue"

	-- Side fins along the first third of the body.
	for _, side in ipairs({ -1, 1 }) do
		animate(
			piece(
				model,
				Vector3.new(girth * 1.6, girth * 0.16, girth * 1.2),
				Vector3.new(side * girth * 0.8, headY - girth * 0.15, step * 0.8),
				accent,
				nil,
				Enum.Material.Neon,
				Vector3.new(0, 0, side * 0.5),
				"wedge"
			),
			"wing",
			side * 0.8,
			0.5
		).Name = "Fin"
	end

	if rarityIndex >= 3 then
		-- A crest of descending spines down the spine.
		for i = 1, 4 do
			local t = (i - 1) / 4
			piece(
				model,
				Vector3.new(girth * 0.12, girth * (0.8 - t * 0.4), girth * 0.3),
				Vector3.new(math.sin(t * math.pi * 1.6) * girth * 0.9, headY + girth * 0.5, i * step - step * 0.5),
				accent,
				Enum.PartType.Block,
				Enum.Material.Neon
			).Name = "Spine"
		end
	end

	return headY + headSize
end

local function buildAvian(model: Model, rng: Random, scale: number, primary: Color3, secondary: Color3, accent: Color3, rarityIndex: number): number
	-- Upright, two legs, big wings. Tall rather than long, so it stands out in a
	-- habitat full of four-legged creatures.
	local legHeight = rng:NextNumber(2.0, 3.0) * scale
	local bodyHeight = rng:NextNumber(2.6, 3.4) * scale
	local bodyWidth = rng:NextNumber(2.0, 2.6) * scale
	local bodyY = legHeight + bodyHeight * 0.5

	local body = piece(model, Vector3.new(bodyWidth, bodyHeight, bodyWidth * 1.1), Vector3.new(0, bodyY, 0), primary, Enum.PartType.Ball)
	body.Name = "Body"
	animate(body, "body", 0)

	-- Pale breast, the counter-shading that reads as a bird.
	piece(
		model,
		Vector3.new(bodyWidth * 0.72, bodyHeight * 0.7, bodyWidth * 0.7),
		Vector3.new(0, bodyY - bodyHeight * 0.1, -bodyWidth * 0.4),
		primary:Lerp(Color3.new(1, 1, 1), 0.4),
		Enum.PartType.Ball
	).Name = "Breast"

	local headSize = bodyWidth * 0.8
	local headY = bodyY + bodyHeight * 0.6
	local head = piece(model, Vector3.new(headSize, headSize, headSize), Vector3.new(0, headY, -headSize * 0.15), primary, Enum.PartType.Ball)
	head.Name = "Head"
	animate(head, "head", 0.5, 1.3)
	addEyes(model, headSize, headY, -headSize * 0.15, headSize * 0.28, accent)

	-- Beak: a real wedge, so it tapers to a point instead of ending in a slab.
	piece(
		model,
		Vector3.new(headSize * 0.34, headSize * 0.34, headSize * 0.95),
		Vector3.new(0, headY - headSize * 0.04, -headSize * 0.8),
		accent,
		nil,
		nil,
		Vector3.new(-1.57, 0, 0),
		"wedge"
	).Name = "Beak"

	-- Wings, swept back and translucent.
	for _, side in ipairs({ -1, 1 }) do
		local wing = piece(
			model,
			Vector3.new(bodyWidth * 1.9, bodyHeight * 0.16, bodyWidth * 1.5),
			Vector3.new(side * bodyWidth * 1.0, bodyY + bodyHeight * 0.18, bodyWidth * 0.15),
			secondary,
			nil,
			Enum.Material.Neon,
			Vector3.new(0, 0, side * 0.45),
			"wedge"
		)
		wing.Name = "Wing"
		wing.Transparency = 0.22
		-- Opposite phase per side would look like rowing; birds flap together.
		animate(wing, "wing", 0, side)
	end

	-- Fan tail.
	for i = -1, 1 do
		animate(
			piece(
				model,
				Vector3.new(bodyWidth * 0.28, bodyHeight * 0.12, bodyWidth * 1.3),
				Vector3.new(i * bodyWidth * 0.28, bodyY - bodyHeight * 0.25, bodyWidth * 1.1),
				secondary,
				Enum.PartType.Block,
				nil,
				Vector3.new(-0.25, i * 0.18, 0)
			),
			"tail",
			i * 0.5,
			0.7
		).Name = "TailFeather"
	end

	-- Two thin legs with feet.
	for _, side in ipairs({ -1, 1 }) do
		animate(
			piece(
				model,
				Vector3.new(bodyWidth * 0.16, legHeight, bodyWidth * 0.16),
				Vector3.new(side * bodyWidth * 0.24, legHeight / 2, 0),
				accent,
				Enum.PartType.Cylinder
			),
			"leg",
			side > 0 and 0 or math.pi
		).Name = "Leg"
		animate(
			piece(
				model,
				Vector3.new(bodyWidth * 0.34, bodyWidth * 0.12, bodyWidth * 0.6),
				Vector3.new(side * bodyWidth * 0.24, bodyWidth * 0.06, -bodyWidth * 0.14),
				accent,
				Enum.PartType.Block
			),
			"leg",
			side > 0 and 0 or math.pi,
			0.5
		).Name = "Foot"
	end

	if rarityIndex >= 4 then
		piece(
			model,
			Vector3.new(headSize * 0.16, headSize * 0.7, headSize * 0.4),
			Vector3.new(0, headY + headSize * 0.6, -headSize * 0.05),
			accent,
			Enum.PartType.Block,
			Enum.Material.Neon,
			Vector3.new(-0.3, 0, 0)
		).Name = "Crest"
	end

	return headY + headSize
end

local function buildGolem(model: Model, rng: Random, scale: number, primary: Color3, secondary: Color3, accent: Color3, rarityIndex: number): number
	-- All blocks, no neck, wider than it is tall. Reads as heavy from any angle.
	local legHeight = rng:NextNumber(1.2, 1.8) * scale
	local torsoHeight = rng:NextNumber(3.0, 3.8) * scale
	local torsoWidth = rng:NextNumber(3.4, 4.2) * scale
	local torsoDepth = torsoWidth * 0.72
	local bodyY = legHeight + torsoHeight * 0.5

	local torso = piece(model, Vector3.new(torsoWidth, torsoHeight, torsoDepth), Vector3.new(0, bodyY, 0), primary, Enum.PartType.Block)
	torso.Name = "Torso"
	animate(torso, "body", 0, 0.6)

	local headSize = torsoWidth * 0.42
	local headY = bodyY + torsoHeight * 0.5 + headSize * 0.3
	piece(model, Vector3.new(headSize, headSize * 0.85, headSize), Vector3.new(0, headY, -torsoDepth * 0.08), primary, Enum.PartType.Block).Name =
		"Head"
	-- Glowing slot eyes rather than balls — a golem has no eyeballs.
	for _, side in ipairs({ -1, 1 }) do
		piece(
			model,
			Vector3.new(headSize * 0.26, headSize * 0.12, headSize * 0.12),
			Vector3.new(side * headSize * 0.24, headY + headSize * 0.06, -torsoDepth * 0.08 - headSize * 0.5),
			accent,
			Enum.PartType.Block,
			Enum.Material.Neon
		).Name = "Eye"
	end

	-- Slab arms hanging past the waist.
	for _, side in ipairs({ -1, 1 }) do
		-- Heavy limbs swing less: `swing` below 1 is what separates a golem's
		-- trudge from a bird's stride, without a second animation system.
		animate(
			piece(
				model,
				Vector3.new(torsoWidth * 0.3, torsoHeight * 0.9, torsoDepth * 0.55),
				Vector3.new(side * torsoWidth * 0.66, bodyY - torsoHeight * 0.06, 0),
				secondary,
				Enum.PartType.Block,
				nil,
				Vector3.new(0, 0, side * 0.08)
			),
			"leg",
			side > 0 and math.pi or 0,
			0.45
		).Name = "Arm"
		animate(
			piece(
				model,
				Vector3.new(torsoWidth * 0.34, torsoWidth * 0.3, torsoDepth * 0.62),
				Vector3.new(side * torsoWidth * 0.7, bodyY - torsoHeight * 0.56, 0),
				primary,
				Enum.PartType.Block
			),
			"leg",
			side > 0 and math.pi or 0,
			0.45
		).Name = "Fist"
	end

	for _, side in ipairs({ -1, 1 }) do
		animate(
			piece(
				model,
				Vector3.new(torsoWidth * 0.32, legHeight, torsoDepth * 0.6),
				Vector3.new(side * torsoWidth * 0.24, legHeight / 2, 0),
				secondary,
				Enum.PartType.Block
			),
			"leg",
			side > 0 and 0 or math.pi,
			0.55
		).Name = "Leg"
	end

	-- Floating shoulder plates: the "held together by magic" tell.
	if rarityIndex >= 3 then
		for _, side in ipairs({ -1, 1 }) do
			-- Plates drift rather than swing: they are held up by magic, not joints.
			animate(
				piece(
					model,
					Vector3.new(torsoWidth * 0.42, torsoHeight * 0.16, torsoDepth * 0.7),
					Vector3.new(side * torsoWidth * 0.6, bodyY + torsoHeight * 0.55, 0),
					accent,
					Enum.PartType.Block,
					Enum.Material.Neon,
					Vector3.new(0, 0, side * 0.3)
				),
				"float",
				side * 1.6,
				0.3
			).Name = "Plate"
		end
	end

	-- Core seam glowing through the chest.
	piece(
		model,
		Vector3.new(torsoWidth * 0.24, torsoWidth * 0.24, torsoWidth * 0.24),
		Vector3.new(0, bodyY + torsoHeight * 0.1, -torsoDepth * 0.5),
		accent,
		Enum.PartType.Ball,
		Enum.Material.Neon
	).Name = "Core"

	return headY + headSize
end

local function buildWisp(model: Model, rng: Random, scale: number, primary: Color3, secondary: Color3, accent: Color3, rarityIndex: number): number
	-- No legs, no ground contact: a neon core inside a smoked shell, trailed by
	-- a comet tail and ringed with shards.
	local coreSize = rng:NextNumber(2.0, 2.8) * scale
	local floatY = coreSize * 1.6

	local shell = piece(
		model,
		Vector3.new(coreSize * 1.7, coreSize * 1.7, coreSize * 1.7),
		Vector3.new(0, floatY, 0),
		primary,
		Enum.PartType.Ball,
		Enum.Material.ForceField
	)
	shell.Name = "Shell"
	shell.Transparency = 0.55

	local core = piece(model, Vector3.new(coreSize, coreSize, coreSize), Vector3.new(0, floatY, 0), accent, Enum.PartType.Ball, Enum.Material.Neon)
	core.Name = "Core"
	animate(core, "body", 0, 1.4)

	-- Eyes float inside the shell — the only anchor for a face.
	addEyes(model, coreSize, floatY, -coreSize * 0.1, coreSize * 0.24, accent)

	-- Orbiting shards. Static positions; AmbienceService is not involved because
	-- these move with the creature, not with the plot.
	local shardCount = 3 + math.min(3, rarityIndex - 1)
	for i = 1, shardCount do
		local angle = (i - 1) / shardCount * math.pi * 2
		animate(
			piece(
				model,
				Vector3.new(coreSize * 0.22, coreSize * 0.6, coreSize * 0.22),
				Vector3.new(
					math.cos(angle) * coreSize * 1.5,
					floatY + math.sin(angle * 2) * coreSize * 0.4,
					math.sin(angle) * coreSize * 1.5
				),
				secondary,
				nil,
				Enum.Material.Neon,
				Vector3.new(0.4, angle, 0.3),
				"wedge"
			),
			"float",
			angle,
			coreSize * 0.32
		).Name = "Shard"
	end

	-- Comet tail, shrinking behind.
	for i = 1, 4 do
		local t = i / 4
		local trail = piece(
			model,
			Vector3.new(coreSize * (0.8 - t * 0.55), coreSize * (0.8 - t * 0.55), coreSize * (0.8 - t * 0.55)),
			Vector3.new(0, floatY - t * coreSize * 0.3, coreSize * (0.9 + i * 0.6)),
			secondary,
			Enum.PartType.Ball,
			Enum.Material.Neon
		)
		trail.Name = "Trail"
		trail.Transparency = 0.2 + t * 0.5
		-- Later trail balls lag further behind, so the tail whips rather than
		-- shifting as a rigid block.
		animate(trail, "segment", -t * 2.6, 0.5 + t)
	end

	return floatY + coreSize
end

local function buildBrute(model: Model, rng: Random, scale: number, primary: Color3, secondary: Color3, accent: Color3, rarityIndex: number): number
	-- Upright bruiser: heavy chest, tiny head, huge arms. The Arena silhouette.
	local legHeight = rng:NextNumber(1.6, 2.2) * scale
	local chestHeight = rng:NextNumber(2.8, 3.4) * scale
	local chestWidth = rng:NextNumber(3.2, 3.8) * scale
	local chestDepth = chestWidth * 0.62
	local bodyY = legHeight + chestHeight * 0.5

	local chest = piece(model, Vector3.new(chestWidth, chestHeight, chestDepth), Vector3.new(0, bodyY, 0), primary, Enum.PartType.Ball)
	chest.Name = "Chest"
	animate(chest, "body", 0, 0.8)

	local headSize = chestWidth * 0.34
	local headY = bodyY + chestHeight * 0.46
	local head = piece(model, Vector3.new(headSize, headSize, headSize), Vector3.new(0, headY, -chestDepth * 0.12), primary, Enum.PartType.Ball)
	head.Name = "Head"
	animate(head, "head", 2.1, 0.8)
	addEyes(model, headSize, headY, -chestDepth * 0.12, headSize * 0.26, accent)

	-- Jaw tusks.
	for _, side in ipairs({ -1, 1 }) do
		piece(
			model,
			Vector3.new(headSize * 0.14, headSize * 0.4, headSize * 0.14),
			Vector3.new(side * headSize * 0.24, headY - headSize * 0.3, -chestDepth * 0.12 - headSize * 0.36),
			Color3.fromRGB(242, 238, 220),
			Enum.PartType.Ball,
			nil,
			Vector3.new(0.4, 0, 0)
		).Name = "Tusk"
	end

	-- Arms: upper mass plus a fist that hangs near the ground.
	for _, side in ipairs({ -1, 1 }) do
		piece(
			model,
			Vector3.new(chestWidth * 0.42, chestHeight * 0.5, chestDepth * 0.7),
			Vector3.new(side * chestWidth * 0.6, bodyY + chestHeight * 0.12, 0),
			secondary,
			Enum.PartType.Ball
		).Name = "Shoulder"
		animate(
			piece(
				model,
				Vector3.new(chestWidth * 0.34, chestHeight * 0.62, chestDepth * 0.55),
				Vector3.new(side * chestWidth * 0.68, bodyY - chestHeight * 0.34, chestDepth * 0.08),
				secondary,
				Enum.PartType.Ball
			),
			"leg",
			side > 0 and math.pi or 0,
			0.7
		).Name = "Fist"
	end

	-- Stubby legs.
	for _, side in ipairs({ -1, 1 }) do
		animate(
			piece(
				model,
				Vector3.new(chestWidth * 0.3, legHeight, chestWidth * 0.3),
				Vector3.new(side * chestWidth * 0.24, legHeight / 2, 0),
				secondary,
				Enum.PartType.Cylinder
			),
			"leg",
			side > 0 and 0 or math.pi,
			0.8
		).Name = "Leg"
	end

	if rarityIndex >= 3 then
		for _, side in ipairs({ -1, 1 }) do
			piece(
				model,
				Vector3.new(chestWidth * 0.16, chestHeight * 0.55, chestWidth * 0.16),
				Vector3.new(side * chestWidth * 0.42, bodyY + chestHeight * 0.55, 0),
				accent,
				Enum.PartType.Ball,
				Enum.Material.Neon,
				Vector3.new(0, 0, side * 0.4)
			).Name = "Spike"
		end
	end

	return headY + headSize
end


--[[
	Crab: wide, low and armoured, with two oversized claws. The only plan that is
	broader than it is tall, so it reads instantly against everything else in a
	habitat.
]]
local function buildCrab(model: Model, rng: Random, scale: number, primary: Color3, secondary: Color3, accent: Color3, rarityIndex: number): number
	local shellW = rng:NextNumber(4.2, 5.2) * scale
	local shellH = rng:NextNumber(1.8, 2.4) * scale
	local legH = rng:NextNumber(1.4, 2.0) * scale
	local bodyY = legH + shellH / 2

	local shell = piece(model, Vector3.new(shellW, shellH, shellW * 0.8), Vector3.new(0, bodyY, 0), primary, Enum.PartType.Ball)
	shell.Name = "Shell"
	animate(shell, "body", 0, 0.7)
	-- Armour plates across the back.
	for i = -1, 1 do
		piece(
			model,
			Vector3.new(shellW * 0.24, shellH * 0.5, shellW * 0.62),
			Vector3.new(i * shellW * 0.26, bodyY + shellH * 0.42, 0),
			secondary,
			nil,
			nil,
			Vector3.new(0, 0, i * 0.2),
			"wedge"
		).Name = "Plate"
	end

	-- Eyes on stalks, since a crab has no head to put them on.
	for _, side in ipairs({ -1, 1 }) do
		piece(
			model,
			Vector3.new(shellW * 0.08, shellH * 0.9, shellW * 0.08),
			Vector3.new(side * shellW * 0.18, bodyY + shellH * 0.7, -shellW * 0.3),
			secondary,
			Enum.PartType.Cylinder
		).Name = "Stalk"
		piece(
			model,
			Vector3.new(shellW * 0.18, shellW * 0.18, shellW * 0.18),
			Vector3.new(side * shellW * 0.18, bodyY + shellH * 1.15, -shellW * 0.3),
			accent,
			Enum.PartType.Ball,
			Enum.Material.Neon
		).Name = "Eye"
	end

	-- Claws: an upper arm plus a two-part pincer.
	for _, side in ipairs({ -1, 1 }) do
		animate(
			piece(
				model,
				Vector3.new(shellW * 0.5, shellH * 0.55, shellW * 0.34),
				Vector3.new(side * shellW * 0.62, bodyY, -shellW * 0.34),
				secondary,
				Enum.PartType.Ball
			),
			"leg",
			side > 0 and 0 or math.pi,
			0.6
		).Name = "Arm"
		for _, half in ipairs({ 1, -1 }) do
			animate(
				piece(
					model,
					Vector3.new(shellW * 0.34, shellH * 0.3, shellW * 0.5),
					Vector3.new(side * shellW * 0.78, bodyY + half * shellH * 0.18, -shellW * 0.66),
					primary,
					nil,
					nil,
					Vector3.new(0, 0, half * 0.25),
					"wedge"
				),
				"ear",
				side * 1.2,
				1.2
			).Name = "Claw"
		end
	end

	-- Six scuttling legs.
	for _, side in ipairs({ -1, 1 }) do
		for i = 1, 3 do
			animate(
				piece(
					model,
					Vector3.new(shellW * 0.09, legH, shellW * 0.09),
					Vector3.new(side * shellW * 0.44, legH / 2, (i - 2) * shellW * 0.24),
					secondary,
					Enum.PartType.Cylinder
				),
				"leg",
				i * 1.1 + (side > 0 and 0 or math.pi),
				0.7
			).Name = "Leg"
		end
	end

	if rarityIndex >= 3 then
		piece(
			model,
			Vector3.new(shellW * 0.6, shellH * 0.3, shellW * 0.6),
			Vector3.new(0, bodyY + shellH * 0.6, 0),
			accent,
			Enum.PartType.Ball,
			Enum.Material.Neon
		).Name = "Core"
	end

	return bodyY + shellH * 1.4
end

--[[
	Dragon: the showpiece plan. A quadruped body with a raised neck, a horned
	head, spread wings and a spiked tail — the silhouette the top of the dex
	should have.
]]
local function buildDragon(model: Model, rng: Random, scale: number, primary: Color3, secondary: Color3, accent: Color3, rarityIndex: number): number
	local bodyLen = rng:NextNumber(4.6, 5.6) * scale
	local bodyH = rng:NextNumber(2.6, 3.2) * scale
	local bodyW = rng:NextNumber(2.6, 3.2) * scale
	local legH = rng:NextNumber(2.0, 2.8) * scale
	local bodyY = legH + bodyH / 2

	local body = piece(model, Vector3.new(bodyW, bodyH, bodyLen), Vector3.new(0, bodyY, 0), primary, Enum.PartType.Ball)
	body.Name = "Body"
	animate(body, "body", 0)
	piece(
		model,
		Vector3.new(bodyW * 0.8, bodyH * 0.5, bodyLen * 0.84),
		Vector3.new(0, bodyY - bodyH * 0.28, 0),
		primary:Lerp(Color3.new(1, 1, 1), 0.32),
		Enum.PartType.Ball
	).Name = "Belly"

	-- Neck: three segments rising toward the head.
	local neckZ = -bodyLen / 2
	for i = 1, 3 do
		local t = i / 3
		animate(
			piece(
				model,
				Vector3.new(bodyW * (0.5 - t * 0.12), bodyW * (0.5 - t * 0.12), bodyW * 0.6),
				Vector3.new(0, bodyY + bodyH * 0.3 + t * bodyH * 0.8, neckZ - t * bodyW * 0.9),
				primary,
				Enum.PartType.Ball
			),
			"head",
			t * 1.4,
			t
		).Name = "Neck"
	end

	local headSize = bodyW * 0.75
	local headY = bodyY + bodyH * 1.2
	local headZ = neckZ - bodyW * 1.2
	local head = piece(model, Vector3.new(headSize * 0.85, headSize * 0.8, headSize * 1.4), Vector3.new(0, headY, headZ), primary, Enum.PartType.Ball)
	head.Name = "Head"
	animate(head, "head", 1.6, 1.3)
	addEyes(model, headSize, headY, headZ - headSize * 0.3, headSize * 0.24, accent)

	-- Snout and swept-back horns.
	piece(model, Vector3.new(headSize * 0.5, headSize * 0.4, headSize * 0.5), Vector3.new(0, headY - headSize * 0.16, headZ - headSize * 0.8), secondary, Enum.PartType.Ball).Name =
		"Snout"
	for _, side in ipairs({ -1, 1 }) do
		piece(
			model,
			Vector3.new(headSize * 0.18, headSize * 0.9, headSize * 0.22),
			Vector3.new(side * headSize * 0.26, headY + headSize * 0.6, headZ + headSize * 0.2),
			accent,
			nil,
			Enum.Material.Neon,
			Vector3.new(-0.5, 0, side * 0.4),
			"wedge"
		).Name = "Horn"
	end

	-- Wings, always present: a dragon without them is just a big lizard.
	for _, side in ipairs({ -1, 1 }) do
		local wing = piece(
			model,
			Vector3.new(bodyW * 2.4, bodyH * 0.14, bodyLen * 0.9),
			Vector3.new(side * bodyW * 1.4, bodyY + bodyH * 0.5, 0),
			secondary,
			nil,
			Enum.Material.Neon,
			Vector3.new(0, 0, side * 0.35),
			"wedge"
		)
		wing.Name = "Wing"
		wing.Transparency = 0.2
		animate(wing, "wing", 0, side * 1.2)
	end

	-- Four legs, diagonals in phase.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			animate(
				piece(
					model,
					Vector3.new(bodyW * 0.26, legH, bodyW * 0.26),
					Vector3.new(sx * bodyW * 0.34, legH / 2, sz * bodyLen * 0.3),
					secondary,
					Enum.PartType.Cylinder
				),
				"leg",
				(sx * sz > 0) and 0 or math.pi
			).Name = "Leg"
		end
	end

	-- Tail with a run of spines.
	for i = 1, 4 do
		local t = i / 4
		animate(
			piece(
				model,
				Vector3.new(bodyW * (0.42 - t * 0.24), bodyW * (0.42 - t * 0.24), bodyLen * 0.3),
				Vector3.new(0, bodyY - t * bodyH * 0.2, bodyLen / 2 + i * bodyLen * 0.22),
				primary,
				Enum.PartType.Ball
			),
			"tail",
			t * 2,
			t * 1.4
		).Name = "Tail"
		if rarityIndex >= 3 then
			piece(
				model,
				Vector3.new(bodyW * 0.1, bodyW * 0.5, bodyW * 0.24),
				Vector3.new(0, bodyY + bodyW * 0.24 - t * bodyH * 0.2, bodyLen / 2 + i * bodyLen * 0.22),
				accent,
				nil,
				Enum.Material.Neon,
				nil,
				"wedge"
			).Name = "Spine"
		end
	end

	return headY + headSize
end

local BUILDERS: { [string]: (Model, Random, number, Color3, Color3, Color3, number) -> number } = {
	quadruped = buildQuadruped,
	serpent = buildSerpent,
	avian = buildAvian,
	golem = buildGolem,
	wisp = buildWisp,
	brute = buildBrute,
	crab = buildCrab,
	dragon = buildDragon,
}

--[[
	Creates the beast model at the origin. Parts store their local offset as an
	attribute; `BeastModelFactory.pivot` re-places them, which keeps movement a
	single cheap loop over parts rather than a weld/physics tree.
]]
function BeastModelFactory.create(beastId: string, variantId: string?): Model?
	local beast = BeastConfig.ById[beastId]
	if not beast then
		return nil
	end

	local variant = VariantConfig.get(variantId or "Normal")
	local variantIndex = VariantConfig.index(variant.id)
	local rarityIndex = rarityIndexOf(beast.rarity)

	local scale = PlotConfig.RARITY_SCALE[beast.rarity] or 1
	-- Higher variants read as slightly larger as well as brighter.
	scale *= 1 + (variantIndex - 1) * 0.07

	local seed = seedFor(beastId)
	local rng = Random.new(seed)
	local primary = elementColor(beast.elements[1])
	local secondary = elementColor(beast.elements[math.min(2, #beast.elements)])
	local accent = RARITY_COLOR[beast.rarity] or Color3.fromRGB(220, 220, 220)

	-- Nudge each species' hue so two Fire beasts of the same plan are still
	-- telling apart at a distance.
	local tint = Color3.fromHSV((seed % 100) / 100, 0.5, 1)
	primary = primary:Lerp(tint, 0.14)
	secondary = secondary:Lerp(tint, 0.22)

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

	-- Root: invisible anchor the whole creature is positioned from.
	local root = piece(model, Vector3.new(1, 1, 1), Vector3.new(0, 0, 0), primary, Enum.PartType.Block)
	root.Name = "Root"
	root.Transparency = 1
	model.PrimaryPart = root

	local form = formFor(beast, seed)
	local builder = BUILDERS[form] or buildQuadruped
	local height = builder(model, rng, scale, primary, secondary, accent, rarityIndex)

	-- Sparkles mark every variant above Normal — cheap, readable prestige.
	if variant.sparkle then
		local sparkleHost = piece(
			model,
			Vector3.new(0.6, 0.6, 0.6),
			Vector3.new(0, height * 0.6, 0),
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
			Vector3.new(height * 0.7, height * 0.7, height * 0.7),
			Vector3.new(0, height * 0.55, 0),
			accent,
			Enum.PartType.Ball,
			Enum.Material.Neon
		)
		aura.Name = "Aura"
		aura.Transparency = 0.88
		Build.glow(aura, accent, range * scale, 2 + rarityIndex * 0.4)
	end

	-- Nameplate: variant-prefixed name in the variant/rarity colour.
	local plate = Build.label(root, VariantConfig.label(variant.id, beast.name), Vector2.new(240, 52), height + 2.4, 85)
	local plateText = plate:FindFirstChild("Text") :: TextLabel
	plateText.TextColor3 = accent
	plate.MaxDistance = 140

	model:SetAttribute("BeastId", beastId)
	model:SetAttribute("Rarity", beast.rarity)
	model:SetAttribute("Variant", variant.id)
	model:SetAttribute("Form", form)
	model:SetAttribute("Height", height)

	return model
end

--[[
	Builds an Arena boss.

	Bosses reuse the same body plans as beasts, at a much larger scale and in a
	darkened, ember-lit palette, so they read as the same kind of creature the
	player collects — just bigger and angrier. `tier` is the boss's rung on the
	ladder (1..n) and drives size, so The Hollow towers over the Clay Sentinel.

	The rarity index is forced to the top, which is what switches on every
	plan's extras: crests, floating plates, spikes and shoulder armour.
]]
function BeastModelFactory.createBoss(boss, tier: number): Model?
	-- Grows across the whole ladder without the late rungs becoming absurd: the
	-- first boss is roughly twice a Mythic beast, the tenth about five times.
	local scale = 2.2 + tier * 0.28
	local rng = Random.new(seedFor(boss.id))

	local element = elementColor(boss.element)
	local primary = element:Lerp(Color3.fromRGB(24, 18, 34), 0.55)
	local secondary = element:Lerp(Color3.fromRGB(12, 9, 20), 0.7)
	local accent = Color3.fromRGB(255, 120, 60) -- ember, the shared "boss" tell

	local model = Instance.new("Model")
	model.Name = "Boss_" .. boss.id

	local root = piece(model, Vector3.new(1, 1, 1), Vector3.new(0, 0, 0), primary, Enum.PartType.Block)
	root.Name = "Root"
	root.Transparency = 1
	model.PrimaryPart = root

	local builder = BUILDERS[boss.form] or buildBrute
	local height = builder(model, rng, scale, primary, secondary, accent, #RARITY_ORDER)

	-- Menace aura: large, dim and ember-coloured, so a boss is lit from within
	-- rather than glowing like a collectible.
	local aura = piece(
		model,
		Vector3.new(height * 0.85, height * 0.85, height * 0.85),
		Vector3.new(0, height * 0.5, 0),
		accent,
		Enum.PartType.Ball,
		Enum.Material.Neon
	)
	aura.Name = "Aura"
	aura.Transparency = 0.92
	Build.glow(aura, accent, 26, 2)

	model:SetAttribute("BossId", boss.id)
	model:SetAttribute("Rarity", "Boss")
	model:SetAttribute("Height", height)

	return model
end

--[[
	Positions every piece from its stored local offset, applying its animation
	role. Cheap enough to call on a movement tick for every beast on the server:
	no allocations beyond the CFrames themselves, no per-part state, no threads.

	`t`      — a clock, usually os.clock(). Omit for a static pose.
	`moving` — 0..1 walk intensity. Legs and wings scale with it, so a standing
	           beast breathes and a running one strides. Idle motion (tail, ears,
	           floating pieces) never fully stops, because a creature frozen
	           between steps is what made these read as statues.

	Roles pivot around a piece's own centre. That is a deliberate simplification
	over a real joint hierarchy: a leg rotating about its middle reads correctly
	at these proportions and costs one CFrame instead of a rig.
]]
function BeastModelFactory.pivot(model: Model, cframe: CFrame, t: number?, moving: number?)
	local clock = t or 0
	local gait = math.clamp(moving or 0, 0, 1)
	-- Idle amplitude floor: even at a standstill everything keeps a little life.
	local energy = 0.35 + gait * 0.65

	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") then
			local offset = child:GetAttribute("Offset")
			if typeof(offset) == "Vector3" then
				local rotation = CFrame.identity
				local stored = child:GetAttribute("Rot")
				if typeof(stored) == "Vector3" then
					rotation = CFrame.Angles(stored.X, stored.Y, stored.Z)
				end

				local role = child:GetAttribute("Anim")
				local slide = Vector3.zero
				if role and clock > 0 then
					local phase = (child:GetAttribute("Phase") :: number?) or 0
					local swing = (child:GetAttribute("Swing") :: number?) or 1
					local wave = math.sin(clock * 4 + phase)

					if role == "leg" then
						-- Stride fore-and-aft, plus a small lift on the forward half.
						rotation *= CFrame.Angles(wave * 0.55 * energy * swing, 0, 0)
						slide = Vector3.new(0, math.max(0, wave) * 0.18 * gait * swing, 0)
					elseif role == "wing" then
						-- Flap on Z; wings stay busy even when hovering.
						rotation *= CFrame.Angles(0, 0, math.sin(clock * 6 + phase) * 0.5 * (0.6 + gait * 0.4) * swing)
					elseif role == "tail" then
						rotation *= CFrame.Angles(0, wave * 0.35 * energy * swing, wave * 0.12)
					elseif role == "head" then
						-- A slow nod at a different rate, so the head never locks to
						-- the leg rhythm.
						rotation *= CFrame.Angles(math.sin(clock * 2.2 + phase) * 0.1 * swing, math.sin(clock * 1.3 + phase) * 0.14 * swing, 0)
					elseif role == "ear" then
						rotation *= CFrame.Angles(0, 0, wave * 0.22 * energy * swing)
					elseif role == "body" then
						-- Breathing: a subtle rise, plus a roll into the stride.
						slide = Vector3.new(0, math.sin(clock * 2.4 + phase) * 0.12 * swing, 0)
						rotation *= CFrame.Angles(0, 0, wave * 0.05 * gait)
					elseif role == "float" then
						-- Orbiting shards and trailing motes: move in space rather
						-- than rotate in place.
						slide = Vector3.new(
							math.cos(clock * 1.4 + phase) * 0.9 * swing,
							math.sin(clock * 1.9 + phase) * 0.7 * swing,
							math.sin(clock * 1.4 + phase) * 0.9 * swing
						)
						rotation *= CFrame.Angles(clock * 0.8, clock * 1.1 + phase, 0)
					elseif role == "segment" then
						-- Serpent bodies undulate: the phase offset along the chain
						-- is what turns individual bobs into one travelling wave.
						slide = Vector3.new(math.sin(clock * 3 + phase) * 0.75 * swing * energy, 0, 0)
					end
				end

				-- Cylinders are X-aligned; stand them upright before any per-piece
				-- rotation, so a "leg" is a leg whatever else was asked for.
				if child:IsA("Part") and (child :: Part).Shape == Enum.PartType.Cylinder then
					rotation *= CFrame.Angles(0, 0, math.rad(90))
				end

				child.CFrame = cframe * CFrame.new(offset + slide) * rotation
			end
		end
	end
end

return BeastModelFactory
