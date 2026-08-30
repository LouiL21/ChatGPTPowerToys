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
	local count = #PlotConfig.BuyPads
	local spread = (count - 1) * PlotConfig.PAD_SPACING
	local x = -spread / 2 + (order - 1) * PlotConfig.PAD_SPACING
	local base = toWorld(origin, Vector3.new(x, 0, PlotConfig.PAD_ROW_Z))

	local pad = Build.part({
		size = Vector3.new(9, 1, 9),
		position = base + Vector3.new(0, 0.5, 0),
		color = PlotConfig.COLORS.locked,
		material = Enum.Material.Neon,
		canCollide = false,
		name = "Pad_" .. spec.id,
		parent = model,
	})
	pad.Transparency = 0.25

	local billboard = Build.label(pad, spec.label, Vector2.new(190, 70), 5)
	local label = billboard:FindFirstChild("Text") :: TextLabel
	label.Text = string.format("%s\n%d", spec.label, spec.cost)

	return { id = spec.id, pad = pad, label = label, purchased = false }
end

function PlotBuilder.build(index: number, origin: CFrame, parent: Instance): PlotHandle
	local model = Instance.new("Model")
	model.Name = "Plot_" .. index
	model.Parent = parent

	buildGround(model, origin)
	local altar, altarCrystal = buildAltar(model, origin)

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
		sign = sign,
		nodes = nodes,
		pads = pads,
		pickupFolder = Build.folder("Pickups", model),
		beastFolder = Build.folder("Beasts", model),
	}
end

return PlotBuilder
