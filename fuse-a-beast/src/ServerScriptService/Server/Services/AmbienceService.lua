--!strict
--[[
	AmbienceService
	Motion is what separates a built world from a dead one. This service keeps
	the island in gentle constant movement: altar crystals spin and breathe, node
	crystals bob, element motes orbit, arena pillars pulse.

	Cost control: everything is driven by ONE Heartbeat pass over a registered
	list of animators. Nothing here creates threads or instances per frame, and
	all of it operates on already-anchored parts.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlotConfig = require(ReplicatedStorage.Shared.Config.PlotConfig)

local AmbienceService = { Name = "AmbienceService" }
local Registry: any

type Animator = {
	part: BasePart,
	origin: Vector3,
	kind: string,
	phase: number,
	spin: number,
	radius: number,
	baseSize: Vector3,
	light: PointLight?,
}

local _animators: { Animator } = {}

function AmbienceService:Init(registry)
	Registry = registry
end

local function register(part: BasePart, kind: string, options: { [string]: any }?)
	-- Plots are re-registered whenever they change hands; the marker keeps a part
	-- from accumulating one animator per owner who ever held the plot.
	if part:GetAttribute("Animated") then
		return
	end
	part:SetAttribute("Animated", true)
	options = options or {}
	table.insert(_animators, {
		part = part,
		origin = part.Position,
		kind = kind,
		phase = math.random() * math.pi * 2,
		spin = (options :: any).spin or 1,
		radius = (options :: any).radius or 0,
		baseSize = part.Size,
		light = part:FindFirstChildOfClass("PointLight"),
	})
end

-- Registers everything animatable on one plot. Called once per plot at build.
function AmbienceService:registerPlot(handle)
	register(handle.altarCrystal, "pulse", { spin = 0.6 })

	for _, child in ipairs(handle.model:GetChildren()) do
		if child:IsA("BasePart") then
			if string.sub(child.Name, 1, 5) == "Mote_" then
				register(child, "orbit", { radius = 9, spin = 0.5 })
			elseif string.sub(child.Name, 1, 12) == "NodeCrystal_" then
				register(child, "bob", { spin = 1.2 })
			end
		end
	end

	if handle.barn then
		local vane = handle.barn:FindFirstChild("BarnVane")
		if vane and vane:IsA("BasePart") then
			register(vane, "pulse", { spin = 0.9 })
		end
	end

	if handle.chamber then
		local core = handle.chamber:FindFirstChild("ChamberCore")
		if core and core:IsA("BasePart") then
			register(core, "pulse", { spin = 1.5 })
		end
		for _, child in ipairs(handle.chamber:GetChildren()) do
			if child:IsA("BasePart") and child.Name == "PodGlass" then
				register(child, "bob", { spin = 0.8 })
			end
		end
	end
end

function AmbienceService:registerHub(world: Instance)
	local hub = world:FindFirstChild("Hub")
	local arena = hub and hub:FindFirstChild("Arena")
	if not arena then
		return
	end
	for _, child in ipairs(arena:GetChildren()) do
		if child:IsA("BasePart") and child.Name == "PillarCrystal" then
			register(child, "pulse", { spin = 0.4 })
		end
	end
end

function AmbienceService:Start()
	-- Plots are built before this service starts, so sweep them here.
	Registry.PlotService.PlotAssigned:connect(function(_, handle)
		-- Chamber parts may only have become visible on purchase; re-registering
		-- is harmless because animators are keyed by part, not by owner.
		self:registerPlot(handle)
	end)

	task.defer(function()
		local world = workspace:FindFirstChild("FaBWorld")
		if world then
			self:registerHub(world)
		end
	end)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for index = #_animators, 1, -1 do
			local animator = _animators[index]
			local part = animator.part
			if not part.Parent then
				table.remove(_animators, index)
			else
				local t = now * animator.spin + animator.phase

				if animator.kind == "pulse" then
					local scale = 1 + math.sin(t * 1.6) * 0.08
					part.Size = animator.baseSize * scale
					part.CFrame = CFrame.new(animator.origin) * CFrame.Angles(t * 0.4, t * 0.7, 0)
					if animator.light then
						animator.light.Brightness = 1.5 + math.sin(t * 1.6) * 0.5
					end
				elseif animator.kind == "bob" then
					part.CFrame = CFrame.new(animator.origin + Vector3.new(0, math.sin(t * 1.4) * 0.6, 0))
						* CFrame.Angles(0, t * 0.8, 0)
				elseif animator.kind == "orbit" then
					-- Motes circle the altar around its centre.
					local centre = animator.origin
					local angle = t + animator.phase
					part.Position = Vector3.new(
						centre.X + math.cos(angle) * 0.6,
						centre.Y + math.sin(t * 1.8) * 0.8,
						centre.Z + math.sin(angle) * 0.6
					)
				end
			end
		end
	end)
end

return AmbienceService
