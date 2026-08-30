--!strict
--[[
	PlotBuilder
	Builds one player's Sanctuary: ground, rim, the Fusion Altar, element node
	structures, tycoon buy-pads and the nameplate.

	Returns a handle holding references to the live parts so services can drive
	them (unlock a node, light the altar, retitle the sign) without re-searching
	the tree every tick.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local PlotConfig = require(Shared.Config.PlotConfig)
local ElementConfig = require(Shared.Config.ElementConfig)
local Format = require(Shared.Util.Format)

local Build = require(script.Parent.Build)

local PlotBuilder = {}

export type NodeHandle = {
	element: string,
	root: BasePart,
	crystal: BasePart,
	emitPoint: Vector3,
	unlocked: boolean,
}

export type PadHandle = {
	id: string,
	pad: BasePart,
	label: TextLabel,
	purchased: boolean,
}

export type PlotHandle = {
	index: number,
	model: Model,
	origin: CFrame,
	altar: BasePart,
	altarCrystal: BasePart,
	chamber: Model,
	chamberPillar: BasePart,
	sign: TextLabel,
	nodes: { [string]: NodeHandle },
	pads: { [string]: PadHandle },
	pickupFolder: Folder,
	beastFolder: Folder,
}

local function elementColor(elementId: string): Color3
	local element = ElementConfig.ById[elementId]
	if not element then
		return Color3.fromRGB(200, 200, 200)
	end
	return Color3.new(element.color[1], element.color[2], element.color[3])
end

-- Convert a plot-local offset into world space.
local function toWorld(origin: CFrame, offset: Vector3): Vector3
	return (origin * CFrame.new(offset)).Position
end

local function buildGround(model: Model, origin: CFrame)
	local half = PlotConfig.PLOT_SIZE / 2

	Build.part({
		size = Vector3.new(PlotConfig.PLOT_SIZE, 4, PlotConfig.PLOT_SIZE),
		cframe = origin * CFrame.new(0, -2, 0),
		color = PlotConfig.COLORS.plotGround,
		material = Enum.Material.Grass,
		name = "Ground",
		parent = model,
	})

	Build.part({
		size = Vector3.new(PlotConfig.PLOT_SIZE + 6, 2, PlotConfig.PLOT_SIZE + 6),
		cframe = origin * CFrame.new(0, -4.5, 0),
		color = PlotConfig.COLORS.plotRim,
		material = Enum.Material.Slate,
		name = "Rim",
		parent = model,
	})

	-- Low decorative walls on the three outer edges (keeps players on the plot
	-- and gives the sanctuary a contained, buildable feel).
	local wallSpecs = {
		{ size = Vector3.new(PlotConfig.PLOT_SIZE, 5, 2), offset = Vector3.new(0, 2.5, -half) },
		{ size = Vector3.new(2, 5, PlotConfig.PLOT_SIZE), offset = Vector3.new(-half, 2.5, 0) },
		{ size = Vector3.new(2, 5, PlotConfig.PLOT_SIZE), offset = Vector3.new(half, 2.5, 0) },
	}
	for _, spec in ipairs(wallSpecs) do
		Build.part({
			size = spec.size,
			cframe = origin * CFrame.new(spec.offset),
			color = PlotConfig.COLORS.plotRim,
			material = Enum.Material.Slate,
			name = "Wall",
			parent = model,
		})
	end

	-- Glowing capstones along the wall line. A flat slab reads as unfinished; a
	-- repeated lit detail reads as built, and it costs nine parts.
	for i = -1, 1 do
		for _, spec in ipairs({
			{ x = i * (half * 0.62), z = -half },
			{ x = -half, z = i * (half * 0.62) },
			{ x = half, z = i * (half * 0.62) },
		}) do
			local cap = Build.part({
				size = Vector3.new(3.2, 3.2, 3.2),
				cframe = origin * CFrame.new(Vector3.new(spec.x, 6.2, spec.z)) * CFrame.Angles(0, math.rad(45), 0),
				color = PlotConfig.COLORS.altarGlow,
				material = Enum.Material.Neon,
				canCollide = false,
				name = "WallCap",
				parent = model,
			})
			Build.glow(cap, PlotConfig.COLORS.altarGlow, 12, 1.2)
		end
	end
end

--[[
	Scatters trees and rocks around the sanctuary. Purely decorative, but an
	empty green square is the single biggest reason a procedural world reads as
	a prototype rather than a game. Placement is deterministic per plot and
	keeps clear of the altar, chamber and pad rows so nothing blocks the loop.
]]
local function buildScenery(model: Model, origin: CFrame, index: number)
	local rng = Random.new(index * 7919)
	local half = PlotConfig.PLOT_SIZE / 2

	local KEEP_CLEAR = {
		{ point = PlotConfig.ALTAR_OFFSET, radius = 22 },
		{ point = PlotConfig.CHAMBER_OFFSET, radius = 20 },
		{ point = PlotConfig.SPAWN_OFFSET, radius = 14 },
		{ point = PlotConfig.HABITAT_CENTRE, radius = 16 },
	}

	local function isClear(offset: Vector3): boolean
		-- Keep out of the pad rows entirely.
		if offset.Z > PlotConfig.PAD_ROW_Z - PlotConfig.PAD_ROW_GAP - PlotConfig.PAD_SIZE then
			return false
		end
		for _, zone in ipairs(KEEP_CLEAR) do
			if (Vector3.new(offset.X, 0, offset.Z) - Vector3.new(zone.point.X, 0, zone.point.Z)).Magnitude < zone.radius then
				return false
			end
		end
		for _, node in ipairs(PlotConfig.Nodes) do
			if (Vector3.new(offset.X, 0, offset.Z) - Vector3.new(node.offset.X, 0, node.offset.Z)).Magnitude < 14 then
				return false
			end
		end
		return true
	end

	local placed = 0
	local attempts = 0
	while placed < 22 and attempts < 220 do
		attempts += 1
		local offset = Vector3.new(rng:NextNumber(-half + 8, half - 8), 0, rng:NextNumber(-half + 8, half - 10))
		if isClear(offset) then
			placed += 1
			local base = toWorld(origin, offset)

			if rng:NextNumber() < 0.55 then
				-- Tree: trunk plus two stacked canopy balls.
				local height = rng:NextNumber(7, 12)
				Build.part({
					size = Vector3.new(1.8, height, 1.8),
					position = base + Vector3.new(0, height / 2, 0),
					color = Color3.fromRGB(84, 60, 44),
					material = Enum.Material.Wood,
					canCollide = false,
					name = "Trunk",
					parent = model,
				})
				local leafColor = Color3.fromRGB(56, 120, 62):Lerp(Color3.fromRGB(92, 168, 96), rng:NextNumber())
				for i = 1, 2 do
					local spread = rng:NextNumber(6, 9) - i * 1.8
					Build.part({
						size = Vector3.new(spread, spread * 0.8, spread),
						position = base + Vector3.new(0, height + i * 2.2 - 1.5, 0),
						color = leafColor,
						material = Enum.Material.Grass,
						shape = Enum.PartType.Ball,
						canCollide = false,
						name = "Canopy",
						parent = model,
					})
				end
			else
				-- Rock cluster.
				local count = rng:NextInteger(2, 3)
				for i = 1, count do
					local size = rng:NextNumber(2, 4.5) / i
					Build.part({
						size = Vector3.new(size * 1.4, size, size * 1.2),
						cframe = CFrame.new(base + Vector3.new(rng:NextNumber(-2, 2), size * 0.35, rng:NextNumber(-2, 2)))
							* CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 6), rng:NextNumber(-0.2, 0.2)),
						color = Color3.fromRGB(96, 92, 116),
						material = Enum.Material.Rock,
						canCollide = false,
						name = "Rock",
						parent = model,
					})
				end
			end
		end
	end
