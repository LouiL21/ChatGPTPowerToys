--!strict
--[[
	WorldBuilder
	Generates the island the moment the server starts: the central Hub (spawn,
	Arena, leaderboard pillars) and the ring of plot foundations around it.

	Everything is procedural so the repo needs no binary assets and the layout
	stays a config edit. Individual plot contents are built by PlotBuilder when a
	plot is claimed.
]]

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotConfig = require(ReplicatedStorage.Shared.Config.PlotConfig)
local Build = require(script.Parent.Build)

local WorldBuilder = {}

-- Plot i (1-based) sits on a ring around the hub, facing inward.
function WorldBuilder.plotCFrame(index: number): CFrame
	local angle = (index - 1) / PlotConfig.PLOT_COUNT * math.pi * 2
	local position = Vector3.new(
		math.cos(angle) * PlotConfig.PLOT_RING_RADIUS,
		PlotConfig.GROUND_Y,
		math.sin(angle) * PlotConfig.PLOT_RING_RADIUS
	)
	-- Face the hub, so a plot's -Z is "toward the centre".
	return CFrame.lookAt(position, Vector3.new(0, PlotConfig.GROUND_Y, 0))
end

--[[
	Sky and exposure.

	The first pass ran a bright midday sky at Brightness 2.4 with heavy bloom.
	That is the worst possible backdrop for this game: every neon crystal, node
	and buy-pad blew out to a flat white square, so the world lost all its
	detail and the interface had to fight the background for attention.

	The fix is to light the world for its own content — a deep violet twilight
	that neon reads against, with the exposure pulled well back. Ambient does the
	heavy lifting instead of sun brightness, so nothing is actually hard to see;
	it is just no longer overexposed.
]]
local function buildSky()
	Lighting.Ambient = Color3.fromRGB(104, 96, 136)
	Lighting.OutdoorAmbient = Color3.fromRGB(142, 132, 180)
	Lighting.Brightness = 1.7
	Lighting.ExposureCompensation = -0.05
	-- Half an hour earlier: the sun is still low enough for the violet-and-amber
	-- band, but above the horizon rather than sitting on it. Most of the extra
	-- light comes from ambient and a thinner atmosphere, not from turning the
	-- sun up, so the neon keeps its contrast instead of washing out again.
	Lighting.ClockTime = 18.9
	Lighting.GeographicLatitude = 12
	Lighting.EnvironmentDiffuseScale = 0.8
	Lighting.EnvironmentSpecularScale = 0.5
	Lighting.FogColor = Color3.fromRGB(66, 54, 100)
	Lighting.FogEnd = 1600
	Lighting.FogStart = 560

	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Haze = 1.7
	atmosphere.Glare = 0 -- glare is what smeared the horizon into white
	atmosphere.Color = Color3.fromRGB(196, 182, 228)
	atmosphere.Decay = Color3.fromRGB(102, 84, 146)
	atmosphere.Parent = Lighting

	-- No skybox textures: leaving the faces blank lets Roblox render its own
	-- time-of-day gradient, which at 19:24 is the violet-into-orange band we
	-- want. It needs no uploaded assets, so a fresh place looks right on the
	-- first Play. Stars fade in as the sun drops.
	local sky = Lighting:FindFirstChildOfClass("Sky") or Instance.new("Sky")
	sky.StarCount = 6000
	sky.CelestialBodiesShown = true
	sky.SunAngularSize = 12
	sky.MoonAngularSize = 14
	sky.Parent = Lighting

	--[[
		Post-processing, deliberately restrained. Bloom above a HIGH threshold
		only catches genuinely emissive surfaces, so crystals glow and everything
		else keeps its edges — the previous low threshold bloomed the entire
		frame.
	]]
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = 0.35
	bloom.Size = 20
	bloom.Threshold = 1.9
	bloom.Parent = Lighting

	local grade = Lighting:FindFirstChildOfClass("ColorCorrectionEffect") or Instance.new("ColorCorrectionEffect")
	grade.Brightness = -0.03
	grade.Contrast = 0.1
	grade.Saturation = 0.12
	grade.TintColor = Color3.fromRGB(240, 236, 255)
	grade.Parent = Lighting

	-- Sun rays across a low sun turn into a white wash; keep them barely there.
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect") or Instance.new("SunRaysEffect")
	rays.Intensity = 0.02
	rays.Spread = 0.4
	rays.Parent = Lighting
