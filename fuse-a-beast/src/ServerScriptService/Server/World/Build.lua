--!strict
--[[
	Build
	Tiny declarative helpers for procedural geometry. The whole world is
	generated from code (no .rbxmx assets in git), so these keep world files
	readable instead of a wall of Instance.new boilerplate.
]]

local Build = {}

export type PartOptions = {
	size: Vector3,
	cframe: CFrame?,
	position: Vector3?,
	color: Color3?,
	material: Enum.Material?,
	anchored: boolean?,
	canCollide: boolean?,
	transparency: number?,
	shape: Enum.PartType?,
	name: string?,
	parent: Instance?,
	corner: number?, -- adds a rounded look via a cylinder/ball shape hint
}

function Build.part(options: PartOptions): BasePart
	local part = Instance.new("Part")
	part.Size = options.size
	part.Anchored = if options.anchored == nil then true else options.anchored
	part.CanCollide = if options.canCollide == nil then true else options.canCollide
	part.Color = options.color or Color3.fromRGB(140, 140, 150)
	part.Material = options.material or Enum.Material.SmoothPlastic
	part.Transparency = options.transparency or 0
	part.Name = options.name or "Part"
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth

	if options.shape then
		local shaped = Instance.new("Part")
		shaped.Shape = options.shape
		-- Part.Shape only applies to the Part class; copy props across.
		shaped.Size = part.Size
		shaped.Anchored = part.Anchored
		shaped.CanCollide = part.CanCollide
		shaped.Color = part.Color
		shaped.Material = part.Material
		shaped.Transparency = part.Transparency
		shaped.Name = part.Name
		shaped.TopSurface = Enum.SurfaceType.Smooth
		shaped.BottomSurface = Enum.SurfaceType.Smooth
		part:Destroy()
		part = shaped
	end

	if options.cframe then
		part.CFrame = options.cframe
	elseif options.position then
		part.Position = options.position
	end

	if options.parent then
		part.Parent = options.parent
	end
	return part
end

-- A flat cylinder used for discs (hub floor, altar base, buy pads).
function Build.disc(radius: number, height: number, position: Vector3, color: Color3, parent: Instance?): BasePart
	local part = Instance.new("Part")
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, radius * 2, radius * 2)
	-- Cylinders are X-aligned; rotate so the flat face points up.
	part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	part.Anchored = true
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if parent then
		part.Parent = parent
	end
	return part
end

-- Billboard label used for signage, buy-pad prices and beast nameplates.
function Build.label(adornee: BasePart, text: string, size: Vector2, offsetY: number): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = adornee
	billboard.Size = UDim2.fromOffset(size.X, size.Y)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 220
	billboard.Parent = adornee

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.35
	label.TextStrokeColor3 = Color3.fromRGB(10, 7, 19)
	label.Text = text
	label.Parent = billboard

	return billboard
end

function Build.glow(part: BasePart, color: Color3, range: number, brightness: number?)
	if range <= 0 then
		return
	end
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness or 2
	light.Parent = part
end

function Build.folder(name: string, parent: Instance): Folder
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

return Build