end

local function buildAltar(model: Model, origin: CFrame): (BasePart, BasePart)
	local base = toWorld(origin, PlotConfig.ALTAR_OFFSET)

	Build.disc(15, 2, base + Vector3.new(0, 1, 0), PlotConfig.COLORS.altarStone, model).Name = "AltarBase"
	Build.disc(11, 2, base + Vector3.new(0, 2.6, 0), Color3.fromRGB(64, 54, 100), model).Name = "AltarStep"

	local pillar = Build.part({
		size = Vector3.new(7, 9, 7),
		position = base + Vector3.new(0, 7.5, 0),
		color = PlotConfig.COLORS.altarStone,
		material = Enum.Material.Slate,
		name = "AltarPillar",
		parent = model,
	})

	local crystal = Build.part({
		size = Vector3.new(6, 6, 6),
		position = base + Vector3.new(0, 15, 0),
		color = PlotConfig.COLORS.altarGlow,
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
		canCollide = false,
		name = "AltarCrystal",
		parent = model,
	})
	Build.glow(crystal, PlotConfig.COLORS.altarGlow, 30, 3)

	-- Orbiting element motes, mirroring the UI mockup's altar.
	for i, element in ipairs(ElementConfig.List) do
		local angle = (i - 1) / #ElementConfig.List * math.pi * 2
		local mote = Build.part({
			size = Vector3.new(1.6, 1.6, 1.6),
			position = base + Vector3.new(math.cos(angle) * 9, 15, math.sin(angle) * 9),
			color = elementColor(element.id),
			material = Enum.Material.Neon,
			shape = Enum.PartType.Ball,
			canCollide = false,
			name = "Mote_" .. element.id,
			parent = model,
		})
		Build.glow(mote, elementColor(element.id), 8, 1.2)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "AltarPrompt"
	prompt.ActionText = "Fuse"
	prompt.ObjectText = "Fusion Altar"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = pillar

	Build.label(crystal, "Fusion Altar", Vector2.new(220, 50), 6)

	return pillar, crystal