end

local function buildHub(parent: Instance)
	local hub = Build.folder("Hub", parent)

	-- Sea plane so the island reads as an island.
	Build.part({
		size = Vector3.new(2400, 4, 2400),
		position = Vector3.new(0, PlotConfig.GROUND_Y - 6, 0),
		color = PlotConfig.COLORS.water,
		material = Enum.Material.Glass,
		transparency = 0.28,
		name = "Sea",
		parent = hub,
	})

	Build.disc(PlotConfig.HUB_RADIUS, 6, Vector3.new(0, PlotConfig.GROUND_Y - 3, 0), PlotConfig.COLORS.hubGround, hub).Name =
		"HubFloor"
	Build.disc(PlotConfig.HUB_RADIUS + 5, 3, Vector3.new(0, PlotConfig.GROUND_Y - 5, 0), PlotConfig.COLORS.hubTrim, hub).Name =
		"HubTrim"

	-- Spawn pad in the hub centre.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(22, 1, 22)
	spawn.Position = Vector3.new(0, PlotConfig.GROUND_Y + 0.5, 0)
	spawn.Anchored = true
	spawn.CanCollide = true
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Color = PlotConfig.COLORS.hubTrim
	spawn.Material = Enum.Material.Neon
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = hub

	-- The Arena: a raised ring at the hub centre where events run.
	local arena = Build.folder("Arena", hub)
	Build.disc(34, 4, Vector3.new(0, PlotConfig.GROUND_Y + 1, 0), Color3.fromRGB(46, 38, 74), arena).Name = "ArenaFloor"
	for i = 1, 10 do
		local angle = (i - 1) / 10 * math.pi * 2
		local pillar = Build.part({
			size = Vector3.new(4, 20, 4),
			position = Vector3.new(math.cos(angle) * 38, PlotConfig.GROUND_Y + 10, math.sin(angle) * 38),
			color = PlotConfig.COLORS.altarStone,
			material = Enum.Material.Slate,
			name = "Pillar",
			parent = arena,
		})
		local crystal = Build.part({
			size = Vector3.new(3, 5, 3),
			position = pillar.Position + Vector3.new(0, 12, 0),
			color = PlotConfig.COLORS.hubTrim,
			material = Enum.Material.Neon,
			shape = Enum.PartType.Ball,
			canCollide = false,
			name = "PillarCrystal",
			parent = arena,
		})
		Build.glow(crystal, PlotConfig.COLORS.hubTrim, 14, 1.0)
	end

	local banner = Build.part({
		size = Vector3.new(28, 1, 6),
		position = Vector3.new(0, PlotConfig.GROUND_Y + 16, 0),
		transparency = 1,
		canCollide = false,
		name = "ArenaBanner",
		parent = arena,
	})
	Build.label(banner, "THE ARENA", Vector2.new(400, 90), 0, 260)

	-- Paths from the hub out to each plot, so the world reads as connected.
	local paths = Build.folder("Paths", hub)
	for i = 1, PlotConfig.PLOT_COUNT do
		local angle = (i - 1) / PlotConfig.PLOT_COUNT * math.pi * 2
		local inner = PlotConfig.HUB_RADIUS
		local outer = PlotConfig.PLOT_RING_RADIUS - PlotConfig.PLOT_SIZE / 2
		local length = outer - inner
		local mid = inner + length / 2
		Build.part({
			size = Vector3.new(14, 1.5, length),
			cframe = CFrame.lookAt(
				Vector3.new(math.cos(angle) * mid, PlotConfig.GROUND_Y - 0.5, math.sin(angle) * mid),
				Vector3.new(0, PlotConfig.GROUND_Y - 0.5, 0)
			),
			color = PlotConfig.COLORS.path,
			material = Enum.Material.Cobblestone,
			name = "Path",
			parent = paths,
		})
	end

	return hub
end

function WorldBuilder.build(): Folder
	local existing = workspace:FindFirstChild("FaBWorld")
	if existing then
		existing:Destroy()
	end

	local world = Build.folder("FaBWorld", workspace)
	buildSky()
	buildHub(world)
	Build.folder("Plots", world)

	-- Remove the default baseplate if the place still has one.
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end

	return world
end

return WorldBuilder