end

-- The Fusion Chamber: two input pods flanking a containment ring. Hidden until
-- the player buys it, then revealed by PlotService:applyProgression.
local function buildChamber(model: Model, origin: CFrame): (Model, BasePart)
	local base = toWorld(origin, PlotConfig.CHAMBER_OFFSET)
	local chamber = Instance.new("Model")
	chamber.Name = "FusionChamber"
	chamber.Parent = model

	Build.disc(13, 2, base + Vector3.new(0, 1, 0), Color3.fromRGB(44, 38, 70), chamber).Name = "ChamberBase"

	-- Two input pods — the visual metaphor for "put two beasts in".
	for _, side in ipairs({ -1, 1 }) do
		local pod = Build.part({
			size = Vector3.new(5, 5, 5),
			position = base + Vector3.new(side * 7, 4.5, 0),
			color = Color3.fromRGB(58, 50, 92),
			material = Enum.Material.Metal,
			name = "Pod",
			parent = chamber,
		})
		local podGlass = Build.part({
			size = Vector3.new(4, 4, 4),
			position = pod.Position + Vector3.new(0, 4, 0),
			color = Color3.fromRGB(120, 200, 255),
			material = Enum.Material.Glass,
			shape = Enum.PartType.Ball,
			canCollide = false,
			transparency = 0.55,
			name = "PodGlass",
			parent = chamber,
		})
		Build.glow(podGlass, Color3.fromRGB(120, 200, 255), 10, 1.6)
	end

	-- Central containment core where the result appears.
	local core = Build.part({
		size = Vector3.new(4.5, 4.5, 4.5),
		position = base + Vector3.new(0, 9, 0),
		color = Color3.fromRGB(255, 150, 220),
		material = Enum.Material.Neon,
		shape = Enum.PartType.Ball,
		canCollide = false,
		name = "ChamberCore",
		parent = chamber,
	})
	Build.glow(core, Color3.fromRGB(255, 150, 220), 22, 2.5)

	local pillar = Build.part({
		size = Vector3.new(5, 7, 5),
		position = base + Vector3.new(0, 4.5, 0),
		color = Color3.fromRGB(52, 44, 82),
		material = Enum.Material.Slate,
		name = "ChamberPillar",
		parent = chamber,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ChamberPrompt"
	prompt.ActionText = "Fuse Beasts"
	prompt.ObjectText = "Fusion Chamber"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 16
	prompt.RequiresLineOfSight = false
	prompt.Parent = pillar

	Build.label(core, "Fusion Chamber", Vector2.new(250, 50), 5)

	return chamber, pillar
end

local function buildNode(model: Model, origin: CFrame, spec): NodeHandle
	local base = toWorld(origin, spec.offset)
	local color = elementColor(spec.element)

	local root = Build.part({
		size = Vector3.new(8, 3, 8),
		position = base + Vector3.new(0, 1.5, 0),
		color = PlotConfig.COLORS.altarStone,
		material = Enum.Material.Slate,
		name = "Node_" .. spec.element,
		parent = model,
	})

	local crystal = Build.part({
		size = Vector3.new(3.6, 6, 3.6),
		position = base + Vector3.new(0, 6, 0),
		color = color,
		material = Enum.Material.Neon,
		canCollide = false,
		name = "NodeCrystal_" .. spec.element,
		parent = model,
	})
	crystal.CFrame = CFrame.new(crystal.Position) * CFrame.Angles(0, math.rad(45), 0)

	Build.label(crystal, spec.element, Vector2.new(150, 40), 4.5)

	return {
		element = spec.element,
		root = root,
		crystal = crystal,
		emitPoint = base + Vector3.new(0, 4, 0),
		unlocked = spec.unlockedByDefault,
	}
end

local function buildPad(model: Model, origin: CFrame, spec, order: number): PadHandle
	-- Pads wrap into rows so each one can be large enough to read and to stand
	-- on. Rows march inward from the plot entrance, so the cheap early pads are
	-- the first thing a new player walks over.
	local perRow = PlotConfig.PAD_PER_ROW
	local total = #PlotConfig.BuyPads
	local row = math.floor((order - 1) / perRow)
	local column = (order - 1) % perRow
	-- The last row is usually short; centre it rather than leaving a gap.
	local inThisRow = math.min(perRow, total - row * perRow)
	local spread = (inThisRow - 1) * PlotConfig.PAD_SPACING
	local x = -spread / 2 + column * PlotConfig.PAD_SPACING
	local z = PlotConfig.PAD_ROW_Z - row * PlotConfig.PAD_ROW_GAP
	local base = toWorld(origin, Vector3.new(x, 0, z))

	local size = PlotConfig.PAD_SIZE

	-- A recessed plinth under the pad reads as a built object rather than a
	-- decal lying on the grass.
	Build.part({
		size = Vector3.new(size + 2, 1, size + 2),
		position = base + Vector3.new(0, 0.5, 0),
		color = PlotConfig.COLORS.plotRim,
		material = Enum.Material.Slate,
		name = "PadPlinth",
		parent = model,
	})

	local pad = Build.part({
		size = Vector3.new(size, 1, size),
		position = base + Vector3.new(0, 1.2, 0),
		color = PlotConfig.COLORS.locked,
		material = Enum.Material.Neon,
		canCollide = false,
		name = "Pad_" .. spec.id,
		parent = model,
	})
	pad.Transparency = 0.25

	local billboard = Build.label(pad, spec.label, Vector2.new(260, 96), 6.5)
	local label = billboard:FindFirstChild("Text") :: TextLabel
	label.Text = string.format("%s\n%s", spec.label, Format.abbreviate(spec.cost))

	return { id = spec.id, pad = pad, label = label, purchased = false }
end

function PlotBuilder.build(index: number, origin: CFrame, parent: Instance): PlotHandle
	local model = Instance.new("Model")
	model.Name = "Plot_" .. index
	model.Parent = parent

	buildGround(model, origin)
	buildScenery(model, origin, index)
	local altar, altarCrystal = buildAltar(model, origin)
	local chamber, chamberPillar = buildChamber(model, origin)

	local nodes: { [string]: NodeHandle } = {}
	for _, spec in ipairs(PlotConfig.Nodes) do
		nodes[spec.element] = buildNode(model, origin, spec)
	end

	local pads: { [string]: PadHandle } = {}
	for _, spec in ipairs(PlotConfig.BuyPads) do
		pads[spec.id] = buildPad(model, origin, spec, spec.order)
	end

	-- Entrance nameplate.
	local signPost = Build.part({
		size = Vector3.new(2, 10, 2),
		position = toWorld(origin, PlotConfig.SIGN_OFFSET) + Vector3.new(0, 5, 0),
		color = PlotConfig.COLORS.plotRim,
		material = Enum.Material.Wood,
		name = "SignPost",
		parent = model,
	})
	local signBillboard = Build.label(signPost, "Empty Sanctuary", Vector2.new(300, 70), 7)
	local sign = signBillboard:FindFirstChild("Text") :: TextLabel

	return {
		index = index,
		model = model,
		origin = origin,
		altar = altar,
		altarCrystal = altarCrystal,
		chamber = chamber,
		chamberPillar = chamberPillar,
		sign = sign,
		nodes = nodes,
		pads = pads,
		pickupFolder = Build.folder("Pickups", model),
		beastFolder = Build.folder("Beasts", model),
	}
end

return PlotBuilder
